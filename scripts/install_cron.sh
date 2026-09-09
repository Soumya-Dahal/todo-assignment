#!/usr/bin/env bash
#
# install_cron.sh
# Installs the two cron jobs required by the assignment:
#   1. infra_health_check.sh   -> every 15 minutes
#   2. db_backup.sh            -> once daily at 02:00
#
# Run as root (or the user that should own these cron jobs, with sudo rights
# to write to /opt/scripts, /var/log, /var/backups).
#
set -euo pipefail

SCRIPT_DIR="/opt/scripts"
HEALTH_SCRIPT="${SCRIPT_DIR}/infra_health_check.sh"
BACKUP_SCRIPT="${SCRIPT_DIR}/db_backup.sh"

mkdir -p "$SCRIPT_DIR"
mkdir -p /var/backups/db
touch /var/log/infra_health.log

echo "[INFO] Copying scripts to $SCRIPT_DIR ..."
cp "$(dirname "$0")/infra_health_check.sh" "$HEALTH_SCRIPT"
cp "$(dirname "$0")/db_backup.sh" "$BACKUP_SCRIPT"
chmod +x "$HEALTH_SCRIPT" "$BACKUP_SCRIPT"

CRON_MARKER="# infra_health_check + db_backup (installed by install_cron.sh)"
CRON_HEALTH="*/15 * * * * ${HEALTH_SCRIPT} >> /var/log/infra_health_cron.log 2>&1"
CRON_BACKUP="0 2 * * * ${BACKUP_SCRIPT} >> /var/log/db_backup_cron.log 2>&1"

TMP_CRON="$(mktemp)"
crontab -l 2>/dev/null | grep -v -F "$HEALTH_SCRIPT" | grep -v -F "$BACKUP_SCRIPT" | grep -v -F "$CRON_MARKER" > "$TMP_CRON" || true

{
    echo "$CRON_MARKER"
    echo "$CRON_HEALTH"
    echo "$CRON_BACKUP"
} >> "$TMP_CRON"

crontab "$TMP_CRON"
rm -f "$TMP_CRON"

echo "[INFO] Cron jobs installed. Current crontab:"
crontab -l
