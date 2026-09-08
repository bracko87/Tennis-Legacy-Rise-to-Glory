import { useCallback, useEffect, useState } from 'react'
import { createPortal } from 'react-dom'

import { supabase } from '../../lib/supabase'
import '../../styles/finance-sponsors.css'

type SponsorSourcePool = 'market' | 'worldwide'
type SponsorObjectiveStatus = 'active' | 'achieved' | 'failed'

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

interface SponsorObjective {
  id: string
  objective_code: 'appearances' | 'match_wins' | 'performance_result'
  title: string
  description: string
  target_value: number
  current_value: number
  reward_amount: number
  status: SponsorObjectiveStatus
  achieved_absolute_day?: number | null
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
  bonus_pool_total?: number
  bonus_earned?: number
  objectives?: SponsorObjective[]
  status: string
}

interface SponsorDashboard {
  player_id: string
  season: number
  current_absolute_day: number
  season_end_absolute_day: number
  player_rank: number
  player_country_code: string
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

function SponsorLogo({ name, url }: { name: string; url?: string | null }) {
  const [failed, setFailed] = useState(false)
  const src = (url ?? '').trim()
  if (!src || failed) {
    return <div className="tlg-finance-sponsor-logo fallback" aria-label={`${name} logo`}>{name.slice(0, 2).toUpperCase()}</div>
  }
  return <div className="tlg-finance-sponsor-logo"><img src={src} alt={`${name} logo`} onError={() => setFailed(true)} /></div>
}

function ObjectiveCard({ objective }: { objective: SponsorObjective }) {
  const current = Math.max(0, Number(objective.current_value) || 0)
  const target = Math.max(1, Number(objective.target_value) || 1)
  const progress = Math.min(100, (current / target) * 100)
  const displayCurrent = Math.min(current, target)

  return (
    <article className={`tlg-finance-sponsor-objective ${objective.status}`}>
      <div className="tlg-finance-sponsor-objective-head">
        <div>
          <span className="tlg-finance-sponsor-kicker">PERFORMANCE OBJECTIVE</span>
          <h3>{objective.title}</h3>
        </div>
        <span className={`tlg-finance-sponsor-objective-status ${objective.status}`}>{objective.status}</span>
      </div>
      <p>{objective.description}</p>
      <div className="tlg-finance-sponsor-objective-metrics">
        <div><span>Progress</span><strong>{displayCurrent} / {target}</strong></div>
        <div><span>Bonus</span><strong>{money(objective.reward_amount)}</strong></div>
      </div>
      <div className="tlg-finance-sponsor-objective-progress"><i style={{ width: `${progress}%` }} /></div>
      {objective.status === 'achieved' && objective.achieved_absolute_day != null && (
        <small>Completed {absoluteGameDate(objective.achieved_absolute_day)} · Bonus posted to Career Balance</small>
      )}
      {objective.status === 'failed' && <small>Agreement ended before this objective was completed.</small>}
    </article>
  )
}

function ActiveSponsor({ contract }: { contract: SponsorContract }) {
  const paid = Math.max(0, Number(contract.income_received) || 0)
  const total = Math.max(1, Number(contract.total_contract_value) || 1)
  const progress = Math.min(100, (paid / total) * 100)
  const objectives = contract.objectives ?? []
  const bonusPool = Math.max(0, Number(contract.bonus_pool_total) || 0)
  const bonusEarned = Math.max(0, Number(contract.bonus_earned) || 0)
  const achievedObjectives = objectives.filter((objective) => objective.status === 'achieved').length

  return (
    <section className="tlg-finance-sponsor-active">
      <div className="tlg-finance-sponsor-active-head">
        <div className="tlg-finance-sponsor-brand">
          <SponsorLogo name={contract.sponsor_name} url={contract.logo_url} />
          <div>
            <span className="tlg-finance-sponsor-kicker">ACTIVE MAIN SPONSOR</span>
            <h2>{contract.sponsor_name}</h2>
            <span className="tlg-finance-sponsor-country">{contract.sponsor_country_code}</span>
          </div>
        </div>
        <div className="tlg-finance-sponsor-contract-value">
          <span>GUARANTEED AGREEMENT</span>
          <strong>{money(contract.total_contract_value)}</strong>
          <small>Through {absoluteGameDate(contract.end_absolute_day)}</small>
        </div>
      </div>

      <div className="tlg-finance-sponsor-active-stats">
        <div><span>Weekly payment</span><strong>{money(contract.weekly_payment_amount)}</strong></div>
        <div><span>Guaranteed paid</span><strong>{money(paid)}</strong></div>
        <div><span>Bonus earned</span><strong>{money(bonusEarned)}</strong></div>
        <div><span>Next payment</span><strong>{contract.next_payment_absolute_day == null ? 'Season complete' : absoluteGameDate(contract.next_payment_absolute_day)}</strong></div>
      </div>

      <div className="tlg-finance-sponsor-progress-copy">
        <span>Guaranteed agreement paid</span><strong>{Math.round(progress)}%</strong>
      </div>
      <div className="tlg-finance-sponsor-progress"><i style={{ width: `${progress}%` }} /></div>

      <section className="tlg-finance-sponsor-bonus-summary">
        <div>
          <span className="tlg-finance-sponsor-kicker">PERFORMANCE BONUS POOL</span>
          <h3>{money(bonusPool)} available</h3>
          <p>Performance bonuses sit on top of the guaranteed agreement and are paid automatically when an objective is achieved.</p>
        </div>
        <div className="tlg-finance-sponsor-bonus-numbers">
          <div><span>Earned</span><strong>{money(bonusEarned)}</strong></div>
          <div><span>Objectives complete</span><strong>{achievedObjectives} / {objectives.length}</strong></div>
        </div>
      </section>

      {objectives.length > 0 && (
        <section className="tlg-finance-sponsor-objectives-grid">
          {objectives.map((objective) => <ObjectiveCard key={objective.id} objective={objective} />)}
        </section>
      )}

      <p className="tlg-finance-sponsor-note">Guaranteed payments and achieved objective bonuses are posted automatically to the Finance transaction ledger.</p>
    </section>
  )
}

function SponsorOfferCard({
  offer,
  actionId,
  onSign,
  onDecline,
}: {
  offer: SponsorOffer
  actionId: string | null
  onSign: (id: string) => void
  onDecline: (id: string) => void
}) {
  const busy = actionId === offer.id
  return (
    <article className="tlg-finance-sponsor-offer">
      <div className="tlg-finance-sponsor-offer-visual">
        <SponsorLogo name={offer.sponsor_name} url={offer.logo_url} />
      </div>

      <div className="tlg-finance-sponsor-offer-content">
        <div className="tlg-finance-sponsor-offer-heading">
          <div>
            <span className="tlg-finance-sponsor-kicker">MAIN SPONSOR OFFER</span>
            <h3>{offer.sponsor_name}</h3>
            <span className="tlg-finance-sponsor-country">{offer.sponsor_country_code}</span>
          </div>
        </div>

        <div className="tlg-finance-sponsor-offer-value">
          <span>CONTRACT VALUE TO SEASON END</span>
          <strong>{money(offer.total_contract_value)}</strong>
          <small>{money(offer.weekly_payment_amount)} per week · {offer.scheduled_payment_count} payments</small>
        </div>

        <div className="tlg-finance-sponsor-offer-details">
          <div><span>First payment</span><strong>{absoluteGameDate(offer.first_payment_absolute_day)}</strong></div>
          <div><span>Offer expires</span><strong>{absoluteGameDate(offer.expires_absolute_day)}</strong></div>
        </div>

        <p className="tlg-finance-sponsor-offer-bonus-note">Three performance objectives add extra cash bonuses on top of the guaranteed contract.</p>

        <div className="tlg-finance-sponsor-offer-actions">
          <button type="button" className="secondary" disabled={actionId !== null} onClick={() => onDecline(offer.id)}>
            {busy ? 'Working…' : 'Decline'}
          </button>
          <button type="button" className="primary" disabled={actionId !== null} onClick={() => onSign(offer.id)}>
            {busy ? 'Signing…' : 'Sign agreement'}
          </button>
        </div>
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
  if (loading && !dashboard) return <div className="tlg-finance-sponsor-state">Loading sponsor offers…</div>
  if (error && !dashboard) {
    return <div className="tlg-finance-sponsor-state error"><span>{error}</span><button type="button" onClick={onRetry}>Retry</button></div>
  }
  if (!dashboard) return null

  const offers = dashboard.offers ?? []

  return (
    <div className="tlg-finance-sponsor-page">
      {error && <div className="tlg-finance-sponsor-inline-error">{error}</div>}

      <section className="tlg-finance-sponsor-intro">
        <div>
          <span className="tlg-finance-sponsor-kicker">COMMERCIAL PARTNERSHIPS</span>
          <h2>Sponsor agreements</h2>
          <p>Choose one main sponsor for the current season. Contract value follows your ranking and is recalculated at the exact moment you sign.</p>
        </div>
        <button type="button" className="tlg-finance-sponsor-refresh" onClick={onRetry} disabled={loading}>{loading ? 'Refreshing…' : 'Refresh offers'}</button>
      </section>

      {dashboard.active_contract ? (
        <ActiveSponsor contract={dashboard.active_contract} />
      ) : (
        <>
          <section className="tlg-finance-sponsor-market-summary compact">
            <span className="tlg-finance-sponsor-kicker">AVAILABLE SPONSORS</span>
            <h2>{offers.length} sponsor offers</h2>
          </section>

          {offers.length === 0 ? (
            <div className="tlg-finance-sponsor-state">No sponsor offers are currently available.</div>
          ) : (
            <section className="tlg-finance-sponsor-offers-grid">
              {offers.map((offer) => (
                <SponsorOfferCard key={offer.id} offer={offer} actionId={actionId} onSign={onSign} onDecline={onDecline} />
              ))}
            </section>
          )}

          <p className="tlg-finance-sponsor-note standalone">Signing one agreement closes the other main-sponsor offers for the current season.</p>
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
    const { data, error: sponsorError } = await supabase.rpc('get_player_sponsor_dashboard_v2')
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
