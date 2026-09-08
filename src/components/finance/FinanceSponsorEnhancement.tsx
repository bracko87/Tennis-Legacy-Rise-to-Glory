import { useCallback, useEffect, useState } from 'react'
import { createPortal } from 'react-dom'

import { supabase } from '../../lib/supabase'
import '../../styles/finance-sponsors.css'

type SponsorSourcePool = 'market' | 'worldwide'

interface SponsorOffer {
  id: string
  sponsor_company_id: string
  sponsor_name: string
  sponsor_country_code: string
  logo_url: string
  is_worldwide: boolean
  source_pool: SponsorSourcePool
  market_group_code: string
  player_rank: number
  generated_absolute_day: number
  expires_absolute_day: number
  first_payment_absolute_day: number
  full_season_value: number
  weekly_payment_amount: number
  scheduled_payment_count: number
  total_contract_value: number
  status: string
}

interface SponsorContract {
  id: string
  sponsor_company_id: string
  sponsor_name: string
  sponsor_country_code: string
  logo_url: string
  is_worldwide: boolean
  source_pool: SponsorSourcePool
  market_group_code: string
  signed_absolute_day: number
  start_absolute_day: number
  end_absolute_day: number
  full_season_value: number
  weekly_payment_amount: number
  scheduled_payment_count: number
  total_contract_value: number
  income_received: number
  next_payment_absolute_day?: number | null
  status: string
}

