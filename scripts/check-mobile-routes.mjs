import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const app = readFileSync(new URL('../src/App.tsx', import.meta.url), 'utf8')
const matrix = JSON.parse(readFileSync(new URL('../docs/mobile-route-audit.json', import.meta.url), 'utf8'))
const configured = [...app.matchAll(/<Route\s+path="([^"]+)"/g)].map((match) => match[1])
const inventoried = matrix.routes.map((entry) => entry.path)

assert.equal(configured.length, new Set(configured).size, 'App.tsx contains duplicate routes')
assert.equal(inventoried.length, new Set(inventoried).size, 'Mobile route inventory contains duplicates')
assert.deepEqual(
  inventoried.slice().sort(),
  configured.slice().sort(),
  'Every configured route (including new/removed routes) must appear exactly once in the mobile QA inventory'
)
assert.ok(matrix.workflows.length > 0, 'Mobile route audit must also cover non-URL workflows')
for (const entry of matrix.routes) {
  assert.ok(
    ['pending_device_validation', 'passed', 'blocked', 'not_applicable'].includes(entry.status),
    'Invalid route QA status: ' + entry.path
  )
}
const pendingRoutes = matrix.routes.filter((entry) => entry.status === 'pending_device_validation').length
const pendingFlows = matrix.workflows.filter((flow) => flow.status === 'pending_device_validation').length
console.log(
  'Mobile route inventory matches ' + configured.length + ' real routes; ' +
  pendingRoutes + ' routes and ' + pendingFlows +
  ' workflows still await device/browser verification.'
)
