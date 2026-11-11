import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')
const dashboard = read('../src/pages/dashboard/Overview.tsx')
const component = read('../src/components/season/Season2Week1PreRegistration.tsx')
const css = read('../src/styles/season2-week1-preregistration.css')

test('Season 2 Week 1 registration is mounted on the player dashboard', () => {
  assert.match(dashboard, /import Season2Week1PreRegistration from ['"]\.\.\/\.\.\/components\/season\/Season2Week1PreRegistration['"]/)
  assert.match(dashboard, /<Season2Week1PreRegistration\s*\/>/)
  assert.match(dashboard, /<SeasonTransitionNotice variant="dashboard"/)
})

test('UI uses only the authenticated server-checked preference RPCs', () => {
  assert.match(component, /useAuth\(\)/)
  assert.match(component, /supabase\.rpc\(['"]get_tennis_season2_week1_preentry_v1['"]\)/)
  assert.match(component, /supabase\.rpc\(['"]set_tennis_season2_week1_preentry_v1['"]/)
  assert.match(component, /p_competition_id:\s*selected/)
  assert.match(component, /p_accept_qualification:\s*acceptQualification/)
  assert.doesNotMatch(component, /\.from\(['"](?:tournament_applications|tournament_entries|tournament_matches|tournament_draw_publications)['"]\)/)
  assert.doesNotMatch(component, /service_role|sb_secret_/i)
})

test('registration cannot claim a confirmed tournament place', () => {
  assert.match(component, /if \(!player\?\.id \|\| !state\?\.enabled/)
  assert.match(component, /!choiceIsAvailable/)
  assert.match(component, /not an accepted entry or a confirmed draw place/i)
  assert.match(component, /preference saved/i)
  assert.match(component, /setChoice\(next\.selected_competition_id \?\? ''\)/)
})

test('player can withdraw, choose qualification and see errors', () => {
  assert.match(component, /save\(null\)/)
  assert.match(component, /setAcceptQualification\(event\.target\.checked\)/)
  assert.match(component, /role="alert"/)
  assert.match(component, /role="status"/)
})

test('registration panel has mobile-friendly layout rules', () => {
  assert.match(css, /@media\s*\(max-width:\s*600px\)/)
  assert.match(css, /\.tlg-season2-week1-actions/)
  assert.match(css, /\.tlg-season2-week1-error/)
})
