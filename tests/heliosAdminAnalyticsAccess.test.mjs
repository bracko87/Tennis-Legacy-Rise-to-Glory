import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
const read = (path) => readFileSync(new URL('../'+path, import.meta.url),'utf8')

test('Helios applies exclusively to Tennis Legacy, not ProPeloton Saturn',()=>{
  const roadmap=read('PROJECT_HELIOS.md')
  assert.match(roadmap,/Tennis Legacy: Rise to Glory ONLY/)
  assert.match(roadmap,/Project Saturn/)
})

test('admin analytics is visible in sidebar only to approved admins',()=>{
  const sidebar=read('src/components/layout/GameSidebar.tsx')
  const app=read('src/App.tsx')
  assert.match(sidebar,/\{isAdmin && \(/)
  assert.match(sidebar,/Admin Analytics/)
  assert.match(sidebar,/\/game\/admin\/analytics/)
  assert.match(app,/<RequireAdmin><AdminAnalyticsPage \/><\/RequireAdmin>/)
})

test('admin analytics only exposes aggregates and checks page-view totals',()=>{
  const sql=read('supabase/migrations/20261120094000_helios_admin_analytics_freshness.sql')
  const page=read('src/pages/manager/AdminAnalytics.tsx')
  assert.match(sql,/if not public\.is_app_admin_v1\(auth\.uid\(\)\) then/)
  assert.match(sql,/'recent_sessions_5m'/)
  assert.match(sql,/'recent_visitors_5m'/)
  assert.match(sql,/'totals_match'/)
  assert.match(page,/Recently recorded activity/)
  assert.match(page,/Tracking integrity/)
  assert.match(page,/These are not live connections/)
  assert.match(page,/Last recorded page navigation/)
})
