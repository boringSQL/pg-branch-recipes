#!/usr/bin/env bash
# Creates file-backed ZFS pool. No spare device needed.
# For CI runners or dev machines without dedicated disk.
set -euo pipefail

POOL="${POOL:-tank}"
IMAGE="${IMAGE:-/zfs.img}"
SIZE="${SIZE:-20G}"
PGDATA="${PGDATA:-/var/lib/postgresql/data}"

apt-get install -y zfsutils-linux

truncate -s "$SIZE" "$IMAGE"
zpool create -f "$POOL" "$IMAGE"
zfs set recordsize=8K "$POOL"

# Enable block cloning. Disabled in ZFS 2.2.1 after data-corruption bugs
# and stayed off through the whole 2.2.x series (Ubuntu 24.04). Back on
# by default in OpenZFS 2.3+. Without this FILE_COPY "works" but copies
# bytes: 3.3s and +468MiB instead of 0.56s and +0 on a 6GB database.
echo 1 | tee /sys/module/zfs/parameters/zfs_bclone_enabled
echo "options zfs zfs_bclone_enabled=1" | tee /etc/modprobe.d/zfs.conf

echo "pool $POOL ready at /$POOL"
echo "move your PGDATA to /$POOL/pgdata or take a snapshot of existing:"
echo "  zfs create $POOL/pgdata"
echo "  rsync -a $PGDATA/ /$POOL/pgdata/"
