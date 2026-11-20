import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = p => readFileSync(new URL('../'+p, import.meta.url), 'utf8')
const sql = read('supabase/migrations/20261120113000_helios_h14_event_history.sql')
const ui = read('src/components/admin/AdminEventHistory.tsx')
const page = read('src/pages/manager/AdminAnalytics.tsx')
const checklist = read('HELIOS_CHECKLIST.md')

test('H14 history comes from real, source-stamped events only', () => {
  for (const table of ['system_incidents','referral_admin_audit','coin_ledger','billing_transactions','career_finance_transactions','player_training_sessions','tournament_applications','player_staff_contracts','player_sponsor_contracts']) {
    assert.match(sql, new RegExp('public\\.'+table))
  }
  assert.match(sql,/occurred_at/)
  assert.match(sql,/category\|\|':'\|\|q\.event_id/)
  assert.match(sql,/ORDER BY occurred_at DESC,category,event_id LIMIT v_limit OFFSET v_offset/)
  assert.match(sql,/least\(coalesce\(p_limit,25\),50\)/)
  assert.match(sql,/least\(coalesce\(p_offset,0\),5000\)/)
})

test('H14 event history is restricted, bounded and sanitizes sensitive fields', () => {
  assert.match(sql,/IF NOT public\.is_app_admin_v1\(auth\.uid\(\)\) THEN/)
  assert.match(sql,/REVOKE ALL ON FUNCTION public\.get_admin_tennis_event_history_v1\(integer,text,text,integer,integer\) FROM PUBLIC,anon/)
  assert.match(sql,/GRANT EXECUTE ON FUNCTION public\.get_admin_tennis_event_history_v1\(integer,text,text,integer,integer\) TO authenticated/)
  assert.doesNotMatch(sql,/SELECT \* FROM public\.billing_transactions/i)
  assert.doesNotMatch(sql,/stripe_customer_id|stripe_payment_intent_id|stripe_checkout_session_id/)
  assert.match(sql,/not an exhaustive or immutable change log/)
  assert.match(sql,/Uses retention of source tables/)
})

test('H14 admin UI exposes date, category, search, pagination and limitations', () => {
  assert.match(ui,/get_admin_tennis_event_history_v1/)
  assert.match(ui,/Searchable administrator event history/)
  assert.match(ui,/setCategory/)
  assert.match(ui,/setAppliedSearch/)
  assert.match(ui,/Previous/)
  assert.match(ui,/Next/)
  assert.match(ui,/report\.definition/)
  assert.match(ui,/report\.retention/)
  assert.match(page,/<AdminEventHistory period=\{period\} \/>/)
  assert.match(checklist,/\*\*H14\*\*/)
  assert.match(checklist,/append-only audit/)
})
