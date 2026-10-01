#!/usr/bin/env bash
set -euo pipefail

POOL="${POOL:-tank}"
BRANCH="${1:-}"
# PORT="${2:-}" # kept for symmetry with create, but pg_ctl stops via -D

if [ -z "$BRANCH" ]; then
    echo "usage: $0 <branch-name>" >&2
    exit 1
fi

# if fast hangs on uncommitted transactions: swap -m fast for -m immediate
pg_ctl stop -D "/$POOL/$BRANCH" -m fast 2>/dev/null || true
zfs destroy "$POOL/$BRANCH"
