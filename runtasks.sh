#!/bin/bash
set -euo pipefail

# =============================================================================
# run-tasks.sh — Executa todas as tasks de uma pasta PRD via Cursor CLI (agent)
# Uso: ./run-tasks.sh tasks/prd-painel-clima [opções]
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
SKIP_COMPLETED=true
STOP_ON_ERROR=true
FORCE_MODE=false
APPROVE_MCPS=false
TRUST_WORKSPACE=false
MODEL=""
PRD_DIR=""

# Contadores
TOTAL=0
EXECUTED=0
SKIPPED=0
FAILED=0

usage() {
  cat <<EOF
Uso: ./run-tasks.sh <pasta-prd> [opções]

Executa todas as tasks de uma pasta PRD sequencialmente via Cursor CLI (agent).

Argumentos:
  <pasta-prd>                Caminho da pasta PRD (ex: tasks/prd-painel-clima)

Opções:
  --no-skip-completed        Executa mesmo tasks já marcadas como [x]
  --no-stop-on-error         Continua execução mesmo se uma task falhar
  --force                    Pula prompts de aprovação de comandos (alias: --yolo)
  --yolo                     Alias para --force
  --approve-mcps             Aprova automaticamente todos os MCP servers
  --trust                    Confia no workspace sem prompt (modo headless)
  --model <model>            Modelo a utilizar (ex: claude-4-opus)
  -h, --help                 Mostra esta mensagem

Exemplos:
  ./run-tasks.sh tasks/prd-painel-clima
  ./run-tasks.sh tasks/prd-painel-clima --no-skip-completed --model claude-4-opus
  ./run-tasks.sh tasks/prd-painel-clima --force --approve-mcps --trust
EOF
  exit 0
}

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[SKIP]${NC} $1"; }
log_error()   { echo -e "${RED}[ERRO]${NC} $1"; }

# --- Parse de argumentos ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-skip-completed)
      SKIP_COMPLETED=false
      shift
      ;;
    --no-stop-on-error)
      STOP_ON_ERROR=false
      shift
      ;;
    --force|--yolo)
      FORCE_MODE=true
      shift
      ;;
    --approve-mcps)
      APPROVE_MCPS=true
      shift
      ;;
    --trust)
      TRUST_WORKSPACE=true
      shift
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    -*)
      log_error "Flag desconhecida: $1"
      usage
      ;;
    *)
      if [[ -z "$PRD_DIR" ]]; then
        PRD_DIR="$1"
      else
        log_error "Argumento extra inesperado: $1"
        usage
      fi
      shift
      ;;
  esac
done

# --- Validação ---
if [[ -z "$PRD_DIR" ]]; then
  log_error "Pasta PRD não informada."
  usage
fi

PRD_DIR="${PRD_DIR%/}"

if [[ ! -d "$PRD_DIR" ]]; then
  log_error "Pasta não encontrada: $PRD_DIR"
  exit 1
fi

for required_file in tasks.md prd.md techspec.md; do
  if [[ ! -f "$PRD_DIR/$required_file" ]]; then
    log_error "Arquivo obrigatório não encontrado: $PRD_DIR/$required_file"
    exit 1
  fi
done

# --- Verificar que Cursor CLI (agent) está disponível ---
if ! command -v agent &> /dev/null; then
  log_error "Cursor CLI (agent) não encontrado. Instale seguindo: https://cursor.com/docs/cli/overview"
  exit 1
fi

# --- Descobrir tasks ---
TASK_FILES=()
for f in "$PRD_DIR"/*_task.md; do
  [[ -f "$f" ]] || continue
  basename_f=$(basename "$f")
  if [[ "$basename_f" =~ ^[0-9]+_task\.md$ ]]; then
    TASK_FILES+=("$f")
  fi
done

if [[ ${#TASK_FILES[@]} -eq 0 ]]; then
  log_error "Nenhuma task encontrada em $PRD_DIR (padrão: N_task.md)"
  exit 1
fi

# Ordenar numericamente
IFS=$'\n' TASK_FILES=($(for f in "${TASK_FILES[@]}"; do echo "$f"; done | sort -t/ -k2 -V))
unset IFS

TOTAL=${#TASK_FILES[@]}
log_info "Encontradas $TOTAL task(s) em $PRD_DIR"
echo ""

# --- Função para verificar se task está completa ---
is_task_completed() {
  local task_num="$1"
  grep -qE "^[[:space:]]*-[[:space:]]*\[x\][[:space:]]*${task_num}\.0" "$PRD_DIR/tasks.md" 2>/dev/null
}

# --- Loop principal ---
for task_file in "${TASK_FILES[@]}"; do
  basename_f=$(basename "$task_file")
  task_num="${basename_f%%_task.md}"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info "Task $task_num — $task_file"

  if [[ "$SKIP_COMPLETED" == true ]] && is_task_completed "$task_num"; then
    log_warn "Task $task_num já completa — pulando"
    ((SKIPPED++))
    echo ""
    continue
  fi

  PROMPT=$(cat <<PROMPT_EOF
Você é um assistente IA responsável por implementar as tarefas de forma correta.

Ative e siga a skill executar-task para conduzir todo o processo de implementação. A skill contém o procedimento completo de configuração, análise, planejamento, implementação e revisão.

Identifique e carregue as skills necessárias para que a tarefa seja executada com base nas tecnologias utilizadas.

VOCÊ DEVE iniciar a implementação logo após o planejamento.

Utilize o Context7 MCP para analisar a documentação da linguagem, frameworks e bibliotecas envolvidas na implementação.

Após completar a tarefa, marque como completa em tasks.md.

SEMPRE EXECUTE O task-reviewer no final.

Implemente a tarefa ${task_num} do PRD localizado em ${PRD_DIR}.
- Task file: ${PRD_DIR}/${task_num}_task.md
- PRD: ${PRD_DIR}/prd.md
- Tech Spec: ${PRD_DIR}/techspec.md
- Tasks: ${PRD_DIR}/tasks.md
PROMPT_EOF
)

  # Montar comando agent (Cursor CLI)
  AGENT_CMD=(
    agent
    -p
  )

  if [[ "$FORCE_MODE" == true ]]; then
    AGENT_CMD+=(--force)
  fi

  if [[ "$APPROVE_MCPS" == true ]]; then
    AGENT_CMD+=(--approve-mcps)
  fi

  if [[ "$TRUST_WORKSPACE" == true ]]; then
    AGENT_CMD+=(--trust)
  fi

  if [[ -n "$MODEL" ]]; then
    AGENT_CMD+=(--model "$MODEL")
  fi

  AGENT_CMD+=("$PROMPT")

  log_info "Executando agent para task $task_num..."
  echo ""

  set +e
  "${AGENT_CMD[@]}"
  exit_code=$?
  set -e

  if [[ $exit_code -eq 0 ]]; then
    log_success "Task $task_num concluída com sucesso"
    ((EXECUTED++))
  else
    log_error "Task $task_num falhou (exit code: $exit_code)"
    ((FAILED++))

    if [[ "$STOP_ON_ERROR" == true ]]; then
      log_error "Interrompendo execução (use --no-stop-on-error para continuar)"
      break
    fi
  fi

  echo ""
done

# --- Resumo ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}RESUMO${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Total:     $TOTAL"
echo -e "  Executadas: ${GREEN}$EXECUTED${NC}"
echo -e "  Puladas:    ${YELLOW}$SKIPPED${NC}"
echo -e "  Falhas:     ${RED}$FAILED${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
