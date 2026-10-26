import { ArrowLeft, ChevronDown, ChevronUp, Mail, UserRound } from 'lucide-react'
import { useEffect, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { Link, useLocation, useNavigate, useParams } from 'react-router'

import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import usePlayerAvatarUrl from '../../hooks/usePlayerAvatarUrl'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { supabase } from '../../lib/supabase'
import { lifestyleCopy } from '../../lib/lifestyleCareerI18n'
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
  playing_hand: 'right' | 'left'
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
  analyst_name?: string
  estimate_margin?: number
  confidence_percent?: number
  report_stage?: 'general' | 'quick' | 'partial' | 'normal' | 'full'
  preparation_hours?: number
  attributes?: Record<string, { min: number; max: number }>
  identified_strength?: string
  identified_weakness?: string
  preferred_surface?: string | null
  playing_style?: string
  playing_hand?: 'right' | 'left'
  tactical_observations?: string[]
  recommendations?: string[]
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
  residence?: { city?: string | null; country_code?: string | null; nationality?: string | null }
}

interface PlayerProfileReturnState {
  playerProfileReturn?: string
  playerProfileReturnLabel?: string
  playerProfileReturnState?: unknown
}

const MONTH_LENGTHS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const EMPTY_TOURNAMENT_SUMMARY: PlayerTournamentSummary = { next_tournaments: [], recent_tournaments: [], best_results: [] }
const EMPTY_PRIVATE_LIFE: PrivateLifeSummary = { player_id: '', prestige_points: 0, asset_count: 0, asset_value: 0, possessions: [] }

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

function tournamentStartDate(item: TournamentSummaryItem, t: TFunction) {
  const absolute = (item.season - 1) * 366 + 2 + (item.start_week - 1) * 7
  const day = fromAbsoluteDay(absolute)
  const months = t('staffPage.months', { returnObjects: true }) as string[]
  const month = months[day.month] ?? `M${day.month}`
  return `${month} ${String(day.day).padStart(2, '0')}`
}

function tournamentWeekLabel(item: TournamentSummaryItem, t: TFunction) {
  if (item.start_week === item.end_week) return t('playerProfilePage.tournament.weekSingle', { season: item.season, week: item.start_week })
  return t('playerProfilePage.tournament.weekRange', { season: item.season, start: item.start_week, end: item.end_week })
}

function scoutLabel(value: string | null | undefined, t: TFunction) {
  if (!value) return '—'
  return t(`playerProfilePage.scouting.attributes.${value}`, { defaultValue: value.replaceAll('_', ' ') })
}

function surfaceLabel(value: string | null | undefined, t: TFunction) {
  if (!value) return t('playerProfilePage.notSet')
  return t(`playerProfilePage.surface.${value}`, { defaultValue: value })
}

function styleLabel(value: string | null | undefined, t: TFunction) {
  if (!value) return t('playerProfilePage.notSet')
  return t(`playerProfilePage.style.${value}`, { defaultValue: value })
}

function TournamentRows({ items, emptyText, showResult = false, ranked = false }: { items: TournamentSummaryItem[]; emptyText: string; showResult?: boolean; ranked?: boolean }) {
  const { t } = useTranslation()
  if (items.length === 0) return <div className="tlg-public-tournament-empty">{emptyText}</div>
  return (
    <div className="tlg-public-tournament-list">
      {items.map((item, index) => (
        <article className="tlg-public-tournament-row" key={item.result_id ?? item.competition_id}>
          {ranked && <strong className="tlg-public-tournament-place">{index + 1}</strong>}
          <span className="tlg-public-tournament-date">{tournamentStartDate(item, t)}</span>
          <div className="tlg-public-tournament-name">
            <CountryFlag countryCode={item.country_code} countryName={item.country_code} width={23} height={16} />
            <div><strong>{item.tournament_name}</strong><small>{item.city} · {tournamentWeekLabel(item, t)}</small></div>
          </div>
          <div className="tlg-public-tournament-meta"><span>{item.category_code}</span><small>{surfaceLabel(item.surface, t)}</small></div>
          {showResult && <div className="tlg-public-tournament-result"><strong>{item.result_label ?? t('playerProfilePage.tournament.completed')}</strong>{(item.ranking_points_earned ?? 0) > 0 && <small>{t('playerProfilePage.tournament.points', { points: item.ranking_points_earned })}</small>}</div>}
        </article>
      ))}
    </div>
  )
}

