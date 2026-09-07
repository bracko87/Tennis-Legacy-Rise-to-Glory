import {
  ArrowLeft,
  CalendarDays,
  CheckCircle2,
  CircleDollarSign,
  Clock3,
  MapPin,
  Trophy,
  UserPlus,
  Users,
  XCircle,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useLocation, useParams, useSearchParams } from 'react-router'

import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import { useGameClock } from '../../hooks/useGameClock'
import { supabase } from '../../lib/supabase'
import '../../styles/tournament-detail.css'
import '../../styles/tournament-detail-schedule.css'
import '../../styles/tournament-detail-v2.css'

const MONTHS = [
  { name: 'January', days: 31 },
  { name: 'February', days: 29 },
  { name: 'March', days: 31 },
  { name: 'April', days: 30 },
  { name: 'May', days: 31 },
  { name: 'June', days: 30 },
  { name: 'July', days: 31 },
  { name: 'August', days: 31 },
  { name: 'September', days: 30 },
  { name: 'October', days: 31 },
  { name: 'November', days: 30 },
  { name: 'December', days: 31 },
] as const

const MONTH_STARTS = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335] as const
const DAYS_PER_SEASON = 366

const SURFACE_IMAGES: Record<'hard' | 'clay' | 'grass', string> = {
  hard: 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Branding/hard.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9CcmFuZGluZy9oYXJkLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgxODM3MTgsImV4cCI6NDkxMDI0NzcxOH0.A8nFMfrv24zncDCqjuE5PihskAwMLdak04-Qz64_2ksvFiHfzDpunlMMdcGqy9IDh-qPQCfoFe5HP0Hu9pcfow',
  grass: 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Branding/grass.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9CcmFuZGluZy9ncmFzcy5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg4MTgzNzM2LCJleHAiOjQ5MTAyNDc3MzZ9.wENm_84C6GKo4fyTBxTsJ04OiNa8SZwLrEIxACdxJQN5D8EQDd6WhiRVDUbM5pwqQPgrovW009ULGRV92alrOQ',
  clay: 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Branding/clay.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9CcmFuZGluZy9jbGF5LnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgxODM3NTUsImV4cCI6NDkxMDI0Nzc1NX0.8AJ27KTGHBvo0Sf4xnNqHv8KXY9Sh2lVo7Fi1mbjtPY_Wi7_hqAVkFkC8GfiYbhN5mS3d4QI03HWyQ5wT9PVpA',
}

const BRACKET_MATCH_WIDTH = 210
const BRACKET_MATCH_HEIGHT = 62
const BRACKET_COLUMN_GAP = 72
const BRACKET_FIRST_ROUND_GAP = 12
const BRACKET_STEP = BRACKET_MATCH_HEIGHT + BRACKET_FIRST_ROUND_GAP

interface TournamentScheduleSlot {
  calendar_month: number
  month_week: number
  phase: 'full' | 'qualification' | 'main_draw'
  slot_order: number
}

interface TournamentDetailRow {
  competition_id: string
  tournament_id: string
  edition_id: string
  world: 'ATP' | 'WTA'
  competition_status: string
  season_number: number
  tournament_name: string
  city: string
  country_code: string
  country_name: string
  category_code: string
  category_label: string
  winner_points: number
  main_draw_capacity: number
  qualifying_capacity_max: number
  default_qualifier_slots: number
  competition_weeks: number
  qualification_rounds_max: number
  main_draw_rounds: number
  qualification_rest_day_first: boolean
  main_draw_rest_day_first: boolean
  one_match_per_player_per_day: boolean
  same_city_for_qualification: boolean
  surface: 'hard' | 'clay' | 'grass'
  environment: 'indoor' | 'outdoor'
  schedule_slots: TournamentScheduleSlot[]
}

interface TournamentApplicationState {
  applications_open: boolean
  tournament_started: boolean
  applicant_count: number
  other_applicant_count: number
  direct_entry_slots: number
  qualifying_capacity: number
  qualifier_slots: number
  projected_main_count: number
  projected_qualifying_count: number
  projected_waiting_count: number
  user_applied: boolean
  user_projection: 'main_draw' | 'qualification' | 'waiting_list' | null
  if_apply_projection: 'main_draw' | 'qualification' | 'waiting_list' | null
  projection_basis: 'ranking_snapshot' | 'capacity_order'
}

