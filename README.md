# pg-branch-recipes

Companion repo for my talk **DIY Database Branching** and the
[boringsql.com](https://boringsql.com) article on instant clones in
PostgreSQL 18. Everything here I've run myself.

> **Warning:** talk material, not a product. These scripts snapshot,
> clone and delete Postgres data directories, mostly without asking.
> I run them on machines I own and still read them first. Don't point
> them at data you can't lose; if you do, the `zfs destroy` in
> `branch-destroy.sh` won't save you.

There are two ways to clone a PostgreSQL database, and the industry
picked one.

- **Level 1: database-level.** `CREATE DATABASE ... TEMPLATE ... STRATEGY=FILE_COPY`.
  One database cloned inside a running cluster. ~200ms on PostgreSQL 18
  with `file_copy_method = clone`. The source needs zero sessions, not
  zero queries: one idle pool connection is enough to fail. I tried to
  patch the check out; the patch deserved to die. The clone shares the
  cluster-wide `pg_xact` commit log, so a transaction committing *after*
  the copy makes rows appear in the clone that nobody wrote. That's why
  Level 2 exists.
- **Level 2: cluster-level.** Snapshot the whole data directory, start a
  new Postgres per branch. Works on a live source, any version, since
  about 2005. Neon, Xata and DbLab all do this. They don't get around
  the zero-sessions rule either; they work below it.

## Recipes

| Your situation | Recipe |
|---|---|
| CI test isolation, you own the box | `level1-template/` |
| Branch a live database, you have ZFS | `level2-zfs/` |
| Branch a live database, XFS/Btrfs replica | `level2-reflink-replica/` |
| RDS / Cloud SQL (no filesystem access) | None of these work. That's what managed vendors sell. |

Not sure what your filesystem can do:

```bash
./compat/check-filesystem.sh
```

## Gotchas

The scripts handle these. If you write your own, don't skip the list.

- **`archive_mode=off` is a must-have.** A branch of production boots up
  believing it *is* production: same timeline, same archive destination.
  It generates identically named WAL segments and ships them over your
  production archive. I caught mine after two segments. Every recipe here
  starts the branch with `-c archive_mode=off` and then runs
  `level2-zfs/sanitize.sql`.
- **Delete `postmaster.pid`** before starting a cloned data directory, or
  Postgres refuses to start.
- **`cp -a`, not `cp -r`.** `-r` silently drops file ownership; Postgres
  checks that it owns its data directory and won't start. Burned an hour
  on this.
- **`--reflink=always`, not `--reflink=auto`.** `auto` silently falls back
  to a full byte-for-byte copy. `always` fails loudly.
- **ZFS block cloning is off on Ubuntu 24.04** (ZFS 2.2.x, disabled after
  data-corruption bugs; back on by default in OpenZFS 2.3). Without it
  FILE_COPY "works" but copies bytes: 3.3s and +468MiB instead of 0.56s
  and +0. `level2-zfs/setup-pool.sh` flips it.
- **Masking goes in the refresh job, not the template.** A clone lands on
  a CI runner in 200ms. `ALTER DATABASE ... ALLOW_CONNECTIONS false`
  blocks new connections but leaves attached sessions running.

## Numbers

Measured on my machines:

| What | Before | After |
|---|---|---|
| `CREATE DATABASE` on 6GB, WAL_LOG → FILE_COPY+clone | 67s | 212ms |
| FILE_COPY on ZFS, bclone off → on | 3.3s, +468MiB | 0.56s, +0 |
| Reflink branch of 1,025MB data dir | n/a | +1MB disk |
| 500 isolated tests × 212ms clone | n/a | ~2min total overhead |

## Layout

```
compat/                 filesystem capability check
level1-template/        template DB + pytest fixture for per-test clones
level2-zfs/             pool setup, branch create/destroy, CI workflow
level2-reflink-replica/ pause replica, reflink copy, promote
```

It's plain bash and SQL: no framework to install, nothing to
authenticate. Read the scripts first; they touch Postgres and ZFS as
root.

## Links

TBD 


## License

BSD 2-Clause, see [LICENSE](LICENSE).
