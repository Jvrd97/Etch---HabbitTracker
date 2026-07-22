---
description: "Parse a brain dump into structured grilling sessions. Use after dumping many ideas at once. Saves triage report to brain-dumps/triaged/."
---

Spawn the `triage` sub-agent with the following input:

$ARGUMENTS

The triage agent will:
1. Read the brain dump (from inline text, file path, or last message)
2. Identify discrete concerns
3. Categorize each (PRD, ADR, refactor, etc.)
4. Order them by priority and dependencies
5. Flag friction points (pre-decisions needed, conflicts in the dump)
6. Save report to `brain-dumps/triaged/<date>-<topic>-triage.md`

After triage completes:
- Show the user a SHORT summary (2-3 lines per concern, just title + type + size)
- Print the path to the full triage file
- Ask: "Which concern should we tackle first? Or should we adjust the triage?"

Do NOT auto-start grilling. The user picks the first concern, then runs `/grill-me <concern brief>` separately.

If the user just typed `/triage` with no arguments and there's no obvious dump in context — ask them to paste it or point to a file.
