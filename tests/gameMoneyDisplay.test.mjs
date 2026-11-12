import assert from 'node:assert/strict'
import test from 'node:test'
import { readFileSync } from 'node:fs'
import {
  formatGameCurrency,
  formatPurchasePrice,
  formatMarketQuote,
} from '../src/lib/moneyFormatting.ts'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')

test('all game cash, balances, prizes and sponsor offers show whole money amounts', () => {
  assert.equal(formatGameCurrency(66000, 'en-US', 'USD'), '$66,000')
  assert.equal(formatGameCurrency(25775, 'en-US', 'USD'), '$25,775')
  assert.equal(formatGameCurrency(0, 'en-US', 'USD'), '$0')
  assert.equal(formatGameCurrency(775, 'en-US', 'USD'), '$775')
  assert.equal(formatGameCurrency(-700, 'en-US', 'USD'), '-$700')
  assert.equal(formatGameCurrency(1000.6, 'en-US', 'USD'), '$1,001')
  assert.equal(formatGameCurrency(-0.3, 'en-US', 'USD'), '$0')
  assert.match(formatGameCurrency(66000, 'de-DE', 'EUR'), /^66\\.000.*€/)
  assert.doesNotMatch(formatGameCurrency(66000, 'de-DE', 'EUR'), /,00/)
})

test('paid Premium, purchases, and fractional market quotes keep meaningful precision', () => {
  assert.equal(formatPurchasePrice(3.29, 'en-US', 'EUR'), '€3.29')
  assert.equal(formatPurchasePrice(9.49, 'en-US', 'EUR'), '€9.49')
  assert.equal(formatPurchasePrice(33.49, 'en-US', 'EUR'), '€33.49')
  assert.equal(formatMarketQuote(140, 'en-US', 'USD'), '$140')
  assert.equal(formatMarketQuote(140.35, 'en-US', 'USD'), '$140.35')
  assert.equal(formatMarketQuote(0.001234, 'en-US', 'USD', 6), '$0.001234')
})

test('shared formatter is used across game pages without changing persisted financial values', () => {
  const shared = read('../src/i18n/LocalizationProvider.tsx')
  assert.match(shared, /formatCurrency: \(value, currency = 'EUR'\) => formatGameCurrency\(value, localeTag, currency\)/)
  const overview = read('../src/pages/dashboard/Overview.tsx')
  const finance = read('../src/pages/dashboard/Finance.tsx')
  const privateLife = read('../src/pages/dashboard/PrivateLife.tsx')
  const tournament = read('../src/components/dashboard/NextTournamentExtras.tsx')
  for (const [name, file] of [['Overview', overview], ['Finance', finance], ['Private Life', privateLife], ['Tournament', tournament]]) {
    assert.ok(file.includes('formatCurrency'), name)
  }
  const investments = read('../src/components/private-life/PrivateLifeInvestments.tsx')
  assert.ok(investments.includes('formatGameCurrency'))
  assert.ok(investments.includes('formatMarketQuote'))
  assert.ok(investments.includes('money(portfolioValuePrecise, currency)'))
  assert.ok(investments.includes('signedMoney(unrealizedPrecise, currency)'))
})

test('real-money billing remains exact and game per-use prices omit .00', () => {
  const billing = read('../src/pages/manager/ProPackages.tsx')
  assert.ok(billing.includes('formatPurchasePrice(cents / 100, localeTag'))
  assert.ok(billing.includes('formatPurchasePrice(pack.price, localeTag'))
  assert.ok(billing.includes('formatPurchasePrice(pack.price / pack.coins, localeTag'))
  const equipment = read('../src/components/premium/PremiumEquipmentIntelligence.tsx')
  assert.ok(equipment.includes('minimumFractionDigits:0,maximumFractionDigits:2'))
})
