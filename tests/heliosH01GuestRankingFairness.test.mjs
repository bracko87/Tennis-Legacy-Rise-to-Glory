import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = path => readFileSync(new URL('../'+path,import.meta.url),'utf8')
const singles = read('supabase/migrations/20261120184500_helios_guest_zero_point_rank_fairness.sql')
const doubles = read('supabase/migrations/20261120185000_helios_guest_doubles_rank_fairness.sql')
const previous = read('supabase/migrations/20261120142000_helios_h01_guest_player_creation.sql')
const expiry = read('supabase/migrations/20261120171000_helios_h08_guest_gameplay_expiry_guards.sql')
const checklist = read('HELIOS_CHECKLIST.md')

test('H01: server-side zero-point guest rank tie-break; earned points retain full weight',()=>{
  assert.match(singles,/FUNCTION public\.is_tennis_zero_point_guest_rank_tie_v1/)
  assert.match(singles,/coalesce\(p_points,0\)=0/)
  assert.match(singles,/auth\.users u/)
  assert.match(singles,/control_center_private\.tennis_guest_trials_v1 g/)
  assert.match(singles,/u\.is_anonymous/)
  assert.match(singles,/THEN 1 ELSE 0/)
  assert.match(singles,/REVOKE ALL ON FUNCTION public\.is_tennis_zero_point_guest_rank_tie_v1/)
  assert.doesNotMatch(singles,/GRANT EXECUTE ON FUNCTION public\.is_tennis_zero_point_guest_rank_tie_v1/)
})

test('H01: ranked singles, player display and tournament field use the same tie-break',()=>{
  for(const name of [
    'get_world_rankings_v1','get_world_rankings_v2','get_world_rankings_v3',
    'player_current_rank_position_v1','get_player_world_rank_position_v1',
    'get_player_profile_v2','get_tournament_application_field_v1',
    'capture_world_ranking_snapshot_internal_v1','get_world_doubles_rankings_v1'
  ]){
    const idx=singles.indexOf('CREATE OR REPLACE FUNCTION public.'+name+'(')
    assert.ok(idx>=0,'missing original ranking function '+name)
    const end=singles.indexOf(';\n\nCREATE OR REPLACE FUNCTION',idx)
    const segment=singles.slice(idx,end<0?undefined:end)
    assert.match(segment,/is_tennis_zero_point_guest_rank_tie_v1/,'missing guest tie-break in '+name)
    assert.match(segment,/ranking_points,0\) desc/i,'ranking points must remain first')
  }
})

test('H01: doubles publication and partner-selection tie-break are consistent',()=>{
  assert.match(doubles,/FUNCTION public\.process_doubles_rankings_for_day_v1/)
  assert.match(doubles,/FROM public\.player_doubles_rankings r/)
  assert.match(doubles,/JOIN public\.players p ON p\.id=r\.player_id/i)
  assert.match(doubles,/is_tennis_zero_point_guest_rank_tie_v1\(p\.owner_user_id,r\.ranking_points\) asc/i)
  assert.match(doubles,/FUNCTION public\.get_tournament_doubles_hub_v1/)
  assert.match(doubles,/is_tennis_zero_point_guest_rank_tie_v1\(p\.owner_user_id,dr\.ranking_points\) asc/i)
  assert.match(doubles,/is_tennis_zero_point_guest_rank_tie_v1\(p\.owner_user_id,coalesce\(pr\.ranking_points,0\)\) asc/i)
})

test('H01: no guest ranking points are manufactured and guest competition calls keep expiry',()=>{
  assert.match(previous,/NEW\.player_type<>'human'/)
  assert.match(previous,/public\.assert_my_tennis_guest_access_v1\(\)/)
  assert.match(expiry,/'apply_to_tournament_v3'/)
  assert.match(expiry,/'apply_late_tournament_entry_v1'/)
  assert.doesNotMatch(singles,/UPDATE public\.player_rankings\s+SET\s+ranking_points/i)
  assert.doesNotMatch(doubles,/UPDATE public\.player_rankings\s+SET\s+ranking_points/i)
  assert.match(checklist,/Existing 836 player positions verified unchanged/)
  assert.match(checklist,/Keep Guest Mode disabled/)
})
