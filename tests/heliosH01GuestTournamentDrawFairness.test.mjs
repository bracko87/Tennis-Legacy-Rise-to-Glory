import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8')
const draw=read('supabase/migrations/20261120190500_helios_guest_draw_seeding_fairness.sql')
const priorRank=read('supabase/migrations/20261120184500_helios_guest_zero_point_rank_fairness.sql')
const checklist=read('HELIOS_CHECKLIST.md')
const doc=read('docs/HELIOS_GUEST_TOURNAMENT_FAIRNESS.md')

test('H01: draw publication uses points-first server-authorized guest tie-break',()=>{
  assert.match(draw,/CREATE OR REPLACE FUNCTION public\.publish_tournament_draw_v1\(p_competition_id uuid\)/)
  assert.match(draw,/row_number\(\) over\(order by coalesce\(pr\.ranking_points,0\) desc,public\.is_tennis_zero_point_guest_rank_tie_v1\(p\.owner_user_id,coalesce\(pr\.ranking_points,0\)\) asc,coalesce\(pr\.seed_rating,0\) desc,p\.created_at asc,p\.id asc\)/)
  assert.match(draw,/update public\.tournament_entries e set ranking_position_snapshot=w\.rank_position/i)
  assert.match(draw,/order by e\.ranking_position_snapshot nulls last,e\.player_id limit v_main_seeds/i)
  assert.match(draw,/order by e\.ranking_position_snapshot nulls last,e\.player_id limit v_q_seeds/i)
  assert.match(draw,/Missing or invalid main draw seed layout/)
})

test('H01: application field uses same tie-break as final draw, not a user-supplied guest flag',()=>{
  assert.match(priorRank,/FUNCTION public\.get_player_world_rank_position_v1/)
  assert.match(priorRank,/FUNCTION public\.get_tournament_application_field_v1/)
  assert.match(priorRank,/FROM auth\.users u/)
  assert.match(priorRank,/u\.is_anonymous/)
  assert.match(draw,/from public\.players p left join public\.player_rankings pr/i)
  assert.doesNotMatch(draw,/UPDATE public\.player_rankings/)
  assert.doesNotMatch(draw,/UPDATE public\.player_doubles_rankings/)
})

test('H01: synthetic zero-point guest is last; earned points remain primary',()=>{
  const players=[
    {id:'a',points:0,guest:0,seed:100,created:1},
    {id:'b',points:0,guest:0,seed:0,created:2},
    {id:'g',points:0,guest:1,seed:999999,created:3},
    {id:'c',points:2,guest:0,seed:0,created:4},
  ]
  const order=xs=>[...xs].sort((a,b)=>b.points-a.points || (a.points===0?a.guest-b.guest:0) || b.seed-a.seed || a.created-b.created || a.id.localeCompare(b.id)).map(x=>x.id)
  assert.deepEqual(order(players),['c','a','b','g'])
  assert.deepEqual(order(players.map(x=>x.id==='g'?{...x,points:3}:x)),['g','c','a','b'])
})

test('H01: no live match claim and remaining policy gaps are tracked',()=>{
  assert.match(doc,/zero.*anonymous users.*guest trials.*tournament applications.*draws.*matches/i)
  assert.match(doc,/automatic scheduled match simulation can still operate/)
  assert.match(checklist,/H01 tournament draw selection\/seeding \(current\)/)
  assert.match(checklist,/Keep Guest Mode disabled/)
})
