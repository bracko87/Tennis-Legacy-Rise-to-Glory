import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const sql=readFileSync(
  new URL('../supabase/migrations/20261114120000_publish_due_rankings_before_tournament_watchdog_v1.sql',import.meta.url),
  'utf8'
)

test('watchdog publishes ready ranking cycles BEFORE checking for tournament errors', () => {
  assert.match(sql,/run_tournament_operations_watchdog_v1/)
  const ranking=sql.indexOf('v_ranking_recovery:=public.process_weekly_rankings_v1()')
  assert.ok(ranking>0)
  // This is a source-rewrite migration: the existing problem-loop anchor is
  // declared before the inserted code, but the replacement prepends the patch
  // in the compiled watchdog function.
  assert.match(sql,/v_source:=replace\(v_source,v_anchor,v_patch\|\|v_anchor\)/)
  assert.match(sql,/v_ranking_recovery jsonb/)
  assert.match(sql,/ranking_recovery/)
})

test('ranking recovery only runs on active game Mondays with overdue final results', () => {
  assert.match(sql,/SELECT speed_multiplier FROM public.get_game_clock_v1\(\)/)
  assert.match(sql,/SELECT is_paused FROM public.game_clock WHERE id=1/)
  assert.match(sql,/public\.get_current_game_day_internal_v1\(\) d/)
  assert.match(sql,/d\.season-1\)\*366-2,7/)
  assert.match(sql,/r\.ranking_publish_status='pending'/)
  assert.match(sql,/r\.ranking_publish_absolute_day<=public\.game_day_absolute_v1/)
  assert.match(sql,/NOT EXISTS \(\s*SELECT 1 FROM public\.ranking_defence_cycles dc/)
  assert.match(sql,/fm\.draw_type='main_draw'/)
  assert.match(sql,/fm\.winner_id IS NOT NULL/)
  assert.match(sql,/public\.tournament_cancellations cx/)
})

test('ranking failures remain visible, with no direct clock, payment, or match rewrites', () => {
  assert.match(sql,/EXCEPTION WHEN OTHERS THEN/)
  assert.match(sql,/'status','failed'/)
  assert.match(sql,/Unexpected watchdog/)
  assert.doesNotMatch(sql,/\b(?:UPDATE|TRUNCATE|DELETE FROM)\s+public\.(?:game_clock|tournament_matches|player_rankings|player_tournament_results|career_finance_transactions)\b/i)
  assert.doesNotMatch(sql,/cron\.(?:schedule|unschedule|alter_job)/i)
})
