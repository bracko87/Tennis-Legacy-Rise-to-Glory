import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')

test('season opening extends both application windows without touching the game clock or tournament results', () => {
  const sql = read('../supabase/migrations/20261111182000_first_two_season_weeks_entry_windows.sql')
  assert.match(sql, /IF \(v_first_week=1 AND v_season=1\) OR v_first_week=2 THEN/)
  assert.match(sql, /v_open:=\(v_season-1\)::bigint \* 31622400/)
  assert.match(sql, /v_close:=\(v_first_start-1\)::bigint\*86400\+16\*3600/)
  assert.match(sql, /v_late_close:=\(v_first_start-1\)::bigint\*86400\+18\*3600/)
  assert.match(sql, /v_draw:=\(v_first_start-1\)::bigint\*86400\+22\*3600/)
  assert.match(sql, /IF v_first_week=1 AND v_season>=2 THEN/)
  assert.doesNotMatch(sql, /\bUPDATE\s+(?:public\.)?(?:game_clock|tournament_matches|tournament_entries)\b/i)
})

test('Premium Tournament Watchlist is RPC-only and reminder worker stays inactive during preseason', () => {
  const sql = read('../supabase/migrations/20261111183500_enable_premium_tournament_watchlist_paused.sql')
  const hook = read('../src/hooks/usePremiumTournamentWatchlist.ts')
  assert.match(sql, /create table if not exists public\.player_premium_tournament_watches/)
  assert.match(sql, /enable row level security/)
  assert.match(sql, /get_premium_tournament_watchlist_v1/)
  assert.match(sql, /set_premium_tournament_watch_v1/)
  assert.match(sql, /grant execute on function public\.get_premium_tournament_watchlist_v1\(uuid\) to authenticated/)
  assert.match(sql, /grant execute on function public\.set_premium_tournament_watch_v1\(uuid,uuid,boolean\) to authenticated/)
  assert.match(sql, /cron\.alter_job\(v_job_id,active=>false\)/)
  assert.ok(hook.includes("supabase.rpc('get_premium_tournament_watchlist_v1'"))
  assert.ok(hook.includes("supabase.rpc('set_premium_tournament_watch_v1'"))
})

test('Season 1 Weeks 1 and 2 monitoring, auto-repair, and minimum-field checks honor late entry deadlines', () => {
  const sql = read('../supabase/migrations/20261111185000_season1_early_weeks_entry_pipeline_due_alignment.sql')
  assert.match(sql, /check_tournament_entry_pipeline_health_v1/)
  assert.match(sql, /auto_repair_due_tournament_entry_pipelines_v1/)
  assert.match(sql, /process_minimum_tournament_fields_v1/)
  assert.match(sql, /mod\(r\.start_abs,366\) IN \(2,9\)/)
  assert.match(sql, /min\(ss\.season_week\) IN \(1,2\)/)
  assert.match(sql, /late_close_game_second/)
  assert.match(sql, /ELSE \(\(r\.start_abs-8\)::bigint\*86400\)\+\(18\*3600\)/)
  assert.match(sql, /RAISE EXCEPTION 'Unexpected % procedure version/)
  assert.doesNotMatch(sql, /\bUPDATE\s+(?:public\.)?(?:game_clock|tournament_matches|tournament_entries)\b/i)
})
