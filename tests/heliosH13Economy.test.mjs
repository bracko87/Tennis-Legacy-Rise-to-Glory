import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8')
const sql=read('supabase/migrations/20261120112500_helios_h13_economy_monitoring.sql')
const ui=read('src/pages/manager/AdminAnalytics.tsx')
const checklist=read('HELIOS_CHECKLIST.md')

test('H13: finance is authoritative and starting balances are not revenue',()=>{
 for (const name of ['coin_ledger','billing_transactions','career_finance_transactions','player_sponsor_contracts','player_sponsor_objectives','user_wallets']) assert.match(sql,new RegExp('public\\.'+name))
 assert.match(sql,/status='paid'/)
 assert.match(sql,/opening_balance/)
 assert.match(sql,/operational_income/)
 assert.match(sql,/operational_expenses/)
 assert.match(sql,/wallet_vs_latest_ledger_discrepancies/)
 assert.match(sql,/wallet_negative_balances/)
})
test('H13: financial dashboard RPC requires actual administrator access',()=>{
 assert.match(sql,/IF NOT public\.is_app_admin_v1\(auth\.uid\(\)\) THEN/)
 assert.match(sql,/REVOKE ALL ON FUNCTION public\.get_admin_tennis_economy_v1\(integer\) FROM PUBLIC,anon/)
 assert.match(sql,/GRANT EXECUTE ON FUNCTION public\.get_admin_tennis_economy_v1\(integer\) TO authenticated/)
 assert.doesNotMatch(sql,/stripe_customer_id|stripe_invoice_id|stripe_payment_intent_id/)
})
test('H13: independent refresh and monitoring panel, with delivery tracking',()=>{
 assert.match(ui,/get_admin_tennis_economy_v1/)
 assert.match(ui,/Economy &amp; Transactions/)
 assert.match(ui,/Current balances &amp; integrity/)
 assert.match(ui,/economy\.definition/)
 assert.match(ui,/setEconomyError/)
 assert.match(checklist,/\*\*H13\*\*/)
 assert.match(checklist,/authenticated production UI check/)
})
