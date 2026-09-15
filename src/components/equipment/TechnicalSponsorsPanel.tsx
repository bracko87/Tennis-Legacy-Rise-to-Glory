import { useEffect, useMemo, useState } from 'react'

import GameConfirmDialog from '../common/GameConfirmDialog'
import { supabase } from '../../lib/supabase'

type Category = 'apparel' | 'shoes' | 'racket'
type Tier = 'entry' | 'established' | 'premium' | 'elite'
type Json = Record<string, any>

const CATEGORIES: Category[] = ['apparel', 'shoes', 'racket']
const LABEL: Record<Category, string> = { apparel: 'Clothing', shoes: 'Shoes', racket: 'Racquets' }
const SLOT: Record<Category, string> = { apparel: 'Clothing Sponsor', shoes: 'Shoe Sponsor', racket: 'Racquet Sponsor' }
const TIERS: Tier[] = ['entry', 'established', 'premium', 'elite']

function pct(value: number) {
  const n = Number(value) || 0
  return Number.isInteger(n) ? `${n}%` : `${n.toFixed(1)}%`
}

function tierLabel(value: Tier) {
  return value === 'elite' ? 'Elite / Global' : value.charAt(0).toUpperCase() + value.slice(1)
}

export default function TechnicalSponsorsPanel({ onChanged }: { onChanged?: () => Promise<void> | void }) {
  const [dashboard, setDashboard] = useState<Json | null>(null)
  const [catalog, setCatalog] = useState<Json | null>(null)
  const [pendingSign, setPendingSign] = useState<Json | null>(null)
  const [search, setSearch] = useState('')
  const [category, setCategory] = useState<'all' | Category>('all')
  const [tier, setTier] = useState<'all' | Tier>('all')
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    setError(null)
    const [d, c] = await Promise.all([
      supabase.rpc('get_player_technical_sponsor_dashboard_v1'),
      supabase.rpc('get_technical_sponsor_catalog_v1'),
    ])
    if (d.error || !d.data) setError(d.error?.message ?? 'Unable to load technical sponsor contracts.')
    else setDashboard(d.data as Json)
    if (c.error || !c.data) setError((current) => current ?? c.error?.message ?? 'Unable to load technical sponsor brands.')
    else setCatalog(c.data as Json)
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
      setMessage((data as Json)?.status === 'scheduled' ? `${offer.brand.name} is signed as your next ${LABEL[offer.category as Category].toLowerCase()} sponsor.` : `${offer.brand.name} is now your active ${LABEL[offer.category as Category].toLowerCase()} sponsor.`)
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

  const brands = useMemo(() => {
    const q = search.trim().toLowerCase()
    return ((catalog?.brands ?? []) as Json[]).filter((brand) => {
      const sponsorCategories = (brand.categories ?? []).filter((entry: Json) => CATEGORIES.includes(entry.category))
      if (!sponsorCategories.length) return false
      if (category !== 'all' && !sponsorCategories.some((entry: Json) => entry.category === category)) return false
      if (tier !== 'all' && brand.tier !== tier) return false
      return !q || `${brand.name} ${brand.country_code} ${brand.region} ${brand.philosophy}`.toLowerCase().includes(q)
    })
  }, [catalog, category, search, tier])

  if (loading && !dashboard) return <section className="tlg-equipment-panel"><div className="tlg-equipment-state">Loading Technical Sponsors…</div></section>

  return (
    <>
      <section className="tlg-equipment-panel tlg-technical-sponsor-panel">
        <header className="tlg-equipment-panel-head market-head">
          <div><span>TECHNICAL SPONSORSHIPS</span><h2>Clothing · Shoes · Racquets</h2><p>Three independent exclusive equipment contracts. Accessories remain outside the technical sponsorship system.</p></div>
          {dashboard && <div className="tlg-technical-player-profile"><span>CAREER PROFILE</span><strong>#{dashboard.player_profile.rank} · Rep {dashboard.player_profile.reputation}</strong><small>{pct(dashboard.player_profile.recent_win_pct)} recent win rate</small></div>}
        </header>
        {error && <div className="tlg-equipment-alert error tlg-technical-inline-alert">{error}</div>}
        {message && <div className="tlg-equipment-alert tlg-technical-inline-alert">{message}</div>}

        {dashboard && <div className="tlg-technical-contract-grid">{CATEGORIES.map((cat) => {
          const active = (dashboard.contracts as Json[]).find((c) => c.category === cat && c.status === 'active')
          const scheduled = (dashboard.contracts as Json[]).find((c) => c.category === cat && c.status === 'scheduled')
          const offers = (dashboard.offers as Json[]).filter((o) => o.category === cat)
          return <article className={`tlg-technical-contract-slot${active ? ' active' : ''}`} key={cat}>
            <div className="tlg-technical-contract-slot-head"><span>{SLOT[cat].toUpperCase()}</span><b>{active ? 'ACTIVE' : scheduled ? 'NEXT DEAL SIGNED' : 'OPEN'}</b></div>
            {active ? <><div className="tlg-technical-current-brand">{active.brand.logo_url && <img src={active.brand.logo_url} alt="" />}<div><small>{tierLabel(active.brand.tier)}</small><h3>{active.brand.name}</h3></div></div><div className="tlg-technical-contract-primary"><strong>{pct(active.discount_pct)}</strong><span>marketplace discount</span></div><dl className="tlg-technical-contract-facts"><div><dt>Remaining</dt><dd>{active.days_remaining} days</dd></div><div><dt>Free equipment</dt><dd>{active.free_equipment_remaining}/{active.free_equipment_allowance_total}</dd></div><div><dt>Replacements</dt><dd>{active.free_replacements_remaining}/{active.free_replacements_total}</dd></div><div><dt>Premium bonus</dt><dd>{active.premium_discount_bonus_pct ? `+${pct(active.premium_discount_bonus_pct)}` : '—'}</dd></div></dl></> : <div className="tlg-technical-no-contract"><strong>No active sponsor</strong><p>Choose from the available {LABEL[cat].toLowerCase()} proposals below.</p></div>}
            {scheduled && <div className="tlg-technical-scheduled"><span>NEXT CONTRACT</span><strong>{scheduled.brand.name}</strong><small>Starts career day {scheduled.start_absolute_day} · {pct(scheduled.discount_pct)} discount</small></div>}
            <div className="tlg-technical-slot-offer-count"><span>Available proposals</span><strong>{offers.length}</strong></div>
          </article>
        })}</div>}

        {dashboard && CATEGORIES.map((cat) => {
          const offers = (dashboard.offers as Json[]).filter((o) => o.category === cat)
          return <section className="tlg-technical-offer-section" key={cat}><div className="tlg-technical-offer-section-head"><div><span>{SLOT[cat].toUpperCase()} OFFERS</span><h3>{offers.length ? `${offers.length} proposals available` : 'No proposals available'}</h3></div><small>Offers expire automatically. Renewal offers appear in the final {dashboard.renewal_window_days} days.</small></div>{offers.length ? <div className="tlg-technical-offer-grid">{offers.map((offer) => <article className="tlg-technical-offer-card" key={offer.id}><div className="tlg-technical-offer-brand">{offer.brand.logo_url && <img src={offer.brand.logo_url} alt="" />}<div><small>{offer.brand.country_code} · {tierLabel(offer.brand.tier)}</small><h4>{offer.brand.name}</h4></div></div><div className="tlg-technical-offer-main"><strong>{pct(offer.discount_pct)}</strong><span>brand discount</span></div><div className="tlg-technical-offer-benefits"><span>{offer.contract_weeks} weeks</span><span>{offer.free_equipment_allowance} free items</span><span>{offer.free_replacement_allowance} replacements</span>{offer.premium_discount_bonus_pct > 0 && <span>+{pct(offer.premium_discount_bonus_pct)} premium</span>}</div><p>{offer.brand.philosophy}</p><details><summary>Review full offer</summary><dl className="tlg-technical-offer-review"><div><dt>Marketplace discount</dt><dd>{pct(offer.discount_pct)}</dd></div><div><dt>Premium Tier 4–5 bonus</dt><dd>{offer.premium_discount_bonus_pct ? `+${pct(offer.premium_discount_bonus_pct)}` : 'None'}</dd></div><div><dt>Free equipment allowance</dt><dd>{offer.free_equipment_allowance}</dd></div><div><dt>Free worn-item replacements</dt><dd>{offer.free_replacement_allowance}</dd></div><div><dt>Maintenance discount</dt><dd>{pct(offer.maintenance_discount_pct)} reserved for future maintenance</dd></div><div><dt>Requirements</dt><dd>Rank #{offer.requirements.target_rank_best}–#{offer.requirements.target_rank_worst} · Rep {offer.requirements.min_reputation}+</dd></div><div><dt>Your profile</dt><dd>#{offer.player_rank} · Rep {offer.player_reputation} · {pct(offer.recent_win_pct)} recent wins</dd></div><div><dt>Offer expiry</dt><dd>Career day {offer.expires_absolute_day}</dd></div></dl></details><div className="tlg-technical-offer-foot"><span>{offer.is_renewal ? 'Renewal offer' : `Expires in ${offer.days_until_expiry} days`}</span><div><button type="button" className="secondary" disabled={busy === `decline:${offer.id}`} onClick={() => void declineOffer(offer)}>Decline</button><button type="button" onClick={() => setPendingSign(offer)}>Sign</button></div></div></article>)}</div> : <div className="tlg-technical-empty-offers">No open {LABEL[cat].toLowerCase()} offers right now.</div>}</section>
        })}
      </section>

      <section className="tlg-equipment-panel tlg-technical-sponsor-panel tlg-technical-brand-pool">
        <header className="tlg-equipment-panel-head market-head"><div><span>TECHNICAL BRAND POOL</span><h2>{catalog?.brands?.length ?? 0} international brands</h2><p>Browse the manufacturers behind the offer system. Only Clothing, Shoes and Racquets count as technical sponsor slots.</p></div><div className="tlg-equipment-market-balance"><span>VISIBLE</span><strong>{brands.length}</strong></div></header>
        <div className="tlg-technical-sponsor-toolbar"><input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search brand, country or philosophy…" /><select value={category} onChange={(e) => setCategory(e.target.value as 'all' | Category)}><option value="all">All 3 categories</option>{CATEGORIES.map((c) => <option value={c} key={c}>{SLOT[c]}</option>)}</select><select value={tier} onChange={(e) => setTier(e.target.value as 'all' | Tier)}><option value="all">All tiers</option>{TIERS.map((t) => <option value={t} key={t}>{tierLabel(t)}</option>)}</select></div>
        <div className="tlg-technical-sponsor-grid">{brands.map((brand) => <article className="tlg-technical-sponsor-card" key={brand.id}><div className="tlg-technical-sponsor-logo">{brand.logo_url ? <img src={brand.logo_url} alt={`${brand.name} logo`} /> : <span>{brand.name.slice(0, 2)}</span>}</div><div className="tlg-technical-sponsor-card-head"><div><span>{brand.country_code} · {brand.region}</span><h3>{brand.name}</h3></div><b className={`tier ${brand.tier}`}>{tierLabel(brand.tier)}</b></div><p>{brand.philosophy}</p><div className="tlg-technical-sponsor-categories">{brand.categories.filter((entry: Json) => CATEGORIES.includes(entry.category)).map((entry: Json) => <span key={entry.category}>{LABEL[entry.category as Category]} · {entry.product_count_target} models</span>)}</div><div className="tlg-technical-sponsor-metrics"><div><span>Prestige</span><strong>{brand.prestige}/100</strong></div><div><span>Contract</span><strong>{brand.contract_strength}/100</strong></div><div><span>Generosity</span><strong>{brand.generosity}/100</strong></div><div><span>Products</span><strong>{brand.product_count}</strong></div></div></article>)}</div>
      </section>

      {pendingSign && <GameConfirmDialog open eyebrow="Technical sponsorship" title={`Sign with ${pendingSign.brand.name}?`} message={<>This creates an exclusive <strong>{SLOT[pendingSign.category as Category]}</strong> agreement for {pendingSign.contract_weeks} weeks with a <strong>{pct(pendingSign.discount_pct)}</strong> equipment discount.</>} detail={pendingSign.available_from_absolute_day > (dashboard?.current_absolute_day ?? 0) ? <>The agreement will be scheduled to begin on career day <strong>{pendingSign.available_from_absolute_day}</strong> after your current deal ends.</> : <>The agreement becomes active immediately and other open offers in this category expire.</>} confirmLabel="Sign technical sponsor" tone="neutral" busy={busy === `sign:${pendingSign.id}`} onCancel={() => { if (!busy) setPendingSign(null) }} onConfirm={signOffer} />}
    </>
  )
}
