import { useEffect, useMemo, useState, type CSSProperties } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { useSearchParams } from 'react-router'

import GameLayout from '../../components/layout/GameLayout'
import { useLocalization } from '../../i18n/LocalizationProvider'
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

const MONTH_LENGTHS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const TRANSACTIONS_PER_PAGE = 20
const DONUT_COLORS = ['#2f68cc', '#2d9a6a', '#d69a24', '#875bc6', '#d45a61', '#4b8fa3', '#7b879b']

function financeDate(season: number, month: number, day: number, t: TFunction) {
  const months = t('staffPage.months', { returnObjects: true }) as string[]
  const monthLabel = months[Math.max(1, month)] ?? `M${month}`
  return t('financePage.gameDate', { month: monthLabel, day, season })
}

function absoluteGameDate(absoluteDay: number, t: TFunction) {
  const safe = Math.max(0, Math.floor(Number(absoluteDay) || 0))
  const season = Math.floor(safe / 366) + 1
  let remaining = safe % 366
  let month = 1
  while (month <= 12 && remaining >= MONTH_LENGTHS[month - 1]) {
    remaining -= MONTH_LENGTHS[month - 1]
    month += 1
  }
  return financeDate(season, Math.min(month, 12), remaining + 1, t)
}

function label(value: string) {
  return value.replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function categoryName(value: string, t: TFunction) {
  return t(`financePage.categories.${value}`, { defaultValue: label(value) })
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
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()
  const money = (value: number, currency = 'USD') => {
    const amount = formatCurrency(Math.abs(Math.round(Number(value) || 0)), currency)
    return value < 0 ? `−${amount}` : amount
  }
  const signedMoney = (value: number, currency = 'USD') => {
    const amount = formatCurrency(Math.abs(Math.round(Number(value) || 0)), currency)
    return value > 0 ? `+${amount}` : value < 0 ? `−${amount}` : amount
  }
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
    if (financeError || !data) setError(financeError?.message ?? t('financePage.loadError'))
    else setDashboard(data as FinanceDashboard)
    setLoading(false)
    if (background) setRefreshing(false)
  }

  async function loadAnalytics(nextGranularity: AnalyticsGranularity) {
    setAnalyticsLoading(true)
    const { data, error: analyticsError } = await supabase.rpc('get_career_finance_analytics_v1', { p_granularity: nextGranularity })
    if (analyticsError || !data) setError(analyticsError?.message ?? t('financePage.analyticsError'))
    else setAnalytics(data as FinanceAnalytics)
    setAnalyticsLoading(false)
  }

  async function refreshAll() {
    setRefreshing(true)
    await Promise.all([loadDashboard(true), loadAnalytics(granularity)])
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
    <GameLayout title={t('financePage.title')} subtitle={t('financePage.subtitle')}>
      <div className="tlg-finance-v2-page">
        <section className="tlg-finance-v2-hero">
          <div>
            <span className="eyebrow">CAREER ECONOMY</span>
            <h1>Finance Center</h1>
            <p>One USD career account for tennis income, staff, travel, accommodation, training and future Private Life spending. Premium coins remain completely separate.</p>
          </div>
          <button type="button" className="tlg-finance-v2-refresh" onClick={() => void refreshAll()} disabled={refreshing || loading}>
            {refreshing ? t('financePage.refreshing') : t('financePage.refresh')}
          </button>
        </section>

        {loading ? (
          <div className="tlg-finance-v2-state">{t('financePage.loading')}</div>
        ) : error && !dashboard ? (
          <div className="tlg-finance-v2-state error">{error}</div>
        ) : dashboard ? (
          <>
            {error && <div className="tlg-finance-v2-inline-error">{error}</div>}

            <section className="tlg-finance-v2-summary">
              <div className={`balance ${dashboard.balance < 0 ? 'negative-balance' : ''}`}>
                <span>{t('financePage.balance')}</span>
                <strong>{money(dashboard.balance, 'USD')}</strong>
                <small>{t('financePage.availableCash')}</small>
              </div>
              <MetricCard label={t('financePage.seasonIncome')} value={money(dashboard.season_income, 'USD')} tone="positive" />
              <MetricCard label={t('financePage.seasonExpenses')} value={money(dashboard.season_expenses, 'USD')} tone="negative" />
              <MetricCard label={t('financePage.seasonNet')} value={signedMoney(dashboard.season_net, 'USD')} tone={dashboard.season_net >= 0 ? 'positive' : 'negative'} />
              <MetricCard label={t('financePage.estimatedTax')} value={money(dashboard.tax?.current_month_estimated_tax ?? 0, 'USD')} detail={t('financePage.monthlyRate', { rate: Math.round((dashboard.tax?.rate ?? 0.18) * 100) })} />
            </section>

            <nav className="tlg-finance-v2-tabs" aria-label={t('financePage.tabsAria')}>
              {(['overview', 'transactions', 'tax', 'sponsors'] as FinanceTab[]).map((tab) => (
                <button key={tab} type="button" className={activeTab === tab ? 'active' : ''} onClick={() => setActiveTab(tab)}>
                  {t(`financePage.tabs.${tab}`)}
                </button>
              ))}
            </nav>

            {activeTab === 'overview' && (
              <div className="tlg-finance-v2-overview">
                <section className="tlg-finance-v2-panel tlg-finance-v2-flow-panel">
                  <div className="tlg-finance-v2-panel-head">
                    <div><span>{t('financePage.overview.flowKicker')}</span><h2>{t('financePage.overview.flowTitle')}</h2><p>{t('financePage.overview.flowBody')}</p></div>
                    <div className="tlg-finance-v2-periods" role="group" aria-label={t('financePage.overview.chartAria')}>
                      {(['daily', 'weekly', 'monthly', 'season'] as AnalyticsGranularity[]).map((period) => (
                        <button key={period} type="button" className={granularity === period ? 'active' : ''} onClick={() => setGranularity(period)}>{t(`financePage.granularity.${period}`)}</button>
                      ))}
                    </div>
                  </div>
                  <CashFlowChart t={t} money={money} analytics={analytics} loading={analyticsLoading} currency="USD" />
                </section>

                <section className="tlg-finance-v2-donut-grid">
                  <DonutPanel t={t} money={money} title={t('financePage.overview.incomeMix')} subtitle={t('financePage.overview.incomeMixBody')} items={analytics?.income_categories ?? []} currency="USD" />
                  <DonutPanel t={t} money={money} title={t('financePage.overview.expenseMix')} subtitle={t('financePage.overview.expenseMixBody')} items={analytics?.expense_categories ?? []} currency="USD" />
                  <section className="tlg-finance-v2-panel tlg-finance-v2-tax-ring-panel">
                    <div className="tlg-finance-v2-panel-head compact"><div><span>{t('financePage.overview.monthlyTax')}</span><h2>{t('financePage.overview.taxExposure')}</h2></div></div>
                    <div className="tlg-finance-v2-tax-ring-wrap">
                      <div className="tlg-finance-v2-tax-ring" style={{ '--tax-angle': `${(dashboard.tax?.rate ?? 0.18) * 360}deg` } as CSSProperties}>
                        <div><strong>{Math.round((dashboard.tax?.rate ?? 0.18) * 100)}%</strong><span>{t('financePage.overview.flatRate')}</span></div>
                      </div>
                      <div className="tlg-finance-v2-tax-ring-copy">
                        <span>{t('financePage.overview.taxableMonth')}</span><strong>{money(dashboard.tax?.current_month_taxable_income ?? 0, 'USD')}</strong>
                        <small>{t('financePage.overview.estimatedSettlement', { amount: money(dashboard.tax?.current_month_estimated_tax ?? 0, 'USD') })}</small>
                      </div>
                    </div>
                  </section>
                </section>

                <div className="tlg-finance-v2-two-column">
                  <section className="tlg-finance-v2-panel">
                    <div className="tlg-finance-v2-panel-head compact"><div><span>{t('financePage.overview.nextCosts')}</span><h2>{t('financePage.overview.commitments')}</h2></div><small>{t('financePage.overview.next60')}</small></div>
                    {dashboard.upcoming_commitments.length === 0 ? <EmptyState text={t('financePage.overview.noCommitments')} /> : (
                      <div className="tlg-finance-v2-commitments">
                        {dashboard.upcoming_commitments.slice(0, 8).map((item, index) => (
                          <div key={`${item.kind}-${item.due_absolute_day}-${index}`}>
                            <div><strong>{item.description}</strong><span>{categoryName(item.kind, t)} · {absoluteGameDate(item.due_absolute_day, t)}</span></div>
                            <b>−{money(item.amount, 'USD')}</b>
                          </div>
                        ))}
                      </div>
                    )}
                  </section>

                  <section className="tlg-finance-v2-panel">
                    <div className="tlg-finance-v2-panel-head compact"><div><span>{t('financePage.overview.latest')}</span><h2>{t('financePage.overview.recent')}</h2></div><button type="button" className="text-action" onClick={() => setActiveTab('transactions')}>{t('financePage.overview.viewLedger')}</button></div>
                    <CompactTransactions t={t} money={money} signedMoney={signedMoney} transactions={transactions.slice(0, 6)} />
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
                <TransactionTable t={t} money={money} signedMoney={signedMoney} transactions={visibleTransactions} />
                <div className="tlg-finance-v2-pagination">
                  <span>{t('financePage.ledger.page', { page: transactionPage + 1, pages: transactionPages, count: transactions.length })}</span>
                  <div>
                    <button type="button" onClick={() => setTransactionPage((page) => Math.max(0, page - 1))} disabled={transactionPage === 0}>{t('financePage.ledger.previous')}</button>
                    <button type="button" onClick={() => setTransactionPage((page) => Math.min(transactionPages - 1, page + 1))} disabled={transactionPage >= transactionPages - 1}>{t('financePage.ledger.next')}</button>
                  </div>
                </div>
              </section>
            )}

            {activeTab === 'tax' && (
              <div className="tlg-finance-v2-tax-page">
                <section className="tlg-finance-v2-panel tlg-finance-v2-tax-hero">
                  <div className="tlg-finance-v2-tax-big-rate"><strong>{Math.round((dashboard.tax?.rate ?? 0.18) * 100)}%</strong><span>{t('financePage.tax.universal')}</span></div>
                  <div className="tlg-finance-v2-tax-summary">
                    <div><span>{t('financePage.tax.taxableIncome')}</span><strong>{money(dashboard.tax?.current_month_taxable_income ?? 0, 'USD')}</strong></div>
                    <div><span>{t('financePage.tax.estimated')}</span><strong>{money(dashboard.tax?.current_month_estimated_tax ?? 0, 'USD')}</strong></div>
                    <div><span>{t('financePage.tax.nextSettlement')}</span><strong>{absoluteGameDate(dashboard.tax?.next_settlement_absolute_day ?? dashboard.current_absolute_day, t)}</strong></div>
                  </div>
                </section>

                <section className="tlg-finance-v2-panel">
                  <div className="tlg-finance-v2-panel-head"><div><span>{t('financePage.tax.procedure')}</span><h2>{t('financePage.tax.how')}</h2></div></div>
                  <div className="tlg-finance-v2-tax-rules">
                    <div><strong>{t('financePage.tax.rule1Title')}</strong><p>{t('financePage.tax.rule1Body')}</p></div>
                    <div><strong>{t('financePage.tax.rule2Title')}</strong><p>{t('financePage.tax.rule2Body')}</p></div>
                    <div><strong>{t('financePage.tax.rule3Title')}</strong><p>{t('financePage.tax.rule3Body')}</p></div>
                    <div><strong>{t('financePage.tax.rule4Title')}</strong><p>{t('financePage.tax.rule4Body')}</p></div>
                  </div>
                </section>

                <section className="tlg-finance-v2-panel">
                  <div className="tlg-finance-v2-panel-head"><div><span>{t('financePage.tax.historyKicker')}</span><h2>{t('financePage.tax.historyTitle')}</h2></div></div>
                  <TaxHistoryTable t={t} money={money} history={dashboard.tax?.history ?? []} />
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

function CashFlowChart({ t, money, analytics, loading, currency }: { t: TFunction; money: (value: number, currency?: string) => string; analytics: FinanceAnalytics | null; loading: boolean; currency: string }) {
  if (loading) return <div className="tlg-finance-v2-chart-state">{t('financePage.chart.loading')}</div>
  const series = analytics?.series ?? []
  if (series.length === 0) return <div className="tlg-finance-v2-chart-state">{t('financePage.chart.empty')}</div>
  const max = Math.max(1, ...series.flatMap((point) => [Number(point.income), Number(point.expenses)]))
  return (
    <div className="tlg-finance-v2-cash-chart">
      <div className="tlg-finance-v2-chart-legend"><span><i className="income" />{t('financePage.chart.income')}</span><span><i className="expenses" />{t('financePage.chart.expenses')}</span></div>
      <div className="tlg-finance-v2-bars">
        {series.map((point) => (
          <div className="bar-group" key={point.key} title={t('financePage.chart.tooltip', { label: point.label, income: money(point.income, currency), expenses: money(point.expenses, currency) })}>
            <div className="bars"><i className="income" style={{ height: `${Math.max(3, (Number(point.income) / max) * 100)}%` }} /><i className="expenses" style={{ height: `${Math.max(3, (Number(point.expenses) / max) * 100)}%` }} /></div>
            <span>{point.label}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

function DonutPanel({ t, money, title, subtitle, items, currency }: { t: TFunction; money: (value: number, currency?: string) => string; title: string; subtitle: string; items: FinanceCategorySlice[]; currency: string }) {
  const visible = items.filter((item) => Number(item.amount) > 0).slice(0, DONUT_COLORS.length)
  const total = visible.reduce((sum, item) => sum + Number(item.amount), 0)
  return (
    <section className="tlg-finance-v2-panel tlg-finance-v2-donut-panel">
      <div className="tlg-finance-v2-panel-head compact"><div><span>{t('financePage.breakdown.kicker')}</span><h2>{title}</h2><p>{subtitle}</p></div></div>
      {total <= 0 ? <div className="tlg-finance-v2-donut-empty"><div className="empty-ring" /><span>{t('financePage.breakdown.noData')}</span></div> : (
        <div className="tlg-finance-v2-donut-content">
          <div className="tlg-finance-v2-donut" style={{ background: donutBackground(visible) }}><div><strong>{money(total, currency)}</strong><span>{t('financePage.breakdown.total')}</span></div></div>
          <div className="tlg-finance-v2-donut-legend">
            {visible.map((item, index) => <div key={item.category}><i style={{ background: DONUT_COLORS[index % DONUT_COLORS.length] }} /><span>{categoryName(item.category, t)}</span><strong>{money(item.amount, currency)}</strong></div>)}
          </div>
        </div>
      )}
    </section>
  )
}

function CompactTransactions({ t, money: _money, signedMoney, transactions }: { t: TFunction; money: (value: number, currency?: string) => string; signedMoney: (value: number, currency?: string) => string; transactions: FinanceTransaction[] }) {
  if (transactions.length === 0) return <EmptyState text={t('financePage.ledger.noTransactions')} />
  return <div className="tlg-finance-v2-compact-transactions">{transactions.map((tx) => <div key={tx.id}><div><strong>{tx.description}</strong><span>{financeDate(tx.season, tx.month, tx.day, t)} · {categoryName(tx.category, t)}</span></div><b className={tx.amount >= 0 ? 'positive' : 'negative'}>{signedMoney(tx.amount, 'USD')}</b></div>)}</div>
}

function TransactionTable({ t, money, signedMoney, transactions }: { t: TFunction; money: (value: number, currency?: string) => string; signedMoney: (value: number, currency?: string) => string; transactions: FinanceTransaction[] }) {
  if (transactions.length === 0) return <EmptyState text={t('financePage.ledger.noPage')} />
  return (
    <div className="tlg-finance-v2-table-wrap">
      <table className="tlg-finance-v2-ledger-table">
        <thead><tr><th>{t('financePage.ledger.columns.date')}</th><th>{t('financePage.ledger.columns.reason')}</th><th>{t('financePage.ledger.columns.category')}</th><th>{t('financePage.ledger.columns.source')}</th><th className="amount">{t('financePage.ledger.columns.amount')}</th><th className="amount">{t('financePage.ledger.columns.balance')}</th></tr></thead>
        <tbody>{transactions.map((tx) => <tr key={tx.id}><td>{financeDate(tx.season, tx.month, tx.day, t)}</td><td><strong>{tx.description}</strong><small>{label(tx.subcategory)}{tx.is_taxable ? ` · ${t('financePage.ledger.taxableIncome')}` : ''}</small></td><td>{categoryName(tx.category, t)}</td><td>{tx.source_type ? label(tx.source_type) : t('financePage.ledger.system')}</td><td className={`amount ${tx.amount >= 0 ? 'positive' : 'negative'}`}>{signedMoney(tx.amount, 'USD')}</td><td className="amount">{money(tx.balance_after, 'USD')}</td></tr>)}</tbody>
      </table>
    </div>
  )
}

function TaxHistoryTable({ t, money, history }: { t: TFunction; money: (value: number, currency?: string) => string; history: TaxPeriod[] }) {
  if (history.length === 0) return <EmptyState text={t('financePage.tax.noHistory')} />
  return (
    <div className="tlg-finance-v2-table-wrap">
      <table className="tlg-finance-v2-ledger-table">
        <thead><tr><th>{t('financePage.tax.columns.period')}</th><th>{t('financePage.tax.columns.income')}</th><th>{t('financePage.tax.columns.rate')}</th><th>{t('financePage.tax.columns.paid')}</th><th>{t('financePage.tax.columns.settlement')}</th></tr></thead>
        <tbody>{history.map((row) => <tr key={`${row.season}-${row.month}`}><td>{financeDate(row.season, row.month, 1, t).replace(/\s1\s·/, ' ·')}</td><td>{money(row.taxable_income, 'USD')}</td><td>{Math.round(Number(row.tax_rate) * 100)}%</td><td className="negative">−{money(row.tax_amount, 'USD')}</td><td>{absoluteGameDate(row.settled_absolute_day, t)}</td></tr>)}</tbody>
      </table>
    </div>
  )
}

function EmptyState({ text }: { text: string }) {
  return <div className="tlg-finance-v2-empty">{text}</div>
}
