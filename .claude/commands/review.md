---
description: "Run the reviewer sub-agent on current changes. Operates in isolated context."
---

Spawn the `reviewer` sub-agent on the current branch's changes.

Pass to it:
- Output of `git diff main --stat`
- Output of `git diff main`
- Path to the relevant issue file in `issues/` (if any)

Wait for its review report and present it to the user.

If there are 🔴 BLOCKERS, do NOT auto-fix them — present them to the user for triage.
