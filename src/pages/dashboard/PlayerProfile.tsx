import { ArrowLeft, Mail, UserRound } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Link, useLocation, useNavigate, useParams } from 'react-router'

import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import usePlayerAvatarUrl from '../../hooks/usePlayerAvatarUrl'
import { supabase } from '../../lib/supabase'
import '../../styles/player-public-profile.css'
import '../../styles/player-public-profile-avatar.css'
import '../../styles/player-private-life-profile.css'

interface PlayerProfileRow {
  player_id: string
  first_name: string
  last_name: string
  world: 'ATP' | 'WTA'
  country_code: string
  home_city: string | null
  image_path: string | null
  preferred_surface: 'Hard' | 'Clay' | 'Grass' | null
  playing_style: 'Aggressive Baseliner' | 'Defensive Baseliner' | 'All-court' | 'Serve & Volley'
  ranking_points: number
  rank_position: number
  is_own_player: boolean
  is_ai: boolean
}

interface TournamentSummaryItem {
  competition_id: string
  result_id?: string
  season: number
  start_week: number
  end_week: number
  tournament_name: string
  city: string
  country_code: string
  category_code: string
  category_label: string
  surface: string
  logo_url: string | null
  result_code?: string
  result_label?: string
  ranking_points_earned?: number
}

interface PlayerTournamentSummary {
  next_tournaments: TournamentSummaryItem[]
  recent_tournaments: TournamentSummaryItem[]
  best_results: TournamentSummaryItem[]
}

interface ScoutingReport {
  available: boolean
  reason?: string
  analyst_rating?: number
  estimate_margin?: number
  attributes?: Record<string, { min: number; max: number }>
  identified_strength?: string
  identified_weakness?: string
  preferred_surface?: string | null
  playing_style?: string
}

interface PrivateLifePossession {
  id: string
  category: string
  name: string
  prestige: number
  acquisition_type?: string
  city?: string | null
  country_code?: string | null
  country_name?: string | null
}

interface PrivateLifeSummary {
  player_id: string
  prestige_points: number
  asset_count: number
  asset_value: number
  possessions: PrivateLifePossession[]
}

interface PlayerProfileReturnState {
  playerProfileReturn?: string
  playerProfileReturnLabel?: string
  playerProfileReturnState?: unknown
}

const MONTH_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const MONTH_LENGTHS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const EMPTY_TOURNAMENT_SUMMARY: PlayerTournamentSummary = { next_tournaments: [], recent_tournaments: [], best_results: [] }
const EMPTY_PRIVATE_LIFE: PrivateLifeSummary = { player_id: '', prestige_points: 0, asset_count: 0, asset_value: 0, possessions: [] }
const SCOUT_LABELS: Record<string, string> = {
  serve: 'Serve', forehand: 'Forehand', backhand: 'Backhand', return_skill: 'Return', volley: 'Volley', slice: 'Slice', drop_shot: 'Drop Shot', lob: 'Lob', smash: 'Smash',
  fitness: 'Fitness', stamina: 'Stamina', recovery: 'Recovery', movement: 'Movement',
}
const PRIVATE_LIFE_CATEGORY_LABELS: Record<string, string> = {
  watch: 'Watch', jewelry: 'Jewelry', car: 'Vehicle', apartment: 'Apartment', house_villa: 'House & Villa', yacht: 'Yacht', private_jet: 'Private Jet', art: 'Art', collectible: 'Collectible',
}

function fromAbsoluteDay(value: number) {
  const season = Math.floor(value / 366) + 1
  let remaining = value % 366
  let month = 1
  for (let index = 0; index < MONTH_LENGTHS.length; index += 1) {
    if (remaining < MONTH_LENGTHS[index]) { month = index + 1; break }
    remaining -= MONTH_LENGTHS[index]
  }
  return { season, month, day: remaining + 1 }
}

function tournamentStartDate(item: TournamentSummaryItem) {
  const absolute = (item.season - 1) * 366 + 2 + (item.start_week - 1) * 7
  const day = fromAbsoluteDay(absolute)
  return `${MONTH_SHORT[day.month - 1]} ${String(day.day).padStart(2, '0')}`
}

function tournamentWeekLabel(item: TournamentSummaryItem) {
  if (item.start_week === item.end_week) return `Season ${item.season} · Week ${item.start_week}`
  return `Season ${item.season} · Weeks ${item.start_week}–${item.end_week}`
}

