import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = path => readFileSync(new URL('../'+path, import.meta.url), 'utf8')
const sql = read('supabase/migrations/20261120115000_helios_h17_admin_security.sql')
const ui = read('src/components/admin/AdminSecurityStatus.tsx')
const admin = read('src/pages/manager/AdminAnalytics.tsx')
const checklist = read('HELIOS_CHECKLIST.md')

test('H17: admin permission requires same authenticated, linked and verified account', () => {
  assert.match(sql, /p_user_id = auth\.uid\(\)/)
  assert.match(sql, /a\.user_id=auth\.uid\(\)/)
  assert.match(sql, /JOIN auth\.users u ON u\.id=a\.user_id/)
  assert.match(sql, /u\.email_confirmed_at IS NOT NULL/)
  assert.match(sql, /lower\(u\.email\)=lower\(a\.email\)/)
  assert.match(sql, /u\.deleted_at IS NULL/)
  assert.doesNotMatch(sql, /auth\.jwt\(\)/)
  assert.match(sql, /REVOKE ALL ON FUNCTION public\.is_app_admin_v1\(uuid\) FROM PUBLIC,anon/)
})

test('H17: only designated orphaned admin grant disabled; no global account changes', () => {
  assert.match(sql, /WHERE lower\(email\) = 'levnajic\.aleksandar@gmail\.com'/)
  assert.match(sql, /AND user_id IS NULL/)
  assert.match(sql, /SET is_active = false/)
  assert.doesNotMatch(sql, /DELETE FROM auth\.users|UPDATE auth\.users/)
})

test('H17: security status is admin-gated and reports anonymous API grants', () => {
  assert.match(sql, /IF NOT public\.is_app_admin_v1\(auth\.uid\(\)\) THEN/)
  assert.match(sql, /'unlinked_active_records'/)
  assert.match(sql, /'verified_active_admins'/)
  assert.match(sql, /'analytics_anon_execute'/)
  assert.match(sql, /'history_anon_execute'/)
  assert.match(sql, /'economy_anon_execute'/)
  assert.match(sql, /REVOKE ALL ON FUNCTION public\.get_admin_tennis_security_status_v1\(\) FROM PUBLIC,anon/)
  assert.match(ui, /get_admin_tennis_security_status_v1/)
  assert.match(ui, /Administrator security/)
  assert.match(ui, /report\.definition/)
  assert.match(admin, /<AdminSecurityStatus \/>/)
  assert.match(checklist, /\*\*H17\*\*/)
})
