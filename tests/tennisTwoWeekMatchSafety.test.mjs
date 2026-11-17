import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = name => readFileSync(new URL('../supabase/migrations/'+name,import.meta.url),'utf8')
const secure = read('20261117105000_remove_public_test_e2e_functions.sql')
const phases = read('20261117110000_respect_qualification_and_main_draw_weeks.sql')
const length = read('20261117111500_simulated_match_duration_and_safe_start.sql')
const startup = read('20261117112500_finalize_realistic_duration_and_reschedule_due_matches.sql')
const follow = read('20261117113000_reschedule_followups_after_long_match.sql')

test('E2E helpers cannot survive in public if no production dependency exists',()=>{
 assert.match(secure,/A non-test function references E2E helpers/)
 assert.match(secure,/An existing cron job references E2E helpers/)
 assert.match(secure,/DROP FUNCTION %s RESTRICT/)
 assert.match(secure,/REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated/)
})

test('multiweek tournaments use the actual qualification and main draw weeks',()=>{
 assert.match(phases,/min\(ss\.season_week\) FILTER \(WHERE ss\.phase='qualification'\)/)
 assert.match(phases,/min\(ss\.season_week\) FILTER \(WHERE ss\.phase='main_draw'\)/)
 assert.match(phases,/new\.scheduled_season_week:=v_qual_week/)
 assert.match(phases,/new\.scheduled_season_week:=v_main_first_week\+\(v_event_day-1\)\/7/)
 assert.doesNotMatch(phases,/v_first_week-1/)
 assert.match(phases,/Invalid configured qualification\/main-draw weeks/)
})

test('match duration is based on tennis games and points, not short replay playback',()=>{
 assert.match(length,/p_total_games,0\)\*5\.0/)
 assert.match(length,/p_total_points,0\)\*0\.13/)
 assert.match(length,/least\(420,greatest\(60/)
 assert.match(startup,/actual_duration_minutes=public\.simulated_tennis_duration_minutes_v1\(s\.total_games,s\.total_points\)/)
 assert.doesNotMatch(startup,/actual_duration_minutes=150/)
})

test('later singles starts are moved when court, player or a still-live replay is occupied',()=>{
 assert.match(length,/ensure_safe_singles_start_v1/)
 assert.match(length,/x\.court_number=v_court/)
 assert.match(length,/x\.player1_id IN \(target\.player1_id,target\.player2_id\)/)
 assert.match(length,/sx\.live_ends_at>now\(\)/)
 assert.match(length,/x\.status IN \('scheduled','in_progress','completed'\)/)
 assert.match(length,/update public\.tournament_matches/i)
 assert.match(length,/status','rescheduled'/)
 assert.match(length,/status','blocked'/)
 assert.match(startup,/pg_advisory_xact_lock/)
 assert.match(startup,/v_gate:=public\.ensure_safe_singles_start_v1\(r\.match_id,v_game\)/)
 assert.match(startup,/if v_gate->>'status'<>'ready' then/)
})

test('after a long match completes, following playable matches are checked and moved',()=>{
 assert.match(follow,/played\.actual_duration_minutes<=coalesce\(played\.estimated_duration_minutes,150\)/)
 assert.match(follow,/x\.status='scheduled'/)
 assert.match(follow,/public\.ensure_safe_singles_start_v1\(next_match\.id,v_current_second\)/)
 assert.match(follow,/perform public\.reschedule_following_player_matches_v1\(p_match_id\)/)
 assert.match(follow,/Post-match rescheduling failed/)
})

test('new scheduling implementation cannot rewrite historical results at install time',()=>{
 for(const file of [phases,length,startup,follow]){
   const beforeDefinition=file.split('CREATE OR REPLACE FUNCTION public.')[0]
   assert.doesNotMatch(beforeDefinition,/\b(?:update|delete|truncate)\s+public\.(?:tournament_matches|tournament_entries|career_finance_transactions|player_rankings)\b/i)
 }
 assert.match(length,/IF target\.id IS NULL OR target\.status<>'scheduled'/)
 assert.match(follow,/IF played\.id IS NULL OR played\.status<>'completed'/)
})


const doublesPhase=read('20261117114500_doubles_main_phase_and_variable_singles_conflicts.sql')
const doublesStart=read('20261117115000_doubles_start_guard_and_rebooking.sql')

test('doubles are scheduled in the main-draw phase rather than the qualifying phase',()=>{
 assert.match(doublesPhase,/ss\.phase='main_draw'/)
 assert.match(doublesPhase,/coalesce\(main_phase\.main_start,w\.start_absolute_day\)/)
 assert.match(doublesPhase,/coalesce\(main_phase\.main_end,w\.end_absolute_day\)/)
 assert.match(doublesPhase,/v_abs::bigint\*1440\+v_slot<=v_game_minute\+10/)
})

test('doubles can never start when a singles player or court remains in use',()=>{
 assert.match(doublesPhase,/public\.simulated_tennis_duration_minutes_v1\(sim\.total_games,sim\.total_points\)/)
 assert.match(doublesStart,/sm\.status='in_progress'/)
 assert.match(doublesStart,/public\.player_match_slot_conflict_v1\(/)
 assert.match(doublesStart,/schedule_reason='conflict_pending'/)
 assert.match(doublesStart,/public\.schedule_doubles_match_v1\(m\.id\)/)
 assert.match(doublesStart,/IF v_conflict THEN/)
 assert.match(doublesStart,/CONTINUE;/)
 assert.match(doublesStart,/pg_advisory_xact_lock\(171106,20261117\)/)
 assert.match(doublesStart,/REVOKE EXECUTE ON FUNCTION public\.process_due_doubles_matches_v1\(\)/)
})
