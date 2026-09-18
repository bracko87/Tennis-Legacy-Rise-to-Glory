import { useEffect, useMemo, useState } from 'react'
import {
  Activity,
  BarChart3,
  Eye,
  Globe2,
  Monitor,
  MousePointerClick,
  RefreshCw,
  Smartphone,
  Tablet,
  UserPlus,
  UsersRound,
} from 'lucide-react'
import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'

import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'

interface AnalyticsSummary {
  unique_visitors: number
  pageviews: number
  sessions: number
  registered_active_users: number
  anonymous_visitors: number
  new_registrations: number
  total_registered_users: number
  dau: number
  wau: number
  mau: number
}

interface DailyPoint {
  date: string
  unique_visitors: number
  pageviews: number
  sessions: number
  registered_active_users: number
  new_registrations: number
}

interface CountryRow {
  country_code: string
  country_name: string
  unique_visitors: number
  pageviews: number
}

interface PageRow {
  path: string
  pageviews: number
  unique_visitors: number
}

interface DeviceRow {
  device_type: 'desktop' | 'tablet' | 'mobile'
  unique_visitors: number
  pageviews: number
}

interface SourceRow {
  source: string
  sessions: number
  unique_visitors: number
}

interface AnalyticsDashboard {
  generated_at: string
  timezone: string
  period: {
    start_date: string
    end_date: string
    days: number
  }
  summary: AnalyticsSummary
  daily: DailyPoint[]
  countries: CountryRow[]
  pages: PageRow[]
  devices: DeviceRow[]
  sources: SourceRow[]
}

const PERIOD_OPTIONS = [
  { value: 7, label: 'Last 7 days' },
  { value: 30, label: 'Last 30 days' },
  { value: 90, label: 'Last 3 months' },
  { value: 365, label: 'Last 12 months' },
  { value: 0, label: 'All time' },
]

const wholeNumber = new Intl.NumberFormat('en-US')
const compactNumber = new Intl.NumberFormat('en-US', {
  notation: 'compact',
  maximumFractionDigits: 1,
})

function asNumber(value: unknown) {
  const number = Number(value)
  return Number.isFinite(number) ? number : 0
}

function normalizeDashboard(value: AnalyticsDashboard): AnalyticsDashboard {
  return {
    ...value,
    summary: Object.fromEntries(
      Object.entries(value.summary ?? {}).map(([key, item]) => [key, asNumber(item)]),
    ) as unknown as AnalyticsSummary,
    daily: (value.daily ?? []).map((item) => ({
      ...item,
      unique_visitors: asNumber(item.unique_visitors),
      pageviews: asNumber(item.pageviews),
      sessions: asNumber(item.sessions),
      registered_active_users: asNumber(item.registered_active_users),
      new_registrations: asNumber(item.new_registrations),
    })),
    countries: (value.countries ?? []).map((item) => ({
      ...item,
      unique_visitors: asNumber(item.unique_visitors),
      pageviews: asNumber(item.pageviews),
    })),
    pages: (value.pages ?? []).map((item) => ({
      ...item,
      pageviews: asNumber(item.pageviews),
      unique_visitors: asNumber(item.unique_visitors),
    })),
    devices: (value.devices ?? []).map((item) => ({
      ...item,
      unique_visitors: asNumber(item.unique_visitors),
      pageviews: asNumber(item.pageviews),
    })),
    sources: (value.sources ?? []).map((item) => ({
      ...item,
      sessions: asNumber(item.sessions),
      unique_visitors: asNumber(item.unique_visitors),
    })),
  }
}

function CountryFlag({ code, name }: { readonly code: string; readonly name: string }) {
  const normalized = String(code || '').toUpperCase()
  if (!/^[A-Z]{2}$/.test(normalized) || normalized === 'XX') {
    return <Globe2 size={18} aria-label="Unknown country" />
  }

  return (
    <img
      className="tlg-admin-country-flag"
      src={'https://flagcdn.com/28x21/' + normalized.toLowerCase() + '.png'}
      srcSet={
        'https://flagcdn.com/56x42/' + normalized.toLowerCase() + '.png 2x, ' +
        'https://flagcdn.com/84x63/' + normalized.toLowerCase() + '.png 3x'
      }
      width="28"
      height="21"
      alt={name + ' flag'}
      loading="lazy"
    />
  )
}

function formatDay(value: string) {
  const date = new Date(`${value}T12:00:00`)
  if (Number.isNaN(date.getTime())) return value
  return new Intl.DateTimeFormat('en', { month: 'short', day: 'numeric' }).format(date)
}

