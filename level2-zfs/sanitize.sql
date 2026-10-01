-- Run on branch immediately after startup, before any other connection.
-- Branch inherits all settings from source, including archive destination.
-- It boots on the same timeline as production and generates identically
-- named WAL segments. I caught mine two segments into overwriting the
-- production archive. archive_mode=off is a must-have.

ALTER SYSTEM SET archive_mode = off;
ALTER SYSTEM SET synchronous_standby_names = '';
ALTER SYSTEM RESET cron.database_name;
SELECT pg_drop_replication_slot(slot_name) FROM pg_replication_slots;
SELECT pg_reload_conf();
