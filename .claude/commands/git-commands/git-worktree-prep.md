---
description: "Prepare git worktrees for parallel AFK work. Creates a worktree per unblocked AFK issue so multiple agents can work in parallel."
---

Prepare git worktrees for parallel AFK work.

Use case: you want multiple Claude agents to work on different unblocked AFK issues in parallel. Each agent needs its own working directory + branch. `git worktree` is the right tool.

Process:
1. Check current state is clean:
   - `git status --porcelain` — if dirty, STOP and tell user to commit/stash

2. Make sure on main and up to date:
   - `git checkout main && git pull origin main`

3. Find unblocked AFK issues:
   - Read `issues/*.md` (excluding `closed/`)
   - Filter: `Type: AFK`
   - Filter: all blockers in `closed/`
   - Take top N (default 3, override via $ARGUMENTS like `--count=5`)

4. Show plan:
   ```
   Will create N worktrees:
     ../<repo-name>-01-inject-lab-results  → branch feat/01-inject-lab-results
     ../<repo-name>-02-add-redis-cache     → branch feat/02-add-redis-cache
     ../<repo-name>-03-supplements         → branch feat/03-supplements

   Each worktree:
   - Shares git history with this repo (no full clone)
   - Has independent working files
   - Can run claude/tests/etc independently
   ```

5. Ask user: `[y]es create / [n]o`

6. Create worktrees:
   ```bash
   for each issue:
     git worktree add ../<repo-name>-<issue-id> -b feat/<issue-id>-<slug>
   ```

7. Output for each worktree:
   - Path
   - Suggested commands to start agent there:
     ```bash
     cd <path>
     # In a new terminal/tmux window:
     claude /next-task
     # Or for AFK loop:
     bash scripts/ralph-once.sh
     ```

8. Reminder about cleanup:
   - "When done, merge branches and remove worktrees with `/git-worktree-clean` or `git worktree remove <path>`."

Rules:
- NEVER create worktree for an issue that has active blockers
- Default to 3 worktrees max — too many parallel agents = merge conflict hell
- Always check disk space first (`df -h`) — worktrees aren't tiny
- Don't create worktree inside the current repo dir (creates recursion mess)
- Skip if repo has untracked migrations or other "must run together" state
