import {
  ArrowLeft,
  CheckCircle2,
  Clock3,
  MapPin,
  Send,
  UserMinus,
  UserPlus,
  XCircle,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { Link, useParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import { useLocalization } from '../../i18n/LocalizationProvider'
import CountryFlag from '../../components/common/CountryFlag'
import DoublesMatchTacticPanel from '../../components/tournament/DoublesMatchTacticPanel'
import GameLayout from '../../components/layout/GameLayout'
import {
  MONTHS,
  formatCompetitionWeekDay,
  formatCompetitionWeekRange,
} from '../../lib/competitionCalendar'
import { supabase } from '../../lib/supabase'
import '../../styles/tournament-detail.css'
import '../../styles/tournament-detail-schedule.css'
import '../../styles/tournament-detail-v2.css'
import '../../styles/tournament-logo.css'
import '../../styles/tournament-doubles.css'
import '../../styles/shared-segmented-tabs.css'
import '../../styles/tournament-entry-lifecycle.css'


const SURFACE_IMAGES: Record<'hard' | 'clay' | 'grass', string> = {
  hard: 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Branding/hard.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9CcmFuZGluZy9oYXJkLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgxODM3MTgsImV4cCI6NDkxMDI0NzcxOH0.A8nFMfrv24zncDCqjuE5PihskAwMLdak04-Qz64_2ksvFiHfzDpunlMMdcGqy9IDh-qPQCfoFe5HP0Hu9pcfow',
  grass: 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Branding/grass.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9CcmFuZGluZy9ncmFzcy5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg4MTgzNzM2LCJleHAiOjQ5MTAyNDc3MzZ9.wENm_84C6GKo4fyTBxTsJ04OiNa8SZwLrEIxACdxJQN5D8EQDd6WhiRVDUbM5pwqQPgrovW009ULGRV92alrOQ',
  clay: 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Branding/clay.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9CcmFuZGluZy9jbGF5LnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgxODM3NTUsImV4cCI6NDkxMDI0Nzc1NX0.8AJ27KTGHBvo0Sf4xnNqHv8KXY9Sh2lVo7Fi1mbjtPY_Wi7_hqAVkFkC8GfiYbhN5mS3d4QI03HWyQ5wT9PVpA',
}


interface TournamentScheduleSlot {
  season_week: number
  calendar_month: number
  month_week: number
  phase: 'full' | 'qualification' | 'main_draw'
  slot_order: number
}

interface TournamentDetailRow {
  competition_id: string
  world: 'ATP' | 'WTA'
  season_number: number
  tournament_name: string
  city: string
  country_code: string
  country_name: string
  category_code: string
  category_label: string
  surface: 'hard' | 'clay' | 'grass'
  environment: 'indoor' | 'outdoor'
  logo_url: string | null
  schedule_slots: TournamentScheduleSlot[]
}

interface DoublesDayPlan {
  day: number
  date: string
  activity: string
  kind: 'main' | 'preparation'
}

interface GameMoment {
  season: number
  month: number
  day: number
  hour: number
  minute: number
  game_second: number
}

interface DoublesRewardRow {
  stage_code: string
  stage_label: string
  ranking_points: number
  team_prize_usd: number
  player_prize_usd: number
}

interface DoublesCore {
  world: 'ATP' | 'WTA'
  enabled: boolean
  draw_size: number
  minimum_teams: number
  confirmed_teams: number
  draw_published: boolean
  fatigue_multiplier: number
  equipment_wear_multiplier: number
  minimum_recovery_minutes: number
  announced_team_prize_pool_usd: number
  winner_points: number
  reward_rows: DoublesRewardRow[]
}

interface DoublesTimeline {
  phase: 'not_open' | 'marketplace_open' | 'partnership_resolution' | 'entry_locked' | 'draw_locked'
  registration_open: GameMoment
  registration_deadline: GameMoment
  partnership_deadline: GameMoment
  draw_lock: GameMoment
  tournament_start: GameMoment
  tournament_end: GameMoment
  can_create_listing: boolean
  can_send_invitation: boolean
  can_respond_invitation: boolean
  can_cancel_listing: boolean
  can_change_partnership: boolean
  entry_locked: boolean
  draw_locked: boolean
}

interface TournamentInfo {
  competition_id: string
  world: 'ATP' | 'WTA'
  name: string
  city: string
  country_code: string
  surface: string
  category_code: string
}

interface Availability {
  available: boolean
  reason: string
  blocking_tournament?: string
  blocking_city?: string
}

interface MyListing {
  id: string
  status: 'active' | 'cancelled' | 'matched' | 'expired'
  created_at: string
}

interface MyTeam {
  id: string
  status: 'confirmed' | 'active' | 'alternate' | 'eliminated' | 'champion' | 'withdrawn'
  entry_strength: number
  seed_number: number | null
  partner_id: string
  partner_name: string
  partner_country_code: string
  partner_doubles_points: number
}

interface PartnerRow {
  listing_id: string
  player_id: string
  first_name: string
  last_name: string
  country_code: string
  preferred_surface: string | null
  surface_match: boolean
  playing_style: string
  doubles_rank: number | null
  doubles_points: number
  singles_rank: number | null
  singles_points: number
  singles_participation: string
  doubles_events: number
  doubles_titles: number
  is_me: boolean
}

interface InvitationRow {
  id: string
  status: string
  partner_id: string
  partner_name: string
  country_code: string
  created_at: string
  expires_game_second: number
  expires_at_game: GameMoment
  doubles_points: number
}

interface TeamRow {
  id: string
  status: string
  player1_id: string
  player1_name: string
  player1_country_code: string
  player2_id: string
  player2_name: string
  player2_country_code: string
  combined_doubles_points: number
  entry_strength: number
  seed_number: number | null
}

interface DoublesHub {
  competition_id: string
  tournament: TournamentInfo
  core: DoublesCore
  timeline: DoublesTimeline
  availability: Availability
  player_status: string
  my_listing: MyListing | null
  my_team: MyTeam | null
  marketplace: PartnerRow[]
  incoming_invitations: InvitationRow[]
  outgoing_invitations: InvitationRow[]
  teams: TeamRow[]
}

interface DoublesDrawMatch {
  match_id: string
  round_number: number
  round_label: string
  match_number: number
  bracket_size: number
  scheduled_season_week: number
  scheduled_day: number
  scheduled_start_minute: number | null
  court_number: number | null
  match_status: string
  team1_id: string | null
  team1_player1_id: string | null
  team1_player1_first_name: string | null
  team1_player1_last_name: string | null
  team1_player2_id: string | null
  team1_player2_first_name: string | null
  team1_player2_last_name: string | null
  team2_id: string | null
  team2_player1_id: string | null
  team2_player1_first_name: string | null
  team2_player1_last_name: string | null
  team2_player2_id: string | null
  team2_player2_first_name: string | null
  team2_player2_last_name: string | null
  winner_team_id: string | null
}


function titleCase(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1)
}

function tournamentInitials(name: string) {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 3)
    .map((part) => part[0]?.toUpperCase() ?? '')
    .join('')
}

