---
name: cu-next-task
description: "Pick the next AFK task from ClickUp and implement it via TDD. Replaces /next-task when using ClickUp as kanban backend."
---

Apply the `clickup-issues` skill in the following mode:

1. Use `mcp__clickup__filter_tasks` (or equivalent ClickUp MCP tool) to find tasks where:
   - List: $ARGUMENTS (or ask user if not specified)
   - Status: Open / Todo / Backlog (not In Progress, Done, Closed)
   - Tag or custom field: type=AFK
   - Not blocked: no active dependencies on Open tasks

2. Sort by priority (Urgent → High → Normal → Low) then by oldest first.

3. Pick the top task.

4. Apply the `implement-issue` skill workflow on its description:
   - Read full task description
   - Run TDD: red → green → refactor
   - Run feedback loops (typecheck, lint, tests)
   - Commit with `Closes <ClickUp-task-url>` in body

5. After implementation:
   - Update ClickUp task status to "Done" / "Closed" via `mcp__clickup__update_task`
   - Add comment with commit SHA and summary via `mcp__clickup__create_task_comment`

6. If no AFK task is available — output "NO MORE AFK TASKS IN CLICKUP" and stop.

Do NOT touch local `issues/*.md` files in this mode — ClickUp is source of truth for tickets.
