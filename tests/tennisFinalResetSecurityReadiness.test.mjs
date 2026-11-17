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
 assert.match(reset,/IF v_count<>149 OR v_tables IS NULL/)
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

test('final reset preserves real payment and referral histories',()=>{
 const scope=reset.split('INTO v_count,v_tables FROM pg_tables WHERE')[1]?.split("EXECUTE 'TRUNCATE TABLE'")[0]
 assert.ok(scope,'Expected reset inventory')
 assert.doesNotMatch(scope,/left\(tablename,9\)='referral_'/)
 assert.doesNotMatch(scope,/'site_analytics_daily_pages'/)
 assert.doesNotMatch(scope,/,'referrals'/)
 for(const preserved of ['auth.users','billing_transactions','premium_memberships',
 'user_wallets','coin_ledger','stripe_webhook_events','referral_rewards',
 'referral_premium_grants','referrals','site_analytics_daily_visitors']){
   assert.match(reset,new RegExp(preserved.replace('.',String.raw`\.`)))
 }
 assert.match(reset,/tennis_prelaunch\.wallet_balance_before/)
 assert.match(reset,/Post-reset consistency failed/)
})

test('reset clears obsolete repair links only after preserving full private evidence',()=>{
 assert.match(reset,/tablename='tournament_qualification_nocontest_repairs_v1'/)
 assert.match(reset,/CREATE TABLE IF NOT EXISTS control_center_private\.tennis_prelaunch_reset_repair_evidence_archive_v1/)
 assert.match(reset,/to_jsonb\(r\)/)
 assert.match(reset,/tennis_prelaunch\.repair_rows_before/)
 assert.match(report,/No dangling foreign keys from reset scope/)
 assert.match(report,/Referrals and website analytics remain intact/)
})

test('restart needs owner approval and independent backup plus rehearsal references',()=>{
 assert.match(reset,/current_setting\('tennis_prelaunch\.owner_approved',true\)/)
 assert.match(reset,/current_setting\('tennis_prelaunch\.backup_restore_reference',true\)/)
 assert.match(reset,/current_setting\('tennis_prelaunch\.rehearsal_reference',true\)/)
 assert.match(reset,/speed_multiplier=current_setting\('tennis_prelaunch\.target_speed'\)::numeric/)
 assert.doesNotMatch(reset,/speed_multiplier=2,/)
 assert.doesNotMatch(reset,/>=40000|<40000/)
 assert.match(report,/Restorable database backup/)
 assert.match(report,/Isolated January-February simulation/)
})

const playerAcl = read('supabase/migrations/20261117140000_restrict_authenticated_player_rpc_anon_access.sql')
test('authentication-only player actions remain available to logged-in users, not anonymous callers',()=>{
 for (const name of [
   'set_training_week_day_v1','get_player_calendar_activity_v1','get_staff_dashboard_v2',
   'save_tournament_preparation_v1','book_training_camp_v3','restart_tennis_legacy_account_v1',
   'get_admin_tournament_operations_v1','get_player_inbox_v1'
 ]) assert.match(playerAcl,new RegExp(name))
 assert.match(playerAcl,/REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC,anon/)
 assert.match(playerAcl,/GRANT EXECUTE ON FUNCTION %s TO authenticated,service_role/)
 assert.match(playerAcl,/p\.prosrc ILIKE '%auth.uid%'/)
 assert.doesNotMatch(playerAcl,/get_public_registration_status_v1/)
 assert.doesNotMatch(playerAcl,/record_site_analytics_event_v1/)
})
