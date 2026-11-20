import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = (path) => readFileSync(new URL('../' + path, import.meta.url), 'utf8')
const sql = read('supabase/migrations/20261120203000_helios_h18_live_page_activity.sql')
const tracker = read('src/components/analytics/AnalyticsTracker.tsx')
const report = read('src/components/admin/AdminLivePageActivity.tsx')
const analytics = read('src/pages/manager/AdminAnalytics.tsx')

test('Helios H18: only aggregated live page activity can be read by verified administrators', () => {
  assert.match(sql, /control_center_private\.tennis_live_page_sessions_v1/)
  assert.match(sql, /ENABLE ROW LEVEL SECURITY/)
  assert.match(sql, /REVOKE ALL ON TABLE control_center_private\.tennis_live_page_sessions_v1 FROM PUBLIC, anon, authenticated/)
  assert.match(sql, /IF NOT public\.is_app_admin_v1\(auth\.uid\(\)\)/)
  assert.match(sql, /REVOKE ALL ON FUNCTION public\.get_admin_live_page_activity_v1\(\) FROM PUBLIC, anon, authenticated/)
  assert.match(sql, /GRANT EXECUTE ON FUNCTION public\.get_admin_live_page_activity_v1\(\) TO authenticated/)
  assert.match(sql, /SELECT DISTINCT ON \(visitor_id\)/)
  assert.match(sql, /interval '2 minutes'/)
  assert.match(sql, /interval '24 hours'/)
})

test('Helios H18: client tracks foreground interaction without artificial idle presence', () => {
  assert.match(tracker, /OFFICIAL_ANALYTICS_HOSTS/)
  assert.match(tracker, /record_live_page_presence_v1/)
  assert.match(tracker, /location\.pathname\.startsWith\('\/game\/admin\/'\)/)
  assert.match(tracker, /document\.visibilityState !== 'visible'/)
  assert.match(tracker, /now - lastInteractionAt > 90_000/)
  assert.match(tracker, /now - lastSentAt < 25_000/)
  assert.match(tracker, /setInterval\(\(\) => \{ void recordLivePage\(\) \}, 30_000\)/)
  assert.match(tracker, /clearInterval\(interval\)/)
})

test('Helios H18: admin view labels browser estimates and preserves last valid data on errors', () => {
  assert.match(analytics, /<AdminLivePageActivity formatPath=\{formatPath\} \/>/)
  assert.match(report, /get_admin_live_page_activity_v1/)
  assert.match(report, /Active visitors/)
  assert.match(report, /Registered browsers/)
  assert.match(report, /Guests \/ anonymous/)
  assert.match(report, /Not a websocket connection count/)
  assert.match(report, /setInterval\(refreshIfVisible, 30_000\)/)
  assert.match(report, /Showing the last successful report/)
  assert.match(report, /Administrator pages and localhost are excluded/)
})
