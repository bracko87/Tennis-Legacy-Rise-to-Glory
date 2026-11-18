import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const sql=readFileSync(new URL('../supabase/migrations/20261118163000_restore_orphaned_prelaunch_trial_claims.sql',import.meta.url),'utf8')

test('prelaunch orphaned email claim can reserve a trial without reusing an active trial',()=>{
  assert.match(sql,/if v_claimed=1 or \(/)
  assert.match(sql,/v_reserve_for_launch and not exists \(/)
  assert.match(sql,/current_trial\.email_claim_hash=v_email_hash/)
  assert.match(sql,/on conflict do nothing returning \* into v_trial/)
})

test('trial timing and paid-account exclusions are preserved',()=>{
  assert.match(sql,/v_reserve_for_launch := v_launch_actual IS NULL/)
  assert.match(sql,/if v_trial\.user_id is null and not v_paid_active and not v_paid_before then/)
  assert.match(sql,/WHEN v_reserve_for_launch THEN v_launch_scheduled/)
  assert.match(sql,/v_start_anchor\+interval '7 days'/)
  assert.match(sql,/'state','pending_launch','is_premium',true,'trial_started',false/)
  assert.match(sql,/'started_at',null,'expires_at',null,'seconds_left',604800/)
})