function formatPath(path: string) {
  const known: Record<string, string> = {
    '/': 'Home',
    '/login': 'Login',
    '/register': 'Register',
    '/forgot-password': 'Forgot password',
    '/create-player': 'Create player',
    '/game/overview': 'Overview',
    '/game/skills': 'Skills',
    '/game/training': 'Training',
    '/game/staff': 'Staff',
    '/game/calendar': 'Calendar',
    '/game/schedule': 'Schedule',
    '/game/rankings': 'Rankings',
    '/game/equipment': 'Equipment',
    '/game/finance': 'Finance',
    '/game/injuries': 'Injuries',
    '/game/private-life': 'Private Life',
    '/game/tennis-club': 'Tennis Club',
    '/game/statistics': 'Statistics',
    '/game/inbox': 'Inbox',
    '/game/pro-packages': 'Pro Packages',
    '/game/invite-friends': 'Invite Friends',
  }
  if (known[path]) return known[path]
  if (path.startsWith('/game/tournaments/')) return 'Tournament detail'
  if (path.startsWith('/game/players/')) return 'Player profile'
  return path
}

function DeviceIcon({ type }: { readonly type: DeviceRow['device_type'] }) {
  if (type === 'mobile') return <Smartphone size={18} />
  if (type === 'tablet') return <Tablet size={18} />
  return <Monitor size={18} />
}

