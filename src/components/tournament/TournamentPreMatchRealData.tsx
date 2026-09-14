import { createPortal } from 'react-dom'
import { useEffect, useMemo, useState } from 'react'
import { useParams } from 'react-router'

import CountryFlag from '../common/CountryFlag'
import { supabase } from '../../lib/supabase'
import '../../styles/tournament-prematch-real-data.css'

type DrawType = 'main_draw' | 'qualification'
type MatchStatus = 'scheduled' | 'in_progress' | 'bye' | 'completed' | 'walkover' | 'cancelled'

interface DrawMatch {
  match_id: string
  draw_type: DrawType
  round_number: number
  round_label: string
  match_number: number
  match_status: MatchStatus
  player1_id: string | null
  player1_first_name: string | null
  player1_last_name: string | null
  player1_country_code: string | null
  player1_set_scores: number[]
  player2_id: string | null
  player2_first_name: string | null
  player2_last_name: string | null
  player2_country_code: string | null
  player2_set_scores: number[]
  winner_id: string | null
}

interface HeadToHeadSet {
  set_number: number
  player1_games: number
  player2_games: number
  player1_tiebreak_points: number | null
  player2_tiebreak_points: number | null
}

interface HeadToHeadMeeting {
  match_id: string
  competition_id: string
  season_number: number
  tournament_name: string
  round_label: string
  winner_id: string
  player1_id: string
  player2_id: string
  completed_at: string | null
  sets: HeadToHeadSet[]
}

interface HeadToHeadData {
  player1_wins: number
  player2_wins: number
  meeting_count: number
  meetings: HeadToHeadMeeting[]
}

interface RoundKey {
  draw_type: DrawType
  round_number: number
  round_label: string
}

function fullName(first: string | null, last: string | null) {
  return `${first ?? ''} ${last ?? ''}`.trim() || 'Player'
}

function roundShort(label: string) {
  const roundOf = label.match(/Round of\s+(\d+)/i)
  if (roundOf) return `R${roundOf[1]}`
  if (/quarterfinal/i.test(label)) return 'QF'
  if (/semifinal/i.test(label)) return 'SF'
  if (/^final$/i.test(label)) return 'F'
  if (/final qualifying/i.test(label)) return 'FQ'
  const qualifying = label.match(/Qualifying Round\s+(\d+)/i)
  if (qualifying) return `Q${qualifying[1]}`
  return label.length <= 5 ? label : label.slice(0, 5).toUpperCase()
}

function roundOrder(drawType: DrawType, roundNumber: number) {
  return (drawType === 'qualification' ? 0 : 100) + roundNumber
}

function matchInRound(matches: DrawMatch[], playerId: string | null, round: RoundKey) {
  if (!playerId) return null
  return matches.find((match) =>
    match.draw_type === round.draw_type
    && match.round_number === round.round_number
    && (match.player1_id === playerId || match.player2_id === playerId)
    && ['completed', 'walkover', 'bye'].includes(match.match_status)
  ) ?? null
}

function resultForPlayer(match: DrawMatch, playerId: string) {
  if (match.match_status === 'bye') return 'BYE'
  if (match.match_status === 'walkover') return 'W/O'
  const playerIsOne = match.player1_id === playerId
  const own = playerIsOne ? match.player1_set_scores : match.player2_set_scores
  const opponent = playerIsOne ? match.player2_set_scores : match.player1_set_scores
  if (own.length > 0 && own.length === opponent.length) {
    return own.map((games, index) => `${games}–${opponent[index]}`).join('  ')
  }
  return match.winner_id === playerId ? 'W' : 'L'
}

function opponentForPlayer(match: DrawMatch, playerId: string) {
  const playerIsOne = match.player1_id === playerId
  const opponentId = playerIsOne ? match.player2_id : match.player1_id
  if (!opponentId) return null
  return {
    id: opponentId,
    first_name: playerIsOne ? match.player2_first_name : match.player1_first_name,
    last_name: playerIsOne ? match.player2_last_name : match.player1_last_name,
    country_code: playerIsOne ? match.player2_country_code : match.player1_country_code,
  }
}

