import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')

test('application field shows unique live ATP/WTA positions, preserves application snapshot separately', () => {
  const sql = read('../supabase/migrations/20261111205500_show_current_world_rank_in_tournament_field.sql')
  assert.match(sql, /rw\.current_world_rank::integer world_rank/)
  assert.match(sql, /a\.ranking_position_snapshot::integer application_rank_at_submission/)
  assert.match(sql, /row_number\(\) over\(order by rw\.current_world_rank,a\.created_at,a\.id\)/)
  assert.doesNotMatch(sql, /coalesce\(a\.ranking_position_snapshot,rw\.current_world_rank\)::integer world_rank/)
})

test('AI event choices retain ranking eligibility but account for variation and field crowding', () => {
  const sql = read('../supabase/migrations/20261111211000_spread_ai_tournament_choices_without_losing_rank_rules.sql')
  assert.match(sql, /ai_tournament_rank_floor_v1\(p_category\)/)
  assert.match(sql, /ai_tournament_rank_ceiling_v1\(p_category\)/)
  assert.match(sql, /241\)::integer/)
  assert.match(sql, /750 \* power/)
  assert.match(sql, /candidate\.live_count::numeric/)
  assert.match(sql, /candidate\.soft_cap/)
  assert.match(sql, /and a\.application_source like 'ai%'/)
  assert.match(sql, /candidate\.fit_score>-100000/)
})

test('direct multi-week main-draw participants may use qualification week, but qualifiers remain occupied', () => {
  const sql = read('../supabase/migrations/20261111212400_direct_main_draw_frees_qualification_week.sql')
  assert.match(sql, /get_player_effective_competition_window_v1/)
  assert.match(sql, /te\.draw_type='main_draw'/)
  assert.match(sql, /ph\.main_draw_week>ph\.qualification_week/)
  assert.match(sql, /a\.direct_main AND NOT q\.did_qualify/)
  assert.match(sql, /m\.draw_type='qualification'/)
  assert.match(sql, /get_player_effective_competition_window_v1\(te\.player_id,te\.competition_id\)/)
  assert.match(sql, /get_player_effective_competition_window_v1\(a\.player_id,a\.competition_id\)/)
  assert.doesNotMatch(sql, /\b(?:UPDATE|DELETE FROM|TRUNCATE)\s+public\.tournament_(?:matches|entries|applications)\b/i)
})
