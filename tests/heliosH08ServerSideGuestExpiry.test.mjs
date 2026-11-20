import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = path => readFileSync(new URL('../'+path, import.meta.url), 'utf8')
const primary = read('supabase/migrations/20261120171000_helios_h08_guest_gameplay_expiry_guards.sql')
const secondary = read('supabase/migrations/20261120171500_helios_h08_additional_guest_expiry_guards.sql')
const checklist = read('HELIOS_CHECKLIST.md')

function names(source) {
  const match = source.match(/FOREACH v_name IN ARRAY ARRAY\[([\s\S]*?)\]/)
  assert.ok(match, 'migration has an explicit auditable function allowlist')
  return [...match[1].matchAll(/'([a-z][a-z_0-9]+)'/g)].map(x => x[1])
}

test('H08: 81 auditable gameplay RPCs check guest trial BEFORE their business mutations', () => {
  const first = names(primary)
  const more = names(secondary)
  assert.equal(first.length, 65)
  assert.equal(more.length, 16)
  assert.equal(new Set([...first, ...more]).size, 81)
  for (const name of [
    'apply_to_tournament_v3', 'complete_regular_training_today_v1',
    'purchase_equipment_item_v2', 'negotiate_staff_offer_v1',
    'sign_player_sponsor_offer_v1', 'save_tournament_match_tactic_v1',
    'set_regular_training_plan_v1', 'set_private_life_home_base_v1',
    'send_player_message_v1', 'send_doubles_partner_invitation_v1'
  ]) assert.ok(first.includes(name) || more.includes(name), 'guard missing: ' + name)
  for (const action of ['delete_tennis_legacy_account_v1','get_my_tennis_guest_trial_v1','enroll_my_tennis_guest_trial_v1','record_site_analytics_event_v1']) {
    assert.ok(!first.includes(action) && !more.includes(action), action+' should stay outside gameplay lock')
  }
  for (const src of [primary,secondary]) {
    assert.match(src,/v_guard|v_insert/)
    assert.match(src,/public\.assert_my_tennis_guest_access_v1\(\)/)
    assert.match(src,/v_pos|v_begin_pos/)
    assert.match(src,/pg_get_functiondef/)
    assert.match(src,/EXECUTE/)
  }
})

test('H08: direct player and tutorial writes have server-side guest guard', () => {
  assert.match(primary,/CREATE OR REPLACE FUNCTION public\.guard_tennis_guest_direct_gameplay_write_v1\(\)/)
  assert.match(primary,/auth\.uid\(\) IS NOT NULL/)
  assert.match(primary,/FROM auth\.users WHERE id=auth\.uid\(\) AND is_anonymous/)
  assert.match(primary,/PERFORM public\.assert_my_tennis_guest_access_v1\(\)/)
  assert.match(primary,/BEFORE INSERT OR UPDATE ON public\.players/)
  assert.match(primary,/BEFORE INSERT OR UPDATE ON public\.player_tutorial_progress/)
  assert.match(primary,/REVOKE ALL ON FUNCTION public\.guard_tennis_guest_direct_gameplay_write_v1\(\)/)
})

test('H08: rollout remains disabled and audit gaps accurately documented', () => {
  assert.match(checklist,/81 gameplay mutation RPCs/)
  assert.match(checklist,/Guest Mode OFF/)
  assert.match(checklist,/Not an exhaustive audit/)
  assert.match(checklist,/anonymous-to-registered identity linking/)
})
