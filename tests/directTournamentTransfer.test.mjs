import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
const read = (p) => readFileSync(new URL(p, import.meta.url), 'utf8')
const sql = read('../supabase/migrations/20261113083500_tournament_direct_transfer_choice_v1.sql')
const ui = read('../src/pages/dashboard/Schedule.tsx')

test('existing return-home rule is the default and the user must choose direct travel', () => {
  assert.match(sql, /v_choice text:='home'/)
  assert.match(sql, /coalesce\(v_choice,'home'\)/)
  assert.match(sql, /route_choice text not null check \(route_choice in \('home','direct'\)\)/)
  assert.match(ui, /useState<TournamentTransferChoice>\('home'\)/)
  assert.match(ui, /Return home first \(default\)/)
})
test('preparation saves an authorized destination-specific travel preference', () => {
  assert.match(sql, /p\.owner_user_id=auth\.uid\(\)/)
  assert.match(sql, /function public\.save_tournament_transfer_preference_v1/)
  assert.match(sql, /on conflict\(player_id,competition_id\)/)
  assert.match(sql, /perform public\.rebuild_player_travel_plan_v1\(p_player_id\)/)
  assert.match(ui, /save_tournament_transfer_preference_v1/)
  assert.match(ui, /p_route_choice: transferChoice/)
})
test('direct travel suppresses an unnecessary home leg and keeps early departure', () => {
  assert.match(sql, /pref\.source_competition_id::text=v_source_ref/)
  assert.match(sql, /pref\.competition_id::text=c\.reference_id/)
  assert.match(sql, /then greatest\(v_current,v_prev_end\+1\)/)
  assert.match(sql, /then least\(v_pref_day,l\.departure_absolute_day\)/)
  assert.match(sql, /l\.source_location_type='tournament'/)
})
test('protects completed travel and does not rewrite match results or player balances', () => {
  assert.match(sql, /l\.status='completed'/)
  assert.doesNotMatch(sql, /\b(?:UPDATE|DELETE FROM|TRUNCATE)\s+public\.tournament_matches\b/i)
  assert.doesNotMatch(sql, /\b(?:UPDATE|DELETE FROM|TRUNCATE)\s+public\.player_finances\b/i)
  assert.match(ui, /The standard round-trip cost estimate below does not include this alternative route/)
})
