import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (file) => readFileSync(new URL(file, import.meta.url), 'utf8')
const app = read('../src/App.tsx')
const home = read('../src/pages/Home.tsx')
const boundary = read('../src/components/season/SeasonMaintenanceBoundary.tsx')
const styles = read('../src/styles/season-maintenance.css')

test('maintenance boundary protects all login and gameplay routes before auth provider mounts', () => {
  const guard = app.indexOf('<SeasonMaintenanceBoundary>')
  const auth = app.indexOf('<AuthProvider>')
  const routes = app.indexOf('<Routes>')
  assert.ok(guard > -1 && auth > guard && routes > auth)
  assert.ok(app.indexOf('</AuthProvider>') < app.indexOf('</SeasonMaintenanceBoundary>'))
  assert.ok(app.includes('import { SeasonMaintenanceBoundary }'))
})

test('maintenance data is read-only, server-owned and refreshed for existing sessions', () => {
  assert.ok(boundary.includes("supabase.rpc('get_tennis_public_maintenance_v1')"))
  assert.ok(boundary.includes('maintenance_active'))
  assert.ok(boundary.includes('window.setInterval('))
  assert.ok(boundary.includes("window.addEventListener('focus'"))
  assert.ok(boundary.includes("supabase.auth.signOut({ scope: 'local' })"))
  assert.ok(!boundary.includes('set_tennis_public_maintenance_v1'))
  assert.ok(!boundary.includes('service_role'))
})

test('homepage announces future downtime with real-world reopening dates', () => {
  assert.ok(home.includes('<SeasonMaintenanceAnnouncement />'))
  assert.ok(boundary.includes('announcement_visible'))
  assert.ok(boundary.includes('24 real-world hours'))
  assert.ok(boundary.includes('formatDateTime(state.starts_at)'))
  assert.ok(boundary.includes('formatDateTime(state.estimated_reopen_at)'))
})

test('late migration cannot silently auto-reopen the game', () => {
  assert.ok(boundary.includes('reopening_delayed'))
  assert.ok(boundary.includes('Maintenance is taking longer than planned'))
  assert.ok(boundary.includes('The game will reopen only when the migration is verified'))
  assert.ok(!boundary.includes('localStorage.setItem'))
})

test('maintenance page is readable on mobile and does not request player data', () => {
  assert.ok(styles.includes('.tlg-season-maintenance-page'))
  assert.ok(styles.includes('.tlg-season-maintenance-announcement'))
  assert.ok(styles.includes('@media(max-width: 600px)'))
  assert.ok(!boundary.includes(".from('players')"))
  assert.ok(!boundary.includes('get_user_finance'))
})
