import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = path => readFileSync(new URL('../'+path, import.meta.url), 'utf8')
const migration = read('supabase/migrations/20261120124500_helios_h03_google_oauth_prepare.sql')
const hook = read('src/hooks/useGoogleSignInAvailability.ts')
const login = read('src/pages/auth/Login.tsx')
const register = read('src/pages/auth/Register.tsx')
const checklist = read('HELIOS_CHECKLIST.md')
const plan = read('docs/HELIOS_H03_GOOGLE_ACTIVATION.md')

test('H03: Google OAuth is disabled by default and fail closed on errors', () => {
  assert.match(migration,/google_oauth_enabled boolean NOT NULL DEFAULT false/)
  assert.match(migration,/get_public_google_oauth_status_v1/)
  assert.match(migration,/GRANT EXECUTE ON FUNCTION public\.get_public_google_oauth_status_v1\(\) TO anon, authenticated/)
  assert.match(hook,/useState\(false\)/)
  assert.match(hook,/!error && data === true/)
  assert.match(hook,/setEnabled\(false\)/)
  assert.match(login,/\{googleAvailable && \(/)
  assert.match(register,/\{googleAvailable && !inviteToken && !getStoredReferralCode\(\) && \(/)
})

test('H03: first-time Google users get stable, unique usernames without changing email signup validation',()=>{
  assert.match(migration,/new\.raw_app_meta_data->>'provider'='google'/)
  assert.match(migration,/v_username:='google_'\|\|left\(replace\(new\.id::text,'-',''\),16\)/)
  assert.match(migration,/if v_username !~ '\^\[A-Za-z0-9_\.\-\]\{3,24\}\$' then/)
  assert.match(migration,/birthday_month,birthday_day,birthday_year/)
  assert.match(migration,/v_month is null and v_year is not null/)
  assert.match(migration,/insert into public\.profiles/)
})

test('H03: OAuth redirects to protected player-aware route without reassigning accounts',()=>{
  assert.match(hook,/supabase\.auth\.signInWithOAuth/)
  assert.match(hook,/provider: 'google'/)
  assert.match(hook,/new URL\('\/create-player', window\.location\.origin\)/)
  assert.doesNotMatch(hook,/linkIdentity|updateUser|updateAuthUser|signOut/)
  assert.match(login,/startTennisGoogleSignIn/)
  assert.match(register,/startTennisGoogleSignIn/)
  assert.match(register,/getStoredReferralCode\(\)/)
  assert.match(plan,/same `auth\.users\.id`/)
  assert.match(plan,/disabled/)
  assert.match(checklist,/\*\*H03\*\*/)
})
