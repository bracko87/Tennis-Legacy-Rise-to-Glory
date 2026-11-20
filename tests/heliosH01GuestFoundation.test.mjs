import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import test from 'node:test'

const read = p => readFileSync(new URL('../'+p,import.meta.url),'utf8')
const sql = read('supabase/migrations/20261120133000_helios_h01_guest_trial_foundation.sql')
const checklist = read('HELIOS_CHECKLIST.md')

test('Helios guest feature is disabled and cannot accidentally activate',()=>{
  assert.match(sql,/guest_test_enabled boolean NOT NULL DEFAULT false/)
  assert.match(sql,/NOT public\.get_public_tennis_guest_test_status_v1\(\)/)
  assert.match(sql,/Guest mode is not available/)
  assert.match(checklist,/Guest Mode stays disabled/)
})

test('guest expiry derives from server timestamps and cannot reset through repeated enrollment',()=>{
  assert.match(sql,/user_id uuid PRIMARY KEY REFERENCES auth\.users\(id\)/)
  assert.match(sql,/expires_at = started_at \+ interval '14 days'/)
  assert.match(sql,/VALUES \(v_user,now\(\),now\(\)\+interval '14 days'\)/)
  assert.match(sql,/ON CONFLICT \(user_id\) DO NOTHING/)
  assert.match(sql,/v_expires<=v_now THEN 'expired'/)
  assert.match(sql,/can_convert',true/)
})

test('guest trial access uses exact signed-in identity, never caller supplied account ids',()=>{
  assert.match(sql,/v_user uuid := auth\.uid\(\)/)
  assert.match(sql,/SELECT is_anonymous INTO v_anonymous FROM auth\.users WHERE id=v_user/)
  assert.match(sql,/REVOKE ALL ON control_center_private\.tennis_guest_trials_v1 FROM PUBLIC, anon, authenticated/)
  assert.match(sql,/REVOKE ALL ON FUNCTION public\.enroll_my_tennis_guest_trial_v1\(\) FROM PUBLIC,anon/)
  assert.match(sql,/IF EXISTS\(SELECT 1 FROM auth\.users WHERE id=v_user AND is_anonymous\)/)
  assert.match(sql,/Guest trial expired or not enrolled/)
  assert.doesNotMatch(sql,/GRANT (SELECT|INSERT|UPDATE|DELETE) ON control_center_private\.tennis_guest_trials_v1 TO (anon|authenticated)/)
})

test('checklist preserves remaining full guest workflow and premium safety work',()=>{
  assert.match(checklist,/H01\/H08 foundation/)
  assert.match(checklist,/anonymous Supabase signup/)
  assert.match(checklist,/Premium/)
  assert.match(checklist,/rankings/)
  assert.match(checklist,/permanent conversion/)
})
