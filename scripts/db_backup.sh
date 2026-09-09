#!/usr/bin/env bash
#
# db_backup.sh
# Dumps the PostgreSQL database running in the 'postgres_db' container,
# compresses it, and stores it in /var/backups/db/ with a timestamp.
#
# Output file: /var/backups/db/db_backup_YYYYMMDD.sql.gz
# (If run more than once a day, add %H%M for uniqueness — see note below.)
#
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-postgres_db}"
DB_NAME="${POSTGRES_DB:-appdb}"
DB_USER="${POSTGRES_USER:-appuser}"
BACKUP_DIR="/var/backups/db"
DATE_STAMP="$(date '+%Y%m%d')"
BACKUP_FILE="${BACKUP_DIR}/db_backup_${DATE_STAMP}.sql.gz"
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

echo "[INFO] Starting backup of database '${DB_NAME}' from container '${DB_CONTAINER}'..."

# pg_dump inside the container, compress on the way out
docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"

if [ -s "$BACKUP_FILE" ]; then
    echo "[INFO] Backup successful: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
else
    echo "[ERROR] Backup file is empty or was not created." >&2
    rm -f "$BACKUP_FILE"
    exit 1
fi

# ---- Retention: delete backups older than RETENTION_DAYS ----
echo "[INFO] Removing backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -name "db_backup_*.sql.gz" -mtime "+${RETENTION_DAYS}" -exec rm -v {} \;

echo "[INFO] Backup process complete."

# -----------------------------------------------------------------
# RESTORE PROCEDURE (documented per assignment requirement, also in README.md):
#
#   1. Decompress the archive:
#        gunzip -k db_backup_YYYYMMDD.sql.gz
#
#   2. Copy the .sql file into the running db container (or restore directly via pipe):
#        gunzip -c db_backup_YYYYMMDD.sql.gz | docker exec -i postgres_db \
#            psql -U appuser -d appdb
#
#      (If restoring into a fresh/empty database, create it first:
#        docker exec -it postgres_db createdb -U appuser appdb)
#
#   3. Verify:
#        docker exec -it postgres_db psql -U appuser -d appdb -c '\dt'
# -----------------------------------------------------------------
