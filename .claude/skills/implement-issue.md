---
name: implement-issue
description: "Use to implement a single kanban issue end-to-end with TDD. Triggers on: 'implement issue X', 'work on this ticket', 'do task #N', 'pick the next AFK task'. Enforces red-green-refactor and feedback loops."
---

# Implement an Issue (TDD)

## Цель

Реализовать один тикет end-to-end через TDD, с обязательными feedback loops после каждого изменения.

## Процесс

### 1. Pick & Read
- Если тикет не указан — выбери следующий AFK тикет без блокеров
- Прочитай тикет полностью, включая Acceptance и Out of Scope
- Если что-то непонятно — **остановись и спроси**, не угадывай

### 2. Explore (минимально)
- Прочитай файлы из Module Map
- Не читай весь репо — только то, что в Module Map тикета
- Если Module Map неполный — добавь файлы по grep, но не более 5

### 3. Red — Write Failing Test First
```
1. Создай тест файл (если его нет)
2. Напиши ОДИН тест на acceptance criterion из тикета
3. Запусти тест → должен упасть
4. Зафиксируй: "RED confirmed: <reason for failure>"
```

**Запрещено**: писать имплементацию до падающего теста.

### 4. Green — Minimal Implementation
```
1. Реализуй ровно столько, чтобы тест прошёл
2. Запусти тест → должен пройти
3. Зафиксируй: "GREEN confirmed"
```

**Запрещено**: добавлять "пока я тут" фичи, которых нет в acceptance.

### 5. Refactor — Without Breaking Tests
```
1. Улучши код (DRY, naming, structure) — НО только если очевидно
2. Запусти тест → всё ещё проходит
3. Если тест сломался — откати рефакторинг
```

### 6. Repeat — пока не закроешь все acceptance criteria

Каждый цикл red-green-refactor — один acceptance criterion.

### 7. Feedback Loops (обязательно)

После того как все criteria закрыты, запусти:

**Python:**
```bash
ruff check .
mypy .
pytest -q
```

**TypeScript/Node:**
```bash
npm run typecheck
npm run lint
npm test -- --run
```

Если что-то красное — **сначала чини**, потом завершай.

### 8. Commit
- Один тикет = один коммит (или цепочка коммитов с явным префиксом тикета)
- Сообщение: `<type>(<scope>): <summary>` (conventional commits)
- Включи `Closes #<issue>` в тело коммита если используются GitHub issues

### 9. Self-Review

Прежде чем отчитаться о завершении:

- [ ] Все acceptance criteria закрыты?
- [ ] Все feedback loops зелёные?
- [ ] Нет новых `any` / `# type: ignore` без обоснования?
- [ ] Нет `console.log` / `print` debug-вывода?
- [ ] Нет закомментированного кода?
- [ ] Нет TODO без issue-ссылки?
- [ ] Тесты осмысленные (не `expect(true).toBe(true)`)?
- [ ] Покрыли edge cases из тикета?

## Запрещено

- ❌ Писать код без failing теста сначала
- ❌ Игнорировать красные feedback loops "это не относится к моему тикету"
- ❌ Добавлять фичи вне acceptance criteria
- ❌ Завершать тикет с broken tests / failing types
- ❌ Mock'ать всё подряд "чтобы тест прошёл"
- ❌ Подгонять тесты под код (вместо кода под тесты)