function RoadSide({ match, playerId, align }: { match: DrawMatch | null; playerId: string | null; align: 'left' | 'right' }) {
  if (!match || !playerId) return <div className={`tlg-real-road-side ${align} empty`}>—</div>
  const opponent = opponentForPlayer(match, playerId)
  if (!opponent) {
    return <div className={`tlg-real-road-side ${align}`}><span className="tlg-real-road-bye">BYE</span><strong>{resultForPlayer(match, playerId)}</strong></div>
  }
  return (
    <div className={`tlg-real-road-side ${align}`}>
      <span className="tlg-real-road-opponent">
        <CountryFlag countryCode={opponent.country_code ?? ''} countryName={opponent.country_code ?? ''} width={20} height={14} />
        <b>{fullName(opponent.first_name, opponent.last_name)}</b>
      </span>
      <strong>{resultForPlayer(match, playerId)}</strong>
    </div>
  )
}

function meetingScore(meeting: HeadToHeadMeeting) {
  if (!meeting.sets?.length) return 'Result recorded'
  const winnerWasOne = meeting.winner_id === meeting.player1_id
  return meeting.sets
    .map((set) => winnerWasOne
      ? `${set.player1_games}–${set.player2_games}`
      : `${set.player2_games}–${set.player1_games}`)
    .join(', ')
}

function parseModalMatch(modal: HTMLElement, matches: DrawMatch[]) {
  const text = modal.querySelector<HTMLElement>('.tlg-match-modal-head h2')?.textContent?.trim() ?? ''
  const marker = ' · Match '
  const markerIndex = text.lastIndexOf(marker)
  if (markerIndex < 0) return null
  const roundLabel = text.slice(0, markerIndex).trim()
  const matchNumber = Number.parseInt(text.slice(markerIndex + marker.length).trim(), 10)
  if (!Number.isInteger(matchNumber)) return null
  return matches.find((match) => match.round_label === roundLabel && match.match_number === matchNumber) ?? null
}

