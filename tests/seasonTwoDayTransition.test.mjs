import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')
const controller = read('../supabase/migrations/20261111120000_season_transition_two_real_days_v1.sql')
const windows = read('../supabase/migrations/20261111121000_season_transition_preseason_january_applications_v1.sql')
const week1 = read('../supabase/migrations/20261111132000_season2_week1_open_until_first_match_safe_redraw.sql')
const boundary = read('../src/components/season/SeasonMaintenanceBoundary.tsx')
const css = read('../src/styles/season-maintenance.css')
const notice = read('../src/components/season/SeasonTransitionNotice.tsx')

test('two separate 24h real-world windows are server-managed, not browser timers', () => {
  assert.match(controller, /planned_reopen_at=now\(\)\+interval '24 hours'/)
  assert.match(controller, /preseason_ends_at=now\(\)\+interval '24 hours'/)
  assert.match(controller, /now\(\)>=v_control\.planned_reopen_at/)
  assert.match(controller, /now\(\)>=v_control\.preseason_ends_at/)
  assert.match(controller, /cron\.schedule\('tennis-season-transition-two-day-v1'/)
  assert.doesNotMatch(boundary, /setTimeout\(\(\) => supabase\.rpc/)
})

test('migration can never be assumed complete just because 24h elapsed', () => {
  assert.match(controller, /v_run\.status='completed'/)
  assert.match(controller, /v_run\.operator_approved AND v_run\.execution_enabled/)
  assert.match(controller, /v_run\.finance_verified AND v_run\.contracts_verified/)
  assert.match(controller, /s\.step_key='postcheck' AND s\.status='completed'/)
  assert.match(controller, /'phase','migration_delayed'/)
  assert.match(controller, /v_clock\.season=v_control\.target_season/)
})

test('game time never progresses during either 24h stage', () => {
  assert.match(controller, /s\.status IN\('active','extended','preseason'\) THEN 0::numeric/)
  assert.match(controller, /s\.source_season::bigint\*31622400-1/)
  assert.match(controller, /WHEN s\.status='preseason' THEN \(s\.target_season-1\)::bigint\*31622400/)
  assert.match(controller, /is_paused=true,speed_multiplier=2/)
  assert.match(controller, /is_paused=false,speed_multiplier=2/)
  assert.match(controller, /stop_at_total_seconds=v_control\.target_season::bigint\*31622400-1/)
})

test('Week 1 exclusively is booked in its own season until Jan 3, with first match at 10:00', () => {
  assert.match(week1, /IF v_first_week=1 AND v_season>=2 THEN/)
  assert.match(week1, /v_open := \(v_season-1\)::bigint\*31622400/)
  assert.match(week1, /v_close := v_first_start::bigint\*86400 \+ 6\*3600/)
  assert.match(week1, /v_late_close := v_first_start::bigint\*86400 \+ 7\*3600/)
  assert.match(week1, /v_draw := v_first_start::bigint\*86400 \+ 8\*3600/)
  assert.match(week1, /CASE WHEN v_first_week=1 AND v_season>=2 THEN 10\*3600 ELSE 0 END/)
  assert.match(week1, /v_count<>2 THEN RAISE EXCEPTION 'Expected two lifecycle selection sites/)
  assert.match(week1, /process_minimum_tournament_fields_v1/)
})

test('premature Season 2 Week 1 drawings are archived and reset only if no match was played', () => {
  assert.match(week1, /CREATE TABLE IF NOT EXISTS control_center_private\.tennis_season2_week1_draw_deferral_archive_v1/)
  assert.match(week1, /FROM public\.tournament_matches m/)
  assert.match(week1, /m\.started_at IS NOT NULL/)
  assert.match(week1, /m\.status NOT IN \('scheduled','bye','cancelled'\)/)
  assert.match(week1, /original_data jsonb NOT NULL/)
  assert.match(week1, /'applications'/)
  assert.match(week1, /'matches'/)
  assert.match(week1, /'travel'/)
  assert.match(week1, /a\.status IN\('accepted_main_draw','accepted_qualification'\)/)
  assert.match(week1, /IF v_human_apps<>1 THEN RAISE EXCEPTION 'Human tournament preference not preserved'/)
  assert.match(week1, /WHERE e\.season_number=2 AND ss\.season_week=1/)
})

test('maintenance blocks routes and displays real-world reopening; preseason allows login', () => {
  assert.match(boundary, /supabase\.rpc\('get_tennis_public_maintenance_v1'\)/)
  assert.match(boundary, /supabase\.auth\.signOut\(\{ scope: 'local' \}\)/)
  assert.match(boundary, /if \(state\.maintenance_active\) return <MaintenanceScreen/)
  assert.match(boundary, /preseasonPopupVisible/)
  assert.match(boundary, /You can sign in, prepare your player/)
  assert.match(boundary, /formatDateTime\(state\.preseason_ends_at\)/)
  assert.match(boundary, /to="\/game\/calendar"/)
  assert.match(css, /\.tlg-preseason-modal-backdrop/)
  assert.match(notice, /notice\.phase === 'completed'/)
})

test('old development popup is not mounted and preparation notice reflects real game-time pause', () => {
  const header = read('../src/components/layout/MarketingHeader.tsx')
  assert.doesNotMatch(header, /<BetaDisclaimer \/>/)
  assert.match(boundary, /its[\s\S]*?current in-game time/)
  assert.match(boundary, /formatDateTime\(state.preseason_ends_at\)/)
})
