---
description: "Take a local PRD markdown and create corresponding ClickUp tasks (vertical slices) with dependencies."
---

Apply the `clickup-issues` skill to create ClickUp tasks from a local PRD.

## Формат задач (командные правила, обязательны)

- **Главная задача** (одна на PRD): название по формуле **«глагол + что сделать + результат»** + описание + лид-ответственный + дедлайн. Все четыре поля обязательны — задача без них возвращается создателю.
  - ✅ `Подключить GA4 к лендингу Day-Night`
  - ❌ `Бэкенд`, `[Андрей] документ`
- **Vertical slices** → subtasks главной задачи (`parent`), каждая с конкретным **исполнителем** и **своим дедлайном**. Название subtask — по той же формуле.
- **Описание каждой задачи** — по шаблону из `clickup-issues` («Формат описания задачи»): шапка Type/Size/Blocked by → Source → Goal прозой → Layers/Шаги → Acceptance → Out of Scope. Эталон: https://app.clickup.com/t/90152350557/86c9q94y3. Никаких описаний-фрагментов через точку с запятой.
- Документы — только ClickUp Docs (не Drive, не мессенджер). В описание задачи — ссылка на Doc, не вложение.

## Process

1. Find the PRD file: $ARGUMENTS (or default to most recent `issues/**/PRDs/**/*.md`)
2. Read it fully
3. **Спроси у пользователя, если не задано: лид главной задачи, исполнители subtasks, дедлайны, target list.** Не создавай задачи с пустыми обязательными полями.
4. Create the main task via `mcp__clickup__create_task` (или `mcp__claude_ai_ClickUp__clickup_create_task`): formula name, markdown description (цель + ссылка на PRD/Doc), assignee = лид, due date
5. Apply `prd-to-issues` skill logic to determine vertical slices and dependencies
6. For each slice: create subtask (`parent` = main task id) with formula name, full slice content (Layers, Acceptance, Out of Scope), исполнитель, дедлайн
7. For each subtask with "Blocked by", call `mcp__clickup__add_task_dependency`
8. Output summary: main task + subtasks with their ClickUp URLs

Use `mcp__clickup__get_workspace_hierarchy` if you need to discover available lists.

Do NOT keep local markdown issue files in this mode — only the PRD remains in git.
