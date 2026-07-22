---
name: prd-to-issues
description: "Use after a PRD is written to break it into independently grabbable kanban issues using vertical slices (tracer bullets). Each issue should touch all relevant layers — schema, service, API, minimal UI — for end-to-end feedback. Triggers on: 'break this into tasks', 'create issues', 'make a kanban board', 'plan implementation'."
---

# PRD → Issues (Vertical Slice Kanban)

## Цель

Превратить PRD в DAG (directed acyclic graph) маленьких задач, которые **независимо grabbable** агентами. Каждая задача = thin vertical slice через все слои системы.

## Процесс

1. **Найди PRD** в `issues/PRD-*.md`. Если несколько — спроси, с каким работаем.

2. **Прочитай Module Map из PRD**. Это база для разбиения.

3. **Драфт vertical slices**. Каждый slice должен:
   - Быть end-to-end testable (от хранения до видимого результата)
   - Давать ценность сам по себе (даже если последующие slices не реализованы)
   - Не превышать ~300 строк изменений

4. **Проверь на horizontal slicing** — самый частый промах:

   ❌ **Плохо** (horizontal):
   ```
   Issue 1: All schema changes (DB + migrations)
   Issue 2: All service layer
   Issue 3: All API endpoints
   Issue 4: All UI
   ```
   Фидбэк только после issue 4. Не делай так.

   ✅ **Хорошо** (vertical):
   ```
   Issue 1: Award points on lesson complete
            (schema for points + service.awardPoints +
             POST /lessons/:id/complete + dashboard counter)
   Issue 2: Show streak counter
            (streak schema + service.getStreak +
             GET /users/me/stats + UI badge)
   Issue 3: Leaderboard
            (denormalized view + service.getLeaderboard +
             GET /courses/:id/leaderboard + UI table)
   ```
   После issue 1 — работающая система. Каждый следующий — приращение.

5. **Назначь зависимости**. Используй `blocked_by` минимально. Цель — параллелизуемость.

6. **Помечай тип задачи**:
   - `AFK` — агент может выполнить без человека
   - `human-in-the-loop` — нужен дизайн/QA/решение
   - `quick-win` — мелкий рефакторинг

7. **Сохрани каждую задачу как `issues/<slug>.md`**.

## Шаблон тикета

```markdown
# <Title — vertical slice>

**Type**: AFK | human-in-the-loop | quick-win
**Blocked by**: [#issue-1, #issue-2] (или "none")
**Estimated**: S | M | L (S=<2h, M=2-6h, L=>6h)

## Vertical Slice Layers
- [ ] Schema: <что меняется в БД>
- [ ] Service: <какой метод/класс добавляется, какой интерфейс>
- [ ] API: <какой endpoint, какие request/response>
- [ ] UI: <минимальное визуальное представление>
- [ ] Tests: <unit + integration границы>

## Module Map Impact
**New**: <files>
**Modified**: <files>
**Test boundary**: <where>

## Acceptance
- [ ] <Конкретное наблюдаемое условие>
- [ ] All feedback loops green (typecheck, lint, tests)
- [ ] No new `any` / `# type: ignore` without justification

## Out of Scope (для этого slice)
<Что НЕ делаем здесь, отложено на следующий slice>
```

## Self-check перед тем как закончить

Прежде чем отдать список тикетов:

- [ ] **Slice #1 даёт работающий end-to-end результат?** (если нет — переразбей)
- [ ] **Каждый slice пересекает >1 слой?** (если только один слой — это horizontal)
- [ ] **Зависимости минимальны?** (можно ли распараллелить хотя бы 2 slices?)
- [ ] **Каждый slice имеет четкое acceptance criterion?**
- [ ] **AFK задачи реально AFK?** (или там скрытые design decisions?)

## Запрещено

- ❌ Layer-by-layer разбиение (horizontal)
- ❌ Один большой issue на всю фичу
- ❌ Issues без acceptance criteria
- ❌ Issues с зависимостью "all previous"
