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

interface CommerceCatalogItem {
  code: string
  kind: 'premium' | 'coin_pack'
  label: string
  coins: number
  price_eur_cents: number
  stripe_payment_link_url: string
  sort_order: number
}

interface CommerceSettings {
  stripe_customer_portal_url: string | null
  premium_monthly_price_eur_cents: number
  premium_monthly_coin_reward: number
}

interface CoinPack {
  code: string
  coins: number
  price: number
  paymentLinkUrl: string
  helper: string
  badge?: string
}

interface PremiumOffer {
  code: 'premium_monthly' | 'premium_quarterly' | 'premium_yearly'
  label: string
  months: number
  fallbackPriceCents: number
  fallbackCoins: number
  badge?: string
}

const fallbackCoinPacks: readonly CoinPack[] = [
  { code: 'coin_70', coins: 70, price: 2.99, paymentLinkUrl: '', helper: 'Starter boost' },
  { code: 'coin_130', coins: 130, price: 4.99, paymentLinkUrl: '', helper: 'Great for a new season' },
  { code: 'coin_270', coins: 270, price: 9.99, paymentLinkUrl: '', helper: 'Most balanced pick' },
  { code: 'coin_390', coins: 390, price: 13.99, paymentLinkUrl: '', helper: 'Most popular', badge: 'Most popular' },
  { code: 'coin_570', coins: 570, price: 19.99, paymentLinkUrl: '', helper: 'Serious manager mode' },
  { code: 'coin_900', coins: 900, price: 29.99, paymentLinkUrl: '', helper: 'Best for long-term play', badge: 'Best value' },
]

const premiumOffers: readonly PremiumOffer[] = [
  { code: 'premium_quarterly', label: '3 Months', months: 3, fallbackPriceCents: 949, fallbackCoins: 90, badge: 'Most popular' },
  { code: 'premium_monthly', label: 'Monthly', months: 1, fallbackPriceCents: 329, fallbackCoins: 30 },
  { code: 'premium_yearly', label: '12 Months', months: 12, fallbackPriceCents: 3349, fallbackCoins: 360, badge: 'Save 15%' },
] as const

