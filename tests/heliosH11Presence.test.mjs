import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8')
const sql=read('supabase/migrations/20261120111000_helios_h11_player_presence.sql')
const client=read('src/components/analytics/AnalyticsTracker.tsx')
const admin=read('src/pages/manager/AdminAnalytics.tsx')
const checklist=read('HELIOS_CHECKLIST.md')

test('H11 server owns identity and only records authenticated human players',()=>{
 assert.match(sql,/v_user uuid := auth\.uid\(\)/)
 assert.match(sql,/auth\.role\(\) <> 'authenticated'/)
 assert.match(sql,/p\.owner_user_id = v_user AND p\.player_type='human'/)
 assert.match(sql,/REVOKE ALL ON control_center_private\.tennis_active_player_presence_v1 FROM PUBLIC, anon, authenticated/)
 assert.match(sql,/GRANT EXECUTE ON FUNCTION public\.record_my_tennis_presence_v1\(\) TO authenticated/)
 assert.match(sql,/user_id uuid PRIMARY KEY/)
 assert.match(sql,/last_activity_at >= now\(\) - interval '2 minutes'/)
 assert.match(sql,/if not public\.is_app_admin_v1\(auth\.uid\(\)\) then/)
})
test('H11 client observes foreground interaction rather than fake online page views',()=>{
 assert.match(client,/record_my_tennis_presence_v1/)
 assert.match(client,/document\.visibilityState !== 'visible'/)
 assert.match(client,/lastInteraction > 90_000/)
 assert.match(client,/window\.addEventListener\('pointerdown'/)
 assert.match(client,/window\.addEventListener\('keydown'/)
 assert.match(client,/document\.addEventListener\('visibilitychange'/)
 assert.match(client,/window\.clearInterval\(interval\)/)
 assert.match(client,/if \(authLoading \|\| !user\?\.id \|\| !player\?\.id\) return/)
})
test('H11 admin UI and checklist label presence limitations clearly',()=>{
 assert.match(admin,/Active players · last 2 min/)
 assert.match(admin,/dashboard\.presence\.definition/)
 assert.match(checklist,/H11/)
 assert.match(checklist,/deployment/)
})
