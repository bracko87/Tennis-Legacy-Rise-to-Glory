import { useCallback, useEffect, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { createPortal } from 'react-dom'

import { useLocalization } from '../../i18n/LocalizationProvider'
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

const MONTH_LENGTHS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

function absoluteGameDate(absoluteDay: number, t: TFunction) {
  const safe = Math.max(0, Math.floor(Number(absoluteDay) || 0))
  const season = Math.floor(safe / 366) + 1
  let remaining = safe % 366
  let month = 1
  while (month <= 12 && remaining >= MONTH_LENGTHS[month - 1]) {
    remaining -= MONTH_LENGTHS[month - 1]
    month += 1
  }
  const months = t('staffPage.months', { returnObjects: true }) as string[]
  const monthLabel = months[Math.max(1, Math.min(month, 12))] ?? `M${month}`
  return t('financePage.gameDate', { month: monthLabel, day: remaining + 1, season })
}

function resultLevelLabel(level: number, t: TFunction) {
  switch (Math.max(0, Math.round(Number(level) || 0))) {
    case 8: return t('financeSponsorPage.objective.result.champion')
    case 7: return t('financeSponsorPage.objective.result.final')
    case 6: return t('financeSponsorPage.objective.result.semifinal')
    case 5: return t('financeSponsorPage.objective.result.quarterfinal')
    case 4: return t('financeSponsorPage.objective.result.r16')
    case 3: return t('financeSponsorPage.objective.result.r32')
    case 2: return t('financeSponsorPage.objective.result.r64')
    case 1: return t('financeSponsorPage.objective.result.main')
    default: return t('financeSponsorPage.objective.result.notPlayed')
  }
}

function statusLabel(status: SponsorObjectiveStatus | undefined, t: TFunction) {
  return t(`financeSponsorPage.objective.status.${status ?? 'preview'}`)
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

function objectiveProgressText(objective: SponsorObjectiveView, t: TFunction) {
  const current = Math.max(0, Number(objective.current_value) || 0)
  const target = Math.max(1, Number(objective.target_value) || 1)

  if (objective.objective_code === 'tournament_result') {
    return t('financeSponsorPage.objective.progressResult', { current: resultLevelLabel(current, t), target: objective.requirement_label ?? resultLevelLabel(target, t) })
  }

  if (objective.objective_code === 'tournament_appearance') {
    return current >= 1 ? t('financeSponsorPage.objective.appearanceComplete') : t('financeSponsorPage.objective.notPlayed')
  }

  if (objective.objective_code === 'ranking_peak' || objective.objective_code === 'season_finish_rank') {
    const targetRank = targetRankFor(objective)
    const currentRank = currentRankFor(objective)
    if (targetRank && currentRank) return t('financeSponsorPage.objective.currentRank', { current: currentRank, target: targetRank })
    if (targetRank) return t('financeSponsorPage.objective.targetRank', { target: targetRank })
  }

  return `${Math.min(current, target)} / ${target}`
}

function objectiveCopy(objective: SponsorObjectiveView, t: TFunction, sponsorName?: string) {
  const target = Math.max(1, Math.round(Number(objective.target_value) || 1))
  if (objective.objective_code === 'match_wins_period' || objective.objective_code === 'match_wins') {
    return {
      title: t('financeSponsorPage.objective.dynamic.winsTitle', { count: target }),
      description: t('financeSponsorPage.objective.dynamic.winsDescription', { count: target }),
      requirement: t('financeSponsorPage.objective.dynamic.winsRequirement', { count: target }),
    }
  }
  if (objective.objective_code === 'ranking_peak' || objective.objective_code === 'season_finish_rank') {
    const rank = targetRankFor(objective) ?? target
    return {
      title: t('financeSponsorPage.objective.dynamic.rankingTitle', { rank }),
      description: t('financeSponsorPage.objective.dynamic.rankingDescription', { rank }),
      requirement: t('financeSponsorPage.objective.dynamic.rankingTitle', { rank }),
    }
  }
  if (objective.objective_code === 'tournament_appearance' && objective.tournament_name) {
    return {
      title: t('financeSponsorPage.objective.dynamic.appearanceTitle', { tournament: objective.tournament_name }),
      description: t('financeSponsorPage.objective.dynamic.appearanceDescription', { tournament: objective.tournament_name, sponsor: sponsorName ?? '' }),
      requirement: t('financeSponsorPage.objective.dynamic.appearanceRequirement'),
    }
  }
  if ((objective.objective_code === 'tournament_result' || objective.objective_code === 'performance_result') && objective.tournament_name) {
    const result = resultLevelLabel(target, t)
    return {
      title: t('financeSponsorPage.objective.dynamic.resultTitle', { tournament: objective.tournament_name }),
      description: t('financeSponsorPage.objective.dynamic.resultDescription', { tournament: objective.tournament_name, result }),
      requirement: t('financeSponsorPage.objective.dynamic.resultRequirement', { result }),
    }
  }
  return { title: objective.title, description: objective.description, requirement: objective.requirement_label ?? objective.title }
}

function SponsorLogo({ name, url }: { name: string; url?: string | null }) {
  const { t } = useTranslation()
  const [failed, setFailed] = useState(false)
  const src = (url ?? '').trim()
  if (!src || failed) {
    return <div className="tlg-finance-sponsor-logo fallback" aria-label={t('financeSponsorPage.logoAria', { name })}>{name.slice(0, 2).toUpperCase()}</div>
  }
  return <div className="tlg-finance-sponsor-logo"><img src={src} alt={t('financeSponsorPage.logoAria', { name })} onError={() => setFailed(true)} /></div>
}

function ObjectiveDetailModal({
  objective,
  onClose,
}: {
  objective: SponsorObjectiveView | null
  onClose: () => void
}) {
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()
  const money = (value: number) => formatCurrency(Math.max(0, Math.round(Number(value) || 0)), 'USD')
  const copy = objective ? objectiveCopy(objective, t) : null
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
      <section className="tlg-finance-sponsor-objective-modal" role="dialog" aria-modal="true" aria-label={copy?.title ?? objective.title}>
        <button type="button" className="tlg-finance-sponsor-objective-modal-close" onClick={onClose} aria-label={t('financeSponsorPage.objective.close')}>×</button>
        <div className="tlg-finance-sponsor-objective-modal-head">
          <div>
            <span className="tlg-finance-sponsor-kicker">{t('financeSponsorPage.objective.kicker')}</span>
            <h2>{objective.title}</h2>
          </div>
          <span className={`tlg-finance-sponsor-objective-status ${objective.status ?? 'preview'}`}>{statusLabel(objective.status, t)}</span>
        </div>

        <p className="tlg-finance-sponsor-objective-modal-description">{copy?.description}</p>

        <div className="tlg-finance-sponsor-objective-modal-grid">
          {objective.tournament_name && (
            <div><span>{t('terminology.tournament')}</span><strong>{objective.tournament_name}</strong></div>
          )}
          <div><span>{t('financeSponsorPage.objective.requirement')}</span><strong>{copy?.requirement}</strong></div>
          {objective.start_absolute_day != null && (
            <div><span>{t('financeSponsorPage.objective.starts')}</span><strong>{absoluteGameDate(objective.start_absolute_day, t)}</strong></div>
          )}
          {objective.deadline_absolute_day != null && (
            <div><span>{t('financeSponsorPage.objective.deadline')}</span><strong>{absoluteGameDate(objective.deadline_absolute_day, t)}</strong></div>
          )}
          <div><span>{t('financeSponsorPage.objective.bonus')}</span><strong>{money(objective.reward_amount)}</strong></div>
          {objective.status && (
            <div><span>{t('financeSponsorPage.objective.currentProgress')}</span><strong>{objectiveProgressText(objective, t)}</strong></div>
          )}
          {objective.category_code && (
            <div><span>{t('financeSponsorPage.objective.category')}</span><strong>{objective.category_code.replaceAll('_', ' ')}</strong></div>
          )}
          {objective.surface && (
            <div><span>{t('financeSponsorPage.objective.surface')}</span><strong>{objective.surface}</strong></div>
          )}
        </div>

        {objective.status === 'completed' && objective.achieved_absolute_day != null && (
          <p className="tlg-finance-sponsor-objective-modal-note success">
            {t('financeSponsorPage.objective.completedNote', { date: absoluteGameDate(objective.achieved_absolute_day, t) })}
          </p>
        )}
        {objective.status === 'failed' && (
          <p className="tlg-finance-sponsor-objective-modal-note failed">{t('financeSponsorPage.objective.failedNote')}</p>
        )}
        {objective.status === 'expired' && (
          <p className="tlg-finance-sponsor-objective-modal-note failed">{t('financeSponsorPage.objective.expiredNote')}</p>
        )}
      </section>
    </div>,
    document.body,
  )
}

function ObjectiveCard({ objective }: { objective: SponsorObjective }) {
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()
  const money = (value: number) => formatCurrency(Math.max(0, Math.round(Number(value) || 0)), 'USD')
  const copy = objectiveCopy(objective, t)
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
            <span className="tlg-finance-sponsor-kicker">{objective.tournament_name ? objective.tournament_name.toUpperCase() : t('financeSponsorPage.objective.performanceKicker')}</span>
            <h3>{copy.title}</h3>
          </div>
          <span className={`tlg-finance-sponsor-objective-status ${objective.status}`}>{statusLabel(objective.status, t)}</span>
        </div>
        <p>{copy.description}</p>
        <div className="tlg-finance-sponsor-objective-metrics">
          <div><span>{t('financeSponsorPage.objective.progress')}</span><strong>{objectiveProgressText(objective, t)}</strong></div>
          <div><span>{t('financeSponsorPage.objective.bonus')}</span><strong>{money(objective.reward_amount)}</strong></div>
        </div>
        {objective.deadline_absolute_day != null && (
          <div className="tlg-finance-sponsor-objective-deadline">
            <span>{t('financeSponsorPage.objective.deadline')}</span><strong>{absoluteGameDate(objective.deadline_absolute_day, t)}</strong>
          </div>
        )}
        <div className="tlg-finance-sponsor-objective-progress"><i style={{ width: `${progress}%` }} /></div>
        {objective.status === 'completed' && objective.achieved_absolute_day != null && (
          <small>{t('financeSponsorPage.objective.completedSmall', { date: absoluteGameDate(objective.achieved_absolute_day, t) })}</small>
        )}
        {objective.status === 'failed' && <small>{t('financeSponsorPage.objective.failedSmall')}</small>}
        {objective.status === 'expired' && <small>{t('financeSponsorPage.objective.expiredSmall')}</small>}
        <span className="tlg-finance-sponsor-objective-open-hint">{t('financeSponsorPage.objective.openDetails')}</span>
      </button>
      <ObjectiveDetailModal objective={open ? objective : null} onClose={() => setOpen(false)} />
    </>
  )
}

