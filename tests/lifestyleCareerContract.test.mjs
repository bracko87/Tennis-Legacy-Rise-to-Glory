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
const jetPreview=read('src/components/private-life/PrivateJetTravelPreview.tsx')
const tournamentV3=read('src/pages/dashboard/TournamentV3.tsx')
const confirmDialog=read('src/components/common/GameConfirmDialog.tsx')
const dialogCss=read('src/styles/game-confirm-dialog.css')
const privateLifeCss=read('src/styles/private-life.css')
const travelSettings=read('src/components/private-life/TravelPreferenceSettings.tsx')
const accountPage=read('src/pages/manager/ManagerPages.tsx')
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

test('commercial fallback clearly shows full party fare and ordinary fatigue in tournament UI',()=>{
 assert.match(picker,/commercialTotal = Number\(quote\?\.commercial_player_cost/)
 assert.match(picker,/quote\?\.commercial_staff_cost/)
 assert.match(picker,/c\.commercialRoundTrip/)
 assert.match(picker,/c\.commercialFatigueNote/)
 assert.match(picker,/choice==='private_jet' && !supported \? c\.bookCommercial : c\.save/)
 assert.match(i18n,/commercialFallback: string/)
 assert.match(i18n,/Normal commercial travel costs and fatigue apply/)
})

test('nine private airplane marketplace previews match their SQL travel specifications',()=>{
 const models=[...jetPreview.matchAll(/^\s*(air_[a-z0-9_]+):\s*\{\s*seats:\s*(\d+),\s*rangeKm:\s*(\d+),\s*fatigueReduction:\s*(\d+),\s*baseCost:\s*(\d+),\s*costPerKm:\s*(\d+)\s*\}/gm)]
 assert.equal(models.length,9,'Preview must cover exactly the nine approved aircraft')
 const ids=new Set()
 for(const [,code,seats,range,reduction,base,rate] of models){
  assert.ok(!ids.has(code),'Duplicate preview aircraft '+code);ids.add(code)
  const db=jet.match(new RegExp("'"+code+"'\\s*,\\s*(\\d+),\\s*(\\d+),\\s*(\\d+),\\s*(\\d+),\\s*(\\d+)"))
  assert.ok(db,'SQL migration does not approve '+code)
  assert.deepEqual([+seats,+range,+base,+rate,+reduction*100],db.slice(1,6).map(Number),'Preview specifications mismatch '+code)
 }
 assert.match(privateLife,/PrivateJetTravelPreview/)
 assert.match(privateLife,/listing\.category === 'private_jet'/)
 assert.match(privateLife,/detailTarget\.listing\.category === 'private_jet'/)
 assert.match(privateLife,/detailTarget\.asset\.category === 'private_jet'/)
 assert.match(privateLife,/connectedBackendActive=\{Boolean\(dashboard\.career_lifestyle\)\}/)
 assert.match(jetPreview,/Preview only/)
 assert.match(jetPreview,/If out of range, player and staff fly commercially/)
})

test('tournament page binds translation function for disabled doubles navigation',()=>{
 assert.match(tournamentV3,/import \{ useTranslation \} from 'react-i18next'/)
 assert.match(tournamentV3,/export default function TournamentPage\(\) \{\s*const \{ t \} = useTranslation\(\)/)
})
test('large private life dialogs scroll images and details without hiding controls',()=>{
 assert.match(confirmDialog,/tlg-game-confirm-scroll-area/)
 assert.match(dialogCss,/max-height: calc\(100dvh - 32px\)/)
 assert.match(dialogCss,/\.tlg-game-confirm-scroll-area\s*\{[^}]*overflow-y: auto/s)
 assert.match(dialogCss,/\.tlg-game-confirm-head, \.tlg-game-confirm-actions \{ flex: 0 0 auto; \}/)
})
test('marketplace categories share desktop width equally and mobile selector stays intact',()=>{
 assert.match(privateLifeCss,/@media \(min-width: 761px\)/)
 assert.match(privateLifeCss,/\.private-life-page \.private-life-section \.private-life-filter-bar\s*\{[^}]*display: grid;[^}]*grid-template-columns: repeat\(10, minmax\(110px, 1fr\)\);[^}]*width: 100%;/s)
 assert.match(privateLifeCss,/\.private-life-page \.private-life-section \.private-life-filter-bar > button\s*\{[^}]*width: 100%;[^}]*text-align: center;/s)
 const mobileCss=read('src/styles/private-life-mobile-compact.css')
 assert.match(mobileCss,/\.private-life-section \.private-life-filter-bar \{ display: none; \}/)
})
test('missing private-life RPCs render explicitly unavailable UI rather than disappearing',()=>{
 assert.match(privateLife,/!dashboard\.career_lifestyle && tab === 'overview'/)
 assert.match(privateLife,/careerCopy\.backendPending/)
 assert.doesNotMatch(travelSettings,/if \(mode===null\) return null/)
 assert.match(travelSettings,/disabled=\{saving \|\| mode===null\}/)
 assert.match(travelSettings,/loaded && mode===null/)
 assert.match(accountPage,/get_my_private_life_career_v1/)
 assert.match(accountPage,/careerCopy\.homeBase/)
})

test('Lifestyle and career card matches Private Life panels on desktop and mobile',()=>{
 const css=read('src/styles/private-life-career.css')
 assert.match(css,/\.tlg-career-panel,\.tlg-jet-picker,\.tlg-career-preview\s*\{[^}]*border:1px solid #dce4ee;[^}]*background:#fff;/s)
 assert.match(css,/\.private-life-page > \.tlg-career-panel\s*\{[^}]*margin:0;[^}]*padding:20px;[^}]*border-radius:16px/s)
 assert.match(css,/@media\(max-width:640px\)\s*\{[\s\S]*?\.private-life-page > \.tlg-career-panel\s*\{padding:14px\}/)
 assert.doesNotMatch(css,/var\(--(?:card|border|foreground|background|muted-foreground|primary)[,)]/)
 assert.match(privateLife,/<LifestyleCareerPanel/)
 assert.match(privateLife,/<section className="tlg-career-panel tlg-career-panel-pending"/)
})
