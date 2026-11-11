import assert from 'node:assert/strict'
import test from 'node:test'
import { readFileSync } from 'node:fs'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')

test('public registration route follows the server registration switch', () => {
  const app = read('../src/App.tsx')
  assert.ok(app.includes('<Route path="/register" element={<AnonymousOnly><RegisterRoute /></AnonymousOnly>} />'))
  assert.ok(app.includes("const availability = usePublicRegistrationStatus()"))
  assert.ok(app.includes("availability === 'open' ? <RegisterPage /> : <Navigate to=\"/login\" replace />"))
  assert.ok(!app.includes('<Route path="/register" element={<RegisterPage />} />'))
})

test('registration gate is read-only and fails closed when the server is unavailable', () => {
  const hook = read('../src/hooks/usePublicRegistrationStatus.ts')
  assert.ok(hook.includes("supabase.rpc('get_public_registration_status_v1')"))
  assert.ok(hook.includes("!error && data === true ? 'open' : 'closed'"))
  assert.ok(hook.includes("useState<RegistrationAvailability>('loading')"))
  const migration = read('../supabase/migrations/20261111170000_tennis_public_registration_status_read_only.sql')
  assert.ok(migration.includes('get_public_registration_status_v1'))
  assert.ok(migration.includes('FROM public.registration_control WHERE singleton_id=true'))
  assert.ok(migration.includes('GRANT EXECUTE ON FUNCTION'))
  assert.ok(!migration.includes('GRANT SELECT ON public.registration_control'))
})

test('public entry points show account creation only when registration is open', () => {
  const home = read('../src/pages/Home.tsx')
  const login = read('../src/pages/auth/Login.tsx')
  const footer = read('../src/components/layout/MarketingFooter.tsx')
  for (const [name, content] of [['home', home], ['login', login], ['footer', footer]]) {
    assert.ok(content.includes("usePublicRegistrationStatus()"), name)
    assert.ok(content.includes("registrationAvailability === 'open'"), name)
    assert.ok(content.includes('to="/register"'), name)
    assert.ok(content.includes("t('authPages.login.registrationClosed')"), name)
  }
  const header = read('../src/components/layout/MarketingHeader.tsx')
  assert.ok(header.includes('to="/login"'))
})

test('profile creation remains separate from account registration and clock pause', () => {
  const login = read('../src/pages/auth/Login.tsx')
  const app = read('../src/App.tsx')
  const css = read('../src/styles/home-branding.css')
  assert.ok(login.includes("navigate(player ? '/game/overview' : '/create-player'"))
  assert.ok(app.includes('<Route path="/create-player" element={<RequireNoPlayer><CreatePlayerRoute /></RequireNoPlayer>} />'))
  assert.ok(css.includes('.tlg-prelaunch-registration-note'))
})
