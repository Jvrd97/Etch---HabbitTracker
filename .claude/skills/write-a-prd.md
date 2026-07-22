---
name: write-a-prd
description: "Use after grill-me session is complete and shared understanding is reached. Generates a PRD (Product Requirements Document) as the destination document for a feature. Triggers on: 'write the PRD', 'now plan it', 'create the spec', 'document this'."
---

# Write a PRD

## Цель

Превратить достигнутое после `grill-me` понимание в **destination document** — описание "куда мы идём". PRD это не план реализации, это описание целевого состояния системы.

## Процесс

1. **Если grill-me не запускался** — остановись и предложи запустить его сначала. PRD без alignment = мусор.

2. **Если в проекте есть код** — быстро проверь, какие модули будут затронуты. Включи это в PRD как `Module Map`.

3. **Заполни шаблон ниже**. Не выдумывай детали, которых не было в грилинге.

4. **Определи фазу и сохрани сам — не спрашивай путь.**
   - Активная фаза = цель симлинка `issues/current` (источник истины — `docs/ROADMAP/STATUS.md`). Например `issues/current → PHASE-00`.
   - PRD живёт в **активной** фазе, даже если контент трогает другую фазу (precedent: PRD сервисов P1 лежат в `PHASE-00/PRDs/`). Меняй фазу, только если пользователь явно назвал другую.
   - Путь: `issues/<active-phase>/PRDs/in-review/PRD-<slug>.md`. Lifecycle папок: `in-review` (новые) → `in-work` → `done`/`issued` — новый PRD всегда в `in-review`.
   - Если структуры `issues/<phase>/PRDs/` нет — fallback на `issues/PRD-<slug>.md` и предупреди.

5. **НЕ перечитывай свой PRD пользователю**. Просто скажи где сохранил (полный путь). Если grill-me был хороший — PRD просто саммари того, что уже в голове у пользователя.

## Шаблон

```markdown
# PRD: <Feature Name>

## Problem Statement
<2-4 предложения: какая проблема у пользователя, почему это важно сейчас>

## Solution
<2-4 предложения: что мы строим и как это решает проблему>

## User Stories
- As a <role>, I want <action>, so that <benefit>.
- ...
(15-20 штук, конкретных, с критериями приёмки)

## Acceptance Criteria
- [ ] <Конкретное измеримое условие>
- [ ] ...

## Module Map (для AI-friendly архитектуры)
**New modules:**
- `<path/to/new-service>` — <простой интерфейс наружу>

**Modified modules:**
- `<path/to/existing>` — <что меняется и почему>

**Test boundaries:**
- Wrap test boundary around: <module>
- Mock at: <interface>

## Implementation Decisions
<Конкретные решения, принятые в грилинге. Не описание процесса, а готовые ответы.>
- Data model: <структура таблиц/коллекций>
- Caching: <что и где кэшируем>
- LLM calls: <какая модель, какой context window, какой prompt>
- Failure handling: <что делаем при сбое>

## Testing Decisions
- Unit: <что тестируем юнитами и где границы>
- Integration: <какие интеграции тестируем>
- E2E: <какие сценарии end-to-end>
- Test data: <откуда берём, как генерируем>

## Out of Scope
**Явно НЕ делаем в этом PRD:**
- <Фича, которая может казаться очевидной, но отложена>
- ...
(Это критично для definition of done.)

## Open Questions
<Если что-то осталось неразрешённым. В идеале — пусто.>
<Например вопросы, котрые нужно разрешить с другии специалистами>
```

## Запрещено

- ❌ Писать PRD без грилинга (даже если "очевидно")
- ❌ Добавлять решения, которых не было в обсуждении
- ❌ Перечитывать PRD пользователю как лекцию
- ❌ Хранить PRD в репо после имплементации (см. CLAUDE.md о doc rot)