function phaseLabel(phase: TournamentScheduleSlot['phase'], t: TFunction) {
  return t(`tournamentDoublesPage.phases.${phase}`)
}

function buildDoublesDayPlan(slot: TournamentScheduleSlot, draw: DoublesDrawMatch[], t: TFunction): DoublesDayPlan[] {
  return Array.from({ length: 7 }, (_, index) => {
    const day = index + 1
    const matches = draw.filter((match) =>
      match.scheduled_season_week === slot.season_week
      && match.scheduled_day === day
      && match.match_status !== 'cancelled'
    )
    const rounds = Array.from(new Set(matches.map((match) => match.round_label).filter(Boolean)))
    const activity = rounds.length > 0
      ? rounds.join(' / ')
      : slot.phase === 'qualification'
        ? t('tournamentDoublesPage.activities.marketplaceQualifying')
        : t('tournamentDoublesPage.activities.matchRecovery')

    return {
      day,
      date: formatCompetitionWeekDay(slot.season_week, day),
      activity,
      kind: matches.length > 0 ? 'main' : 'preparation',
    }
  })
}

function formatMoment(moment: GameMoment | null | undefined, t: TFunction, localeTag: string, includeTime = true) {
  if (!moment) return t('tournamentDoublesPage.bracket.tbd')
  const date = new Intl.DateTimeFormat(localeTag, { month: 'long', day: 'numeric' }).format(new Date(2026, Math.max(0, moment.month - 1), moment.day))
  const seasonDate = t('notifications.context.seasonMoment', {
    season: moment.season,
    day: String(moment.day).padStart(2, '0'),
    month: String(moment.month).padStart(2, '0'),
    time: `${String(moment.hour).padStart(2, '0')}:${String(moment.minute).padStart(2, '0')}`,
    defaultValue: `Season ${moment.season} · ${date} · ${String(moment.hour).padStart(2, '0')}:${String(moment.minute).padStart(2, '0')}`,
  })
  if (!includeTime) return seasonDate.replace(/\s·\s\d{2}:\d{2}$/, '')
  return seasonDate
}

function playerName(first: string | null, last: string | null) {
  return `${first ?? ''} ${last ?? ''}`.trim() || 'TBD'
}

function teamName(
  first1: string | null,
  last1: string | null,
  first2: string | null,
  last2: string | null,
) {
  return `${playerName(first1, last1)} / ${playerName(first2, last2)}`
}

function doublesPhaseIndex(phase: DoublesTimeline['phase']) {
  const order: Record<DoublesTimeline['phase'], number> = {
    not_open: 0,
    marketplace_open: 1,
    partnership_resolution: 2,
    entry_locked: 3,
    draw_locked: 4,
  }
  return order[phase] ?? 0
}

function statusLabel(status: string, t: TFunction) {
  return t(`tournamentDoublesPage.statuses.${status}`, {
    defaultValue: status.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase()),
  })
}

function singlesParticipationLabel(value: string, t: TFunction) {
  return t(`tournamentDoublesPage.participation.${value === 'main_draw' || value === 'qualification' || value === 'applied' ? value : 'none'}`)
}

function rankLabel(rank: number | null, points: number, t: TFunction, formatNumber: (value: number) => string) {
  return rank
    ? t('tournamentDoublesPage.rank.ranked', { rank: formatNumber(rank), points: formatNumber(points) })
    : t('tournamentDoublesPage.rank.unranked', { points: formatNumber(points) })
}


function isPlayerInDoublesMatch(match: DoublesDrawMatch, playerId: string | null | undefined) {
  if (!playerId) return false
  return [
    match.team1_player1_id,
    match.team1_player2_id,
    match.team2_player1_id,
    match.team2_player2_id,
  ].includes(playerId)
}

function doublesScheduleLabel(match: DoublesDrawMatch, t: TFunction) {
  if (match.scheduled_start_minute == null) {
    return match.match_status === 'bye'
      ? t('tournamentDoublesPage.scheduleStatus.bye')
      : t('tournamentDoublesPage.scheduleStatus.timeTbd')
  }
  const hour = String(Math.floor(match.scheduled_start_minute / 60)).padStart(2, '0')
  const minute = String(match.scheduled_start_minute % 60).padStart(2, '0')
  const court = match.court_number ? ` · ${t('tournamentDoublesPage.scheduleStatus.court', { court: match.court_number })}` : ''
  return t('tournamentDoublesPage.scheduleStatus.line', {
    week: match.scheduled_season_week,
    day: match.scheduled_day,
    time: `${hour}:${minute}`,
    court,
  })
}

interface DoublesBracketRound {
  label: string
  matches: number
  roundNumber: number
}

const DOUBLES_BRACKET_MATCH_WIDTH = 300
const DOUBLES_BRACKET_MATCH_HEIGHT = 76
const DOUBLES_BRACKET_COLUMN_GAP = 80
const DOUBLES_BRACKET_FIRST_ROUND_GAP = 14
const DOUBLES_BRACKET_STEP = DOUBLES_BRACKET_MATCH_HEIGHT + DOUBLES_BRACKET_FIRST_ROUND_GAP

