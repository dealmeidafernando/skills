---
name: executar-task
description: Implements feature tasks by loading required skills, reading PRD/TechSpec context, analyzing dependencies, and executing the implementation with tests. Marks tasks as complete in tasks.md and triggers review upon completion. Use when the user asks to implement a task, execute a task, or start working on a specific task number. Do not use for creating tasks, running QA, code review, or bug fixing.
---

# Task Execution

## Procedures

**Step 1: Pre-Task Configuration (Mandatory)**
1. Read the task definition file at `./tasks/prd-[feature-slug]/[num]_task.md`.
2. Read the PRD at `./tasks/prd-[feature-slug]/prd.md` for context.
3. Read the Tech Spec at `./tasks/prd-[feature-slug]/techspec.md` for technical requirements.
4. Identify dependencies from previous tasks and verify they are complete.
5. Do NOT skip any of these reads.

**Step 2: Load Required Skills**
1. Identify the technologies involved in the task (React, Hono, shadcn, etc.).
2. Load the corresponding skills from the project’s `.cursor/skills/` directory, from `~/.cursor/skills-cursor/`, or from other configured Cursor skill locations, based on technologies used.
3. Use Context7 MCP to analyze documentation of involved languages, frameworks, and libraries.

**Step 3: Task Analysis (Mandatory)**
1. Analyze the task considering:
   - Main objectives.
   - How the task fits into the project context.
   - Alignment with project rules and standards.
   - Possible approaches or solutions.
2. Generate a task summary:
   - Task ID and Name.
   - PRD Context (main points).
   - Tech Spec Requirements (key technical requirements).
   - Dependencies.
   - Main Objectives.
   - Risks/Challenges.

**Step 4: Approach Plan (Mandatory)**
1. Define a numbered step-by-step approach.
2. Do NOT skip any step.

**Step 5: Implementation (Mandatory)**
1. Begin implementation immediately after planning.
2. Follow all project standards established in `.cursor/rules/`, `AGENTS.md`, `CLAUDE.md`, and project rules as applicable.
3. Implement solutions without workarounds.
4. Create and run all task tests before considering the task finished.

**Step 6: Mark Task Complete (Mandatory)**
1. After successful implementation and tests, mark the task as complete in `tasks.md`.

**Step 7: Review (Mandatory)**
1. Run a structured review using the `executar-review` skill when available, or an equivalent thorough code review pass.
2. Address any issues identified by the reviewer.
3. Do not finalize the task until review issues are resolved.

## Error Handling
- If the task file does not exist, halt and report to the user.
- If dependencies are not complete, warn the user and ask whether to proceed.
- If tests fail, fix the issues before marking the task as complete.
- If the reviewer identifies critical issues, address them before finalizing.
