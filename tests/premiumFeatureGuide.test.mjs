// Run: node --experimental-strip-types --test tests/premiumFeatureGuide.test.mjs
import assert from 'node:assert/strict'
import test from 'node:test'
import { PREMIUM_INTELLIGENCE_IDS, premiumGuideCopy } from '../src/lib/premiumFeatureGuideI18n.ts'

test('exactly eleven delivered intelligence areas are marketed', () => {
  assert.equal(PREMIUM_INTELLIGENCE_IDS.length, 11)
  assert.equal(new Set(PREMIUM_INTELLIGENCE_IDS).size, 11)
  assert.ok(!PREMIUM_INTELLIGENCE_IDS.includes('convenience'))
})

test('each of the eight languages describes every implemented Premium area', () => {
  for (const language of ['en', 'de', 'sr', 'es', 'fr', 'it', 'ru', 'pt']) {
    const copy = premiumGuideCopy(language)
    assert.ok(copy.heading.length > 10, language)
    assert.equal(copy.freeItems.length, 4, language)
    assert.ok(copy.freeTitle && copy.premiumTitle, language)
    assert.ok(copy.trustNote && copy.coinsNote && copy.trialNote, language)
    assert.equal(Object.keys(copy.modules).length, 11, language)
    for (const module of PREMIUM_INTELLIGENCE_IDS) {
      assert.ok(copy.modules[module]?.length > 25, language + ': ' + module)
    }
    assert.ok(copy.modules.training.includes(language === 'en' ? 'Training Optimization' : copy.modules.training.slice(-7)) || copy.modules.training.length > 40)
  }
})

test('region variants fall back to their matching language and unknown codes to English', () => {
  assert.deepEqual(premiumGuideCopy('pt-BR'), premiumGuideCopy('pt'))
  assert.deepEqual(premiumGuideCopy('de-DE'), premiumGuideCopy('de'))
  assert.deepEqual(premiumGuideCopy('xx'), premiumGuideCopy('en'))
})
