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
    assert.ok(content.includes(name === 'home' ? "t('home.hero.betaNotice')" : "t('authPages.login.registrationClosed')"), name)
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

test('homepage groups action buttons and places final beta notice below the actions', () => {
  const home = read('../src/pages/Home.tsx')
  const css = read('../src/styles/home-branding.css')
  const actions = home.match(/<div className="tlg-hero-actions">([\s\S]*?)<\/div>/)?.[1]
  assert.ok(actions, 'hero action group is present')
  assert.ok(actions.includes('to="/login"'), 'Sign In in action group')
  assert.ok(actions.includes("t('home.hero.explore')"), 'Explore in action group')
  assert.ok(actions.includes('to="/register"'), 'Create Account in same action group when enabled')
  assert.ok(actions.includes("registrationAvailability === 'open'"), 'Register conditional')
  assert.ok(home.includes("registrationAvailability === 'closed' && <BetaDisclaimer />"), 'Beta disclaimer when closed')
  assert.ok(home.includes("t('home.hero.betaNotice')"), 'Beta notice below buttons')
  assert.ok(css.includes('flex-wrap: nowrap'), 'desktop actions on one row')
  assert.ok(css.includes('white-space: nowrap'), 'button labels do not wrap')
  const modal = read('../src/components/marketing/BetaDisclaimer.tsx')
  assert.ok(modal.includes('final phase of testing'))
  assert.ok(modal.includes('New account registration is closed until the public launch'))
  assert.ok(!modal.includes('we are not close to the final release yet'))
})

test('beta launch messaging is available in all eight translations', () => {
  for (const lang of ['en', 'de', 'es', 'fr', 'it', 'pt', 'ru', 'sr']) {
    const translation = read(`../src/i18n/locales/${lang}.ts`)
    assert.ok(translation.includes('betaNotice'), `home beta notice missing in ${lang}`)
  }
})


test('November 23 open-registration notice appears on homepage and signup page',()=>{
  const home=read('../src/pages/Home.tsx')
  const register=read('../src/pages/auth/Register.tsx')
  const notice=read('../src/components/marketing/RegistrationLaunchNotice.tsx')
  const noticeCss=read('../src/styles/registration-launch-notice.css')
  assert.ok(home.includes("registrationAvailability === 'open' && ("))
  assert.ok(home.includes('<RegistrationLaunchNotice modal />'))
  assert.ok(register.includes('<RegistrationLaunchNotice compact />'))
  assert.ok(notice.includes('Official launch: 23 November 2026.'))
  assert.ok(notice.includes('Registration is open to everyone.'))
  assert.ok(notice.includes('You can sign up and create your tennis player'))
  assert.ok(notice.includes('Season 1, January 1, 00:00'))
  assert.ok(notice.includes('2× speed when the game begins'))
  assert.ok(notice.includes("clock.speedMultiplier === 0"))
  assert.ok(noticeCss.includes('.tlg-registration-launch-notice'))
  for(const lang of ['en','de','es','fr','it','pt','ru','sr']){
    assert.ok(notice.includes(`  ${lang}: {`), `missing notice translation ${lang}`)
  }
})

test('opening registration is not accidentally blocked by legacy CSS or beta overlay',()=>{
  const css=read('../src/styles/public-beta.css')
  const betaGate=read('../src/components/marketing/PublicBetaGate.tsx')
  assert.doesNotMatch(css,/a\[href=["']\/register["']\]\s*\{[^}]*display\s*:\s*none/i)
  assert.ok(betaGate.includes("registrationAvailability !== 'closed'"))
  const home=read('../src/pages/Home.tsx')
  assert.ok(home.includes("registrationAvailability === 'closed' && <BetaDisclaimer />"))
  assert.ok(home.includes("registrationAvailability === 'open' && ("))
  const login=read('../src/pages/auth/Login.tsx')
  assert.ok(login.includes("registrationAvailability === 'open'"))
  const app=read('../src/App.tsx')
  assert.ok(app.includes("availability === 'open' ? <RegisterPage />"))
})

test('prelaunch public game clock is labelled paused rather than live or 0x',()=>{
  const home=read('../src/pages/Home.tsx')
  const display=read('../src/components/marketing/HomeLiveEnhancements.tsx')
  assert.ok(home.includes('Season 1 · January 1'))
  assert.ok(home.includes('<time>00:00</time>'))
  assert.ok(home.includes('month === seasonMonths[0]'))
  assert.ok(display.includes("clock.speedMultiplier === 0 ? ' Game time paused' : ' Live game time'"))
  assert.ok(display.includes('The saved speed is 2×.'))
})

test('prelaunch popup expires precisely at November 23 at 07:00 German time',()=>{
  const notice = read('../src/components/marketing/RegistrationLaunchNotice.tsx')
  const home = read('../src/pages/Home.tsx')
  assert.ok(notice.includes("2026-11-23T07:00:00+01:00"))
  assert.ok(notice.includes('TENNIS_LAUNCH_AT - Date.now()'))
  assert.ok(notice.includes('setBeforeLaunch(false)'))
  assert.ok(notice.includes('if (!beforeLaunch) return null'))
  assert.ok(notice.includes('createPortal('))
  assert.ok(notice.includes('aria-modal="true"'))
  assert.ok(notice.includes("window.sessionStorage.setItem(PRELAUNCH_NOTICE_DISMISSED, '1')"))
  assert.ok(notice.includes("event.key === 'Escape'"))
  assert.ok(notice.includes('copy.closeLabel'))
  assert.ok(notice.includes('copy.continueLabel'))
  assert.ok(home.includes('<RegistrationLaunchNotice modal />'))
  assert.ok(!home.includes('<RegistrationLaunchNotice />'))
  assert.ok(!notice.includes('UPDATE public.game_clock'))
  assert.ok(!notice.includes('cron.alter_job'))
  assert.equal(new Date('2026-11-23T07:00:00+01:00').toISOString(), '2026-11-23T06:00:00.000Z')
})

test('Register link visible beside Sign In on desktop and mobile while signup open',()=>{
  const header = read('../src/components/layout/MarketingHeader.tsx')
  const css = read('../src/styles/registration-launch-notice.css')
  assert.ok(header.includes('usePublicRegistrationStatus()'))
  assert.ok(header.includes("registrationAvailability === 'open'"))
  assert.ok(header.includes('tlg-header-signin'))
  assert.ok(header.includes('tlg-header-register'))
  assert.ok(header.includes("to=\"/register\""))
  assert.ok(header.includes("en: 'Register'"))
  assert.ok(header.includes('tlg-btn-full tlg-header-register'))
  assert.ok(css.includes('font-size: 12px'))
  assert.ok(css.includes('.tlg-registration-launch-modal-actions'))
  assert.ok(css.includes('.tlg-registration-launch-backdrop'))
})
