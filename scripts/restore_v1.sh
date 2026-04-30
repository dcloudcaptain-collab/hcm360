#!/bin/bash
# ================================================================
# HCM360 v1.0 — Database Restore Script
# Usage: ./scripts/restore_v1.sh [dump_file]
# Default: backups/hcm360_v1.0_20260412.dump
# ================================================================
set -e

DUMP_FILE="${1:-backups/hcm360_v1.0_20260412.dump}"
CONTAINER="hris_db"
DB_NAME="hris_db"
DB_USER="hris_admin"

if [ ! -f "$DUMP_FILE" ]; then
  echo "ERROR: Dump file not found: $DUMP_FILE"
  exit 1
fi

echo "=== HCM360 v1.0 Database Restore ==="
echo "Source: $DUMP_FILE"
echo "Target: $CONTAINER / $DB_NAME"
echo ""
read -p "This will REPLACE all data in $DB_NAME. Continue? [y/N] " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Aborted."
  exit 0
fi

echo "Copying dump into container..."
docker cp "$DUMP_FILE" "$CONTAINER:/tmp/restore.dump"

echo "Dropping and recreating database..."
docker exec "$CONTAINER" psql -U "$DB_USER" -d postgres -c "
  SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();
"
docker exec "$CONTAINER" dropdb -U "$DB_USER" --if-exists "$DB_NAME"
docker exec "$CONTAINER" createdb -U "$DB_USER" "$DB_NAME"

echo "Restoring from dump..."
docker exec "$CONTAINER" pg_restore -U "$DB_USER" -d "$DB_NAME" --no-owner --no-privileges /tmp/restore.dump

echo "Cleaning up..."
docker exec "$CONTAINER" rm /tmp/restore.dump

echo ""
echo "=== Restore complete ==="
echo "Restart containers: docker compose restart"
