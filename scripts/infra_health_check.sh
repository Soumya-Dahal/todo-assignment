#!/usr/bin/env bash
#
# infra_health_check.sh
# Checks CPU / RAM / disk usage and Docker + app container status.
# Logs a [WARNING] to /var/log/infra_health.log when disk usage > 85%
# or the app container is not running.
#
# Intended location: /opt/scripts/infra_health_check.sh
# Runs every 15 minutes via cron (see install_cron.sh).
#
set -uo pipefail  # no -e: we want to keep going even if one check fails

LOG_FILE="/var/log/infra_health.log"
DISK_THRESHOLD=85
APP_CONTAINER_NAME="${APP_CONTAINER_NAME:-web_app}"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# Ensure log file exists and is writable (create with sudo on first run)
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE" 2>/dev/null || {
        echo "[ERROR] Cannot write to $LOG_FILE. Run with sudo or fix permissions." >&2
        exit 1
    }
fi

log_warning() {
    local message="$1"
    echo "[WARNING] $message"
    echo "${TIMESTAMP} [WARNING] ${message}" >> "$LOG_FILE"
}

log_info() {
    local message="$1"
    echo "[INFO] $message"
}

# ---- CPU usage (%) ----
# 100 - idle percentage, averaged over a short sample
if command -v mpstat &>/dev/null; then
    CPU_USAGE=$(mpstat 1 1 | awk '/Average/ {print 100 - $NF}')
else
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk -F'id,' '{split($1, a, ","); print 100 - a[length(a)]}' | awk '{print $NF}')
fi
CPU_USAGE=${CPU_USAGE:-0}
log_info "CPU usage: ${CPU_USAGE}%"

# ---- RAM usage (%) ----
RAM_USAGE=$(free | awk '/Mem:/ {printf "%.1f", ($2-$7)/$2 * 100}')
log_info "RAM usage: ${RAM_USAGE}%"

# ---- Root disk usage (%) ----
DISK_USAGE=$(df -h / | awk 'NR==2 {gsub("%","",$5); print $5}')
log_info "Root disk usage: ${DISK_USAGE}%"

if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
    log_warning "Root disk usage is ${DISK_USAGE}%, exceeding threshold of ${DISK_THRESHOLD}%."
fi

# ---- Docker daemon status ----
if command -v docker &>/dev/null && systemctl is-active --quiet docker; then
    log_info "Docker daemon is running."
else
    log_warning "Docker daemon is NOT running."
fi

# ---- App container status ----
if command -v docker &>/dev/null; then
    CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' "$APP_CONTAINER_NAME" 2>/dev/null)
    if [ "$CONTAINER_STATUS" == "running" ]; then
        log_info "App container '${APP_CONTAINER_NAME}' is running."
    else
        log_warning "App container '${APP_CONTAINER_NAME}' is stopped or not found (status: ${CONTAINER_STATUS:-not found})."
    fi
else
    log_warning "Docker command not available; cannot check container '${APP_CONTAINER_NAME}'."
fi

log_info "Health check complete at ${TIMESTAMP}."
exit 0
