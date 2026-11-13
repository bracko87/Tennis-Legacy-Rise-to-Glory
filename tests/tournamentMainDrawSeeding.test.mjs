import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const migration=readFileSync(
 new URL('../supabase/migrations/20261113103500_restore_tournament_main_draw_seed_layouts.sql',import.meta.url),'utf8'
)
test('restore all supported 16/32/64/128-player seed layouts',()=>{
 for(const [size,group,seedEnd] of [[16,3,4],[32,4,8],[64,6,16],[128,8,32]]){
  assert.ok(migration.includes(`(${size},${group},`),`missing ${size} draw group ${group}`)
  assert.ok(migration.includes(`when ${size} then ${seedEnd}`),`missing ${size} seed count`)
 }
 assert.match(migration,/on conflict \(draw_size,group_no\) do update/i)
 assert.match(migration,/on conflict \(draw_size,bracket_slot\) do update/i)
})
test('future draw publication never silently proceeds when seed layout is missing',()=>{
 assert.match(migration,/v_expected_seed_count/)
 assert.match(migration,/v_configured_seed_count<>v_expected_seed_count/)
 assert.match(migration,/v_configured_slot_count<>v_expected_seed_count/)
 assert.match(migration,/raise exception 'Missing or invalid main draw seed layout/)
 assert.match(migration,/v_main_seeds:=least\(v_main_seeds,v_main_count\)/)
})
test('do not redraw existing started tournaments or rewrite seeded players or results',()=>{
 const installation=migration.split('CREATE OR REPLACE FUNCTION public.publish_tournament_draw_v1')[0]
 assert.doesNotMatch(installation,/\bdelete\s+from\s+public\.tournament_matches\b/i)
 assert.doesNotMatch(installation,/\btruncate\s+public\.tournament_matches\b/i)
 assert.doesNotMatch(installation,/\bupdate\s+public\.tournament_matches\b/i)
 assert.doesNotMatch(installation,/\bupdate\s+public\.tournament_draw_publications\b/i)
 assert.doesNotMatch(installation,/\bupdate\s+public\.player_rankings\b/i)
 assert.doesNotMatch(installation,/\btruncate\s+public\.tournament_draw_seed_groups\b/i)
})
