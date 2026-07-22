---
description: "Create a feature branch from a kanban issue file. Branch name follows convention: <type>/<issue-id>-<slug>."
---

Create a git branch from an issue file in `issues/`.

Process:
1. Determine which issue:
   - If $ARGUMENTS is given: use it as issue identifier (e.g., `01` or `01-inject-lab-results`)
   - Otherwise: list available issues and ask user to pick

2. Read the issue file `issues/<issue-id>-*.md`. Extract:
   - **Type field** — maps to git type prefix:
     - `Type: AFK` and title contains "feat" / "add" / "implement" → `feat/`
     - `Type: AFK` and title contains "fix" / "bug" → `fix/`
     - `Type: AFK` and title contains "refactor" → `refactor/`
     - `Type: human-in-the-loop` → `chore/` or `feat/` based on content
     - `Type: quick-win` → `chore/` usually
   - **Slug** — kebab-case from issue filename: `01-inject-lab-results` → `01-inject-lab-results`

3. Verify clean working state:
   - Run `git status --porcelain`. If output is non-empty:
     - Ask user: stash, commit first, or cancel?

4. Verify on main/master:
   - If not on `main` or `master` — ask: switch to main first, or branch from current?

5. Create branch:
   ```bash
   git checkout -b <type>/<issue-id>-<slug>
   ```

6. Output:
   - The branch name created
   - Suggestion to run `/next-task` or `/cu-next-task` to start work

Examples:
- Issue `01-inject-lab-results.md` → branch `feat/01-inject-lab-results`
- Issue `15-fix-cache-bug.md` → branch `fix/15-cache-bug`
- Issue `22-bump-deps.md` → branch `chore/22-bump-deps`

Rules:
- Never branch from a dirty working tree without confirmation
- Branch names always kebab-case, lowercase
- Always pull latest main before branching (offer it explicitly)
