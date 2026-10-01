#!/usr/bin/env bash
set -euo pipefail

POOL="${POOL:-tank}"
SNAPSHOT="${1:-}"
BRANCH="${2:-}"
PORT="${3:-5433}"
SANITIZE_SQL="$(dirname "$0")/sanitize.sql"

if [ -z "$SNAPSHOT" ] || [ -z "$BRANCH" ]; then
    echo "usage: $0 <snapshot> <branch-name> [port]" >&2
    echo "  e.g. $0 pgdata@nightly mybranch 5433" >&2
    exit 1
fi

zfs clone "$POOL/$SNAPSHOT" "$POOL/$BRANCH"
rm -f "/$POOL/$BRANCH/postmaster.pid"

sudo -u postgres pg_ctl start \
    -D "/$POOL/$BRANCH" \
    -o "-p $PORT -c archive_mode=off" \
    -w

psql -p "$PORT" -U postgres postgres -f "$SANITIZE_SQL"

echo "branch $BRANCH running on port $PORT"