function money(value: number) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(Number(value || 0))
}

function TournamentRows({ items, emptyText, showResult = false, ranked = false }: { items: TournamentSummaryItem[]; emptyText: string; showResult?: boolean; ranked?: boolean }) {
  if (items.length === 0) return <div className="tlg-public-tournament-empty">{emptyText}</div>
  return (
    <div className="tlg-public-tournament-list">
      {items.map((item, index) => (
        <article className="tlg-public-tournament-row" key={item.result_id ?? item.competition_id}>
          {ranked && <strong className="tlg-public-tournament-place">{index + 1}</strong>}
          <span className="tlg-public-tournament-date">{tournamentStartDate(item)}</span>
          <div className="tlg-public-tournament-name">
            <CountryFlag countryCode={item.country_code} countryName={item.country_code} width={23} height={16} />
            <div><strong>{item.tournament_name}</strong><small>{item.city} · {tournamentWeekLabel(item)}</small></div>
          </div>
          <div className="tlg-public-tournament-meta"><span>{item.category_code}</span><small>{item.surface}</small></div>
          {showResult && <div className="tlg-public-tournament-result"><strong>{item.result_label ?? 'Completed'}</strong>{(item.ranking_points_earned ?? 0) > 0 && <small>+{item.ranking_points_earned} pts</small>}</div>}
        </article>
      ))}
    </div>
  )
}

function PrivateLifeProfileCard({ summary, loading }: { summary: PrivateLifeSummary; loading: boolean }) {
  return (
    <section className="tlg-player-private-life-card">
      <header>
        <div><span>PRIVATE LIFE</span><h2>Prestige & possessions</h2><p>Prestige is the combined point value of the physical assets this player currently owns. Sold possessions no longer contribute.</p></div>
      </header>
      {loading ? <div className="tlg-player-private-life-loading">Loading Private Life profile…</div> : (
        <>
          <div className="tlg-player-private-life-summary">
            <div className="prestige"><span>Prestige points</span><strong>{Number(summary.prestige_points || 0).toLocaleString()}</strong></div>
            <div><span>Current possessions</span><strong>{Number(summary.asset_count || 0).toLocaleString()}</strong></div>
            <div><span>Physical asset value</span><strong>{money(Number(summary.asset_value || 0))}</strong></div>
          </div>
          {summary.possessions.length ? (
            <div className="tlg-player-private-life-list">
              {summary.possessions.map((item) => (
                <article className="tlg-player-private-life-item" key={item.id}>
                  <span>{PRIVATE_LIFE_CATEGORY_LABELS[item.category] ?? item.category.replaceAll('_', ' ')}</span>
                  <strong>{item.name}</strong>
                  <small><span>{item.city ? `${item.city}${item.country_code ? `, ${item.country_code}` : ''}` : item.acquisition_type === 'starter_home' ? 'Starting residence' : 'Owned asset'}</span><b>+{item.prestige} prestige pts</b></small>
                </article>
              ))}
            </div>
          ) : <div className="tlg-player-private-life-empty">No current Private Life possessions.</div>}
        </>
      )}
    </section>
  )
}

