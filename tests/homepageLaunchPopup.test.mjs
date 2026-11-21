import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = (path) => readFileSync(new URL('../' + path, import.meta.url), 'utf8')

test('homepage opens the existing launch and Discord popup when registration is open', () => {
  const home = read('src/pages/Home.tsx')
  assert.match(home, /import RegistrationLaunchNotice from '\.\.\/components\/marketing\/RegistrationLaunchNotice'/)
  assert.match(home, /registrationAvailability === 'open' && <RegistrationLaunchNotice modal \/>/)
})

test('launch popup gives correct time and never treats configured 2x speed as an unpaused clock', () => {
  const notice = read('src/components/marketing/RegistrationLaunchNotice.tsx')
  assert.match(notice, /2026-12-01T07:00:00\+01:00/)
  assert.match(notice, /1 December 2026, 07:00 CET/)
  assert.match(notice, /copy\.paused/)
  assert.match(notice, /TENNIS_DISCORD_INVITE_URL/)
  assert.doesNotMatch(notice, /clock\.speedMultiplier === 0/)
})

test('launch popup has no decorative calendar icon; compact notice can retain its icon', () => {
  const notice = read('src/components/marketing/RegistrationLaunchNotice.tsx')
  assert.doesNotMatch(notice, /tlg-registration-launch-modal-icon/)
  assert.match(notice, /tlg-registration-launch-icon/)
})
