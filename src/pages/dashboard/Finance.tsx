import { useEffect, useMemo, useState, type CSSProperties } from 'react'
import { useSearchParams } from 'react-router'

import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/finance-v2.css'

type FinanceTab = 'overview' | 'transactions' | 'tax' | 'sponsors'
type AnalyticsGranularity = 'daily' | 'weekly' | 'monthly' | 'season'

interface FinanceTransaction {
  id: string
  game_absolute_day: number
  season: number
  month: number
  day: number
  category: string
  subcategory: string
  amount: number
  balance_before: number
  balance_after: number
  description: string
  source_type?: string | null
  source_id?: string | null
  metadata?: Record<string, unknown>
  is_taxable?: boolean
  created_at: string
}

interface FinanceCategoryTotal {
  category: string
  income: number
  expenses: number
  net: number
}

interface FinanceCommitment {
  kind: string
  due_absolute_day: number
  description: string
  amount: number
  metadata?: Record<string, unknown>
}

interface TaxPeriod {
  season: number
  month: number
  taxable_income: number
  tax_rate: number
  tax_amount: number
  due_absolute_day: number
  settled_absolute_day: number
}

interface FinanceTaxSummary {
  rate: number
  current_month_taxable_income: number
  current_month_estimated_tax: number
  next_settlement_absolute_day: number
  history: TaxPeriod[]
}

interface FinanceDashboard {
  player_id: string
  currency: string
  balance: number
  is_live: boolean
  current_absolute_day: number
  season: number
  month: number
  day: number
  season_income: number
  season_expenses: number
  season_net: number
  category_totals: FinanceCategoryTotal[]
  upcoming_commitments: FinanceCommitment[]
  recent_transactions: FinanceTransaction[]
  tax: FinanceTaxSummary
}

interface FinanceSeriesPoint {
  key: number
  label: string
  income: number
  expenses: number
  net: number
}

interface FinanceCategorySlice {
  category: string
  amount: number
}

