import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const panel = readFileSync(new URL('../src/components/manager/AdminSeasonMigrationPanel.tsx', import.meta.url), 'utf8')
const css = readFileSync(new URL('../src/styles/admin-season-migration.css', import.meta.url), 'utf8')

test('all 13 rollover steps still display live execution journal statuses, not fabricated completion', () => {
  assert.match(panel, /13 migration checkpoints/)
  assert.match(panel, /status\?\.steps\?\.find\(\(entry\) => entry\.step_key === step\.id\)\?\.status/)
  assert.match(panel, /Live execution/)
  assert.doesNotMatch(panel, /setStatus\(\{.*completed.*\}\)/s)
})

test('preparation is a separate database-fed status and is never called live execution', () => {
  assert.match(panel, /step_preparation\?: Record<string, PreparationStep>/)
  assert.match(panel, /status\?\.step_preparation\?\.\[step\.id\]\?\.label/)
  assert.match(panel, /status\?\.step_preparation\?\.\[step\.id\]\?\.detail/)
  assert.match(panel, /A tested step is not the same as an executed step/)
  assert.match(panel, /Preparation/)
})

test('two statuses remain readable at mobile sizes', () => {
  assert.match(css, /\.tlg-admin-season-status-pair/)
  assert.match(css, /\.tlg-admin-season-execution/)
  assert.match(css, /@media\(max-width:390px\)/)
})

test('migration remains read-only from the dashboard', () => {
  assert.match(panel, /Read-only migration plan/)
  assert.match(panel, /get_admin_season_transition_readiness_v1/)
  assert.doesNotMatch(panel, /\.rpc\(['"](?:execute_tennis_season1_to2_atomic_v1|reconcile_tennis_season2_week1_draws_v1)/)
})
