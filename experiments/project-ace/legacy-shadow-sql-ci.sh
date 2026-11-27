#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[[ "${ACE_SHADOW_SQL_REHEARSAL:-}" == "disposable-ci-only" && "${GITHUB_ACTIONS:-}" == "true" ]] || { echo 'CI-only disposable rehearsal'; exit 1; }
# No published ports, bind mounts, external network, production env or credentials.
name="ace-shadow-sql-${GITHUB_RUN_ID:?}-${GITHUB_RUN_ATTEMPT:?}"
tmp="$(mktemp -d)"
created=0
cleanup(){ if [[ "$created" == 1 ]]; then docker rm -f -v "$name" >/dev/null; fi; rm -rf "$tmp"; }
trap cleanup EXIT
docker run -d --name "$name" --network none -e POSTGRES_DB=ace_legacy_shadow -e POSTGRES_PASSWORD=ace-shadow-disposable-admin postgres:17 -p 55433 -c listen_addresses=127.0.0.1 >/dev/null
created=1
admin(){ docker exec -i -e PGPASSWORD=ace-shadow-disposable-admin "$name" psql -X -qAt -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 55433 -U postgres -d ace_legacy_shadow "$@"; }
reader(){ docker exec -i -e PGPASSWORD=ace-shadow-disposable-reader "$name" psql -X -qAt -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 55433 -U ace_shadow_reader -d ace_legacy_shadow "$@"; }
ready=0
for i in $(seq 1 60); do
 if admin -c 'SELECT 1' >/dev/null 2>&1; then ready=1;break;fi
 sleep 1
done
[[ "$ready" == 1 ]]
[[ "$(admin -c 'SHOW server_version_num' | cut -c1-2)" == 17 ]]
echo "PASS isolated PostgreSQL 17 server version"
[[ "$(docker inspect -f '{{.HostConfig.NetworkMode}}' "$name")" == none ]]
admin < legacy-shadow-fixture.sql
match_id=00000000-0000-4000-8000-000000000001
capture(){ reader -v match_id="$match_id" -f - < capture-legacy-shadow-result.sql; }
reject(){ local expected="$1"; if capture >"$tmp/out" 2>"$tmp/error";then echo "Unexpected capture success: $expected";exit 1;fi;grep -Fq "$expected" "$tmp/error"; }
reject 'missing restore approval marker'
admin <<'SQL'
CREATE SCHEMA ace_shadow_guard;
CREATE TABLE ace_shadow_guard.approval(singleton boolean PRIMARY KEY CHECK(singleton),marker text NOT NULL,approved_read_only boolean NOT NULL,restore_id text NOT NULL);
INSERT INTO ace_shadow_guard.approval VALUES(true,'ace-legacy-shadow-isolated-v027',false,'synthetic-ci-restore');
GRANT USAGE ON SCHEMA ace_shadow_guard TO ace_shadow_reader;
GRANT SELECT ON ace_shadow_guard.approval TO ace_shadow_reader;
SQL
reject 'restore not approved'
admin -c 'UPDATE ace_shadow_guard.approval SET approved_read_only=true'
reject 'cron inventory required'
admin <<'SQL'
CREATE SCHEMA cron;
CREATE TABLE cron.job(jobid integer PRIMARY KEY,active boolean);
INSERT INTO cron.job VALUES(1,true);
GRANT USAGE ON SCHEMA cron TO ace_shadow_reader;
GRANT SELECT ON cron.job TO ace_shadow_reader;
SQL
reject 'active scheduled jobs'
admin -c 'UPDATE cron.job SET active=false'
# Reader must not have application write privileges even if it opts out of read-only.
if reader -c "BEGIN READ WRITE; UPDATE public.tournament_matches SET status='cancelled'; ROLLBACK;" >"$tmp/out" 2>"$tmp/error";then echo 'Unexpected reader write';exit 1;fi
grep -q 'permission denied' "$tmp/error"
# A wrong database must fail before touching any application relation.
if docker exec -i -e PGPASSWORD=ace-shadow-disposable-admin "$name" psql -X -qAt -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 55433 -U postgres -d postgres -v match_id="$match_id" -f - < capture-legacy-shadow-result.sql >"$tmp/out" 2>"$tmp/error";then exit 1;fi
grep -q 'dedicated local shadow restore required' "$tmp/error"
fingerprint(){ admin -c "SELECT md5((SELECT jsonb_agg(to_jsonb(m) ORDER BY id)::text FROM public.tournament_matches m)||(SELECT jsonb_agg(to_jsonb(s) ORDER BY match_id)::text FROM public.tournament_match_simulations s)||(SELECT jsonb_agg(to_jsonb(s) ORDER BY match_id,set_number)::text FROM public.tournament_match_sets s)||(SELECT jsonb_agg(to_jsonb(s) ORDER BY match_id,player_id)::text FROM public.tournament_match_player_stats s))"; }
before="$(fingerprint)"
capture > "$tmp/capture.json"
capture > "$tmp/repeat.json"
cmp "$tmp/capture.json" "$tmp/repeat.json"
node legacy-shadow-sql-ci.test.cjs "$tmp/capture.json"
[[ "$before" == "$(fingerprint)" ]]
echo 'PASS real PostgreSQL read-only capture, disabled cron, approval and endpoint guards, reader isolation, stable export and unchanged synthetic rows'
# Independent historical source-code rehearsal, still inside the disposable network-none container.
node historical-legacy-shadow-fixture.cjs "$tmp"
admin < "$tmp/historical-fixture.sql"
before="$(fingerprint)"
reader -c "BEGIN READ ONLY; SELECT public.simulate_tournament_match_v1('00000000-0000-4000-8000-000000000005','321'); ROLLBACK;" > "$tmp/historical-result.json"
reader -c "BEGIN READ ONLY; SELECT public.simulate_tournament_match_v1('00000000-0000-4000-8000-000000000005','321'); ROLLBACK;" > "$tmp/historical-repeat.json"
cmp "$tmp/historical-result.json" "$tmp/historical-repeat.json"
node historical-legacy-shadow.test.cjs "$tmp"
[[ "$before" == "$(fingerprint)" ]]
[[ "$(admin -c "SELECT status FROM public.tournament_matches WHERE id='00000000-0000-4000-8000-000000000005'")" == scheduled ]]
admin < "$tmp/historical-later.sql"
before="$(fingerprint)"
for version in v1 v2; do
 reader -c "BEGIN READ ONLY; SELECT public.simulate_tournament_match_${version}('00000000-0000-4000-8000-000000000005','321'); ROLLBACK;" > "$tmp/historical-${version}.json"
 reader -c "BEGIN READ ONLY; SELECT public.simulate_tournament_match_${version}('00000000-0000-4000-8000-000000000005','321'); ROLLBACK;" > "$tmp/historical-${version}-repeat.json"
 cmp "$tmp/historical-${version}.json" "$tmp/historical-${version}-repeat.json"
