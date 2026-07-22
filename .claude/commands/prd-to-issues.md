---
description: "Break a PRD into vertical-slice kanban issues. Each issue must touch all relevant layers."
---

Apply the `prd-to-issues` skill.

$ARGUMENTS

Remember the critical check: **vertical slices, not horizontal**. Slice #1 must give an end-to-end working result. If you find yourself splitting "all schema first, then all API, then all UI" — that's horizontal, redo it.

Save each issue as `issues/<slug>.md`. Output a summary table with: issue title, type (AFK/human-in-the-loop), blocked_by, estimated size.
