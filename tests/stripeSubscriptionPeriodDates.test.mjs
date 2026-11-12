import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')
const migration = read('../supabase/migrations/20261112101500_stripe_subscription_item_period_dates.sql')

test('Stripe webhook supports modern item-level subscription period dates', () => {
  assert.match(migration, /items,data,0,current_period_start/)
  assert.match(migration, /items,data,0,current_period_end/)
  assert.match(migration, /coalesce\(\s*nullif\(v_obj->>'current_period_start'/)
  assert.match(migration, /coalesce\(\s*nullif\(v_obj->>'current_period_end'/)
  assert.match(migration, /try_process_tennis_stripe_event_v2\(p_event_id text\)/)
  assert.match(migration, /current_period_end=coalesce\(v_period_end,current_period_end\)/)
})

test('Premium page displays the verified billing period end independently of trial expiry', () => {
  const page = read('../src/pages/manager/ProPackages.tsx')
  const commerce = read('../src/hooks/useCommerce.ts')
  assert.ok(page.includes("t('commercePage.currentPeriodEnds', { date: date(membership?.current_period_end) })"))
  assert.ok(page.includes("t('premiumTrial.trialEnds', { date: date(commerce.trial?.expires_at) })"))
  assert.ok(commerce.includes('current_period_end: string | null'))
  assert.ok(commerce.includes("supabase.rpc('get_my_tennis_premium_trial_v1'"))
})
