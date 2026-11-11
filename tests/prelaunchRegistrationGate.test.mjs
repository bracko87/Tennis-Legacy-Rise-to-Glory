import assert from 'node:assert/strict'
import test from 'node:test'
import { readFileSync } from 'node:fs'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')

test('public registration route remains blocked while prelaunch reset is unverified', () => {
  const app = read('../src/App.tsx')
  assert.ok(app.includes('<Route path="/register" element={<Navigate to="/login" replace />} />'))
  assert.ok(!app.includes('<Route path="/register" element={<RegisterPage'))
})

test('homepage, public header and footer do not offer registration buttons', () => {
  const home = read('../src/pages/Home.tsx')
  const header = read('../src/components/layout/MarketingHeader.tsx')
  const footer = read('../src/components/layout/MarketingFooter.tsx')
  for (const [name, content] of [['home', home], ['header', header], ['footer', footer]]) {
    assert.ok(!content.includes('to="/register"'), name)
    assert.ok(content.includes('to="/login"'), name)
  }
  assert.ok(!header.includes("t('marketing.startPlaying')"))
  assert.ok(!header.includes("sectionId: 'premium-features'"))
  assert.ok(home.includes("t('authPages.login.registrationClosed')"))
  assert.ok(footer.includes("t('authPages.login.registrationClosed')"))
})

test('login and referral pages cannot direct visitors to open signup', () => {
  const login = read('../src/pages/auth/Login.tsx')
  const referral = read('../src/pages/ReferralLanding.tsx')
  assert.ok(login.includes("t('authPages.login.registrationClosed')"))
  assert.ok(!login.includes('to="/register"'))
  assert.ok(!referral.includes("navigate('/register'"))
  assert.ok(referral.includes("navigate('/', { replace: true })"))
})

test('closed registration notice is visible and not linked to game clock reset', () => {
  const css = read('../src/styles/home-branding.css')
  const home = read('../src/pages/Home.tsx')
  assert.ok(css.includes('.tlg-prelaunch-registration-note'))
  assert.ok(home.includes('className="tlg-prelaunch-registration-note"'))
  assert.ok(!home.includes('public_signup_enabled'))
})