interface BracketRound {
  label: string
  matches: number
}

interface TournamentDayPlan {
  day: number
  date: string
  activity: string
  kind: 'rest' | 'qualification' | 'main' | 'preparation'
}

type DrawView = 'main' | 'qualification'

function titleCase(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1)
}

function parseIntegerParam(value: string | null, minimum: number, maximum: number) {
  if (!value) return null
  const parsed = Number.parseInt(value, 10)
  return Number.isInteger(parsed) && parsed >= minimum && parsed <= maximum ? parsed : null
}

function phaseLabel(phase: TournamentScheduleSlot['phase']) {
  if (phase === 'qualification') return 'Qualification'
  if (phase === 'main_draw') return 'Main Draw'
  return 'Tournament Week'
}

function weekStartDay(monthWeek: number) {
  if (monthWeek === 1) return 1
  if (monthWeek === 2) return 8
  if (monthWeek === 3) return 15
  return 22
}

function weekWindow(slot: TournamentScheduleSlot) {
  const month = MONTHS[slot.calendar_month - 1]
  if (!month) return `Month ${slot.calendar_month} · Week ${slot.month_week}`
  const start = weekStartDay(slot.month_week)
  return `${month.name} ${start}–${start + 6}`
}

function formatCompetitionDate(calendarMonth: number, monthWeek: number, competitionDay: number) {
  let monthIndex = calendarMonth - 1
  let day = weekStartDay(monthWeek) + competitionDay - 1

  while (monthIndex < MONTHS.length && day > MONTHS[monthIndex].days) {
    day -= MONTHS[monthIndex].days
    monthIndex += 1
  }

  if (monthIndex >= MONTHS.length) monthIndex = 0
  return `${MONTHS[monthIndex].name} ${day}`
}

function absoluteGameDay(season: number, monthIndex: number, day: number) {
  return (season - 1) * DAYS_PER_SEASON + MONTH_STARTS[monthIndex] + day - 1
}

function slotAbsoluteStart(season: number, slot: TournamentScheduleSlot) {
  return absoluteGameDay(season, slot.calendar_month - 1, weekStartDay(slot.month_week))
}

function mainDrawRounds(capacity: number): BracketRound[] {
  const rounds: BracketRound[] = []
  let participants = capacity

  while (participants >= 2) {
    const label = participants === 2
      ? 'Final'
      : participants === 4
        ? 'Semifinal'
        : participants === 8
          ? 'Quarterfinal'
          : `Round of ${participants}`

    rounds.push({ label, matches: participants / 2 })
    participants /= 2
  }

  return rounds
}

function qualificationRounds(capacity: number, qualifierSlots: number): BracketRound[] {
  if (capacity <= 0 || qualifierSlots <= 0 || capacity <= qualifierSlots) return []

  const raw: BracketRound[] = []
  let participants = capacity

  while (participants > qualifierSlots) {
    raw.push({ label: '', matches: participants / 2 })
    participants /= 2
  }

  return raw.map((round, index) => ({
    ...round,
    label: index === raw.length - 1 ? 'Final Qualifying Round' : `Qualifying Round ${index + 1}`,
  }))
}

