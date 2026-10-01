-- Run once to create the template database.
-- After this, refresh-template.sh handles nightly reloads.

CREATE DATABASE app_template;

-- Load your data here, e.g.:
-- \! pg_restore -d app_template /path/to/dump.dump

-- Run masking SQL here before freezing:
-- UPDATE app_template.users SET email = 'masked_' || id || '@example.com';

ALTER DATABASE app_template IS_TEMPLATE true;
ALTER DATABASE app_template ALLOW_CONNECTIONS false;

-- ALLOW_CONNECTIONS false blocks new connections. Sessions already
-- attached stay attached.
-- Masking runs in the refresh job, not here.

-- The zero-sessions rule exists because I once patched this error down to
-- a warning. The clone shares the cluster-wide pg_xact commit log, so a
-- transaction committing after the copy makes rows appear in the clone
-- that nobody wrote. The patch deserved to die. If you need a live
-- source, that's what level2-zfs/ is for.
