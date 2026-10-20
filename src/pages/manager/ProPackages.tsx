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
import { useTranslation } from 'react-i18next'

import GameLayout from '../../components/layout/GameLayout'
import { useAuth } from '../../auth/AuthContext'
import { useCommerce } from '../../hooks/useCommerce'
import { trainingEffectivenessLabels } from '../../lib/trainingEffectivenessI18n'
import { useLocalization } from '../../i18n/LocalizationProvider'
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
  helperKey: string
  badgeKey?: string
}

interface PremiumOffer {
  code: 'premium_monthly' | 'premium_quarterly' | 'premium_yearly'
  labelKey: string
  months: number
  fallbackPriceCents: number
  fallbackCoins: number
  badgeKey?: string
}

const fallbackCoinPacks: readonly CoinPack[] = [
  { code: 'coin_70', coins: 70, price: 2.99, paymentLinkUrl: '', helperKey: 'commercePage.packStarter' },
  { code: 'coin_130', coins: 130, price: 4.99, paymentLinkUrl: '', helperKey: 'commercePage.packSeason' },
  { code: 'coin_270', coins: 270, price: 9.99, paymentLinkUrl: '', helperKey: 'commercePage.packBalanced' },
  { code: 'coin_390', coins: 390, price: 13.99, paymentLinkUrl: '', helperKey: 'commercePage.packPopular', badgeKey: 'commercePage.mostPopular' },
  { code: 'coin_570', coins: 570, price: 19.99, paymentLinkUrl: '', helperKey: 'commercePage.packSerious' },
  { code: 'coin_900', coins: 900, price: 29.99, paymentLinkUrl: '', helperKey: 'commercePage.packLongTerm', badgeKey: 'commercePage.bestValue' },
]

const premiumOffers: readonly PremiumOffer[] = [
  { code: 'premium_quarterly', labelKey: 'commercePage.threeMonths', months: 3, fallbackPriceCents: 949, fallbackCoins: 90, badgeKey: 'commercePage.mostPopular' },
  { code: 'premium_monthly', labelKey: 'commercePage.monthly', months: 1, fallbackPriceCents: 329, fallbackCoins: 30 },
  { code: 'premium_yearly', labelKey: 'commercePage.twelveMonths', months: 12, fallbackPriceCents: 3349, fallbackCoins: 360, badgeKey: 'commercePage.save15' },
] as const

