import { readFileSync } from 'node:fs'
import assert from 'node:assert/strict'
import test from 'node:test'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..')
const read=relative=>readFileSync(path.join(root,relative),'utf8')
const foundation=read('supabase/migrations/20261026093000_private_life_career_foundation_v1.sql')
const jet=read('supabase/migrations/20261026094500_private_life_jet_travel_integration_v1.sql')
const profile=read('supabase/migrations/20261026095500_private_life_profile_residence_v1.sql')
const privateLife=read('src/pages/dashboard/PrivateLife.tsx')
const schedule=read('src/pages/dashboard/Schedule.tsx')
const overview=read('src/pages/dashboard/Overview.tsx')
const settings=read('src/pages/manager/GamePreferences.tsx')
const picker=read('src/components/private-life/TournamentJetPicker.tsx')
const i18n=read('src/lib/lifestyleCareerI18n.ts')

test('lifestyle morale is temporary, capped, decay-based and anti-farming',()=>{
 assert.match(foundation,/least\(3,/i)
 assert.match(foundation,/purchased_absolute_day\)\/7/)
 assert.match(foundation,/v_day-14/)
 assert.match(foundation,/trg_lifestyle_purchase_morale/)
 assert.match(foundation,/acquisition_type<>'purchase'/)
})
test('residence requires ownership, blocks travel exploits and protects history',()=>{
 assert.match(foundation,/a\.player_id=v_player and a\.sold_absolute_day is null/)
 assert.match(foundation,/c\.category in \('apartment','house_villa'\)/)
 assert.match(foundation,/v_current-v_last<30/)
 assert.match(foundation,/v_current\+2/)
 assert.match(foundation,/location_type<>'home'/)
 assert.match(foundation,/trg_lifestyle_prevent_home_listing/)
 assert.match(jet,/v_home_city:=homep->>'city'/)
 assert.match(jet,/v_source_city:=coalesce\(v_state.current_city/)
 assert.match(profile,/'residence',public\.get_player_home_base_v1/)
})
test('private aircraft need booking and travel costs, not automatic 90% fatigue',()=>{
 assert.match(jet,/tournament_travel_eligible/)
 assert.match(jet,/max_range_km/)
 assert.match(jet,/reposition_cost/)
 assert.match(jet,/cost_per_km/)
 assert.match(jet,/reduction_bps.*5000|5000.*reduction_bps/s)
 assert.match(jet,/set_private_life_tournament_travel_v1/)
 assert.match(jet,/travel_mode='private_jet'/)
 assert.doesNotMatch(jet,/v_reduction:=coalesce\(\(v_jet->>'reduction_bps'\)::integer,9000\)/)
 assert.match(jet,/staff_ticket_cost/)
 assert.match(jet,/v_fallback_staff/)
})
test('one active home, jet choice, profile and preferences appear in UI',()=>{
 assert.match(privateLife,/set_private_life_home_base_v1/)
 assert.match(privateLife,/LifestyleCareerPanel/)
 assert.match(schedule,/TournamentJetPicker/)
 assert.match(overview,/CareerLocationPreview/)
 assert.match(settings,/TravelPreferenceSettings/)
 assert.match(picker,/get_private_life_tournament_travel_v1/)
 assert.match(picker,/set_private_life_tournament_travel_v1/)
})
test('eight Tennis Legacy game languages have lifestyle copy',()=>{
 for(const code of ['en','sr','de','es','fr','it','ru','pt']){
   assert.match(i18n,new RegExp("(?:^|\\n)\\s*"+code+":|['\\\"]"+code+"['\\\"]"))
 }
})

test('Private Life jet booking stays Premium-only and summary identifies real flight mode', () => {
 assert.match(schedule,/!membershipLoading && isPremium && <TournamentJetPicker/)
 assert.match(schedule,/estimate\.private_jet\?\.active/)
 assert.match(schedule,/staff_on_jet/)
 assert.match(schedule,/staff_commercial/)
})

test('jet booking requires real route range and reposition checks, with persistent aircraft location',()=>{
 assert.match(jet,/v_route_jet:=public\.quote_private_jet_leg_v1/)
 assert.match(jet,/p_mode:='commercial'/)
 assert.match(jet,/'commercial_fallback'/)
 assert.match(jet,/trg_initialize_private_jet_position/)
 assert.match(jet,/on conflict\(owned_asset_id\) do nothing/)
 assert.match(jet,/join public\.player_location_state|left join public\.player_location_state/)
 assert.match(jet,/select city,country_code into v_origin_city,v_origin_country from public\.player_private_jet_positions/)
})

test('travel-mode changes rebuild unfinished journeys', () => {
 assert.match(foundation, /perform public\.rebuild_player_travel_plan_v1\(v_player\)/)
})

test('only nine screenshot airplanes get whole-team fares and quick-flight quotes',()=>{
 const approved=[
  'air_cessaro_citation_m3','air_emborgier_phenom_350e','air_bombara_challenger_420',
  'air_cessaro_citation_latitude_x','air_emborgier_praetor_680','air_dassier_falcon_9x',
  'air_gulfstar_g650_lx','air_bombara_global_8000x','air_gulfstar_g900_sovereign'
 ]
 for(const code of approved)assert.ok(jet.includes(code),'Missing screenshot model '+code)
 assert.match(jet,/tournament_travel_eligible',false/)
 assert.match(jet,/insufficient_passenger_seats/)
 assert.match(jet,/'staff_on_jet',greatest\(0,coalesce\(p_staff_count,0\)\),'staff_commercial',0/)
 assert.match(jet,/v_staff_cost:=0;/)
 assert.match(jet,/overnight_transfer_possible/)
 assert.match(jet,/quote_my_private_life_jet_v1/)
 assert.match(picker,/quote_my_private_life_jet_v1/)
 assert.match(picker,/fullPartyCostNote/)
})


test('out-of-range private flights automatically use normal commercial travel',()=>{
 assert.match(jet,/v_fallback_reason:=coalesce\(v_route_jet->>'reason','jet_out_of_range'\)/)
 assert.match(jet,/p_mode:='commercial'/)
 assert.match(jet,/p_owned_jet_asset_id:=null/)
 assert.match(picker,/requestedMode = choice==='private_jet' && !supported \? 'commercial' : choice/)
 assert.match(picker,/saveData\?\.travel_mode==='commercial'/)
 assert.match(picker,/commercialFallback/)
 assert.doesNotMatch(jet,/private_jet_refuel_route_v1/)
})
