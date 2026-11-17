import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = file => readFileSync(new URL(file,import.meta.url),'utf8')
const sql = read('../supabase/migrations/20261117090000_calendar_one_travel_day_per_journey.sql')

test('one journey occupies only departure date even when its arrival is next game day',()=>{
  const travel = sql.split('  travel_rows as (')[1]?.split('  accepted_rows as (')[0]
  assert.ok(travel,'Expected dedicated travel_rows calendar section')
  assert.match(travel,/public\.absolute_game_day_v1\(l\.departure_absolute_day\) gd/)
  assert.doesNotMatch(travel,/generate_series\s*\(/i)
  assert.doesNotMatch(travel,/absolute_game_day_v1\(l\.arrival_absolute_day\)/)
  assert.match(travel,/l\.status in \('planned','completed'\)/)
  assert.match(travel,/l\.id::text/)
})

test('calendar continues to show travel status and excludes duplicate daily activity rows',()=>{
  assert.match(sql,/not \(a\.activity_type='travel' and a\.source='travel_plan'\)/)
  assert.match(sql,/when l\.status='completed' then 'travel_completed' else 'travel_plan'/)
  assert.match(sql,/when 'tournament_live' then 0/)
  assert.match(sql,/public\.get_player_calendar_activity_v1/)
})

test('one-day calendar rule does not rewrite journeys, results, or game finances',()=>{
  const definition = sql.split('CREATE OR REPLACE FUNCTION')[0]
  assert.doesNotMatch(definition,/\b(?:update|delete|truncate)\s+public\./i)
  assert.doesNotMatch(sql,/\b(?:update|delete|truncate)\s+public\.(?:player_travel_legs|player_daily_activity|career_finance_transactions|tournament_matches|player_training_sessions)\b/i)
  assert.match(sql,/Real arrival, duration, travel charges and fatigue still use the travel leg/)
})
