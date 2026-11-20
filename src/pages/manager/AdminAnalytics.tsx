import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
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

interface EconomyReport {
  generated_at: string
  timezone: string
  start_date: string
  end_date: string
  definition: string
  coin_movements: { credits: number; debits: number; entries: number; signup_grants: number; other_credits: number }
  career_finance: { opening_funds: number; operational_income: number; operational_expenses: number; transaction_entries: number; sponsor_related_entries: number; sponsor_related_net: number }
  billing: { paid_transactions: number; paid_eur_cents: number; paid_coin_packs: number; paid_premium: number; pending_transactions: number; failed_transactions: number }
  sponsorships: { sponsor_contracts_signed: number; active_sponsor_contracts_now: number; objective_rewards_recorded: number }
  current_balances: { wallet_count: number; wallet_coin_balance: number; wallet_negative_balances: number; wallet_vs_latest_ledger_discrepancies: number; human_career_balances: number }
}

interface GameActivityReport {
  generated_at: string
  timezone: string
  start_date: string
  end_date: string
  training_sessions: number
  tournament_applications: number
  completed_matches: number
  staff_contracts_signed: number
  nonstarter_equipment_acquired: number
  skill_history_updates: number
  distinct_human_players_with_actions: number
  last_gameplay_event_at: string | null
  is_game_clock_paused: boolean
  definition: string
}

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
  linked_funnel?: {
    homepage_browser_ids: number
    registration_browser_ids: number
    linked_accounts: number
    linked_players: number
    returned_browser_ids: number
    shared_browser_exclusion: boolean
    definition: string
  }
  presence?: {
    active_players_2m: number
    last_player_active_at: string | null
    definition: string
  }
  onboarding?: {
    landing_visitors: number
    registration_opened_visitors: number
    registration_completed_accounts: number
    player_created_accounts: number
    returned_registered_accounts: number
    data_note: string
  }
  freshness?: {
    last_pageview_at: string | null
    last_session_at: string | null
    recent_sessions_5m: number
    recent_visitors_5m: number
    recent_registered_5m: number
  }
  reconciliation?: {
    visitor_pageviews: number
    session_pageviews: number
    path_pageviews: number
    totals_match: boolean
  }
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
  const [gameActivity, setGameActivity] = useState<GameActivityReport | null>(null)
  const [economy, setEconomy] = useState<EconomyReport | null>(null)
  const [economyError, setEconomyError] = useState<string | null>(null)
  const [gameActivityError, setGameActivityError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [lastLoadedAt, setLastLoadedAt] = useState<Date | null>(null)
  const requestSequence = useRef(0)

  const loadDashboard = useCallback(async (nextPeriod: number, silent = false) => {
    const request = ++requestSequence.current
    if (!silent) setLoading(true)

    try {
      const [siteResult, gameResult, economyResult] = await Promise.all([
        supabase.rpc('get_admin_analytics_dashboard_v1', { p_days: nextPeriod }),
        supabase.rpc('get_admin_tennis_game_activity_v1', { p_days: nextPeriod }),
        supabase.rpc('get_admin_tennis_economy_v1', { p_days: nextPeriod }),
      ])
      if (request !== requestSequence.current) return
      if (siteResult.error || !siteResult.data) {
        throw new Error(siteResult.error?.message || 'Analytics could not be loaded.')
      }

      setDashboard(normalizeDashboard(siteResult.data as AnalyticsDashboard))
      if (gameResult.error || !gameResult.data) {
        setGameActivityError(gameResult.error?.message || 'Game activity could not be loaded.')
      } else {
        setGameActivity(gameResult.data as GameActivityReport)
        setGameActivityError(null)
      }
      if (economyResult.error || !economyResult.data) {
        setEconomyError(economyResult.error?.message || 'Economy metrics could not be loaded.')
      } else {
        setEconomy(economyResult.data as EconomyReport)
        setEconomyError(null)
      }
      setLastLoadedAt(new Date())
      setError(null)
    } catch (err) {
      if (request !== requestSequence.current) return
      setError(err instanceof Error ? err.message : 'Analytics could not be loaded.')
      // The last successful counts remain visible, marked by an error.
    } finally {
      if (request === requestSequence.current) setLoading(false)
    }
  }, [])

  useEffect(() => {
    void loadDashboard(period)
    const refreshIfVisible = () => {
      if (document.visibilityState === 'visible') void loadDashboard(period, true)
    }
    const interval = window.setInterval(refreshIfVisible, 60_000)
    window.addEventListener('focus', refreshIfVisible)
    return () => {
      requestSequence.current += 1
      window.clearInterval(interval)
      window.removeEventListener('focus', refreshIfVisible)
    }
  }, [period, loadDashboard])

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

        <p role="status" style={{ margin: '8px 0', fontSize: 12, color: '#586779' }}>
          {lastLoadedAt
            ? `Last loaded from database: ${lastLoadedAt.toLocaleTimeString()}`
            : 'Waiting for first analytics load'}
          {' · Auto-refresh every 60 seconds while visible'}
          {dashboard?.generated_at
            ? ` · Server generated: ${new Date(dashboard.generated_at).toLocaleString()}`
            : ''}
        </p>
        {error && <div className="tlg-admin-analytics-error">{error}</div>}

        <section className="tlg-admin-analytics-panel" aria-label="Tennis Legacy economy and transactions">
          <h2 style={{ marginBottom: 8 }}>Economy &amp; Transactions</h2>
          {economyError && <p role="alert" className="tlg-admin-analytics-error">Economy metrics refresh failed: {economyError}</p>}
          {economy ? (
            <>
              <p style={{ fontSize: 12, color: '#667085', marginBottom: 12 }}>
                Recorded transactions: {economy.start_date} – {economy.end_date} ({economy.timezone})
              </p>
              <div className="tlg-admin-analytics-summary">
                {([
                  ['Coins granted or earned', economy.coin_movements.credits],
                  ['Coins spent', economy.coin_movements.debits],
                  ['Welcome coins issued', economy.coin_movements.signup_grants],
                  ['Paid transactions', economy.billing.paid_transactions],
                  ['Paid revenue', asNumber(economy.billing.paid_eur_cents) / 100],
                  ['Paid Premium orders', economy.billing.paid_premium],
                  ['Paid coin packs', economy.billing.paid_coin_packs],
                  ['Career starting funds ($)', economy.career_finance.opening_funds],
                  ['Career income ($)', economy.career_finance.operational_income],
                  ['Career expenses ($)', economy.career_finance.operational_expenses],
                  ['Sponsor payments ($)', economy.career_finance.sponsor_related_net],
                  ['Sponsor contracts signed', economy.sponsorships.sponsor_contracts_signed],
                  ['Sponsor objective rewards', economy.sponsorships.objective_rewards_recorded],
                  ['Pending billing attempts', economy.billing.pending_transactions],
                  ['Failed billing attempts', economy.billing.failed_transactions],
                ] as const).map(([label, value]) => (
                  <article key={label}>
                    <BarChart3 size={18}/>
                    <div><span>{label}</span><strong>{label === 'Paid revenue'
                      ? new Intl.NumberFormat('en-IE', { style: 'currency', currency: 'EUR' }).format(asNumber(value))
                      : wholeNumber.format(asNumber(value))}</strong></div>
                  </article>
                ))}
              </div>
              <h3 style={{ marginTop: 16, marginBottom: 8 }}>Current balances &amp; integrity</h3>
              <div className="tlg-admin-analytics-summary">
                {([
                  ['Wallet coins', economy.current_balances.wallet_coin_balance],
                  ['Career balances ($)', economy.current_balances.human_career_balances],
                  ['Negative coin wallets', economy.current_balances.wallet_negative_balances],
                  ['Wallet/ledger differences', economy.current_balances.wallet_vs_latest_ledger_discrepancies],
                  ['Currently active sponsor contracts', economy.sponsorships.active_sponsor_contracts_now],
                ] as const).map(([label, value]) => (
                  <article key={label}>
                    <Activity size={18}/>
                    <div><span>{label}</span><strong>{wholeNumber.format(asNumber(value))}</strong></div>
                  </article>
                ))}
              </div>
              <p style={{ fontSize: 12, color: '#667085', marginTop: 10 }}>
                {economy.definition}
              </p>
            </>
          ) : !economyError ? <p>Loading economy metrics…</p> : null}
        </section>

        <section className="tlg-admin-analytics-panel" aria-label="Recorded tennis gameplay activity">
          <h2 style={{ marginBottom: 8 }}>Game Activity — Tennis Legacy</h2>
          {gameActivityError && (
            <p role="alert" className="tlg-admin-analytics-error">
              Gameplay metrics refresh failed: {gameActivityError}
            </p>
          )}
          {gameActivity ? (
            <>
              <p style={{ fontSize: 12, color: '#667085', marginBottom: 12 }}>
                {gameActivity.start_date} – {gameActivity.end_date} ({gameActivity.timezone})
                {gameActivity.is_game_clock_paused ? ' · Game clock paused' : ' · Game clock running'}
              </p>
              <div className="tlg-admin-analytics-summary">
                {([
                  ['Training sessions', gameActivity.training_sessions],
                  ['Tournament applications', gameActivity.tournament_applications],
                  ['Completed matches involving players', gameActivity.completed_matches],
                  ['Staff contracts signed', gameActivity.staff_contracts_signed],
                  ['Equipment acquired (not starter)', gameActivity.nonstarter_equipment_acquired],
                  ['Recorded skill changes', gameActivity.skill_history_updates],
                  ['Distinct active human players', gameActivity.distinct_human_players_with_actions],
                ] as const).map(([label, value]) => (
                  <article key={label}>
                    <Activity size={18}/>
                    <div><span>{label}</span><strong>{wholeNumber.format(asNumber(value))}</strong></div>
                  </article>
                ))}
              </div>
              <p style={{ fontSize: 12, color: '#667085', marginTop: 12 }}>
                Last recorded gameplay action: {gameActivity.last_gameplay_event_at
                  ? new Date(gameActivity.last_gameplay_event_at).toLocaleString()
                  : 'None in the selected period'}
              </p>
              <p style={{ fontSize: 12, color: '#667085', marginTop: 6 }}>
                {gameActivity.definition}
              </p>
            </>
          ) : !gameActivityError ? <p>Loading gameplay activity…</p> : null}
        </section>

        {dashboard?.presence && (
          <section className="tlg-admin-analytics-panel" aria-label="Authenticated player activity">
            <h2 style={{ marginBottom: 8 }}>Active tennis players</h2>
            <div className="tlg-admin-analytics-summary" style={{ marginBottom: 12 }}>
              <article>
                <UsersRound size={18} />
                <div>
                  <span>Active players · last 2 min</span>
                  <strong>{wholeNumber.format(asNumber(dashboard.presence.active_players_2m))}</strong>
                </div>
              </article>
            </div>
            <p style={{ fontSize: 12, color: '#667085', marginBottom: 6 }}>
              {dashboard.presence.definition}
            </p>
            <p style={{ fontSize: 12, color: '#667085' }}>
              Latest recorded player interaction:{' '}
              {dashboard.presence.last_player_active_at
                ? new Date(dashboard.presence.last_player_active_at).toLocaleString()
                : 'None recorded yet'}
            </p>
          </section>
        )}

        {dashboard?.freshness && (
          <section className="tlg-admin-analytics-panel" aria-label="Recently recorded website activity">
            <h2 style={{ marginBottom: 8 }}>Recently recorded activity</h2>
            <p style={{ fontSize: 12, color: '#667085', marginBottom: 14 }}>
              Browser navigation events seen in the last 5 minutes. These are not live connections:
              visitors who stay on a page without navigating may not appear.
            </p>
            <div className="tlg-admin-analytics-summary" style={{ marginBottom: 12 }}>
              <article>
                <Activity size={18} />
                <div><span>Sessions · 5 min</span>
                  <strong>{wholeNumber.format(asNumber(dashboard.freshness.recent_sessions_5m))}</strong></div>
              </article>
              <article>
                <UsersRound size={18} />
                <div><span>Visitors · 5 min</span>
                  <strong>{wholeNumber.format(asNumber(dashboard.freshness.recent_visitors_5m))}</strong></div>
              </article>
              <article>
                <UserPlus size={18} />
                <div><span>Registered · 5 min</span>
                  <strong>{wholeNumber.format(asNumber(dashboard.freshness.recent_registered_5m))}</strong></div>
              </article>
            </div>
            <p style={{ fontSize: 12, color: '#667085' }}>
              Last recorded page navigation:{' '}
              {dashboard.freshness.last_pageview_at
                ? new Date(dashboard.freshness.last_pageview_at).toLocaleString()
                : 'No recorded events'}
            </p>
          </section>
        )}

        {dashboard?.reconciliation && (
          <section className="tlg-admin-analytics-panel" aria-label="Analytics data integrity">
            <h2 style={{ marginBottom: 6 }}>Tracking integrity</h2>
            <p style={{ fontSize: 13, marginBottom: 6 }}>
              {dashboard.reconciliation.totals_match
                ? 'Recorded page-view totals agree across visitors, sessions and pages.'
                : 'Warning: recorded page-view totals differ across analytics tables.'}
            </p>
            <p style={{ fontSize: 12, color: '#667085' }}>
              Visitor totals: {wholeNumber.format(asNumber(dashboard.reconciliation.visitor_pageviews))}
              {' · '}Session totals: {wholeNumber.format(asNumber(dashboard.reconciliation.session_pageviews))}
              {' · '}Page totals: {wholeNumber.format(asNumber(dashboard.reconciliation.path_pageviews))}
            </p>
          </section>
        )}

        {dashboard?.linked_funnel && (
          <section className="tlg-admin-analytics-panel" aria-label="Linked onboarding journey">
            <h2 style={{ marginBottom: 8 }}>Browser-linked registration journey</h2>
            <div className="tlg-admin-analytics-summary">
              {([
                ['Homepage browsers', dashboard.linked_funnel.homepage_browser_ids],
                ['Reached registration', dashboard.linked_funnel.registration_browser_ids],
                ['Linked accounts created', dashboard.linked_funnel.linked_accounts],
                ['Linked tennis players', dashboard.linked_funnel.linked_players],
                ['Returned after 24h', dashboard.linked_funnel.returned_browser_ids],
              ] as const).map(([label, value]) => (
                <article key={label}>
                  <UserPlus size={18}/>
                  <div><span>{label}</span><strong>{wholeNumber.format(asNumber(value))}</strong></div>
                </article>
              ))}
            </div>
            <p style={{ fontSize: 12, color: '#667085', marginTop: 12 }}>
              {dashboard.linked_funnel.definition}
            </p>
          </section>
        )}

        {dashboard?.onboarding && (
          <section className="tlg-admin-analytics-panel" aria-label="Player onboarding stages">
            <h2 style={{ marginBottom: 8 }}>Registration &amp; player onboarding</h2>
            <div className="tlg-admin-analytics-summary">
              {([
                ['Homepage visitors', dashboard.onboarding.landing_visitors],
                ['Registration opened', dashboard.onboarding.registration_opened_visitors],
                ['Accounts created', dashboard.onboarding.registration_completed_accounts],
                ['Tennis players created', dashboard.onboarding.player_created_accounts],
                ['Returned after 24h', dashboard.onboarding.returned_registered_accounts],
              ] as const).map(([label, value]) => (
                <article key={label}>
                  <UserPlus size={18} />
                  <div><span>{label}</span><strong>{wholeNumber.format(asNumber(value))}</strong></div>
                </article>
              ))}
            </div>
            <p style={{ fontSize: 12, color: '#667085', marginTop: 12 }}>
              {dashboard.onboarding.data_note}
            </p>
          </section>
        )}

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
