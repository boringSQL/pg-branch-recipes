#!/usr/bin/env bash
set -euo pipefail

REPLICA_HOST="${REPLICA_HOST:-replica}"
REPLICA_DATA="${REPLICA_DATA:-/mnt/xfs/replica}"
BRANCH_DATA="${1:-/mnt/xfs/branch}"
PORT="${2:-5436}"
SANITIZE_SQL="$(dirname "$0")/../level2-zfs/sanitize.sql"

if [ -z "$BRANCH_DATA" ]; then
    echo "usage: $0 <branch-path> [port]" >&2
    exit 1
fi

if [ -e "$BRANCH_DATA" ]; then
    echo "$BRANCH_DATA already exists; cp would nest inside it" >&2
    exit 1
fi

# Pause replay and wait for confirmed pause before checkpoint.
# If anything fails below, don't leave the replica paused forever.
resume_replay() {
    psql -h "$REPLICA_HOST" -U postgres -c "SELECT pg_wal_replay_resume();" >/dev/null 2>&1 || true
}
trap resume_replay ERR

psql -h "$REPLICA_HOST" -U postgres -c "SELECT pg_wal_replay_pause();"
until psql -h "$REPLICA_HOST" -U postgres -tAc \
    "SELECT pg_get_wal_replay_pause_state();" | grep -q "^paused$"; do
    sleep 0.1
done
# Replay is paused so no new WAL applies, but dirty pages may still be in
# memory. CHECKPOINT flushes them, or the copy can have half-written pages.
psql -h "$REPLICA_HOST" -U postgres -c "CHECKPOINT;"

# -a not -r: -r silently drops ownership, Postgres then refuses to start.
# Cost me an hour. --reflink=always not =auto: auto silently does a full
# byte-for-byte copy on a 1TB data directory.
cp -a --reflink=always "$REPLICA_DATA" "$BRANCH_DATA"

trap - ERR
resume_replay

rm -f "$BRANCH_DATA/postmaster.pid"
# sed -i on linux; mac sed needs -i '' but this targets linux replicas anyway
sed -i \
    's/^primary_conninfo/#primary_conninfo/;s/^primary_slot_name/#primary_slot_name/' \
    "$BRANCH_DATA/postgresql.auto.conf"

pg_ctl start -D "$BRANCH_DATA" -o "-p $PORT -c archive_mode=off" -w
pg_ctl promote -D "$BRANCH_DATA" -w

psql -p "$PORT" -U postgres postgres -f "$SANITIZE_SQL"

# sanity check during testing:
# psql -p "$PORT" -U postgres -c "SELECT pg_is_in_recovery();"

echo "branch ready on port $PORT"
