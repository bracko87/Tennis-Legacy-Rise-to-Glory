import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parsePrivateLifeLocalStatus } from '../scripts/private-life-local-config.mjs'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const fakeKey = 'sb_publishable_local_fixture_only_no_production_access'

test('CMD local developer launch extracts ONLY the sandbox API and public key', () => {
  const output = [
    'API_URL="http://127.0.0.1:54331"',
    'ANON_KEY="eyJthisisafakeanonjwtfortestsnotarealkey"',
    'PUBLISHABLE_KEY="' + fakeKey + '"',
    'SERVICE_ROLE_KEY="do_not_copy_this"',
    'SECRET_KEY="do_not_copy_this_either"',
  ].join('\r\n')
  assert.deepEqual(parsePrivateLifeLocalStatus(output), {
    url: 'http://127.0.0.1:54331',
    publishableKey: fakeKey,
  })
})
test('local developer launcher never accepts production or unrelated endpoints', () => {
  for (const url of [
    'https://cwfznmroiqcyhfkfcrow.supabase.co',
    'http://127.0.0.1:54321',
    'http://evil.example:54331',
    'http://127.0.0.1:54331@evil.example',
    'http://127.0.0.1:54331/other-path',
  ]) {
    assert.throws(
      () => parsePrivateLifeLocalStatus('API_URL=' + url + '\nPUBLISHABLE_KEY=' + fakeKey),
      /non-sandbox backend/
    )
  }
})
test('local developer launcher never uses service-role key as the frontend key', () => {
  assert.throws(() => parsePrivateLifeLocalStatus(
    'API_URL=http://127.0.0.1:54331\nSERVICE_ROLE_KEY=eyJservice-role-fake'
  ), /browser-safe/)
  assert.throws(() => parsePrivateLifeLocalStatus(
    'API_URL=http://127.0.0.1:54331\nANON_KEY=sb_secret_never_serve_in_browser'
  ), /browser-safe/)
})
test('regular owner three-command workflow stays untouched', () => {
  const packageJson = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'))
  assert.equal(packageJson.scripts.build, 'node scripts/build.mjs --production')
  assert.equal(packageJson.scripts.dev, 'node scripts/build.mjs')
  assert.equal(packageJson.scripts['dev:private-life'], 'node scripts/private-life-dev.mjs')
  const localDev = fs.readFileSync(path.join(root, 'scripts/private-life-dev.mjs'), 'utf8')
  assert.match(localDev, /\.private-life-sandbox/)
  assert.match(localDev, /npx supabase status -o env/)
  assert.match(localDev, /await import\('\.\/build\.mjs'\)/)
  assert.doesNotMatch(localDev, /supabase db push|db reset --linked|SERVICE_ROLE_KEY/)
})
