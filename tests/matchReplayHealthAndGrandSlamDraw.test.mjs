import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')
const sql = read('../supabase/migrations/20261113065000_tennis_match_replay_health_and_early_grand_slam_draw_v1.sql')

test('stalled-match monitoring does not call a real running replay overdue', () => {
  assert.match(sql, /run_system_health_watchdog_v1/)
  assert.match(sql, /left join public\.tournament_match_simulations sim on sim\.match_id=m\.id/)
  assert.match(sql, /m\.status='scheduled'/)
  assert.match(sql, /sim\.match_id is null/)
  assert.match(sql, /sim\.simulation_status is distinct from 'live'/)
  assert.match(sql, /sim\.live_ends_at is null/)
  assert.match(sql, /sim\.live_ends_at < now\(\)-interval '5 minutes'/)
  assert.match(sql, /public\.tournament_match_game_second_v1\(m\.id\) < v_now_second-21600/)
})

test('January multi-week Grand Slam qualifiers get a draw before Jan 6, not Jan 9', () => {
  assert.match(sql, /get_tournament_entry_timeline_v1/)
  assert.match(sql, /v_first_week=2 AND v_last_week>v_first_week/)
  assert.match(sql, /v_category='grand_slam_2000'/)
  assert.match(sql, /v_open := \(v_season-1\)::bigint\*31622400/)
  assert.match(sql, /v_close := \(v_first_start-5\)::bigint\*86400 \+ 16\*3600/)
  assert.match(sql, /v_late_close := \(v_first_start-5\)::bigint\*86400 \+ 18\*3600/)
  assert.match(sql, /v_draw := \(v_first_start-5\)::bigint\*86400 \+ 22\*3600/)
  assert.match(sql, /Unexpected tournament timeline source/)
})

test('changes only database functions, not existing results, game clock, or balances', () => {
  assert.doesNotMatch(sql, /\b(?:UPDATE|DELETE|TRUNCATE|INSERT)\s+(?:INTO\s+|FROM\s+)?(?:public\.)?(?:tournament_matches|tournament_match_simulations|player_tournament_results|player_ranking_contributions|game_clock|career_finance_transactions)\b/i)
  assert.doesNotMatch(sql, /cron\.unschedule|cron\.alter_job|cron\.schedule/i)
  assert.match(sql, /EXECUTE v_sql/)
})