function buildTournamentDayPlan(detail: TournamentDetailRow, slot: TournamentScheduleSlot): TournamentDayPlan[] {
  const qualificationLabels = qualificationRounds(
    detail.qualifying_capacity_max,
    detail.default_qualifier_slots,
  ).map((round) => round.label)
  const mainLabels = mainDrawRounds(detail.main_draw_capacity).map((round) => round.label)
  const activities: Array<{ activity: string; kind: TournamentDayPlan['kind'] }> = []

  if (slot.phase === 'qualification') {
    if (detail.qualification_rest_day_first && qualificationLabels.length < 7) {
      activities.push({ activity: 'Arrival / Rest', kind: 'rest' })
    }
    activities.push(...qualificationLabels.map((activity) => ({ activity, kind: 'qualification' as const })))
    while (activities.length < 7) activities.push({ activity: 'Recovery / Preparation', kind: 'preparation' })
  } else if (slot.phase === 'main_draw') {
    if (detail.main_draw_rest_day_first && mainLabels.length < 7) {
      activities.push({ activity: 'Arrival / Rest', kind: 'rest' })
    }
    activities.push(...mainLabels.map((activity) => ({ activity, kind: 'main' as const })))
    while (activities.length < 7) activities.push({ activity: 'Recovery / Preparation', kind: 'preparation' })
  } else {
    const combinedMatchDays = [...qualificationLabels, ...mainLabels]
    const canUseFirstRestDay = combinedMatchDays.length < 7
      && (detail.qualification_rest_day_first || detail.main_draw_rest_day_first)

    if (canUseFirstRestDay) activities.push({ activity: 'Arrival / Rest', kind: 'rest' })
    activities.push(...qualificationLabels.map((activity) => ({ activity, kind: 'qualification' as const })))
    activities.push(...mainLabels.map((activity) => ({ activity, kind: 'main' as const })))
    while (activities.length < 7) activities.push({ activity: 'Recovery / Preparation', kind: 'preparation' })
  }

  return activities.slice(0, 7).map((item, index) => ({
    day: index + 1,
    date: formatCompetitionDate(slot.calendar_month, slot.month_week, index + 1),
    activity: item.activity,
    kind: item.kind,
  }))
}

function bracketMatchCenter(roundIndex: number, matchIndex: number) {
  const firstRoundMatchSpan = 2 ** roundIndex
  const representedFirstMatchCenter = matchIndex * firstRoundMatchSpan + (firstRoundMatchSpan - 1) / 2
  return BRACKET_MATCH_HEIGHT / 2 + representedFirstMatchCenter * BRACKET_STEP
}

function TournamentBracket({ rounds, emptyMessage }: { rounds: BracketRound[]; emptyMessage: string }) {
  if (rounds.length === 0) return <div className="tlg-detail-bracket-empty">{emptyMessage}</div>

  const width = rounds.length * BRACKET_MATCH_WIDTH + (rounds.length - 1) * BRACKET_COLUMN_GAP
  const height = Math.max(
    BRACKET_MATCH_HEIGHT,
    (rounds[0].matches - 1) * BRACKET_STEP + BRACKET_MATCH_HEIGHT,
  )

  return (
    <div className="tlg-detail-bracket-scroll">
      <div className="tlg-detail-bracket-headings" style={{ width }}>
        {rounds.map((round, roundIndex) => (
          <header
            key={`${round.label}-${round.matches}`}
            style={{ left: roundIndex * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP) }}
          >
            <strong>{round.label}</strong>
            <span>{round.matches} {round.matches === 1 ? 'match' : 'matches'}</span>
          </header>
        ))}
      </div>

      <div className="tlg-detail-bracket-tree" style={{ width, height }}>
        <svg
          className="tlg-detail-bracket-connectors"
          width={width}
          height={height}
          viewBox={`0 0 ${width} ${height}`}
          aria-hidden="true"
        >
          {rounds.slice(0, -1).map((_, roundIndex) => {
            const boundaryX = (roundIndex + 1) * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP) - BRACKET_COLUMN_GAP / 2
            return (
              <line
                key={`round-separator-${roundIndex}`}
                x1={boundaryX}
                x2={boundaryX}
                y1={0}
                y2={height}
                stroke="#0b6fc8"
                strokeWidth="1.4"
                opacity="0.72"
                vectorEffect="non-scaling-stroke"
              />
            )
          })}

          {rounds.slice(0, -1).flatMap((_, roundIndex) => {
            const parentRound = rounds[roundIndex + 1]
            const startX = roundIndex * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP) + BRACKET_MATCH_WIDTH
            const middleX = startX + BRACKET_COLUMN_GAP / 2
            const endX = (roundIndex + 1) * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP)

            return Array.from({ length: parentRound.matches }, (_, parentIndex) => {
              const firstY = bracketMatchCenter(roundIndex, parentIndex * 2)
              const secondY = bracketMatchCenter(roundIndex, parentIndex * 2 + 1)
              const parentY = bracketMatchCenter(roundIndex + 1, parentIndex)

              return (
                <path
                  key={`connector-${roundIndex}-${parentIndex}`}
                  d={`M ${startX} ${firstY} H ${middleX} M ${startX} ${secondY} H ${middleX} M ${middleX} ${firstY} V ${secondY} M ${middleX} ${parentY} H ${endX}`}
                />
              )
            })
          })}
        </svg>

        {rounds.map((round, roundIndex) => (
          <section
            key={`${round.label}-${round.matches}`}
            className="tlg-detail-bracket-round"
            style={{ left: roundIndex * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP) }}
          >
            {Array.from({ length: round.matches }, (_, matchIndex) => {
              const top = bracketMatchCenter(roundIndex, matchIndex) - BRACKET_MATCH_HEIGHT / 2
              return (
                <div
                  key={`${round.label}-${matchIndex}`}
                  className="tlg-detail-bracket-match"
                  style={{ top }}
                >
                  <div><span>{matchIndex * 2 + 1}</span><strong>TBD</strong></div>
                  <div><span>{matchIndex * 2 + 2}</span><strong>TBD</strong></div>
                </div>
              )
            })}
          </section>
        ))}
      </div>
    </div>
  )
}

