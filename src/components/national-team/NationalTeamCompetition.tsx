import {
  CalendarDays,
  CheckCircle2,
  Coins,
  LockKeyhole,
  MapPin,
  MessageCircle,
  Send,
  ShieldCheck,
  Trophy,
  UsersRound,
  XCircle,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../common/CountryFlag'
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

interface CompetitionHub {
  available: boolean
  game_day: number
  season_number: number
  association_id: string
  association_name: string
  country_code: string
  world: 'ATP' | 'WTA'
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

interface ChatRow {
  message_id: string
  player_id: string
  player_name: string
  game_absolute_day: number
  message: string
  created_at: string
  is_mine: boolean
}

type SlotCode = LineupSlot['slot_code']

const SLOT_LABELS: Array<{ code: SlotCode; label: string; discipline: string }> = [
  { code: 'S1', label: 'Singles Slot 1', discipline: 'Singles' },
  { code: 'S2', label: 'Singles Slot 2', discipline: 'Singles' },
  { code: 'D1A', label: 'Doubles Player A', discipline: 'Doubles' },
  { code: 'D1B', label: 'Doubles Player B', discipline: 'Doubles' },
  { code: 'S3', label: 'Singles Slot 3', discipline: 'Singles' },
  { code: 'S4', label: 'Singles Slot 4', discipline: 'Singles' },
]

const MONTH_LENGTHS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function formatAbsoluteDay(absoluteDay?: number | null) {
  if (absoluteDay === null || absoluteDay === undefined || absoluteDay < 0) return '—'
  const season = Math.floor(absoluteDay / 366) + 1
  let remaining = absoluteDay % 366
  let month = 0
  while (month < MONTH_LENGTHS.length - 1 && remaining >= MONTH_LENGTHS[month]) {
    remaining -= MONTH_LENGTHS[month]
    month += 1
  }
  return `Season ${season} · ${remaining + 1} ${MONTH_NAMES[month]}`
}

function money(value?: number | null) {
  return `$${Number(value ?? 0).toLocaleString()}`
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

function callupStatusLabel(status: string | null) {
  if (!status) return 'Not invited'
  if (status === 'accepted') return 'Accepted'
  if (status === 'declined') return 'Declined'
  if (status === 'pending') return 'Awaiting response'
  if (status === 'withdrawn') return 'Withdrawn'
  if (status === 'expired') return 'Expired'
  return titleCase(status)
}

export default function NationalTeamCompetition() {
  const { player } = useAuth()
  const [hub, setHub] = useState<CompetitionHub | null>(null)
  const [standings, setStandings] = useState<StandingRow[]>([])
  const [selectedFixtureId, setSelectedFixtureId] = useState<string | null>(null)
  const [detail, setDetail] = useState<FixtureDetail | null>(null)
  const [chat, setChat] = useState<ChatRow[]>([])
  const [chatDraft, setChatDraft] = useState('')
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

    const [hubResult, standingsResult, chatResult] = await Promise.all([
      supabase.rpc('get_my_national_team_competition_v1'),
      supabase.rpc('get_my_national_division_standings_v1'),
      supabase.rpc('get_my_national_team_chat_v1', { p_limit: 100 }),
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
    setChat(chatResult.error ? [] : ((chatResult.data ?? []) as ChatRow[]))
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
        setError(`This call-up cannot be accepted until the conflicting commitment is resolved: ${blocking}.`)
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

  async function sendChat() {
    const value = chatDraft.trim()
    if (!value) return

    setWorking(true)
    setError(null)
    const { error: rpcError } = await supabase.rpc('send_national_team_chat_message_v1', {
      p_message: value,
    })

    if (rpcError) setError(rpcError.message)
    else {
      setChatDraft('')
      const { data } = await supabase.rpc('get_my_national_team_chat_v1', { p_limit: 100 })
      setChat((data ?? []) as ChatRow[])
    }
    setWorking(false)
  }

  const pendingFixture = useMemo(
    () => hub?.fixtures.find((fixture) => fixture.my_callup?.status === 'pending') ?? null,
    [hub],
  )

  if (loading) {
    return <section className="tlg-v2-panel nt-competition-loading">Loading national competition data…</section>
  }

  if (!hub?.available) {
    return (
      <section className="tlg-v2-panel nt-placeholder">
        National competition data becomes available after your national association membership is created.
      </section>
    )
  }

  return (
    <div className="nt-competition-layout">
      {pendingFixture?.my_callup && (
        <section className="tlg-v2-panel nt-callup-alert">
          <div className="nt-callup-alert-copy">
            <span>NATIONAL-TEAM CALL-UP</span>
            <h3>
              {hub.association_name} vs {pendingFixture.opponent_name}
            </h3>
            <p>
              {formatAbsoluteDay(pendingFixture.tie_start_absolute_day)} · {pendingFixture.host_city}, {pendingFixture.host_country_code}
              {' · '}Expected appearance payment {money(pendingFixture.expected_appearance_fee_usd)}
            </p>
            <small>Response deadline: {formatAbsoluteDay(pendingFixture.response_deadline_absolute_day)}</small>
          </div>
          <div className="nt-callup-actions">
            <button type="button" className="accept" disabled={working} onClick={() => void respondCallup(pendingFixture.my_callup!.id, true)}>
              <CheckCircle2 size={15} /> Accept
            </button>
            <button type="button" className="decline" disabled={working} onClick={() => void respondCallup(pendingFixture.my_callup!.id, false)}>
              <XCircle size={15} /> Decline
            </button>
          </div>
        </section>
      )}

      {error && <div className="nt-alert nt-alert-error">{error}</div>}
      {message && <div className="nt-alert nt-alert-success">{message}</div>}

      <div className="nt-competition-main-grid">
        <div className="nt-competition-primary">
          <section className="tlg-v2-panel nt-window-panel">
            <header className="nt-section-header">
              <div><span>NATIONAL CALENDAR</span><h3>National-team windows</h3></div>
              <CalendarDays size={22} />
            </header>
            <p className="nt-section-copy">
              Windows are visible well before play so tournament planning can account for national-team weeks. Accepted call-ups become hard calendar commitments.
            </p>

            <div className="nt-window-list">
              {hub.windows.map((window) => (
                <article key={window.id}>
                  <div>
                    <span>{window.status === 'planned' ? 'Scheduled window' : titleCase(window.status)}</span>
                    <strong>{window.label}</strong>
                    <small>Season {window.season_number} · Week {window.season_week}</small>
                  </div>
                  <div>
                    <span>Window</span>
                    <strong>{formatAbsoluteDay(window.start_absolute_day)}</strong>
                    <small>through {formatAbsoluteDay(window.end_absolute_day)}</small>
                  </div>
                  <div>
                    <span>Fixture announcement target</span>
                    <strong>{formatAbsoluteDay(window.announcement_absolute_day)}</strong>
                    <small>approximately 45 game days before the window</small>
                  </div>
                </article>
              ))}
            </div>
          </section>

          <section className="tlg-v2-panel nt-fixtures-panel">
            <header className="nt-section-header">
              <div><span>FIXTURES</span><h3>National ties</h3></div>
              <Trophy size={22} />
            </header>

            {hub.fixtures.length === 0 ? (
              <div className="nt-placeholder">
                <CalendarDays size={20} />
                <div>
                  <strong>No announced fixture yet</strong>
                  <span>The national windows are reserved. Division pairings are announced automatically when the announcement date arrives.</span>
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
                      <small>{formatAbsoluteDay(fixture.tie_start_absolute_day)}</small>
                      <strong>vs {fixture.opponent_name}</strong>
                      <em>{fixture.host_city} · {titleCase(fixture.surface)} · {titleCase(fixture.status)}</em>
                    </span>
                    {fixture.my_callup?.status && <b className={`callup-${fixture.my_callup.status}`}>{callupStatusLabel(fixture.my_callup.status)}</b>}
                  </button>
                ))}
              </div>
            )}
          </section>

          {detailLoading && <section className="tlg-v2-panel nt-competition-loading">Loading selected fixture…</section>}

          {detail && !detailLoading && (
            <>
              <section className="tlg-v2-panel nt-fixture-detail">
                <header className="nt-section-header">
                  <div>
                    <span>SELECTED TIE</span>
                    <h3>{detail.fixture.home_name} vs {detail.fixture.away_name}</h3>
                  </div>
                  <ShieldCheck size={22} />
                </header>

                <div className="nt-fixture-meta">
                  <div><MapPin size={15} /><span>Host</span><strong>{detail.fixture.host_city}, {detail.fixture.host_country_code}</strong></div>
                  <div><CalendarDays size={15} /><span>Dates</span><strong>{formatAbsoluteDay(detail.fixture.tie_start_absolute_day)} – {formatAbsoluteDay(detail.fixture.tie_end_absolute_day)}</strong></div>
                  <div><Coins size={15} /><span>Appearance payment</span><strong>{money(detail.fixture.expected_appearance_fee_usd)}</strong></div>
                  <div><Trophy size={15} /><span>Tie score</span><strong>{detail.fixture.home_match_wins} – {detail.fixture.away_match_wins}</strong></div>
                </div>

                {detail.fixture.central_event_key && (
                  <div className="nt-central-event-note">
                    Centralized event · players remain in one host location between ties and normal fatigue carries into the next tie.
                  </div>
                )}

                <div className="nt-format-strip">
                  <span>1</span><strong>Singles</strong>
                  <span>2</span><strong>Singles</strong>
                  <span>3</span><strong>Doubles</strong>
                  <span>4</span><strong>Singles</strong>
                  <span>5</span><strong>Singles</strong>
                </div>
                <p className="nt-rule-note">
                  First to three match wins takes the tie. Once the tie is decided, remaining dead rubbers are cancelled to avoid unnecessary fatigue and injury exposure.
                </p>
              </section>

              {detail.is_captain && (
                <section className="tlg-v2-panel nt-captain-desk">
                  <header className="nt-section-header">
                    <div><span>CAPTAIN DESK</span><h3>Call-ups & five-player squad</h3></div>
                    <UsersRound size={22} />
                  </header>

                  <div className="nt-captain-deadlines">
                    <div><span>Call-up response deadline</span><strong>{formatAbsoluteDay(detail.fixture.response_deadline_absolute_day)}</strong></div>
                    <div><span>Squad nomination deadline</span><strong>{formatAbsoluteDay(detail.fixture.squad_deadline_absolute_day)}</strong></div>
                  </div>

                  <div className="nt-eligible-callups">
                    {detail.eligible_members.map((member) => (
                      <article key={member.player_id}>
                        <div>
                          <strong>{memberName(member)}</strong>
                          <small>{member.rank_position ? `World #${member.rank_position}` : 'Unranked'} · {member.national_appearances} national appearance{member.national_appearances === 1 ? '' : 's'}</small>
                        </div>
                        <span className={`callup-status status-${member.callup_status ?? 'none'}`}>{callupStatusLabel(member.callup_status)}</span>
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
                      <div><span>FINAL SQUAD</span><strong>{squadSelection.length} / 5 selected</strong></div>
                      <small>Only players who accepted can be nominated. Four are required for four different singles slots; a fifth player can remain reserve.</small>
                    </div>
                    <div className="nt-squad-options">
                      {detail.eligible_members.filter((member) => member.accepted).map((member) => {
                        const selected = squadSelection.includes(member.player_id)
                        return (
                          <label key={member.player_id} className={selected ? 'selected' : ''}>
                            <input type="checkbox" checked={selected} onChange={() => toggleSquadPlayer(member.player_id)} disabled={!selected && squadSelection.length >= 5} />
                            <span><strong>{memberName(member)}</strong><small>{member.rank_position ? `#${member.rank_position}` : 'Unranked'}</small></span>
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
                    <div><span>HIDDEN LINEUP</span><h3>Submit match roles privately</h3></div>
                    <LockKeyhole size={22} />
                  </header>
                  <p className="nt-section-copy">
                    Four different players must fill the four singles slots. A player may additionally play doubles, but nobody can play two singles matches in the same tie.
                  </p>

                  <div className="nt-lineup-grid">
                    {SLOT_LABELS.map((slot) => (
                      <label key={slot.code}>
                        <span>{slot.label}<small>{slot.discipline}</small></span>
                        <select
                          value={lineupDraft[slot.code]}
                          disabled={detail.our_lineup_status === 'locked' || detail.our_lineup_status === 'auto_locked'}
                          onChange={(event) => setLineupDraft((current) => ({ ...current, [slot.code]: event.target.value }))}
                        >
                          <option value="">Select player</option>
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
                    <span>Lineup status: <strong>{detail.our_lineup_status ? titleCase(detail.our_lineup_status) : 'Not submitted'}</strong></span>
                    {detail.our_lineup_status !== 'locked' && detail.our_lineup_status !== 'auto_locked' && (
                      <>
                        <button type="button" disabled={working || Object.values(lineupDraft).some((value) => !value)} onClick={() => void saveLineup()}>
                          Save private lineup
                        </button>
                        <button type="button" className="lock" disabled={working || detail.our_lineup.length !== 6} onClick={() => void lockLineup()}>
                          <LockKeyhole size={14} /> Lock lineup
                        </button>
                      </>
                    )}
                  </div>
                </section>
              )}

              <section className="tlg-v2-panel nt-reveal-panel">
                <header className="nt-section-header">
                  <div><span>LINEUP REVEAL</span><h3>{detail.lineups_revealed ? 'Both lineups revealed' : 'Opponent lineup hidden'}</h3></div>
                  <LockKeyhole size={22} />
                </header>

                <div className="nt-lineup-compare">
                  <div>
                    <span>{detail.association.name}</span>
                    {detail.our_lineup.length === 0 ? <small>No lineup submitted yet.</small> : detail.our_lineup.map((slot) => (
                      <div key={slot.slot_code}><b>{slot.slot_code}</b><strong>{slot.first_name} {slot.last_name}</strong></div>
                    ))}
                  </div>
                  <div className={!detail.lineups_revealed ? 'hidden' : ''}>
                    <span>{detail.fixture.opponent_name}</span>
                    {!detail.lineups_revealed ? (
                      <div className="nt-hidden-lineup"><LockKeyhole size={20} /><strong>Hidden until simultaneous reveal</strong></div>
                    ) : detail.opponent_lineup.map((slot) => (
                      <div key={slot.slot_code}><b>{slot.slot_code}</b><strong>{slot.first_name} {slot.last_name}</strong></div>
                    ))}
                  </div>
                </div>
              </section>

              {detail.matches.length > 0 && (
                <section className="tlg-v2-panel nt-match-order">
                  <header className="nt-section-header">
                    <div><span>MATCH ORDER</span><h3>Five-match national tie</h3></div>
                    <Trophy size={22} />
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
                            <small>{match.discipline === 'doubles' ? 'Doubles' : 'Singles'} · {titleCase(match.status)}</small>
                            <strong>{playerNames(match.home_players)} vs {playerNames(match.away_players)}</strong>
                          </div>
                          {match.winner_association_id && <b>Completed</b>}
                          {isMine && route && match.status === 'scheduled' && (
                            <Link to={route}>Open my match controls</Link>
                          )}
                        </article>
                      )
                    })}
                  </div>
                  <p className="nt-rule-note">
                    The captain controls selection and doubles pairing only. Each human player keeps control of their own tactics, equipment and match strategy in the normal match interface.
                  </p>
                </section>
              )}
            </>
          )}

          <section className="tlg-v2-panel nt-standings-panel">
            <header className="nt-section-header">
              <div><span>DIVISION</span><h3>National standings</h3></div>
              <Trophy size={22} />
            </header>

            {standings.length === 0 ? (
              <div className="nt-placeholder">Division standings will appear after the association has an active national division entry.</div>
            ) : (
              <div className="nt-standings-table">
                <div className="head"><span>#</span><span>Country</span><span>Ties</span><span>W–L</span><span>Matches</span><span>Pts</span></div>
                {standings.map((row) => (
                  <div key={row.association_id} className={row.is_my_association ? 'mine' : ''}>
                    <strong>{row.rank_position}</strong>
                    <span className="country"><CountryFlag countryCode={row.country_code} countryName={row.country_code} width={21} height={14} /> {row.association_name}</span>
                    <span>{row.ties_played}</span>
                    <span>{row.ties_won}–{row.ties_lost}</span>
                    <span>{row.matches_won}–{row.matches_lost}</span>
                    <strong>{row.standings_points}</strong>
                  </div>
                ))}
              </div>
            )}
          </section>
        </div>

        <aside className="nt-competition-side">
          <section className="tlg-v2-panel nt-cash-treasury">
            <header className="nt-section-header">
              <div><span>ASSOCIATION CASH</span><h3>{money(detail?.treasury.cash_balance_usd ?? hub.treasury?.cash_balance_usd)}</h3></div>
              <Coins size={22} />
            </header>
            <p>
              Federation grants, competition income and future sponsorships fund national travel, accommodation and symbolic player appearance payments.
            </p>
            <div className="nt-cash-summary">
              <div><span>Lifetime income</span><strong>{money(detail?.treasury.lifetime_cash_income_usd ?? hub.treasury?.lifetime_cash_income_usd)}</strong></div>
              <div><span>Lifetime spent</span><strong>{money(detail?.treasury.lifetime_cash_spent_usd ?? hub.treasury?.lifetime_cash_spent_usd)}</strong></div>
            </div>
            {(detail?.treasury.recent_transactions ?? []).length > 0 && (
              <div className="nt-finance-mini-list">
                {(detail?.treasury.recent_transactions ?? []).slice(0, 6).map((item) => (
                  <div key={item.id}>
                    <span>{item.description}</span>
                    <strong className={item.amount_usd >= 0 ? 'positive' : 'negative'}>
                      {item.amount_usd >= 0 ? '+' : ''}{money(item.amount_usd)}
                    </strong>
                  </div>
                ))}
              </div>
            )}
            <small>Activation and renewal game coins remain separate from this cash treasury.</small>
          </section>

          <section className="tlg-v2-panel nt-team-chat">
            <header className="nt-section-header">
              <div><span>PRIVATE TEAM CHAT</span><h3>Association room</h3></div>
              <MessageCircle size={22} />
            </header>
            <p>Only eligible association members can read or post here. Use it for call-ups, doubles pairing and national strategy.</p>

            <div className="nt-chat-stream">
              {chat.length === 0 ? (
                <div className="nt-chat-empty">No messages yet.</div>
              ) : [...chat].reverse().map((row) => (
                <article key={row.message_id} className={row.is_mine ? 'mine' : ''}>
                  <header><strong>{row.player_name}</strong><span>Game day {row.game_absolute_day}</span></header>
                  <p>{row.message}</p>
                </article>
              ))}
            </div>

            <div className="nt-chat-compose">
              <textarea
                value={chatDraft}
                maxLength={1000}
                placeholder="Message your national association…"
                onChange={(event) => setChatDraft(event.target.value)}
              />
              <button type="button" disabled={working || !chatDraft.trim()} onClick={() => void sendChat()}>
                <Send size={15} /> Send
              </button>
            </div>
          </section>
        </aside>
      </div>
    </div>
  )
}
