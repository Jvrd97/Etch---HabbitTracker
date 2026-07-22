---
name: improve-codebase-architecture
description: "Use to scan the codebase for shallow modules and propose deepening them into AI-friendly deep modules. Triggers on: 'review architecture', 'find architectural improvements', 'make this AI-friendly', 'refactor structure'. Run periodically (e.g., once per sprint)."
---

# Improve Codebase Architecture

## Цель

Найти **shallow modules** в кодбазе и предложить, как объединить их в **deep modules** с простыми интерфейсами и богатой внутренней логикой.

Это критично для AI: глубокие модули = чёткие границы тестов = сильные feedback loops = AI кодит лучше.

## Концепция (быстрая ссылка)

**Shallow module** — тонкий wrapper, мало логики, много export'ов в граф зависимостей.
**Deep module** — простой интерфейс снаружи, рич логика внутри, легко тестировать как unit.

См. *A Philosophy of Software Design* (John Ousterhout) — глава 4.

## Процесс

### 1. Scan
Используй `find`/`fd` для построения карты модулей. Группируй по:
- Папкам сервисов (`services/`, `lib/`, `domain/`)
- Кластерам взаимных импортов (`grep -r 'from .X import'`)
- Размеру файлов (мелкие тесно связанные = кандидаты)

### 2. Identify Shallow Clusters
Признаки shallow модуля:
- Файл <50 строк, экспортирует одну функцию
- Тесно связан с 2-5 соседями (часто меняются вместе)
- Тесты разбросаны и моки везде
- Нет чёткой "поверхности" (интерфейса) — всё public

### 3. Propose Deep Module Replacements

Для каждого кластера предложи:

```markdown
## Candidate: <Module Name>

**Currently shallow modules** (cluster):
- `path/to/a.ts` (32 LOC) — `getUser`, `getUserByEmail`
- `path/to/b.ts` (28 LOC) — `validateUser`
- `path/to/c.ts` (45 LOC) — `formatUserDisplay`

**Coupling evidence**:
- All 3 imported together in 8 of 12 callers
- Tests use shared fixtures
- Changes co-occur in git history (last 10 changes)

**Proposed deep module**:
`services/user/UserService.ts`
- Public interface (5 methods)
- Internal logic (~200 LOC)
- ONE test boundary covering all behavior

**Estimated effort**: M (2-6h)
**Test impact**: 8 small test files → 1 focused integration test

**Priority**: <high/med/low based on how often it's touched>
```

### 4. Output

Сохрани результат в `docs/current/architecture/reviews/architecture-review-<date>.md` со списком кандидатов, отсортированных по приоритету.

**НЕ делай рефакторинг сам** — только предложения. Пользователь решит, что взять в спринт. Каждый approved кандидат → новый issue в kanban через `prd-to-issues`-подобный процесс.

## Anti-patterns to Flag

Помечай эти паттерны как **архитектурные смелы** (не обязательно фиксить, но обращай внимание):

- **Anemic domain models** — классы только с getter/setter, логика снаружи
- **Service jungles** — UserService → AuthService → SessionService → UserService (циклы)
- **God controllers/routes** — endpoint с 200+ строками логики прямо в роуте
- **Mock-heavy tests** — тест где >50% это `mock()` вызовы
- **Files exporting one liner** — `export const x = (y) => z(y)`
- **Duplicate validation logic** — одна и та же проверка в 3+ местах

## Что НЕ предлагать

- ❌ Рефакторинг ради рефакторинга (если модуль работает и редко меняется — оставь)
- ❌ Объединение по смыслу без coupling evidence (могут быть в одном домене, но независимы)
- ❌ Микросервисы (это не архитектурное упражнение)
- ❌ Замену библиотек/фреймворков