function doublesBracketRounds(capacity: number, t: TFunction): DoublesBracketRound[] {
  const rounds: DoublesBracketRound[] = []
  let teams = capacity
  let roundNumber = 1
  while (teams >= 2) {
    const label = teams === 2
      ? t('tournamentDoublesPage.bracket.final')
      : teams === 4
        ? t('tournamentDoublesPage.bracket.semifinal')
        : teams === 8
          ? t('tournamentDoublesPage.bracket.quarterfinal')
          : t('tournamentDoublesPage.bracket.roundOf', { count: teams })
    rounds.push({ label, matches: teams / 2, roundNumber })
    teams /= 2
    roundNumber += 1
  }
  return rounds
}

function doublesBracketMatchCenter(roundIndex: number, matchIndex: number) {
  const firstRoundMatchSpan = 2 ** roundIndex
  const representedFirstMatchCenter = matchIndex * firstRoundMatchSpan + (firstRoundMatchSpan - 1) / 2
  return DOUBLES_BRACKET_MATCH_HEIGHT / 2 + representedFirstMatchCenter * DOUBLES_BRACKET_STEP
}

function doublesTeamLabel(match: DoublesDrawMatch | undefined, side: 1 | 2, t: TFunction) {
  if (!match) return t('tournamentDoublesPage.bracket.tbd')
  const teamId = side === 1 ? match.team1_id : match.team2_id
  if (!teamId) return match.match_status === 'bye' ? t('tournamentDoublesPage.bracket.bye') : t('tournamentDoublesPage.bracket.tbd')
  return side === 1
    ? teamName(match.team1_player1_first_name,match.team1_player1_last_name,match.team1_player2_first_name,match.team1_player2_last_name)
    : teamName(match.team2_player1_first_name,match.team2_player1_last_name,match.team2_player2_first_name,match.team2_player2_last_name)
}

function doublesBracketStatus(match: DoublesDrawMatch | undefined, side: 1 | 2, t: TFunction) {
  if (!match) return '—'
  const teamId = side === 1 ? match.team1_id : match.team2_id
  if (!teamId) return match.match_status === 'bye' ? t('tournamentDoublesPage.bracket.bye') : '—'
  if (match.winner_team_id === teamId) return t('tournamentDoublesPage.bracket.win')
  if (match.match_status === 'completed') return t('tournamentDoublesPage.bracket.out')
  if (match.match_status === 'in_progress') return t('tournamentDoublesPage.bracket.live')
  return match.match_status === 'bye' ? t('tournamentDoublesPage.bracket.bye') : '—'
}

