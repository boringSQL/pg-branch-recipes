#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DB="${TEMPLATE_DB:-app_template}"
SOURCE_DUMP="${SOURCE_DUMP:-/var/backups/app_latest.dump}"
ADMIN_DSN="${ADMIN_DSN:-postgresql://postgres@localhost/postgres}"
TEMPLATE_DSN="${TEMPLATE_DSN:-postgresql://postgres@localhost/$TEMPLATE_DB}"
MASK_SQL="${MASK_SQL:-}"

# if ALTER fails with "source database is being accessed by other users":
# psql "$ADMIN_DSN" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$TEMPLATE_DB';"

psql "$ADMIN_DSN" -c "ALTER DATABASE $TEMPLATE_DB IS_TEMPLATE false;" 2>/dev/null || true
psql "$ADMIN_DSN" -c "DROP DATABASE IF EXISTS $TEMPLATE_DB WITH (FORCE);"
psql "$ADMIN_DSN" -c "CREATE DATABASE $TEMPLATE_DB;"

pg_restore --no-owner --no-acl -d "$TEMPLATE_DSN" "$SOURCE_DUMP"

if [ -n "$MASK_SQL" ]; then
    psql "$TEMPLATE_DSN" -f "$MASK_SQL"
fi

psql "$ADMIN_DSN" -c "ALTER DATABASE $TEMPLATE_DB IS_TEMPLATE true;"
psql "$ADMIN_DSN" -c "ALTER DATABASE $TEMPLATE_DB ALLOW_CONNECTIONS false;"

# echo "refreshed in $((SECONDS))s"
