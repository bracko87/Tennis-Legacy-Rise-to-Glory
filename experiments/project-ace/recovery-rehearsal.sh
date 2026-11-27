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
# Negative control: equivalent explicit/default schema ACLs match, genuine
# grants and grant options differ. All changes are rolled back on the CI source.
sql ace_review <<'SQL'
BEGIN;
DO $acl$
DECLARE owner_oid oid; expected jsonb; explicit_acl jsonb; changed jsonb;
BEGIN
 SELECT nspowner INTO STRICT owner_oid FROM pg_namespace WHERE nspname='ace_migration_journal';
 SELECT jsonb_agg(to_jsonb(a) ORDER BY a.grantor,a.grantee,a.privilege_type,a.is_grantable)
 INTO expected FROM aclexplode(acldefault('n',owner_oid)) a;
 SELECT jsonb_agg(to_jsonb(a) ORDER BY a.grantor,a.grantee,a.privilege_type,a.is_grantable)
 INTO explicit_acl FROM pg_namespace n CROSS JOIN LATERAL aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) a WHERE n.nspname='ace_migration_journal';
 IF explicit_acl IS DISTINCT FROM expected THEN RAISE EXCEPTION 'unexpected migration journal grants'; END IF;
 GRANT USAGE ON SCHEMA ace_migration_journal TO ace_review_worker WITH GRANT OPTION;
 SELECT jsonb_agg(to_jsonb(a) ORDER BY a.grantor,a.grantee,a.privilege_type,a.is_grantable)
 INTO changed FROM pg_namespace n CROSS JOIN LATERAL aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) a WHERE n.nspname='ace_migration_journal';
 IF changed IS NOT DISTINCT FROM expected THEN RAISE EXCEPTION 'genuine schema grant not detected'; END IF;
END $acl$;
ROLLBACK;
SQL
echo 'PASS schema ACL normalization and genuine grant negative control'
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

# Verify the restored journal against the exact checked-out candidate.
node migration-package-review.cjs manifest > "$tmp/manifest.json"
sql ace_review_recovery -c "SELECT jsonb_agg(jsonb_build_object('ordinal',ordinal,'filename',filename,'sha256',sha256) ORDER BY ordinal) FROM ace_migration_journal.installed" > "$tmp/journal.json"
node migration-package-review.cjs verify "$tmp/manifest.json" "$tmp/journal.json"
# Stopped-pilot state and worker epoch must survive disaster recovery.
[[ "$(sql ace_review_recovery -c "SELECT stopped_at IS NOT NULL AND stop_reason='synthetic operator stop' FROM ace_cutover_review.pilot_sessions WHERE competition_id='pilot-control-ci'")" == t ]]
[[ "$(sql ace_review_recovery -c "SELECT generation||':'||sequence FROM ace_cutover_review.pilot_worker_heartbeat WHERE competition_id='pilot-control-ci'")" == '2:1' ]]
[[ "$(sql ace_review_recovery -c "SELECT owner||':'||status FROM ace_cutover_review.matches WHERE id='pilot-control-ci-1-1'")" == 'ace:scheduled' ]]
[[ "$(sql ace_review_recovery -c "SELECT ace_cutover_review.pilot_monitor('pilot-control-ci')->>'can_retire_pilot'")" == false ]]
# Snapshot all restored rows and metadata except the heartbeat record itself.
# Later comparisons must retain career, ranking, prize, schedule, ownership,
# policy, stop receipt and journal history while allowing only a new pulse.
protected() { sql ace_review_recovery -f recovery-fingerprint.sql | grep -v '^ace_cutover_review.pilot_worker_heartbeat|'; }
protected > "$tmp/protected-before"
[[ "$(sql ace_review_recovery -c "SELECT ace_cutover_review.register_pilot_worker('pilot-control-ci',2)")" == 3 ]]
if engine "SELECT ace_cutover_review.pilot_worker_pulse('pilot-control-ci',2,2)" > "$tmp/old-pulse" 2>&1; then echo 'Old heartbeat generation accepted after restore'; exit 1; fi
grep -q 'invalid or stale worker pulse' "$tmp/old-pulse"
[[ "$(engine "SELECT ace_cutover_review.pilot_worker_pulse('pilot-control-ci',3,0)")" == observed ]]
[[ "$(engine "SELECT ace_cutover_review.pilot_worker_pulse('pilot-control-ci',3,0)")" == already_observed ]]
[[ "$(sql ace_review_recovery -c "SELECT ace_cutover_review.pilot_health('pilot-control-ci',900)->>'heartbeat_state'")" == fresh ]]
[[ "$(sql ace_review_recovery -c "SELECT ace_cutover_review.stop_pilot('pilot-control-ci','synthetic operator stop')->>'status'")" == already_stopped ]]
[[ "$(engine "SELECT ace_cutover_review.admit_source('pilot-control-ci-1-1',0)->>'status'")" == already_admitted ]]
[[ "$(engine "SELECT ace_cutover_review.admit_source('pilot-control-ci-1-2',0)->>'status'")" == wrong_engine ]]
protected > "$tmp/protected-after"
diff -u "$tmp/protected-before" "$tmp/protected-after"
echo 'PASS restored candidate journal, stopped pilot, preserved ownership, old worker fencing and replacement heartbeat without other row or metadata changes'
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