function ActiveSponsor({ contract }: { contract: SponsorContract }) {
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()
  const money = (value: number) => formatCurrency(Math.max(0, Math.round(Number(value) || 0)), 'USD')
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
            <span className="tlg-finance-sponsor-kicker">{t('financeSponsorPage.active.kicker')}</span>
            <h2>{contract.sponsor_name}</h2>
            <span className="tlg-finance-sponsor-country">{contract.sponsor_country_code}</span>
          </div>
        </div>
        <div className="tlg-finance-sponsor-contract-value">
          <span>{t('financeSponsorPage.active.guaranteed')}</span>
          <strong>{money(contract.total_contract_value)}</strong>
          <small>{t('financeSponsorPage.active.paidWeekly', { date: absoluteGameDate(contract.end_absolute_day, t) })}</small>
        </div>
      </div>

      <div className="tlg-finance-sponsor-active-stats">
        <div><span>{t('financeSponsorPage.active.weeklyPayment')}</span><strong>{money(weeklyPayment)}</strong></div>
        <div><span>{t('financeSponsorPage.active.guaranteedPaid')}</span><strong>{money(paid)}</strong></div>
        <div><span>{t('financeSponsorPage.active.bonusEarned')}</span><strong>{money(bonusEarned)}</strong></div>
        <div><span>{t('financeSponsorPage.active.nextPayment')}</span><strong>{contract.next_payment_absolute_day == null ? t('financeSponsorPage.active.seasonComplete') : absoluteGameDate(contract.next_payment_absolute_day, t)}</strong></div>
      </div>

      <section className="tlg-finance-sponsor-payment-schedule">
        <div className="tlg-finance-sponsor-payment-schedule-copy">
          <span className="tlg-finance-sponsor-kicker">{t('financeSponsorPage.active.scheduleKicker')}</span>
          <h3>{t('financeSponsorPage.active.scheduleTitle', { count: scheduledPayments, weekly: money(weeklyPayment), total: money(contract.total_contract_value) })}</h3>
          <p>{t('financeSponsorPage.active.scheduleBody')}</p>
        </div>
        <div className="tlg-finance-sponsor-payment-schedule-grid">
          <div><span>{t('financeSponsorPage.active.signed')}</span><strong>{absoluteGameDate(contract.signed_absolute_day, t)}</strong></div>
          <div><span>{t('financeSponsorPage.active.firstPayment')}</span><strong>{firstPayment == null ? '—' : absoluteGameDate(firstPayment, t)}</strong></div>
          <div><span>{t('financeSponsorPage.active.frequency')}</span><strong>{t('financeSponsorPage.active.everyDays', { count: paymentFrequency })}</strong></div>
          <div><span>{t('financeSponsorPage.active.finalPayment')}</span><strong>{lastPayment == null ? '—' : absoluteGameDate(lastPayment, t)}</strong></div>
        </div>
        <p className="tlg-finance-sponsor-payment-schedule-note">{t('financeSponsorPage.active.installmentNote', { made: paymentsMade, total: scheduledPayments })}</p>
      </section>

      <div className="tlg-finance-sponsor-progress-copy">
        <span>{t('financeSponsorPage.active.paidProgress')}</span><strong>{Math.round(progress)}%</strong>
      </div>
      <div className="tlg-finance-sponsor-progress"><i style={{ width: `${progress}%` }} /></div>

      <section className="tlg-finance-sponsor-bonus-summary">
        <div>
          <span className="tlg-finance-sponsor-kicker">{t('financeSponsorPage.active.objectivesKicker')}</span>
          <h3>{t('financeSponsorPage.active.maximumPool', { amount: money(bonusPool) })}</h3>
          <p>{t('financeSponsorPage.active.objectivesBody')}</p>
        </div>
        <div className="tlg-finance-sponsor-bonus-numbers expanded">
          <div><span>{t('financeSponsorPage.active.earned')}</span><strong>{money(bonusEarned)}</strong></div>
          <div><span>{t('financeSponsorPage.active.available')}</span><strong>{money(bonusAvailable)}</strong></div>
          <div><span>{t('financeSponsorPage.active.missed')}</span><strong>{money(bonusMissed)}</strong></div>
          <div><span>{t('financeSponsorPage.active.completed')}</span><strong>{completedObjectives} / {objectives.length}</strong></div>
        </div>
      </section>

      {objectives.length > 0 && (
        <section className="tlg-finance-sponsor-objectives-grid">
          {objectives.map((objective) => <ObjectiveCard key={objective.id} objective={objective} />)}
        </section>
      )}

      <p className="tlg-finance-sponsor-note">{t('financeSponsorPage.active.ledgerNote')}</p>
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
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()
  const money = (value: number) => formatCurrency(Math.max(0, Math.round(Number(value) || 0)), 'USD')
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
              <span className="tlg-finance-sponsor-kicker">{t('financeSponsorPage.offer.kicker')}</span>
              <h3>{offer.sponsor_name}</h3>
              <span className="tlg-finance-sponsor-country">{offer.sponsor_country_code}</span>
            </div>
          </div>

          <div className="tlg-finance-sponsor-offer-value">
            <span>{t('financeSponsorPage.offer.guaranteed')}</span>
            <strong>{money(offer.total_contract_value)}</strong>
            <small>{t('financeSponsorPage.offer.weekly', { amount: money(offer.weekly_payment_amount), count: offer.scheduled_payment_count })}</small>
          </div>

          <div className="tlg-finance-sponsor-offer-money-grid">
            <div><span>{t('financeSponsorPage.offer.bonusPool')}</span><strong>{money(bonusPool)}</strong></div>
            <div><span>{t('financeSponsorPage.offer.maximum')}</span><strong>{money(maximumTotal)}</strong></div>
          </div>

          <div className="tlg-finance-sponsor-offer-details">
            <div><span>{t('financeSponsorPage.offer.firstPayment')}</span><strong>{absoluteGameDate(offer.first_payment_absolute_day, t)}</strong></div>
            <div><span>{t('financeSponsorPage.offer.expires')}</span><strong>{absoluteGameDate(offer.expires_absolute_day, t)}</strong></div>
          </div>

          <div className="tlg-finance-sponsor-offer-objective-summary">
            <div>
              <span className="tlg-finance-sponsor-kicker">{t('financeSponsorPage.offer.expectations')}</span>
              <strong>{t('financeSponsorPage.offer.objectiveCount', { count: objectivePlan.length })}</strong>
              <small>{t('financeSponsorPage.offer.expectationsBody')}</small>
            </div>
            <button type="button" onClick={() => setShowObjectives((value) => !value)}>
              {showObjectives ? t('financeSponsorPage.offer.hideObjectives') : t('financeSponsorPage.offer.viewObjectives')}
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
                    <span>{objective.tournament_name ?? t('financeSponsorPage.offer.seasonObjective')}</span>
                    <strong>{objectiveCopy(objective, t, offer.sponsor_name).requirement}</strong>
                  </div>
                  <strong>{money(objective.reward_amount)}</strong>
                </button>
              ))}
            </div>
          )}

          <div className="tlg-finance-sponsor-offer-actions">
            <button type="button" className="secondary" disabled={actionId !== null} onClick={() => onDecline(offer.id)}>
              {busy ? t('financeSponsorPage.offer.working') : t('financeSponsorPage.offer.decline')}
            </button>
            <button type="button" className="primary" disabled={actionId !== null} onClick={() => onSign(offer.id)}>
              {busy ? t('financeSponsorPage.offer.signing') : t('financeSponsorPage.offer.sign')}
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
  const { t } = useTranslation()
  if (loading && !dashboard) return <div className="tlg-finance-sponsor-state">{t('financeSponsorPage.market.loading')}</div>
  if (error && !dashboard) {
    return <div className="tlg-finance-sponsor-state error"><span>{error}</span><button type="button" onClick={onRetry}>{t('financeSponsorPage.market.retry')}</button></div>
  }
  if (!dashboard) return null

  const offers = dashboard.offers ?? []

  return (
    <div className="tlg-finance-sponsor-page">
      {error && <div className="tlg-finance-sponsor-inline-error">{error}</div>}

      <section className="tlg-finance-sponsor-intro">
        <div>
          <span className="tlg-finance-sponsor-kicker">{t('financeSponsorPage.market.kicker')}</span>
          <h2>{t('financeSponsorPage.market.title')}</h2>
          <p>{t('financeSponsorPage.market.body')}</p>
        </div>
        <button type="button" className="tlg-finance-sponsor-refresh" onClick={onRetry} disabled={loading}>{loading ? t('financeSponsorPage.market.refreshing') : t('financeSponsorPage.market.refresh')}</button>
      </section>

      {dashboard.active_contract ? (
        <ActiveSponsor contract={dashboard.active_contract} />
      ) : (
        <>
          <section className="tlg-finance-sponsor-market-summary compact">
            <span className="tlg-finance-sponsor-kicker">{t('financeSponsorPage.market.available')}</span>
            <h2>{offers.length} sponsor offers</h2>
          </section>

          {offers.length === 0 ? (
            <div className="tlg-finance-sponsor-state">{t('financeSponsorPage.market.empty')}</div>
          ) : (
            <section className="tlg-finance-sponsor-offers-grid">
              {offers.map((offer) => (
                <SponsorOfferCard key={offer.id} offer={offer} actionId={actionId} onSign={onSign} onDecline={onDecline} />
              ))}
            </section>
          )}

          <p className="tlg-finance-sponsor-note standalone">{t('financeSponsorPage.market.signingNote')}</p>
        </>
      )}
    </div>
  )
}

export default function FinanceSponsorEnhancement() {
  const { t } = useTranslation()
  const [target, setTarget] = useState<HTMLElement | null>(null)
  const [dashboard, setDashboard] = useState<SponsorDashboard | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [actionId, setActionId] = useState<string | null>(null)

  const loadSponsors = useCallback(async () => {
    setLoading(true)
    setError(null)
    const { data, error: sponsorError } = await supabase.rpc('get_player_sponsor_dashboard_v2')
    if (sponsorError || !data) setError(sponsorError?.message ?? t('financeSponsorPage.loadError'))
    else setDashboard(data as SponsorDashboard)
    setLoading(false)
  }, [t])

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
