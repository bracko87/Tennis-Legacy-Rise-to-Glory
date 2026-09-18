import { useCallback, useEffect, useState } from 'react'
import { createPortal } from 'react-dom'

import { supabase } from '../../lib/supabase'
import '../../styles/finance-sponsors.css'
import '../../styles/finance-sponsor-objectives.css'

type SponsorSourcePool = 'market' | 'worldwide'
type SponsorObjectiveStatus = 'upcoming' | 'active' | 'completed' | 'failed' | 'expired'
type SponsorObjectiveCode =
  | 'tournament_appearance'
  | 'tournament_result'
  | 'ranking_peak'
  | 'season_finish_rank'
  | 'match_wins_period'
  | 'appearances'
  | 'match_wins'
  | 'performance_result'

interface SponsorObjectiveView {
  id?: string
  objective_key?: string
  objective_code: SponsorObjectiveCode
  title: string
  description: string
  target_value: number
  current_value?: number
  reward_amount: number
  status?: SponsorObjectiveStatus
  achieved_absolute_day?: number | null
  competition_id?: string | null
  tournament_series_id?: string | null
  tournament_name?: string | null
  requirement_label?: string | null
  start_absolute_day?: number | null
  deadline_absolute_day?: number | null
  country_code?: string | null
  category_code?: string | null
  surface?: string | null
  target_rank?: number | null
  geography_basis?: string | null
  metadata?: Record<string, unknown> | null
}

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
  performance_bonus_pool?: number
  maximum_total_value?: number
  objective_plan?: SponsorObjectiveView[]
  status: string
}