export default function ProPackagesPage() {
  const { t, i18n } = useTranslation()
  const trainingLabels = trainingEffectivenessLabels(i18n.resolvedLanguage ?? i18n.language)
  const { formatCurrency, formatDate } = useLocalization()
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
      showStripeNotice(t('commercePage.signInAgain'))
      return
    }

    const { data, error: intentError } = await supabase.rpc('create_commerce_checkout_intent_v1', {
      p_catalog_code: catalogCode,
    })

    if (intentError || !data) {
      showStripeNotice(intentError?.message ?? t('commercePage.checkoutUnavailable'))
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
      showStripeNotice(t('commercePage.checkoutRefresh'))
      return
    }

    const url = new URL(checkout.payment_link_url)
    url.searchParams.set('client_reference_id', checkout.intent_id)
    if (checkout.prefilled_email) url.searchParams.set('prefilled_email', checkout.prefilled_email)
    window.location.assign(url.toString())
  }

  const membership = commerce.membership
  const planName = commerce.isTrial ? t('premiumTrial.planName') : commerce.isPaidPremium ? t('commercePage.premiumName') : t('commercePage.freeName')
  const resolvedPremiumOffers = premiumOffers.map((offer) => {
    const item = catalog.find((candidate) => candidate.code === offer.code)
    const priceCents = item?.price_eur_cents ?? offer.fallbackPriceCents
    const coins = item?.coins ?? offer.fallbackCoins
    return { ...offer, priceCents, coins, monthlyEquivalentCents: Math.round(priceCents / offer.months) }
  })
  const mainPremiumOffer = resolvedPremiumOffers.find((offer) => offer.code === 'premium_quarterly')!
  const activeBillingMonths = membership?.billing_period_months ?? 1
  const activeBillingAmount = membership?.billing_amount_eur_cents ?? (commerce.isPaidPremium ? membership?.monthly_price_eur_cents ?? 329 : 0)
  const activeMonthlyEquivalent = commerce.isPaidPremium ? membership?.monthly_price_eur_cents ?? 329 : 0
  const activeCoinsPerPayment = membership?.coins_per_payment ?? (commerce.isPaidPremium ? membership?.monthly_coin_reward ?? 30 : 0)
  const coinPacks: readonly CoinPack[] = fallbackCoinPacks.map((fallback) => {
    const item = catalog.find((candidate) => candidate.code === fallback.code)
    return item ? {
      ...fallback,
      price: item.price_eur_cents / 100,
      paymentLinkUrl: item.stripe_payment_link_url,
    } : fallback
  })

  const comparisonRows = [
    [t('commercePage.comparePlayer'), true, true],
    [t('commercePage.compareTournaments'), true, true],
    [t('commercePage.compareCore'), true, true],
    [t('commercePage.compareAccount'), true, true],
    [t('statisticsPage.premiumInsights.title'), false, true],
    [t('deepMatchAnalysis.title'), false, true],
    [t('developmentPremium.title'), false, true],
    [trainingLabels.title, false, true],
    [t('commercePage.compareReward'), '—', t('commercePage.compareRewardValue')],
    [t('commercePage.compareBuyCoins'), true, true],
    [t('commercePage.compareCoinFeatures'), true, true],
  ] as const

  const money = (cents: number) => formatCurrency(cents / 100, 'EUR')
  const date = (value: string | null | undefined) => value ? formatDate(value, { year: 'numeric', month: 'long', day: 'numeric' }) : '—'

  return (
    <GameLayout title={t('commercePage.title')} subtitle={t('commercePage.subtitle')}>
      <div className="tlg-commerce-page">
        <section className="tlg-commerce-heading">
          <div>
            <span>{t('commercePage.eyebrow')}</span>
            <h1>{t('commercePage.heading')}</h1>
            <p>{t('commercePage.intro')}</p>
          </div>
          <button type="button" className="tlg-commerce-refresh" onClick={() => void commerce.refresh()}>
            <RefreshCw size={15} />
            {t('commercePage.refresh')}
          </button>
        </section>

        {checkoutNotice && (
          <div className="tlg-commerce-notice" role="status">
            <Info size={17} />
            <span>{checkoutNotice}</span>
          </div>
        )}

        {commerce.isTrial && (
          <section className="mb-4 rounded-xl border border-amber-300 bg-amber-50 p-5 text-slate-900" aria-label={t('premiumTrial.planName')}>
            <h2 className="mb-2 flex items-center gap-2 text-lg font-bold"><Crown size={20} /> {t('premiumTrial.activeLabel')}</h2>
            <p className="mb-2 text-sm">{t('premiumTrial.trialEnds', { date: date(commerce.trial?.expires_at) })}</p>
            <p className="text-sm">{t('premiumTrial.privateLife')} {t('premiumTrial.rankingProtection')}</p>
            <p className="mt-2 text-xs">{t('premiumTrial.noBilling')}</p>
          </section>
        )}

        <section className="tlg-commerce-premium-card">
          <div className="tlg-commerce-premium-main">
            <div className="tlg-commerce-badges">
              <span className="tlg-commerce-badge-premium">{t('commercePage.premium')}</span>
              <span className={commerce.isPremium ? 'tlg-commerce-badge-active' : 'tlg-commerce-badge-free'}>
                {commerce.isPremium ? t('commercePage.active') : t('commercePage.optional')}
              </span>
            </div>
            <h2>{t('commercePage.premiumName')}</h2>
            <div className="tlg-commerce-price"><strong>{money(mainPremiumOffer.priceCents)}</strong><span>{t('commercePage.everyThreeMonths', { monthly: money(mainPremiumOffer.monthlyEquivalentCents) })}</span></div>
            <ul className="tlg-commerce-benefits">
              <li><Check size={15} /> {t('statisticsPage.premiumInsights.title')}</li>
              <li><Check size={15} /> {t('deepMatchAnalysis.title')}</li>
              <li><Check size={15} /> {t('developmentPremium.title')}</li>
              <li><Check size={15} /> {trainingLabels.title}</li>
              <li><Check size={15} /> {t('premiumTrial.rankingProtection')}</li>
              <li><Check size={15} /> {t('premiumTrial.privateLife')}</li>
              <li><Check size={15} /> {t('commercePage.benefit4')}</li>
              <li><Check size={15} /> {t('commercePage.benefit5')}</li>
            </ul>
            <div className="tlg-commerce-free-rule">
              <strong>{commerce.isTrial ? t('premiumTrial.activeLabel') : commerce.isPaidPremium ? t('commercePage.premiumActive') : t('commercePage.freeAvailable')}</strong>
              <span>{commerce.isTrial ? t('premiumTrial.trialEnds', { date: date(commerce.trial?.expires_at) }) : commerce.isPaidPremium ? t('commercePage.currentPeriodEnds', { date: date(membership?.current_period_end) }) : t('commercePage.premiumOptionalBody')}</span>
            </div>
          </div>

          <aside className="tlg-commerce-premium-side">
            <Crown size={25} />
            <span>{t('commercePage.premiumMembership')}</span>
            <div className="tlg-commerce-premium-featured">
              <span className="tlg-commerce-plan-badge">{t('commercePage.mostPopular')}</span>
              <strong>{money(mainPremiumOffer.priceCents)}</strong>
              <small>{t('commercePage.everyThreeMonths', { monthly: money(mainPremiumOffer.monthlyEquivalentCents) })}</small>
              <button
                type="button"
                onClick={() => {
                  if (commerce.isPaidPremium) {
                    const portalUrl = commerceSettings?.stripe_customer_portal_url
                    if (portalUrl) window.location.assign(portalUrl)
                    else showStripeNotice(t('commercePage.subscriptionUnavailable'))
                  } else {
                    void openStripeCheckout('premium_quarterly')
                  }
                }}
              >
                {commerce.isPaidPremium ? t('commercePage.manageSubscription') : t('commercePage.chooseThree')}
              </button>
            </div>

            <div className="tlg-commerce-premium-alternatives">
              {resolvedPremiumOffers.filter((offer) => offer.code !== 'premium_quarterly').map((offer) => (
                <div key={offer.code} className="tlg-commerce-premium-option">
                  <div>
                    <span>{t(offer.labelKey)}</span>
                    {offer.badgeKey && <small className="tlg-commerce-plan-saving">{t(offer.badgeKey)}</small>}
                  </div>
                  <strong>{money(offer.priceCents)}</strong>
                  <small>{offer.months === 1 ? t('commercePage.perMonth') : t('commercePage.perYearMonthly', { monthly: money(offer.monthlyEquivalentCents) })}</small>
                  <button
                    type="button"
                    onClick={() => {
                      if (commerce.isPaidPremium) {
                        const portalUrl = commerceSettings?.stripe_customer_portal_url
                        if (portalUrl) window.location.assign(portalUrl)
                        else showStripeNotice(t('commercePage.subscriptionUnavailable'))
                      } else {
                        void openStripeCheckout(offer.code)
                      }
                    }}
                  >
                    {commerce.isPaidPremium ? t('commercePage.manage') : offer.months === 1 ? t('commercePage.chooseMonthly') : t('commercePage.chooseAnnual')}
                  </button>
                </div>
              ))}
            </div>
            <p>{t('commercePage.stripeNote')}</p>
          </aside>
        </section>

        <section className="tlg-commerce-section">
          <div className="tlg-commerce-section-title">
            <h2>{t('commercePage.comparisonTitle')}</h2>
            <p>{t('commercePage.comparisonBody')}</p>
          </div>
          <div className="tlg-commerce-table-wrap">
            <table className="tlg-commerce-table">
              <thead><tr><th>{t('commercePage.benefit')}</th><th>{t('commercePage.free')}</th><th>{t('commercePage.premiumColumn')}</th></tr></thead>
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
            <h2>{t('commercePage.coinsTitle')}</h2>
            <p>{t('commercePage.coinsBody')}</p>
          </div>
          <div className="tlg-commerce-pack-grid">
            {coinPacks.map((pack) => (
              <article key={pack.code} className={`tlg-commerce-pack ${pack.badgeKey === 'commercePage.bestValue' ? 'tlg-commerce-pack-best' : ''}`}>
                {pack.badgeKey && <span className="tlg-commerce-pack-badge">{t(pack.badgeKey)}</span>}
                <span>{t('commercePage.coinPack')}</span>
                <h3><Coins size={28} /> {pack.coins}</h3>
                <p>{t(pack.helperKey)}</p>
                <strong>{formatCurrency(pack.price, 'EUR')}</strong>
                <small>{t('commercePage.perCoin', { price: formatCurrency(pack.price / pack.coins, 'EUR') })}</small>
                <button
                  type="button"
                  onClick={() => void openStripeCheckout(pack.code)}
                >
                  {t('commercePage.buyNow')}
                </button>
                <p className="tlg-commerce-pack-footnote">{t('commercePage.coinFootnote')}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="tlg-commerce-section tlg-cpx-earn-section" aria-label={t('commercePage.earnAria')}>
          <div>
            <h2>{t('commercePage.earnTitle')}</h2>
            <p>{t('commercePage.earnBody')}</p>
          </div>
          <button type="button" className="tlg-cpx-launch"
            onClick={() => window.dispatchEvent(new Event('tlg:open-earn-coins'))}>
            <Coins size={18} /> {t('commercePage.browseSurveys')}
          </button>
        </section>

        <section className="tlg-commerce-section">
          <div className="tlg-commerce-section-title">
            <h2>{t('commercePage.currentMembership')}</h2>
            <p>{t('commercePage.currentMembershipBody')}</p>
          </div>
          <div className="tlg-commerce-membership-card">
            <MembershipStat label={t('commercePage.plan')} value={planName} />
            <MembershipStat label={t('commercePage.status')} value={commerce.isTrial ? t('premiumTrial.activeLabel') : membership?.status === 'active' ? t('commercePage.active') : membership?.status ?? t('commercePage.free')} />
            <MembershipStat label={t('commercePage.started')} value={date(commerce.isTrial ? commerce.trial?.started_at : membership?.started_at)} />
            <MembershipStat label={t('commercePage.currentPeriodEndsLabel')} value={date(commerce.isTrial ? commerce.trial?.expires_at : membership?.current_period_end)} />
            <MembershipStat label={t('commercePage.nextRenewal')} value={commerce.isPaidPremium && !membership?.cancel_at_period_end ? date(membership?.current_period_end) : '—'} />
            <MembershipStat label={t('commercePage.billingPlan')} value={commerce.isTrial ? t('premiumTrial.noBillingPlan') : commerce.isPaidPremium ? activeBillingMonths === 12 ? t('commercePage.months12') : activeBillingMonths === 3 ? t('commercePage.months3') : t('commercePage.monthly') : t('commercePage.free')} />
            <MembershipStat label={t('commercePage.pricePerPeriod')} value={money(activeBillingAmount)} />
            <MembershipStat label={t('commercePage.monthlyEquivalent')} value={money(activeMonthlyEquivalent)} />
            <MembershipStat label={t('commercePage.coinRewardPerPayment')} value={commerce.isTrial ? t('premiumTrial.noPaidCoins') : t('commercePage.coinsCount', { count: activeCoinsPerPayment })} />
            <MembershipStat label={t('commercePage.cancelAtEnd')} value={commerce.isTrial ? t('premiumTrial.noAutomaticRenewal') : membership?.cancel_at_period_end ? t('commercePage.yes') : t('commercePage.no')} />
          </div>
        </section>

        <section className="tlg-commerce-section">
          <div className="tlg-commerce-section-title">
            <h2>{t('commercePage.historyTitle')}</h2>
            <p>{t('commercePage.historyBody')}</p>
          </div>

          <HistoryBlock
            icon={<ReceiptText size={19} />}
            title={t('commercePage.premiumInvoices')}
            subtitle={t('commercePage.premiumInvoicesBody')}
            open={!!historyOpen.premium}
            onToggle={() => setHistoryOpen((current) => ({ ...current, premium: !current.premium }))}
          >
            <BillingRows rows={premiumInvoices} loading={historyLoading} empty={t('commercePage.noPremiumInvoices')} t={t} formatDateValue={date} formatMoneyValue={money} />
          </HistoryBlock>

          <HistoryBlock
            icon={<WalletCards size={19} />}
            title={t('commercePage.coinPurchases')}
            subtitle={t('commercePage.coinPurchasesBody')}
            open={!!historyOpen.packs}
            onToggle={() => setHistoryOpen((current) => ({ ...current, packs: !current.packs }))}
          >
            <BillingRows rows={coinPurchases} loading={historyLoading} empty={t('commercePage.noCoinPurchases')} t={t} formatDateValue={date} formatMoneyValue={money} />
          </HistoryBlock>

          <HistoryBlock
            icon={<History size={19} />}
            title={t('commercePage.ledger')}
            subtitle={t('commercePage.ledgerBody')}
            open={!!historyOpen.ledger}
            onToggle={() => setHistoryOpen((current) => ({ ...current, ledger: !current.ledger }))}
          >
            {historyLoading ? <div className="tlg-commerce-history-empty">{t('commercePage.loadingHistory')}</div> : ledger.length === 0 ? (
              <div className="tlg-commerce-history-empty">{t('commercePage.noCoinTransactions', { count: commerce.coins })}</div>
            ) : (
              <div className="tlg-commerce-history-list">
                {ledger.map((entry) => (
                  <div key={entry.id} className="tlg-commerce-history-row">
                    <span>{entry.description ?? entry.entry_type.replaceAll('_', ' ')}</span>
                    <span>{date(entry.created_at)}</span>
                    <strong className={entry.amount > 0 ? 'tlg-commerce-positive' : ''}>{entry.amount > 0 ? '+' : ''}{entry.amount}</strong>
                    <strong>{t('commercePage.balanceCoins', { count: entry.balance_after })}</strong>
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
  const { t } = useTranslation()
  return (
    <article className="tlg-commerce-history-card">
      <div className="tlg-commerce-history-summary">
        <div className="tlg-commerce-history-icon">{icon}</div>
        <div><strong>{title}</strong><span>{subtitle}</span></div>
        <button type="button" onClick={onToggle}>{open ? t('commercePage.hideHistory') : t('commercePage.showHistory')}</button>
      </div>
      {open && <div className="tlg-commerce-history-detail">{children}</div>}
    </article>
  )
}

function BillingRows({ rows, loading, empty, t, formatDateValue, formatMoneyValue }: { rows: BillingTransaction[]; loading: boolean; empty: string; t: ReturnType<typeof useTranslation>['t']; formatDateValue: (value: string | null | undefined) => string; formatMoneyValue: (cents: number) => string }) {
  if (loading) return <div className="tlg-commerce-history-empty">{t('commercePage.loadingHistory')}</div>
  if (!rows.length) return <div className="tlg-commerce-history-empty">{empty}</div>

  return (
    <div className="tlg-commerce-history-list">
      {rows.map((entry) => (
        <div key={entry.id} className="tlg-commerce-history-row">
          <span>{entry.description ?? entry.kind.replaceAll('_', ' ')}</span>
          <span>{formatDateValue(entry.created_at)}</span>
          <strong>{entry.coins_amount ? t('commercePage.coinsCount', { count: entry.coins_amount }) : '—'}</strong>
          <strong>{formatMoneyValue(entry.amount_eur_cents)}</strong>
        </div>
      ))}
    </div>
  )
}
