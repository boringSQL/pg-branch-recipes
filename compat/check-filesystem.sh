#!/usr/bin/env bash
# Check filesystem support for Level 1 (reflinks) and Level 2 (snapshots).

PGDATA="${PGDATA:-/var/lib/postgresql/data}"

if [ "$(uname)" = "Darwin" ]; then
    # macOS df has no -T; ask diskutil instead
    fs=$(diskutil info "$PGDATA" 2>/dev/null | awk '/File System Personality/{print tolower($NF)}')
else
    fs=$(df -T "$PGDATA" 2>/dev/null | awk 'NR==2{print $2}')
fi
echo "filesystem: $fs"

case "$fs" in
    xfs)
        echo "Level 1 reflinks: supported"
        echo "Level 2 ZFS snapshot: not available (not ZFS)"
        echo "Level 2 reflink replica: supported (cp --reflink=always)"
        ;;
    zfs)
        bclone=$(cat /sys/module/zfs/parameters/zfs_bclone_enabled 2>/dev/null || echo "unknown")
        echo "Level 1 reflinks: supported (zfs_bclone_enabled=$bclone)"
        if [ "$bclone" = "0" ]; then
            echo "  WARNING: block cloning disabled, FILE_COPY will be slow"
            echo "  Fix: echo 1 | sudo tee /sys/module/zfs/parameters/zfs_bclone_enabled"
        fi
        echo "Level 2 ZFS snapshot: supported"
        echo "Level 2 reflink replica: supported"
        ;;
    btrfs)
        echo "Level 1 reflinks: supported"
        echo "Level 2 ZFS snapshot: not available (not ZFS)"
        echo "Level 2 reflink replica: supported (cp --reflink=always)"
        ;;
    apfs)
        echo "Level 1 reflinks: supported (macOS)"
        echo "Level 2 ZFS snapshot: not available"
        echo "Level 2 reflink replica: supported"
        ;;
    ext4)
        echo "Level 1 reflinks: NOT supported"
        echo "Level 2 ZFS snapshot: not available (not ZFS)"
        echo "Level 2 reflink replica: NOT supported"
        echo ""
        echo "Options: move PGDATA to XFS/ZFS volume, or use Neon/Xata."
        ;;
    *)
        echo "unknown filesystem: $fs, cannot determine support"
        ;;
esac
