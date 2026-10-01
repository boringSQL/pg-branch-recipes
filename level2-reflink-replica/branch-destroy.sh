#!/usr/bin/env bash
set -euo pipefail

BRANCH_DATA="${1:-}"

if [ -z "$BRANCH_DATA" ]; then
    echo "usage: $0 <branch-path>" >&2
    exit 1
fi

pg_ctl stop -D "$BRANCH_DATA" -m fast 2>/dev/null || true
rm -rf "$BRANCH_DATA"

echo "branch $BRANCH_DATA destroyed"