function PrivateLifeProfileCard({ summary, loading }: { summary: PrivateLifeSummary; loading: boolean }) {
  const { t } = useTranslation()
  const { formatCurrency, formatNumber } = useLocalization()
  const [expanded, setExpanded] = useState(false)

  useEffect(() => {
    setExpanded(false)
  }, [summary.player_id])

  const visiblePossessions = expanded ? summary.possessions : summary.possessions.slice(0, 3)
  const canExpand = summary.possessions.length > 3

  return (
    <section className="tlg-player-private-life-card">
      <header>
        <div><span>{t('playerProfilePage.privateLife.kicker')}</span><h2>{t('playerProfilePage.privateLife.title')}</h2><p>{t('playerProfilePage.privateLife.body')}</p></div>
      </header>
      {loading ? <div className="tlg-player-private-life-loading">{t('playerProfilePage.privateLife.loading')}</div> : (
        <>
          <div className="tlg-player-private-life-summary">
            <div className="prestige"><span>{t('playerProfilePage.privateLife.prestige')}</span><strong>{formatNumber(Number(summary.prestige_points || 0))}</strong></div>
            <div><span>{t('playerProfilePage.privateLife.possessions')}</span><strong>{formatNumber(Number(summary.asset_count || 0))}</strong></div>
            <div><span>{t('playerProfilePage.privateLife.value')}</span><strong>{formatCurrency(Number(summary.asset_value || 0), 'USD')}</strong></div>
          </div>
          {summary.possessions.length ? (
            <>
              <div className="tlg-player-private-life-list">
                {visiblePossessions.map((item) => (
                  <article className="tlg-player-private-life-item" key={item.id}>
                    <span>{t(`playerProfilePage.privateLife.categories.${item.category}`, { defaultValue: item.category.replaceAll('_', ' ') })}</span>
                    <strong>{item.name}</strong>
                    <small>{item.city ? `${item.city}${item.country_code ? `, ${item.country_code}` : ''}` : item.acquisition_type === 'starter_home' ? t('playerProfilePage.privateLife.startingResidence') : t('playerProfilePage.privateLife.ownedAsset')}</small>
                  </article>
                ))}
              </div>
              {canExpand && (
                <button type="button" className="tlg-player-private-life-toggle" onClick={() => setExpanded((current) => !current)}>
                  {expanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                  {expanded ? t('playerProfilePage.privateLife.showFewer') : t('playerProfilePage.privateLife.showAll', { count: summary.possessions.length })}
                </button>
              )}
            </>
          ) : <div className="tlg-player-private-life-empty">{t('playerProfilePage.privateLife.empty')}</div>}
        </>
      )}
    </section>
  )
}

export default function PlayerProfilePage() {
  const { t, i18n } = useTranslation()
  const careerCopy = lifestyleCopy(i18n.resolvedLanguage ?? i18n.language)
  const { formatNumber } = useLocalization()
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
  const backLabel = returnState?.playerProfileReturnLabel ?? t('playerProfilePage.backRankings')
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
      if (profileResponse.error || !row) { setProfile(null); setError(profileResponse.error?.message ?? t('playerProfilePage.notFound')) } else setProfile(row)
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
    if (conversationError || !data) { setError(conversationError?.message ?? t('playerProfilePage.conversationError')); return }
    navigate(`/game/inbox?conversation=${encodeURIComponent(String(data))}`)
  }

  const name = profile ? `${profile.first_name} ${profile.last_name}` : t('playerProfilePage.player')

  return (
    <GameLayout title={t('playerProfilePage.title')} subtitle={t('playerProfilePage.subtitle')}>
      <div className="tlg-public-player-page">
        <Link to={backTarget} state={backState} className="tlg-public-player-back"><ArrowLeft size={15} /> {backLabel}</Link>
        {loading ? <div className="tlg-public-player-state">{t('playerProfilePage.loading')}</div> : error && !profile ? <div className="tlg-public-player-state">{error}</div> : profile ? (
          <>
            <section className="tlg-public-player-card">
              <aside className="tlg-public-player-visual"><div className={`tlg-public-player-avatar${avatarUrl ? ' has-avatar' : ''}`}>{avatarUrl ? <img src={avatarUrl} alt={t('playerProfilePage.avatarAlt', { name })} /> : <UserRound size={72} />}</div></aside>
              <div className="tlg-public-player-main">
                <div className="tlg-public-player-heading-row">
                  <div><span className="tlg-public-player-kicker">{t('playerProfilePage.singlesPlayer', { world: profile.world })}</span><h1>{name}</h1><div className="tlg-public-player-country"><CountryFlag countryCode={profile.country_code} countryName={profile.country_code} width={26} height={17} /><span>{(privateLife.residence?.city ?? profile.home_city) ? `${privateLife.residence?.city ?? profile.home_city}, ${privateLife.residence?.country_code ?? profile.country_code}` : profile.country_code}</span></div></div>
                  <div className="tlg-public-player-primary-action">{profile.is_own_player ? <button type="button" onClick={() => navigate('/game/inbox')}>{t('playerProfilePage.openInbox')}</button> : !profile.is_ai ? <button type="button" onClick={startConversation} disabled={messageBusy}><Mail size={16} /> {messageBusy ? t('playerProfilePage.opening') : t('playerProfilePage.sendMessage')}</button> : null}</div>
                </div>
                <div className="tlg-public-player-stats"><article><span>{t('playerProfilePage.worldRanking')}</span><strong>#{profile.rank_position}</strong></article><article><span>{t('playerProfilePage.rankingPoints')}</span><strong>{formatNumber(profile.ranking_points)}</strong></article><article><span>{t('playerProfilePage.competitionWorld')}</span><strong>{profile.world}</strong></article></div>
                <div className="tlg-public-player-info">
                  <header><span>{t('playerProfilePage.information')}</span><h2>{t('playerProfilePage.careerOverview')}</h2></header>
                  <div className="tlg-public-player-info-grid"><div><span>{t('playerProfilePage.homeCity')}</span><strong>{profile.home_city ?? t('playerProfilePage.notSet')}</strong></div><div><span>{careerCopy.homeBase}</span><strong>{[privateLife.residence?.city ?? profile.home_city,privateLife.residence?.country_code ?? profile.country_code].filter(Boolean).join(', ')}</strong></div><div><span>{t('playerProfilePage.country')}</span><strong>{profile.country_code}</strong></div><div><span>{t('playerProfilePage.playingHand')}</span><strong>{profile.playing_hand === 'left' ? t('playerProfilePage.leftHanded') : t('playerProfilePage.rightHanded')}</strong></div><div><span>{t('playerProfilePage.preferredSurface')}</span><strong>{surfaceLabel(profile.preferred_surface, t)}</strong></div><div><span>{t('playerProfilePage.playingStyle')}</span><strong>{styleLabel(profile.playing_style, t)}</strong></div><div><span>{t('playerProfilePage.discipline')}</span><strong>{t('playerProfilePage.singles')}</strong></div><div><span>{t('playerProfilePage.tour')}</span><strong>{profile.world}</strong></div><div><span>{t('playerProfilePage.rankingStatus')}</span><strong>{profile.rank_position > 0 ? t('playerProfilePage.ranked', { rank: profile.rank_position }) : t('playerProfilePage.unranked')}</strong></div></div>
                  <p>{t('playerProfilePage.privacyNote')}</p>
                </div>
                {error && <p className="tlg-public-player-error">{error}</p>}
              </div>
            </section>

            <PrivateLifeProfileCard summary={privateLife} loading={privateLifeLoading} />

            {!profile.is_own_player && (
              <section className="tlg-public-scouting-card">
                <header><div><span>{t('playerProfilePage.scouting.kicker')}</span><h2>{t('playerProfilePage.scouting.title')}</h2><p>{t('playerProfilePage.scouting.body')}</p></div>{scouting?.available && <div className="accuracy"><strong>{scouting.confidence_percent ?? 0}%</strong><span>{t('playerProfilePage.scouting.report', { stage: t(`playerProfilePage.scouting.stages.${scouting.report_stage ?? 'general'}`) })}</span><small>±{scouting.estimate_margin} · {scouting.analyst_name ?? t('playerProfilePage.scouting.analyst', { rating: scouting.analyst_rating })}</small></div>}</header>
                {!scouting?.available ? <div className="tlg-public-scouting-locked"><div><strong>{t('playerProfilePage.scouting.unavailable')}</strong><p>{scouting?.reason ?? t('playerProfilePage.scouting.hireAnalyst')}</p><small>{t('playerProfilePage.scouting.known', { hand: (scouting?.playing_hand ?? profile.playing_hand) === 'left' ? t('playerProfilePage.scouting.leftHanded') : t('playerProfilePage.scouting.rightHanded'), surface: surfaceLabel(scouting?.preferred_surface ?? profile.preferred_surface, t), style: styleLabel(scouting?.playing_style ?? profile.playing_style, t) })}</small></div><Link to="/game/staff">{t('playerProfilePage.scouting.openStaff')}</Link></div> : (
                  <>
                    <div className="tlg-public-scouting-summary"><div><span>{t('playerProfilePage.scouting.strength')}</span><strong>{scoutLabel(scouting.identified_strength, t)}</strong></div><div><span>{t('playerProfilePage.scouting.weakness')}</span><strong>{scoutLabel(scouting.identified_weakness, t)}</strong></div><div><span>{t('playerProfilePage.scouting.identity')}</span><strong>{scouting.playing_hand === 'left' ? t('playerProfilePage.scouting.leftHanded') : t('playerProfilePage.scouting.rightHanded')} · {surfaceLabel(scouting.preferred_surface, t)} · {styleLabel(scouting.playing_style, t)}</strong></div></div>
                    <div className="tlg-public-scouting-progress"><span>{t('playerProfilePage.scouting.preparation')}</span><strong>{t('playerProfilePage.scouting.gameHours', { stage: t(`playerProfilePage.scouting.stages.${scouting.report_stage ?? 'general'}`), hours: Number(scouting.preparation_hours ?? 0).toFixed(1) })}</strong><small>{t('playerProfilePage.scouting.preparationBody')}</small></div>
                    <div className="tlg-public-scouting-grid">{Object.entries(scouting.attributes ?? {}).map(([key, range]) => <div key={key}><span>{scoutLabel(key, t)}</span><strong>{range.min}–{range.max}</strong><small>{t('playerProfilePage.scouting.estimated')}</small></div>)}</div>
                    {((scouting.tactical_observations?.length ?? 0) > 0 || (scouting.recommendations?.length ?? 0) > 0) && <div className="tlg-public-scouting-intelligence">
                      <div><span>{t('playerProfilePage.scouting.tendencies')}</span>{scouting.tactical_observations?.map((item) => <p key={item}>{item}</p>)}</div>
                      <div><span>{t('playerProfilePage.scouting.considerations')}</span>{scouting.recommendations?.map((item) => <p key={item}>{item}</p>)}</div>
                    </div>}
                  </>
                )}
              </section>
            )}

            <section className="tlg-public-player-career-grid">
              <article className="tlg-public-player-career-card"><header><div><span>{t('playerProfilePage.tournament.upcomingKicker')}</span><h2>{t('playerProfilePage.tournament.upcomingTitle')}</h2><p>{t('playerProfilePage.tournament.upcomingBody')}</p></div></header>{tournamentsLoading ? <div className="tlg-public-tournament-empty">{t('playerProfilePage.tournament.loadingSchedule')}</div> : <TournamentRows items={tournaments.next_tournaments} emptyText={t('playerProfilePage.tournament.noUpcoming')} />}</article>
              <article className="tlg-public-player-career-card"><header><div><span>{t('playerProfilePage.tournament.recentKicker')}</span><h2>{t('playerProfilePage.tournament.recentTitle')}</h2><p>{t('playerProfilePage.tournament.recentBody')}</p></div></header>{tournamentsLoading ? <div className="tlg-public-tournament-empty">{t('playerProfilePage.tournament.loadingHistory')}</div> : <TournamentRows items={tournaments.recent_tournaments} emptyText={t('playerProfilePage.tournament.noCompleted')} showResult />}</article>
              <article className="tlg-public-player-career-card best-results"><header><div><span>{t('playerProfilePage.tournament.bestKicker')}</span><h2>{t('playerProfilePage.tournament.bestTitle')}</h2><p>{t('playerProfilePage.tournament.bestBody')}</p></div></header>{tournamentsLoading ? <div className="tlg-public-tournament-empty">{t('playerProfilePage.tournament.loadingBest')}</div> : <TournamentRows items={tournaments.best_results} emptyText={t('playerProfilePage.tournament.noResults')} showResult ranked />}</article>
            </section>
            {tournamentError && <p className="tlg-public-player-error tlg-public-player-tournament-error">{t('playerProfilePage.tournament.loadError', { error: tournamentError })}</p>}
          </>
        ) : null}
      </div>
    </GameLayout>
  )
}
