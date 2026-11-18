import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8')

test('both Premium notices share the regular commerce typography', () => {
  const page = read('src/pages/manager/ProPackages.tsx')
  const css = read('src/styles/commerce.css')
  assert.match(page, /className="tlg-commerce-policy-notice"/)
  assert.match(page, /className="tlg-commerce-preview-notice"/)
  assert.match(css, /\.tlg-commerce-page \.tlg-commerce-policy-notice,\s*\.tlg-commerce-page \.tlg-commerce-preview-notice/)
  assert.match(css, /font-family: inherit/)
  assert.match(css, /font-size: \.88rem/)
})

test('national divisions browser safely handles unavailable API response', () => {
  const code = read('src/components/national-team/NationalCompetitionDivisions.tsx')
  assert.match(code, /browser\?\.available && browser\.selected_division/)
  assert.match(code, /Array\.isArray\(browser\.competition_options\)/)
  assert.match(code, /Refresh competitions/)
})

test('all eligible players may browse divisions without joining a national association', () => {
  const sql = read('supabase/migrations/20261118114500_national_team_division_browser_nonmembers.sql')
  assert.match(sql, /if v_assoc is null then\s*select p\.world into v_world/)
  assert.match(sql, /p\.player_type='human'/)
  assert.match(sql, /if v_my_division is null and v_assoc is not null then/)
  assert.match(sql, /if v_my_division is null then\s*select d\.id into v_my_division/)
  assert.match(sql, /where d\.world=v_world and d\.is_active/)
  assert.doesNotMatch(sql, /if v_assoc is null then return jsonb_build_object\('available',false\)/)
})
