import { useEffect, useState } from 'react'

import GameConfirmDialog from '../common/GameConfirmDialog'
import { supabase } from '../../lib/supabase'
import '../../styles/equipment-refinement-v2.css'

type Category = 'apparel' | 'shoes' | 'racket'
type Tier = 'entry' | 'established' | 'premium' | 'elite'
type Json = Record<string, any>

const CATEGORIES: Category[] = ['apparel', 'shoes', 'racket']
const LABEL: Record<Category, string> = { apparel: 'Clothing', shoes: 'Shoes', racket: 'Racquets' }
const SLOT: Record<Category, string> = { apparel: 'Clothing Sponsor', shoes: 'Shoe Sponsor', racket: 'Racquet Sponsor' }

function pct(value: number) {
  const n = Number(value) || 0
  return Number.isInteger(n) ? `${n}%` : `${n.toFixed(1)}%`
}

function money(value: number) {
  return `$${Math.round(Number(value) || 0).toLocaleString()}`
}

function tierLabel(value: Tier) {
  return value === 'elite' ? 'Elite / Global' : value.charAt(0).toUpperCase() + value.slice(1)
}

export default function TechnicalSponsorsPanel({ onChanged }: { onChanged?: () => Promise<void> | void }) {
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
    if (loadError || !data) setError(loadError?.message ?? 'Unable to load technical sponsor contracts.')
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
      const suffix = bonus > 0 ? ` ${money(bonus)} was added to Career Finance.` : ''
      setMessage(result?.status === 'scheduled'
        ? `${offer.brand.name} is signed as your next ${LABEL[offer.category as Category].toLowerCase()} sponsor.${suffix}`
        : `${offer.brand.name} is now your active ${LABEL[offer.category as Category].toLowerCase()} sponsor.${suffix}`)
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
    else { setMessage(`${offer.brand.name} offer declined.`); await load() }
    setBusy(null)
  }

  if (loading && !dashboard) return <section className="tlg-equipment-panel"><div className="tlg-equipment-state">Loading Technical Sponsors…</div></section>

  return (
    <>
      <section className="tlg-equipment-panel tlg-technical-sponsor-panel tlg-technical-sponsor-panel-v2">
        <header className="tlg-equipment-panel-head market-head">
          <div><span>TECHNICAL SPONSORSHIPS</span><h2>Clothing · Shoes · Racquets</h2><p>One exclusive equipment sponsor per category. Offers are based only on your current world ranking and every signed agreement runs until the end of its season.</p></div>
          {dashboard && <div className="tlg-technical-player-profile"><span>CURRENT RANKING</span><strong>#{dashboard.player_profile.rank}</strong></div>}
        </header>
        {error && <div className="tlg-equipment-alert error tlg-technical-inline-alert">{error}</div>}
        {message && <div className="tlg-equipment-alert tlg-technical-inline-alert">{message}</div>}

        {dashboard && <div className="tlg-technical-contract-grid">{CATEGORIES.map((cat) => {
          const active = (dashboard.contracts as Json[]).find((c) => c.category === cat && c.status === 'active')
          const scheduled = (dashboard.contracts as Json[]).find((c) => c.category === cat && c.status === 'scheduled')
          const offers = (dashboard.offers as Json[]).filter((o) => o.category === cat)
          return <article className={`tlg-technical-contract-slot${active ? ' active' : ''}`} key={cat}>
            <div className="tlg-technical-contract-slot-head"><span>{SLOT[cat].toUpperCase()}</span><b>{active ? 'ACTIVE' : scheduled ? 'NEXT DEAL SIGNED' : 'OPEN'}</b></div>
            {active ? <>
              <div className="tlg-technical-current-brand">{active.brand.logo_url && <img src={active.brand.logo_url} alt={`${active.brand.name} logo`} />}<div><small>{tierLabel(active.brand.tier)}</small><h3>{active.brand.name}</h3></div></div>
              <div className="tlg-technical-contract-primary"><strong>{pct(active.discount_pct)}</strong><span>marketplace discount</span></div>
              <dl className="tlg-technical-contract-facts"><div><dt>Contract</dt><dd>Until season end</dd></div><div><dt>Free equipment</dt><dd>{active.free_equipment_remaining}/{active.free_equipment_allowance_total}</dd></div><div><dt>Replacements</dt><dd>{active.free_replacements_remaining}/{active.free_replacements_total}</dd></div><div><dt>Signed at</dt><dd>World #{active.player_rank_at_sign}</dd></div></dl>
            </> : <div className="tlg-technical-no-contract"><strong>No active sponsor</strong><p>Choose from the available {LABEL[cat].toLowerCase()} proposals below.</p></div>}
            {scheduled && <div className="tlg-technical-scheduled"><span>NEXT CONTRACT</span><strong>{scheduled.brand.name}</strong><small>Starts after the current season · {pct(scheduled.discount_pct)} discount</small></div>}
            <div className="tlg-technical-slot-offer-count"><span>Available proposals</span><strong>{offers.length}</strong></div>
          </article>
        })}</div>}

        {dashboard && CATEGORIES.map((cat) => {
          const offers = (dashboard.offers as Json[]).filter((o) => o.category === cat)
          return <section className="tlg-technical-offer-section" key={cat}>
            <div className="tlg-technical-offer-section-head"><div><span>{SLOT[cat].toUpperCase()} OFFERS</span><h3>{offers.length ? `${offers.length} proposals available` : 'No proposals available'}</h3></div><small>Offer quantity and value are determined by your current ranking group.</small></div>
            {offers.length ? <div className="tlg-technical-offer-grid">{offers.map((offer) => <article className="tlg-technical-offer-card tlg-technical-offer-card-v2" key={offer.id}>
              <div className="tlg-technical-offer-copy">
                <div className="tlg-technical-offer-brand">{offer.brand.logo_url && <img src={offer.brand.logo_url} alt="" />}<div><small>{offer.brand.country_code} · {tierLabel(offer.brand.tier)}</small><h4>{offer.brand.name}</h4></div></div>
                <div className="tlg-technical-offer-main"><strong>{pct(offer.discount_pct)}</strong><span>brand discount</span></div>
                <div className="tlg-technical-offer-benefits"><span>Until season end</span><span>{offer.free_equipment_allowance} free items</span><span>{offer.free_replacement_allowance} replacements</span>{Number(offer.signing_bonus_usd) > 0 && <span>{money(offer.signing_bonus_usd)} signing bonus</span>}{offer.premium_discount_bonus_pct > 0 && <span>+{pct(offer.premium_discount_bonus_pct)} premium</span>}</div>
                <p>{offer.brand.philosophy}</p>
                <details><summary>Review full offer</summary><dl className="tlg-technical-offer-review"><div><dt>Marketplace discount</dt><dd>{pct(offer.discount_pct)}</dd></div><div><dt>Signing payment</dt><dd>{Number(offer.signing_bonus_usd) > 0 ? money(offer.signing_bonus_usd) : 'No signing payment'}</dd></div><div><dt>Free equipment allowance</dt><dd>{offer.free_equipment_allowance}</dd></div><div><dt>Free worn-item replacements</dt><dd>{offer.free_replacement_allowance}</dd></div><div><dt>Premium Tier 4–5 bonus</dt><dd>{offer.premium_discount_bonus_pct ? `+${pct(offer.premium_discount_bonus_pct)}` : 'None'}</dd></div><div><dt>Eligibility</dt><dd>Current ranking only · {offer.requirements.rank_group_label} (#{offer.requirements.rank_best}–#{offer.requirements.rank_worst})</dd></div><div><dt>Your ranking at offer</dt><dd>World #{offer.player_rank}</dd></div><div><dt>Contract term</dt><dd>Signing/start date through season end</dd></div><div><dt>Offer expiry</dt><dd>In {offer.days_until_expiry} days</dd></div></dl></details>
                <div className="tlg-technical-offer-foot"><span>{offer.is_renewal ? 'Renewal offer' : `Expires in ${offer.days_until_expiry} days`}</span><div><button type="button" className="secondary" disabled={busy === `decline:${offer.id}`} onClick={() => void declineOffer(offer)}>Decline</button><button type="button" onClick={() => setPendingSign(offer)}>Sign</button></div></div>
              </div>
              <div className="tlg-technical-offer-logo-stage">{offer.brand.logo_url ? <img src={offer.brand.logo_url} alt={`${offer.brand.name} logo`} /> : <strong>{offer.brand.name}</strong>}</div>
            </article>)}</div> : <div className="tlg-technical-empty-offers">No open {LABEL[cat].toLowerCase()} offers right now.</div>}
          </section>
        })}
      </section>

      {pendingSign && <GameConfirmDialog open eyebrow="Technical sponsorship" title={`Sign with ${pendingSign.brand.name}?`} message={<>This creates an exclusive <strong>{SLOT[pendingSign.category as Category]}</strong> agreement with a <strong>{pct(pendingSign.discount_pct)}</strong> equipment discount until the end of the season.</>} detail={<>{Number(pendingSign.signing_bonus_usd) > 0 ? <>Signing payment: <strong>{money(pendingSign.signing_bonus_usd)}</strong>. </> : null}Free equipment: <strong>{pendingSign.free_equipment_allowance}</strong>. The agreement is based on your current world ranking of <strong>#{pendingSign.player_rank}</strong>.</>} confirmLabel="Sign technical sponsor" tone="neutral" busy={busy === `sign:${pendingSign.id}`} onCancel={() => { if (!busy) setPendingSign(null) }} onConfirm={signOffer} />}
    </>
  )
}
