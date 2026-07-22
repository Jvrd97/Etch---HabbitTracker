#!/usr/bin/env bash
# ralph-loop.sh
# Loops ralph-once.sh until either:
#   - No more AFK issues
#   - MAX_ITERATIONS reached
#   - Feedback loops have been failing for N iterations
#
# Safety: do NOT run this until you've validated ralph-once.sh manually.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

MAX_ITERATIONS="${MAX_ITERATIONS:-20}"
SLEEP_SECONDS="${SLEEP_SECONDS:-30}"
LOG_DIR=".claude/logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/ralph-loop-$(date -u +%Y%m%dT%H%M%SZ).log"

echo "Starting Ralph loop. Max iterations: $MAX_ITERATIONS"
echo "Logging to: $LOG_FILE"
echo ""

CONSECUTIVE_FAILURES=0
MAX_CONSECUTIVE_FAILURES=2

for ((i=1; i<=MAX_ITERATIONS; i++)); do
  echo "=== Iteration $i/$MAX_ITERATIONS at $(date -u +%FT%TZ) ===" | tee -a "$LOG_FILE"

  # Run one iteration
  if ! bash scripts/ralph-once.sh 2>&1 | tee -a "$LOG_FILE"; then
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    echo "Iteration $i failed. Consecutive failures: $CONSECUTIVE_FAILURES"

    if [[ "$CONSECUTIVE_FAILURES" -ge "$MAX_CONSECUTIVE_FAILURES" ]]; then
      echo "Stopping: $MAX_CONSECUTIVE_FAILURES consecutive failures." | tee -a "$LOG_FILE"
      exit 1
    fi
  else
    CONSECUTIVE_FAILURES=0
  fi

  # Check if "NO MORE AFK TASKS" was emitted
  if grep -q "NO MORE AFK TASKS" "$LOG_FILE"; then
    echo "All AFK tasks complete. Exiting." | tee -a "$LOG_FILE"
    exit 0
  fi

  echo "Sleeping ${SLEEP_SECONDS}s before next iteration..."
  sleep "$SLEEP_SECONDS"
done

echo "Reached max iterations ($MAX_ITERATIONS). Stopping."
