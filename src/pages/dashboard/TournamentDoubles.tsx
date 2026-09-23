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
import { Link, useParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
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

function phaseLabel(phase: TournamentScheduleSlot['phase']) {
  if (phase === 'qualification') return 'Qualification'
  if (phase === 'main_draw') return 'Main Draw'
  return 'Tournament Week'
}

function buildDoublesDayPlan(slot: TournamentScheduleSlot, draw: DoublesDrawMatch[]): DoublesDayPlan[] {
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
        ? 'Partner marketplace / tournament qualifying'
        : 'Doubles match window / recovery'

    return {
      day,
      date: formatCompetitionWeekDay(slot.season_week, day),
      activity,
      kind: matches.length > 0 ? 'main' : 'preparation',
    }
  })
}

function formatMoney(value: number | null | undefined) {
  return `$${Math.round(Number(value) || 0).toLocaleString()}`
}

function formatMoment(moment: GameMoment | null | undefined, includeTime = true) {
  if (!moment) return 'TBD'
  const month = MONTHS[moment.month - 1]?.name ?? `Month ${moment.month}`
  const date = `Season ${moment.season} · ${moment.day} ${month}`
  if (!includeTime) return date
  return `${date} · ${String(moment.hour).padStart(2, '0')}:${String(moment.minute).padStart(2, '0')}`
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

function statusLabel(status: string) {
  const labels: Record<string, string> = {
    available: 'Available for doubles',
    not_open: 'Registration not open',
    looking_for_partner: 'Looking for a partner',
    invitation_received: 'Invitation received',
    partnership_confirmed: 'Partnership confirmed',
    entry_accepted: 'Entry accepted',
    waitlisted: 'Waitlisted / alternate',
    entry_locked: 'Entries locked',
    unavailable: 'Unavailable',
    champion: 'Doubles champion',
    eliminated: 'Eliminated',
    withdrawn: 'Withdrawn',
    confirmed: 'Partnership confirmed',
    active: 'Entry accepted',
    alternate: 'Waitlisted',
  }
  return labels[status] ?? status.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function singlesParticipationLabel(value: string) {
  if (value === 'main_draw') return 'Singles Main Draw'
  if (value === 'qualification') return 'Singles Qualifying'
  if (value === 'applied') return 'Singles application'
  return 'Doubles only / no singles entry'
}

function rankLabel(rank: number | null, points: number) {
  return rank ? `#${rank} · ${points.toLocaleString()} pts` : `Unranked · ${points.toLocaleString()} pts`
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

function doublesScheduleLabel(match: DoublesDrawMatch) {
  if (match.scheduled_start_minute == null) {
    return match.match_status === 'bye' ? 'Bye' : 'Time TBD'
  }
  const hour = String(Math.floor(match.scheduled_start_minute / 60)).padStart(2, '0')
  const minute = String(match.scheduled_start_minute % 60).padStart(2, '0')
  const court = match.court_number ? ' · Court ' + match.court_number : ''
  return 'Week ' + match.scheduled_season_week + ' · Day ' + match.scheduled_day + ' · ' + hour + ':' + minute + court
}

export default function TournamentDoublesPage() {
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
      <GameLayout title="Doubles" subtitle="Loading tournament doubles">
        <div className="tlg-detail-loading">Loading doubles competition…</div>
      </GameLayout>
    )
  }

  if (!hub?.core?.enabled || !hub.tournament) {
    return (
      <GameLayout title="Doubles" subtitle="Tournament doubles">
        <div className="tlg-detail-error">
          <strong>Doubles is not available for this tournament</strong>
          <p>{error ?? 'This tournament does not currently support a doubles draw.'}</p>
          <Link to={competitionId ? `/game/tournaments/${competitionId}` : '/game/calendar?tab=tournament-calendar'}>Back to tournament</Link>
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

  return (
    <GameLayout title={`${tournament.name} Doubles`} subtitle={`${tournament.world} · ${tournament.city} · ${tournament.surface} doubles`}>
      <div className="tlg-detail-page tlg-doubles-page">
        <Link to="/game/calendar?tab=tournament-calendar" className="tlg-detail-back-link">
          <ArrowLeft size={15} /> Back to Tournament Calendar
        </Link>

        <nav className="tlg-tournament-discipline-tabs tlg-standard-tabs" aria-label="Tournament competition">
          <Link to={`/game/tournaments/${competitionId}`}>Singles</Link>
          <Link to={`/game/tournaments/${competitionId}/doubles`} className="active" aria-current="page">Doubles</Link>
        </nav>

        <section className="tlg-detail-hero">
          <div className="tlg-detail-surface-card">
            <img
              src={SURFACE_IMAGES[surface]}
              alt={titleCase(surface) + ' tennis court surface'}
              className="tlg-detail-surface-image"
            />
            <div className="tlg-detail-surface-copy">
              <strong>{titleCase(surface)}</strong>
              <span>{titleCase(environment)} court</span>
            </div>
          </div>

          <div className="tlg-detail-hero-copy">
            <div className="tlg-detail-eyebrow">Season {seasonNumber} · {tournament.world} doubles</div>
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
                <span><MapPin size={13} /> Official tournament location</span>
              </div>
            </div>

            <p>
              A {categoryLabel} doubles event played on {titleCase(surface)} courts in {tournament.city}.
              It uses the same location, surface and tournament dates as singles, while the doubles draw,
              partner marketplace, ranking points and prize money remain separate.
            </p>

            <div className="tlg-detail-tags">
              <span>{categoryLabel}</span>
              <span>{titleCase(surface)}</span>
              <span>{titleCase(environment)}</span>
              <span>Doubles</span>
            </div>
          </div>

          <div className={'tlg-detail-logo-slot' + (detail?.logo_url ? ' tlg-detail-logo-slot-recovered' : '')} aria-label="Tournament logo">
            {detail?.logo_url ? (
              <img
                className="tlg-tournament-logo-image tlg-tournament-logo-image-ready"
                src={detail.logo_url}
                alt={tournament.name + ' tournament logo'}
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
          <article><span>Draw capacity</span><strong>{core.draw_size} teams</strong></article>
          <article><span>Team prize pool</span><strong>{formatMoney(core.announced_team_prize_pool_usd)}</strong></article>
          <article><span>Winner ranking points</span><strong>{core.winner_points.toLocaleString()} pts each</strong></article>
          <article><span>Your doubles status</span><strong>{statusLabel(hub.player_status)}</strong></article>
        </section>

        <section className="tlg-detail-panel tlg-entry-lifecycle-panel tlg-doubles-entry-timeline-panel">
          <header className="tlg-detail-panel-head tlg-entry-lifecycle-head">
            <div>
              <span>Tournament entry</span>
              <h2>Application & entry timeline</h2>
              <p>
                Doubles follows the same six-step tournament-entry presentation as singles. Partner registration,
                partnership resolution, field locking and draw publication use the deadlines below.
              </p>
            </div>
            <strong className={'tlg-entry-phase phase-' + timeline.phase}>{statusLabel(timeline.phase)}</strong>
          </header>

          <div className="tlg-entry-milestones">
            <article className={entryPhaseIndex > 0 ? 'done' : entryPhaseIndex === 0 ? 'current' : ''}>
              <span>1</span>
              <div><strong>Registration opens</strong><small>{formatMoment(timeline.registration_open)}</small></div>
            </article>
            <article className={entryPhaseIndex > 1 ? 'done' : entryPhaseIndex === 1 ? 'current' : ''}>
              <span>2</span>
              <div><strong>Marketplace deadline</strong><small>{formatMoment(timeline.registration_deadline)}</small></div>
            </article>
            <article className={entryPhaseIndex > 2 ? 'done' : entryPhaseIndex === 2 ? 'current' : ''}>
              <span>3</span>
              <div><strong>Partnership deadline</strong><small>{formatMoment(timeline.partnership_deadline)}</small></div>
            </article>
            <article className={entryPhaseIndex > 3 ? 'done' : entryPhaseIndex === 3 ? 'current' : ''}>
              <span>4</span>
              <div><strong>Final field locked</strong><small>{formatMoment(timeline.draw_lock)}</small></div>
            </article>
            <article className={core.draw_published ? 'done' : entryPhaseIndex === 4 ? 'current' : ''}>
              <span>5</span>
              <div><strong>Draw published</strong><small>{core.draw_published ? 'Published' : 'After final field lock'}</small></div>
            </article>
            <article className={core.draw_published ? 'current' : ''}>
              <span>6</span>
              <div><strong>Tournament begins</strong><small>{formatMoment(timeline.tournament_start,false)}</small></div>
            </article>
          </div>

          <div className="tlg-entry-personal-card tlg-doubles-entry-summary">
            <div className="tlg-entry-personal-head">
              <div>
                <span>Your status</span>
                <strong>{statusLabel(hub.player_status)}</strong>
              </div>
              <div className="tlg-entry-vacancy-mini">
                <span>Confirmed teams {core.confirmed_teams}</span>
                <span>Maximum draw {core.draw_size} teams</span>
                <span>Looking for partner {hub.marketplace.length}</span>
              </div>
            </div>
            <p className="tlg-entry-passive-note">
              AI doubles interest is sampled only from AI players already entered in this exact singles tournament:
              about 40% of qualification players and 15% of main-draw players. High-tier events may use a limited
              last-minute fill when genuine doubles places remain.
            </p>
          </div>
        </section>

        <section className="tlg-detail-panel">
          <header className="tlg-detail-panel-head tlg-entry-lifecycle-head">
            <div>
              <span>Tournament schedule</span>
              <h2>Competition window</h2>
            </div>
          </header>

          {detail?.schedule_slots?.length ? (
            <div className="tlg-detail-schedule-list tlg-detail-schedule-list-expanded">
              {detail.schedule_slots.map((slot) => {
                const dayPlan = buildDoublesDayPlan(slot, draw)
                return (
                  <article key={slot.season_week + '-' + slot.phase} className="tlg-detail-schedule-card">
                    <div className="tlg-detail-schedule-card-head">
                      <div>
                        <span>{phaseLabel(slot.phase)}</span>
                        <strong>{MONTHS[slot.calendar_month - 1]?.name ?? 'Month ' + slot.calendar_month} · Week {slot.month_week} · Season Week {slot.season_week}</strong>
                      </div>
                      <p>{formatCompetitionWeekRange(slot.season_week)} · Monday–Sunday</p>
                    </div>

                    <div className="tlg-detail-day-strip" role="table" aria-label={phaseLabel(slot.phase) + ' doubles day schedule'}>
                      {dayPlan.map((item) => (
                        <div
                          key={item.day}
                          className={'tlg-detail-day-tile tlg-detail-day-tile-' + item.kind}
                          role="row"
                        >
                          <span role="cell">Day {item.day}</span>
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
              <strong>Tournament schedule is loading</strong>
              <p>Doubles uses the same official competition weeks and venue as singles.</p>
            </div>
          )}

          <p className="tlg-detail-schedule-note">
            Doubles shares the tournament venue and calendar with singles. Match times are assigned through the unified
            scheduling engine so a player cannot be scheduled for singles and doubles at the same time, and the required
            recovery interval is preserved.
          </p>
        </section>

        <section className="tlg-detail-panel">
          <header className="tlg-detail-panel-head">
            <div><span>Your doubles entry</span><h2>Partner & entry status</h2></div>
          </header>

          <div className="tlg-doubles-my-status">
            <div>
              <span className={`tlg-doubles-status-chip status-${hub.player_status}`}>{statusLabel(hub.player_status)}</span>
              {hub.my_team ? (
                <>
                  <h3>{hub.my_team.partner_name}</h3>
                  <p>
                    Partner · {hub.my_team.partner_doubles_points.toLocaleString()} doubles points
                    {hub.my_team.seed_number ? ` · Seed #${hub.my_team.seed_number}` : ''}
                  </p>
                </>
              ) : listingActive ? (
                <>
                  <h3>Your player is visible in this tournament's partner marketplace</h3>
                  <p>Only managers looking for a partner for {tournament.name} can see and invite you here.</p>
                </>
              ) : (
                <>
                  <h3>No doubles partnership yet</h3>
                  <p>You can advertise for this tournament or directly invite a player who is already looking.</p>
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
                  <UserPlus size={15} /> {busyKey === 'listing-on' ? 'Adding…' : 'Look for a Partner'}
                </button>
              )}
              {!hasLiveTeam && listingActive && (
                <button type="button" className="tlg-detail-secondary-button" disabled={!timeline.can_cancel_listing || busyKey !== null} onClick={() => void setLooking(false)}>
                  <UserMinus size={15} /> {busyKey === 'listing-off' ? 'Removing…' : 'Stop Looking'}
                </button>
              )}
              {hasLiveTeam && (
                <button type="button" className="tlg-detail-secondary-button" disabled={busyKey !== null} onClick={() => void withdrawTeam()}>
                  <UserMinus size={15} />
                  {busyKey === 'withdraw-team'
                    ? 'Processing…'
                    : core.draw_published || timeline.draw_locked
                      ? 'Withdraw Doubles Team'
                      : 'Leave Partnership'}
                </button>
              )}
            </div>
          </div>

          {error && <div className="tlg-detail-inline-error"><XCircle size={14} /> {error}</div>}
        </section>

        {hub.incoming_invitations.length > 0 && (
          <section className="tlg-detail-panel">
            <header className="tlg-detail-panel-head">
              <div><span>Action required</span><h2>Doubles invitations</h2></div>
            </header>
            <div className="tlg-doubles-invitations">
              {hub.incoming_invitations.map((invitation) => (
                <article key={invitation.id}>
                  <div className="tlg-doubles-invite-player">
                    <CountryFlag countryCode={invitation.country_code} width={24} height={16} />
                    <div>
                      <strong>{invitation.partner_name}</strong>
                      <span>{invitation.doubles_points.toLocaleString()} doubles points · expires {formatMoment(invitation.expires_at_game)}</span>
                    </div>
                  </div>
                  <div className="tlg-doubles-invite-actions">
                    <button type="button" className="tlg-detail-primary-button" disabled={!timeline.can_respond_invitation || busyKey !== null} onClick={() => void respond(invitation.id,true)}>
                      <CheckCircle2 size={14} /> Accept
                    </button>
                    <button type="button" className="tlg-detail-secondary-button" disabled={!timeline.can_respond_invitation || busyKey !== null} onClick={() => void respond(invitation.id,false)}>
                      Decline
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
              <div><span>Pending</span><h2>Invitations you sent</h2></div>
            </header>
            <div className="tlg-doubles-outgoing">
              {hub.outgoing_invitations.map((invitation) => (
                <article key={invitation.id}>
                  <CountryFlag countryCode={invitation.country_code} width={24} height={16} />
                  <div>
                    <strong>{invitation.partner_name}</strong>
                    <span>Waiting for response · deadline {formatMoment(invitation.expires_at_game)}</span>
                  </div>
                  <button type="button" className="tlg-detail-secondary-button" disabled={busyKey !== null} onClick={() => void cancelInvitation(invitation.id)}>
                    Cancel
                  </button>
                </article>
              ))}
            </div>
          </section>
        )}

        <section className="tlg-detail-panel">
          <header className="tlg-detail-panel-head">
            <div><span>Tournament-specific marketplace</span><h2>Players looking for a partner</h2></div>
          </header>

          <p className="tlg-doubles-market-note">
            Human managers appear here only after choosing “Look for a Partner” for {tournament.name}.
            AI candidates are selected only from players already applied to or entered in this same singles tournament,
            with qualifying and lower-ranked entrants receiving priority. Listings never carry over to another event.
          </p>

          {hub.marketplace.length === 0 ? (
            <div className="tlg-doubles-empty">
              <strong>No available partner listings right now</strong>
              <p>Managers can join this marketplace until {formatMoment(timeline.registration_deadline)}.</p>
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
                        <strong>{partner.first_name} {partner.last_name}{partner.is_me ? ' · You' : ''}</strong>
                        <span>{partner.playing_style}{partner.surface_match ? ` · Prefers ${tournament.surface}` : partner.preferred_surface ? ` · Prefers ${partner.preferred_surface}` : ''}</span>
                      </div>
                    </div>
                    <div className="tlg-doubles-market-metrics">
                      <span><small>Doubles</small><b>{rankLabel(partner.doubles_rank,partner.doubles_points)}</b></span>
                      <span><small>Singles</small><b>{rankLabel(partner.singles_rank,partner.singles_points)}</b></span>
                      <span><small>At this event</small><b>{singlesParticipationLabel(partner.singles_participation)}</b></span>
                      <span><small>Doubles history</small><b>{partner.doubles_events} events · {partner.doubles_titles} titles</b></span>
                    </div>
                    <div className="tlg-doubles-market-action">
                      {partner.is_me ? (
                        <span className="tlg-doubles-you-chip">Your listing</span>
                      ) : pending ? (
                        <button type="button" className="tlg-detail-secondary-button" disabled onClick={() => undefined}>Invitation pending</button>
                      ) : (
                        <button type="button" className="tlg-detail-primary-button" disabled={!canInvite || busyKey !== null} onClick={() => void invite(partner.player_id)}>
                          <Send size={14} /> {busyKey === `invite-${partner.player_id}` ? 'Sending…' : 'Invite'}
                        </button>
                      )}
                    </div>
                  </article>
                )
              })}
            </div>
          )}
        </section>

        <section className="tlg-detail-panel">
          <header className="tlg-detail-panel-head">
            <div><span>Entry field</span><h2>Confirmed teams & alternates</h2></div>
          </header>

          {hub.teams.length === 0 ? (
            <div className="tlg-doubles-empty">
              <strong>No partnerships confirmed yet</strong>
              <p>Teams appear here immediately after an invitation is accepted.</p>
            </div>
          ) : (
            <div className="tlg-doubles-team-list">
              {hub.teams.map((team, index) => (
                <article key={team.id}>
                  <span className="tlg-doubles-team-order">{team.seed_number ? `#${team.seed_number}` : index + 1}</span>
                  <div>
                    <strong>{team.player1_name} / {team.player2_name}</strong>
                    <span>{team.combined_doubles_points.toLocaleString()} established doubles points · entry strength {team.entry_strength.toLocaleString()}</span>
                  </div>
                  <span className={`tlg-doubles-entry-chip status-${team.status}`}>{statusLabel(team.status)}</span>
                </article>
              ))}
            </div>
          )}
        </section>

        {core.draw_published && draw.length > 0 && (
          <section className="tlg-detail-panel">
            <header className="tlg-detail-panel-head">
              <div><span>Official doubles draw</span><h2>Matches & schedule</h2></div>
            </header>
            <div className="tlg-doubles-draw-list">
              {draw.map((match) => {
                const isOwnMatch = isPlayerInDoublesMatch(match, player?.id)

                return (
                  <div key={match.match_id} className={'tlg-doubles-draw-match-block' + (isOwnMatch ? ' is-own-match' : '')}>
                    <article className={'tlg-doubles-draw-match status-' + match.match_status}>
                      <div>
                        <span>{match.round_label} · Match #{match.match_number}{isOwnMatch ? ' · Your match' : ''}</span>
                        <strong>{teamName(match.team1_player1_first_name,match.team1_player1_last_name,match.team1_player2_first_name,match.team1_player2_last_name)}</strong>
                        <b>vs</b>
                        <strong>{teamName(match.team2_player1_first_name,match.team2_player1_last_name,match.team2_player2_first_name,match.team2_player2_last_name)}</strong>
                      </div>
                      <small>{doublesScheduleLabel(match)}</small>
                    </article>
                    {isOwnMatch && player?.id && match.match_status !== 'bye' && match.match_status !== 'cancelled' && (
                      <DoublesMatchTacticPanel matchId={match.match_id} currentPlayerId={player.id} />
                    )}
                  </div>
                )
              })}
            </div>
          </section>
        )}

        <section className="tlg-detail-panel">
          <header className="tlg-detail-panel-head">
            <div><span>Doubles rewards</span><h2>Ranking points & prize money</h2></div>
          </header>
          <div className="tlg-doubles-rules-strip">
            <span>Team prize is split 50/50.</span>
            <span>Doubles fatigue ≈ {Math.round(core.fatigue_multiplier * 100)}% of singles.</span>
            <span>Equipment wear ≈ {Math.round(core.equipment_wear_multiplier * 100)}% of singles.</span>
            <span>Minimum recovery: {Math.round(core.minimum_recovery_minutes / 60)} hours.</span>
          </div>
          <div className="tlg-detail-rewards-table tlg-doubles-rewards-table">
            <div className="tlg-detail-rewards-row tlg-detail-rewards-head">
              <span>Finishing stage</span><span>Points each</span><span>Team prize</span><span>Per player</span>
            </div>
            {(core.reward_rows ?? []).map((row) => (
              <div key={row.stage_code} className="tlg-detail-rewards-row">
                <strong>{row.stage_label}</strong>
                <span>{row.ranking_points.toLocaleString()} pts</span>
                <span>{formatMoney(row.team_prize_usd)}</span>
                <span>{formatMoney(row.player_prize_usd)}</span>
              </div>
            ))}
          </div>
        </section>
      </div>
    </GameLayout>
  )
}
