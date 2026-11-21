import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = path => readFileSync(new URL('../'+path,import.meta.url),'utf8')
const provider = read('src/tutorial/TutorialProvider.tsx')
const notice = read('src/components/premium/WelcomePremiumTrial.tsx')
const layout = read('src/components/layout/GameLayout.tsx')

test('one career-scoped Premium notice owns the tutorial gate', () => {
  assert.doesNotMatch(layout, /<WelcomePremiumTrial/)
  assert.match(provider, /<WelcomePremiumTrial\s+key=\{noticeScope\}/)
  assert.match(provider, /noticeState\?\.scope !== noticeScope/)
  assert.match(notice, /onBlockingChange\(loading \|\| showNotice \|\| busy\)/)
  assert.match(notice, /const showNotice = !isPaidPremium && Boolean\(trial\?\.show_welcome \|\| trial\?\.show_expired\)/)
})
test('tutorial launch, route changes, targets and resume wait for the Premium notice', () => {
  assert.match(provider, /if \(premiumNoticeBlocking \|\| !inGame\) return/)
  assert.match(provider, /if \(premiumNoticeBlocking \|\| status !== 'active'/)
  assert.match(provider, /const tutorialUiVisible = !premiumNoticeBlocking/)
  assert.match(provider, /const pausedUiVisible = !premiumNoticeBlocking/)
  assert.match(notice, /await refresh\(\)[\s\S]*finally \{\s*setBusy\(false\)/)
})