interface FinanceAnalytics {
  granularity: AnalyticsGranularity
  from_absolute_day: number
  through_absolute_day: number
  series: FinanceSeriesPoint[]
  income_categories: FinanceCategorySlice[]
  expense_categories: FinanceCategorySlice[]
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const MONTH_LENGTHS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const TRANSACTIONS_PER_PAGE = 20
const DONUT_COLORS = ['#2f68cc', '#2d9a6a', '#d69a24', '#875bc6', '#d45a61', '#4b8fa3', '#7b879b']

function money(value: number, currency = 'USD') {
  const amount = Math.abs(Math.round(Number(value) || 0))
  const prefix = value < 0 ? '−' : ''
  return `${prefix}${currency === 'USD' ? '$' : `${currency} `}${amount.toLocaleString()}`
}

function signedMoney(value: number, currency = 'USD') {
  const amount = Math.abs(Math.round(Number(value) || 0))
  const prefix = value > 0 ? '+' : value < 0 ? '−' : ''
  return `${prefix}${currency === 'USD' ? '$' : `${currency} `}${amount.toLocaleString()}`
}

function gameDate(season: number, month: number, day: number) {
  return `${MONTHS[Math.max(0, month - 1)] ?? `M${month}`} ${day} · Season ${season}`
}

function absoluteGameDate(absoluteDay: number) {
  const safe = Math.max(0, Math.floor(Number(absoluteDay) || 0))
  const season = Math.floor(safe / 366) + 1
  let remaining = safe % 366
  let month = 1
  while (month <= 12 && remaining >= MONTH_LENGTHS[month - 1]) {
    remaining -= MONTH_LENGTHS[month - 1]
    month += 1
  }
  return gameDate(season, Math.min(month, 12), remaining + 1)
}

function label(value: string) {
  return value.replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function categoryName(value: string) {
  const names: Record<string, string> = {
    prize_money: 'Prize Money',
    sponsorship: 'Sponsorship',
    appearance_fee: 'Appearance Fees',
    performance_bonus: 'Performance Bonuses',
    other_income: 'Other Income',
    travel: 'Travel',
    hotel: 'Hotels',
    staff: 'Staff',
    training: 'Training',
    tax: 'Tax',
    career: 'Career',
  }
  return names[value] ?? label(value)
}

function donutBackground(items: FinanceCategorySlice[]) {
  const visible = items.filter((item) => Number(item.amount) > 0)
  const total = visible.reduce((sum, item) => sum + Number(item.amount), 0)
  if (total <= 0) return '#edf1f6'
  let cursor = 0
  const stops = visible.slice(0, DONUT_COLORS.length).map((item, index) => {
    const start = cursor
    cursor += (Number(item.amount) / total) * 100
    return `${DONUT_COLORS[index % DONUT_COLORS.length]} ${start.toFixed(2)}% ${cursor.toFixed(2)}%`
  })
  if (cursor < 100) stops.push(`#edf1f6 ${cursor.toFixed(2)}% 100%`)
  return `conic-gradient(${stops.join(', ')})`
}

export default function FinancePage() {
  const [searchParams] = useSearchParams()
  const requestedTab = searchParams.get('tab')
  const [activeTab, setActiveTab] = useState<FinanceTab>(() => (
    requestedTab === 'transactions' || requestedTab === 'tax' || requestedTab === 'sponsors'
      ? requestedTab
      : 'overview'
  ))
  const [dashboard, setDashboard] = useState<FinanceDashboard | null>(null)
  const [analytics, setAnalytics] = useState<FinanceAnalytics | null>(null)
  const [granularity, setGranularity] = useState<AnalyticsGranularity>('monthly')
  const [transactionPage, setTransactionPage] = useState(0)
  const [loading, setLoading] = useState(true)
  const [analyticsLoading, setAnalyticsLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function loadDashboard(background = false) {
    if (background) setRefreshing(true)
    else setLoading(true)
    setError(null)
    const { data, error: financeError } = await supabase.rpc('get_career_finance_dashboard_v1', { p_limit: 500 })
    if (financeError || !data) setError(financeError?.message ?? 'Unable to load career finances.')
    else setDashboard(data as FinanceDashboard)
    setLoading(false)
    if (background) setRefreshing(false)
  }

  async function loadAnalytics(nextGranularity: AnalyticsGranularity) {
    setAnalyticsLoading(true)
    const { data, error: analyticsError } = await supabase.rpc('get_career_finance_analytics_v1', { p_granularity: nextGranularity })
    if (analyticsError || !data) setError(analyticsError?.message ?? 'Unable to load finance analytics.')
    else setAnalytics(data as FinanceAnalytics)
    setAnalyticsLoading(false)
  }

  async function refreshAll() {
    setRefreshing(true)
    await Promise.all([loadDashboard(false), loadAnalytics(granularity)])
    setRefreshing(false)
  }

  useEffect(() => {
    if (requestedTab === 'overview' || requestedTab === 'transactions' || requestedTab === 'tax' || requestedTab === 'sponsors') {
      setActiveTab(requestedTab)
    }
  }, [requestedTab])

  useEffect(() => {
    void loadDashboard()
  }, [])

  useEffect(() => {
    void loadAnalytics(granularity)
  }, [granularity])

  const transactions = dashboard?.recent_transactions ?? []
  const transactionPages = Math.max(1, Math.ceil(transactions.length / TRANSACTIONS_PER_PAGE))
  const visibleTransactions = useMemo(
    () => transactions.slice(transactionPage * TRANSACTIONS_PER_PAGE, transactionPage * TRANSACTIONS_PER_PAGE + TRANSACTIONS_PER_PAGE),
    [transactions, transactionPage],
  )

  useEffect(() => {
    if (transactionPage >= transactionPages) setTransactionPage(Math.max(0, transactionPages - 1))
  }, [transactionPage, transactionPages])

  return (
    <GameLayout title="Finance" subtitle="Career balance, tax, expenses and transaction history">
      <div className="tlg-finance-v2-page">
        <section className="tlg-finance-v2-hero">
          <div>
            <span className="eyebrow">CAREER ECONOMY</span>
            <h1>Finance Center</h1>
            <p>One USD career account for tennis income, staff, travel, accommodation, training and future Private Life spending. Premium coins remain completely separate.</p>
          </div>
          <button type="button" className="tlg-finance-v2-refresh" onClick={() => void refreshAll()} disabled={refreshing || loading}>
            {refreshing ? 'Refreshing…' : 'Refresh finances'}
          </button>
        </section>

        {loading ? (
          <div className="tlg-finance-v2-state">Loading career finances…</div>
        ) : error && !dashboard ? (
          <div className="tlg-finance-v2-state error">{error}</div>
        ) : dashboard ? (
          <>
            {error && <div className="tlg-finance-v2-inline-error">{error}</div>}

            <section className="tlg-finance-v2-summary">
              <div className={`balance ${dashboard.balance < 0 ? 'negative-balance' : ''}`}>
                <span>CAREER BALANCE</span>
                <strong>{money(dashboard.balance, 'USD')}</strong>
                <small>Available career cash · USD</small>
              </div>
              <MetricCard label="Season income" value={money(dashboard.season_income, 'USD')} tone="positive" />
              <MetricCard label="Season expenses" value={money(dashboard.season_expenses, 'USD')} tone="negative" />
              <MetricCard label="Season net" value={signedMoney(dashboard.season_net, 'USD')} tone={dashboard.season_net >= 0 ? 'positive' : 'negative'} />
              <MetricCard label="Estimated tax" value={money(dashboard.tax?.current_month_estimated_tax ?? 0, 'USD')} detail={`${Math.round((dashboard.tax?.rate ?? 0.18) * 100)}% monthly`} />
            </section>

            <nav className="tlg-finance-v2-tabs" aria-label="Finance sections">
              {(['overview', 'transactions', 'tax', 'sponsors'] as FinanceTab[]).map((tab) => (
                <button key={tab} type="button" className={activeTab === tab ? 'active' : ''} onClick={() => setActiveTab(tab)}>
                  {tab === 'tax' ? 'Tax' : label(tab)}
                </button>
              ))}
            </nav>

            {activeTab === 'overview' && (
              <div className="tlg-finance-v2-overview">
                <section className="tlg-finance-v2-panel tlg-finance-v2-flow-panel">
                  <div className="tlg-finance-v2-panel-head">
                    <div><span>FINANCIAL FLOW</span><h2>Income vs expenses</h2><p>Switch the time scale to inspect short-term cash flow or the wider career picture.</p></div>
                    <div className="tlg-finance-v2-periods" role="group" aria-label="Finance chart period">
                      {(['daily', 'weekly', 'monthly', 'season'] as AnalyticsGranularity[]).map((period) => (
                        <button key={period} type="button" className={granularity === period ? 'active' : ''} onClick={() => setGranularity(period)}>{label(period)}</button>
                      ))}
                    </div>
                  </div>
                  <CashFlowChart analytics={analytics} loading={analyticsLoading} currency="USD" />
                </section>

                <section className="tlg-finance-v2-donut-grid">
                  <DonutPanel title="Income mix" subtitle="Where career income comes from" items={analytics?.income_categories ?? []} currency="USD" />
                  <DonutPanel title="Expense mix" subtitle="Where career money is spent" items={analytics?.expense_categories ?? []} currency="USD" />
                  <section className="tlg-finance-v2-panel tlg-finance-v2-tax-ring-panel">
                    <div className="tlg-finance-v2-panel-head compact"><div><span>MONTHLY TAX</span><h2>Tax exposure</h2></div></div>
                    <div className="tlg-finance-v2-tax-ring-wrap">
                      <div className="tlg-finance-v2-tax-ring" style={{ '--tax-angle': `${(dashboard.tax?.rate ?? 0.18) * 360}deg` } as CSSProperties}>
                        <div><strong>{Math.round((dashboard.tax?.rate ?? 0.18) * 100)}%</strong><span>flat rate</span></div>
                      </div>
                      <div className="tlg-finance-v2-tax-ring-copy">
                        <span>Taxable this month</span><strong>{money(dashboard.tax?.current_month_taxable_income ?? 0, 'USD')}</strong>
                        <small>Estimated settlement {money(dashboard.tax?.current_month_estimated_tax ?? 0, 'USD')}</small>
                      </div>
                    </div>
                  </section>
                </section>

                <div className="tlg-finance-v2-two-column">
                  <section className="tlg-finance-v2-panel">
                    <div className="tlg-finance-v2-panel-head compact"><div><span>NEXT COSTS</span><h2>Upcoming commitments</h2></div><small>Next 60 game days</small></div>
                    {dashboard.upcoming_commitments.length === 0 ? <EmptyState text="No scheduled financial commitments." /> : (
                      <div className="tlg-finance-v2-commitments">
                        {dashboard.upcoming_commitments.slice(0, 8).map((item, index) => (
                          <div key={`${item.kind}-${item.due_absolute_day}-${index}`}>
                            <div><strong>{item.description}</strong><span>{categoryName(item.kind)} · {absoluteGameDate(item.due_absolute_day)}</span></div>
                            <b>−{money(item.amount, 'USD')}</b>
                          </div>
                        ))}
                      </div>
                    )}
                  </section>

                  <section className="tlg-finance-v2-panel">
                    <div className="tlg-finance-v2-panel-head compact"><div><span>LATEST ACTIVITY</span><h2>Recent transactions</h2></div><button type="button" className="text-action" onClick={() => setActiveTab('transactions')}>View ledger</button></div>
                    <CompactTransactions transactions={transactions.slice(0, 6)} />
                  </section>
                </div>
              </div>
            )}

            {activeTab === 'transactions' && (
              <section className="tlg-finance-v2-panel tlg-finance-v2-ledger-panel">
                <div className="tlg-finance-v2-panel-head">
                  <div><span>PERMANENT LEDGER</span><h2>Career transactions</h2><p>Every career-money movement is recorded with its game date, reason, source, amount and resulting balance.</p></div>
                  <small>20 transactions per page</small>
                </div>
                <TransactionTable transactions={visibleTransactions} />
                <div className="tlg-finance-v2-pagination">
                  <span>Page {transactionPage + 1} of {transactionPages} · {transactions.length} transactions loaded</span>
                  <div>
                    <button type="button" onClick={() => setTransactionPage((page) => Math.max(0, page - 1))} disabled={transactionPage === 0}>Previous</button>
                    <button type="button" onClick={() => setTransactionPage((page) => Math.min(transactionPages - 1, page + 1))} disabled={transactionPage >= transactionPages - 1}>Next</button>
                  </div>
                </div>
              </section>
            )}

            {activeTab === 'tax' && (
              <div className="tlg-finance-v2-tax-page">
                <section className="tlg-finance-v2-panel tlg-finance-v2-tax-hero">
                  <div className="tlg-finance-v2-tax-big-rate"><strong>{Math.round((dashboard.tax?.rate ?? 0.18) * 100)}%</strong><span>UNIVERSAL MONTHLY INCOME TAX</span></div>
                  <div className="tlg-finance-v2-tax-summary">
                    <div><span>Current month taxable income</span><strong>{money(dashboard.tax?.current_month_taxable_income ?? 0, 'USD')}</strong></div>
                    <div><span>Estimated tax</span><strong>{money(dashboard.tax?.current_month_estimated_tax ?? 0, 'USD')}</strong></div>
                    <div><span>Next settlement</span><strong>{absoluteGameDate(dashboard.tax?.next_settlement_absolute_day ?? dashboard.current_absolute_day)}</strong></div>
                  </div>
                </section>

                <section className="tlg-finance-v2-panel">
                  <div className="tlg-finance-v2-panel-head"><div><span>TAX PROCEDURE</span><h2>How monthly tax works</h2></div></div>
                  <div className="tlg-finance-v2-tax-rules">
                    <div><strong>1. Income is tagged</strong><p>Prize money, sponsorship income, appearance fees, performance bonuses and other career income are marked taxable when posted to the central ledger.</p></div>
                    <div><strong>2. Month closes</strong><p>On the first game day of the following month, the engine totals taxable income from the completed month.</p></div>
                    <div><strong>3. Flat 18% settlement</strong><p>The same 18% rate applies regardless of the player's country. Expenses are not deductions in this first tax version.</p></div>
                    <div><strong>4. One permanent transaction</strong><p>The tax payment is posted once with an idempotent monthly key, so catch-up processing can never tax the same month twice.</p></div>
                  </div>
                </section>

                <section className="tlg-finance-v2-panel">
                  <div className="tlg-finance-v2-panel-head"><div><span>SETTLEMENT HISTORY</span><h2>Monthly tax history</h2></div></div>
                  <TaxHistoryTable history={dashboard.tax?.history ?? []} />
                </section>
              </div>
            )}

            {activeTab === 'sponsors' && (
              <section className="tlg-finance-v2-panel tlg-finance-v2-sponsors">
                <span>SPONSORSHIPS</span>
                <h2>Commercial income will use this same account</h2>
                <p>Sponsor offers, weekly payments and performance bonuses are the next income layer. When implemented, every payment will enter this same USD ledger and taxable sponsor income will automatically feed the monthly 18% tax process.</p>
              </section>
            )}
          </>
        ) : null}
      </div>
    </GameLayout>
  )
}

function MetricCard({ label: metricLabel, value, tone, detail }: { label: string; value: string; tone?: 'positive' | 'negative'; detail?: string }) {
  return <div className="tlg-finance-v2-metric"><span>{metricLabel.toUpperCase()}</span><strong className={tone ?? ''}>{value}</strong>{detail && <small>{detail}</small>}</div>
}

function CashFlowChart({ analytics, loading, currency }: { analytics: FinanceAnalytics | null; loading: boolean; currency: string }) {
  if (loading) return <div className="tlg-finance-v2-chart-state">Loading chart…</div>
  const series = analytics?.series ?? []
  if (series.length === 0) return <div className="tlg-finance-v2-chart-state">No income or expenses yet in this period. The chart will populate automatically as the career economy starts moving.</div>
  const max = Math.max(1, ...series.flatMap((point) => [Number(point.income), Number(point.expenses)]))
  return (
    <div className="tlg-finance-v2-cash-chart">
      <div className="tlg-finance-v2-chart-legend"><span><i className="income" />Income</span><span><i className="expenses" />Expenses</span></div>
      <div className="tlg-finance-v2-bars">
        {series.map((point) => (
          <div className="bar-group" key={point.key} title={`${point.label}: income ${money(point.income, currency)}, expenses ${money(point.expenses, currency)}`}>
            <div className="bars"><i className="income" style={{ height: `${Math.max(3, (Number(point.income) / max) * 100)}%` }} /><i className="expenses" style={{ height: `${Math.max(3, (Number(point.expenses) / max) * 100)}%` }} /></div>
            <span>{point.label}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

function DonutPanel({ title, subtitle, items, currency }: { title: string; subtitle: string; items: FinanceCategorySlice[]; currency: string }) {
  const visible = items.filter((item) => Number(item.amount) > 0).slice(0, DONUT_COLORS.length)
  const total = visible.reduce((sum, item) => sum + Number(item.amount), 0)
  return (
    <section className="tlg-finance-v2-panel tlg-finance-v2-donut-panel">
      <div className="tlg-finance-v2-panel-head compact"><div><span>BREAKDOWN</span><h2>{title}</h2><p>{subtitle}</p></div></div>
      {total <= 0 ? <div className="tlg-finance-v2-donut-empty"><div className="empty-ring" /><span>No data yet</span></div> : (
        <div className="tlg-finance-v2-donut-content">
          <div className="tlg-finance-v2-donut" style={{ background: donutBackground(visible) }}><div><strong>{money(total, currency)}</strong><span>Total</span></div></div>
          <div className="tlg-finance-v2-donut-legend">
            {visible.map((item, index) => <div key={item.category}><i style={{ background: DONUT_COLORS[index % DONUT_COLORS.length] }} /><span>{categoryName(item.category)}</span><strong>{money(item.amount, currency)}</strong></div>)}
          </div>
        </div>
      )}
    </section>
  )
}

function CompactTransactions({ transactions }: { transactions: FinanceTransaction[] }) {
  if (transactions.length === 0) return <EmptyState text="No transactions yet." />
  return <div className="tlg-finance-v2-compact-transactions">{transactions.map((tx) => <div key={tx.id}><div><strong>{tx.description}</strong><span>{gameDate(tx.season, tx.month, tx.day)} · {categoryName(tx.category)}</span></div><b className={tx.amount >= 0 ? 'positive' : 'negative'}>{signedMoney(tx.amount, 'USD')}</b></div>)}</div>
}

function TransactionTable({ transactions }: { transactions: FinanceTransaction[] }) {
  if (transactions.length === 0) return <EmptyState text="No transactions on this page." />
  return (
    <div className="tlg-finance-v2-table-wrap">
      <table className="tlg-finance-v2-ledger-table">
        <thead><tr><th>Date</th><th>Reason / transaction</th><th>Category</th><th>Source</th><th className="amount">Amount</th><th className="amount">Balance</th></tr></thead>
        <tbody>{transactions.map((tx) => <tr key={tx.id}><td>{gameDate(tx.season, tx.month, tx.day)}</td><td><strong>{tx.description}</strong><small>{label(tx.subcategory)}{tx.is_taxable ? ' · Taxable income' : ''}</small></td><td>{categoryName(tx.category)}</td><td>{tx.source_type ? label(tx.source_type) : 'System'}</td><td className={`amount ${tx.amount >= 0 ? 'positive' : 'negative'}`}>{signedMoney(tx.amount, 'USD')}</td><td className="amount">{money(tx.balance_after, 'USD')}</td></tr>)}</tbody>
      </table>
    </div>
  )
}

function TaxHistoryTable({ history }: { history: TaxPeriod[] }) {
  if (history.length === 0) return <EmptyState text="No completed monthly tax settlements yet. The first one will be created after the current in-game month ends." />
  return (
    <div className="tlg-finance-v2-table-wrap">
      <table className="tlg-finance-v2-ledger-table">
        <thead><tr><th>Tax period</th><th>Taxable income</th><th>Rate</th><th>Tax paid</th><th>Settlement</th></tr></thead>
        <tbody>{history.map((row) => <tr key={`${row.season}-${row.month}`}><td>{MONTHS[row.month - 1]} · Season {row.season}</td><td>{money(row.taxable_income, 'USD')}</td><td>{Math.round(Number(row.tax_rate) * 100)}%</td><td className="negative">−{money(row.tax_amount, 'USD')}</td><td>{absoluteGameDate(row.settled_absolute_day)}</td></tr>)}</tbody>
      </table>
    </div>
  )
}

function EmptyState({ text }: { text: string }) {
  return <div className="tlg-finance-v2-empty">{text}</div>
}