export default function AdminAnalyticsPage() {
  const [period, setPeriod] = useState(30)
  const [dashboard, setDashboard] = useState<AnalyticsDashboard | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  async function loadDashboard(nextPeriod = period) {
    setLoading(true)
    setError(null)

    const { data, error: rpcError } = await supabase.rpc(
      'get_admin_analytics_dashboard_v1',
      { p_days: nextPeriod },
    )

    if (rpcError || !data) {
      setDashboard(null)
      setError(rpcError?.message || 'Analytics could not be loaded.')
      setLoading(false)
      return
    }

    setDashboard(normalizeDashboard(data as AnalyticsDashboard))
    setLoading(false)
  }

  useEffect(() => {
    void loadDashboard(period)
  }, [period])

  const chartData = useMemo(
    () => (dashboard?.daily ?? []).map((point) => ({
      ...point,
      label: formatDay(point.date),
    })),
    [dashboard?.daily],
  )

  const summary = dashboard?.summary
  const maxCountryVisitors = Math.max(1, ...(dashboard?.countries ?? []).map((row) => row.unique_visitors))
  const maxPageviews = Math.max(1, ...(dashboard?.pages ?? []).map((row) => row.pageviews))
  const maxSourceSessions = Math.max(1, ...(dashboard?.sources ?? []).map((row) => row.sessions))

  return (
    <GameLayout title="Admin Analytics" subtitle="Private website traffic and player activity">
      <div className="tlg-admin-analytics">
        <div className="tlg-admin-analytics-toolbar">
          <div>
            <span>REPORTING WINDOW</span>
            <select value={period} onChange={(event) => setPeriod(Number(event.target.value))}>
              {PERIOD_OPTIONS.map((option) => (
                <option key={option.value} value={option.value}>{option.label}</option>
              ))}
            </select>
          </div>
          <button type="button" onClick={() => void loadDashboard()} disabled={loading}>
            <RefreshCw size={15} className={loading ? 'is-spinning' : undefined} />
            Refresh
          </button>
        </div>

        {error && <div className="tlg-admin-analytics-error">{error}</div>}

        <section className="tlg-admin-analytics-summary">
          <article><Eye size={18} /><div><span>Unique visitors</span><strong>{wholeNumber.format(summary?.unique_visitors ?? 0)}</strong></div></article>
          <article><MousePointerClick size={18} /><div><span>Pageviews</span><strong>{wholeNumber.format(summary?.pageviews ?? 0)}</strong></div></article>
          <article><Activity size={18} /><div><span>Sessions</span><strong>{wholeNumber.format(summary?.sessions ?? 0)}</strong></div></article>
          <article><UsersRound size={18} /><div><span>Active registered</span><strong>{wholeNumber.format(summary?.registered_active_users ?? 0)}</strong></div></article>
          <article><UserPlus size={18} /><div><span>New registrations</span><strong>{wholeNumber.format(summary?.new_registrations ?? 0)}</strong></div></article>
          <article><BarChart3 size={18} /><div><span>Total accounts</span><strong>{wholeNumber.format(summary?.total_registered_users ?? 0)}</strong></div></article>
        </section>

        <section className="tlg-admin-analytics-active-strip">
          <article><span>DAU</span><strong>{wholeNumber.format(summary?.dau ?? 0)}</strong><small>registered players today</small></article>
          <article><span>WAU</span><strong>{wholeNumber.format(summary?.wau ?? 0)}</strong><small>registered players · 7 days</small></article>
          <article><span>MAU</span><strong>{wholeNumber.format(summary?.mau ?? 0)}</strong><small>registered players · 30 days</small></article>
          <article><span>Anonymous</span><strong>{wholeNumber.format(summary?.anonymous_visitors ?? 0)}</strong><small>unique visitors in window</small></article>
        </section>

        <section className="tlg-admin-analytics-panel tlg-admin-analytics-trend">
          <header>
            <div><span>TRAFFIC TREND</span><h2>Visitors and registered activity</h2></div>
            <small>{dashboard ? `${dashboard.period.start_date} → ${dashboard.period.end_date}` : '—'}</small>
          </header>
          <div className="tlg-admin-analytics-chart">
            <ResponsiveContainer width="100%" height={310}>
              <LineChart data={chartData} margin={{ top: 12, right: 18, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} />
                <XAxis dataKey="label" minTickGap={24} tick={{ fontSize: 11 }} />
                <YAxis allowDecimals={false} width={42} tick={{ fontSize: 11 }} />
                <Tooltip formatter={(value: number) => wholeNumber.format(value)} />
                <Line type="monotone" dataKey="unique_visitors" name="Visitors" stroke="#1479b8" strokeWidth={2.4} dot={false} />
                <Line type="monotone" dataKey="registered_active_users" name="Registered active" stroke="#20a66a" strokeWidth={2.2} dot={false} />
                <Line type="monotone" dataKey="new_registrations" name="Registrations" stroke="#d58b18" strokeWidth={1.8} dot={false} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </section>

        <div className="tlg-admin-analytics-grid">
          <section className="tlg-admin-analytics-panel">
            <header><div><span>GEOGRAPHY</span><h2>Visitors by country</h2></div><Globe2 size={19} /></header>
            <div className="tlg-admin-analytics-ranked-list">
              {!dashboard?.countries.length && <p className="empty">No country data has been recorded yet.</p>}
              {dashboard?.countries.map((row) => (
                <article key={row.country_code}>
                  <div className="rank-main">
                    <span className="tlg-admin-country-flag-wrap">
                      <CountryFlag code={row.country_code} name={row.country_name} />
                    </span>
                    <div><strong>{row.country_name}</strong><small>{row.country_code}</small></div>
                    <span>{wholeNumber.format(row.unique_visitors)}</span>
                  </div>
                  <div className="rank-bar"><i style={{ width: `${Math.max(3, (row.unique_visitors / maxCountryVisitors) * 100)}%` }} /></div>
                  <small>{compactNumber.format(row.pageviews)} pageviews</small>
                </article>
              ))}
            </div>
          </section>

          <section className="tlg-admin-analytics-panel">
            <header><div><span>CONTENT</span><h2>Most visited pages</h2></div><Eye size={19} /></header>
            <div className="tlg-admin-analytics-ranked-list">
              {!dashboard?.pages.length && <p className="empty">No page data has been recorded yet.</p>}
              {dashboard?.pages.map((row) => (
                <article key={row.path}>
                  <div className="rank-main">
                    <div className="page-copy"><strong>{formatPath(row.path)}</strong><small>{row.path}</small></div>
                    <span>{wholeNumber.format(row.pageviews)}</span>
                  </div>
                  <div className="rank-bar"><i style={{ width: `${Math.max(3, (row.pageviews / maxPageviews) * 100)}%` }} /></div>
                  <small>{wholeNumber.format(row.unique_visitors)} unique visitors</small>
                </article>
              ))}
            </div>
          </section>
        </div>

        <div className="tlg-admin-analytics-grid">
          <section className="tlg-admin-analytics-panel">
            <header><div><span>ACQUISITION</span><h2>Traffic sources</h2></div></header>
            <div className="tlg-admin-analytics-ranked-list">
              {!dashboard?.sources.length && <p className="empty">No source data has been recorded yet.</p>}
              {dashboard?.sources.map((row) => (
                <article key={row.source}>
                  <div className="rank-main">
                    <div><strong>{row.source}</strong><small>{wholeNumber.format(row.unique_visitors)} visitors</small></div>
                    <span>{wholeNumber.format(row.sessions)}</span>
                  </div>
                  <div className="rank-bar"><i style={{ width: `${Math.max(3, (row.sessions / maxSourceSessions) * 100)}%` }} /></div>
                  <small>sessions</small>
                </article>
              ))}
            </div>
          </section>

          <section className="tlg-admin-analytics-panel">
            <header><div><span>DEVICES</span><h2>Visitor devices</h2></div></header>
            <div className="tlg-admin-analytics-devices">
              {!dashboard?.devices.length && <p className="empty">No device data has been recorded yet.</p>}
              {dashboard?.devices.map((row) => (
                <article key={row.device_type}>
                  <DeviceIcon type={row.device_type} />
                  <div><strong>{row.device_type}</strong><span>{wholeNumber.format(row.unique_visitors)} visitors</span></div>
                  <small>{compactNumber.format(row.pageviews)} views</small>
                </article>
              ))}
            </div>
          </section>
        </div>

        <footer className="tlg-admin-analytics-note">
          <strong>Privacy-safe first-party analytics.</strong>
          <span>
            Reporting uses Europe/Berlin day boundaries. The game stores random browser/session identifiers, page paths,
            device class and country code only — not visitor IP addresses or exact coordinates. Statistics begin when this feature is deployed.
          </span>
        </footer>
      </div>
    </GameLayout>
  )
}