interface SponsorDashboard {
  player_id: string
  season: number
  current_absolute_day: number
  season_end_absolute_day: number
  player_rank: number
  player_country_code: string
  market: {
    code: string
    name: string
    macro_region: string
  }
  offer_rule: {
    code: string
    offer_count_min: number
    offer_count_max: number
    local_share_percent: number
    worldwide_share_percent: number
    full_season_value_min: number
    full_season_value_max: number
  }
  offer_week_start_absolute_day: number
  next_offer_refresh_absolute_day: number
  active_contract: SponsorContract | null
  offers: SponsorOffer[]
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const MONTH_LENGTHS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

function money(value: number) {
  return `$${Math.max(0, Math.round(Number(value) || 0)).toLocaleString()}`
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
  return `${MONTHS[Math.max(0, Math.min(month, 12) - 1)]} ${remaining + 1} · Season ${season}`
}

function sponsorLogoUrl(url: string | null | undefined) {
  return (url ?? '').trim()
}

function SponsorLogo({ name, url }: { name: string; url?: string | null }) {
  const [failed, setFailed] = useState(false)
  const src = sponsorLogoUrl(url)
  if (!src || failed) {
    return <div className="tlg-finance-sponsor-logo fallback" aria-label={`${name} logo`}>{name.slice(0, 2).toUpperCase()}</div>
  }
  return <div className="tlg-finance-sponsor-logo"><img src={src} alt={`${name} logo`} onError={() => setFailed(true)} /></div>
}

function SourceBadge({ source, marketName }: { source: SponsorSourcePool; marketName: string }) {
  return (
    <span className={`tlg-finance-sponsor-badge ${source === 'worldwide' ? 'worldwide' : 'market'}`}>
      {source === 'worldwide' ? 'Worldwide' : marketName}
    </span>
  )
}

function ActiveSponsor({ contract, dashboard }: { contract: SponsorContract; dashboard: SponsorDashboard }) {
  const paid = Math.max(0, Number(contract.income_received) || 0)
  const total = Math.max(1, Number(contract.total_contract_value) || 1)
  const progress = Math.min(100, (paid / total) * 100)

  return (
    <section className="tlg-finance-sponsor-active">
      <div className="tlg-finance-sponsor-active-head">
        <div className="tlg-finance-sponsor-brand">
          <SponsorLogo name={contract.sponsor_name} url={contract.logo_url} />
          <div>
            <span className="tlg-finance-sponsor-kicker">ACTIVE MAIN SPONSOR</span>
            <h2>{contract.sponsor_name}</h2>
            <div className="tlg-finance-sponsor-brand-meta">
              <span>{contract.sponsor_country_code}</span>
              <SourceBadge source={contract.source_pool} marketName={dashboard.market.name} />
            </div>
          </div>
        </div>
        <div className="tlg-finance-sponsor-contract-value">
          <span>SEASON AGREEMENT</span>
          <strong>{money(contract.total_contract_value)}</strong>
          <small>Guaranteed through {absoluteGameDate(contract.end_absolute_day)}</small>
        </div>
      </div>

      <div className="tlg-finance-sponsor-active-stats">
        <div><span>Weekly payment</span><strong>{money(contract.weekly_payment_amount)}</strong></div>
        <div><span>Paid to date</span><strong>{money(paid)}</strong></div>
        <div><span>Next payment</span><strong>{contract.next_payment_absolute_day == null ? 'Season complete' : absoluteGameDate(contract.next_payment_absolute_day)}</strong></div>
        <div><span>Signed</span><strong>{absoluteGameDate(contract.signed_absolute_day)}</strong></div>
      </div>

      <div className="tlg-finance-sponsor-progress-copy">
        <span>Agreement paid</span><strong>{Math.round(progress)}%</strong>
      </div>
      <div className="tlg-finance-sponsor-progress"><i style={{ width: `${progress}%` }} /></div>
      <p className="tlg-finance-sponsor-note">Guaranteed sponsor payments are posted automatically to Career Balance every seven game days and are included in taxable sponsorship income.</p>
    </section>
  )
}

function SponsorOfferCard({
  offer,
  dashboard,
  actionId,
  onSign,
  onDecline,
}: {
  offer: SponsorOffer
  dashboard: SponsorDashboard
  actionId: string | null
  onSign: (id: string) => void
  onDecline: (id: string) => void
}) {
  const busy = actionId === offer.id
  return (
    <article className="tlg-finance-sponsor-offer">
      <div className="tlg-finance-sponsor-offer-brand">
        <SponsorLogo name={offer.sponsor_name} url={offer.logo_url} />
        <div>
          <SourceBadge source={offer.source_pool} marketName={dashboard.market.name} />
          <h3>{offer.sponsor_name}</h3>
          <span className="tlg-finance-sponsor-country">{offer.sponsor_country_code}</span>
        </div>
      </div>

      <div className="tlg-finance-sponsor-offer-value">
        <span>CONTRACT VALUE TO SEASON END</span>
        <strong>{money(offer.total_contract_value)}</strong>
        <small>{money(offer.weekly_payment_amount)} / week · {offer.scheduled_payment_count} payments</small>
      </div>

      <div className="tlg-finance-sponsor-offer-details">
        <div><span>Full-season equivalent</span><strong>{money(offer.full_season_value)}</strong></div>
        <div><span>First payment</span><strong>{absoluteGameDate(offer.first_payment_absolute_day)}</strong></div>
        <div><span>Offer expires</span><strong>{absoluteGameDate(offer.expires_absolute_day)}</strong></div>
      </div>

      <div className="tlg-finance-sponsor-offer-actions">
        <button type="button" className="secondary" disabled={actionId !== null} onClick={() => onDecline(offer.id)}>
          {busy ? 'Working…' : 'Decline'}
        </button>
        <button type="button" className="primary" disabled={actionId !== null} onClick={() => onSign(offer.id)}>
          {busy ? 'Signing…' : 'Sign agreement'}
        </button>
      </div>
    </article>
  )
}

function SponsorContent({
  dashboard,
  loading,
  error,
  actionId,
  onRetry,
  onSign,
  onDecline,
}: {
  dashboard: SponsorDashboard | null
  loading: boolean
  error: string | null
  actionId: string | null
  onRetry: () => void
  onSign: (id: string) => void
  onDecline: (id: string) => void
}) {
  if (loading && !dashboard) return <div className="tlg-finance-sponsor-state">Loading sponsor market…</div>
  if (error && !dashboard) {
    return <div className="tlg-finance-sponsor-state error"><span>{error}</span><button type="button" onClick={onRetry}>Retry</button></div>
  }
  if (!dashboard) return null

  const offers = dashboard.offers ?? []
  const marketCount = offers.filter((offer) => offer.source_pool === 'market').length
  const worldwideCount = offers.filter((offer) => offer.source_pool === 'worldwide').length

  return (
    <div className="tlg-finance-sponsor-page">
      {error && <div className="tlg-finance-sponsor-inline-error">{error}</div>}

      <section className="tlg-finance-sponsor-intro">
        <div>
          <span className="tlg-finance-sponsor-kicker">COMMERCIAL PARTNERSHIPS</span>
          <h2>Sponsor agreements</h2>
          <p>Choose one main sponsor for the current season. Your ranking controls how many offers arrive, how much they are worth, and how strongly the weekly market leans toward your home marketing region.</p>
        </div>
        <button type="button" className="tlg-finance-sponsor-refresh" onClick={onRetry} disabled={loading}>{loading ? 'Refreshing…' : 'Refresh offers'}</button>
      </section>

      <section className="tlg-finance-sponsor-context">
        <div><span>WORLD RANKING</span><strong>#{dashboard.player_rank}</strong><small>Current ranking used for this offer batch</small></div>
        <div><span>HOME MARKETING MARKET</span><strong>{dashboard.market.name}</strong><small>{dashboard.player_country_code} · {dashboard.market.macro_region}</small></div>
        <div><span>WEEKLY OFFER RANGE</span><strong>{dashboard.offer_rule.offer_count_min}–{dashboard.offer_rule.offer_count_max}</strong><small>{dashboard.offer_rule.local_share_percent}% market · {dashboard.offer_rule.worldwide_share_percent}% worldwide</small></div>
        <div><span>NEXT OFFER REFRESH</span><strong>{absoluteGameDate(dashboard.next_offer_refresh_absolute_day)}</strong><small>New weekly group if no agreement is signed</small></div>
      </section>

      {dashboard.active_contract ? (
        <ActiveSponsor contract={dashboard.active_contract} dashboard={dashboard} />
      ) : (
        <>
          <section className="tlg-finance-sponsor-market-summary">
            <div>
              <span className="tlg-finance-sponsor-kicker">THIS WEEK'S SPONSOR MARKET</span>
              <h2>{offers.length} offers available</h2>
              <p>{marketCount} from {dashboard.market.name} · {worldwideCount} worldwide. Offer value is based on your current ranking and the number of weekly payments remaining before season end.</p>
            </div>
            <div className="tlg-finance-sponsor-season-scale">
              <span>RANK BAND FULL-SEASON RANGE</span>
              <strong>{money(dashboard.offer_rule.full_season_value_min)} – {money(dashboard.offer_rule.full_season_value_max)}</strong>
              <small>Your actual contract is prorated automatically to the remaining season.</small>
            </div>
          </section>

          {offers.length === 0 ? (
            <div className="tlg-finance-sponsor-state">No open sponsor offers in the current weekly group. New offers arrive at the next weekly refresh.</div>
          ) : (
            <section className="tlg-finance-sponsor-offers-grid">
              {offers.map((offer) => (
                <SponsorOfferCard key={offer.id} offer={offer} dashboard={dashboard} actionId={actionId} onSign={onSign} onDecline={onDecline} />
              ))}
            </section>
          )}

          <p className="tlg-finance-sponsor-note standalone">Signing one agreement closes every other open main-sponsor offer for the current season. Declined offers are not replaced until the next weekly sponsor group.</p>
        </>
      )}
    </div>
  )
}

export default function FinanceSponsorEnhancement() {
  const [target, setTarget] = useState<HTMLElement | null>(null)
  const [dashboard, setDashboard] = useState<SponsorDashboard | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [actionId, setActionId] = useState<string | null>(null)

  const loadSponsors = useCallback(async () => {
    setLoading(true)
    setError(null)
    const { data, error: sponsorError } = await supabase.rpc('get_player_sponsor_dashboard_v1')
    if (sponsorError || !data) setError(sponsorError?.message ?? 'Unable to load sponsor offers.')
    else setDashboard(data as SponsorDashboard)
    setLoading(false)
  }, [])

  useEffect(() => {
    const locate = () => {
      const next = document.querySelector<HTMLElement>('.tlg-finance-v2-sponsors')
      if (next) {
        if (!next.classList.contains('tlg-finance-v2-sponsors-enhanced')) next.classList.add('tlg-finance-v2-sponsors-enhanced')
        setTarget((current) => current === next ? current : next)
      } else {
        setTarget((current) => current === null ? current : null)
      }
    }

    locate()
    const observer = new MutationObserver(locate)
    observer.observe(document.body, { childList: true, subtree: true })
    return () => observer.disconnect()
  }, [])

  useEffect(() => {
    if (target) void loadSponsors()
  }, [target, loadSponsors])

  async function signOffer(offerId: string) {
    setActionId(offerId)
    setError(null)
    const { error: signError } = await supabase.rpc('sign_player_sponsor_offer_v1', { p_offer_id: offerId })
    if (signError) setError(signError.message)
    else await loadSponsors()
    setActionId(null)
  }

  async function declineOffer(offerId: string) {
    setActionId(offerId)
    setError(null)
    const { error: declineError } = await supabase.rpc('decline_player_sponsor_offer_v1', { p_offer_id: offerId })
    if (declineError) setError(declineError.message)
    else await loadSponsors()
    setActionId(null)
  }

  if (!target) return null

  return createPortal(
    <SponsorContent
      dashboard={dashboard}
      loading={loading}
      error={error}
      actionId={actionId}
      onRetry={() => void loadSponsors()}
      onSign={(id) => void signOffer(id)}
      onDecline={(id) => void declineOffer(id)}
    />,
    target,
  )
}
