-- Historical production fix for app_session_context() when a profile has no city.
-- The corrected function body is intentionally folded into the preceding
-- 20260824023309 migration in source control so a fresh database never passes
-- through the broken record-shape implementation. This version marker is kept
-- to preserve migration-history parity with production.
--
-- The invariant established by this migration is:
--   * cityless/unconfigured users receive configured=false and default features
--   * no PL/pgSQL uninitialized-record access occurs
--   * privileged role membership still resolves exclusively from auth.uid()

select 1;
