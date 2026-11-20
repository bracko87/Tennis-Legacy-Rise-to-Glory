import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import test from 'node:test'
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8')
const sql=read('supabase/migrations/20261120105000_helios_h12_gameplay_activity.sql')
const ui=read('src/pages/manager/AdminAnalytics.tsx')
const checklist=read('HELIOS_CHECKLIST.md')

test('H12: gameplay comes from authoritative records of human players',()=>{
 for(const tab of [
 'player_training_sessions','tournament_applications','tournament_matches',
 'player_staff_contracts','player_equipment_inventory','player_skill_history'
 ]) assert.ok(sql.includes('public.'+tab),tab)
 assert.match(sql,/p\.player_type='human'/)
 assert.match(sql,/m\.completed_at>=v_start_time/)
 assert.match(sql,/e\.acquired_source NOT IN \('starter','initial'\)/)
 assert.match(sql,/h\.source<>'initial'/)
 assert.match(sql,/v_start::timestamp AT TIME ZONE 'Europe\/Berlin'/)
 assert.match(sql,/v_end_time/)
})
test('H12: only authenticated admins may query aggregates',()=>{
 assert.match(sql,/IF NOT public\.is_app_admin_v1\(auth\.uid\(\)\) THEN/)
 assert.match(sql,/REVOKE ALL ON FUNCTION public\.get_admin_tennis_game_activity_v1\(integer\) FROM PUBLIC,anon/)
 assert.match(sql,/GRANT EXECUTE ON FUNCTION public\.get_admin_tennis_game_activity_v1\(integer\) TO authenticated/)
 assert.match(sql,/RETURNS jsonb/)
 assert.doesNotMatch(sql,/jsonb_build_object\([^]*?'user_id'/)
})
test('H12: admin UI shows gameplay activity separately and explains paused zero',()=>{
 assert.match(ui,/get_admin_tennis_game_activity_v1/)
 assert.match(ui,/Game Activity — Tennis Legacy/)
 assert.match(ui,/gameActivity\.is_game_clock_paused/)
 assert.match(ui,/gameActivity\.definition/)
 assert.match(ui,/Last recorded gameplay action/)
 assert.match(checklist,/\*\*H12\*\*/)
 assert.match(checklist,/production UI verification pending/)
})
