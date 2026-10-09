import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'

import GameConfirmDialog from '../common/GameConfirmDialog'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { supabase } from '../../lib/supabase'
import '../../styles/equipment-refinement-v2.css'

type Category = 'apparel' | 'shoes' | 'racket'
type Tier = 'entry' | 'established' | 'premium' | 'elite'
type Json = Record<string, any>

const CATEGORIES: Category[] = ['apparel', 'shoes', 'racket']

function pct(value: number) {
  const n = Number(value) || 0
  return Number.isInteger(n) ? `${n}%` : `${n.toFixed(1)}%`
}


export default function TechnicalSponsorsPanel({ onChanged }: { onChanged?: () => Promise<void> | void }) {
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()
  const money = (value: number) => formatCurrency(Number(value) || 0, 'USD')
  const categoryLabel = (category: Category) => t(`equipmentPage.categories.${category}`)
  const slotLabel = (category: Category) => t(`equipmentPage.technicalUi.slots.${category}`)
  const tierLabel = (value: Tier) => t(`equipmentPage.ui.sponsorTiers.${value}`)
  const [dashboard, setDashboard] = useState<Json | null>(null)
  const [pendingSign, setPendingSign] = useState<Json | null>(null)
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    setError(null)
    const { data, error: loadError } = await supabase.rpc('get_player_technical_sponsor_dashboard_v1')
    if (loadError || !data) setError(loadError?.message ?? t('equipmentPage.technicalLoadError'))
    else setDashboard(data as Json)
    setLoading(false)
  }

  useEffect(() => { void load() }, [])

  async function signOffer() {
    if (!pendingSign) return
    const offer = pendingSign
    setBusy(`sign:${offer.id}`)
    setError(null)
    const { data, error: signError } = await supabase.rpc('sign_player_technical_sponsor_offer_v1', { p_offer_id: offer.id })
    if (signError) setError(signError.message)
    else {
      const result = data as Json
      const bonus = Number(result?.signing_bonus_usd ?? offer.signing_bonus_usd ?? 0)
      const suffix = bonus > 0 ? t('equipmentPage.technicalUi.bonusAdded', { amount: money(bonus) }) : ''
      const category = categoryLabel(offer.category as Category).toLowerCase()
      setMessage(result?.status === 'scheduled'
        ? t('equipmentPage.technicalUi.scheduledSigned', { brand: offer.brand.name, category, suffix })
        : t('equipmentPage.technicalUi.activeSigned', { brand: offer.brand.name, category, suffix }))
      setPendingSign(null)
      await load()
      await onChanged?.()
    }
    setBusy(null)
  }

  async function declineOffer(offer: Json) {
    setBusy(`decline:${offer.id}`)
    setError(null)
    const { error: declineError } = await supabase.rpc('decline_player_technical_sponsor_offer_v1', { p_offer_id: offer.id })
    if (declineError) setError(declineError.message)
    else { setMessage(t('equipmentPage.technicalUi.declined', { brand: offer.brand.name })); await load() }
    setBusy(null)
  }

  if (loading && !dashboard) return <section className="tlg-equipment-panel"><div className="tlg-equipment-state">{t('equipmentPage.technicalUi.loading')}</div></section>

  return (
    <>
      <section className="tlg-equipment-panel tlg-technical-sponsor-panel tlg-technical-sponsor-panel-v2">
        <header className="tlg-equipment-panel-head market-head">
          <div><span>{t('equipmentPage.technicalUi.kicker')}</span><h2>{t('equipmentPage.technicalUi.heading')}</h2><p>{t('equipmentPage.technicalUi.intro')}</p></div>
          {dashboard && <div className="tlg-technical-player-profile"><span>{t('equipmentPage.technicalUi.currentRanking')}</span><strong>#{dashboard.player_profile.rank}</strong></div>}
        </header>
        {error && <div className="tlg-equipment-alert error tlg-technical-inline-alert">{error}</div>}
        {message && <div className="tlg-equipment-alert tlg-technical-inline-alert">{message}</div>}

        {dashboard && <div className="tlg-technical-contract-grid">{CATEGORIES.map((cat) => {
          const active = (dashboard.contracts as Json[]).find((c) => c.category === cat && c.status === 'active')
          const scheduled = (dashboard.contracts as Json[]).find((c) => c.category === cat && c.status === 'scheduled')
          const offers = (dashboard.offers as Json[]).filter((o) => o.category === cat)
          return <article className={`tlg-technical-contract-slot${active ? ' active' : ''}`} key={cat}>
            <div className="tlg-technical-contract-slot-head"><span>{slotLabel(cat).toUpperCase()}</span><b>{active ? t('equipmentPage.technicalUi.status.active') : scheduled ? t('equipmentPage.technicalUi.status.scheduled') : t('equipmentPage.technicalUi.status.open')}</b></div>
            {active ? <>
              <div className="tlg-technical-current-brand">{active.brand.logo_url && <img src={active.brand.logo_url} alt={`${active.brand.name} logo`} />}<div><small>{tierLabel(active.brand.tier)}</small><h3>{active.brand.name}</h3></div></div>
              <div className="tlg-technical-contract-primary"><strong>{pct(active.discount_pct)}</strong><span>{t('equipmentPage.technicalUi.marketplaceDiscount')}</span></div>
              <dl className="tlg-technical-contract-facts"><div><dt>{t('equipmentPage.technicalUi.contract')}</dt><dd>{t('equipmentPage.technicalUi.untilSeasonEnd')}</dd></div><div><dt>{t('equipmentPage.technicalUi.marketplace')}</dt><dd>{t('equipmentPage.technicalUi.off', { discount: pct(active.discount_pct) })}</dd></div><div><dt>{t('equipmentPage.technicalUi.premiumTier')}</dt><dd>{Number(active.premium_discount_bonus_pct) > 0 ? `+${pct(active.premium_discount_bonus_pct)}` : t('equipmentPage.technicalUi.sameDiscount')}</dd></div><div><dt>{t('equipmentPage.technicalUi.signedAt')}</dt><dd>{t('equipmentPage.technicalUi.worldRank', { rank: active.player_rank_at_sign })}</dd></div></dl>
            </> : <div className="tlg-technical-no-contract"><strong>{t('equipmentPage.technicalUi.noActive')}</strong><p>{t('equipmentPage.technicalUi.chooseProposals', { category: categoryLabel(cat).toLowerCase() })}</p></div>}
            {scheduled && <div className="tlg-technical-scheduled"><span>{t('equipmentPage.technicalUi.nextContract')}</span><strong>{scheduled.brand.name}</strong><small>{t('equipmentPage.technicalUi.startsNextSeason', { discount: pct(scheduled.discount_pct) })}</small></div>}
            <div className="tlg-technical-slot-offer-count"><span>{t('equipmentPage.technicalUi.availableProposals')}</span><strong>{offers.length}</strong></div>
          </article>
        })}</div>}

        {dashboard && CATEGORIES.map((cat) => {
          const offers = (dashboard.offers as Json[]).filter((o) => o.category === cat)
          return <section className="tlg-technical-offer-section" key={cat}>
            <div className="tlg-technical-offer-section-head"><div><span>{t('equipmentPage.technicalUi.offersKicker', { slot: slotLabel(cat).toUpperCase() })}</span><h3>{offers.length ? t('equipmentPage.technicalUi.proposalsAvailable', { count: offers.length }) : t('equipmentPage.technicalUi.noProposals')}</h3></div><small>{t('equipmentPage.technicalUi.rankingGroupNote')}</small></div>
            {offers.length ? <div className="tlg-technical-offer-grid">{offers.map((offer) => <article className="tlg-technical-offer-card tlg-technical-offer-card-v2" key={offer.id}>
              <div className="tlg-technical-offer-copy">
                <div className="tlg-technical-offer-brand">{offer.brand.logo_url && <img src={offer.brand.logo_url} alt="" />}<div><small>{offer.brand.country_code} · {tierLabel(offer.brand.tier)}</small><h4>{offer.brand.name}</h4></div></div>
                <div className="tlg-technical-offer-main"><strong>{pct(offer.discount_pct)}</strong><span>{t('equipmentPage.technicalUi.brandDiscount')}</span></div>
                <div className="tlg-technical-offer-benefits"><span>{t('equipmentPage.technicalUi.untilSeasonEnd')}</span><span>{t('equipmentPage.technicalUi.discountOnly')}</span>{Number(offer.signing_bonus_usd) > 0 && <span>{t('equipmentPage.technicalUi.signingBonus', { amount: money(offer.signing_bonus_usd) })}</span>}{offer.premium_discount_bonus_pct > 0 && <span>{t('equipmentPage.technicalUi.premiumItemDiscount', { discount: pct(offer.premium_discount_bonus_pct) })}</span>}</div>
                <p>{offer.brand.philosophy}</p>
                <details><summary>{t('equipmentPage.technicalUi.reviewOffer')}</summary><dl className="tlg-technical-offer-review"><div><dt>{t('equipmentPage.technicalUi.marketplaceDiscount')}</dt><dd>{pct(offer.discount_pct)}</dd></div><div><dt>{t('equipmentPage.technicalUi.signingPayment')}</dt><dd>{Number(offer.signing_bonus_usd) > 0 ? money(offer.signing_bonus_usd) : t('equipmentPage.technicalUi.noSigningPayment')}</dd></div><div><dt>{t('equipmentPage.technicalUi.equipmentBenefit')}</dt><dd>{t('equipmentPage.technicalUi.discountedOnly')}</dd></div><div><dt>{t('equipmentPage.technicalUi.premiumBonus')}</dt><dd>{offer.premium_discount_bonus_pct ? `+${pct(offer.premium_discount_bonus_pct)}` : t('equipmentPage.technicalUi.sameBaseDiscount')}</dd></div><div><dt>{t('equipmentPage.technicalUi.eligibility')}</dt><dd>{t('equipmentPage.technicalUi.eligibilityValue', { group: offer.requirements.rank_group_label, best: offer.requirements.rank_best, worst: offer.requirements.rank_worst })}</dd></div><div><dt>{t('equipmentPage.technicalUi.rankingAtOffer')}</dt><dd>{t('equipmentPage.technicalUi.worldRank', { rank: offer.player_rank })}</dd></div><div><dt>{t('equipmentPage.technicalUi.contractTerm')}</dt><dd>{t('equipmentPage.technicalUi.contractTermValue')}</dd></div><div><dt>{t('equipmentPage.technicalUi.offerExpiry')}</dt><dd>{t('equipmentPage.technicalUi.inDays', { count: offer.days_until_expiry })}</dd></div></dl></details>
                <div className="tlg-technical-offer-foot"><span>{offer.is_renewal ? t('equipmentPage.technicalUi.renewal') : t('equipmentPage.technicalUi.expiresIn', { count: offer.days_until_expiry })}</span><div><button type="button" className="secondary" disabled={busy === `decline:${offer.id}`} onClick={() => void declineOffer(offer)}>{t('equipmentPage.technicalUi.decline')}</button><button type="button" onClick={() => setPendingSign(offer)}>{t('equipmentPage.technicalUi.sign')}</button></div></div>
              </div>
              <div className="tlg-technical-offer-logo-stage">{offer.brand.logo_url ? <img src={offer.brand.logo_url} alt={`${offer.brand.name} logo`} /> : <strong>{offer.brand.name}</strong>}</div>
            </article>)}</div> : <div className="tlg-technical-empty-offers">{t('equipmentPage.technicalUi.noOpenOffers', { category: categoryLabel(cat).toLowerCase() })}</div>}
          </section>
        })}
      </section>

      {pendingSign && <GameConfirmDialog open eyebrow={t('equipmentPage.technicalUi.dialogEyebrow')} title={t('equipmentPage.technicalUi.dialogTitle', { brand: pendingSign.brand.name })} message={<>{t('equipmentPage.technicalUi.dialogMessage', { slot: slotLabel(pendingSign.category as Category), discount: pct(pendingSign.discount_pct) })}</>} detail={<>{Number(pendingSign.signing_bonus_usd) > 0 ? t('equipmentPage.technicalUi.dialogSigning', { amount: money(pendingSign.signing_bonus_usd) }) : ''}{t('equipmentPage.technicalUi.dialogDetail', { rank: pendingSign.player_rank })}</>} confirmLabel={t('equipmentPage.technicalUi.confirm')} tone="neutral" busy={busy === `sign:${pendingSign.id}`} onCancel={() => { if (!busy) setPendingSign(null) }} onConfirm={signOffer} />}
    </>
  )
}
