import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')

test('in-progress qualifying and main-draw matches become Live activity, not Confirmed', () => {
  const sql = read('../supabase/migrations/20261113080500_calendar_show_live_qualifying_matches.sql')
  assert.match(sql, /when m\.status='in_progress' then 'tournament_live'/)
  assert.match(sql, /when m\.status in \('completed','walkover'\) then 'tournament_completed'/)
  assert.match(sql, /else 'tournament_confirmed'/)
  assert.match(sql, /when 'tournament_live' then 0/)
  // Must not restrict classification to the main draw; qualifiers are live too.
  assert.doesNotMatch(sql, /when m\.status='in_progress' and m\.draw_type='main_draw'/i)
  assert.doesNotMatch(sql, /\b(?:UPDATE|DELETE FROM|TRUNCATE)\s+public\.tournament_(?:matches|entries|applications)\b/i)
})

test('live match is emphasized on today only, with historical and future statuses intact', () => {
  const calendar = read('../src/pages/dashboard/Calendar.tsx')
  assert.match(calendar, /activity\.source === 'tournament_live'/)
  assert.match(calendar, /primaryActivity\.source === 'tournament_live'/)
  assert.match(calendar, /activityAbsoluteDay === todayAbsoluteDay/)
  assert.match(calendar, /primaryAbsoluteDay === todayAbsoluteDay/)
  assert.match(calendar, /: tournamentLive\s*\? 'live'/)
  assert.match(calendar, /: primaryLive\s*\? 'live'/)
  assert.match(calendar, /tournamentCompleted \? 'played' : tournamentLive \? 'live'/)
  assert.match(calendar, /tournamentPredicted \? 'predicted'/)
  assert.match(calendar, /tournamentAccepted \? 'accepted'/)
})

test('current tournament day highlights Live and status is translated', () => {
  const styles = read('../src/styles/calendar-player-activity.css')
  assert.match(styles, /\.tlg-calendar-day-current\.tlg-calendar-day-tournament-live/)
  assert.match(styles, /\.tlg-calendar-player-activity\.tournament\.live/)
  for (const [lang, text] of [['en', 'Live'], ['de', 'Live'], ['es', 'En vivo'], ['pt', 'Ao vivo']]) {
    const source = read(`../src/i18n/locales/${lang}.ts`)
    assert.ok(source.includes(`live: '${text}'`), `Missing live label for ${lang}`)
  }
})
