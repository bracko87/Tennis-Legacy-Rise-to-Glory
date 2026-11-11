import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')

test('all new human players begin with zero rank seed, not the historical artificial top-ten seed', () => {
  const sql = read('../supabase/migrations/20261111224500_new_human_player_starts_last_in_world_ranking.sql')
  assert.match(sql, /new\.player_type='ai'/)
  assert.match(sql, /else 0\s+end/)
  assert.doesNotMatch(sql, /else 45000\s+end/)
  assert.match(sql, /insert into public\.player_rankings\(player_id,seed_rating\)/)
})

test('weekly year-end ranking snapshots break zero-point ties by creation date', () => {
  const sql = read('../supabase/migrations/20261111224500_new_human_player_starts_last_in_world_ranking.sql')
  assert.match(sql, /coalesce\(pr\.ranking_points,0\) desc, coalesce\(pr\.seed_rating,0\) desc, p\.created_at asc, p\.id/)
  assert.match(sql, /public\.capture_world_ranking_snapshot_internal_v1/)
})

test('the actual live ranking and sponsor rules remain based on accumulated points and rank tiers', () => {
  const file = read('../supabase/migrations/20261111224500_new_human_player_starts_last_in_world_ranking.sql')
  assert.doesNotMatch(file, /\b(?:UPDATE|DELETE FROM|TRUNCATE)\s+public\.(?:players|game_clock|tournament_matches|player_sponsor_contracts)/i)
  const sponsor = read('../supabase/migrations/20261111161000_tennis_sponsor_ranking_and_local_eligibility.sql')
  assert.match(sponsor, /sponsor_offer_rank_v1/)
  assert.match(sponsor, /NOT s\.is_worldwide/)
})
