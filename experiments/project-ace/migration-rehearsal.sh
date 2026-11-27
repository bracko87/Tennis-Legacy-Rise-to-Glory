#!/usr/bin/env bash
# Dedicated CI review database only. Never connect to Supabase or a restored customer DB.
set -euo pipefail
cd "$(dirname "$0")"
[[ "${ACE_MIGRATION_REHEARSAL:-}" == "disposable-ci-only" ]] || { echo "Missing disposable rehearsal authorization" >&2; exit 1; }
# Explicit connection and sanitized environment; no arbitrary database or host options.
db() {
  env -i PATH="$PATH" PGPASSWORD=ace-disposable-admin PGCONNECT_TIMEOUT=5 PGSSLMODE=disable psql -X -qAt -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 55432 -U postgres -d ace_review "$@"
}
[[ "$(db -c "SELECT current_database() || ':' || current_user")" == "ace_review:postgres" ]] || exit 1
[[ "$(db -c "SELECT marker FROM ace_migration_fixture.guard WHERE singleton")" == "ace-disposable-ci-v025" ]] || { echo "Not a marked rehearsal database" >&2; exit 1; }
files=(
  postgres-review.sql
  cutover-ownership-review.sql
  cutover-settlement-review.sql
  cutover-medical-review.sql
  cutover-admission-review.sql
  cutover-guest-review.sql
  cutover-surrender-review.sql
  cutover-cancellation-review.sql
  cutover-special-closure-review.sql
  cutover-reconciliation-review.sql
  cutover-drain-review.sql
  cutover-source-transaction-review.sql
  cutover-source-readiness-review.sql
  cutover-source-resources-review.sql
  cutover-source-rest-review.sql
  cutover-source-career-review.sql
  cutover-source-exceptions-review.sql
  cutover-source-void-review.sql
  cutover-source-qualification-review.sql
  cutover-source-lifecycle-review.sql
  cutover-pilot-preflight-review.sql
)
bundle="$(mktemp)"
trap 'rm -f "$bundle"' EXIT
cat > "$bundle" <<'SQL'
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
SELECT pg_advisory_xact_lock(250025,1);
DO $$ BEGIN
 IF to_regnamespace('ace_review') IS NOT NULL OR to_regnamespace('ace_cutover_review') IS NOT NULL OR to_regnamespace('ace_migration_journal') IS NOT NULL THEN RAISE EXCEPTION 'review schemas already installed; no implicit reinstallation'; END IF;
END $$;
CREATE SCHEMA ace_migration_journal;
REVOKE ALL ON SCHEMA ace_migration_journal FROM PUBLIC;
CREATE TABLE ace_migration_journal.installed (
 ordinal integer PRIMARY KEY,
 filename text NOT NULL UNIQUE,
 sha256 text NOT NULL CHECK(sha256 ~ '^[0-9a-f]{64}$')
);
SQL
i=0
for f in "${files[@]}"; do
  # Only strip the exact outer transaction delimiters, not procedural BEGIN blocks.
  [[ "$(grep -c '^BEGIN;$' "$f")" == 1 && "$(grep -c '^COMMIT;$' "$f")" == 1 ]] || { echo "Unexpected transaction wrapper: $f" >&2; exit 1; }
  [[ "$(grep -E '^(BEGIN|COMMIT);$' "$f" | paste -sd ' ' -)" == "BEGIN; COMMIT;" ]] || exit 1
  hash="$(sha256sum "$f" | cut -d ' ' -f1)"
  ((i+=1))
  sed -e '/^BEGIN;$/d' -e '/^COMMIT;$/d' "$f" >> "$bundle"
  printf "\nINSERT INTO ace_migration_journal.installed VALUES (%s,'%s','%s');\n" "$i" "$f" "$hash" >> "$bundle"
done
case "${1:-}" in
  inject-failure)
    echo "DO \$\$ BEGIN RAISE EXCEPTION 'ACE_REHEARSAL_INJECTED_FAILURE'; END \$\$;" >> "$bundle"
    ;;
  install) ;;
  *) echo "Expected install or inject-failure" >&2; exit 1 ;;
esac
echo 'COMMIT;' >> "$bundle"
db -f "$bundle"
