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

const v2 = read('../supabase/migrations/20261113090000_direct_transfer_cost_hotel_morale_v2.sql')
const v3 = read('../supabase/migrations/20261113091000_direct_transfer_jet_and_duration_v3.sql')
const v4 = read('../supabase/migrations/20261113092000_direct_transfer_late_resolution_v4.sql')
const picker = read('../src/components/private-life/TournamentJetPicker.tsx')
const labels = read('../src/lib/directTournamentTravelI18n.ts')
const styles = read('../src/styles/schedule-operations-v2.css')

test('saved direct transfer has a server-side owner-checked quote', () => {
 assert.match(v2,/function public\.quote_tournament_transfer_options_v1/)
 assert.match(v2,/get_tournament_transfer_preference_v1\(p_player_id,p_competition_id\)/)
 assert.match(v2,/quote_travel_v2\(v_source\.city,v_source\.country_code/)
 assert.match(v2,/quote_private_jet_leg_v1\(p_player_id,v_source\.city/)
 assert.match(v2,/'direct_flight_cost',v_leg_cost/)
 assert.match(v2,/'commercial_via_home_cost',v_home_cost/)
 assert.match(v2,/'extra_hotel_nights',v_extra_nights/)
 assert.match(ui,/quote_tournament_transfer_options_v1/)
 assert.match(ui,/transferQuote\.direct_total_cost/)
})

test('hotel charges include early-arrival days only for completed direct journeys', () => {
 assert.match(v2,/function public\.process_tournament_hotel_day_v1/)
 assert.match(v2,/l\.status='completed'/)
 assert.match(v2,/p_absolute_day<target\.start_absolute_day/)
 assert.match(v2,/post_tournament_hotel_night_v1\(p_player_id,c\.destination_reference_id::uuid,p_absolute_day\)/)
 assert.doesNotMatch(v2,/\b(?:DELETE FROM|TRUNCATE)\s+public\.career_finance_transactions/i)
})

test('time away morale is capped and only applies after a completed direct transfer', () => {
 assert.match(v2,/applied_penalty between 0 and 2/)
 assert.match(v2,/l\.status='completed'/)
 assert.match(v2,/p_absolute_day-v_away_start\+1>=15 then 2/)
 assert.match(v2,/p_absolute_day-v_away_start\+1>=8 then 1/)
 assert.match(v2,/greatest\(0,v_previous-1\)/)
 assert.match(v2,/if p_absolute_day<=v_last_day/)
 assert.match(v2,/apply_direct_transfer_morale_v1\(p_player_id,v_abs\)/)
})

test('private jet selection and flight duration use direct route when opted in', () => {
 assert.match(v3,/function public\.quote_my_private_life_jet_v1/)
 assert.match(v3,/function public\.set_private_life_tournament_travel_v1/)
 assert.match(v3,/function public\.get_private_life_tournament_travel_v1/)
 assert.match(v3,/l\.jet_quote->>'estimated_hours'/)
 assert.match(picker,/direct_transfer_scope/)
 assert.match(ui,/quoteRevision=\{travelModeRevision\}/)
 assert.match(ui,/transferQuote\?\.direct_distance_km/)
})
test('resolved previous tournament can still be linked from player location', () => {
 assert.match(v4,/when v_source_type='tournament' and c\.commitment_type='tournament'/)
 assert.doesNotMatch(v4,/when v_had and v_source_type='tournament' and c\.commitment_type='tournament'/)
})
test('clear travel labels are available in all eight supported languages', () => {
 for (const code of ['en','de','es','fr','it','pt','ru','sr']) assert.ok(labels.includes(' '+code+':{'),code)
 assert.match(styles,/\.tlg-prep-transfer-quote/)
})
