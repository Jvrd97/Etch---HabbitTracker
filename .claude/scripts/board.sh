#!/usr/bin/env bash
# board.sh
# Visualizes the kanban state by parsing markdown issue files.
#
# Reads:
#   issues/*.md          — active tickets
#   issues/closed/*.md   — done tickets
#
# Each ticket file should have at the top:
#   **Type**: AFK | human-in-the-loop | quick-win
#   **Blocked by**: <comma-separated names or 'none'>
#   **Estimated**: S | M | L
#
# Usage:
#   bash scripts/board.sh           # full board view
#   bash scripts/board.sh --next    # just next available task
#   bash scripts/board.sh --json    # machine-readable

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

ISSUES_DIR="issues"
CLOSED_DIR="issues/closed"

if [[ ! -d "$ISSUES_DIR" ]]; then
  echo "No issues/ directory found. Run /prd-to-issues first."
  exit 1
fi

# Colors (disabled if not a TTY)
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'
  CYAN=$'\033[0;36m'
  GRAY=$'\033[0;90m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  RED="" GREEN="" YELLOW="" BLUE="" CYAN="" GRAY="" BOLD="" RESET=""
fi

# Parse a single issue file → outputs one line: "filename|title|type|blocked_by|estimated"
parse_issue() {
  local file="$1"
  local title type blocked_by estimated

  # Title from first heading
  title=$(grep -m1 "^# " "$file" 2>/dev/null | sed 's/^# //' || echo "(no title)")

  # Fields from bold-prefixed lines
  type=$(grep -m1 "^\*\*Type\*\*:" "$file" 2>/dev/null | sed 's/^\*\*Type\*\*:\s*//' | xargs || echo "?")
  blocked_by=$(grep -m1 "^\*\*Blocked by\*\*:" "$file" 2>/dev/null | sed 's/^\*\*Blocked by\*\*:\s*//' | xargs || echo "none")
  estimated=$(grep -m1 "^\*\*Estimated\*\*:" "$file" 2>/dev/null | sed 's/^\*\*Estimated\*\*:\s*//' | xargs | awk '{print $1}' || echo "?")

  echo "$(basename "$file" .md)|$title|$type|$blocked_by|$estimated"
}

# Check if all blockers are in closed/
is_unblocked() {
  local blocked_by="$1"
  if [[ "$blocked_by" == "none" || -z "$blocked_by" ]]; then
    return 0
  fi

  IFS=',' read -ra blockers <<< "$blocked_by"
  for blocker in "${blockers[@]}"; do
    blocker=$(echo "$blocker" | xargs)  # trim
    # Match by prefix (e.g., "01-inject-lab-results" matches "01-...")
    local id="${blocker%%-*}"
    if ! ls "$CLOSED_DIR"/${id}-*.md 2>/dev/null | grep -q .; then
      return 1
    fi
  done
  return 0
}

# Type icon
type_icon() {
  case "$1" in
    AFK) echo "🤖" ;;
    human-in-the-loop) echo "👤" ;;
    quick-win) echo "⚡" ;;
    *) echo "❓" ;;
  esac
}

# JSON mode
if [[ "${1:-}" == "--json" ]]; then
  echo "["
  first=1
  for f in "$ISSUES_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    [[ "$(basename "$f")" == PRD-* ]] && continue
    line=$(parse_issue "$f")
    IFS='|' read -r name title type blocked estimated <<< "$line"
    [[ $first -eq 0 ]] && echo ","
    first=0
    if is_unblocked "$blocked"; then status="available"; else status="blocked"; fi
    printf '  {"name":"%s","title":"%s","type":"%s","blocked_by":"%s","estimated":"%s","status":"%s"}' \
      "$name" "$title" "$type" "$blocked" "$estimated" "$status"
  done
  echo ""
  echo "]"
  exit 0
fi

# Collect tickets
AVAILABLE=()
BLOCKED=()
DONE=()
PRDS=()

