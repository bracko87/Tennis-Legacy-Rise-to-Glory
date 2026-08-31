import type { CSSProperties } from 'react'
import {
  ArrowLeft,
  CalendarDays,
  CircleDollarSign,
  MapPin,
  Trophy,
  Users,
} from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router'

import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/tournament-detail.css'

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
  surface: 'hard' | 'clay' | 'grass'
  environment: 'indoor' | 'outdoor'
  schedule_slots: TournamentScheduleSlot[]
}

interface BracketRound {
  label: string
  matches: number
}

type DrawView = 'main' | 'qualification'

function titleCase(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1)
}

function phaseLabel(phase: TournamentScheduleSlot['phase']) {
  if (phase === 'qualification') return 'Qualification'
  if (phase === 'main_draw') return 'Main Draw'
  return 'Tournament Week'
}

function weekWindow(slot: TournamentScheduleSlot) {
  const month = MONTHS[slot.calendar_month - 1]
  if (!month) return `Month ${slot.calendar_month} · Week ${slot.month_week}`

  const start = slot.month_week === 1
    ? 1
    : slot.month_week === 2
      ? 8
      : slot.month_week === 3
        ? 15
        : 22

  const end = slot.month_week === 1
    ? 7
    : slot.month_week === 2
      ? 14
      : slot.month_week === 3
        ? 21
        : month.days

  return `${month.name} ${start}–${end}`
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

function TournamentBracket({
  rounds,
  emptyMessage,
}: {
  rounds: BracketRound[]
  emptyMessage: string
}) {
  if (rounds.length === 0) {
    return <div className="tlg-detail-bracket-empty">{emptyMessage}</div>
  }

  return (
    <div className="tlg-detail-bracket-scroll">
      <div className="tlg-detail-bracket-tree">
        {rounds.map((round, roundIndex) => {
          const spacing = Math.min(10 + roundIndex * 14, 80)
          const offset = roundIndex === 0 ? 0 : Math.min(roundIndex * 12, 54)

          return (
            <section
              key={`${round.label}-${round.matches}`}
              className="tlg-detail-bracket-round"
              style={{
                '--bracket-gap': `${spacing}px`,
                '--bracket-offset': `${offset}px`,
              } as CSSProperties}
            >
              <header>
                <strong>{round.label}</strong>
                <span>{round.matches} {round.matches === 1 ? 'match' : 'matches'}</span>
              </header>

              <div className="tlg-detail-bracket-matches">
                {Array.from({ length: round.matches }, (_, index) => (
                  <div key={`${round.label}-${index}`} className="tlg-detail-bracket-match">
                    <div><span>{index * 2 + 1}</span><strong>TBD</strong></div>
                    <div><span>{index * 2 + 2}</span><strong>TBD</strong></div>
                  </div>
                ))}
              </div>
            </section>
          )
        })}
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

export default function TournamentPage() {
  const { competitionId } = useParams()
  const [detail, setDetail] = useState<TournamentDetailRow | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [drawView, setDrawView] = useState<DrawView>('main')

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

    return () => {
      cancelled = true
    }
  }, [competitionId])

  const mainRounds = useMemo(
    () => mainDrawRounds(detail?.main_draw_capacity ?? 0),
    [detail?.main_draw_capacity],
  )

  const qualifierRounds = useMemo(
    () => qualificationRounds(
      detail?.qualifying_capacity_max ?? 0,
      detail?.default_qualifier_slots ?? 0,
    ),
    [detail?.default_qualifier_slots, detail?.qualifying_capacity_max],
  )

  const activeRounds = drawView === 'main' ? mainRounds : qualifierRounds

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
          <Link to="/game/calendar">Back to Tournament Calendar</Link>
        </div>
      </GameLayout>
    )
  }

  return (
    <GameLayout
      title={detail.tournament_name}
      subtitle={`${detail.world} · Season ${detail.season_number} · ${detail.category_label}`}
    >
      <div className="tlg-detail-page">
        <Link to="/game/calendar" className="tlg-detail-back-link">
          <ArrowLeft size={15} /> Back to Tournament Calendar
        </Link>

        <section className="tlg-detail-hero">
          <div className="tlg-detail-logo-slot" aria-label="Tournament logo placeholder">
            <span>{tournamentInitials(detail.tournament_name)}</span>
            <small>Tournament logo</small>
          </div>

          <div className="tlg-detail-hero-copy">
            <div className="tlg-detail-eyebrow">Season {detail.season_number} · {detail.world} singles</div>
            <h1>{detail.tournament_name}</h1>

            <div className="tlg-detail-location-line">
              <CountryFlag
                countryCode={detail.country_code}
                countryName={detail.country_name}
                width={30}
                height={20}
              />
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

          <div className={`tlg-detail-surface-card tlg-detail-surface-${detail.surface}`}>
            <div className="tlg-detail-court-graphic" aria-hidden="true">
              <i />
              <i />
              <i />
            </div>
            <strong>{titleCase(detail.surface)}</strong>
            <span>{titleCase(detail.environment)} court</span>
          </div>
        </section>

        <section className="tlg-detail-stats-grid">
          <article>
            <Trophy size={18} />
            <span>Winner ranking points</span>
            <strong>{detail.winner_points}</strong>
          </article>
          <article>
            <CircleDollarSign size={18} />
            <span>Prize money</span>
            <strong>To be assigned</strong>
          </article>
          <article>
            <Users size={18} />
            <span>Main draw capacity</span>
            <strong>{detail.main_draw_capacity} players</strong>
          </article>
          <article>
            <Users size={18} />
            <span>Qualification capacity</span>
            <strong>Up to {detail.qualifying_capacity_max}</strong>
          </article>
        </section>

        <section className="tlg-detail-panel">
          <header className="tlg-detail-panel-head">
            <div>
              <span>Tournament schedule</span>
              <h2>Competition window</h2>
            </div>
            <CalendarDays size={18} />
          </header>

          <div className="tlg-detail-schedule-list">
            {detail.schedule_slots.map((slot) => (
              <article key={`${slot.calendar_month}-${slot.month_week}-${slot.phase}`}>
                <div>
                  <span>{phaseLabel(slot.phase)}</span>
                  <strong>{MONTHS[slot.calendar_month - 1]?.name ?? `Month ${slot.calendar_month}`} · Week {slot.month_week}</strong>
                </div>
                <p>{weekWindow(slot)}</p>
              </article>
            ))}
          </div>

          <p className="tlg-detail-schedule-note">
            These are the fixed calendar competition windows. Exact qualifying and round-by-round match dates will be attached later when the tournament scheduling engine is implemented.
          </p>
        </section>

        <section className="tlg-detail-panel tlg-detail-draw-panel">
          <header className="tlg-detail-panel-head tlg-detail-draw-head">
            <div>
              <span>Tournament draw</span>
              <h2>Knockout bracket</h2>
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
                <p>If fewer players enter, the tournament continues with byes. The bracket is never artificially filled.</p>
              </>
            ) : (
              <>
                <strong>Qualification · up to {detail.qualifying_capacity_max} players</strong>
                <p>
                  Qualification is dynamic. The number of qualifying rounds shrinks when fewer players need to qualify. The normal target is {detail.default_qualifier_slots} qualifier places in the main draw.
                </p>
              </>
            )}
          </div>

          <TournamentBracket
            rounds={activeRounds}
            emptyMessage="No qualification bracket is required for this tournament category."
          />
        </section>
      </div>
    </GameLayout>
  )
}
