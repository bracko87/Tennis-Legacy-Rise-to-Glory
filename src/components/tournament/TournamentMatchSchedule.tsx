import { createPortal } from 'react-dom'
import { useEffect, useMemo, useState } from 'react'
import { useParams } from 'react-router'

import { supabase } from '../../lib/supabase'
import TournamentMatchReplayModal from './TournamentMatchReplayModal'
import '../../styles/tournament-match-schedule.css'

type ScheduleReason = 'standard' | 'travel_accommodation' | 'travel_risk'

interface ScheduledDrawMatch {
  match_id: string
  draw_type: 'main_draw' | 'qualification'
  round_number: number
  round_label: string
  match_number: number
  scheduled_season_week: number
  scheduled_day: number
  scheduled_start_minute: number | null
  court_number: number | null
  schedule_reason: ScheduleReason
  match_status: string
  player1_first_name: string | null
  player1_last_name: string | null
  player2_first_name: string | null
  player2_last_name: string | null
}

function timeLabel(value: number | null) {
  if (value == null) return 'TBD'
  const hour = Math.floor(value / 60)
  const minute = value % 60
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`
}

function playerLabel(first: string | null, last: string | null) {
  return `${first ?? ''} ${last ?? ''}`.trim() || 'TBD'
}

function dayKey(match: ScheduledDrawMatch) {
  return `${match.scheduled_season_week}:${match.scheduled_day}`
}

function replayActionLabel(status: string) {
  if (status === 'in_progress') return 'Watch Live'
  if (status === 'completed') return 'Replay'
  return 'View'
}

export default function TournamentMatchSchedule() {
  const { competitionId } = useParams()
  const [target, setTarget] = useState<HTMLElement | null>(null)
  const [matches, setMatches] = useState<ScheduledDrawMatch[]>([])
  const [selectedDay, setSelectedDay] = useState<string>('')
  const [replayMatchId, setReplayMatchId] = useState<string | null>(null)

  useEffect(() => {
    let frame = 0
    let cancelled = false
    const findTarget = () => {
      if (cancelled) return
      const next = document.querySelector<HTMLElement>('.tlg-detail-page')
      if (next) {
        setTarget(next)
        return
      }
      frame = window.requestAnimationFrame(findTarget)
    }
    frame = window.requestAnimationFrame(findTarget)
    return () => {
      cancelled = true
      window.cancelAnimationFrame(frame)
      setTarget(null)
    }
  }, [competitionId])

  useEffect(() => {
    if (!competitionId) return
    let cancelled = false

    const load = async () => {
      const { data, error } = await supabase.rpc('get_tournament_draw_v1', { p_competition_id: competitionId })
      if (cancelled || error) return
      const rows = (data ?? []) as ScheduledDrawMatch[]
      setMatches(rows)
      const keys = Array.from(new Set(rows.map(dayKey)))
      setSelectedDay((current) => current && keys.includes(current) ? current : (keys[0] ?? ''))
    }

    void load()
    const channel = supabase.channel(`tournament-schedule-${competitionId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_matches', filter: `competition_id=eq.${competitionId}` }, () => void load())
      .subscribe()

    return () => {
      cancelled = true
      void supabase.removeChannel(channel)
    }
  }, [competitionId])

  const days = useMemo(() => {
    const byKey = new Map<string, { key: string; week: number; day: number; count: number }>()
    for (const match of matches) {
      const key = dayKey(match)
      const current = byKey.get(key)
      if (current) current.count += 1
      else byKey.set(key, { key, week: match.scheduled_season_week, day: match.scheduled_day, count: 1 })
    }
    return Array.from(byKey.values()).sort((a, b) => a.week - b.week || a.day - b.day)
  }, [matches])

  const visible = useMemo(() => matches
    .filter((match) => dayKey(match) === selectedDay)
    .sort((a, b) => (a.scheduled_start_minute ?? 9999) - (b.scheduled_start_minute ?? 9999) || (a.court_number ?? 99) - (b.court_number ?? 99) || a.match_number - b.match_number), [matches, selectedDay])

  if (!target || matches.length === 0) return replayMatchId ? <TournamentMatchReplayModal matchId={replayMatchId} onClose={() => setReplayMatchId(null)} /> : null

  const selected = days.find((day) => day.key === selectedDay)

  return (
    <>
      {createPortal(
        <section className="tlg-detail-panel tlg-match-schedule-panel">
          <header className="tlg-detail-panel-head tlg-match-schedule-head">
            <div>
              <span>Match schedule</span>
              <h2>Order of play</h2>
              <p>All times are tournament local. Several matches may run simultaneously on different courts.</p>
            </div>
            <div className="tlg-match-schedule-day-tabs" aria-label="Tournament schedule day">
              {days.map((day) => (
                <button key={day.key} type="button" className={selectedDay === day.key ? 'active' : ''} onClick={() => setSelectedDay(day.key)}>
                  <span>W{day.week}</span><strong>Day {day.day}</strong><small>{day.count} matches</small>
                </button>
              ))}
            </div>
          </header>

          <div className="tlg-match-schedule-summary">
            <strong>{selected ? `Season Week ${selected.week} · Day ${selected.day}` : 'Tournament day'}</strong>
            <span>{visible.length} scheduled {visible.length === 1 ? 'match' : 'matches'}</span>
          </div>

          <div className="tlg-match-schedule-table-wrap">
            <div className="tlg-match-schedule-table">
              <div className="tlg-match-schedule-row head"><span>Time</span><span>Court</span><span>Draw</span><span>Round</span><span>Match</span><span>Players</span><span>Note</span><span>Replay</span></div>
              {visible.map((match) => {
                const p1 = playerLabel(match.player1_first_name, match.player1_last_name)
                const p2 = playerLabel(match.player2_first_name, match.player2_last_name)
                const note = match.schedule_reason === 'travel_accommodation' ? 'Travel-adjusted start' : match.schedule_reason === 'travel_risk' ? 'Travel connection at risk' : 'Standard schedule'
                return (
                  <div key={match.match_id} className={`tlg-match-schedule-row ${match.schedule_reason} status-${match.match_status}`}>
                    <strong>{timeLabel(match.scheduled_start_minute)}</strong>
                    <span>{match.court_number ? `Court ${match.court_number}` : 'TBD'}</span>
                    <span>{match.draw_type === 'qualification' ? 'Qualifying' : 'Main Draw'}</span>
                    <span>{match.round_label}</span>
                    <span>#{match.match_number}</span>
                    <span className="players">{p1} <b>vs</b> {p2}</span>
                    <span className="note">{note}</span>
                    <button type="button" className={`replay-action ${match.match_status}`} onClick={() => setReplayMatchId(match.match_id)}>{replayActionLabel(match.match_status)}</button>
                  </div>
                )
              })}
            </div>
          </div>
        </section>,
        target,
      )}
      {replayMatchId && <TournamentMatchReplayModal matchId={replayMatchId} onClose={() => setReplayMatchId(null)} />}
    </>
  )
}
