-- Run this on PostgreSQL as a superuser or admin user.
-- Replace CHANGE_ME with a strong password.

CREATE USER postgres_exporter WITH PASSWORD 'postgres';

GRANT pg_monitor TO postgres_exporter;

-- Optional for older PostgreSQL versions if pg_monitor is unavailable:
-- GRANT SELECT ON pg_stat_database TO postgres_exporter;
-- GRANT SELECT ON pg_stat_bgwriter TO postgres_exporter;