export default function TournamentPreMatchRealData() {
  const { competitionId } = useParams()
  const [matches, setMatches] = useState<DrawMatch[]>([])
  const [host, setHost] = useState<HTMLElement | null>(null)
  const [selected, setSelected] = useState<DrawMatch | null>(null)
  const [h2h, setH2h] = useState<HeadToHeadData | null>(null)
  const [h2hLoading, setH2hLoading] = useState(false)

  useEffect(() => {
    if (!competitionId) {
      setMatches([])
      return
    }
    let cancelled = false
    async function loadDraw() {
      const { data, error } = await supabase.rpc('get_tournament_draw_v1', { p_competition_id: competitionId })
      if (!cancelled) setMatches(error ? [] : ((data ?? []) as DrawMatch[]))
    }
    void loadDraw()
    return () => { cancelled = true }
  }, [competitionId])

  useEffect(() => {
    let frame = 0
    let disposed = false
    let currentOriginal: HTMLElement | null = null
    let currentHost: HTMLElement | null = null

    const locate = () => {
      if (disposed) return
      const modal = document.querySelector<HTMLElement>('.tlg-match-modal')
      const original = modal?.querySelector<HTMLElement>('.tlg-prematch-insights') ?? null
      if (!modal || !original || matches.length === 0) {
        if (currentOriginal) currentOriginal.classList.remove('tlg-prematch-insights-replaced')
        currentHost?.remove()
        currentOriginal = null
        currentHost = null
        setHost(null)
        setSelected(null)
        return
      }

      const nextSelected = parseModalMatch(modal, matches)
      if (!nextSelected) return

      if (currentOriginal !== original) {
        if (currentOriginal) currentOriginal.classList.remove('tlg-prematch-insights-replaced')
        currentHost?.remove()
        currentOriginal = original
        original.classList.add('tlg-prematch-insights-replaced')
        currentHost = document.createElement('div')
        currentHost.dataset.tlgRealPrematchHost = 'true'
        original.insertAdjacentElement('beforebegin', currentHost)
      }

      setHost((value) => value === currentHost ? value : currentHost)
      setSelected((value) => value?.match_id === nextSelected.match_id ? value : nextSelected)
    }

    frame = window.requestAnimationFrame(locate)
    const observer = new MutationObserver(locate)
    observer.observe(document.body, { childList: true, subtree: true })

    return () => {
      disposed = true
      window.cancelAnimationFrame(frame)
      observer.disconnect()
      currentOriginal?.classList.remove('tlg-prematch-insights-replaced')
      currentHost?.remove()
      setHost(null)
      setSelected(null)
    }
  }, [matches])

  useEffect(() => {
    const p1 = selected?.player1_id
    const p2 = selected?.player2_id
    if (!p1 || !p2) {
      setH2h(null)
      setH2hLoading(false)
      return
    }
    let cancelled = false
    setH2hLoading(true)
    async function loadHeadToHead() {
      const { data, error } = await supabase.rpc('get_player_head_to_head_v1', {
        p_player1_id: p1,
        p_player2_id: p2,
      })
      if (cancelled) return
      setH2h(error ? null : (data as HeadToHeadData))
      setH2hLoading(false)
    }
    void loadHeadToHead()
    return () => { cancelled = true }
  }, [selected?.match_id, selected?.player1_id, selected?.player2_id])

  const roadRounds = useMemo(() => {
    if (!selected) return [] as Array<{ round: RoundKey; left: DrawMatch | null; right: DrawMatch | null }>
    const currentOrder = roundOrder(selected.draw_type, selected.round_number)
    const roundMap = new Map<string, RoundKey>()
    for (const match of matches) {
      const order = roundOrder(match.draw_type, match.round_number)
      if (order >= currentOrder) continue
      const key = `${match.draw_type}:${match.round_number}`
      if (!roundMap.has(key)) roundMap.set(key, { draw_type: match.draw_type, round_number: match.round_number, round_label: match.round_label })
    }
    return [...roundMap.values()]
      .sort((a, b) => roundOrder(a.draw_type, a.round_number) - roundOrder(b.draw_type, b.round_number))
      .map((round) => ({
        round,
        left: matchInRound(matches, selected.player1_id, round),
        right: matchInRound(matches, selected.player2_id, round),
      }))
      .filter((row) => row.left || row.right)
  }, [matches, selected])

  if (!host || !selected) return null

  const p1Name = fullName(selected.player1_first_name, selected.player1_last_name)
  const p2Name = fullName(selected.player2_first_name, selected.player2_last_name)
  const playerNameById = (id: string) => id === selected.player1_id ? p1Name : p2Name

  return createPortal(
    <section className="tlg-real-prematch-insights">
      <div className="tlg-real-prematch-panel road-panel">
        <header><div><span>This tournament</span><h3>Road to this match</h3></div></header>
        <div className="tlg-real-road-head">
          <div><CountryFlag countryCode={selected.player1_country_code ?? ''} countryName={selected.player1_country_code ?? ''} width={21} height={14} /><strong>{p1Name}</strong></div>
          <span>ROUND</span>
          <div><strong>{p2Name}</strong><CountryFlag countryCode={selected.player2_country_code ?? ''} countryName={selected.player2_country_code ?? ''} width={21} height={14} /></div>
        </div>
        {roadRounds.length === 0 ? (
          <div className="tlg-real-road-empty">No previous-round matches at this tournament.</div>
        ) : (
          <div className="tlg-real-road-list">
            {roadRounds.map(({ round, left, right }) => (
              <div className="tlg-real-road-row" key={`${round.draw_type}:${round.round_number}`}>
                <RoadSide match={left} playerId={selected.player1_id} align="left" />
                <span className="tlg-real-road-round" title={round.round_label}>{roundShort(round.round_label)}</span>
                <RoadSide match={right} playerId={selected.player2_id} align="right" />
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="tlg-real-prematch-panel h2h-panel">
        <header><div><span>Head to head</span><h3>Previous meetings</h3></div></header>
        {h2hLoading ? (
          <div className="tlg-real-h2h-empty">Loading real match history…</div>
        ) : !h2h || h2h.meeting_count === 0 ? (
          <div className="tlg-real-h2h-empty"><strong>No previous meetings</strong><span>These players have no completed match against each other in the game database.</span></div>
        ) : (
          <div className="tlg-real-h2h-wrap">
            <div className="tlg-real-h2h-score">
              <div><CountryFlag countryCode={selected.player1_country_code ?? ''} countryName={selected.player1_country_code ?? ''} width={21} height={14} /><strong>{p1Name}</strong><b>{h2h.player1_wins}</b></div>
              <span>H2H</span>
              <div><b>{h2h.player2_wins}</b><strong>{p2Name}</strong><CountryFlag countryCode={selected.player2_country_code ?? ''} countryName={selected.player2_country_code ?? ''} width={21} height={14} /></div>
            </div>
            <div className="tlg-real-h2h-list">
              {h2h.meetings.map((meeting) => {
                const loserId = meeting.winner_id === meeting.player1_id ? meeting.player2_id : meeting.player1_id
                return (
                  <div key={meeting.match_id}>
                    <span>Season {meeting.season_number} · {meeting.tournament_name} · {roundShort(meeting.round_label)}</span>
                    <strong>{playerNameById(meeting.winner_id)} def. {playerNameById(loserId)}</strong>
                    <b>{meetingScore(meeting)}</b>
                  </div>
                )
              })}
            </div>
          </div>
        )}
      </div>
    </section>,
    host,
  )
}
