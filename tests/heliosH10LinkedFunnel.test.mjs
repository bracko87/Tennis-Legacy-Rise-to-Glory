import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = path => readFileSync(new URL('../'+path,import.meta.url),'utf8')
const sql = read('supabase/migrations/20261120113500_helios_h10_linked_funnel.sql')
const ui = read('src/pages/manager/AdminAnalytics.tsx')
const checklist = read('HELIOS_CHECKLIST.md')

test('H10: privacy-preserving ordered browser-linked journey',()=>{
 for (const stage of ['homepage_browser_ids','registration_browser_ids','linked_accounts','linked_players','returned_browser_ids']){
   assert.match(sql, new RegExp("'"+stage+"'"))
   assert.match(ui,new RegExp(stage))
 }
 assert.match(sql,/having count\(distinct v\.user_id\) = 1/)
 assert.match(sql,/max\(v\.user_id::text\)::uuid as user_id/)
 assert.match(sql,/p\.created_at >= r\.opened_at/)
 assert.match(sql,/v\.last_seen_at >= p\.created_at/)
 assert.match(sql,/p\.player_type='human'/)
 assert.match(sql,/s\.started_at >= c\.created_at \+ interval '24 hours'/)
 assert.match(sql,/is_app_admin_v1\(auth\.uid\(\)\)/)
 assert.match(sql,/not a definitive person-level conversion rate/)
 assert.match(ui,/Browser-linked registration journey/)
 assert.match(ui,/dashboard\.linked_funnel\.definition/)
 assert.match(checklist,/H10 continuation/)
})
