---
description: "Clean up raw voice transcription: fix STT errors, add punctuation, preserve voice. Returns batched questions for uncertain spots. Run BEFORE /triage."
---

Spawn `transcript-cleaner` sub-agent with $ARGUMENTS.

## Input handling

$ARGUMENTS can be:
- **File path** (e.g., `@brain-dumps/raw/2026-05-12-foo.md` or just `brain-dumps/raw/2026-05-12-foo.md`)
- **Inline text** (multi-line paste after command)
- **Empty** — ask user what to clean

For file paths:
- Verify file exists
- Read it fully before invoking agent
- Pass content to agent with explicit "this is from <path>"

For inline text:
- Pass directly to agent
- Ask user for desired output filename if agent doesn't know

## Process

The transcript-cleaner agent runs in isolated context:

1. Reads input fully (Phase 1)
2. Applies confident edits silently (Phase 2)
3. Collects uncertain spots into batched questions (Phase 3)
4. Returns Cleanup Report with provisional cleaned text + question batch (Phase 4)

**Stop here.** Show user the report. Wait for their answers.

After user provides answers:
- Pass answers back to the agent
- Agent applies resolutions and writes final clean file (Phase 5)
- Print one-line confirmation with path

## Pre-flight check

Before calling agent:
- If input file is in `brain-dumps/raw/` — output goes to `brain-dumps/<same-name>.md`
- If input is elsewhere — output to `<dir>/<basename>.cleaned.md`
- If inline text — ask user for output path before agent runs

## When NOT to use this

- Text is already clean (no STT artifacts) — just use it directly with `/triage`
- Need restructuring into concerns — that's `/triage`, not cleanup
- Just want to format markdown — different task
- Want to translate / summarize — different task

If user invokes `/cleanup` on already-clean text, agent should say so and exit early ("This already looks clean, no edits needed. Proceed to /triage.").

## Recommended pipeline position

```
1. Voice recording → STT (Whisper, MacWhisper, etc.)
2. Save raw transcript to brain-dumps/raw/<date>-<topic>.md
3. /cleanup brain-dumps/raw/<date>-<topic>.md   ← THIS COMMAND
4. /triage brain-dumps/<date>-<topic>.md
5. /grill-me or /grill-me-arch per concern
```

Don't skip step 3 if transcript has obvious STT artifacts — triage will struggle parsing noise.