done
node historical-legacy-later.test.cjs "$tmp"
[[ "$before" == "$(fingerprint)" ]]

# Large-sample historical V2 review, no production or external database.
node historical-legacy-cohort-fixture.cjs "$tmp"
admin < "$tmp/cohort-fixture.sql"
admin < "$tmp/current-duration-fixture.sql"
reader -c "SELECT jsonb_agg(jsonb_build_array(g,p,public.simulated_tennis_duration_minutes_v1(g,p)) ORDER BY g,p) FROM (VALUES (0,0),(12,48),(12,50),(20,150),(70,700),(100,1000)) x(g,p);" > "$tmp/current-duration-boundaries.json"
before="$(fingerprint)"
profile_fingerprint(){ admin -c "SELECT md5((SELECT jsonb_agg(to_jsonb(p) ORDER BY id)::text FROM public.players p)||(SELECT jsonb_agg(to_jsonb(s) ORDER BY player_id)::text FROM public.player_skills s))"; }
profiles_before="$(profile_fingerprint)"
reader -f - < "$tmp/cohort-query.sql" > "$tmp/cohort-results.jsonl"
node historical-legacy-cohort.test.cjs "$tmp"
[[ "$before" == "$(fingerprint)" ]]
[[ "$profiles_before" == "$(profile_fingerprint)" ]]

# Current scheduling comparison in a separate disposable database in the same network-none container.
admin -c 'CREATE DATABASE ace_ops_shadow'
ops(){ docker exec -i -e PGPASSWORD=ace-shadow-disposable-admin "$name" psql -X -qAt -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 55433 -U postgres -d ace_ops_shadow "$@"; }
# Minimal dependencies, independent of historical fixtures.
ops <<'SQL'
CREATE TABLE public.tournament_matches(id uuid PRIMARY KEY,competition_id uuid,player1_id uuid,player2_id uuid,status text,draw_type text,scheduled_season_week integer,scheduled_day integer,scheduled_start_minute integer,court_number integer,actual_duration_minutes integer);
CREATE TABLE public.tournament_match_simulations(match_id uuid PRIMARY KEY,total_games integer,total_points integer);
CREATE FUNCTION public.simulated_tennis_duration_minutes_v1(integer,integer) RETURNS integer LANGUAGE sql IMMUTABLE AS $$ SELECT least(420,greatest(60,round(greatest($1,0)*5.0+greatest($2,0)*0.13)::integer)) $$;
SQL
node operational-schedule-sql.cjs "$tmp"
sed -i "s/current_database()<>'ace_legacy_shadow'/current_database()<>'ace_ops_shadow'/" "$tmp/operational-schedule.sql"
ops < "$tmp/operational-schedule.sql" > "$tmp/operational-schedule-results.jsonl"
node operational-schedule-sql.cjs "$tmp" verify

# Original historical replay validator against actual Ace generated event arrays.
node official-replay-validator-fixture.cjs "$tmp"
node official-replay-engine.test.cjs "$tmp"
ops -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF; IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF; END \$\$;"
ops < "$tmp/replay-validator.sql"
ops < "$tmp/replay-validator-cases.sql" > "$tmp/replay-validator-results"
[[ "$(wc -l < "$tmp/replay-validator-results" | tr -d ' ')" == 405 ]]
[[ "$(grep -c '^t$' "$tmp/replay-validator-results")" == 405 ]]
echo 'PASS 400 generated replay arrays and five rejection controls against original Legacy SQL validator'
