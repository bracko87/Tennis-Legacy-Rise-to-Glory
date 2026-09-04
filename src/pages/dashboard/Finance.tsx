import { useEffect, useMemo, useState } from 'react'

import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/finance.css'

type FinanceTab = 'overview' | 'transactions' | 'stats' | 'sponsors'

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
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function money(value: number, currency = 'USD') {
  const amount = Math.abs(Math.round(value))
  return `${value < 0 ? '−' : ''}${currency === 'USD' ? '$' : `${currency} `}${amount.toLocaleString()}`
}

function signedMoney(value: number, currency = 'USD') {
  const amount = Math.abs(Math.round(value))
  const prefix = value > 0 ? '+' : value < 0 ? '−' : ''
  return `${prefix}${currency === 'USD' ? '$' : `${currency} `}${amount.toLocaleString()}`
}

function gameDate(season: number, month: number, day: number) {
  return `${MONTHS[Math.max(0, month - 1)] ?? `M${month}`} ${day} · S${season}`
}

function label(value: string) {
  return value.replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

export default function FinancePage() {
  const [activeTab, setActiveTab] = useState<FinanceTab>('overview')
  const [dashboard, setDashboard] = useState<FinanceDashboard | null>(null)
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function loadFinance(background = false) {
    if (background) setRefreshing(true)
    else setLoading(true)
    setError(null)
    const { data, error: financeError } = await supabase.rpc('get_career_finance_dashboard_v1', { p_limit: 100 })
    if (financeError || !data) {
      setError(financeError?.message ?? 'Unable to load career finances.')
    } else {
      setDashboard(data as FinanceDashboard)
    }
    setLoading(false)
    setRefreshing(false)
  }

  useEffect(() => {
    void loadFinance()
  }, [])

  const latest = dashboard?.recent_transactions?.slice(0, 6) ?? []
  const categories = useMemo(
    () => [...(dashboard?.category_totals ?? [])].sort((a, b) => (b.income + b.expenses) - (a.income + a.expenses)),
    [dashboard?.category_totals],
  )

  return (
    <GameLayout title="Finance" subtitle="Career balance, expenses and transaction history">
      <div className="tlg-finance-page">
        <section className="tlg-finance-hero">
          <div>
            <span className="tlg-finance-kicker">Career economy</span>
            <h2>Your career money</h2>
            <p>Career dollars are completely separate from Premium coins. Staff, travel, hotels, training and future prize money all flow through this account.</p>
          </div>
          <button type="button" className="tlg-finance-refresh" onClick={() => void loadFinance(true)} disabled={refreshing || loading}>
            {refreshing ? 'Refreshing…' : 'Refresh'}
          </button>
        </section>

        {loading ? (
          <div className="tlg-finance-state">Loading career finances…</div>
        ) : error ? (
          <div className="tlg-finance-state error">{error}</div>
        ) : dashboard ? (
          <>
            <section className="tlg-finance-summary-grid">
              <div className={`tlg-finance-balance-card${dashboard.balance < 0 ? ' negative' : ''}`}>
                <span>Career Balance</span>
                <strong>{money(dashboard.balance, dashboard.currency)}</strong>
                <small>{dashboard.balance < 0 ? 'Career account is currently in deficit.' : 'Available for career expenses.'}</small>
              </div>
              <FinanceMetric label="Season Income" value={money(dashboard.season_income, dashboard.currency)} tone="positive" />
              <FinanceMetric label="Season Expenses" value={money(dashboard.season_expenses, dashboard.currency)} tone="negative" />
              <FinanceMetric label="Season Net" value={signedMoney(dashboard.season_net, dashboard.currency)} tone={dashboard.season_net >= 0 ? 'positive' : 'negative'} />
            </section>

            <nav className="tlg-finance-tabs" aria-label="Finance sections">
              {(['overview', 'transactions', 'stats', 'sponsors'] as FinanceTab[]).map((tab) => (
                <button key={tab} type="button" className={activeTab === tab ? 'active' : ''} onClick={() => setActiveTab(tab)}>
                  {label(tab)}
                </button>
              ))}
            </nav>

            {activeTab === 'overview' && (
              <div className="tlg-finance-overview-grid">
                <section className="tlg-finance-panel">
                  <div className="tlg-finance-panel-head">
                    <div><span>Next costs</span><h3>Upcoming commitments</h3></div>
                    <small>Next 60 game days</small>
                  </div>
                  {dashboard.upcoming_commitments.length === 0 ? (
                    <div className="tlg-finance-empty">No scheduled financial commitments.</div>
                  ) : (
                    <div className="tlg-finance-commitments">
                      {dashboard.upcoming_commitments.slice(0, 8).map((item, index) => (
                        <div className="tlg-finance-commitment" key={`${item.kind}-${item.due_absolute_day}-${index}`}>
                          <div><strong>{item.description}</strong><span>{label(item.kind)} · Game day {item.due_absolute_day}</span></div>
                          <b>−{money(item.amount, dashboard.currency)}</b>
                        </div>
                      ))}
                    </div>
                  )}
                </section>

                <section className="tlg-finance-panel">
                  <div className="tlg-finance-panel-head"><div><span>Account activity</span><h3>Latest transactions</h3></div><button type="button" onClick={() => setActiveTab('transactions')}>View all</button></div>
                  <TransactionList transactions={latest} currency={dashboard.currency} compact />
                </section>

                <section className="tlg-finance-panel tlg-finance-panel-wide">
                  <div className="tlg-finance-panel-head"><div><span>How it works</span><h3>One career ledger</h3></div></div>
                  <div className="tlg-finance-rules">
                    <div><strong>Optional purchases</strong><p>Hiring staff and booking Training Camps require enough available money at the moment you confirm them.</p></div>
                    <div><strong>Mandatory career costs</strong><p>Travel, hotel nights and recurring staff obligations are posted when they actually occur, so the account can temporarily go below zero rather than blocking the career.</p></div>
                    <div><strong>Every movement is permanent</strong><p>Each charge has a unique ledger key, so the daily engine cannot accidentally charge the same flight, hotel night or salary twice.</p></div>
                  </div>
                </section>
              </div>
            )}

            {activeTab === 'transactions' && (
              <section className="tlg-finance-panel tlg-finance-transactions-panel">
                <div className="tlg-finance-panel-head"><div><span>Permanent history</span><h3>Career transaction ledger</h3></div><small>{dashboard.recent_transactions.length} most recent</small></div>
                <TransactionList transactions={dashboard.recent_transactions} currency={dashboard.currency} />
              </section>
            )}

            {activeTab === 'stats' && (
              <section className="tlg-finance-panel">
                <div className="tlg-finance-panel-head"><div><span>Season {dashboard.season}</span><h3>Income and expenses by category</h3></div></div>
                {categories.length === 0 ? <div className="tlg-finance-empty">No financial activity yet.</div> : (
                  <div className="tlg-finance-category-list">
                    {categories.map((item) => (
                      <div className="tlg-finance-category-row" key={item.category}>
                        <strong>{label(item.category)}</strong>
                        <div><span>Income</span><b className="positive">{money(item.income, dashboard.currency)}</b></div>
                        <div><span>Expenses</span><b className="negative">{money(item.expenses, dashboard.currency)}</b></div>
                        <div><span>Net</span><b className={item.net >= 0 ? 'positive' : 'negative'}>{signedMoney(item.net, dashboard.currency)}</b></div>
                      </div>
                    ))}
                  </div>
                )}
              </section>
            )}

            {activeTab === 'sponsors' && (
              <section className="tlg-finance-panel tlg-finance-sponsors">
                <span>Sponsorships</span>
                <h3>Commercial contracts are the next income layer</h3>
                <p>The central Finance Engine is now live first. Sponsor offers, weekly payments and performance bonuses can be added on top of the same ledger without creating another money system.</p>
              </section>
            )}
          </>
        ) : null}
      </div>
    </GameLayout>
  )
}

function FinanceMetric({ label: metricLabel, value, tone }: { label: string; value: string; tone?: 'positive' | 'negative' }) {
  return <div className="tlg-finance-metric"><span>{metricLabel}</span><strong className={tone ?? ''}>{value}</strong></div>
}

function TransactionList({ transactions, currency, compact = false }: { transactions: FinanceTransaction[]; currency: string; compact?: boolean }) {
  if (transactions.length === 0) return <div className="tlg-finance-empty">No transactions yet.</div>
  return (
    <div className={`tlg-finance-transactions${compact ? ' compact' : ''}`}>
      {transactions.map((transaction) => (
        <div className="tlg-finance-transaction" key={transaction.id}>
          <div className="tlg-finance-transaction-main">
            <strong>{transaction.description}</strong>
            <span>{gameDate(transaction.season, transaction.month, transaction.day)} · {label(transaction.category)} / {label(transaction.subcategory)}</span>
          </div>
          <div className="tlg-finance-transaction-money">
            <b className={transaction.amount >= 0 ? 'positive' : 'negative'}>{signedMoney(transaction.amount, currency)}</b>
            {!compact && <small>Balance {money(transaction.balance_after, currency)}</small>}
          </div>
        </div>
      ))}
    </div>
  )
}