function tournamentInitials(name: string) {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 3)
    .map((word) => word[0]?.toUpperCase() ?? '')
    .join('')
}

function projectionLabel(value: TournamentApplicationState['if_apply_projection']) {
  if (value === 'main_draw') return 'Main Draw'
  if (value === 'qualification') return 'Qualification'
  if (value === 'waiting_list') return 'Waiting List'
  return 'Pending'
}

function rewardRows(mainDrawCapacity: number, winnerPoints: number) {
  const rows: Array<{ finish: string; points: string; prize: string }> = [
    { finish: 'Winner', points: String(winnerPoints), prize: 'To be assigned' },
    { finish: 'Finalist', points: 'To be assigned', prize: 'To be assigned' },
  ]

  if (mainDrawCapacity >= 4) rows.push({ finish: 'Semifinal', points: 'To be assigned', prize: 'To be assigned' })
  if (mainDrawCapacity >= 8) rows.push({ finish: 'Quarterfinal', points: 'To be assigned', prize: 'To be assigned' })
  if (mainDrawCapacity >= 16) rows.push({ finish: 'Round of 16', points: 'To be assigned', prize: 'To be assigned' })
  if (mainDrawCapacity >= 32) rows.push({ finish: 'Round of 32', points: 'To be assigned', prize: 'To be assigned' })
  if (mainDrawCapacity >= 64) rows.push({ finish: 'Round of 64', points: 'To be assigned', prize: 'To be assigned' })
  if (mainDrawCapacity >= 128) rows.push({ finish: 'Round of 128', points: 'To be assigned', prize: 'To be assigned' })
  rows.push({ finish: 'Qualification', points: 'To be assigned', prize: 'To be assigned' })
  return rows
}