export default function PlayerProfilePage() {
  const { playerId } = useParams()
  const location = useLocation()
  const navigate = useNavigate()
  const [profile, setProfile] = useState<PlayerProfileRow | null>(null)
  const [tournaments, setTournaments] = useState<PlayerTournamentSummary>(EMPTY_TOURNAMENT_SUMMARY)
  const [scouting, setScouting] = useState<ScoutingReport | null>(null)
  const [privateLife, setPrivateLife] = useState<PrivateLifeSummary>(EMPTY_PRIVATE_LIFE)
  const [loading, setLoading] = useState(true)
  const [tournamentsLoading, setTournamentsLoading] = useState(true)
  const [privateLifeLoading, setPrivateLifeLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [tournamentError, setTournamentError] = useState<string | null>(null)
  const [messageBusy, setMessageBusy] = useState(false)
  const avatarUrl = usePlayerAvatarUrl(profile?.image_path)
  const returnState = location.state as PlayerProfileReturnState | null
  const backTarget = returnState?.playerProfileReturn ?? '/game/rankings'
  const backLabel = returnState?.playerProfileReturnLabel ?? 'Back to Rankings'
  const backState = returnState?.playerProfileReturnState

  useEffect(() => {
    let active = true
    async function loadProfile() {
      if (!playerId) return
      setLoading(true); setTournamentsLoading(true); setPrivateLifeLoading(true); setError(null); setTournamentError(null); setScouting(null); setPrivateLife(EMPTY_PRIVATE_LIFE)
      const [profileResponse, tournamentResponse, scoutingResponse, privateLifeResponse] = await Promise.all([
        supabase.rpc('get_player_profile_v2', { p_player_id: playerId }),
        supabase.rpc('get_player_tournament_summary_v1', { p_player_id: playerId }),
        supabase.rpc('get_player_scouting_report_v1', { p_target_player_id: playerId }),
        supabase.rpc('get_player_private_life_summary_v1', { p_player_id: playerId }),
      ])
      if (!active) return
      const row = (Array.isArray(profileResponse.data) ? profileResponse.data[0] : profileResponse.data) as PlayerProfileRow | undefined
      if (profileResponse.error || !row) { setProfile(null); setError(profileResponse.error?.message ?? 'Player profile not found.') } else setProfile(row)
      if (tournamentResponse.error) { setTournaments(EMPTY_TOURNAMENT_SUMMARY); setTournamentError(tournamentResponse.error.message) } else setTournaments((tournamentResponse.data as PlayerTournamentSummary | null) ?? EMPTY_TOURNAMENT_SUMMARY)
      if (!scoutingResponse.error) setScouting(scoutingResponse.data as ScoutingReport)
      if (!privateLifeResponse.error && privateLifeResponse.data) setPrivateLife(privateLifeResponse.data as unknown as PrivateLifeSummary)
      setLoading(false); setTournamentsLoading(false); setPrivateLifeLoading(false)
    }
    void loadProfile()
    return () => { active = false }
  }, [playerId])

  async function startConversation() {
    if (!profile || profile.is_own_player || profile.is_ai || messageBusy) return
    setMessageBusy(true)
    const { data, error: conversationError } = await supabase.rpc('get_or_create_player_conversation_v1', { p_target_player_id: profile.player_id })
    setMessageBusy(false)
    if (conversationError || !data) { setError(conversationError?.message ?? 'Unable to start conversation.'); return }
    navigate(`/game/inbox?conversation=${encodeURIComponent(String(data))}`)
  }

  const name = profile ? `${profile.first_name} ${profile.last_name}` : 'Player'

  return (
    <GameLayout title="Player profile" subtitle="Professional player identity">
      <div className="tlg-public-player-page">
        <Link to={backTarget} state={backState} className="tlg-public-player-back"><ArrowLeft size={15} /> {backLabel}</Link>
        {loading ? <div className="tlg-public-player-state">Loading player profile…</div> : error && !profile ? <div className="tlg-public-player-state">{error}</div> : profile ? (
          <>
            <section className="tlg-public-player-card">
              <aside className="tlg-public-player-visual"><div className={`tlg-public-player-avatar${avatarUrl ? ' has-avatar' : ''}`}>{avatarUrl ? <img src={avatarUrl} alt={`${name} avatar`} /> : <UserRound size={72} />}</div></aside>
              <div className="tlg-public-player-main">
                <div className="tlg-public-player-heading-row">
                  <div><span className="tlg-public-player-kicker">{profile.world} singles player</span><h1>{name}</h1><div className="tlg-public-player-country"><CountryFlag countryCode={profile.country_code} countryName={profile.country_code} width={26} height={17} /><span>{profile.home_city ? `${profile.home_city}, ${profile.country_code}` : profile.country_code}</span></div></div>
                  <div className="tlg-public-player-primary-action">{profile.is_own_player ? <button type="button" onClick={() => navigate('/game/inbox')}>Open inbox</button> : !profile.is_ai ? <button type="button" onClick={startConversation} disabled={messageBusy}><Mail size={16} /> {messageBusy ? 'Opening…' : 'Send message'}</button> : null}</div>
                </div>
                <div className="tlg-public-player-stats"><article><span>World ranking</span><strong>#{profile.rank_position}</strong></article><article><span>Ranking points</span><strong>{profile.ranking_points.toLocaleString()}</strong></article><article><span>Competition world</span><strong>{profile.world}</strong></article></div>
                <div className="tlg-public-player-info">
                  <header><span>Player information</span><h2>Career overview</h2></header>
                  <div className="tlg-public-player-info-grid"><div><span>Home city</span><strong>{profile.home_city ?? 'Not set'}</strong></div><div><span>Country</span><strong>{profile.country_code}</strong></div><div><span>Preferred surface</span><strong>{profile.preferred_surface ?? 'Not set'}</strong></div><div><span>Playing style</span><strong>{profile.playing_style}</strong></div><div><span>Discipline</span><strong>Singles</strong></div><div><span>Tour</span><strong>{profile.world}</strong></div><div><span>Ranking status</span><strong>{profile.rank_position > 0 ? `Ranked #${profile.rank_position}` : 'Unranked'}</strong></div></div>
                  <p>Exact internal skills belong to the player and are private. Public results, form and career history remain visible to everyone.</p>
                </div>
                {error && <p className="tlg-public-player-error">{error}</p>}
              </div>
            </section>

            <PrivateLifeProfileCard summary={privateLife} loading={privateLifeLoading} />

            {!profile.is_own_player && (
              <section className="tlg-public-scouting-card">
                <header><div><span>PERFORMANCE ANALYSIS</span><h2>Opponent scouting report</h2><p>Exact opponent attributes are never public. A Performance Analyst converts private data into approximate scouting ranges.</p></div>{scouting?.available && <div className="accuracy"><strong>±{scouting.estimate_margin}</strong><span>estimate range</span><small>Analyst {scouting.analyst_rating}/100</small></div>}</header>
                {!scouting?.available ? <div className="tlg-public-scouting-locked"><div><strong>Detailed scouting unavailable</strong><p>{scouting?.reason ?? 'Hire a Performance Analyst to unlock opponent estimates.'}</p></div><Link to="/game/staff">Open Staff Market</Link></div> : (
                  <><div className="tlg-public-scouting-summary"><div><span>IDENTIFIED STRENGTH</span><strong>{SCOUT_LABELS[scouting.identified_strength ?? ''] ?? scouting.identified_strength}</strong></div><div><span>IDENTIFIED WEAKNESS</span><strong>{SCOUT_LABELS[scouting.identified_weakness ?? ''] ?? scouting.identified_weakness}</strong></div><div><span>KNOWN IDENTITY</span><strong>{scouting.preferred_surface} · {scouting.playing_style}</strong></div></div><div className="tlg-public-scouting-grid">{Object.entries(scouting.attributes ?? {}).map(([key, range]) => <div key={key}><span>{SCOUT_LABELS[key] ?? key}</span><strong>{range.min}–{range.max}</strong><small>estimated</small></div>)}</div></>
                )}
              </section>
            )}

            <section className="tlg-public-player-career-grid">
              <article className="tlg-public-player-career-card"><header><div><span>COMING UP</span><h2>Next tournaments</h2><p>Up to five registered tournaments that have not finished yet.</p></div></header>{tournamentsLoading ? <div className="tlg-public-tournament-empty">Loading tournament schedule…</div> : <TournamentRows items={tournaments.next_tournaments} emptyText="No upcoming registered tournaments." />}</article>
              <article className="tlg-public-player-career-card"><header><div><span>RECENT FORM</span><h2>Recent tournaments</h2><p>The player's five most recently completed tournaments.</p></div></header>{tournamentsLoading ? <div className="tlg-public-tournament-empty">Loading tournament history…</div> : <TournamentRows items={tournaments.recent_tournaments} emptyText="No completed tournaments yet." showResult />}</article>
              <article className="tlg-public-player-career-card best-results"><header><div><span>CAREER HIGHLIGHTS</span><h2>Best results</h2><p>Top five career results, weighted by tournament level and the round reached.</p></div></header>{tournamentsLoading ? <div className="tlg-public-tournament-empty">Loading best results…</div> : <TournamentRows items={tournaments.best_results} emptyText="No tournament results yet." showResult ranked />}</article>
            </section>
            {tournamentError && <p className="tlg-public-player-error tlg-public-player-tournament-error">Tournament statistics could not be loaded: {tournamentError}</p>}
          </>
        ) : null}
      </div>
    </GameLayout>
  )
}
