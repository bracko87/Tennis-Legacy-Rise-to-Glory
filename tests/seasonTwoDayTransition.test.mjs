import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')
const controller = read('../supabase/migrations/20261111120000_season_transition_two_real_days_v1.sql')
const windows = read('../supabase/migrations/20261111121000_season_transition_preseason_january_applications_v1.sql')
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

test('new season January applications remain open with stable deadlines and no draw rewriting', () => {
  assert.match(windows, /v_first_week BETWEEN 1 AND 4/)
  assert.match(windows, /c\.target_season=v_season AND c\.preseason_starts_at IS NOT NULL/)
  assert.match(windows, /NOT EXISTS\([\s\S]*?tournament_draw_publications/)
  assert.match(windows, /v_open := least\(v_open/)
  assert.match(windows, /v_first_week=1/)
  assert.match(windows, /v_draw := \(v_season-1\)::bigint\*31622400 \+ 86400 \+ 22\*3600/)
})

test('maintenance blocks routes and displays real-world reopening; preseason allows login', () => {
  assert.match(boundary, /supabase\.rpc\('get_tennis_public_maintenance_v1'\)/)
  assert.match(boundary, /supabase\.auth\.signOut\(\{ scope: 'local' \}\)/)
  assert.match(boundary, /if \(state\.maintenance_active\) return <MaintenanceScreen/)
  assert.match(boundary, /preseasonPopupVisible/)
  assert.match(boundary, /You can sign in again/)
  assert.match(boundary, /formatDateTime\(state\.preseason_ends_at\)/)
  assert.match(boundary, /to="\/game\/calendar"/)
  assert.match(css, /\.tlg-preseason-modal-backdrop/)
  assert.match(notice, /notice\.phase === 'completed'/)
})