function DoublesPublishedDrawTree({ matches, teams, currentPlayerId }: { matches: DoublesDrawMatch[]; teams: TeamRow[]; currentPlayerId: string | null }) {
  const { t } = useTranslation()
  const firstRound = matches.filter((match) => match.round_number === 1)
  const first = firstRound[0]
  const bracketSize = first?.bracket_size ?? 0
  const rounds = doublesBracketRounds(bracketSize, t)
  const matchByRound = new Map(matches.map((match) => [`${match.round_number}:${match.match_number}`, match]))
  const teamById = new Map(teams.map((team) => [team.id, team]))

  if (rounds.length === 0) return null

  const width = rounds.length * DOUBLES_BRACKET_MATCH_WIDTH + (rounds.length - 1) * DOUBLES_BRACKET_COLUMN_GAP
  const height = Math.max(
    DOUBLES_BRACKET_MATCH_HEIGHT,
    (rounds[0].matches - 1) * DOUBLES_BRACKET_STEP + DOUBLES_BRACKET_MATCH_HEIGHT,
  )

  return (
    <section className="tlg-detail-panel tlg-doubles-bracket-panel">
      <header className="tlg-detail-panel-head tlg-doubles-bracket-head">
        <div>
          <span>{t('tournamentDoublesPage.bracket.official')}</span>
          <h2>{t('tournamentDoublesPage.bracket.tree')}</h2>
          <p>{t('tournamentDoublesPage.bracket.summary', { matches: firstRound.length, teams: bracketSize, week: first?.scheduled_season_week })}</p>
        </div>
        <span className="tlg-doubles-draw-published">{t('tournamentDoublesPage.bracket.drawPublished')}</span>
      </header>

      <div className="tlg-detail-bracket-scroll tlg-doubles-bracket-scroll">
        <div className="tlg-detail-bracket-headings" style={{ width }}>
          {rounds.map((round, roundIndex) => (
            <header
              key={`${round.label}-${round.matches}`}
              style={{ left: roundIndex * (DOUBLES_BRACKET_MATCH_WIDTH + DOUBLES_BRACKET_COLUMN_GAP), width: DOUBLES_BRACKET_MATCH_WIDTH }}
            >
              <strong>{round.label}</strong>
              <span>{t('tournamentDoublesPage.bracket.match', { count: round.matches })}</span>
            </header>
          ))}
        </div>

        <div className="tlg-detail-bracket-tree" style={{ width, height }}>
          <svg className="tlg-detail-bracket-connectors" width={width} height={height} viewBox={`0 0 ${width} ${height}`} aria-hidden="true">
            {rounds.slice(0, -1).flatMap((_, roundIndex) => {
              const parentRound = rounds[roundIndex + 1]
              const startX = roundIndex * (DOUBLES_BRACKET_MATCH_WIDTH + DOUBLES_BRACKET_COLUMN_GAP) + DOUBLES_BRACKET_MATCH_WIDTH
              const middleX = startX + DOUBLES_BRACKET_COLUMN_GAP / 2
              const endX = (roundIndex + 1) * (DOUBLES_BRACKET_MATCH_WIDTH + DOUBLES_BRACKET_COLUMN_GAP)

              return Array.from({ length: parentRound.matches }, (_, parentIndex) => {
                const firstY = doublesBracketMatchCenter(roundIndex, parentIndex * 2)
                const secondY = doublesBracketMatchCenter(roundIndex, parentIndex * 2 + 1)
                const parentY = doublesBracketMatchCenter(roundIndex + 1, parentIndex)

                return (
                  <path
                    key={`doubles-connector-${roundIndex}-${parentIndex}`}
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
              style={{ left: roundIndex * (DOUBLES_BRACKET_MATCH_WIDTH + DOUBLES_BRACKET_COLUMN_GAP), width: DOUBLES_BRACKET_MATCH_WIDTH }}
            >
              {Array.from({ length: round.matches }, (_, matchIndex) => {
                const top = doublesBracketMatchCenter(roundIndex, matchIndex) - DOUBLES_BRACKET_MATCH_HEIGHT / 2
                const match = matchByRound.get(`${round.roundNumber}:${matchIndex + 1}`)
                const ownMatch = Boolean(match && isPlayerInDoublesMatch(match, currentPlayerId))

                return (
                  <div
                    key={`${round.label}-${matchIndex}`}
                    className={`tlg-detail-bracket-match tlg-doubles-tree-match${ownMatch ? ' own-match' : ''}`}
                    style={{ top, width: DOUBLES_BRACKET_MATCH_WIDTH, height: DOUBLES_BRACKET_MATCH_HEIGHT }}
                  >
                    <DoublesBracketTeam
                      label={doublesTeamLabel(match, 1, t)}
                      team={match?.team1_id ? teamById.get(match.team1_id) : undefined}
                      status={doublesBracketStatus(match, 1, t)}
                      winner={Boolean(match?.team1_id && match.winner_team_id === match.team1_id)}
                    />
                    <DoublesBracketTeam
                      label={doublesTeamLabel(match, 2, t)}
                      team={match?.team2_id ? teamById.get(match.team2_id) : undefined}
                      status={doublesBracketStatus(match, 2, t)}
                      winner={Boolean(match?.team2_id && match.winner_team_id === match.team2_id)}
                    />
                  </div>
                )
              })}
            </section>
          ))}
        </div>
      </div>
    </section>
  )
}

function DoublesBracketTeam({ label, team, status, winner }: { label: string; team?: TeamRow; status: string; winner: boolean }) {
  return (
    <div className={`tlg-doubles-tree-team${winner ? ' winner' : ''}`}>
      <span className="tlg-doubles-tree-flags" aria-hidden="true">
        {team ? (
          <>
            <CountryFlag countryCode={team.player1_country_code} width={15} height={10} />
            <CountryFlag countryCode={team.player2_country_code} width={15} height={10} />
          </>
        ) : null}
      </span>
      <span className="tlg-doubles-tree-team-name">{label}</span>
      <span className="tlg-doubles-tree-seed">{team?.seed_number ? `#${team.seed_number}` : ''}</span>
      <span className={`tlg-doubles-tree-team-status status-${status.toLowerCase()}`}>{status}</span>
    </div>
  )
}

export default function TournamentDoublesPage() {
  const { t } = useTranslation()
  const { formatCurrency, formatNumber, localeTag } = useLocalization()
  const { competitionId } = useParams()
  const { player } = useAuth()
  const [hub, setHub] = useState<DoublesHub | null>(null)
  const [detail, setDetail] = useState<TournamentDetailRow | null>(null)
  const [draw, setDraw] = useState<DoublesDrawMatch[]>([])
  const [loading, setLoading] = useState(true)
  const [busyKey, setBusyKey] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    if (!competitionId) return

    const [hubResponse, drawResponse, detailResponse] = await Promise.all([
      supabase.rpc('get_tournament_doubles_hub_v1', { p_competition_id: competitionId }),
      supabase.rpc('get_tournament_doubles_draw_v1', { p_competition_id: competitionId }),
      supabase.rpc('get_tournament_detail_v1', { p_competition_id: competitionId }),
    ])

    if (hubResponse.error) {
      setError(hubResponse.error.message)
      setHub(null)
      setDetail(null)
      setDraw([])
    } else {
      setError(null)
      setHub(hubResponse.data as DoublesHub)
      setDraw(drawResponse.error ? [] : ((drawResponse.data ?? []) as DoublesDrawMatch[]))
      const detailRow = Array.isArray(detailResponse.data) ? detailResponse.data[0] : detailResponse.data
      setDetail(detailResponse.error || !detailRow ? null : (detailRow as TournamentDetailRow))
    }

    setLoading(false)
  }, [competitionId])

  useEffect(() => {
    void load()
    if (!competitionId) return

    const channel = supabase
      .channel(`doubles-hub-${competitionId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_doubles_partner_listings', filter: `competition_id=eq.${competitionId}` }, () => void load())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_doubles_partner_invitations', filter: `competition_id=eq.${competitionId}` }, () => void load())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_doubles_teams', filter: `competition_id=eq.${competitionId}` }, () => void load())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_doubles_matches', filter: `competition_id=eq.${competitionId}` }, () => void load())
      .subscribe()

    return () => {
      void supabase.removeChannel(channel)
    }
  }, [competitionId, load])

  const outgoingByPartner = useMemo(() => new Map(
    (hub?.outgoing_invitations ?? []).map((invitation) => [invitation.partner_id, invitation]),
  ), [hub?.outgoing_invitations])

  async function runAction(key: string, action: () => Promise<{ error: { message: string } | null }>) {
    setBusyKey(key)
    setError(null)
    const result = await action()
    if (result.error) setError(result.error.message)
    await load()
    setBusyKey(null)
  }

  async function setLooking(looking: boolean) {
    if (!competitionId) return
    await runAction(looking ? 'listing-on' : 'listing-off', async () => {
      const { error: actionError } = await supabase.rpc('set_doubles_partner_listing_v1', {
        p_competition_id: competitionId,
        p_looking: looking,
      })
      return { error: actionError }
    })
  }

  async function invite(playerId: string) {
    if (!competitionId) return
    await runAction(`invite-${playerId}`, async () => {
      const { error: actionError } = await supabase.rpc('send_doubles_partner_invitation_v1', {
        p_competition_id: competitionId,
        p_invitee_player_id: playerId,
      })
      return { error: actionError }
    })
  }

  async function respond(invitationId: string, accept: boolean) {
    await runAction(`${accept ? 'accept' : 'decline'}-${invitationId}`, async () => {
      const { error: actionError } = await supabase.rpc('respond_doubles_partner_invitation_v1', {
        p_invitation_id: invitationId,
        p_accept: accept,
      })
      return { error: actionError }
    })
  }

  async function cancelInvitation(invitationId: string) {
    await runAction(`cancel-${invitationId}`, async () => {
      const { error: actionError } = await supabase.rpc('cancel_doubles_partner_invitation_v1', {
        p_invitation_id: invitationId,
      })
      return { error: actionError }
    })
  }

  async function withdrawTeam() {
    if (!competitionId) return
    await runAction('withdraw-team', async () => {
      const { error: actionError } = await supabase.rpc('withdraw_from_doubles_v1', {
        p_competition_id: competitionId,
      })
      return { error: actionError }
    })
  }

  if (loading) {
    return (
      <GameLayout title={t('tournamentDoublesPage.title')} subtitle={t('tournamentDoublesPage.loadingSubtitle')}>
        <div className="tlg-detail-loading">{t('tournamentDoublesPage.loading')}</div>
      </GameLayout>
    )
  }

  if (!hub?.core?.enabled || !hub.tournament) {
    return (
      <GameLayout title={t('tournamentDoublesPage.title')} subtitle={t('tournamentDoublesPage.subtitle')}>
        <div className="tlg-detail-error">
          <strong>{t('tournamentDoublesPage.unavailableTitle')}</strong>
          <p>{error ?? t('tournamentDoublesPage.unavailableBody')}</p>
          <Link to={competitionId ? `/game/tournaments/${competitionId}` : '/game/calendar?tab=tournament-calendar'}>{t('tournamentDoublesPage.backTournament')}</Link>
        </div>
      </GameLayout>
    )
  }

  const { tournament, core, timeline } = hub
  const listingActive = hub.my_listing?.status === 'active'
  const hasLiveTeam = hub.my_team && ['confirmed', 'active', 'alternate'].includes(hub.my_team.status)
  const canList = timeline.can_create_listing && hub.availability.available && !hasLiveTeam
  const canInvite = timeline.can_send_invitation && hub.availability.available && !hasLiveTeam
  const surface = detail?.surface ?? (
    ['hard', 'clay', 'grass'].includes(tournament.surface.toLowerCase())
      ? tournament.surface.toLowerCase() as 'hard' | 'clay' | 'grass'
      : 'hard'
  )
  const environment = detail?.environment ?? 'outdoor'
  const countryName = detail?.country_name ?? tournament.country_code
  const categoryLabel = detail?.category_label ?? tournament.category_code.replaceAll('_', ' ')
  const seasonNumber = detail?.season_number ?? timeline.tournament_start.season
  const entryPhaseIndex = doublesPhaseIndex(timeline.phase)
  const ownDrawMatches = draw
    .filter((match) => isPlayerInDoublesMatch(match, player?.id) && match.match_status !== 'bye' && match.match_status !== 'cancelled')
    .sort((left, right) => right.round_number - left.round_number || right.match_number - left.match_number)
  const activeOwnDrawMatch = ownDrawMatches.find((match) => ['scheduled','in_progress'].includes(match.match_status)) ?? ownDrawMatches[0] ?? null

  return (
    <GameLayout title={`${tournament.name} Doubles`} subtitle={`${tournament.world} · ${tournament.city} · ${tournament.surface} doubles`}>
      <div className="tlg-detail-page tlg-doubles-page">
        <Link to="/game/calendar?tab=tournament-calendar" className="tlg-detail-back-link">
          <ArrowLeft size={15} /> {t('tournamentDoublesPage.backCalendar')}
        </Link>

        <nav className="tlg-tournament-discipline-tabs tlg-standard-tabs" aria-label={t('tournamentDoublesPage.competitionAria')}>
          <Link to={`/game/tournaments/${competitionId}`}>{t('tournamentDoublesPage.singles')}</Link>
          <Link to={`/game/tournaments/${competitionId}/doubles`} className="active" aria-current="page">{t('tournamentDoublesPage.doubles')}</Link>
        </nav>

        <section className="tlg-detail-hero">
          <div className="tlg-detail-surface-card">
            <img
              src={SURFACE_IMAGES[surface]}
              alt={t('tournamentDoublesPage.surfaceAlt', { surface: titleCase(surface) })}
              className="tlg-detail-surface-image"
            />
            <div className="tlg-detail-surface-copy">
              <strong>{titleCase(surface)}</strong>
              <span>{t('tournamentDoublesPage.court', { environment: titleCase(environment) })}</span>
            </div>
          </div>

          <div className="tlg-detail-hero-copy">
            <div className="tlg-detail-eyebrow">{t('tournamentDoublesPage.seasonEyebrow', { season: seasonNumber, world: tournament.world })}</div>
            <h1>{tournament.name}</h1>

            <div className="tlg-detail-location-line">
              <CountryFlag
                countryCode={tournament.country_code}
                countryName={countryName}
                width={24}
                height={16}
              />
              <div>
                <strong>{tournament.city}, {countryName}</strong>
                <span><MapPin size={13} /> {t('tournamentDoublesPage.officialLocation')}</span>
              </div>
            </div>

            <p>
              {t('tournamentDoublesPage.description', { category: categoryLabel, surface: titleCase(surface), city: tournament.city })}
            </p>

            <div className="tlg-detail-tags">
              <span>{categoryLabel}</span>
              <span>{titleCase(surface)}</span>
              <span>{titleCase(environment)}</span>
              <span>{t('tournamentDoublesPage.doubles')}</span>
            </div>
          </div>

          <div className={'tlg-detail-logo-slot' + (detail?.logo_url ? ' tlg-detail-logo-slot-recovered' : '')} aria-label={t('tournamentDoublesPage.logoAria')}>
            {detail?.logo_url ? (
              <img
                className="tlg-tournament-logo-image tlg-tournament-logo-image-ready"
                src={detail.logo_url}
                alt={t('tournamentDoublesPage.logoAlt', { name: tournament.name })}
                decoding="async"
              />
            ) : (
              <>
                <span>{tournamentInitials(tournament.name)}</span>
                <small>{tournament.name}</small>
              </>
            )}
          </div>
        </section>

        <section className="tlg-detail-stats-grid">
          <article><span>{t('tournamentDoublesPage.drawCapacity')}</span><strong>{t('tournamentDoublesPage.teamsCount', { count: core.draw_size })}</strong></article>
          <article><span>{t('tournamentDoublesPage.teamPrizePool')}</span><strong>{formatCurrency(core.announced_team_prize_pool_usd, 'USD')}</strong></article>
          <article><span>{t('tournamentDoublesPage.winnerPoints')}</span><strong>{t('tournamentDoublesPage.pointsEach', { count: formatNumber(core.winner_points) })}</strong></article>
          <article><span>{t('tournamentDoublesPage.yourStatus')}</span><strong>{statusLabel(hub.player_status, t)}</strong></article>
        </section>

        <section className="tlg-detail-panel tlg-entry-lifecycle-panel tlg-doubles-entry-timeline-panel">
          <header className="tlg-detail-panel-head tlg-entry-lifecycle-head">
            <div>
              <span>{t('tournamentDoublesPage.entryKicker')}</span>
              <h2>{t('tournamentDoublesPage.entryTitle')}</h2>
              <p>
                {t('tournamentDoublesPage.entryBody')}
              </p>
            </div>
            <strong className={'tlg-entry-phase phase-' + timeline.phase}>{statusLabel(timeline.phase, t)}</strong>
          </header>

          <div className="tlg-entry-milestones">
            <article className={entryPhaseIndex > 0 ? 'done' : entryPhaseIndex === 0 ? 'current' : ''}>
              <span>1</span>
              <div><strong>{t('tournamentDoublesPage.milestones.registration')}</strong><small>{formatMoment(timeline.registration_open, t, localeTag)}</small></div>
            </article>
            <article className={entryPhaseIndex > 1 ? 'done' : entryPhaseIndex === 1 ? 'current' : ''}>
              <span>2</span>
              <div><strong>{t('tournamentDoublesPage.milestones.marketplace')}</strong><small>{formatMoment(timeline.registration_deadline, t, localeTag)}</small></div>
            </article>
            <article className={entryPhaseIndex > 2 ? 'done' : entryPhaseIndex === 2 ? 'current' : ''}>
              <span>3</span>
              <div><strong>{t('tournamentDoublesPage.milestones.partnership')}</strong><small>{formatMoment(timeline.partnership_deadline, t, localeTag)}</small></div>
            </article>
            <article className={entryPhaseIndex > 3 ? 'done' : entryPhaseIndex === 3 ? 'current' : ''}>
              <span>4</span>
              <div><strong>{t('tournamentDoublesPage.milestones.field')}</strong><small>{formatMoment(timeline.draw_lock, t, localeTag)}</small></div>
            </article>
            <article className={core.draw_published ? 'done' : entryPhaseIndex === 4 ? 'current' : ''}>
              <span>5</span>
              <div><strong>{t('tournamentDoublesPage.milestones.draw')}</strong><small>{core.draw_published ? t('tournamentDoublesPage.milestones.published') : t('tournamentDoublesPage.milestones.afterLock')}</small></div>
            </article>
            <article className={core.draw_published ? 'current' : ''}>
              <span>6</span>
              <div><strong>{t('tournamentDoublesPage.milestones.begins')}</strong><small>{formatMoment(timeline.tournament_start, t, localeTag, false)}</small></div>
            </article>
          </div>

          <div className="tlg-entry-personal-card tlg-doubles-entry-summary">
            <div className="tlg-entry-personal-head">
              <div>
                <span>{t('tournamentDoublesPage.yourStatus')}</span>
                <strong>{statusLabel(hub.player_status, t)}</strong>
              </div>
              <div className="tlg-entry-vacancy-mini">
                <span>{t('tournamentDoublesPage.confirmedTeams', { count: core.confirmed_teams })}</span>
                <span>{t('tournamentDoublesPage.maximumDraw', { count: core.draw_size })}</span>
                <span>{t('tournamentDoublesPage.looking', { count: hub.marketplace.length })}</span>
              </div>
            </div>
            <p className="tlg-entry-passive-note">
              {t('tournamentDoublesPage.aiNote')}
            </p>
          </div>
        </section>

        <section className="tlg-detail-panel">
          <header className="tlg-detail-panel-head tlg-entry-lifecycle-head">
            <div>
              <span>{t('tournamentDoublesPage.scheduleKicker')}</span>
              <h2>{t('tournamentDoublesPage.scheduleTitle')}</h2>
            </div>
          </header>

          {detail?.schedule_slots?.length ? (
            <div className="tlg-detail-schedule-list tlg-detail-schedule-list-expanded">
              {detail.schedule_slots.map((slot) => {
                const dayPlan = buildDoublesDayPlan(slot, draw, t)
                return (
                  <article key={slot.season_week + '-' + slot.phase} className="tlg-detail-schedule-card">
                    <div className="tlg-detail-schedule-card-head">
                      <div>
                        <span>{phaseLabel(slot.phase, t)}</span>
                        <strong>{t('tournamentDoublesPage.monthWeek', { month: MONTHS[slot.calendar_month - 1]?.name ?? slot.calendar_month, week: slot.month_week, seasonWeek: slot.season_week })}</strong>
                      </div>
                      <p>{t('tournamentDoublesPage.weekRange', { range: formatCompetitionWeekRange(slot.season_week) })}</p>
                    </div>

                    <div className="tlg-detail-day-strip" role="table" aria-label={t('tournamentDoublesPage.scheduleAria', { phase: phaseLabel(slot.phase, t) })}>
                      {dayPlan.map((item) => (
                        <div
                          key={item.day}
                          className={'tlg-detail-day-tile tlg-detail-day-tile-' + item.kind}
                          role="row"
                        >
                          <span role="cell">{t('tournamentDoublesPage.day', { day: item.day })}</span>
                          <strong role="cell">{item.date}</strong>
                          <p role="cell">{item.activity}</p>
                        </div>
                      ))}
                    </div>
                  </article>
                )
              })}
            </div>
          ) : (
            <div className="tlg-doubles-empty">
              <strong>{t('tournamentDoublesPage.scheduleLoading')}</strong>
              <p>{t('tournamentDoublesPage.scheduleLoadingBody')}</p>
            </div>
          )}

          <p className="tlg-detail-schedule-note">
            {t('tournamentDoublesPage.scheduleNote')}
          </p>
        </section>

        <section className="tlg-detail-panel">
          <header className="tlg-detail-panel-head">
            <div><span>{t('tournamentDoublesPage.entrySection')}</span><h2>{t('tournamentDoublesPage.partnerStatus')}</h2></div>
          </header>

          <div className="tlg-doubles-my-status">
            <div>
              <span className={`tlg-doubles-status-chip status-${hub.player_status}`}>{statusLabel(hub.player_status, t)}</span>
              {hub.my_team ? (
                <>
                  <h3>{hub.my_team.partner_name}</h3>
                  <p>
                    {t('tournamentDoublesPage.partner')} · {t('tournamentDoublesPage.doublesPoints', { count: formatNumber(hub.my_team.partner_doubles_points) })}
                    {hub.my_team.seed_number ? ` · ${t('tournamentDoublesPage.seed', { seed: hub.my_team.seed_number })}` : ''}
                  </p>
                </>
              ) : listingActive ? (
                <>
                  <h3>{t('tournamentDoublesPage.listedTitle')}</h3>
                  <p>{t('tournamentDoublesPage.listedBody', { name: tournament.name })}</p>
                </>
              ) : (
                <>
                  <h3>{t('tournamentDoublesPage.noPartnership')}</h3>
                  <p>{t('tournamentDoublesPage.noPartnershipBody')}</p>
                </>
              )}
              {!hub.availability.available && (
                <p className="tlg-doubles-availability-warning">
                  <XCircle size={14} />
                  Blocked by {hub.availability.blocking_tournament
                    ? `${hub.availability.blocking_tournament}${hub.availability.blocking_city ? ` in ${hub.availability.blocking_city}` : ''}`
                    : hub.availability.reason.replaceAll('_',' ')}.
                </p>
              )}
            </div>

            <div className="tlg-doubles-my-actions">
              {!hasLiveTeam && !listingActive && (
                <button type="button" className="tlg-detail-primary-button" disabled={!canList || busyKey !== null} onClick={() => void setLooking(true)}>
                  <UserPlus size={15} /> {busyKey === 'listing-on' ? t('tournamentDoublesPage.adding') : t('tournamentDoublesPage.lookPartner')}
                </button>
              )}
              {!hasLiveTeam && listingActive && (
                <button type="button" className="tlg-detail-secondary-button" disabled={!timeline.can_cancel_listing || busyKey !== null} onClick={() => void setLooking(false)}>
                  <UserMinus size={15} /> {busyKey === 'listing-off' ? t('tournamentDoublesPage.removing') : t('tournamentDoublesPage.stopLooking')}
                </button>
              )}
              {hasLiveTeam && (
                <button type="button" className="tlg-detail-secondary-button" disabled={busyKey !== null} onClick={() => void withdrawTeam()}>
                  <UserMinus size={15} />
                  {busyKey === 'withdraw-team'
                    ? t('tournamentDoublesPage.processing')
                    : core.draw_published || timeline.draw_locked
                      ? t('tournamentDoublesPage.withdrawTeam')
                      : t('tournamentDoublesPage.leavePartnership')}
                </button>
              )}
            </div>
          </div>

          {error && <div className="tlg-detail-inline-error"><XCircle size={14} /> {error}</div>}
        </section>

        {hub.incoming_invitations.length > 0 && (
          <section className="tlg-detail-panel">
            <header className="tlg-detail-panel-head">
              <div><span>{t('tournamentDoublesPage.actionRequired')}</span><h2>{t('tournamentDoublesPage.invitations')}</h2></div>
            </header>
            <div className="tlg-doubles-invitations">
              {hub.incoming_invitations.map((invitation) => (
                <article key={invitation.id}>
                  <div className="tlg-doubles-invite-player">
                    <CountryFlag countryCode={invitation.country_code} width={24} height={16} />
                    <div>
                      <strong>{invitation.partner_name}</strong>
                      <span>{t('tournamentDoublesPage.expires', { count: formatNumber(invitation.doubles_points), time: formatMoment(invitation.expires_at_game, t, localeTag) })}</span>
                    </div>
                  </div>
                  <div className="tlg-doubles-invite-actions">
                    <button type="button" className="tlg-detail-primary-button" disabled={!timeline.can_respond_invitation || busyKey !== null} onClick={() => void respond(invitation.id,true)}>
                      <CheckCircle2 size={14} /> {t('tournamentDoublesPage.accept')}
                    </button>
                    <button type="button" className="tlg-detail-secondary-button" disabled={!timeline.can_respond_invitation || busyKey !== null} onClick={() => void respond(invitation.id,false)}>
                      {t('tournamentDoublesPage.decline')}
                    </button>
                  </div>
                </article>
              ))}
            </div>
          </section>
        )}

        {hub.outgoing_invitations.length > 0 && (
          <section className="tlg-detail-panel">
            <header className="tlg-detail-panel-head">
              <div><span>{t('tournamentDoublesPage.pending')}</span><h2>{t('tournamentDoublesPage.sentInvitations')}</h2></div>
            </header>
            <div className="tlg-doubles-outgoing">
              {hub.outgoing_invitations.map((invitation) => (
                <article key={invitation.id}>
                  <CountryFlag countryCode={invitation.country_code} width={24} height={16} />
                  <div>
                    <strong>{invitation.partner_name}</strong>
                    <span>{t('tournamentDoublesPage.waitingResponse', { time: formatMoment(invitation.expires_at_game, t, localeTag) })}</span>
                  </div>
                  <button type="button" className="tlg-detail-secondary-button" disabled={busyKey !== null} onClick={() => void cancelInvitation(invitation.id)}>
                    {t('tournamentDoublesPage.cancel')}
                  </button>
                </article>
              ))}
            </div>
          </section>
        )}

        <section className="tlg-detail-panel">
          <header className="tlg-detail-panel-head">
            <div><span>{t('tournamentDoublesPage.marketplaceKicker')}</span><h2>{t('tournamentDoublesPage.marketplaceTitle')}</h2></div>
          </header>

          <p className="tlg-doubles-market-note">
            {t('tournamentDoublesPage.marketplaceBody', { name: tournament.name })}
          </p>

          {hub.marketplace.length === 0 ? (
            <div className="tlg-doubles-empty">
              <strong>{t('tournamentDoublesPage.noListings')}</strong>
              <p>{t('tournamentDoublesPage.listingsUntil', { time: formatMoment(timeline.registration_deadline, t, localeTag) })}</p>
            </div>
          ) : (
            <div className="tlg-doubles-market-list">
              {hub.marketplace.map((partner) => {
                const pending = outgoingByPartner.get(partner.player_id)
                return (
                  <article key={partner.player_id} className={partner.is_me ? 'is-me' : ''}>
                    <div className="tlg-doubles-market-player">
                      <CountryFlag countryCode={partner.country_code} width={26} height={18} />
                      <div>
                        <strong>{partner.first_name} {partner.last_name}{partner.is_me ? ` · ${t('tournamentDoublesPage.you')}` : ''}</strong>
                        <span>{partner.playing_style}{partner.surface_match ? ` · ${t('tournamentDoublesPage.prefers', { surface: tournament.surface })}` : partner.preferred_surface ? ` · ${t('tournamentDoublesPage.prefers', { surface: partner.preferred_surface })}` : ''}</span>
                      </div>
                    </div>
                    <div className="tlg-doubles-market-metrics">
                      <span><small>{t('tournamentDoublesPage.doublesLabel')}</small><b>{rankLabel(partner.doubles_rank, partner.doubles_points, t, formatNumber)}</b></span>
                      <span><small>{t('tournamentDoublesPage.singlesLabel')}</small><b>{rankLabel(partner.singles_rank, partner.singles_points, t, formatNumber)}</b></span>
                      <span><small>{t('tournamentDoublesPage.atEvent')}</small><b>{singlesParticipationLabel(partner.singles_participation, t)}</b></span>
                      <span><small>{t('tournamentDoublesPage.history')}</small><b>{t('tournamentDoublesPage.eventsTitles', { events: formatNumber(partner.doubles_events), titles: formatNumber(partner.doubles_titles) })}</b></span>
                    </div>
                    <div className="tlg-doubles-market-action">
                      {partner.is_me ? (
                        <span className="tlg-doubles-you-chip">{t('tournamentDoublesPage.yourListing')}</span>
                      ) : pending ? (
                        <button type="button" className="tlg-detail-secondary-button" disabled onClick={() => undefined}>{t('tournamentDoublesPage.invitationPending')}</button>
                      ) : (
                        <button type="button" className="tlg-detail-primary-button" disabled={!canInvite || busyKey !== null} onClick={() => void invite(partner.player_id)}>
                          <Send size={14} /> {busyKey === `invite-${partner.player_id}` ? t('tournamentDoublesPage.sending') : t('tournamentDoublesPage.invite')}
                        </button>
                      )}
                    </div>
                  </article>
                )
              })}
            </div>
          )}
        </section>

        {!core.draw_published && (
          <section className="tlg-detail-panel">
            <header className="tlg-detail-panel-head">
              <div><span>{t('tournamentDoublesPage.fieldKicker')}</span><h2>{t('tournamentDoublesPage.fieldTitle')}</h2></div>
            </header>

            {hub.teams.length === 0 ? (
            <div className="tlg-doubles-empty">
              <strong>{t('tournamentDoublesPage.noTeams')}</strong>
              <p>{t('tournamentDoublesPage.noTeamsBody')}</p>
            </div>
          ) : (
            <div className="tlg-doubles-team-list">
              {hub.teams.map((team, index) => (
                <article key={team.id}>
                  <span className="tlg-doubles-team-order">{team.seed_number ? `#${team.seed_number}` : index + 1}</span>
                  <div>
                    <strong>{team.player1_name} / {team.player2_name}</strong>
                    <span>{t('tournamentDoublesPage.establishedPoints', { points: formatNumber(team.combined_doubles_points), strength: formatNumber(team.entry_strength) })}</span>
                  </div>
                  <span className={`tlg-doubles-entry-chip status-${team.status}`}>{statusLabel(team.status, t)}</span>
                </article>
              ))}
            </div>
            )}
          </section>
        )}

        {core.draw_published && draw.length > 0 && (
          <DoublesPublishedDrawTree matches={draw} teams={hub.teams} currentPlayerId={player?.id ?? null} />
        )}

        {core.draw_published && activeOwnDrawMatch && player?.id && (
          <section className="tlg-detail-panel tlg-doubles-own-tactic-panel">
            <header className="tlg-detail-panel-head">
              <div>
                <span>{t('tournamentDoublesPage.yourMatch')}</span>
                <h2>{t('tournamentDoublesPage.matchNumber', { round: activeOwnDrawMatch.round_label, match: activeOwnDrawMatch.match_number })}</h2>
                <p>{doublesScheduleLabel(activeOwnDrawMatch, t)}</p>
              </div>
            </header>
            <DoublesMatchTacticPanel matchId={activeOwnDrawMatch.match_id} currentPlayerId={player.id} />
          </section>
        )}

        <section className="tlg-detail-panel tlg-doubles-rewards-panel">
          <header className="tlg-detail-panel-head">
            <div><span>{t('tournamentDoublesPage.rewardsKicker')}</span><h2>{t('tournamentDoublesPage.rewardsTitle')}</h2></div>
          </header>
          <div className="tlg-doubles-rules-strip">
            <span>{t('tournamentDoublesPage.splitRule')}</span>
            <span>{t('tournamentDoublesPage.fatigueRule', { percent: formatNumber(Math.round(core.fatigue_multiplier * 100)) })}</span>
            <span>{t('tournamentDoublesPage.wearRule', { percent: formatNumber(Math.round(core.equipment_wear_multiplier * 100)) })}</span>
            <span>{t('tournamentDoublesPage.recoveryRule', { hours: formatNumber(Math.round(core.minimum_recovery_minutes / 60)) })}</span>
          </div>
          <div className="tlg-detail-rewards-table tlg-doubles-rewards-table">
            <div className="tlg-detail-rewards-row tlg-detail-rewards-head">
              <span>{t('tournamentDoublesPage.finishingStage')}</span><span>{t('tournamentDoublesPage.pointsColumn')}</span><span>{t('tournamentDoublesPage.teamPrize')}</span><span>{t('tournamentDoublesPage.perPlayer')}</span>
            </div>
            {(core.reward_rows ?? []).map((row) => (
              <div key={row.stage_code} className="tlg-detail-rewards-row">
                <strong>{row.stage_label}</strong>
                <span>{formatNumber(row.ranking_points)}</span>
                <span>{formatCurrency(row.team_prize_usd, 'USD')}</span>
                <span>{formatCurrency(row.player_prize_usd, 'USD')}</span>
              </div>
            ))}
          </div>
        </section>
      </div>
    </GameLayout>
  )
}