for f in "$ISSUES_DIR"/*.md; do
  [[ -f "$f" ]] || continue
  basename=$(basename "$f")
  if [[ "$basename" == PRD-* ]]; then
    PRDS+=("$f")
    continue
  fi

  line=$(parse_issue "$f")
  IFS='|' read -r name title type blocked estimated <<< "$line"

  if is_unblocked "$blocked"; then
    AVAILABLE+=("$line")
  else
    BLOCKED+=("$line")
  fi
done

if [[ -d "$CLOSED_DIR" ]]; then
  for f in "$CLOSED_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    line=$(parse_issue "$f")
    DONE+=("$line")
  done
fi

# --next mode: just print the next AFK task ID
if [[ "${1:-}" == "--next" ]]; then
  for line in "${AVAILABLE[@]}"; do
    IFS='|' read -r name title type _ _ <<< "$line"
    if [[ "$type" == "AFK" ]]; then
      echo "$name"
      exit 0
    fi
  done
  echo "NO_AFK_AVAILABLE"
  exit 0
fi

# Pretty board
echo ""
echo "${BOLD}═══════════════════════ KANBAN BOARD ═══════════════════════${RESET}"
echo ""

# PRDs
if [[ ${#PRDS[@]} -gt 0 ]]; then
  echo "${GRAY}📋 PRDs:${RESET}"
  for f in "${PRDS[@]}"; do
    title=$(grep -m1 "^# " "$f" | sed 's/^# //')
    echo "   ${GRAY}$(basename "$f"): $title${RESET}"
  done
  echo ""
fi

# AVAILABLE
echo "${GREEN}${BOLD}✅ AVAILABLE (${#AVAILABLE[@]})${RESET}"
echo "${GRAY}─────────────────────────────────────────────────────────────${RESET}"
if [[ ${#AVAILABLE[@]} -eq 0 ]]; then
  echo "   ${GRAY}(none — either no issues or all blocked)${RESET}"
else
  for line in "${AVAILABLE[@]}"; do
    IFS='|' read -r name title type blocked estimated <<< "$line"
    icon=$(type_icon "$type")
    echo "   $icon ${BOLD}$name${RESET} [$estimated]"
    echo "      ${title}"
  done
fi
echo ""

# BLOCKED
echo "${YELLOW}${BOLD}🔒 BLOCKED (${#BLOCKED[@]})${RESET}"
echo "${GRAY}─────────────────────────────────────────────────────────────${RESET}"
if [[ ${#BLOCKED[@]} -eq 0 ]]; then
  echo "   ${GRAY}(none)${RESET}"
else
  for line in "${BLOCKED[@]}"; do
    IFS='|' read -r name title type blocked estimated <<< "$line"
    icon=$(type_icon "$type")
    echo "   $icon ${name} [$estimated]"
    echo "      ${title}"
    echo "      ${YELLOW}↑ blocked by: $blocked${RESET}"
  done
fi
echo ""

# DONE (compact)
echo "${BLUE}${BOLD}✓ DONE (${#DONE[@]})${RESET}"
echo "${GRAY}─────────────────────────────────────────────────────────────${RESET}"
if [[ ${#DONE[@]} -eq 0 ]]; then
  echo "   ${GRAY}(none yet)${RESET}"
else
  for line in "${DONE[@]}"; do
    IFS='|' read -r name title _ _ _ <<< "$line"
    echo "   ${GRAY}✓ $name — $title${RESET}"
  done
fi
echo ""

# Summary
TOTAL=$(( ${#AVAILABLE[@]} + ${#BLOCKED[@]} + ${#DONE[@]} ))
if [[ $TOTAL -gt 0 ]]; then
  PCT=$(( ${#DONE[@]} * 100 / TOTAL ))
  echo "${BOLD}Progress: ${#DONE[@]}/$TOTAL (${PCT}%)${RESET}"
fi

# AFK availability
AFK_AVAILABLE=0
for line in "${AVAILABLE[@]}"; do
  IFS='|' read -r _ _ type _ _ <<< "$line"
  [[ "$type" == "AFK" ]] && AFK_AVAILABLE=$((AFK_AVAILABLE + 1))
done

if [[ $AFK_AVAILABLE -gt 0 ]]; then
  echo "${CYAN}🤖 $AFK_AVAILABLE AFK task(s) ready — run /next-task or bash scripts/ralph-once.sh${RESET}"
else
  HUMAN_AVAILABLE=0
  for line in "${AVAILABLE[@]}"; do
    IFS='|' read -r _ _ type _ _ <<< "$line"
    [[ "$type" == "human-in-the-loop" ]] && HUMAN_AVAILABLE=$((HUMAN_AVAILABLE + 1))
  done
  if [[ $HUMAN_AVAILABLE -gt 0 ]]; then
    echo "${YELLOW}👤 No AFK tasks available, but $HUMAN_AVAILABLE human-in-the-loop task(s) ready${RESET}"
  fi
fi
echo ""