export default function TournamentPageV2() {
  const { competitionId } = useParams()
  const location = useLocation()
  const [searchParams] = useSearchParams()
  const clock = useGameClock()
  const [detail, setDetail] = useState<TournamentDetailRow | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [drawView, setDrawView] = useState<DrawView>('main')
  const [applicationState, setApplicationState] = useState<TournamentApplicationState | null>(null)
  const [applicationLoading, setApplicationLoading] = useState(false)
  const [applicationActionLoading, setApplicationActionLoading] = useState(false)
  const [applicationError, setApplicationError] = useState<string | null>(null)

  const fromMonth = parseIntegerParam(searchParams.get('fromMonth'), 1, 12)
  const fromWeek = parseIntegerParam(searchParams.get('fromWeek'), 1, 4)
  const locationState = location.state as { tournamentCalendarReturn?: string } | null
  const backTarget = locationState?.tournamentCalendarReturn
    ?? (fromMonth && fromWeek
      ? `/game/calendar?tab=tournament-calendar&month=${fromMonth}&week=${fromWeek}#tournament-week-${fromWeek}`
      : '/game/calendar?tab=tournament-calendar')

  useEffect(() => {
    if (!competitionId) {
      setError('Tournament competition is missing.')
      setLoading(false)
      return
    }

    let cancelled = false

    async function loadTournament() {
      setLoading(true)
      setError(null)
      const { data, error: detailError } = await supabase.rpc('get_tournament_detail_v1', {
        p_competition_id: competitionId,
      })

      if (cancelled) return
      if (detailError) {
        setDetail(null)
        setError(detailError.message)
        setLoading(false)
        return
      }

      const row = (Array.isArray(data) ? data[0] : data) as TournamentDetailRow | null
      if (!row) {
        setDetail(null)
        setError('This tournament is unavailable for your competitive world.')
        setLoading(false)
        return
      }

      setDetail(row)
      setLoading(false)
    }

    void loadTournament()
    return () => { cancelled = true }
  }, [competitionId])

  const loadApplicationState = useCallback(async () => {
    if (!competitionId) return
    setApplicationLoading(true)
    setApplicationError(null)
    const { data, error: stateError } = await supabase.rpc('get_tournament_application_state_v1', {
      p_competition_id: competitionId,
    })

    if (stateError) {
      setApplicationState(null)
      setApplicationError(stateError.message)
      setApplicationLoading(false)
      return
    }

    const row = (Array.isArray(data) ? data[0] : data) as TournamentApplicationState | null
    setApplicationState(row)
    setApplicationLoading(false)
  }, [competitionId])

  useEffect(() => {
    if (detail) void loadApplicationState()
  }, [detail, loadApplicationState])

  const mainRounds = useMemo(
    () => mainDrawRounds(detail?.main_draw_capacity ?? 0),
    [detail?.main_draw_capacity],
  )
  const qualifierRounds = useMemo(
    () => qualificationRounds(detail?.qualifying_capacity_max ?? 0, detail?.default_qualifier_slots ?? 0),
    [detail?.default_qualifier_slots, detail?.qualifying_capacity_max],
  )
  const activeRounds = drawView === 'main' ? mainRounds : qualifierRounds

  const lifecycle = useMemo(() => {
    if (!detail || detail.schedule_slots.length === 0 || clock.loading) {
      return { started: false, finished: false, currentSlot: null as TournamentScheduleSlot | null, currentDay: null as number | null, suggestedDraw: 'main' as DrawView }
    }

    const current = absoluteGameDay(clock.season, clock.monthIndex, clock.day)
    const starts = detail.schedule_slots.map((slot) => slotAbsoluteStart(detail.season_number, slot))
    const tournamentStart = Math.min(...starts)
    const tournamentEnd = Math.max(...starts.map((value) => value + 6))
    const started = current >= tournamentStart
    const finished = current > tournamentEnd
    const currentSlot = detail.schedule_slots.find((slot) => {
      const start = slotAbsoluteStart(detail.season_number, slot)
      return current >= start && current <= start + 6
    }) ?? null

    let currentDay: number | null = null
    let suggestedDraw: DrawView = finished ? 'main' : 'main'

    if (currentSlot) {
      const slotStart = slotAbsoluteStart(detail.season_number, currentSlot)
      currentDay = current - slotStart + 1
      const plan = buildTournamentDayPlan(detail, currentSlot)
      const today = plan[currentDay - 1]

      if (currentSlot.phase === 'qualification') suggestedDraw = 'qualification'
      else if (currentSlot.phase === 'main_draw') suggestedDraw = 'main'
      else if (today?.kind === 'qualification') suggestedDraw = 'qualification'
      else if (today?.kind === 'main') suggestedDraw = 'main'
      else {
        const firstMainDay = plan.findIndex((item) => item.kind === 'main') + 1
        suggestedDraw = firstMainDay > 0 && currentDay < firstMainDay ? 'qualification' : 'main'
      }
    }

    return { started, finished, currentSlot, currentDay, suggestedDraw }
  }, [clock.day, clock.loading, clock.monthIndex, clock.season, detail])

  useEffect(() => {
    if (lifecycle.started) setDrawView(lifecycle.suggestedDraw)
  }, [lifecycle.started, lifecycle.suggestedDraw])

  async function applyForTournament() {
    if (!competitionId) return
    setApplicationActionLoading(true)
    setApplicationError(null)
    const { error: applyError } = await supabase.rpc('apply_to_tournament_v1', {
      p_competition_id: competitionId,
    })
    if (applyError) setApplicationError(applyError.message)
    else await loadApplicationState()
    setApplicationActionLoading(false)
  }

  async function withdrawApplication() {
    if (!competitionId) return
    setApplicationActionLoading(true)
    setApplicationError(null)
    const { error: withdrawError } = await supabase.rpc('withdraw_tournament_application_v1', {
      p_competition_id: competitionId,
    })
    if (withdrawError) setApplicationError(withdrawError.message)
    else await loadApplicationState()
    setApplicationActionLoading(false)
  }

  if (loading) {
    return (
      <GameLayout title="Tournament" subtitle="Loading tournament information">
        <div className="tlg-detail-loading">Loading tournament…</div>
      </GameLayout>
    )
  }

  if (!detail || error) {
    return (
      <GameLayout title="Tournament" subtitle="Tournament information">
        <div className="tlg-detail-error">
          <strong>Unable to open tournament</strong>
          <p>{error ?? 'Tournament data is unavailable.'}</p>
          <Link to={backTarget}>Back to Tournament Calendar</Link>
        </div>
      </GameLayout>
    )
  }

  const rewards = rewardRows(detail.main_draw_capacity, detail.winner_points)
  const effectiveApplicationProjection = applicationState?.user_applied
    ? applicationState.user_projection
    : applicationState?.if_apply_projection

  return (
    <GameLayout
      title={detail.tournament_name}
      subtitle={`${detail.world} · Season ${detail.season_number} · ${detail.category_label}`}
    >
      <div className="tlg-detail-page">
        <Link to={backTarget} className="tlg-detail-back-link">
          <ArrowLeft size={15} /> Back to Tournament Calendar
        </Link>

        <section className="tlg-detail-hero">
          <div className="tlg-detail-surface-card">
            <img
              src={SURFACE_IMAGES[detail.surface]}
              alt={`${titleCase(detail.surface)} tennis court surface`}
              className="tlg-detail-surface-image"
            />
            <div className="tlg-detail-surface-copy">
              <strong>{titleCase(detail.surface)}</strong>
              <span>{titleCase(detail.environment)} court</span>
            </div>
          </div>

          <div className="tlg-detail-hero-copy">
            <div className="tlg-detail-eyebrow">Season {detail.season_number} · {detail.world} singles</div>
            <h1>{detail.tournament_name}</h1>

            <div className="tlg-detail-location-line">
              <CountryFlag countryCode={detail.country_code} countryName={detail.country_name} width={24} height={16} />
              <div>
                <strong>{detail.city}, {detail.country_name}</strong>
                <span><MapPin size={13} /> Official tournament location</span>
              </div>
            </div>

            <p>
              A {detail.category_label} event played on {titleCase(detail.surface)} courts in {detail.city}. ATP and WTA use the same tournament location and calendar slot, while entries, qualifying, draw, matches and results remain completely separate.
            </p>

            <div className="tlg-detail-tags">
              <span>{detail.category_label}</span>
              <span>{titleCase(detail.surface)}</span>
              <span>{titleCase(detail.environment)}</span>
              <span>{titleCase(detail.competition_status.replaceAll('_', ' '))}</span>
            </div>
          </div>

          <div className="tlg-detail-logo-slot" aria-label="Tournament logo placeholder">
            <span>{tournamentInitials(detail.tournament_name)}</span>
            <small>{detail.tournament_name}</small>
          </div>
        </section>

        <section className="tlg-detail-stats-grid">
          <article><Trophy size={18} /><span>Winner ranking points</span><strong>{detail.winner_points}</strong></article>
          <article><CircleDollarSign size={18} /><span>Prize money</span><strong>To be assigned</strong></article>
          <article><Users size={18} /><span>Main draw capacity</span><strong>{detail.main_draw_capacity} players</strong></article>
          <article><Users size={18} /><span>Qualification capacity</span><strong>Up to {detail.qualifying_capacity_max}</strong></article>
        </section>

        <section className="tlg-detail-panel">
          <header className="tlg-detail-panel-head">
            <div><span>Tournament schedule</span><h2>Competition window</h2></div>
            <CalendarDays size={18} />
          </header>

          <div className="tlg-detail-schedule-list tlg-detail-schedule-list-expanded">
            {detail.schedule_slots.map((slot) => {
              const dayPlan = buildTournamentDayPlan(detail, slot)
              const isCurrentSlot = lifecycle.currentSlot
                && lifecycle.currentSlot.calendar_month === slot.calendar_month
                && lifecycle.currentSlot.month_week === slot.month_week
                && lifecycle.currentSlot.phase === slot.phase

              return (
                <article key={`${slot.calendar_month}-${slot.month_week}-${slot.phase}`} className="tlg-detail-schedule-card">
                  <div className="tlg-detail-schedule-card-head">
                    <div>
                      <span>{phaseLabel(slot.phase)}</span>
                      <strong>{MONTHS[slot.calendar_month - 1]?.name ?? `Month ${slot.calendar_month}`} · Week {slot.month_week}</strong>
                    </div>
                    <p>{weekWindow(slot)}</p>
                  </div>

                  <div className="tlg-detail-day-strip" role="table" aria-label={`${phaseLabel(slot.phase)} day schedule`}>
                    {dayPlan.map((item) => {
                      const isToday = Boolean(isCurrentSlot && lifecycle.currentDay === item.day)
                      return (
                        <div
                          key={item.day}
                          className={`tlg-detail-day-tile tlg-detail-day-tile-${item.kind}${isToday ? ' tlg-detail-day-tile-current' : ''}`}
                          role="row"
                        >
                          <span>Day {item.day}</span>
                          <strong>{item.date}</strong>
                          <p>{item.activity}</p>
                          {isToday && <small>Today</small>}
                        </div>
                      )
                    })}
                  </div>
                </article>
              )
            })}
          </div>

          <p className="tlg-detail-schedule-note">
            Qualification and main draw are held in the same tournament city. Day 1 is used for arrival/rest whenever the category has enough calendar space; otherwise the required rounds use all available days. Players are not normally scheduled for more than one singles match per in-game day.
          </p>
        </section>

        {!lifecycle.started ? (
          <section className="tlg-detail-panel tlg-detail-application-panel">
            <header className="tlg-detail-panel-head">
              <div><span>Tournament entry</span><h2>Application window</h2></div>
              <UserPlus size={18} />
            </header>

            {applicationLoading ? (
              <div className="tlg-detail-application-loading">Loading applications…</div>
            ) : applicationState ? (
              <div className="tlg-detail-application-body">
                <div className="tlg-detail-application-status-row">
                  <div>
                    <span className="tlg-detail-application-open"><Clock3 size={15} /> Applications open</span>
                    <h3>{applicationState.other_applicant_count} other players have applied</h3>
                    <p>You can see your current projected entry position before committing to this tournament.</p>
                  </div>
                  <div className={`tlg-detail-projection tlg-detail-projection-${effectiveApplicationProjection ?? 'pending'}`}>
                    <small>{applicationState.user_applied ? 'Your current projection' : 'If you apply now'}</small>
                    <strong>{projectionLabel(effectiveApplicationProjection ?? null)}</strong>
                  </div>
                </div>

                <div className="tlg-detail-application-grid">
                  <article><span>Total applicants</span><strong>{applicationState.applicant_count}</strong></article>
                  <article><span>Direct main-draw places</span><strong>{applicationState.direct_entry_slots}</strong></article>
                  <article><span>Qualification field</span><strong>{applicationState.qualifying_capacity}</strong></article>
                  <article><span>Qualifiers reach main draw</span><strong>{applicationState.qualifier_slots}</strong></article>
                </div>

                <div className="tlg-detail-entry-breakdown">
                  <div><span>Main Draw projection</span><strong>{applicationState.projected_main_count}</strong></div>
                  <div><span>Qualification projection</span><strong>{applicationState.projected_qualifying_count}</strong></div>
                  <div><span>Waiting list</span><strong>{applicationState.projected_waiting_count}</strong></div>
                </div>

                <div className="tlg-detail-application-actions">
                  {applicationState.user_applied ? (
                    <>
                      <span className="tlg-detail-applied-note"><CheckCircle2 size={16} /> Application submitted</span>
                      <button type="button" className="tlg-detail-secondary-button" disabled={applicationActionLoading} onClick={() => void withdrawApplication()}>
                        {applicationActionLoading ? 'Updating…' : 'Withdraw application'}
                      </button>
                    </>
                  ) : (
                    <button type="button" className="tlg-detail-primary-button" disabled={applicationActionLoading || !applicationState.applications_open} onClick={() => void applyForTournament()}>
                      {applicationActionLoading ? 'Applying…' : 'Apply for tournament'}
                    </button>
                  )}
                </div>

                <p className="tlg-detail-application-note">
                  This is a live capacity projection, not a final acceptance list. Once the official ATP/WTA ranking engine is connected, direct entry and qualifying cutoffs will be ordered by the ranking snapshot at the tournament deadline.
                </p>
                {applicationError && <div className="tlg-detail-inline-error"><XCircle size={15} /> {applicationError}</div>}
              </div>
            ) : (
              <div className="tlg-detail-application-loading">Application information is unavailable.{applicationError ? ` ${applicationError}` : ''}</div>
            )}
          </section>
        ) : (
          <section className="tlg-detail-panel tlg-detail-draw-panel">
            <header className="tlg-detail-panel-head tlg-detail-draw-head">
              <div>
                <span>Tournament draw</span>
                <h2>{lifecycle.finished ? 'Final tournament draw' : drawView === 'qualification' ? 'Qualification draw' : 'Main draw'}</h2>
              </div>

              <label className="tlg-detail-draw-select">
                <span>View</span>
                <select value={drawView} onChange={(event) => setDrawView(event.target.value as DrawView)}>
                  <option value="main">Main Draw</option>
                  <option value="qualification">Qualification</option>
                </select>
              </label>
            </header>

            <div className="tlg-detail-draw-summary">
              {drawView === 'main' ? (
                <>
                  <strong>Main Draw · maximum {detail.main_draw_capacity} players</strong>
                  <p>The page automatically switches to the main draw when the tournament reaches its main-draw phase. Server-generated player names and results will replace TBD once draw generation is implemented.</p>
                </>
              ) : (
                <>
                  <strong>Qualification · up to {detail.qualifying_capacity_max} players</strong>
                  <p>The qualification draw is the default view while qualifying is being played. {detail.default_qualifier_slots} players can advance into the main draw under the standard full-field format.</p>
                </>
              )}
            </div>

            <TournamentBracket rounds={activeRounds} emptyMessage="No qualification bracket is required for this tournament category." />
          </section>
        )}

        <section className="tlg-detail-panel tlg-detail-rewards-panel">
          <header className="tlg-detail-panel-head">
            <div><span>Tournament rewards</span><h2>Prize money & ranking points</h2></div>
            <Trophy size={18} />
          </header>

          <div className="tlg-detail-rewards-table">
            <div className="tlg-detail-rewards-row tlg-detail-rewards-head"><span>Result</span><span>Ranking points</span><span>Prize money</span></div>
            {rewards.map((row) => (
              <div key={row.finish} className="tlg-detail-rewards-row">
                <strong>{row.finish}</strong>
                <span>{row.points}</span>
                <span>{row.prize}</span>
              </div>
            ))}
          </div>
          <p className="tlg-detail-rewards-note">
            Winner points are already defined by tournament category. Round-by-round ranking points and prize-money amounts will populate here once the reward tables are approved, without changing this page structure.
          </p>
        </section>
      </div>
    </GameLayout>
  )
}