interface SponsorObjective extends SponsorObjectiveView {
  id: string
  current_value: number
  status: SponsorObjectiveStatus
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
  first_payment_absolute_day?: number | null
  last_payment_absolute_day?: number | null
  payment_frequency_days?: number | null
  full_season_value: number
  weekly_payment_amount: number
  scheduled_payment_count: number
  total_contract_value: number
  maximum_total_value?: number
  income_received: number
  next_payment_absolute_day?: number | null
  bonus_pool_total?: number
  bonus_earned?: number
  bonus_available?: number
  bonus_missed?: number
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

function resultLevelLabel(level: number) {
  switch (Math.max(0, Math.round(Number(level) || 0))) {
    case 8: return 'Champion'
    case 7: return 'Final'
    case 6: return 'Semifinal'
    case 5: return 'Quarterfinal'
    case 4: return 'Round of 16'
    case 3: return 'Round of 32'
    case 2: return 'Round of 64'
    case 1: return 'Main Draw'
    default: return 'Not played'
  }
}

function statusLabel(status?: SponsorObjectiveStatus) {
  if (!status) return 'Preview'
  return status.charAt(0).toUpperCase() + status.slice(1)
}

function targetRankFor(objective: SponsorObjectiveView) {
  const fromTopLevel = Number(objective.target_rank)
  if (Number.isFinite(fromTopLevel) && fromTopLevel > 0) return fromTopLevel
  const fromMetadata = Number(objective.metadata?.target_rank)
  return Number.isFinite(fromMetadata) && fromMetadata > 0 ? fromMetadata : null
}

function currentRankFor(objective: SponsorObjectiveView) {
  const currentRank = Number(objective.metadata?.current_rank)
  return Number.isFinite(currentRank) && currentRank > 0 ? currentRank : null
}

function objectiveProgressText(objective: SponsorObjectiveView) {
  const current = Math.max(0, Number(objective.current_value) || 0)
  const target = Math.max(1, Number(objective.target_value) || 1)

  if (objective.objective_code === 'tournament_result') {
    return `${resultLevelLabel(current)} · target ${objective.requirement_label ?? resultLevelLabel(target)}`
  }

  if (objective.objective_code === 'tournament_appearance') {
    return current >= 1 ? 'Tournament appearance completed' : 'Not yet played'
  }

  if (objective.objective_code === 'ranking_peak' || objective.objective_code === 'season_finish_rank') {
    const targetRank = targetRankFor(objective)
    const currentRank = currentRankFor(objective)
    if (targetRank && currentRank) return `Current #${currentRank} · target Top ${targetRank}`
    if (targetRank) return `Target Top ${targetRank}`
  }

  return `${Math.min(current, target)} / ${target}`
}

function SponsorLogo({ name, url }: { name: string; url?: string | null }) {
  const [failed, setFailed] = useState(false)
  const src = (url ?? '').trim()
  if (!src || failed) {
    return <div className="tlg-finance-sponsor-logo fallback" aria-label={`${name} logo`}>{name.slice(0, 2).toUpperCase()}</div>
  }
  return <div className="tlg-finance-sponsor-logo"><img src={src} alt={`${name} logo`} onError={() => setFailed(true)} /></div>
}

function ObjectiveDetailModal({
  objective,
  onClose,
}: {
  objective: SponsorObjectiveView | null
  onClose: () => void
}) {
  useEffect(() => {
    if (!objective) return
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [objective, onClose])

  if (!objective || typeof document === 'undefined') return null

  return createPortal(
    <div
      className="tlg-finance-sponsor-objective-modal-backdrop"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose()
      }}
    >
      <section className="tlg-finance-sponsor-objective-modal" role="dialog" aria-modal="true" aria-label={objective.title}>
        <button type="button" className="tlg-finance-sponsor-objective-modal-close" onClick={onClose} aria-label="Close objective details">×</button>
        <div className="tlg-finance-sponsor-objective-modal-head">
          <div>
            <span className="tlg-finance-sponsor-kicker">SPONSOR PERFORMANCE OBJECTIVE</span>
            <h2>{objective.title}</h2>
          </div>
          <span className={`tlg-finance-sponsor-objective-status ${objective.status ?? 'preview'}`}>{statusLabel(objective.status)}</span>
        </div>

        <p className="tlg-finance-sponsor-objective-modal-description">{objective.description}</p>

        <div className="tlg-finance-sponsor-objective-modal-grid">
          {objective.tournament_name && (
            <div><span>Tournament</span><strong>{objective.tournament_name}</strong></div>
          )}
          <div><span>Requirement</span><strong>{objective.requirement_label ?? objective.title}</strong></div>
          {objective.start_absolute_day != null && (
            <div><span>Starts</span><strong>{absoluteGameDate(objective.start_absolute_day)}</strong></div>
          )}
          {objective.deadline_absolute_day != null && (
            <div><span>Deadline</span><strong>{absoluteGameDate(objective.deadline_absolute_day)}</strong></div>
          )}
          <div><span>Bonus</span><strong>{money(objective.reward_amount)}</strong></div>
          {objective.status && (
            <div><span>Current progress</span><strong>{objectiveProgressText(objective)}</strong></div>
          )}
          {objective.category_code && (
            <div><span>Category</span><strong>{objective.category_code.replaceAll('_', ' ')}</strong></div>
          )}
          {objective.surface && (
            <div><span>Surface</span><strong>{objective.surface}</strong></div>
          )}
        </div>

        {objective.status === 'completed' && objective.achieved_absolute_day != null && (
          <p className="tlg-finance-sponsor-objective-modal-note success">
            Completed {absoluteGameDate(objective.achieved_absolute_day)}. The bonus was posted to Career Balance.
          </p>
        )}
        {objective.status === 'failed' && (
          <p className="tlg-finance-sponsor-objective-modal-note failed">The requirement was attempted but not achieved.</p>
        )}
        {objective.status === 'expired' && (
          <p className="tlg-finance-sponsor-objective-modal-note failed">The deadline passed and this bonus is no longer available.</p>
        )}
      </section>
    </div>,
    document.body,
  )
}

function ObjectiveCard({ objective }: { objective: SponsorObjective }) {
  const [open, setOpen] = useState(false)
  const current = Math.max(0, Number(objective.current_value) || 0)
  const target = Math.max(1, Number(objective.target_value) || 1)
  const progress = objective.objective_code === 'ranking_peak' || objective.objective_code === 'season_finish_rank'
    ? (current >= 1 ? 100 : 0)
    : Math.min(100, (current / target) * 100)

  return (
    <>
      <button
        type="button"
        className={`tlg-finance-sponsor-objective ${objective.status}`}
        onClick={() => setOpen(true)}
      >
        <div className="tlg-finance-sponsor-objective-head">
          <div>
            <span className="tlg-finance-sponsor-kicker">{objective.tournament_name ? objective.tournament_name.toUpperCase() : 'PERFORMANCE OBJECTIVE'}</span>
            <h3>{objective.title}</h3>
          </div>
          <span className={`tlg-finance-sponsor-objective-status ${objective.status}`}>{statusLabel(objective.status)}</span>
        </div>
        <p>{objective.description}</p>
        <div className="tlg-finance-sponsor-objective-metrics">
          <div><span>Progress</span><strong>{objectiveProgressText(objective)}</strong></div>
          <div><span>Bonus</span><strong>{money(objective.reward_amount)}</strong></div>
        </div>
        {objective.deadline_absolute_day != null && (
          <div className="tlg-finance-sponsor-objective-deadline">
            <span>Deadline</span><strong>{absoluteGameDate(objective.deadline_absolute_day)}</strong>
          </div>
        )}
        <div className="tlg-finance-sponsor-objective-progress"><i style={{ width: `${progress}%` }} /></div>
        {objective.status === 'completed' && objective.achieved_absolute_day != null && (
          <small>Completed {absoluteGameDate(objective.achieved_absolute_day)} · Bonus posted to Career Balance</small>
        )}
        {objective.status === 'failed' && <small>Requirement missed. This bonus cannot be paid later.</small>}
        {objective.status === 'expired' && <small>Deadline passed. This bonus is no longer available.</small>}
        <span className="tlg-finance-sponsor-objective-open-hint">Open details</span>
      </button>
      <ObjectiveDetailModal objective={open ? objective : null} onClose={() => setOpen(false)} />
    </>
  )
}

