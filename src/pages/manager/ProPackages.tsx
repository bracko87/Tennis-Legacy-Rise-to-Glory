import {
  Check,
  Coins,
  Crown,
  History,
  Info,
  ReceiptText,
  RefreshCw,
  Sparkles,
  WalletCards,
} from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'

import GameLayout from '../../components/layout/GameLayout'
import { useAuth } from '../../auth/AuthContext'
import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'

interface BillingTransaction {
  id: string
  kind: 'premium_invoice' | 'coin_pack_purchase' | 'refund'
  status: 'pending' | 'paid' | 'failed' | 'refunded' | 'canceled'
  amount_eur_cents: number
  coins_amount: number
  description: string | null
  created_at: string
}

interface CoinLedgerEntry {
  id: string
  amount: number
  balance_after: number
  entry_type: string
  description: string | null
  created_at: string
}

interface CoinPack {
  coins: number
  price: number
  helper: string
  badge?: string
}

const coinPacks: readonly CoinPack[] = [
  { coins: 70, price: 3.99, helper: 'Starter boost' },
  { coins: 130, price: 6.99, helper: 'Great for a new season' },
  { coins: 270, price: 13.99, helper: 'Most balanced pick' },
  { coins: 390, price: 19.99, helper: 'Most popular', badge: 'Most popular' },
  { coins: 570, price: 28.99, helper: 'Serious manager mode' },
  { coins: 900, price: 44.99, helper: 'Best for long-term play', badge: 'Best value' },
]

const comparisonRows = [
  ['Create and manage your professional player', true, true],
  ['Play ATP or WTA singles tournaments', true, true],
  ['Core training, equipment and finance systems', true, true],
  ['Account access without coins', true, true],
  ['Premium analysis and advanced tools', false, true],
  ['Monthly Premium coin reward', '—', '50'],
  ['Buy additional coin packages', true, true],
  ['Use optional coin features', true, true],
] as const

function formatMoney(cents: number) {
  return `€${(cents / 100).toFixed(2)}`
}

function formatDate(value: string | null | undefined) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return new Intl.DateTimeFormat('en', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  }).format(date)
}

