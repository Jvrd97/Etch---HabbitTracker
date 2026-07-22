#!/usr/bin/env bash
# [review:need-review] PHASE-01/02-deploy-vps-tailscale
# summary: daily pg_dump of habit_tracker DB, keeps last 30 dumps
# Cron example: 0 3 * * * /opt/habit-tracker/deploy/backup.sh >> /var/log/habit-backup.log 2>&1
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/habit-tracker/backups}"
KEEP=30

mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y-%m-%d_%H%M%S)"
docker exec habit_postgres pg_dump -U habit_user habit_tracker | gzip > "$BACKUP_DIR/habit_tracker_$STAMP.sql.gz"

# prune old dumps beyond KEEP
ls -1t "$BACKUP_DIR"/habit_tracker_*.sql.gz | tail -n +$((KEEP + 1)) | xargs -r rm --
echo "backup done: $BACKUP_DIR/habit_tracker_$STAMP.sql.gz"
