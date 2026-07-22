---
name: clickup-issues
description: "Use when working with ClickUp as kanban backend instead of (or alongside) local markdown issues. Provides a workflow for creating, fetching, picking, and closing tickets via ClickUp MCP tools. Triggers on: 'next clickup task', 'sync to clickup', 'create clickup tasks from PRD', 'show my clickup board'."
---

# ClickUp-Based Kanban

## Командные правила оформления задач (MANDATORY)

Любая задача, создаваемая в ClickUp (вручную или через skills), обязана соответствовать:

- **Главная задача**: название по формуле **«глагол + что сделать + результат»** + описание + лид-ответственный + дедлайн. Задача без любого из этих полей возвращается создателю.
  - ✅ `Подключить GA4 к лендингу Day-Night`
  - ❌ `Бэкенд`, `[Андрей] документ`
- **Всё остальное** — subtasks главной задачи: у каждой конкретный исполнитель и свой дедлайн, название по той же формуле.
- **Документы — только ClickUp Docs** (не Drive, не мессенджер). В задачах ссылаемся на Docs.
- Если лид/исполнитель/дедлайн не известны из контекста — **спроси пользователя до создания**, не оставляй поля пустыми.
- **Справочник команды** — `docs/GENERAL/team.md`: ClickUp `user_id`, email, роль и зона ответственности каждого. Ассигни выбирай оттуда по зоне; если зона «(уточнить)» — спроси пользователя.
- **Ассигни через MCP НЕ работают** (у локального `create_task` нет поля assignees; коннектор claude.ai не авторизован в воркспейс — вернёт «Team(s) not authorized»). Рабочий путь — прямой API:

  ```bash
  TOKEN=$(jq -r '.mcpServers.clickup.env.CLICKUP_API_KEY' ~/.claude.json)
  curl -s -X PUT "https://api.clickup.com/api/v2/task/<task_id>" \
    -H "Authorization: $TOKEN" -H 'Content-Type: application/json' \
    -d '{"assignees":{"add":[<user_id из team.md>]}}'
  ```

  После мутации перечитай задачу GET'ом и проверь фактическое состояние. Токен не логировать и не выводить.

## Формат описания задачи (MANDATORY)

Описание — самодостаточный документ: исполнитель делает задачу, не открывая чат.
Эталон: https://app.clickup.com/t/90152350557/86c9q94y3

Обязательная структура `markdown_description`:

```markdown
Type: AFK|human-in-the-loop | Size: S|M|L | Blocked by: «имя задачи» (если есть)

Source: `путь/к/PRD.md` §секция (или ревью/ADR — откуда задача взялась)

## Goal
1-3 предложения прозой: что делаем и зачем, какой результат.

## Vertical Slice Layers (или ## Шаги)
Развёрнутые буллеты по слоям/шагам: конкретные эндпоинты, файлы, поведение,
краевые случаи. Отдельный буллет **Tests**: какие unit/integration и что проверяют.

## Acceptance
Проверяемые условия готовности, по одному на строку. Включая «mypy --strict + ruff чисто, pytest зелёный» для кода.

## Out of Scope
Что осознанно НЕ входит (чтобы исполнитель не расползался).
```

Анти-паттерн (так нельзя — фрагменты через точку с запятой без контекста):
❌ `Алиас/deprecation до конца Фазы 0 (ADR-014); фронт (codegen), TESTING/README, карта API, «Medical Service» в main.py.`
Каждый такой фрагмент разворачивается в полное предложение внутри секций шаблона:
что именно сделать, где (файл/сервис) и как проверить.

## When to use

Use ClickUp tools instead of (or alongside) local `issues/*.md` files when:
- Команда смотрит задачи через ClickUp UI
- Нужен PM-friendly доступ для не-разработчиков
- Хочешь интегрировать с уже существующими списками/спринтами в ClickUp
- Нужны временные оценки, assignees, sprint planning, time tracking

## Prerequisites

ClickUp MCP должен быть зарегистрирован:
```bash
claude mcp list
# должен показать: clickup
```