const comparisonRows = [
  ['Create and manage your professional player', true, true],
  ['Play ATP or WTA singles tournaments', true, true],
  ['Core training, equipment and finance systems', true, true],
  ['Account access without coins', true, true],
  ['Premium analysis and advanced tools', false, true],
  ['Premium coin reward', '—', '30 coins per covered month'],
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
  const [catalog, setCatalog] = useState<CommerceCatalogItem[]>([])
  const [commerceSettings, setCommerceSettings] = useState<CommerceSettings | null>(null)

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
      const [billingResult, ledgerResult, catalogResult, settingsResult] = await Promise.all([
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
        supabase.rpc('get_commerce_catalog_v1'),
        supabase
          .from('commerce_runtime_settings')
          .select('stripe_customer_portal_url, premium_monthly_price_eur_cents, premium_monthly_coin_reward')
          .eq('id', true)
          .maybeSingle(),
      ])

      if (!active) return
      setBilling((billingResult.data ?? []) as BillingTransaction[])
      setLedger((ledgerResult.data ?? []) as CoinLedgerEntry[])
      setCatalog((catalogResult.data ?? []) as CommerceCatalogItem[])
      setCommerceSettings((settingsResult.data ?? null) as CommerceSettings | null)
      setHistoryLoading(false)
    }

    void loadHistory()
    return () => { active = false }
  }, [user])

  function showStripeNotice(message: string) {
    setCheckoutNotice(message)
    window.setTimeout(() => setCheckoutNotice(null), 4200)
  }

  async function openStripeCheckout(catalogCode: string) {
    if (!user) {
      showStripeNotice('Please sign in again before starting checkout.')
      return
    }

    const { data, error: intentError } = await supabase.rpc('create_commerce_checkout_intent_v1', {
      p_catalog_code: catalogCode,
    })

    if (intentError || !data) {
      showStripeNotice(intentError?.message ?? 'Secure checkout is temporarily unavailable. Please try again.')
      return
    }

    const checkout = data as {
      status?: string
      intent_id?: string
      payment_link_url?: string
      prefilled_email?: string | null
      portal_url?: string | null
    }

    if (checkout.status === 'already_premium' && checkout.portal_url) {
      window.location.assign(checkout.portal_url)
      return
    }

    if (checkout.status !== 'ready' || !checkout.intent_id || !checkout.payment_link_url) {
      showStripeNotice('Secure checkout is temporarily unavailable. Please refresh and try again.')
      return
    }

    const url = new URL(checkout.payment_link_url)
    url.searchParams.set('client_reference_id', checkout.intent_id)
    if (checkout.prefilled_email) url.searchParams.set('prefilled_email', checkout.prefilled_email)
    window.location.assign(url.toString())
  }

  const membership = commerce.membership
  const planName = commerce.isPremium ? 'Tennis Legacy Premium' : 'Tennis Legacy Free'
  const resolvedPremiumOffers = premiumOffers.map((offer) => {
    const item = catalog.find((candidate) => candidate.code === offer.code)
    const priceCents = item?.price_eur_cents ?? offer.fallbackPriceCents
    const coins = item?.coins ?? offer.fallbackCoins
    return { ...offer, priceCents, coins, monthlyEquivalentCents: Math.round(priceCents / offer.months) }
  })
  const mainPremiumOffer = resolvedPremiumOffers.find((offer) => offer.code === 'premium_quarterly')!
  const activeBillingMonths = membership?.billing_period_months ?? 1
  const activeBillingAmount = membership?.billing_amount_eur_cents ?? (commerce.isPremium ? membership?.monthly_price_eur_cents ?? 329 : 0)
  const activeMonthlyEquivalent = commerce.isPremium ? membership?.monthly_price_eur_cents ?? 329 : 0
  const activeCoinsPerPayment = membership?.coins_per_payment ?? (commerce.isPremium ? membership?.monthly_coin_reward ?? 30 : 0)
  const coinPacks: readonly CoinPack[] = fallbackCoinPacks.map((fallback) => {
    const item = catalog.find((candidate) => candidate.code === fallback.code)
    return item ? {
      ...fallback,
      price: item.price_eur_cents / 100,
      paymentLinkUrl: item.stripe_payment_link_url,
    } : fallback
  })

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
            <div className="tlg-commerce-price"><strong>{formatMoney(mainPremiumOffer.priceCents)}</strong><span>every 3 real-life months · {formatMoney(mainPremiumOffer.monthlyEquivalentCents)}/month</span></div>
            <ul className="tlg-commerce-benefits">
              <li><Check size={15} /> Advanced player analysis and deeper management tools.</li>
              <li><Check size={15} /> Additional scouting, preparation and career-planning insights as those systems launch.</li>
              <li><Check size={15} /> Premium convenience features without removing core gameplay from Free players.</li>
              <li><Check size={15} /> Receive 30 coins per covered month: 30 monthly, 90 every 3 months, or 360 yearly.</li>
              <li><Check size={15} /> Choose monthly, 3-month or annual billing; normal gameplay remains free.</li>
            </ul>
            <div className="tlg-commerce-free-rule">
              <strong>{commerce.isPremium ? 'Premium is active.' : 'Free gameplay remains fully available.'}</strong>
              <span>{commerce.isPremium ? `Current period ends ${formatDate(membership?.current_period_end)}.` : 'Premium adds optional tools and rewards; it is not required to play Tennis Legacy.'}</span>
            </div>
          </div>

          <aside className="tlg-commerce-premium-side">
            <Crown size={25} />
            <span>Premium membership</span>
            <div className="tlg-commerce-premium-featured">
              <span className="tlg-commerce-plan-badge">Most popular</span>
              <strong>{formatMoney(mainPremiumOffer.priceCents)}</strong>
              <small>every 3 months · {formatMoney(mainPremiumOffer.monthlyEquivalentCents)}/month</small>
              <button
                type="button"
                onClick={() => {
                  if (commerce.isPremium) {
                    const portalUrl = commerceSettings?.stripe_customer_portal_url
                    if (portalUrl) window.location.assign(portalUrl)
                    else showStripeNotice('Subscription management is temporarily unavailable.')
                  } else {
                    void openStripeCheckout('premium_quarterly')
                  }
                }}
              >
                {commerce.isPremium ? 'Manage subscription' : 'Choose 3 months'}
              </button>
            </div>

            <div className="tlg-commerce-premium-alternatives">
              {resolvedPremiumOffers.filter((offer) => offer.code !== 'premium_quarterly').map((offer) => (
                <div key={offer.code} className="tlg-commerce-premium-option">
                  <div>
                    <span>{offer.label}</span>
                    {offer.badge && <small className="tlg-commerce-plan-saving">{offer.badge}</small>}
                  </div>
                  <strong>{formatMoney(offer.priceCents)}</strong>
                  <small>{offer.months === 1 ? 'per month' : `per year · ${formatMoney(offer.monthlyEquivalentCents)}/month`}</small>
                  <button
                    type="button"
                    onClick={() => {
                      if (commerce.isPremium) {
                        const portalUrl = commerceSettings?.stripe_customer_portal_url
                        if (portalUrl) window.location.assign(portalUrl)
                        else showStripeNotice('Subscription management is temporarily unavailable.')
                      } else {
                        void openStripeCheckout(offer.code)
                      }
                    }}
                  >
                    {commerce.isPremium ? 'Manage' : offer.months === 1 ? 'Choose monthly' : 'Choose annual'}
                  </button>
                </div>
              ))}
            </div>
            <p>Secure checkout and recurring billing are provided by Stripe. Existing subscribers keep their current plan unless they change it.</p>
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
              <article key={pack.code} className={`tlg-commerce-pack ${pack.badge === 'Best value' ? 'tlg-commerce-pack-best' : ''}`}>
                {pack.badge && <span className="tlg-commerce-pack-badge">{pack.badge}</span>}
                <span>Coin Pack</span>
                <h3><Coins size={28} /> {pack.coins}</h3>
                <p>{pack.helper}</p>
                <strong>€{pack.price.toFixed(2)}</strong>
                <small>≈ €{(pack.price / pack.coins).toFixed(2)} per coin</small>
                <button
                  type="button"
                  onClick={() => void openStripeCheckout(pack.code)}
                >
                  Buy now
                </button>
                <p className="tlg-commerce-pack-footnote">One-time coin purchase. This does not start a Premium subscription.</p>
              </article>
            ))}
          </div>
        </section>

        <section className="tlg-commerce-section tlg-cpx-earn-section" aria-label="Earn Free Coins from surveys">
          <div>
            <h2>Earn Free Coins</h2>
            <p>Prefer to earn Coins instead of buying a package? Complete optional surveys with
              CPX Research. Every $1 of verified publisher rewards earns 15 Tennis Legacy Coins.
              Surveys may not always be available.</p>
          </div>
          <button type="button" className="tlg-cpx-launch"
            onClick={() => window.dispatchEvent(new Event('tlg:open-earn-coins'))}>
            <Coins size={18} /> Browse Surveys
          </button>
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
            <MembershipStat label="Billing plan" value={commerce.isPremium ? activeBillingMonths === 12 ? '12 months' : activeBillingMonths === 3 ? '3 months' : 'Monthly' : 'Free'} />
            <MembershipStat label="Price per billing period" value={formatMoney(activeBillingAmount)} />
            <MembershipStat label="Monthly equivalent" value={formatMoney(activeMonthlyEquivalent)} />
            <MembershipStat label="Coin reward per payment" value={`${activeCoinsPerPayment} coins`} />
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
