import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
const read = p => readFileSync(new URL('../'+p,import.meta.url),'utf8')
const sql=read('supabase/migrations/20261120102000_helios_h10_onboarding_funnel.sql')
const ui=read('src/pages/manager/AdminAnalytics.tsx')
const checklist=read('HELIOS_CHECKLIST.md')

test('H10 reports five independent, privacy-preserving registration stages',()=>{
  for (const name of ['landing_visitors','registration_opened_visitors','registration_completed_accounts','player_created_accounts','returned_registered_accounts']){
    assert.ok(sql.includes("'"+name+"'"),name)
  }
  assert.match(sql,/created_at \+ interval '24 hours'/)
  assert.match(sql,/player_type='human'/)
  assert.match(sql,/not an attributed same-user funnel/)
  assert.match(sql,/is_app_admin_v1\(auth\.uid\(\)\)/)
  assert.match(ui,/Registration &amp; player onboarding/)
  assert.match(ui,/dashboard\.onboarding\.data_note/)
})

test('Helios has a durable checklist of all 21 tennis-only tasks',()=>{
  for(let n=1;n<=21;n++)assert.match(checklist,new RegExp('H'+String(n).padStart(2,'0')+'\\b'))
  assert.match(checklist,/Tennis Legacy: Rise to Glory \*\*only\*\*/)
  assert.match(checklist,/Project Saturn/)
  assert.match(checklist,/Current delivery/)
})
