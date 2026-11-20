import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
const read = p => readFileSync(new URL('../'+p,import.meta.url),'utf8')
const sql = read('supabase/migrations/20261120142000_helios_h01_guest_player_creation.sql')
const ui = read('src/pages/player/CreatePlayer.tsx')
const checklist = read('HELIOS_CHECKLIST.md')

test('H01: only enrolled, unexpired Supabase anonymous accounts may omit home city',()=>{
 assert.match(sql,/auth\.uid\(\) IS NOT NULL/)
 assert.match(sql,/u\.is_anonymous/)
 assert.match(sql,/g\.expires_at>now\(\)/)
 assert.match(sql,/new\.home_city is null or btrim\(new\.home_city\) = ''/)
 assert.match(sql,/not public\.is_my_active_tennis_guest_v1\(\)/)
 assert.match(sql,/Choose a home city before creating the player/)
 assert.match(sql,/REVOKE ALL ON FUNCTION public\.is_my_active_tennis_guest_v1\(\) FROM PUBLIC,anon/)
})

test('H01: server prevents unowned, duplicate or incomplete guest player creation',()=>{
 assert.match(sql,/public\.assert_my_tennis_guest_access_v1\(\)/)
 assert.match(sql,/NEW\.owner_user_id IS DISTINCT FROM auth\.uid\(\)/)
 assert.match(sql,/NEW\.player_type<>'human'/)
 assert.match(sql,/Guest player already created/)
 assert.match(sql,/Guest requires first and last name, country and appearance/)
 assert.match(sql,/Guest player home city must be omitted/)
 assert.match(sql,/CREATE TRIGGER aa_guard_tennis_guest_player_creation_v1/)
})

test('H01: existing player creator hides city and style for real enrolled guest identity',()=>{
 assert.match(ui,/user\?\.is_anonymous === true/)
 assert.match(ui,/get_my_tennis_guest_trial_v1/)
 assert.match(ui,/activeGuest \|\| homeCityValid/)
 assert.match(ui,/activeGuest \? selectedAvatarPath !== null : profileValid/)
 assert.match(ui,/activeGuest && step === 3 \? 5 : step \+ 1/)
 assert.match(ui,/activeGuest \? null : homeCity/)
 assert.match(ui,/activeGuest \? 'Hard' : preferredSurface/)
 assert.match(ui,/activeGuest \? 'All-court' : playingStyle/)
 assert.match(ui,/activeGuest \? 'right' : playingHand/)
 assert.match(ui,/!activeGuest && \(/)
 assert.match(ui,/Your test player is unavailable until Guest Mode is enabled/)
 assert.match(checklist,/Guest Mode NOT enabled/)
})