И в текущей сессии Claude должны быть доступны MCP-инструменты от ClickUp (имена обычно `mcp__clickup__*` или `clickup_*`).

## Workflow

### 1. Create issues from PRD

После `/grill-me` и `/write-prd`:

```
> Apply prd-to-issues skill, but instead of local markdown files,
> create tasks in ClickUp list "<list-name>".
> Structure:
> - Main task (one per PRD): formula name «глагол + что + результат»,
>   description with PRD goal + link, assignee = лид, due date
> - Each vertical slice: subtask (parent = main task) with formula name,
>   full slice content (Layers, Acceptance, Out of Scope),
>   исполнитель, own due date
> - Dependencies between subtasks: use ClickUp's "blocked by" linking
> - Optional tags (if exist in space): type=AFK|human-in-the-loop, size S|M|L
```

Проверка:
- Используй `mcp__clickup__get_workspace_hierarchy` чтобы найти правильный list_id
- Создай задачи через `mcp__clickup__create_task`
- Если есть зависимости — через `mcp__clickup__add_task_dependency`

### 2. Get next AFK task

```
> Find the next ClickUp task that is:
> - Status: "Open" or "Todo" (not started)
> - Has tag/custom field: type=AFK
> - Not blocked by any open task
> - In list <list-name>
> Pick the highest priority one.
```

Использует:
- `mcp__clickup__filter_tasks` с фильтрами по тегу и статусу
- Проверь зависимости каждой кандидат-задачи через `mcp__clickup__get_task`
- Верни одну задачу, готовую к взятию

### 3. Implement and close

После имплементации (через `implement-issue` skill):

```
> Update ClickUp task <task-id> to status "Closed"
> Add comment with commit SHA: <sha>
> Add comment summarizing what was done
```

Использует:
- `mcp__clickup__update_task` для смены статуса
- `mcp__clickup__create_task_comment` для лога

### 4. Show board state

```
> Show me the current ClickUp board state for list <list-name>:
> - Open AFK tasks (count + titles)
> - Open human-in-the-loop tasks (count + titles)
> - Closed tasks today (count + titles)
> - Blocked tasks (count + titles, with what blocks them)
```

Использует:
- `mcp__clickup__filter_tasks` с разными фильтрами
- Группируй и форматируй вывод

## Hybrid mode (recommended)

Не теряй ценность markdown:

| Артефакт | Где живёт | Почему |
|----------|-----------|--------|
| PRD | `issues/PRD-*.md` в git | Версионируется, AI читает легко |
| Decision logs / ADR | `docs/<PHASE-NN>/ADRs/*.md` (+ `docs/GENERAL/ADRs/`) в git | Source of truth для архитектуры |
| Tickets | ClickUp | UI, sprint planning, team view |
| Implementation | git commits | Закрывают ClickUp tasks по ID |

Тогда workflow:
1. `/grill-me` → диалог в Claude
2. `/write-prd` → markdown в git
3. **`/sync-prd-to-clickup`** (новая команда) → создаёт tasks в ClickUp из PRD
4. `/cu-next-task` → берёт следующую из ClickUp
5. `implement-issue` → закрывает ClickUp task с git SHA

## Cautions

- **Не дублируй state.** Если markdown issues + ClickUp tasks существуют параллельно — статус разъедется. Выбери один источник истины.
- **PII в ClickUp.** Если в task description попадают user-specific данные из health platform — это compliance issue. Хорошая практика: ID-only в ClickUp, детали в git.
- **API rate limits.** ClickUp MCP делает реальные API вызовы. AFK loop может упереться в лимиты при массовых обновлениях.

## Example invocations

```
> /clear
> Apply clickup-issues skill: create tasks in ClickUp list "Health Platform v1"
> from issues/PRD-context-injection.md, with proper dependencies.
```

```
> /clear
> Apply clickup-issues skill: pick the next AFK task from ClickUp list
> "Health Platform v1" and implement it via TDD.
```
