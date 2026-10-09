import {
  ArrowDown,
  CalendarDays,
  CheckCircle2,
  Coins,
  Globe2,
  LockKeyhole,
  MapPin,
  Trophy,
  XCircle,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { Link } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import { useLocalization } from '../../i18n/LocalizationProvider'
import CountryFlag from '../common/CountryFlag'
import NationalCompetitionDivisions from './NationalCompetitionDivisions'
import { nationalCountryName } from '../../lib/nationalCountryName'
import { supabase } from '../../lib/supabase'

interface NationalWindow {
  id: string
  season_number: number
  window_code: string
  label: string
  season_week: number
  start_absolute_day: number
  end_absolute_day: number
  announcement_absolute_day: number
  callup_deadline_absolute_day: number
  squad_deadline_absolute_day: number
  status: string
  window_number: number
  window_mode: 'friendly_only' | 'official_mixed'
  competition_phase: string
  official_from_season: number
  allows_friendlies: boolean
}

interface CallupSummary {
  id: string
  status: string
  expected_compensation_usd: number
  response_deadline_absolute_day: number
}

interface FixtureSummary {
  id: string
  window_id: string
  status: string
  opponent_name: string
  opponent_country_code: string
  host_city: string
  host_country_code: string
  surface: string
  environment: string
  central_event_key: string | null
  tie_start_absolute_day: number
  tie_end_absolute_day: number
  response_deadline_absolute_day: number
  squad_deadline_absolute_day: number
  lineup_deadline_game_second: number
  expected_appearance_fee_usd: number
  home_match_wins: number
  away_match_wins: number
  winner_association_id: string | null
  is_captain_fixture: boolean
  my_callup: CallupSummary | null
  my_squad_member: boolean
}

interface PyramidAssociation {
  association_id: string
  name: string
  country_code: string
  placement_state: 'projected' | 'official'
}

interface PyramidDivision {
  division_id: string
  region_code: string
  division_code: string
  label: string
  tier_level: number
  capacity: number
  promotion_slots: number
  relegation_slots: number
  is_global: boolean
  associations: PyramidAssociation[]
}

interface PyramidData {
  world: 'ATP' | 'WTA'
  display_season: number
  official_launch_season: number
  divisions: PyramidDivision[]
}

interface ProjectedEntry {
  division_id?: string
  division_code?: string
  label?: string
  region_code?: string
  tier_level?: number
  season_number?: number
  placement_state?: 'projected' | 'official'
}

interface CompetitionHub {
  available: boolean
  game_day: number
  season_number: number
  association_id: string
  association_name: string
  country_code: string
  world: 'ATP' | 'WTA'
  official_launch_season: number
  season_mode: 'association_building' | 'official'
  competition_label: string
  pyramid_display_season: number
  season_notice: string
  pyramid: PyramidData
  projected_entry: ProjectedEntry
  is_captain: boolean
  is_member: boolean
  windows: NationalWindow[]
  fixtures: FixtureSummary[]
  my_callups: CallupSummary[]
  treasury: {
    cash_balance_usd: number
    lifetime_cash_income_usd: number
    lifetime_cash_spent_usd: number
  } | null
}

interface EligibleMember {
  player_id: string
  first_name: string
  last_name: string
  rank_position: number | null
  callup_id: string | null
  callup_status: string | null
  response_deadline_absolute_day: number | null
  accepted: boolean
  national_appearances: number
  national_singles_wins: number
  national_doubles_wins: number
}

interface SquadMember {
  player_id: string
  first_name: string
  last_name: string
  rank_position: number | null
}

interface LineupSlot {
  slot_code: 'S1' | 'S2' | 'D1A' | 'D1B' | 'S3' | 'S4'
  discipline: 'singles' | 'doubles'
  player_id: string
  first_name: string
  last_name: string
}

interface MatchPlayers {
  player1_id?: string
  player1_name?: string
  player2_id?: string
  player2_name?: string
}

interface FixtureMatch {
  slot_id: string
  slot_order: number
  discipline: 'singles' | 'doubles'
  status: string
  winner_association_id: string | null
  engine_match_id: string | null
  engine_doubles_match_id: string | null
  home_players: MatchPlayers
  away_players: MatchPlayers
}

interface FinanceTransaction {
  id: string
  game_absolute_day: number
  category: string
  amount_usd: number
  balance_after_usd: number
  description: string
}

interface FixtureDetail {
  fixture: {
    id: string
    status: string
    home_association_id: string
    home_name: string
    home_country_code: string
    away_association_id: string
    away_name: string
    away_country_code: string
    opponent_name: string
    opponent_country_code: string
    host_city: string
    host_country_code: string
    surface: string
    environment: string
    central_event_key: string | null
    tie_start_absolute_day: number
    tie_end_absolute_day: number
    response_deadline_absolute_day: number
    squad_deadline_absolute_day: number
    lineup_deadline_game_second: number
    expected_appearance_fee_usd: number
    home_match_wins: number
    away_match_wins: number
    winner_association_id: string | null
    engine_competition_id: string | null
  }
  window: {
    id: string
    label: string
    season_number: number
    season_week: number
    start_absolute_day: number
    end_absolute_day: number
    status: string
  }
  association: {
    id: string
    name: string
    country_code: string
  }
  is_captain: boolean
  lineups_revealed: boolean
  eligible_members: EligibleMember[]
  squad: SquadMember[]
  our_lineup_status: 'draft' | 'locked' | 'auto_locked' | null
  our_lineup: LineupSlot[]
  opponent_lineup: LineupSlot[]
  matches: FixtureMatch[]
  treasury: {
    cash_balance_usd?: number
    lifetime_cash_income_usd?: number
    lifetime_cash_spent_usd?: number
    recent_transactions?: FinanceTransaction[]
  }
}

interface FriendlyMarketAssociation {
  listing_id: string
  association_id: string
  association_name: string
  country_code: string
}

interface FriendlyListingState {
  id: string
  status: string
}

interface FriendlyTieSlot {
  slot: number
  label: string
  available: boolean
  my_listing: FriendlyListingState | null
  market: FriendlyMarketAssociation[]
}

interface FriendlyInvitation {
  id: string
  tie_slot: number
  status: string
  inviter_association_id?: string
  inviter_association_name?: string
  invitee_association_id?: string
  invitee_association_name?: string
  country_code: string
  pairing_deadline_absolute_day: number
}

interface FriendlyWindow {
  window_id: string
  label: string
  season_number: number
  season_week: number
  start_absolute_day: number
  end_absolute_day: number
  pairing_deadline_absolute_day: number
  tie_slots: FriendlyTieSlot[]
  incoming_invitations: FriendlyInvitation[]
  outgoing_invitations: FriendlyInvitation[]
}

interface FriendlyHub {
  available: boolean
  association_id?: string
  is_captain: boolean
  windows: FriendlyWindow[]
}

type CompetitionView = 'divisions' | 'ties' | 'calendar' | 'friendlies' | 'how'

interface StandingRow {
  rank_position: number
  association_id: string
  association_name: string
  country_code: string
  ties_played: number
  ties_won: number
  ties_lost: number
  matches_won: number
  matches_lost: number
  standings_points: number
  is_my_association: boolean
}

type SlotCode = LineupSlot['slot_code']

const SLOT_CODES: SlotCode[] = ['S1', 'S2', 'D1A', 'D1B', 'S3', 'S4']

const MONTH_LENGTHS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

function formatAbsoluteDay(t: TFunction, absoluteDay?: number | null) {
  if (absoluteDay === null || absoluteDay === undefined || absoluteDay < 0) return '—'
  const season = Math.floor(absoluteDay / 366) + 1
  let remaining = absoluteDay % 366
  let month = 0
  while (month < MONTH_LENGTHS.length - 1 && remaining >= MONTH_LENGTHS[month]) {
    remaining -= MONTH_LENGTHS[month]
    month += 1
  }
  const months = t('nationalTeamPage.monthsShort', { returnObjects: true }) as string[]
  return `${t('nationalTeamPage.common.season', { season })} · ${remaining + 1} ${months[month]}`
}

function titleCase(value: string) {
  return value.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function memberName(member: Pick<EligibleMember, 'first_name' | 'last_name'>) {
  return `${member.first_name} ${member.last_name}`.trim()
}

function playerNames(players: MatchPlayers) {
  return [players.player1_name, players.player2_name].filter(Boolean).join(' + ') || 'TBD'
}

function callupStatusLabel(t: TFunction, status: string | null) {
  if (!status) return t('nationalTeamPage.competition.callupStatus.none')
  return t(`nationalTeamPage.competition.callupStatus.${status}`, { defaultValue: titleCase(status) })
}

function regionLabel(t: TFunction, code: string) {
  return t(`nationalTeamPage.competition.regions.${code}`, { defaultValue: code })
}

function windowModeLabel(t: TFunction, window: NationalWindow) {
  return t(`nationalTeamPage.competition.windowModes.${window.window_mode}`)
}

export default function NationalTeamCompetition() {
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()
  const money = (value?: number | null) => formatCurrency(Number(value ?? 0), 'USD')
  const { player } = useAuth()
  const [hub, setHub] = useState<CompetitionHub | null>(null)
  const [standings, setStandings] = useState<StandingRow[]>([])
  const [competitionView, setCompetitionView] = useState<CompetitionView>('divisions')
  const [friendlyHub, setFriendlyHub] = useState<FriendlyHub | null>(null)
  const [selectedFixtureId, setSelectedFixtureId] = useState<string | null>(null)
  const [detail, setDetail] = useState<FixtureDetail | null>(null)
  const [squadSelection, setSquadSelection] = useState<string[]>([])
  const [lineupDraft, setLineupDraft] = useState<Record<SlotCode, string>>({
    S1: '', S2: '', D1A: '', D1B: '', S3: '', S4: '',
  })
  const [loading, setLoading] = useState(true)
  const [detailLoading, setDetailLoading] = useState(false)
  const [working, setWorking] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const loadBase = useCallback(async () => {
    setLoading(true)
    setError(null)

    const [hubResult, standingsResult, friendlyResult] = await Promise.all([
      supabase.rpc('get_my_national_team_competition_v2'),
      supabase.rpc('get_my_national_division_standings_v1'),
      supabase.rpc('get_my_national_team_friendlies_v1'),
    ])

    if (hubResult.error) {
      setHub(null)
      setError(hubResult.error.message)
    } else {
      const nextHub = hubResult.data as CompetitionHub
      setHub(nextHub)
      setSelectedFixtureId((current) => {
        if (current && nextHub.fixtures.some((fixture) => fixture.id === current)) return current
        const pending = nextHub.fixtures.find((fixture) => fixture.my_callup?.status === 'pending')
        return pending?.id ?? nextHub.fixtures[0]?.id ?? null
      })
    }

    setStandings(standingsResult.error ? [] : ((standingsResult.data ?? []) as StandingRow[]))
    setFriendlyHub(friendlyResult.error ? null : ((friendlyResult.data ?? null) as FriendlyHub | null))
    setLoading(false)
  }, [])

  const loadDetail = useCallback(async (fixtureId: string | null) => {
    if (!fixtureId) {
      setDetail(null)
      return
    }

    setDetailLoading(true)
    const { data, error: detailError } = await supabase.rpc('get_national_team_fixture_detail_v1', {
      p_fixture_id: fixtureId,
    })
    setDetailLoading(false)

    if (detailError || !data) {
      setDetail(null)
      setError(detailError?.message ?? 'Unable to load national-team fixture.')
      return
    }

    setDetail(data as FixtureDetail)
  }, [])

  useEffect(() => {
    void loadBase()
  }, [loadBase])

  useEffect(() => {
    void loadDetail(selectedFixtureId)
  }, [loadDetail, selectedFixtureId])

  useEffect(() => {
    if (!detail) return

    setSquadSelection(detail.squad.map((member) => member.player_id))

    const next: Record<SlotCode, string> = {
      S1: '', S2: '', D1A: '', D1B: '', S3: '', S4: '',
    }
    detail.our_lineup.forEach((slot) => {
      next[slot.slot_code] = slot.player_id
    })
    setLineupDraft(next)
  }, [detail?.fixture.id, detail?.our_lineup_status, detail?.lineups_revealed])

  async function refreshAll() {
    await loadBase()
    await loadDetail(selectedFixtureId)
  }

  async function respondCallup(callupId: string, accept: boolean) {
    setWorking(true)
    setError(null)
    setMessage(null)

    const { data, error: rpcError } = await supabase.rpc('respond_national_team_callup_v1', {
      p_callup_id: callupId,
      p_accept: accept,
    })

    if (rpcError) {
      setError(rpcError.message)
    } else {
      const result = data as { status?: string; availability?: { reason?: string; blocking_tournament?: string } } | null
      if (result?.status === 'blocked') {
        const blocking = result.availability?.blocking_tournament ?? result.availability?.reason ?? 'calendar conflict'
        setError(t('nationalTeamPage.competition.callupConflict', { blocking }))
      } else {
        setMessage(accept
          ? 'Call-up accepted. The national window is now locked in your calendar and normal overlapping tournament commitments will be blocked.'
          : 'Call-up declined. The captain may invite another eligible player.')
        await refreshAll()
      }
    }

    setWorking(false)
  }

  async function sendCallup(playerId: string) {
    if (!detail) return
    setWorking(true)
    setError(null)
    setMessage(null)

    const { error: rpcError } = await supabase.rpc('send_national_team_callup_v1', {
      p_fixture_id: detail.fixture.id,
      p_player_id: playerId,
    })

    if (rpcError) setError(rpcError.message)
    else {
      setMessage('Call-up sent. The player can accept or decline voluntarily.')
      await refreshAll()
    }
    setWorking(false)
  }

  function toggleSquadPlayer(playerId: string) {
    setSquadSelection((current) => {
      if (current.includes(playerId)) return current.filter((id) => id !== playerId)
      if (current.length >= 5) return current
      return [...current, playerId]
    })
  }

  async function saveSquad() {
    if (!detail) return
    setWorking(true)
    setError(null)
    setMessage(null)

    const { error: rpcError } = await supabase.rpc('set_national_team_squad_v1', {
      p_fixture_id: detail.fixture.id,
      p_player_ids: squadSelection,
    })

    if (rpcError) setError(rpcError.message)
    else {
      setMessage(`${squadSelection.length}-player national squad saved. Only accepted call-ups can be nominated.`)
      await refreshAll()
    }
    setWorking(false)
  }

  async function saveLineup() {
    if (!detail) return
    setWorking(true)
    setError(null)
    setMessage(null)

    const { error: rpcError } = await supabase.rpc('save_national_team_lineup_v1', {
      p_fixture_id: detail.fixture.id,
      p_s1: lineupDraft.S1,
      p_s2: lineupDraft.S2,
      p_d1a: lineupDraft.D1A,
      p_d1b: lineupDraft.D1B,
      p_s3: lineupDraft.S3,
      p_s4: lineupDraft.S4,
    })

    if (rpcError) setError(rpcError.message)
    else {
      setMessage('Lineup saved privately. The opponent cannot see it before simultaneous reveal.')
      await refreshAll()
    }
    setWorking(false)
  }

  async function lockLineup() {
    if (!detail) return
    setWorking(true)
    setError(null)
    setMessage(null)

    const { error: rpcError } = await supabase.rpc('lock_national_team_lineup_v1', {
      p_fixture_id: detail.fixture.id,
    })

    if (rpcError) setError(rpcError.message)
    else {
      setMessage('Lineup locked. It remains hidden until the opponent also locks or the deadline is processed.')
      await refreshAll()
    }
    setWorking(false)
  }

  async function toggleFriendlyListing(windowId: string, tieSlot: number, looking: boolean) {
    setWorking(true)
    setError(null)
    setMessage(null)

    const { error: rpcError } = await supabase.rpc('set_national_team_friendly_listing_v1', {
      p_window_id: windowId,
      p_tie_slot: tieSlot,
      p_looking: looking,
    })

    if (rpcError) setError(rpcError.message)
    else {
      setMessage(looking ? 'Your national team is now looking for a friendly in this tie slot.' : 'Friendly listing removed.')
      await loadBase()
    }
    setWorking(false)
  }

  async function inviteFriendly(windowId: string, tieSlot: number, associationId: string) {
    setWorking(true)
    setError(null)
    setMessage(null)

    const { error: rpcError } = await supabase.rpc('send_national_team_friendly_invitation_v1', {
      p_window_id: windowId,
      p_tie_slot: tieSlot,
      p_invitee_association_id: associationId,
    })

    if (rpcError) setError(rpcError.message)
    else {
      setMessage('Friendly invitation sent to the other national captain.')
      await loadBase()
    }
    setWorking(false)
  }

  async function respondFriendly(invitationId: string, accept: boolean) {
    setWorking(true)
    setError(null)
    setMessage(null)

    const { error: rpcError } = await supabase.rpc('respond_national_team_friendly_invitation_v1', {
      p_invitation_id: invitationId,
      p_accept: accept,
    })

    if (rpcError) setError(rpcError.message)
    else {
      setMessage(accept ? t('nationalTeamPage.competition.friendlyConfirmed') : t('nationalTeamPage.competition.friendlyDeclined'))
      await refreshAll()
    }
    setWorking(false)
  }

  const pendingFixture = useMemo(
    () => hub?.fixtures.find((fixture) => fixture.my_callup?.status === 'pending') ?? null,
    [hub],
  )

  if (loading) {
    return <section className="tlg-v2-panel nt-competition-loading">{t('nationalTeamPage.competition.loading')}</section>
  }

  if (!hub?.available) {
    return (
      <section className="tlg-v2-panel nt-placeholder">
        {t('nationalTeamPage.competition.unavailable')}
      </section>
    )
  }

  const globalDivisions = hub.pyramid?.divisions?.filter((division) => division.is_global) ?? []
  const regionalDivisions = hub.pyramid?.divisions?.filter((division) => !division.is_global) ?? []
  const regionCodes = ['EUROPE', 'AMERICAS', 'ASIA_OCEANIA', 'AFRICA']
  const seasonNumbers = Array.from(new Set(hub.windows.map((window) => window.season_number))).sort((a, b) => a - b)

  return (
    <div className="nt-competition-layout">
      <section className={`tlg-v2-panel nt-competition-launch ${hub.season_mode === 'association_building' ? 'building' : 'official'}`}>
        <div className="nt-competition-launch-copy">
          <span>{hub.competition_label}</span>
          <h3>
            {hub.season_mode === 'association_building'
              ? t('nationalTeamPage.competition.seasonBuilding')
              : t('nationalTeamPage.competition.seasonOfficial', { season: hub.season_number })}
          </h3>
          <p>{hub.season_notice}</p>
        </div>
        <div className="nt-competition-launch-meta">
          <div>
            <span>{t('nationalTeamPage.competition.officialLaunch')}</span>
            <strong>{t('nationalTeamPage.common.season', { season: hub.official_launch_season })}</strong>
          </div>
          <div>
            <span>{t('nationalTeamPage.competition.annualWindows')}</span>
            <strong>4</strong>
          </div>
          <div>
            <span>{t('nationalTeamPage.competition.currentAssociation')}</span>
            <strong>{hub.association_name}</strong>
          </div>
        </div>
      </section>

      {pendingFixture?.my_callup && (
        <section className="tlg-v2-panel nt-callup-alert">
          <div className="nt-callup-alert-copy">
            <span>{t('nationalTeamPage.competition.callup')}</span>
            <h3>
              {nationalCountryName(hub.country_code, hub.association_name)} vs {nationalCountryName(pendingFixture.opponent_country_code, pendingFixture.opponent_name)}
            </h3>
            <p>
              {formatAbsoluteDay(t, pendingFixture.tie_start_absolute_day)} · {pendingFixture.host_city}, {pendingFixture.host_country_code}
              {' · '}{t('nationalTeamPage.competition.appearancePayment', { amount: money(pendingFixture.expected_appearance_fee_usd) })}
            </p>
            <small>{t('nationalTeamPage.competition.responseDeadline', { date: formatAbsoluteDay(t, pendingFixture.response_deadline_absolute_day) })}</small>
          </div>
          <div className="nt-callup-actions">
            <button type="button" className="accept" disabled={working} onClick={() => void respondCallup(pendingFixture.my_callup!.id, true)}>
              <CheckCircle2 size={15} /> {t('nationalTeamPage.competition.accept')}
            </button>
            <button type="button" className="decline" disabled={working} onClick={() => void respondCallup(pendingFixture.my_callup!.id, false)}>
              <XCircle size={15} /> {t('nationalTeamPage.competition.decline')}
            </button>
          </div>
        </section>
      )}

      {error && <div className="nt-alert nt-alert-error">{error}</div>}
      {message && <div className="nt-alert nt-alert-success">{message}</div>}

      <nav className="nt-competition-subtabs" aria-label={t('nationalTeamPage.competition.tabsAria')}>
        {([
          ['divisions', t('nationalTeamPage.competition.tabs.divisions')],
          ['ties', t('nationalTeamPage.competition.tabs.ties')],
          ['calendar', t('nationalTeamPage.competition.tabs.calendar')],
          ['friendlies', t('nationalTeamPage.competition.tabs.friendlies')],
          ['how', t('nationalTeamPage.competition.tabs.how')],
        ] as Array<[CompetitionView, string]>).map(([key, label]) => (
          <button
            key={key}
            type="button"
            className={competitionView === key ? 'active' : ''}
            onClick={() => setCompetitionView(key)}
          >
            {label}
          </button>
        ))}
      </nav>

      <div className={`nt-competition-main-grid view-${competitionView}`}>
        <div className="nt-competition-primary">
          {competitionView === 'divisions' && <NationalCompetitionDivisions />}

          <section className="tlg-v2-panel nt-pyramid-panel">
            <header className="nt-section-header">
              <div>
                <span>{t('nationalTeamPage.competition.pyramid')}</span>
                <h3>{t('nationalTeamPage.competition.pyramidTitle', { season: hub.pyramid_display_season })}</h3>
              </div>
            </header>

            <p className="nt-section-copy">
              {t('nationalTeamPage.competition.pyramidBody')}
            </p>

            {hub.projected_entry?.label && (
              <div className="nt-pyramid-entry">
                <CountryFlag countryCode={hub.country_code} countryName={hub.country_code} width={24} height={16} />
                <div>
                  <span>{hub.projected_entry.placement_state === 'official' ? t('nationalTeamPage.competition.currentEntry') : t('nationalTeamPage.competition.projectedEntry')}</span>
                  <strong>{nationalCountryName(hub.country_code, hub.association_name)} → {hub.projected_entry.label}</strong>
                </div>
              </div>
            )}

            <div className="nt-pyramid-global">
              {globalDivisions.map((division) => (
                <article key={division.division_id}>
                  <div className="nt-pyramid-division-head">
                    <Globe2 size={14} />
                    <div>
                      <span>{t('nationalTeamPage.competition.tier', { tier: division.tier_level })}</span>
                      <strong>{division.label}</strong>
                    </div>
                    <small>{division.associations.length}/{division.capacity}</small>
                  </div>
                  <div className="nt-pyramid-associations">
                    {division.associations.length === 0 ? (
                      <span className="empty">{t('nationalTeamPage.competition.noActivePlaced')}</span>
                    ) : division.associations.map((association) => (
                      <span key={association.association_id} className="nt-pyramid-team">
                        <CountryFlag countryCode={association.country_code} countryName={association.country_code} width={20} height={14} />
                        {nationalCountryName(association.country_code, association.name)}
                      </span>
                    ))}
                  </div>
                </article>
              ))}
            </div>

            <div className="nt-pyramid-flow">
              <ArrowDown size={17} />
              <span>{t('nationalTeamPage.competition.promotionFlow')}</span>
            </div>

            <div className="nt-pyramid-regions">
              {regionCodes.map((region) => {
                const divisions = regionalDivisions
                  .filter((division) => division.region_code === region)
                  .sort((a, b) => a.tier_level - b.tier_level)

                return (
                  <div key={region} className="nt-pyramid-region">
                    <h4>{regionLabel(t, region)}</h4>
                    {divisions.map((division) => (
                      <article key={division.division_id}>
                        <div className="nt-pyramid-division-head">
                          <div>
                            <span>{t('nationalTeamPage.competition.tier', { tier: division.tier_level })}</span>
                            <strong>{division.label.replace(`${regionLabel(t, region)} `, '')}</strong>
                          </div>
                          <small>{division.associations.length}/{division.capacity}</small>
                        </div>
                        <div className="nt-pyramid-associations">
                          {division.associations.length === 0 ? (
                            <span className="empty">{t('nationalTeamPage.competition.noActiveAssociations')}</span>
                          ) : division.associations.map((association) => (
                            <span key={association.association_id} className="nt-pyramid-team">
                              <CountryFlag countryCode={association.country_code} countryName={association.country_code} width={20} height={14} />
                              {nationalCountryName(association.country_code, association.name)}
                            </span>
                          ))}
                        </div>
                      </article>
                    ))}
                  </div>
                )
              })}
            </div>
          </section>

          <section className="tlg-v2-panel nt-window-panel">
            <header className="nt-section-header">
              <div><span>{t('nationalTeamPage.competition.calendar')}</span><h3>{t('nationalTeamPage.competition.windows')}</h3></div>
            </header>
            <p className="nt-section-copy">
              {t('nationalTeamPage.competition.windowsBody')}
            </p>

            <div className="nt-window-seasons">
              {seasonNumbers.map((seasonNumber) => {
                const windows = hub.windows.filter((window) => window.season_number === seasonNumber)
                const friendlySeason = seasonNumber < hub.official_launch_season

                return (
                  <section key={seasonNumber} className="nt-window-season">
                    <div className="nt-window-season-head">
                      <div>
                        <span>{t('nationalTeamPage.competition.seasonLabel', { season: seasonNumber })}</span>
                        <strong>{friendlySeason ? t('nationalTeamPage.competition.friendlyProgramme') : t('nationalTeamPage.competition.officialCalendar')}</strong>
                      </div>
                      <small>{friendlySeason ? 'No standings · no promotion/relegation' : 'Official results affect the pyramid'}</small>
                    </div>

                    <div className="nt-window-list">
                      {windows.map((window) => (
                        <article key={window.id}>
                          <div>
                            <span>{windowModeLabel(t, window)} · {window.status === 'planned' ? 'Scheduled' : titleCase(window.status)}</span>
                            <strong>{window.label}</strong>
                            <small>Week {window.season_week} · {window.competition_phase}</small>
                          </div>
                          <div>
                            <span>{t('nationalTeamPage.competition.matchWindow')}</span>
                            <strong>{formatAbsoluteDay(t, window.start_absolute_day)}</strong>
                            <small>through {formatAbsoluteDay(t, window.end_absolute_day)}</small>
                          </div>
                          <div>
                            <span>{t('nationalTeamPage.competition.announcementTarget')}</span>
                            <strong>{formatAbsoluteDay(t, window.announcement_absolute_day)}</strong>
                            <small>Call-ups close {formatAbsoluteDay(window.callup_deadline_absolute_day)}</small>
                          </div>
                        </article>
                      ))}
                    </div>
                  </section>
                )
              })}
            </div>
          </section>

          <section className="tlg-v2-panel nt-fixtures-panel">
            <header className="nt-section-header">
              <div><span>{t('nationalTeamPage.competition.fixtures')}</span><h3>{t('nationalTeamPage.competition.tiesTitle')}</h3></div>
            </header>

            {hub.fixtures.length === 0 ? (
              <div className="nt-placeholder">
                <CalendarDays size={20} />
                <div>
                  <strong>{hub.season_mode === 'association_building' ? 'No friendly opponent available yet' : 'No announced fixture yet'}</strong>
                  <span>
                    {hub.season_mode === 'association_building'
                      ? 'Season 1 windows are reserved for captain-arranged friendly ties. Use the Friendlies section to publish availability or invite another active association.'
                      : 'Official pairings are announced automatically when the relevant national window reaches its announcement date.'}
                  </span>
                </div>
              </div>
            ) : (
              <div className="nt-fixture-list">
                {hub.fixtures.map((fixture) => (
                  <button
                    type="button"
                    key={fixture.id}
                    className={fixture.id === selectedFixtureId ? 'active' : ''}
                    onClick={() => setSelectedFixtureId(fixture.id)}
                  >
                    <CountryFlag countryCode={fixture.opponent_country_code} countryName={fixture.opponent_country_code} width={28} height={19} />
                    <span>
                      <small>{formatAbsoluteDay(t, fixture.tie_start_absolute_day)}</small>
                      <strong>vs {nationalCountryName(fixture.opponent_country_code, fixture.opponent_name)}</strong>
                      <em>{fixture.host_city} · {titleCase(fixture.surface)} · {titleCase(fixture.status)}</em>
                    </span>
                    {fixture.my_callup?.status && <b className={`callup-${fixture.my_callup.status}`}>{callupStatusLabel(fixture.my_callup.status)}</b>}
                  </button>
                ))}
              </div>
            )}
          </section>

          {detailLoading && <section className="tlg-v2-panel nt-competition-loading">{t('nationalTeamPage.competition.fixtureLoading')}</section>}

          {detail && !detailLoading && (
            <>
              <section className="tlg-v2-panel nt-fixture-detail">
                <header className="nt-section-header">
                  <div>
                    <span>{t('nationalTeamPage.competition.selectedTie')}</span>
                    <h3>{nationalCountryName(detail.fixture.home_country_code, detail.fixture.home_name)} vs {nationalCountryName(detail.fixture.away_country_code, detail.fixture.away_name)}</h3>
                  </div>
                </header>

                <div className="nt-fixture-meta">
                  <div><MapPin size={15} /><span>{t('nationalTeamPage.competition.host')}</span><strong>{detail.fixture.host_city}, {detail.fixture.host_country_code}</strong></div>
                  <div><CalendarDays size={15} /><span>{t('nationalTeamPage.competition.dates')}</span><strong>{formatAbsoluteDay(t, detail.fixture.tie_start_absolute_day)} – {formatAbsoluteDay(t, detail.fixture.tie_end_absolute_day)}</strong></div>
                  <div><Coins size={15} /><span>{t('nationalTeamPage.competition.appearancePaymentLabel')}</span><strong>{money(detail.fixture.expected_appearance_fee_usd)}</strong></div>
                  <div><Trophy size={15} /><span>{t('nationalTeamPage.competition.tieScore')}</span><strong>{detail.fixture.home_match_wins} – {detail.fixture.away_match_wins}</strong></div>
                </div>

                {detail.fixture.central_event_key && (
                  <div className="nt-central-event-note">
                    Centralized event · players remain in one host location between ties and normal fatigue carries into the next tie.
                  </div>
                )}

                <div className="nt-format-strip">
                  <span>1</span><strong>{t('nationalTeamPage.competition.singles')}</strong>
                  <span>2</span><strong>{t('nationalTeamPage.competition.singles')}</strong>
                  <span>3</span><strong>{t('nationalTeamPage.competition.doubles')}</strong>
                  <span>4</span><strong>{t('nationalTeamPage.competition.singles')}</strong>
                  <span>5</span><strong>{t('nationalTeamPage.competition.singles')}</strong>
                </div>
                <p className="nt-rule-note">
                  First to three match wins takes the tie. Once the tie is decided, remaining dead rubbers are cancelled to avoid unnecessary fatigue and injury exposure.
                </p>
              </section>

              {detail.is_captain && (
                <section className="tlg-v2-panel nt-captain-desk">
                  <header className="nt-section-header">
                    <div><span>{t('nationalTeamPage.competition.captainDesk')}</span><h3>{t('nationalTeamPage.competition.callupsSquad')}</h3></div>
                  </header>

                  <div className="nt-captain-deadlines">
                    <div><span>{t('nationalTeamPage.competition.callupDeadline')}</span><strong>{formatAbsoluteDay(t, detail.fixture.response_deadline_absolute_day)}</strong></div>
                    <div><span>{t('nationalTeamPage.competition.squadDeadline')}</span><strong>{formatAbsoluteDay(t, detail.fixture.squad_deadline_absolute_day)}</strong></div>
                  </div>

                  <div className="nt-eligible-callups">
                    {detail.eligible_members.map((member) => (
                      <article key={member.player_id}>
                        <div>
                          <strong>{memberName(member)}</strong>
                          <small>{member.rank_position ? `World #${member.rank_position}` : t('nationalTeamPage.competition.unranked')} · {member.national_appearances} national appearance{member.national_appearances === 1 ? '' : 's'}</small>
                        </div>
                        <span className={`callup-status status-${member.callup_status ?? 'none'}`}>{callupStatusLabel(t, member.callup_status)}</span>
                        <button
                          type="button"
                          disabled={working || member.callup_status === 'accepted' || member.callup_status === 'pending'}
                          onClick={() => void sendCallup(member.player_id)}
                        >
                          {member.callup_status === 'declined' || member.callup_status === 'expired' ? 'Invite again' : 'Send call-up'}
                        </button>
                      </article>
                    ))}
                  </div>

                  <div className="nt-squad-builder">
                    <div className="nt-squad-builder-head">
                      <div><span>{t('nationalTeamPage.competition.finalSquad')}</span><strong>{t('nationalTeamPage.competition.selectedCount', { count: squadSelection.length })}</strong></div>
                      <small>{t('nationalTeamPage.competition.finalSquadNote')}</small>
                    </div>
                    <div className="nt-squad-options">
                      {detail.eligible_members.filter((member) => member.accepted).map((member) => {
                        const selected = squadSelection.includes(member.player_id)
                        return (
                          <label key={member.player_id} className={selected ? 'selected' : ''}>
                            <input type="checkbox" checked={selected} onChange={() => toggleSquadPlayer(member.player_id)} disabled={!selected && squadSelection.length >= 5} />
                            <span><strong>{memberName(member)}</strong><small>{member.rank_position ? `#${member.rank_position}` : t('nationalTeamPage.competition.unranked')}</small></span>
                          </label>
                        )
                      })}
                    </div>
                    <button type="button" className="nt-primary-action" disabled={working || squadSelection.length < 4 || squadSelection.length > 5} onClick={() => void saveSquad()}>
                      Save nominated squad
                    </button>
                  </div>
                </section>
              )}

              {detail.is_captain && detail.squad.length >= 4 && (
                <section className="tlg-v2-panel nt-lineup-builder">
                  <header className="nt-section-header">
                    <div><span>{t('nationalTeamPage.competition.hiddenLineup')}</span><h3>{t('nationalTeamPage.competition.hiddenLineupTitle')}</h3></div>
                  </header>
                  <p className="nt-section-copy">
                    {t('nationalTeamPage.competition.hiddenLineupBody')}
                  </p>

                  <div className="nt-lineup-grid">
                    {SLOT_CODES.map((code) => (
                      <label key={code}>
                        <span>{t(`nationalTeamPage.competition.slots.${code}`)}<small>{code.startsWith('D') ? t('nationalTeamPage.competition.doubles') : t('nationalTeamPage.competition.singles')}</small></span>
                        <select
                          value={lineupDraft[code]}
                          disabled={detail.our_lineup_status === 'locked' || detail.our_lineup_status === 'auto_locked'}
                          onChange={(event) => setLineupDraft((current) => ({ ...current, [code]: event.target.value }))}
                        >
                          <option value="">{t('nationalTeamPage.competition.selectPlayer')}</option>
                          {detail.squad.map((member) => (
                            <option key={member.player_id} value={member.player_id}>
                              {member.first_name} {member.last_name}
                            </option>
                          ))}
                        </select>
                      </label>
                    ))}
                  </div>

                  <div className="nt-lineup-actions">
                    <span>{t('nationalTeamPage.competition.lineupStatus')}: <strong>{detail.our_lineup_status ? titleCase(detail.our_lineup_status) : t('nationalTeamPage.competition.notSubmitted')}</strong></span>
                    {detail.our_lineup_status !== 'locked' && detail.our_lineup_status !== 'auto_locked' && (
                      <>
                        <button type="button" disabled={working || Object.values(lineupDraft).some((value) => !value)} onClick={() => void saveLineup()}>
                          Save private lineup
                        </button>
                        <button type="button" className="lock" disabled={working || detail.our_lineup.length !== 6} onClick={() => void lockLineup()}>
                          <LockKeyhole size={14} /> {t('nationalTeamPage.competition.lockLineup')}
                        </button>
                      </>
                    )}
                  </div>
                </section>
              )}

              <section className="tlg-v2-panel nt-reveal-panel">
                <header className="nt-section-header">
                  <div><span>{t('nationalTeamPage.competition.reveal')}</span><h3>{detail.lineups_revealed ? t('nationalTeamPage.competition.bothRevealed') : t('nationalTeamPage.competition.opponentHidden')}</h3></div>
                </header>

                <div className="nt-lineup-compare">
                  <div>
                    <span>{nationalCountryName(detail.association.country_code, detail.association.name)}</span>
                    {detail.our_lineup.length === 0 ? <small>{t('nationalTeamPage.competition.noLineup')}</small> : detail.our_lineup.map((slot) => (
                      <div key={slot.slot_code}><b>{slot.slot_code}</b><strong>{slot.first_name} {slot.last_name}</strong></div>
                    ))}
                  </div>
                  <div className={!detail.lineups_revealed ? 'hidden' : ''}>
                    <span>{nationalCountryName(detail.fixture.opponent_country_code, detail.fixture.opponent_name)}</span>
                    {!detail.lineups_revealed ? (
                      <div className="nt-hidden-lineup"><LockKeyhole size={20} /><strong>{t('nationalTeamPage.competition.hiddenUntilReveal')}</strong></div>
                    ) : detail.opponent_lineup.map((slot) => (
                      <div key={slot.slot_code}><b>{slot.slot_code}</b><strong>{slot.first_name} {slot.last_name}</strong></div>
                    ))}
                  </div>
                </div>
              </section>

              {detail.matches.length > 0 && (
                <section className="tlg-v2-panel nt-match-order">
                  <header className="nt-section-header">
                    <div><span>{t('nationalTeamPage.competition.matchOrder')}</span><h3>{t('nationalTeamPage.competition.matchOrderTitle')}</h3></div>
                  </header>

                  <div className="nt-match-list">
                    {detail.matches.map((match) => {
                      const isMine = Boolean(player?.id && (
                        match.home_players.player1_id === player.id
                        || match.home_players.player2_id === player.id
                        || match.away_players.player1_id === player.id
                        || match.away_players.player2_id === player.id
                      ))
                      const route = detail.fixture.engine_competition_id
                        ? match.discipline === 'doubles'
                          ? `/game/tournaments/${detail.fixture.engine_competition_id}/doubles`
                          : `/game/tournaments/${detail.fixture.engine_competition_id}`
                        : null

                      return (
                        <article key={match.slot_id}>
                          <span className="order">{match.slot_order}</span>
                          <div>
                            <small>{match.discipline === 'doubles' ? t('nationalTeamPage.competition.doubles') : t('nationalTeamPage.competition.singles')} · {titleCase(match.status)}</small>
                            <strong>{playerNames(match.home_players)} vs {playerNames(match.away_players)}</strong>
                          </div>
                          {match.winner_association_id && <b>{t('nationalTeamPage.competition.completed')}</b>}
                          {isMine && route && match.status === 'scheduled' && (
                            <Link to={route}>{t('nationalTeamPage.competition.openControls')}</Link>
                          )}
                        </article>
                      )
                    })}
                  </div>
                  <p className="nt-rule-note">
                    {t('nationalTeamPage.competition.matchOrderNote')}
                  </p>
                </section>
              )}
            </>
          )}

          <section className="tlg-v2-panel nt-standings-panel">
            <header className="nt-section-header">
              <div><span>{t('nationalTeamPage.competition.division')}</span><h3>{hub.season_mode === 'association_building' ? t('nationalTeamPage.competition.standingsSeason2') : t('nationalTeamPage.competition.standings')}</h3></div>
            </header>

            {hub.season_mode === 'association_building' ? (
              <div className="nt-season-one-standings">
                <span>{t('nationalTeamPage.competition.season1')}</span>
                <strong>{t('nationalTeamPage.competition.noTable')}</strong>
                <p>
                  {t('nationalTeamPage.competition.noTableBody', { season: hub.official_launch_season })}
                </p>
                {hub.projected_entry?.label && (
                  <small>{t('nationalTeamPage.competition.projected', { entry: hub.projected_entry.label })}</small>
                )}
              </div>
            ) : standings.length === 0 ? (
              <div className="nt-placeholder">{t('nationalTeamPage.competition.standingsEmpty')}</div>
            ) : (
              <div className="nt-standings-table">
                <div className="head"><span>#</span><span>{t('nationalTeamPage.competition.standingsHeaders.country')}</span><span>{t('nationalTeamPage.competition.standingsHeaders.ties')}</span><span>W–L</span><span>{t('nationalTeamPage.competition.standingsHeaders.matches')}</span><span>{t('nationalTeamPage.competition.standingsHeaders.points')}</span></div>
                {standings.map((row) => (
                  <div key={row.association_id} className={row.is_my_association ? 'mine' : ''}>
                    <strong>{row.rank_position}</strong>
                    <span className="country"><CountryFlag countryCode={row.country_code} countryName={row.country_code} width={21} height={14} /> {nationalCountryName(row.country_code, row.association_name)}</span>
                    <span>{row.ties_played}</span>
                    <span>{row.ties_won}–{row.ties_lost}</span>
                    <span>{row.matches_won}–{row.matches_lost}</span>
                    <strong>{row.standings_points}</strong>
                  </div>
                ))}
              </div>
            )}
          </section>

          {competitionView === 'friendlies' && (
            <section className="tlg-v2-panel nt-friendly-market">
              <header className="nt-section-header">
                <div>
                  <span>{t('nationalTeamPage.competition.friendliesKicker')}</span>
                  <h3>{t('nationalTeamPage.competition.friendliesTitle')}</h3>
                </div>
              </header>

              <p className="nt-section-copy">
                {t('nationalTeamPage.competition.friendliesBody')}
              </p>

              {!friendlyHub?.is_captain && (
                <div className="nt-placeholder">
                  {t('nationalTeamPage.competition.friendliesCaptainOnly')}
                </div>
              )}

              <div className="nt-friendly-windows">
                {(friendlyHub?.windows ?? []).map((window) => (
                  <article key={window.window_id} className="nt-friendly-window">
                    <header>
                      <div>
                        <span>{t('nationalTeamPage.competition.seasonLabel', { season: window.season_number })} · {t('nationalTeamPage.competition.week', { week: window.season_week })}</span>
                        <strong>{window.label}</strong>
                        <small>{formatAbsoluteDay(t, window.start_absolute_day)} – {formatAbsoluteDay(t, window.end_absolute_day)}</small>
                      </div>
                      <div className="nt-friendly-deadline">
                        <span>{t('nationalTeamPage.competition.pairingDeadline')}</span>
                        <strong>{formatAbsoluteDay(t, window.pairing_deadline_absolute_day)}</strong>
                      </div>
                    </header>

                    {window.incoming_invitations.length > 0 && (
                      <div className="nt-friendly-incoming">
                        {window.incoming_invitations.map((invitation) => (
                          <div key={invitation.id}>
                            <CountryFlag countryCode={invitation.country_code} countryName={invitation.country_code} width={22} height={15} />
                            <span>
                              <strong>{nationalCountryName(invitation.country_code, invitation.inviter_association_name)}</strong>
                              <small>{t('nationalTeamPage.competition.invitedSlot', { slot: invitation.tie_slot })}</small>
                            </span>
                            <button type="button" className="accept" disabled={working} onClick={() => void respondFriendly(invitation.id, true)}>{t('nationalTeamPage.competition.accept')}</button>
                            <button type="button" className="decline" disabled={working} onClick={() => void respondFriendly(invitation.id, false)}>{t('nationalTeamPage.competition.decline')}</button>
                          </div>
                        ))}
                      </div>
                    )}

                    <div className="nt-friendly-slots">
                      {window.tie_slots.map((slot) => {
                        const listingActive = slot.my_listing?.status === 'active'
                        return (
                          <section key={slot.slot}>
                            <div className="nt-friendly-slot-head">
                              <div>
                                <span>{t('nationalTeamPage.competition.tieSlot', { slot: slot.slot })}</span>
                                <strong>{slot.label}</strong>
                              </div>
                              <span className={slot.available ? 'free' : 'occupied'}>{slot.available ? t('nationalTeamPage.competition.available') : t('nationalTeamPage.competition.occupied')}</span>
                            </div>

                            {friendlyHub?.is_captain && slot.available && (
                              <div className="nt-friendly-listing-action">
                                <span>{listingActive ? t('nationalTeamPage.competition.visibleMarket') : t('nationalTeamPage.competition.needOpponent')}</span>
                                <button
                                  type="button"
                                  disabled={working}
                                  onClick={() => void toggleFriendlyListing(window.window_id, slot.slot, !listingActive)}
                                >
                                  {listingActive ? t('nationalTeamPage.competition.stopLooking') : t('nationalTeamPage.competition.arrangeFriendly')}
                                </button>
                              </div>
                            )}

                            <div className="nt-friendly-market-list">
                              {slot.market.length === 0 ? (
                                <p>{t('nationalTeamPage.competition.noMarket')}</p>
                              ) : slot.market.map((association) => (
                                <div key={association.listing_id}>
                                  <CountryFlag countryCode={association.country_code} countryName={association.country_code} width={23} height={16} />
                                  <strong>{nationalCountryName(association.country_code, association.association_name)}</strong>
                                  {friendlyHub?.is_captain && slot.available && (
                                    <button type="button" disabled={working} onClick={() => void inviteFriendly(window.window_id, slot.slot, association.association_id)}>
                                      Invite
                                    </button>
                                  )}
                                </div>
                              ))}
                            </div>

                            {window.outgoing_invitations.filter((invite) => invite.tie_slot === slot.slot).map((invite) => (
                              <div key={invite.id} className="nt-friendly-outgoing">
                                {t('nationalTeamPage.competition.invitationPending', { name: nationalCountryName(invite.country_code, invite.invitee_association_name) })}
                              </div>
                            ))}
                          </section>
                        )
                      })}
                    </div>
                  </article>
                ))}

                {(friendlyHub?.windows ?? []).length === 0 && (
                  <div className="nt-placeholder">{t('nationalTeamPage.competition.noFutureWindows')}</div>
                )}
              </div>
            </section>
          )}

          {competitionView === 'how' && (
            <section className="tlg-v2-panel nt-competition-how">
              <header className="nt-section-header">
                <div>
                  <span>{t('nationalTeamPage.competition.howKicker')}</span>
                  <h3>{t('nationalTeamPage.competition.howTitle')}</h3>
                </div>
              </header>

              <div className="nt-how-grid">
                <article>
                  <span>{t('nationalTeamPage.competition.howCards.season1K')}</span>
                  <strong>{t('nationalTeamPage.competition.howCards.season1T')}</strong>
                  <p>{t('nationalTeamPage.competition.howCards.season1B')}</p>
                </article>
                <article>
                  <span>{t('nationalTeamPage.competition.howCards.bootstrapK')}</span>
                  <strong>{t('nationalTeamPage.competition.howCards.bootstrapT')}</strong>
                  <p>{t('nationalTeamPage.competition.howCards.bootstrapB')}</p>
                </article>
                <article>
                  <span>{t('nationalTeamPage.competition.howCards.afterK')}</span>
                  <strong>{t('nationalTeamPage.competition.howCards.afterT')}</strong>
                  <p>{t('nationalTeamPage.competition.howCards.afterB')}</p>
                </article>
                <article>
                  <span>{t('nationalTeamPage.competition.howCards.q1K')}</span>
                  <strong>{t('nationalTeamPage.competition.howCards.q1T')}</strong>
                  <p>{t('nationalTeamPage.competition.howCards.q1B')}</p>
                </article>
                <article>
                  <span>{t('nationalTeamPage.competition.howCards.wg1K')}</span>
                  <strong>{t('nationalTeamPage.competition.howCards.wg1T')}</strong>
                  <p>{t('nationalTeamPage.competition.howCards.wg1B')}</p>
                </article>
                <article>
                  <span>{t('nationalTeamPage.competition.howCards.wg2K')}</span>
                  <strong>{t('nationalTeamPage.competition.howCards.wg1T')}</strong>
                  <p>{t('nationalTeamPage.competition.howCards.wg2B')}</p>
                </article>
                <article>
                  <span>{t('nationalTeamPage.competition.howCards.regionalK')}</span>
                  <strong>{t('nationalTeamPage.competition.howCards.regionalT')}</strong>
                  <p>{t('nationalTeamPage.competition.howCards.regionalB')}</p>
                </article>
                <article>
                  <span>{t('nationalTeamPage.competition.howCards.windowK')}</span>
                  <strong>{t('nationalTeamPage.competition.howCards.windowT')}</strong>
                  <p>{t('nationalTeamPage.competition.howCards.windowB')}</p>
                </article>
                <article>
                  <span>{t('nationalTeamPage.competition.howCards.final8K')}</span>
                  <strong>{t('nationalTeamPage.competition.howCards.final8T')}</strong>
                  <p>{t('nationalTeamPage.competition.howCards.final8B')}</p>
                </article>
              </div>
            </section>
          )}
        </div>

      </div>
    </div>
  )
}
