import { useEffect, useState } from 'react'
import { ChevronDown, ChevronUp, Crown, ExternalLink, LockKeyhole, Scale } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'

import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import { tournamentPlanningLabels } from '../../lib/tournamentPlanningI18n'
import '../../styles/tournament-planning-premium.css'

type Tournament = {
  competition_id: string
  tournament_name: string
  season_week_start: number
  season_week_end: number
  city: string
  country_code: string
  category_code: string
  category_label: string
  surface: string
  winner_points: number
  finalist_points: number | null
  prize_pool_usd: number | null
  winner_prize_usd: number | null
  finalist_prize_usd: number | null
  main_draw_capacity: number
  qualifying_capacity_max: number
  tournament_status: string
  user_status: string
  applications_open: boolean
  health_blocked: boolean
  accepted_overlap: boolean
  pending_overlap: boolean
  other_calendar_choices: number
  planning_advisory: string
}

type PlannerReport = {
  player_id: string
  month: number
  season: number
  world: string
  tournament_count: number
  currency: string
  tournaments: Tournament[]
}

const visibleChoices = 3
const isCancelled = (value: Tournament) => value.planning_advisory === 'canceled'

export default function TournamentPlanningIntelligence({
  playerId, season, month, clockLoading,
}: {
  playerId: string | null
  season: number
  month: number
  clockLoading: boolean
}) {
  const { t, i18n } = useTranslation()
  const l = tournamentPlanningLabels(i18n.resolvedLanguage ?? i18n.language)
  const { isPremium, loading: checkingPremium } = useCommerce()
  const [expanded, setExpanded] = useState(false)
  const [report, setReport] = useState<PlannerReport | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(false)
  const [chosen, setChosen] = useState<string[]>([])

  useEffect(() => {
    let cancelled = false
    setReport(null)
    setError(false)
    setChosen([])
    if (!expanded || !isPremium || checkingPremium || clockLoading || !playerId) {
      setLoading(false)
      return () => { cancelled = true }
    }
    setLoading(true)
    void supabase.rpc('get_premium_tournament_planning_v1', {
      p_player_id: playerId,
      p_season: season,
      p_month: month,
    }).then(({ data, error: rpcError }) => {
      if (cancelled) return
      const incoming = data as PlannerReport | null
      if (rpcError || !incoming || incoming.player_id !== playerId
        || incoming.month !== month || incoming.season !== season
        || !Array.isArray(incoming.tournaments)) {
        setError(true)
      } else {
        setReport(incoming)
        setChosen(incoming.tournaments.filter(item => !isCancelled(item))
          .slice(0, visibleChoices).map(item => item.competition_id))
      }
      setLoading(false)
    }).catch(() => {
      if (!cancelled) { setError(true); setLoading(false) }
    })
    return () => { cancelled = true }
  }, [expanded, isPremium, checkingPremium, clockLoading, playerId, season, month])

  const available = report?.tournaments ?? []
  const selected = chosen.map(id => available.find(item => item.competition_id === id) ?? null)
  const displayColumns = Array.from({ length: visibleChoices }, (_, index) => selected[index] ?? null)
  const money = (value: number | null) => value === null ? '—'
    : new Intl.NumberFormat(i18n.language || 'en', { style: 'currency', currency: 'USD',
      maximumFractionDigits: 0 }).format(value)
  const points = (value: number | null) => value === null ? '—' : value.toLocaleString()
  const weekText = (t: Tournament) => t.season_week_start === t.season_week_end
    ? String(t.season_week_start) : `${t.season_week_start}–${t.season_week_end}`
  const advisory = (t: Tournament) => {
    switch (t.planning_advisory) {
      case 'canceled': return l.canceled
      case 'entered': return l.entered
      case 'health_review': return l.healthReview
      case 'accepted_conflict': return l.acceptedConflict
      case 'pending_conflict': return l.pendingConflict
      case 'pending': return l.pending
      case 'application_window_open': return l.open
      default: return l.verify
    }
  }
  const conflict = (t: Tournament) => t.accepted_overlap ? l.acceptedConflict
    : t.pending_overlap ? l.pendingConflict : l.noConflict

  function changeChoice(index: number, next: string) {
    setChosen(current => {
      const updated = [...current]
      updated[index] = next
      return updated
    })
  }
  const metricRows: Array<{ label: string; show: (t: Tournament) => string }> = [
    { label: l.week, show: weekText },
    { label: l.category, show: t => t.category_label },
    { label: l.surface, show: t => t.surface },
    { label: l.winnerPts, show: t => points(t.winner_points) },
    { label: l.finalistPts, show: t => points(t.finalist_points) },
    { label: l.prizePool, show: t => money(t.prize_pool_usd) },
    { label: l.winnerPrize, show: t => money(t.winner_prize_usd) },
    { label: l.finalistPrize, show: t => money(t.finalist_prize_usd) },
    { label: l.slots, show: t => String(t.main_draw_capacity) },
    { label: l.qualification, show: t => String(t.qualifying_capacity_max) },
    { label: l.currentEntry, show: row => t(`calendarPage.tournament.userStatus.${row.user_status}`, { defaultValue: row.user_status.replaceAll('_',' ') }) },
    { label: l.health, show: t => t.health_blocked ? l.healthReview : l.healthClear },
    { label: l.status, show: advisory },
    { label: l.risks, show: conflict },
    { label: l.otherChoices, show: t => String(t.other_calendar_choices) },
  ]

  return (
    <section className="tlg-plan" aria-label={l.title}>
      <header className="tlg-plan-header">
        <div>
          <span className="tlg-plan-kicker"><Crown size={15} aria-hidden="true" /> {l.kicker}</span>
          <h3>{l.title}</h3>
          <p>{l.intro}</p>
        </div>
        <button type="button" className="tlg-plan-toggle"
          aria-expanded={expanded} aria-controls="tlg-plan-content"
          onClick={() => setExpanded(value => !value)}>
          {expanded ? l.hide : l.show}
          {expanded ? <ChevronUp size={16} aria-hidden="true" /> : <ChevronDown size={16} aria-hidden="true" />}
        </button>
      </header>
      <div id="tlg-plan-content" hidden={!expanded}>
        {expanded && (checkingPremium || clockLoading || loading
          ? <p className="tlg-plan-state">{l.loading}</p>
          : !isPremium
            ? <div className="tlg-plan-locked">
              <LockKeyhole size={20} aria-hidden="true" />
              <p>{l.locked}</p>
              <Link to="/game/pro-packages">{l.viewPlans}</Link>
            </div>
            : error ? <p className="tlg-plan-state" role="alert">{l.error}</p>
            : available.length === 0 ? <p className="tlg-plan-state">{l.none}</p>
            : <div className="tlg-plan-body">
              <div className="tlg-plan-subhead">
                <strong><Scale size={17} aria-hidden="true" /> {l.compare}</strong>
                <p>{l.chooseComparison}</p>
              </div>
              <div className="tlg-plan-scroll">
                <table className="tlg-plan-comparison">
                  <thead>
                    <tr>
                      <th scope="col">{l.compare}</th>
                      {displayColumns.map((entry,index) => (
                        <th scope="col" key={index}>
                          <label htmlFor={`tlg-plan-choice-${index}`}>{l.choose} {index+1}</label>
                          <select id={`tlg-plan-choice-${index}`}
                            value={chosen[index] ?? ''}
                            onChange={event => changeChoice(index,event.target.value)}>
                            <option value="">—</option>
                            {available.filter(option => !isCancelled(option)).map(option => (
                              <option key={option.competition_id} value={option.competition_id}
                                disabled={chosen.some((id,i)=>i!==index && id===option.competition_id)}>
                                {option.tournament_name} · {l.week} {weekText(option)}
                              </option>
                            ))}
                          </select>
                          {entry && <Link className="tlg-plan-tournament-link"
                            to={`/game/tournaments/${entry.competition_id}`}>
                            {entry.tournament_name} <ExternalLink size={12} aria-hidden="true" />
                          </Link>}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {metricRows.map(row=>(
                      <tr key={row.label}>
                        <th scope="row">{row.label}</th>
                        {displayColumns.map((item,index)=>(
                          <td key={index}>{item?row.show(item):'—'}</td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <p className="tlg-plan-note">{l.note}</p>
            </div>
        )}
      </div>
    </section>
  )
}
