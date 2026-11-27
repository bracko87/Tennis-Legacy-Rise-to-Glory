#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[[ "${ACE_MIGRATION_REHEARSAL:-}" == "disposable-ci-only" ]] || exit 1
admin() { env -i PATH="$PATH" PGPASSWORD=ace-disposable-admin PGCONNECT_TIMEOUT=5 PGSSLMODE=disable "$@"; }
sql() { local database="$1"; shift; admin psql -X -qAt -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 55432 -U postgres -d "$database" "$@"; }
engine() { env -i PATH="$PATH" PGPASSWORD=ace-disposable-ace PGCONNECT_TIMEOUT=5 PGSSLMODE=disable psql -X -qAt -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 55432 -U ace_cutover_ace -d ace_review_recovery -c "$1"; }
[[ "$(sql ace_review -c 'SELECT marker FROM ace_migration_fixture.guard WHERE singleton')" == "ace-disposable-ci-v025" ]] || exit 1
[[ "$(sql ace_review -c "SELECT count(*) FROM pg_database WHERE datname='ace_review_recovery'")" == 0 ]] || { echo 'Refusing existing recovery target'; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
sql ace_review -f recovery-fingerprint.sql > "$tmp/source-before"
if [[ -n "${ACE_REVIEW_CONTAINER:-}" ]]; then
  [[ "${GITHUB_ACTIONS:-}" == true && "$ACE_REVIEW_CONTAINER" =~ ^[a-f0-9]{64}$ ]] || exit 1
  [[ "$(docker exec -e PGPASSWORD=ace-disposable-admin "$ACE_REVIEW_CONTAINER" psql -X -qAt -h 127.0.0.1 -U postgres -d ace_review -c 'SELECT marker FROM ace_migration_fixture.guard WHERE singleton')" == ace-disposable-ci-v025 ]] || exit 1
  docker exec -e PGPASSWORD=ace-disposable-admin "$ACE_REVIEW_CONTAINER" pg_dump -h 127.0.0.1 -U postgres -d ace_review --format=custom > "$tmp/review.dump"
else
  admin pg_dump -h 127.0.0.1 -p 55432 -U postgres -d ace_review --format=custom --file="$tmp/review.dump"
fi
sha256sum "$tmp/review.dump"
sql ace_review -c 'CREATE DATABASE ace_review_recovery TEMPLATE template0'
if [[ -n "${ACE_REVIEW_CONTAINER:-}" ]]; then
  docker exec -i -e PGPASSWORD=ace-disposable-admin "$ACE_REVIEW_CONTAINER" pg_restore -h 127.0.0.1 -U postgres -d ace_review_recovery --exit-on-error --single-transaction < "$tmp/review.dump"
else
  admin pg_restore -h 127.0.0.1 -p 55432 -U postgres -d ace_review_recovery --exit-on-error --single-transaction "$tmp/review.dump"
fi
sql ace_review_recovery -f recovery-fingerprint.sql > "$tmp/restored"
diff -u "$tmp/source-before" "$tmp/restored"
[[ "$(sql ace_review_recovery -c "SELECT NOT enabled FROM ace_cutover_review.policy WHERE singleton")" == t ]]
[[ "$(engine "SELECT ace_cutover_review.finish_match('rollback-recovery-live',2,'p1',jsonb_build_object('score','6-4 6-4'))")" == completed ]]
[[ "$(engine "SELECT ace_cutover_review.finish_match('rollback-recovery-live',2,'p1',jsonb_build_object('score','6-4 6-4'))")" == already_completed ]]
[[ "$(engine "SELECT ace_cutover_review.finish_match('rollback-recovery-held',2,'p1','{}'::jsonb)")" == handoff_pending ]]
[[ "$(sql ace_review_recovery -c "SELECT count(*) FROM ace_cutover_review.effects WHERE match_id='rollback-recovery-live'")" == 1 ]]
[[ "$(sql ace_review -c "SELECT count(*) FROM ace_cutover_review.effects WHERE match_id='rollback-recovery-live'")" == 0 ]]
[[ "$(sql ace_review_recovery -c "SELECT ace_cutover_review.drain_status('rollback-recovery-ci')->>'can_retire_review_runtime'")" == false ]]
sql ace_review -f recovery-fingerprint.sql > "$tmp/source-after"
diff -u "$tmp/source-before" "$tmp/source-after"
echo 'PASS disposable dump restore, full review-table fingerprints, routine/trigger/grant fingerprints, resumed match exact retry, held event and unchanged source'
