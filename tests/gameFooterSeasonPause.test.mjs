import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

import { formatSeasonResumeTime } from '../src/lib/seasonResumeTime.ts'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')
const footer = read('../src/components/layout/GameFooter.tsx')
const styles = read('../src/styles/dashboard-v4.css')

test('server UTC deadline converts to actual German resume time with explicit time zone', () => {
  const formatted = formatSeasonResumeTime('2026-11-12T11:22:24.404601+00:00', 'en-GB', 'Europe/Berlin')
  assert.match(formatted, /12 Nov 2026/)
  assert.match(formatted, /12:22/)
  assert.match(formatted, /Europe\/Berlin/)
  assert.match(formatted, /CET|GMT\+1/)
})

test('uses visitor time zone, not a fixed German clock', () => {
  const formatted = formatSeasonResumeTime('2026-11-12T11:22:24+00:00', 'en-US', 'America/New_York')
  assert.match(formatted, /06:22/)
  assert.match(formatted, /America\/New_York/)
  assert.match(formatted, /EST|GMT-5/)
})

test('never fabricates an unpause date when the server has none', () => {
  assert.equal(formatSeasonResumeTime(null, 'en-GB', 'Europe/Berlin'), null)
  assert.equal(formatSeasonResumeTime('invalid', 'en-GB', 'Europe/Berlin'), null)
})

test('footer displays plain text only for a server-confirmed clock pause', () => {
  assert.match(footer, /useSeasonMaintenance\(\)/)
  assert.match(footer, /clock\.speedMultiplier === 0/)
  assert.match(footer, /maintenance\?\.game_clock_paused === true/)
  assert.match(footer, /maintenance\?\.preseason_active/)
  assert.match(footer, /maintenance\.preseason_ends_at/)
  assert.match(footer, /className="tlg-v4-game-clock-pause"/)
  assert.match(footer, /t\('footer\.clockPausedUntil'/)
  assert.match(footer, /t\('footer\.clockPaused'/)
  assert.doesNotMatch(footer, /new Date\('2026/)
  assert.match(styles, /\.tlg-v4-game-clock-pause \{/)
  assert.doesNotMatch(styles, /\.tlg-v4-game-clock-pause\s*\{[^}]*background:/)
})

test('the pause label exists in every enabled game locale', () => {
  for (const language of ['en', 'de', 'sr', 'es', 'it', 'fr', 'ru', 'pt']) {
    const translation = read(`../src/i18n/locales/${language}.ts`)
    assert.match(translation, /clockPausedUntil["']?\s*:\s*["'][^\n]*\{\{date\}\}/, language)
  }
})
