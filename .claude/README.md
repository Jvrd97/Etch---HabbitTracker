# Claude Code Config Pack

Production-ready Claude Code конфигурация по методологии Matt Pocock из workshop'а: alignment-first, vertical slices, TDD, deep modules, AFK loops.

## Что внутри

```
.
├── CLAUDE.md                          # Mandatory rules (всегда в контексте)
├── .claude/
│   ├── settings.json                  # Permissions, hooks, defaults
│   ├── settings.local.json.example    # Шаблон для личных настроек
│   ├── hooks/
│   │   ├── guard-dangerous-bash.sh    # Блокирует опасные bash-паттерны
│   │   ├── format-on-save.sh          # Автоформат после Write/Edit
│   │   ├── check-feedback-loops.sh    # Блокирует Stop при красных тестах/типах
│   │   ├── session-context.sh         # Инжектит state в начале сессии
│   │   ├── backup-before-compact.sh   # Бэкап транскрипта перед /compact
│   │   └── statusline.sh              # Status line с Smart/Dumb zone
│   ├── skills/                        # Pull-инструкции (по требованию)
│   │   ├── grill-me.md                # Alignment ритуал
│   │   ├── write-a-prd.md             # Destination document
│   │   ├── prd-to-issues.md           # Vertical-slice kanban
│   │   ├── implement-issue.md         # TDD имплементация
│   │   └── improve-codebase-architecture.md
│   ├── agents/                        # Sub-agents с изолированным контекстом
│   │   ├── explorer.md                # Codebase recon
│   │   └── reviewer.md                # Code review с push'нутыми стандартами
│   └── commands/                      # Слэш-команды
│       ├── grill-me.md
│       ├── write-prd.md
│       ├── prd-to-issues.md
│       ├── next-task.md               # AFK: следующий тикет
│       └── review.md
└── scripts/
    ├── ralph-once.sh                  # Один проход AFK loop
    └── ralph-loop.sh                  # Полный цикл с safety
```

## Установка

1. **Скопируй файлы в корень своего репо**:
   ```bash
   cp -r /path/to/this-pack/. /your/repo/
   ```

2. **Сделай хуки исполняемыми**:
   ```bash
   chmod +x .claude/hooks/*.sh scripts/*.sh
   ```

3. **Адаптируй CLAUDE.md под свой стек**. Особенно секции 3 (Code Style) и 4 (Architecture).

4. **Адаптируй settings.json**. Главное:
   - Допиши специфичные команды в `permissions.allow` (свои make-таргеты, just-рецепты)
   - Допиши свои внешние домены в `permissions.allow` (если нужны WebFetch к специфичным API)

5. **Создай `issues/` директорию**:
   ```bash
   mkdir -p issues/closed
   ```

6. **Опционально**: скопируй `settings.local.json.example` в `settings.local.json` для личных настроек (gitignored автоматически).

7. **Добавь в `.gitignore`**:
   ```
   .claude/logs/
   .claude/backups/
   ```

## Workflow

### Новая фича

```bash
# 1. Чистый старт
/clear

# 2. Грилинг до alignment
/grill-me <описание идеи или путь к brief.md>
# ... 30-100 вопросов с рекомендациями ...

# 3. PRD как destination document
/write-prd

# 4. Разбиение на vertical slices
/prd-to-issues

# 5. Имплементация (вручную или AFK)
/next-task   # один тикет
# или
bash scripts/ralph-once.sh   # автономный одиночный проход
# или после валидации:
bash scripts/ralph-loop.sh   # полная ночная смена
```

### Code review

```bash
/review
```

Запускает sub-agent в изолированном контексте с push'нутыми стандартами из `.claude/agents/reviewer.md`.

### Архитектурный health check (раз в спринт)

В Claude:
> Apply the `improve-codebase-architecture` skill.

## Ключевые feature-флаги через env

```bash
# Отключить feedback-loop check для planning-only сессий
export CLAUDE_SKIP_FEEDBACK_CHECK=1

# Кастомизация Ralph loop
export MAX_ITERATIONS=10
export SLEEP_SECONDS=60
export RALPH_MAX_TURNS=30
```

## Что не делать

- ❌ Не запускай `ralph-loop.sh`, пока `ralph-once.sh` не отработал стабильно 5+ раз
- ❌ Не комментируй PreToolUse hook — он защищает от случайных rm -rf
- ❌ Не выноси все правила в `CLAUDE.md` — он должен оставаться <2000 токенов
- ❌ Не используй `--dangerously-skip-permissions` в реальном репо
- ❌ Не храни PRD после merge (doc rot — убийца контекста через месяц)

## Адаптация под твои проекты

### Health Platform (Postgres + Redis + LangChain + Qdrant)

В `CLAUDE.md` раздел "Architecture Constraints" уже под это заточен. Дополнительно:

- В `permissions.allow` добавь:
  ```
  "Bash(alembic *)",
  "Bash(uv run *)",
  "Bash(python -m langchain *)"
  ```
- Хук `check-feedback-loops.sh` уже умеет pytest+mypy+ruff

### Document Search (Milvus + ingestion service + DGX Spark API)

Дополнительно в `CLAUDE.md`:
- Phase: ingestion service пишется на отдельном сервере, не на DGX
- LLM/embedding API на DGX Spark — клиенты дёргают через REST/gRPC, не локально

В `permissions.allow`:
```
"Bash(docker compose -f infra/docker-compose.dgx.yml *)",
"Bash(curl -X POST http://dgx-spark.local:*)"
```

## Дополнительно: Sand Castle для параллелизма

Когда `ralph-once.sh` работает стабильно — следующий шаг параллелизация через git worktrees + Docker sandboxes. См. https://github.com/mattpocock/sandcastle (концептуально).

Идея:
```
1. Planner: смотрит на kanban, считает фазы (DAG)
2. Для каждой фазы:
   - Создаёт worktree на каждый issue
   - Запускает Claude в Docker sandbox на каждом worktree (параллельно)
   - Ждёт всех
3. Merger: мержит ветки, резолвит конфликты типов/тестов
```
