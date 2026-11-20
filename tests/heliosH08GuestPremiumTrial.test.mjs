import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8')
const sql=read('supabase/migrations/20261120160000_helios_h08_guest_premium_trial.sql')
const checklist=read('HELIOS_CHECKLIST.md')
test('H08: guest Premium grant is inside one server-controlled enrollment transaction',()=>{
  assert.match(sql,/CREATE OR REPLACE FUNCTION public\.enroll_my_tennis_guest_trial_v1\(\)/)
  assert.match(sql,/NOT public\.get_public_tennis_guest_test_status_v1\(\)/)
  assert.match(sql,/v_user uuid := auth\.uid\(\)/)
  assert.match(sql,/v_anonymous,false\)=false/)
  assert.match(sql,/INSERT INTO control_center_private\.tennis_guest_trials_v1/)
  assert.match(sql,/INSERT INTO public\.tennis_premium_trials_v1/)
  assert.match(sql,/v_started,v_started\+interval '7 days',false,false/)
})
test('H08: one seven-day entitlement tied to original user identity, not reset on repeat enrollment',()=>{
  assert.match(sql,/ON CONFLICT \(user_id\) DO NOTHING/)
  assert.match(sql,/ON CONFLICT DO NOTHING/)
  assert.match(sql,/md5\('tennis-guest-premium-v1:'\|\|v_user::text\)/)
  assert.match(sql,/WHERE user_id=v_user/)
  assert.match(sql,/premium_expires_at/)
  assert.doesNotMatch(sql,/UPDATE public\.tennis_premium_trials_v1 SET/)
  assert.doesNotMatch(sql,/DELETE FROM public\.tennis_premium_trials_v1/)
})
test('H08: existing paid subscriptions and purchases remain untouched',()=>{
  assert.match(sql,/public\.billing_transactions b/)
  assert.match(sql,/b\.kind='premium_invoice' AND b\.status='paid'/)
  assert.match(sql,/public\.premium_memberships m/)
  assert.match(sql,/m\.plan_code='premium' AND m\.status='active'/)
  assert.match(checklist,/H08 seven-day guest Premium \(current\)/)
  assert.match(checklist,/Guest Mode remains disabled/)
})