function ActiveSponsor({ contract }: { contract: SponsorContract }) {
  const paid = Math.max(0, Number(contract.income_received) || 0)
  const total = Math.max(1, Number(contract.total_contract_value) || 1)
  const weeklyPayment = Math.max(0, Number(contract.weekly_payment_amount) || 0)
  const scheduledPayments = Math.max(0, Number(contract.scheduled_payment_count) || 0)
  const paymentsMade = weeklyPayment > 0 ? Math.min(scheduledPayments, Math.floor(paid / weeklyPayment)) : 0
  const firstPayment = contract.first_payment_absolute_day
  const lastPayment = contract.last_payment_absolute_day ?? (
    firstPayment == null ? null : firstPayment + Math.max(0, scheduledPayments - 1) * 7
  )
  const paymentFrequency = Math.max(1, Number(contract.payment_frequency_days) || 7)
  const progress = Math.min(100, (paid / total) * 100)
  const objectives = contract.objectives ?? []
  const bonusPool = Math.max(0, Number(contract.bonus_pool_total) || 0)
  const bonusEarned = Math.max(0, Number(contract.bonus_earned) || 0)
  const bonusMissed = Math.max(0, Number(contract.bonus_missed) || 0)
  const bonusAvailable = Math.max(0, Number(contract.bonus_available) || Math.max(0, bonusPool - bonusEarned - bonusMissed))
  const completedObjectives = objectives.filter((objective) => objective.status === 'completed').length

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
          <span>TOTAL GUARANTEED PAYMENTS</span>
          <strong>{money(contract.total_contract_value)}</strong>
          <small>Paid weekly · not upfront · agreement through {absoluteGameDate(contract.end_absolute_day)}</small>
        </div>
      </div>

      <div className="tlg-finance-sponsor-active-stats">
        <div><span>Weekly payment</span><strong>{money(weeklyPayment)}</strong></div>
        <div><span>Guaranteed paid</span><strong>{money(paid)}</strong></div>
        <div><span>Bonus earned</span><strong>{money(bonusEarned)}</strong></div>
        <div><span>Next payment</span><strong>{contract.next_payment_absolute_day == null ? 'Season complete' : absoluteGameDate(contract.next_payment_absolute_day)}</strong></div>
      </div>

      <section className="tlg-finance-sponsor-payment-schedule">
        <div className="tlg-finance-sponsor-payment-schedule-copy">
          <span className="tlg-finance-sponsor-kicker">GUARANTEED PAYMENT SCHEDULE</span>
          <h3>{scheduledPayments} weekly payments × {money(weeklyPayment)} = {money(contract.total_contract_value)}</h3>
          <p>The guaranteed agreement is the fixed sponsor income promised for the season. Performance bonuses sit outside this guaranteed amount.</p>
        </div>
        <div className="tlg-finance-sponsor-payment-schedule-grid">
          <div><span>Agreement signed</span><strong>{absoluteGameDate(contract.signed_absolute_day)}</strong></div>
          <div><span>First payment</span><strong>{firstPayment == null ? '—' : absoluteGameDate(firstPayment)}</strong></div>
          <div><span>Payment frequency</span><strong>Every {paymentFrequency} game days</strong></div>
          <div><span>Final guaranteed payment</span><strong>{lastPayment == null ? '—' : absoluteGameDate(lastPayment)}</strong></div>
        </div>
        <p className="tlg-finance-sponsor-payment-schedule-note">Each installment is automatically added to Career Balance and the Transactions ledger on its due date. {paymentsMade} of {scheduledPayments} guaranteed payments received.</p>
      </section>

      <div className="tlg-finance-sponsor-progress-copy">
        <span>Guaranteed agreement paid</span><strong>{Math.round(progress)}%</strong>
      </div>
      <div className="tlg-finance-sponsor-progress"><i style={{ width: `${progress}%` }} /></div>

      <section className="tlg-finance-sponsor-bonus-summary">
        <div>
          <span className="tlg-finance-sponsor-kicker">OBJECTIVES / PERFORMANCE BONUSES</span>
          <h3>{money(bonusPool)} maximum Performance Bonus Pool</h3>
          <p>Each objective has its own requirement, deadline and cash value. Completed objectives pay automatically and exactly once.</p>
        </div>
        <div className="tlg-finance-sponsor-bonus-numbers expanded">
          <div><span>Earned</span><strong>{money(bonusEarned)}</strong></div>
          <div><span>Still available</span><strong>{money(bonusAvailable)}</strong></div>
          <div><span>Missed / expired</span><strong>{money(bonusMissed)}</strong></div>
          <div><span>Completed</span><strong>{completedObjectives} / {objectives.length}</strong></div>
        </div>
      </section>

      {objectives.length > 0 && (
        <section className="tlg-finance-sponsor-objectives-grid">
          {objectives.map((objective) => <ObjectiveCard key={objective.id} objective={objective} />)}
        </section>
      )}

      <p className="tlg-finance-sponsor-note">Guaranteed payments and completed objective bonuses are posted automatically to the Finance transaction ledger.</p>
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
  const [showObjectives, setShowObjectives] = useState(false)
  const [selectedObjective, setSelectedObjective] = useState<SponsorObjectiveView | null>(null)
  const busy = actionId === offer.id
  const objectivePlan = offer.objective_plan ?? []
  const bonusPool = Math.max(0, Number(offer.performance_bonus_pool) || 0)
  const maximumTotal = Math.max(0, Number(offer.maximum_total_value) || (Number(offer.total_contract_value) || 0) + bonusPool)

  return (
    <>
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
            <span>GUARANTEED VALUE TO SEASON END</span>
            <strong>{money(offer.total_contract_value)}</strong>
            <small>{money(offer.weekly_payment_amount)} per week · {offer.scheduled_payment_count} guaranteed payments</small>
          </div>

          <div className="tlg-finance-sponsor-offer-money-grid">
            <div><span>Performance Bonus Pool</span><strong>{money(bonusPool)}</strong></div>
            <div><span>Maximum possible value</span><strong>{money(maximumTotal)}</strong></div>
          </div>

          <div className="tlg-finance-sponsor-offer-details">
            <div><span>First payment</span><strong>{absoluteGameDate(offer.first_payment_absolute_day)}</strong></div>
            <div><span>Offer expires</span><strong>{absoluteGameDate(offer.expires_absolute_day)}</strong></div>
          </div>

          <div className="tlg-finance-sponsor-offer-objective-summary">
            <div>
              <span className="tlg-finance-sponsor-kicker">SPONSOR EXPECTATIONS</span>
              <strong>{objectivePlan.length} performance objectives</strong>
              <small>Objectives are matched to ranking, sponsor/player geography and realistic tournament level.</small>
            </div>
            <button type="button" onClick={() => setShowObjectives((value) => !value)}>
              {showObjectives ? 'Hide objectives' : 'View objectives'}
            </button>
          </div>

          {showObjectives && objectivePlan.length > 0 && (
            <div className="tlg-finance-sponsor-offer-objective-list">
              {objectivePlan.map((objective, index) => (
                <button
                  key={objective.objective_key ?? `${offer.id}-objective-${index}`}
                  type="button"
                  onClick={() => setSelectedObjective(objective)}
                >
                  <div>
                    <span>{objective.tournament_name ?? 'Season objective'}</span>
                    <strong>{objective.requirement_label ?? objective.title}</strong>
                  </div>
                  <strong>{money(objective.reward_amount)}</strong>
                </button>
              ))}
            </div>
          )}

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

      <ObjectiveDetailModal objective={selectedObjective} onClose={() => setSelectedObjective(null)} />
    </>
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
          <p>Choose one main sponsor for the current season. Guaranteed income is paid weekly; the separate Performance Bonus Pool is earned through clearly defined objectives.</p>
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

          <p className="tlg-finance-sponsor-note standalone">Signing one agreement locks that sponsor's displayed objectives and closes the other main-sponsor offers for the current season.</p>
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
