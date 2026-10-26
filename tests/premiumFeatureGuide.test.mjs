// Run: node --experimental-strip-types --test tests/premiumFeatureGuide.test.mjs
import assert from 'node:assert/strict'
import test from 'node:test'
import { PREMIUM_INTELLIGENCE_IDS, premiumGuideCopy } from '../src/lib/premiumFeatureGuideI18n.ts'
import { readFileSync } from 'node:fs'
import { tournamentWatchLabels } from '../src/lib/tournamentWatchI18n.ts'
import { trainingOptimizationLabels } from '../src/lib/trainingOptimizationI18n.ts'
import { developmentOutlookLabels } from '../src/lib/developmentOutlookI18n.ts'
import { trainingEffectivenessLabels } from '../src/lib/trainingEffectivenessI18n.ts'
import { tournamentPlanningLabels } from '../src/lib/tournamentPlanningI18n.ts'
import { seasonPlanningLabels } from '../src/lib/seasonPlanningI18n.ts'
import { staffAdvisoryLabels } from '../src/lib/staffAdvisoryI18n.ts'
import { sponsorIntelligenceLabels } from '../src/lib/sponsorIntelligenceI18n.ts'
import { financialIntelligenceLabels } from '../src/lib/financialIntelligenceI18n.ts'
import { equipmentIntelligenceLabels } from '../src/lib/equipmentIntelligenceI18n.ts'
import { careerIntelligenceLabels } from '../src/lib/careerIntelligenceI18n.ts'
import en from '../src/i18n/locales/en.ts'
import sr from '../src/i18n/locales/sr.ts'
import de from '../src/i18n/locales/de.ts'
import es from '../src/i18n/locales/es.ts'
import it from '../src/i18n/locales/it.ts'
import fr from '../src/i18n/locales/fr.ts'
import ru from '../src/i18n/locales/ru.ts'
import pt from '../src/i18n/locales/pt.ts'

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
    assert.ok(copy.modules.training.length > 40, language + ': training')
  }
})

test('region variants fall back to their matching language and unknown codes to English', () => {
  assert.deepEqual(premiumGuideCopy('pt-BR'), premiumGuideCopy('pt'))
  assert.deepEqual(premiumGuideCopy('de-DE'), premiumGuideCopy('de'))
  assert.deepEqual(premiumGuideCopy('xx'), premiumGuideCopy('en'))
})

const localeBundles = { en, sr, de, es, it, fr, ru, pt }

test('Premium pages explicitly show the eight-language Tournament Watchlist benefit', () => {
  const guide = readFileSync(new URL('../src/components/marketing/PremiumBenefitsGuide.tsx', import.meta.url), 'utf8')
  const packages = readFileSync(new URL('../src/pages/manager/ProPackages.tsx', import.meta.url), 'utf8')
  const footer = readFileSync(new URL('../src/components/layout/MarketingFooter.tsx', import.meta.url), 'utf8')
  const home = readFileSync(new URL('../src/pages/Home.tsx', import.meta.url), 'utf8')
  assert.match(guide, /tournamentWatchLabels\(language\)/)
  assert.match(guide, /watchCopy\.title/)
  assert.match(guide, /watchCopy\.intro/)
  assert.match(packages, /watchlistLabels\.title, false, true/)
  assert.match(packages, /<PremiumBenefitsGuide placement="packages"/)
  assert.match(footer, /<PremiumBenefitsGuide placement="dialog"/)
  assert.match(home, /<PremiumBenefitsGuide placement="homepage"/)
})

test('all new Premium module titles and descriptions are available in all eight game languages', () => {
  const englishWatchTitle = tournamentWatchLabels('en').title
  for (const [language, locale] of Object.entries(localeBundles)) {
    const labelSources = [
      trainingOptimizationLabels(language), developmentOutlookLabels(language),
      trainingEffectivenessLabels(language), tournamentPlanningLabels(language),
      seasonPlanningLabels(language), staffAdvisoryLabels(language),
      sponsorIntelligenceLabels(language), financialIntelligenceLabels(language),
      equipmentIntelligenceLabels(language), careerIntelligenceLabels(language),
      tournamentWatchLabels(language),
    ]
    for (const module of labelSources) {
      assert.ok(module.title?.trim().length > 5, language + ': missing module title')
    }
    assert.ok(locale.statisticsPage.premiumInsights.title, language + ': Statistics')
    assert.ok(locale.deepMatchAnalysis.title, language + ': Deep Match')
    assert.ok(locale.developmentPremium.title, language + ': Player Development')
    assert.ok(locale.premiumTrial.rankingProtection, language + ': Ranking Protection')
    assert.ok(locale.premiumTrial.privateLife, language + ': Private Life')
    assert.ok(locale.home.premium.eyebrow, language + ': public Premium section')
    assert.ok(locale.commercePage.comparisonTitle, language + ': comparison')
    const watch = tournamentWatchLabels(language)
    assert.ok(watch.title.length > 8 && watch.intro.length > 60, language + ': Watchlist copy')
    assert.ok(watch.locked && watch.watch && watch.unwatch && watch.note, language + ': Watchlist actions')
    if (language !== 'en') assert.notEqual(watch.title, englishWatchTitle, language + ': English fallback')
    const template = locale.notifications.templates.tournament_application_watch_open
    assert.ok(template.title && template.message.includes('{{tournament_name}}'), language + ': Watchlist alert')
  }
})

test('language variants resolve to translations instead of English fallback', () => {
  assert.equal(tournamentWatchLabels('sr-Latn-RS').title, tournamentWatchLabels('sr').title)
  assert.equal(tournamentWatchLabels('pt-BR').title, tournamentWatchLabels('pt').title)
  assert.equal(tournamentWatchLabels('x-unknown').title, tournamentWatchLabels('en').title)
})
