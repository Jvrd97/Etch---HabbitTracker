# Git Commands для Claude Code

8 slash-команд для git, согласованных с методологией (TDD, vertical slices, kanban).

## Команды

| Команда | Что делает |
|---------|-----------|
| `/git-commit` | Conventional commit message из staged diff, ссылка на issue |
| `/git-branch-issue` | Ветка из issue файла, имя по convention `<type>/<id>-<slug>` |
| `/git-pr` | PR description из веток + closed issues |
| `/git-review-self` | Быстрый self-review перед commit (smell-чеклист) |
| `/git-sync` | Безопасный rebase/merge с main, показывает что приходит |
| `/git-cleanup` | Удаление merged веток с подтверждением |
| `/git-worktree-prep` | Создание worktrees для параллельной AFK работы |
| `/git-undo` | Безопасная отмена последней git-операции |

## Установка

Распакуй zip куда-нибудь, потом:

```bash
cd ~/Documents/MyProj/alv
INSTALL_FROM=~/Downloads/git-commands  # подставь свой путь

mkdir -p .claude/commands
cp "$INSTALL_FROM"/git-*.md .claude/commands/

# Проверка
ls .claude/commands/git-*.md
```

После этого **перезапусти Claude** — slash-команды индексируются при старте.

## Использование (типичный день)

```bash
# Утром — что делать?
/clear
bash scripts/board.sh                 # смотрю канбан

# Беру задачу — создаю ветку
/git-branch-issue 03                  # создаст feat/03-supplements

# Работаю через AFK
/next-task                            # AI делает TDD цикл

# Перед коммитом — самопроверка
/git-review-self                      # быстрый smell check

# Коммит
git add .
/git-commit                           # сгенерирует conventional message

# Перед пушем — синк с main
/git-sync                             # безопасный rebase

# PR
git push origin feat/03-supplements
/git-pr                               # сгенерирует body для gh pr create

# После merge — чищу локально
/git-cleanup                          # удалит merged ветки
```

## Параллельная AFK работа

```bash
# В основном репо
/git-worktree-prep --count=3
# создаст 3 worktrees, каждый на своей ветке

# В трёх отдельных терминалах:
cd ../alv-01-inject-lab-results && claude /next-task
cd ../alv-02-add-redis-cache && claude /next-task
cd ../alv-03-supplements && claude /next-task
```

Каждый агент работает независимо. После завершения — мержишь по очереди через `/git-pr` и стандартный PR flow.

## Безопасность

Команды соблюдают правила из `.claude/settings.json`:

- **Никогда** не делают `git push --force` (denied)
- **Никогда** не делают `git reset --hard origin/main` (denied)
- **Спрашивают** перед `git push`, `git rebase`, `git merge` (ask)
- **Не удаляют** ветки с unpushed коммитами без подтверждения
- **Не разрешают** конфликты автоматически — отдают человеку

## Что они НЕ делают (это важно)

- **Не запускают тесты** — это работа `/review` или хука `check-feedback-loops.sh`
- **Не пушат автоматически** — push требует подтверждения
- **Не правят историю удалённых веток** — никаких force-push
- **Не делают `git config`** — никаких изменений настроек git
- **Не работают с GitHub API напрямую** — для PR используют локальный gh CLI

## Расширение

Если нужны ещё команды — паттерн прост:

1. Создай `.claude/commands/git-<name>.md`
2. Frontmatter:
   ```yaml
   ---
   description: "Short description for the picker"
   ---
   ```
3. Body — инструкции что AI должен сделать. Используй `$ARGUMENTS` для параметров.
4. Перезапусти Claude.

Хорошие кандидаты на следующее:
- `/git-blame-explain` — объяснить почему код был изменён
- `/git-stash-named` — stash с описанием
- `/git-cherry-pick-issue` — применить коммит из другой ветки
- `/git-bisect-help` — помощник для bisect (поиск регрессий)