export default function ProPackagesPage() {
  const { user } = useAuth()
  const commerce = useCommerce()
  const [billing, setBilling] = useState<BillingTransaction[]>([])
  const [ledger, setLedger] = useState<CoinLedgerEntry[]>([])
  const [historyOpen, setHistoryOpen] = useState<Record<string, boolean>>({})
  const [historyLoading, setHistoryLoading] = useState(true)
  const [checkoutNotice, setCheckoutNotice] = useState<string | null>(null)

  const premiumInvoices = useMemo(
    () => billing.filter((entry) => entry.kind === 'premium_invoice'),
    [billing],
  )
  const coinPurchases = useMemo(
    () => billing.filter((entry) => entry.kind === 'coin_pack_purchase'),
    [billing],
  )

  useEffect(() => {
    if (!user) return
    const userId = user.id
    let active = true

    async function loadHistory() {
      setHistoryLoading(true)
      const [billingResult, ledgerResult] = await Promise.all([
        supabase
          .from('billing_transactions')
          .select('id, kind, status, amount_eur_cents, coins_amount, description, created_at')
          .eq('user_id', userId)
          .order('created_at', { ascending: false })
          .limit(100),
        supabase
          .from('coin_ledger')
          .select('id, amount, balance_after, entry_type, description, created_at')
          .eq('user_id', userId)
          .order('created_at', { ascending: false })
          .limit(100),
      ])

      if (!active) return
      setBilling((billingResult.data ?? []) as BillingTransaction[])
      setLedger((ledgerResult.data ?? []) as CoinLedgerEntry[])
      setHistoryLoading(false)
    }

    void loadHistory()
    return () => { active = false }
  }, [user])

  function showStripeNotice(message: string) {
    setCheckoutNotice(message)
    window.setTimeout(() => setCheckoutNotice(null), 4200)
  }

  const membership = commerce.membership
  const planName = commerce.isPremium ? 'Tennis Legacy Premium' : 'Tennis Legacy Free'
  const monthlyPrice = commerce.isPremium ? 499 : 0
  const monthlyCoins = commerce.isPremium ? 50 : 0

  return (
    <GameLayout title="Pro Packages" subtitle="Premium membership, coins and billing">
      <div className="tlg-commerce-page">
        <section className="tlg-commerce-heading">
          <div>
            <span>Optional services</span>
            <h1>Premium & Billing</h1>
            <p>Normal gameplay is free. Premium membership and coin packages are optional.</p>
          </div>
          <button type="button" className="tlg-commerce-refresh" onClick={() => void commerce.refresh()}>
            <RefreshCw size={15} />
            Refresh
          </button>
        </section>

        {checkoutNotice && (
          <div className="tlg-commerce-notice" role="status">
            <Info size={17} />
            <span>{checkoutNotice}</span>
          </div>
        )}

        <section className="tlg-commerce-premium-card">
          <div className="tlg-commerce-premium-main">
            <div className="tlg-commerce-badges">
              <span className="tlg-commerce-badge-premium">PREMIUM</span>
              <span className={commerce.isPremium ? 'tlg-commerce-badge-active' : 'tlg-commerce-badge-free'}>
                {commerce.isPremium ? 'Active' : 'Optional'}
              </span>
            </div>
            <h2>Tennis Legacy Premium</h2>
            <div className="tlg-commerce-price"><strong>€4.99</strong><span>per real-life month</span></div>
            <ul className="tlg-commerce-benefits">
              <li><Check size={15} /> Advanced player analysis and deeper management tools.</li>
              <li><Check size={15} /> Additional scouting, preparation and career-planning insights as those systems launch.</li>
              <li><Check size={15} /> Premium convenience features without removing core gameplay from Free players.</li>
              <li><Check size={15} /> Receive 50 coins after every successful monthly Premium payment.</li>
              <li><Check size={15} /> Cancel at any time; normal gameplay remains free.</li>
            </ul>
            <div className="tlg-commerce-free-rule">
              <strong>{commerce.isPremium ? 'Premium is active.' : 'Free gameplay remains fully available.'}</strong>
              <span>{commerce.isPremium ? `Current period ends ${formatDate(membership?.current_period_end)}.` : 'Premium adds optional tools and rewards; it is not required to play Tennis Legacy.'}</span>
            </div>
          </div>

          <aside className="tlg-commerce-premium-side">
            <Crown size={25} />
            <span>Premium membership</span>
            <strong>€4.99</strong>
            <small>per real-life month</small>
            <button
              type="button"
              onClick={() => showStripeNotice(
                commerce.isPremium
                  ? 'Stripe subscription management will be connected in the billing integration step.'
                  : 'Stripe checkout will be connected in the billing integration step. No payment has been made.',
              )}
            >
              {commerce.isPremium ? 'Manage subscription' : 'Get Premium'}
            </button>
            <p>Stripe checkout, invoices and subscription management will be connected later.</p>
          </aside>
        </section>

        <section className="tlg-commerce-section">
          <div className="tlg-commerce-section-title">
            <h2>Free vs Premium</h2>
            <p>Premium adds optional analysis and tools without removing core access from Free players.</p>
          </div>
          <div className="tlg-commerce-table-wrap">
            <table className="tlg-commerce-table">
              <thead><tr><th>Benefit</th><th>Free</th><th>Premium</th></tr></thead>
              <tbody>
                {comparisonRows.map(([label, free, premium]) => (
                  <tr key={label}>
                    <td>{label}</td>
                    <td>{free === true ? <Check size={16} /> : free}</td>
                    <td>{premium === true ? <Check size={16} /> : <strong>{premium}</strong>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="tlg-commerce-section">
          <div className="tlg-commerce-section-title">
            <h2>Need additional coins?</h2>
            <p>Free and Premium players can purchase coins for optional features. Buying coins does not activate Premium membership.</p>
          </div>
          <div className="tlg-commerce-pack-grid">
            {coinPacks.map((pack) => (
              <article key={pack.coins} className={`tlg-commerce-pack ${pack.badge === 'Best value' ? 'tlg-commerce-pack-best' : ''}`}>
                {pack.badge && <span className="tlg-commerce-pack-badge">{pack.badge}</span>}
                <span>Coin Pack</span>
                <h3><Coins size={28} /> {pack.coins}</h3>
                <p>{pack.helper}</p>
                <strong>€{pack.price.toFixed(2)}</strong>
                <small>≈ €{(pack.price / pack.coins).toFixed(2)} per coin</small>
                <button
                  type="button"
                  onClick={() => showStripeNotice(`The ${pack.coins}-coin pack will use secure Stripe checkout. No purchase has been made.`)}
                >
                  Buy now
                </button>
                <p className="tlg-commerce-pack-footnote">One-time coin purchase. This does not start a Premium subscription.</p>
              </article>
            ))}
          </div>
        </section>

        <section className="tlg-commerce-section">
          <div className="tlg-commerce-section-title">
            <h2>Current membership</h2>
            <p>Your current plan, billing period and renewal status.</p>
          </div>
          <div className="tlg-commerce-membership-card">
            <MembershipStat label="Plan" value={planName} />
            <MembershipStat label="Status" value={membership?.status === 'active' ? 'Active' : membership?.status ?? 'Active'} />
            <MembershipStat label="Started" value={formatDate(membership?.started_at)} />
            <MembershipStat label="Current period ends" value={formatDate(membership?.current_period_end)} />
            <MembershipStat label="Next renewal" value={commerce.isPremium && !membership?.cancel_at_period_end ? formatDate(membership?.current_period_end) : '—'} />
            <MembershipStat label="Monthly price" value={formatMoney(monthlyPrice)} />
            <MembershipStat label="Monthly coin reward" value={`${monthlyCoins} coins`} />
            <MembershipStat label="Cancel at period end" value={membership?.cancel_at_period_end ? 'Yes' : 'No'} />
          </div>
        </section>

        <section className="tlg-commerce-section">
          <div className="tlg-commerce-section-title">
            <h2>Billing and purchase history</h2>
            <p>Premium invoices, coin-package purchases and wallet activity are kept separate.</p>
          </div>

          <HistoryBlock
            icon={<ReceiptText size={19} />}
            title="Premium invoices"
            subtitle="Successful Premium payments and monthly coin grants"
            open={!!historyOpen.premium}
            onToggle={() => setHistoryOpen((current) => ({ ...current, premium: !current.premium }))}
          >
            <BillingRows rows={premiumInvoices} loading={historyLoading} empty="No Premium invoices yet." />
          </HistoryBlock>

          <HistoryBlock
            icon={<WalletCards size={19} />}
            title="Coin-package purchases"
            subtitle="One-time purchases of optional coin packages"
            open={!!historyOpen.packs}
            onToggle={() => setHistoryOpen((current) => ({ ...current, packs: !current.packs }))}
          >
            <BillingRows rows={coinPurchases} loading={historyLoading} empty="No coin-package purchases yet." />
          </HistoryBlock>

          <HistoryBlock
            icon={<History size={19} />}
            title="Coin ledger / history"
            subtitle="All coin grants, purchases, rewards and optional-feature spending"
            open={!!historyOpen.ledger}
            onToggle={() => setHistoryOpen((current) => ({ ...current, ledger: !current.ledger }))}
          >
            {historyLoading ? <div className="tlg-commerce-history-empty">Loading history…</div> : ledger.length === 0 ? (
              <div className="tlg-commerce-history-empty">No coin transactions yet. Current balance: {commerce.coins} coins.</div>
            ) : (
              <div className="tlg-commerce-history-list">
                {ledger.map((entry) => (
                  <div key={entry.id} className="tlg-commerce-history-row">
                    <span>{entry.description ?? entry.entry_type.replaceAll('_', ' ')}</span>
                    <span>{formatDate(entry.created_at)}</span>
                    <strong className={entry.amount > 0 ? 'tlg-commerce-positive' : ''}>{entry.amount > 0 ? '+' : ''}{entry.amount}</strong>
                    <strong>{entry.balance_after} coins</strong>
                  </div>
                ))}
              </div>
            )}
          </HistoryBlock>
        </section>
      </div>
    </GameLayout>
  )
}

function MembershipStat({ label, value }: { label: string; value: string }) {
  return <div className="tlg-commerce-membership-stat"><span>{label}</span><strong>{value}</strong></div>
}

function HistoryBlock({
  icon,
  title,
  subtitle,
  open,
  onToggle,
  children,
}: {
  icon: JSX.Element
  title: string
  subtitle: string
  open: boolean
  onToggle: () => void
  children: JSX.Element
}) {
  return (
    <article className="tlg-commerce-history-card">
      <div className="tlg-commerce-history-summary">
        <div className="tlg-commerce-history-icon">{icon}</div>
        <div><strong>{title}</strong><span>{subtitle}</span></div>
        <button type="button" onClick={onToggle}>{open ? 'Hide history' : 'Show history'}</button>
      </div>
      {open && <div className="tlg-commerce-history-detail">{children}</div>}
    </article>
  )
}

function BillingRows({ rows, loading, empty }: { rows: BillingTransaction[]; loading: boolean; empty: string }) {
  if (loading) return <div className="tlg-commerce-history-empty">Loading history…</div>
  if (!rows.length) return <div className="tlg-commerce-history-empty">{empty}</div>

  return (
    <div className="tlg-commerce-history-list">
      {rows.map((entry) => (
        <div key={entry.id} className="tlg-commerce-history-row">
          <span>{entry.description ?? entry.kind.replaceAll('_', ' ')}</span>
          <span>{formatDate(entry.created_at)}</span>
          <strong>{entry.coins_amount ? `${entry.coins_amount} coins` : '—'}</strong>
          <strong>{formatMoney(entry.amount_eur_cents)}</strong>
        </div>
      ))}
    </div>
  )
}
