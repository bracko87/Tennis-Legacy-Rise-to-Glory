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
