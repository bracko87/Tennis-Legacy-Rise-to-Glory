import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = path => readFileSync(new URL('../'+path,import.meta.url),'utf8')
const reset = read('scripts/tennis_prelaunch_season1_reset.sql')
const report = read('scripts/tennis_release_readiness_readonly.sql')
const tables = read('supabase/migrations/20261117130000_lock_server_owned_public_tables.sql')
const engines = read('supabase/migrations/20261117131500_restrict_internal_game_engine_rpcs.sql')

test('final restart never clears permanent tournament draw seeding layouts',()=>{
 assert.match(reset,/'tournament_draw_seed_groups','tournament_draw_seed_slots'/)
 assert.match(reset,/IF v_count<>162 OR v_tables IS NULL/)
 assert.doesNotMatch(reset,/expected 160 tables/)
 assert.match(reset,/count\(\*\) FROM public\.tournament_draw_seed_slots sl/)
 assert.match(reset,/max\(seed_end\).*tournament_draw_seed_groups/)
 assert.match(report,/forbidden_seed_targets/)
 assert.match(report,/correct_sizes=4/)
})

test('no automatic destructive restart without frozen clock and cron',()=>{
 assert.match(reset,/public\.game_clock WHERE id=1 AND is_paused/)
 assert.match(reset,/cron\.job j ON j\.jobid=f\.jobid WHERE j\.active/)
 assert.match(reset,/public_signup_enabled/)
 assert.match(report,/Restorable database backup/)
 assert.match(report,/Isolated January-February simulation/)
 assert.match(report,/NOT_AUTHORIZED/)
 assert.match(report,/NEEDS_DECISION/)
})

test('release audit is genuinely read-only',()=>{
 const src=report.replace(/^\s*--.*$/gm,'')
 assert.doesNotMatch(src,/\b(?:UPDATE|DELETE|INSERT|TRUNCATE|DROP|ALTER|CREATE|GRANT|REVOKE)\s+(?:TABLE|FROM|INTO|public\.|control_center_private\.)/i)
 assert.match(report,/SELECT seq,item,state,evidence FROM checks ORDER BY seq;/)
})

test('internal tables deny public writes without removing existing SELECT grants',()=>{
 assert.match(tables,/ENABLE ROW LEVEL SECURITY/)
 assert.match(tables,/REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER/)
 assert.match(tables,/api_reads_anon:=has_table_privilege/)
 assert.match(tables,/release_keep_anon_read_v1/)
 assert.match(tables,/release_keep_authenticated_read_v1/)
})

test('internal mutating engines and trigger functions are inaccessible directly',()=>{
 assert.match(engines,/grant_new_career_starting_coins_v1/)
 assert.match(engines,/initialize_new_human_career_v1/)
 assert.match(engines,/simulate_doubles_match_v1/)
 assert.match(engines,/REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC,anon,authenticated/)
 assert.match(engines,/p\.prorettype='pg_catalog\.trigger'::regtype/)
 assert.match(engines,/GRANT EXECUTE ON FUNCTION %s TO service_role/)
})
