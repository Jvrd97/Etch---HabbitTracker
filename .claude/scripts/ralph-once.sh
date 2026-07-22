#!/usr/bin/env bash
# ralph-once.sh
# Single iteration of the AFK loop. Picks one AFK issue, implements it, exits.
# Run this manually first (many times) to validate the prompt before looping.
#
# Usage: bash scripts/ralph-once.sh
# Env:
#   RALPH_MAX_TURNS  — max conversation turns (default: 50)
#   RALPH_MODEL      — model override (default: project default)

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [[ ! -d "issues" ]]; then
  echo "No issues/ directory. Create issues first via /prd-to-issues."
  exit 1
fi

# Count remaining AFK issues
AFK_COUNT=$(grep -l "Type: AFK" issues/*.md 2>/dev/null | grep -v "/closed/" | wc -l | tr -d ' ')

if [[ "$AFK_COUNT" -eq 0 ]]; then
  echo "NO MORE AFK TASKS"
  exit 0
fi

echo "AFK issues remaining: $AFK_COUNT"
echo "Starting Claude with /next-task ..."

# Run Claude with tight permissions for AFK mode
claude \
  --permission-mode acceptEdits \
  --max-turns "${RALPH_MAX_TURNS:-50}" \
  ${RALPH_MODEL:+--model "$RALPH_MODEL"} \
  "/next-task"

echo "Iteration complete."
