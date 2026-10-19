import {
  Activity,
  CalendarDays,
  ChevronDown,
  ChevronRight,
  ChevronUp,
  CircleDollarSign,
  Dumbbell,
  LockKeyhole,
  Medal,
  UserRound,
  ShieldCheck,
  ShoppingBag,
  Trophy,
  Users,
} from 'lucide-react'
import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Link } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
import NextTournamentExtras from '../../components/dashboard/NextTournamentExtras'
import RealWorldTennisNews from '../../components/dashboard/RealWorldTennisNews'
import GameLayout from '../../components/layout/GameLayout'
import usePlayerAvatarUrl from '../../hooks/usePlayerAvatarUrl'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { localizeNotification } from '../../i18n/notificationLocalization'
import { supabase } from '../../lib/supabase'
import '../../styles/overview-dashboard.css'

const CATEGORY_LABELS: Record<string, string> = {
  futures_15: 'Futures 15',
  futures_25: 'Futures 25',
  challenger_50: 'Challenger 50',
  challenger_75: 'Challenger 75',
  challenger_100: 'Challenger 100',
  challenger_125: 'Challenger 125',
  tour_250: 'Tour 250',
  tour_500: 'Tour 500',
  masters_1000: 'Masters 1000',
  grand_slam_2000: 'Grand Slam',
}

type GameDay = {
  season: number
  month: number
  day: number
  absolute_day: number
  season_week: number
}

type RankingProtectionEntry = {
  contribution_id: string
  tournament_name: string
  source_result_label: string
  ranking_points: number
  expiration_season: number
  expiration_week: number
  expiration_month: number
  expiration_day: number
  days_remaining: number
  next_edition_scheduled: boolean
}

type RankingProtectionResponse = {
  premium: boolean
  locked: boolean
  contributions: RankingProtectionEntry[]
}

type SeasonStats = {
  matches: number
  wins: number
  losses: number
  win_pct: number
  titles: number
  aces: number
  winners: number
  unforced_errors: number
  total_points_won: number
}

type NextTournament = {
  competition_id: string
  tournament_name: string
  city: string
  country_code: string
  category_code: string
  surface: string
  season_week: number
  entry_status: string
  draw_type: string
} | null

type NextMatch = {
  match_id: string
  competition_id: string
  tournament_name: string
  city: string
  country_code: string
  round_label: string
  season_week: number
  day: number
  status: string
  opponent_id: string
  opponent_first_name: string
  opponent_last_name: string
  opponent_country_code: string
} | null

type MatchSet = {
  set_number: number
  player1_games: number
  player2_games: number
  player1_tiebreak_points: number | null
  player2_tiebreak_points: number | null
}

type LatestResult = {
  match_id: string
  competition_id: string
  tournament_name: string
  city: string
  country_code: string
  round_label: string
  won: boolean
  player_side: 1 | 2
  opponent_id: string
  opponent_first_name: string
  opponent_last_name: string
  opponent_country_code: string
  sets: MatchSet[]
} | null

type TodayTournament = {
  competition_id: string
  tournament_name: string
  city: string
  country_code: string
  category_code: string
  surface: string
  phase: string
  slot_order: number
}

type GameNewsItem = {
  match_id: string
  tournament_name: string
  round_label: string
  winner_id: string
  winner_first_name: string
  winner_last_name: string
  winner_country_code: string
  loser_id: string
  loser_first_name: string
  loser_last_name: string
  loser_country_code: string
}

type CareerNewsItem = {
  id: string
  notification_code: string
  title: string
  message: string
  severity: string
  route: string | null
  payload: Record<string, unknown>
  created_at: string
  read_at: string | null
}

type FinanceTransaction = {
  id: string
  amount: number
  description: string
  category: string
  subcategory: string
  game_absolute_day: number
}

type FinanceCommitment = {
  kind: string
  amount: number
  description: string
  due_absolute_day: number
}

type FinanceSummary = {
  balance: number
  season_income: number
  season_expenses: number
  season_net: number
  recent_transactions: FinanceTransaction[]
  upcoming_commitments: FinanceCommitment[]
}

type TrainingSummary = {
  activity_type: string
  eligible: boolean
  block_reason: string | null
  plan: {
    training_type?: string
    focus_attribute?: string | null
    intensity?: string
  }
  skills: {
    fatigue?: number
    sharpness?: number
    morale?: number
    confidence?: number
    focus?: number
    fitness?: number
  }
}

type EquipmentSlot = {
  condition: number
  item: {
    brand: string
    model: string
  }
} | null

type EquipmentSummary = {
  loadout: {
    racket?: EquipmentSlot
    string?: EquipmentSlot
    shoes?: EquipmentSlot
    string_tension_kg?: number
    apparel_brand?: string
  }
}

type ClubSummary = {
  club: {
    id: string
    name: string
    world_rank: number
    points: number
    member_count: number
    atp_members: number
    wta_members: number
    role: string
  } | null
  coins_balance: number
}

type OverviewDashboard = {
  game_day: GameDay
  player: {
    id: string
    world: 'ATP' | 'WTA'
    current_rank: number
    ranking_points: number
  }
  season_stats: SeasonStats
  next_match: NextMatch
  next_tournament: NextTournament
  latest_result: LatestResult
  today_tournaments: TodayTournament[]
  game_news: GameNewsItem[]
  career_news: CareerNewsItem[]
  finance: FinanceSummary
  training: TrainingSummary
  equipment: EquipmentSummary
  club: ClubSummary
  staff: {
    active_count: number
    weekly_payroll: number
  }
}

function getCountryName(code: string | undefined, localeTag: string, fallback: string) {
  if (!code) return fallback
  try {
    return new Intl.DisplayNames([localeTag], { type: 'region' }).of(code) ?? code
  } catch {
    return code
  }
}

function categoryLabel(code?: string | null) {
  if (!code) return 'Tournament'
  return CATEGORY_LABELS[code] ?? code.replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function titleCase(value?: string | null) {
  if (!value) return '—'
  return value.replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function gameDate(day: GameDay | undefined, localeTag: string, fallback: string, seasonLabel: string) {
  if (!day) return fallback
  const dateLabel = new Intl.DateTimeFormat(localeTag, { month: 'long', day: 'numeric' })
    .format(new Date(2020, Math.max(0, day.month - 1), Math.max(1, day.day)))
  return `${dateLabel} · ${seasonLabel}`
}

function resultScore(result: LatestResult, fallback: string) {
  if (!result || result.sets.length === 0) return fallback
  return result.sets.map((set) => result.player_side === 1 ? `${set.player1_games}-${set.player2_games}` : `${set.player2_games}-${set.player1_games}`).join('  ')
}

export default function OverviewPage() {
  const { t } = useTranslation()
  const { localeTag, formatNumber, formatCurrency } = useLocalization()
  const { player } = useAuth()
  const [dashboard, setDashboard] = useState<OverviewDashboard | null>(null)
  const [rankingProtection, setRankingProtection] = useState<RankingProtectionResponse | null>(null)
  const [rankingProtectionOpen, setRankingProtectionOpen] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const displayName = player ? `${player.first_name} ${player.last_name}`.trim() : t('header.playerFallback')
  const initials = player ? `${player.first_name.charAt(0)}${player.last_name.charAt(0)}`.toUpperCase() : 'TL'
  const countryName = getCountryName(player?.country_code, localeTag, t('header.countryNotSet'))
  const avatarUrl = usePlayerAvatarUrl(player?.image_path)

  useEffect(() => {
    let mounted = true
    async function load() {
      setLoading(true)
      setError(null)
      const [overviewResponse, rankingProtectionResponse] = await Promise.all([
        supabase.rpc('get_overview_dashboard_v2'),
        supabase.rpc('get_premium_ranking_protection_v1'),
      ])
      if (!mounted) return
      if (overviewResponse.error || !overviewResponse.data) {
        setError(overviewResponse.error?.message ?? t('overviewPage.loadError'))
      } else {
        setDashboard(overviewResponse.data as OverviewDashboard)
      }
      if (!rankingProtectionResponse.error && rankingProtectionResponse.data) {
        setRankingProtection(rankingProtectionResponse.data as RankingProtectionResponse)
      } else {
        setRankingProtection(null)
      }
      setLoading(false)
    }
    void load()
    return () => { mounted = false }
  }, [])

  const readiness = dashboard?.training?.skills ?? {}
  const equipment = dashboard?.equipment?.loadout
  const latestFinance = dashboard?.finance?.recent_transactions?.slice(0, 3) ?? []
  const todayTournaments = dashboard?.today_tournaments?.slice(0, 6) ?? []
  const gameNews = dashboard?.game_news?.slice(0, 5) ?? []
  const money = (value: number | null | undefined) => formatCurrency(Math.round(Number(value) || 0), 'USD')
  const number = (value: number | null | undefined) => formatNumber(Math.round(Number(value) || 0))

  const equipmentAverage = useMemo(() => {
    const values = [equipment?.racket?.condition, equipment?.string?.condition, equipment?.shoes?.condition].filter((value): value is number => typeof value === 'number')
    return values.length ? Math.round(values.reduce((sum, value) => sum + value, 0) / values.length) : 0
  }, [equipment])

  return (
    <GameLayout title={t('overviewPage.title')} subtitle={t('overviewPage.subtitle')}>
      <section className="tlg-v2-command">
        <div className="tlg-v2-command-inner">
          <div>
            <span className="tlg-v2-command-kicker">{t('overviewPage.kicker')}</span>
            <h2>{t('overviewPage.welcome', { name: player?.first_name || t('overviewPage.managerFallback') })}</h2>
            <p>{dashboard
              ? t('overviewPage.loadedSummary', {
                date: gameDate(dashboard.game_day, localeTag, t('overviewPage.gameDateUnavailable'), t('overviewPage.season', { season: dashboard.game_day.season })),
                week: dashboard.game_day.season_week,
              })
              : t('overviewPage.loadingSummary')}</p>
          </div>

          <div className="tlg-v2-player-card">
            <div className="tlg-v2-player-row">
              <div className="tlg-v2-player-avatar">
                {avatarUrl ? <img src={avatarUrl} alt={displayName} /> : initials}
              </div>
              <div className="tlg-v2-player-copy">
                <span>{t('overviewPage.professionalProfile')}</span>
                <strong>{displayName}</strong>
                <p className="tlg-v7-country-line">
                  <CountryFlag countryCode={player?.country_code} countryName={countryName} width={20} height={15} />
                  <span>{t('overviewPage.extra.worldLabel', {
                    country: countryName,
                    world: player?.world ?? '—',
                  })}</span>
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {error && <div className="tlg-overview-alert error">{error}</div>}
      {loading && !dashboard ? <div className="tlg-overview-loading">{t('overviewPage.loading')}</div> : null}

      {dashboard && (
        <div className="tlg-overview-dashboard">
          <section className="tlg-overview-kpis">
            <OverviewKpi label={t('overviewPage.worldRanking')} value={`#${dashboard.player.current_rank}`} detail={t('overviewPage.rankingPoints', { points: number(dashboard.player.ranking_points) })} />
            <OverviewKpi label={t('overviewPage.seasonRecord')} value={`${dashboard.season_stats.wins}-${dashboard.season_stats.losses}`} detail={t('overviewPage.winRate', { rate: dashboard.season_stats.win_pct.toLocaleString(localeTag, { maximumFractionDigits: 1 }) })} />
            <OverviewKpi label={t('overviewPage.careerBalance')} value={money(dashboard.finance.balance)} detail={t('overviewPage.seasonNet', { amount: money(dashboard.finance.season_net) })} />
            <OverviewKpi label={t('overviewPage.fatigue')} value={`${number(readiness.fatigue)}/100`} detail={t('overviewPage.sharpnessDetail', { value: number(readiness.sharpness) })} />
            <OverviewKpi label={t('overviewPage.equipment')} value={`${equipmentAverage}%`} detail={t('overviewPage.equippedCondition')} />
            <OverviewKpi label={t('overviewPage.team')} value={t('overviewPage.staffCount', { count: dashboard.staff.active_count })} detail={t('overviewPage.weeklyPayroll', { amount: money(dashboard.staff.weekly_payroll) })} />
          </section>

          <section className={`tlg-overview-panel tlg-overview-ranking-protection${rankingProtectionOpen ? ' is-open' : ''}`}>
            <div className="tlg-overview-ranking-protection-head">
              <div>
                <span>{t('overviewPage.premiumProtection')}</span>
                <h3>{t('overviewPage.upcomingExpirations')}</h3>
                <p>{t('overviewPage.protectionIntro')}</p>
              </div>
              {rankingProtection?.premium ? (
                <button
                  type="button"
                  className="tlg-overview-ranking-protection-toggle"
                  aria-expanded={rankingProtectionOpen}
                  onClick={() => setRankingProtectionOpen((current) => !current)}
                >
                  {rankingProtectionOpen ? t('overviewPage.minimize') : t('overviewPage.expand')}
                  {rankingProtectionOpen ? <ChevronUp size={15} /> : <ChevronDown size={15} />}
                </button>
              ) : (
                <span className="tlg-overview-premium-lock"><LockKeyhole size={14} /> Premium</span>
              )}
            </div>

            {!rankingProtection?.premium ? (
              <div className="tlg-overview-ranking-protection-locked">
                <LockKeyhole size={17} />
                <div>
                  <strong>{t('overviewPage.protectionPremium')}</strong>
                  <span>{t('overviewPage.protectionPremiumBody')}</span>
                </div>
              </div>
            ) : rankingProtectionOpen ? (
              rankingProtection.contributions.length ? (
                <div className="tlg-overview-ranking-protection-list">
                  {rankingProtection.contributions.slice(0, 5).map((item) => (
                    <article key={item.contribution_id}>
                      <div>
                        <span>{item.next_edition_scheduled ? t('overviewPage.defendingPoints') : t('overviewPage.scheduledExpiration')}</span>
                        <strong>{item.tournament_name}</strong>
                        <small>{item.source_result_label}</small>
                      </div>
                      <div className="points">
                        <strong>{t('overviewPage.pointsShort', { points: formatNumber(item.ranking_points) })}</strong>
                        <small>{t('overviewPage.gameDays', { count: item.days_remaining })}</small>
                      </div>
                      <div className="expires">
                        <span>{t('overviewPage.expires')}</span>
                        <strong>{t('overviewPage.seasonAndWeek', { season: item.expiration_season, week: item.expiration_week })}</strong>
                        <small>{t('overviewPage.monthAndDay', { month: item.expiration_month, day: item.expiration_day })}</small>
                      </div>
                    </article>
                  ))}
                </div>
              ) : (
                <div className="tlg-overview-ranking-protection-empty">{t('overviewPage.noExpirations')}</div>
              )
            ) : null}
          </section>

          <section className="tlg-overview-primary-grid">
            <NextTournamentCard tournament={dashboard.next_tournament} match={dashboard.next_match} />
            <LatestResultCard result={dashboard.latest_result} />
          </section>

          <section className="tlg-overview-secondary-grid">
            <FinanceCard finance={dashboard.finance} transactions={latestFinance} />
            <TodayTournamentsCard tournaments={todayTournaments} seasonWeek={dashboard.game_day.season_week} />
          </section>

          <section className="tlg-overview-three-grid">
            <PlayerFormCard stats={dashboard.season_stats} />
            <ReadinessCard training={dashboard.training} />
            <OperationsCard dashboard={dashboard} equipmentAverage={equipmentAverage} />
          </section>

          <section className="tlg-overview-news-grid">
            <GameNewsCard items={gameNews} />
            <CareerNewsCard items={dashboard.career_news} />
          </section>

          <section className="tlg-overview-quick-panel">
            <div className="tlg-overview-panel-head">
              <div><span>{t('overviewPage.quickAccess')}</span><h3>{t('overviewPage.careerOperations')}</h3></div>
            </div>
            <div className="tlg-overview-quick-grid">
              <QuickLink to="/game/calendar" icon={<CalendarDays size={16} />} title={t('overviewPage.calendar')} subtitle={t('overviewPage.calendarSubtitle')} />
              <QuickLink to="/game/training" icon={<Dumbbell size={16} />} title={t('overviewPage.training')} subtitle={t('overviewPage.trainingSubtitle')} />
              <QuickLink to="/game/finance" icon={<CircleDollarSign size={16} />} title={t('overviewPage.finance')} subtitle={t('overviewPage.financeSubtitle')} />
              <QuickLink to="/game/equipment" icon={<ShoppingBag size={16} />} title={t('overviewPage.equipment')} subtitle={t('overviewPage.equipmentSubtitle')} />
              <QuickLink to="/game/tennis-club" icon={<Users size={16} />} title={t('overviewPage.tennisClub')} subtitle={t('overviewPage.tennisClubSubtitle')} />
              <QuickLink to="/game/statistics" icon={<Activity size={16} />} title={t('overviewPage.statistics')} subtitle={t('overviewPage.statisticsSubtitle')} />
            </div>
          </section>
        </div>
      )}
    </GameLayout>
  )
}

function OverviewKpi({ label, value, detail }: { label: string; value: string; detail: string }) {
  return <div className="tlg-overview-kpi"><span>{label}</span><strong>{value}</strong><small>{detail}</small></div>
}

function NextTournamentCard({ tournament, match }: { tournament: NextTournament; match: NextMatch }) {
  const { t } = useTranslation()
  const surface = tournament?.surface?.toLowerCase()
  const surfaceLabel = surface === 'hard'
    ? t('overviewPage.surface.hard')
    : surface === 'clay'
      ? t('overviewPage.surface.clay')
      : surface === 'grass'
        ? t('overviewPage.surface.grass')
        : titleCase(tournament?.surface)

  return (
    <article className="tlg-overview-panel tlg-overview-next-card tlg-overview-next-card-refined">
      <div className="tlg-overview-panel-head">
        <div className="tlg-overview-next-title-group">
          <span>{t('overviewPage.nextMatch')}</span>
          <div className="tlg-overview-next-heading">
            <h3>{tournament?.tournament_name ?? t('overviewPage.noTournament')}</h3>
            {tournament && <div className="tlg-overview-event-meta">
              <CountryFlag countryCode={tournament.country_code} width={24} height={16} />
              <span>{tournament.city}</span><b>{categoryLabel(tournament.category_code)}</b><b>{surfaceLabel}</b><b>{t('overviewPage.week', { week: tournament.season_week })}</b>
            </div>}
          </div>
        </div>
        {tournament && <Link className="tlg-overview-link" to={`/game/tournaments/${tournament.competition_id}`}>{t('overviewPage.openTournament')} <ChevronRight size={14} /></Link>}
      </div>
      {tournament ? (
        <div className="tlg-overview-next-body tlg-overview-next-body-refined">
          <div className="tlg-overview-next-dashboard">
            <section className="tlg-overview-next-tournament-summary" aria-label={t('overviewPage.nextTournament')}>
              <NextTournamentExtras tournament={tournament} />
            </section>
            <section className="tlg-overview-next-opponent-card" aria-label={t('overviewPage.nextMatch')}>
              {match ? (
                <div className="tlg-overview-result-layout">
                  <div className="tlg-overview-result-main">
                    <div className="tournament">
                      <CountryFlag countryCode={match.country_code} width={24} height={16} />
                      <div><strong>{match.tournament_name}</strong><span>{match.round_label} · {t('overviewPage.week', { week: match.season_week })} · {t('overviewPage.day', { day: match.day })}</span></div>
                    </div>
                    <div className="tlg-overview-match-box tlg-overview-upcoming-match-box">
                      <div className="tlg-overview-next-opponent-label">{t('overviewPage.nextMatch')} · {match.round_label}</div>
                      <div className="opponent"><span>{t('overviewPage.versus')}</span><CountryFlag countryCode={match.opponent_country_code} width={22} height={15} /><Link to={`/game/players/${match.opponent_id}`}>{match.opponent_first_name} {match.opponent_last_name}</Link></div>
                      <small>{t('overviewPage.tournamentDay')}: {t('overviewPage.week', { week: match.season_week })} · {t('overviewPage.day', { day: match.day })}</small>
                    </div>
                  </div>
                  <LatestOpponentPortrait playerId={match.opponent_id} name={`${match.opponent_first_name} ${match.opponent_last_name}`} />
                </div>
              ) : (
                <div className="tlg-overview-next-awaiting-match">
                  <strong>{t('overviewPage.nextMatch')}</strong>
                  <p>{t('overviewPage.entryActive')}</p>
                </div>
              )}
            </section>
          </div>
          <div className="tlg-overview-next-actions">
            <Link to="/game/schedule">{t('overviewPage.prepareTournament')}</Link>
            <Link to="/game/calendar">{t('overviewPage.viewCalendar')}</Link>
          </div>
        </div>
      ) : <EmptyCard text={t('overviewPage.noActiveEntry')} />}
    </article>
  )
}

function LatestResultCard({ result }: { result: LatestResult }) {
  const { t } = useTranslation()

  return (
    <article className="tlg-overview-panel tlg-overview-result-card tlg-overview-result-card-refined">
      <div className="tlg-overview-panel-head"><div><span>{t('overviewPage.previousResult')}</span><h3>{t('overviewPage.latestMatch')}</h3></div>{result && <span className={`tlg-overview-result-badge ${result.won ? 'win' : 'loss'}`}>{result.won ? t('overviewPage.win') : t('overviewPage.loss')}</span>}</div>
      {result ? (
        <div className="tlg-overview-result-body tlg-overview-result-body-refined">
          <div className="tlg-overview-result-layout">
            <div className="tlg-overview-result-main">
              <div className="tournament"><CountryFlag countryCode={result.country_code} width={24} height={16} /><div><strong>{result.tournament_name}</strong><span>{result.round_label} · {result.city}</span></div></div>
              <div className="tlg-overview-match-box">
                <div className="score">{resultScore(result, t('overviewPage.resultRecorded'))}</div>
                <div className="opponent"><span>{t('overviewPage.versus')}</span><CountryFlag countryCode={result.opponent_country_code} width={22} height={15} /><Link to={`/game/players/${result.opponent_id}`}>{result.opponent_first_name} {result.opponent_last_name}</Link></div>
              </div>
            </div>
            <LatestOpponentPortrait playerId={result.opponent_id} name={`${result.opponent_first_name} ${result.opponent_last_name}`} />
          </div>
          <Link className="tlg-overview-link tlg-overview-result-bottom-link" to={`/game/tournaments/${result.competition_id}`}>{t('overviewPage.tournamentDetails')} <ChevronRight size={14} /></Link>
        </div>
      ) : <EmptyCard text={t('overviewPage.noCompletedMatch')} />}
    </article>
  )
}

function LatestOpponentPortrait({ playerId, name }: { playerId: string; name: string }) {
  const [imagePath, setImagePath] = useState<string | null>(null)
  const avatarUrl = usePlayerAvatarUrl(imagePath)

  useEffect(() => {
    let active = true
    setImagePath(null)
    void supabase.rpc('get_player_profile_v2', { p_player_id: playerId }).then(({ data, error }) => {
      if (!active) return
      // This SQL RPC returns a TABLE (an array of rows), not one JSON object.
      const rows = data as Array<{ image_path?: string | null }> | null
      if (!error) setImagePath(rows?.[0]?.image_path ?? null)
    }).catch(() => {
      if (active) setImagePath(null)
    })
    return () => { active = false }
  }, [playerId])

  return <div className="tlg-overview-result-portrait">
    {avatarUrl ? <img src={avatarUrl} alt={name} loading="lazy" /> : <UserRound size={50} aria-label={name} />}
  </div>
}

function FinanceCard({ finance, transactions }: { finance: FinanceSummary; transactions: FinanceTransaction[] }) {
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()
  const money = (value: number | null | undefined) => formatCurrency(Math.round(Number(value) || 0), 'USD')

  return (
    <article className="tlg-overview-panel">
      <div className="tlg-overview-panel-head"><div><span>{t('overviewPage.financeEyebrow')}</span><h3>{t('overviewPage.careerMoney')}</h3></div><Link className="tlg-overview-link" to="/game/finance">{t('overviewPage.finance')} <ChevronRight size={14} /></Link></div>
      <div className="tlg-overview-finance-summary">
        <div><span>{t('overviewPage.balance')}</span><strong>{money(finance.balance)}</strong></div>
        <div><span>{t('overviewPage.seasonIncome')}</span><strong className="positive">{money(finance.season_income)}</strong></div>
        <div><span>{t('overviewPage.seasonExpenses')}</span><strong className="negative">{money(finance.season_expenses)}</strong></div>
        <div><span>{t('overviewPage.net')}</span><strong>{money(finance.season_net)}</strong></div>
      </div>
      <div className="tlg-overview-mini-list">
        {transactions.length ? transactions.map((transaction) => <div key={transaction.id}><span>{transaction.description}</span><strong className={transaction.amount >= 0 ? 'positive' : 'negative'}>{transaction.amount >= 0 ? '+' : '−'}{money(Math.abs(transaction.amount))}</strong></div>) : <p>{t('overviewPage.noTransactions')}</p>}
      </div>
      <RecentFinanceTrends finance={finance} transactions={transactions} />
      {finance.upcoming_commitments?.[0] && <div className="tlg-overview-commitment"><span>{t('overviewPage.nextCommitment')}</span><strong>{finance.upcoming_commitments[0].description}</strong><b>−{money(finance.upcoming_commitments[0].amount)}</b></div>}
    </article>
  )
}

function RecentFinanceTrends({ finance }: { finance: FinanceSummary; transactions: FinanceTransaction[] }) {
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()

  // A comparative snapshot of actual values, not an invented historical series.
  const entries = [
    { key: 'balance', label: t('overviewPage.balance'), value: Number(finance.balance) || 0, color: '#277fae' },
    { key: 'income', label: t('overviewPage.seasonIncome'), value: Number(finance.season_income) || 0, color: '#17865b' },
    { key: 'expenses', label: t('overviewPage.seasonExpenses'), value: Number(finance.season_expenses) || 0, color: '#ce655b' },
    { key: 'net', label: t('overviewPage.net'), value: Number(finance.season_net) || 0, color: '#478da8' },
  ]
  const max = Math.max(1, ...entries.map((item) => Math.abs(item.value)))

  return <div className="tlg-overview-finance-bars">
    {entries.map(({ key, label, value, color }) => <div className="tlg-overview-finance-bar" key={key}>
      <div className="tlg-overview-finance-bar-label">
        <span>{label}</span>
        <strong>{formatCurrency(Math.round(value), 'USD')}</strong>
      </div>
      <div className="tlg-overview-finance-track" role="meter" aria-label={label}
        aria-valuemin={0} aria-valuemax={Math.round(max)} aria-valuenow={Math.round(Math.abs(value))}>
        <span style={{ width: `${Math.min(100, (Math.abs(value) / max) * 100)}%`, backgroundColor: color }} />
      </div>
    </div>)}
  </div>
}

function TodayTournamentsCard({ tournaments, seasonWeek }: { tournaments: TodayTournament[]; seasonWeek: number }) {
  const { t } = useTranslation()
  return (
    <article className="tlg-overview-panel">
      <div className="tlg-overview-panel-head"><div><span>{t('overviewPage.todayEyebrow')}</span><h3>{t('overviewPage.todayTournaments')}</h3><p>{t('overviewPage.eventsActive', { week: seasonWeek })}</p></div><Link className="tlg-overview-link" to="/game/calendar">{t('overviewPage.calendar')} <ChevronRight size={14} /></Link></div>
      <div className="tlg-overview-tournament-list">
        {tournaments.length ? tournaments.map((tournament) => {
          const surface = tournament.surface?.toLowerCase()
          const surfaceLabel = surface === 'hard'
            ? t('overviewPage.surface.hard')
            : surface === 'clay'
              ? t('overviewPage.surface.clay')
              : surface === 'grass'
                ? t('overviewPage.surface.grass')
                : titleCase(tournament.surface)

          return (
            <Link to={`/game/tournaments/${tournament.competition_id}`} key={tournament.competition_id}>
              <CountryFlag countryCode={tournament.country_code} width={22} height={15} />
              <div><strong>{tournament.tournament_name}</strong><span>{tournament.city} · {categoryLabel(tournament.category_code)}</span></div>
              <b>{surfaceLabel}</b>
            </Link>
          )
        }) : <EmptyCard text={t('overviewPage.noActiveTournaments')} />}
      </div>
    </article>
  )
}

function PlayerFormCard({ stats }: { stats: SeasonStats }) {
  const { t } = useTranslation()
  const { formatNumber, localeTag } = useLocalization()

  return (
    <article className="tlg-overview-panel tlg-overview-compact-panel">
      <div className="tlg-overview-panel-head"><div><span>{t('overviewPage.playerStatistics')}</span><h3>{t('overviewPage.seasonForm')}</h3></div><Link className="tlg-overview-link" to="/game/statistics">{t('overviewPage.stats')} <ChevronRight size={14} /></Link></div>
      <div className="tlg-overview-record"><strong>{stats.wins}-{stats.losses}</strong><span>{t('overviewPage.wins', { rate: stats.win_pct.toLocaleString(localeTag, { maximumFractionDigits: 1 }) })}</span></div>
      <div className="tlg-overview-stat-grid">
        <SmallStat label={t('overviewPage.matches')} value={formatNumber(stats.matches)} />
        <SmallStat label={t('overviewPage.titles')} value={formatNumber(stats.titles)} />
        <SmallStat label={t('overviewPage.aces')} value={formatNumber(stats.aces)} />
        <SmallStat label={t('overviewPage.winners')} value={formatNumber(stats.winners)} />
        <SmallStat label={t('overviewPage.unforcedErrors')} value={formatNumber(stats.unforced_errors)} />
        <SmallStat label={t('overviewPage.pointsWon')} value={formatNumber(stats.total_points_won)} />
      </div>
    </article>
  )
}

function ReadinessCard({ training }: { training: TrainingSummary }) {
  const { t } = useTranslation()
  const values = [
    [t('overviewPage.fatigue'), training.skills?.fatigue ?? 0, true],
    [t('overviewPage.sharpness'), training.skills?.sharpness ?? 0, false],
    [t('overviewPage.morale'), training.skills?.morale ?? 0, false],
    [t('overviewPage.confidence'), training.skills?.confidence ?? 0, false],
    [t('overviewPage.focus'), training.skills?.focus ?? 0, false],
  ] as const

  return (
    <article className="tlg-overview-panel tlg-overview-compact-panel">
      <div className="tlg-overview-panel-head"><div><span>{t('overviewPage.readiness')}</span><h3>{t('overviewPage.trainingCondition')}</h3></div><Link className="tlg-overview-link" to="/game/training">{t('overviewPage.training')} <ChevronRight size={14} /></Link></div>
      <div className="tlg-overview-readiness-status"><span>{titleCase(training.activity_type)}</span><strong>{training.eligible ? t('overviewPage.trainingAvailable') : training.block_reason ?? t('overviewPage.trainingUnavailable')}</strong></div>
      <div className="tlg-overview-bars">
        {values.map(([label, value, inverse]) => <MetricBar key={label} label={label} value={value} inverse={inverse} />)}
      </div>
      <div className="tlg-overview-plan"><span>{t('overviewPage.currentPlan')}</span><strong>{titleCase(training.plan?.training_type)}</strong><small>{training.plan?.focus_attribute ? `${t('overviewPage.focusLabel', { value: titleCase(training.plan.focus_attribute) })} · ` : ''}{titleCase(training.plan?.intensity)}</small></div>
    </article>
  )
}

function OperationsCard({ dashboard, equipmentAverage }: { dashboard: OverviewDashboard; equipmentAverage: number }) {
  const { t } = useTranslation()
  const { formatCurrency, formatNumber } = useLocalization()
  const loadout = dashboard.equipment?.loadout
  const club = dashboard.club?.club
  const money = (value: number | null | undefined) => formatCurrency(Math.round(Number(value) || 0), 'USD')

  return (
    <article className="tlg-overview-panel tlg-overview-compact-panel">
      <div className="tlg-overview-panel-head"><div><span>{t('overviewPage.careerOperationsEyebrow')}</span><h3>{t('overviewPage.gearTeamClub')}</h3></div></div>
      <OperationRow icon={<ShoppingBag size={15} />} title={t('overviewPage.equipment')} value={t('overviewPage.condition', { value: equipmentAverage })} detail={loadout?.racket ? `${loadout.racket.item.brand} ${loadout.racket.item.model}` : t('overviewPage.noRacket')} to="/game/equipment" />
      <OperationRow icon={<Users size={15} />} title={t('overviewPage.staff')} value={t('overviewPage.activeCount', { count: dashboard.staff.active_count })} detail={t('overviewPage.weeklyPayrollShort', { amount: money(dashboard.staff.weekly_payroll) })} to="/game/staff" />
      <OperationRow icon={<ShieldCheck size={15} />} title={t('overviewPage.tennisClub')} value={club?.name ?? t('overviewPage.noClub')} detail={club ? t('overviewPage.clubDetail', { points: formatNumber(club.points), count: club.member_count }) : t('overviewPage.coinsAvailable', { count: formatNumber(dashboard.club.coins_balance) })} to="/game/tennis-club" />
    </article>
  )
}

function GameNewsCard({ items }: { items: GameNewsItem[] }) {
  const { t } = useTranslation()
  return (
    <article className="tlg-overview-panel tlg-overview-game-news-card">
      <div className="tlg-overview-panel-head"><div><span>{t('overviewPage.gameNews')}</span><h3>{t('overviewPage.latestTourResults')}</h3><p>{t('overviewPage.gameNewsIntro')}</p></div></div>
      <div className="tlg-overview-news-list">
        {items.length ? items.slice(0, 5).map((item) => (
          <div key={item.match_id} className="tlg-overview-news-row">
            <div className="winner"><CountryFlag countryCode={item.winner_country_code} width={22} height={15} /><Link to={`/game/players/${item.winner_id}`}>{item.winner_first_name} {item.winner_last_name}</Link></div>
            <span>{t('overviewPage.defeated')}</span>
            <div><CountryFlag countryCode={item.loser_country_code} width={22} height={15} /><Link to={`/game/players/${item.loser_id}`}>{item.loser_first_name} {item.loser_last_name}</Link></div>
            <small>{item.tournament_name} · {item.round_label}</small>
          </div>
        )) : <EmptyCard text={t('overviewPage.noTourMatches')} />}
      </div>
      <RealWorldTennisNews />
    </article>
  )
}

function CareerNewsCard({ items }: { items: CareerNewsItem[] }) {
  const { t } = useTranslation()

  return (
    <article className="tlg-overview-panel">
      <div className="tlg-overview-panel-head"><div><span>{t('overviewPage.careerNews')}</span><h3>{t('overviewPage.latestUpdates')}</h3></div><Link className="tlg-overview-link" to="/game/notifications">{t('overviewPage.notifications')} <ChevronRight size={14} /></Link></div>
      <div className="tlg-overview-career-news">
        {items.length ? items.map((item) => {
          const localized = localizeNotification(item, t)
          return (
            <div key={item.id} className={item.read_at ? '' : 'unread'}>
              <span>{item.read_at ? t('overviewPage.update') : t('overviewPage.new')}</span>
              <strong>{localized.title}</strong>
              <p>{localized.message}</p>
              {item.route && <Link to={item.route}>{t('overviewPage.open')} <ChevronRight size={13} /></Link>}
            </div>
          )
        }) : <div className="tlg-overview-no-news"><ShieldCheck size={22} /><strong>{t('overviewPage.allCaughtUp')}</strong><p>{t('overviewPage.noCareerNews')}</p></div>}
      </div>
    </article>
  )
}

function SmallStat({ label, value }: { label: string; value: string }) {
  return <div><span>{label}</span><strong>{value}</strong></div>
}

function MetricBar({ label, value, inverse = false }: { label: string; value: number; inverse?: boolean }) {
  const bounded = Math.max(0, Math.min(100, Number(value) || 0))
  return <div><div><span>{label}</span><strong>{Math.round(bounded)}</strong></div><div className={`bar${inverse ? ' inverse' : ''}`}><i style={{ width: `${bounded}%` }} /></div></div>
}

function OperationRow({ icon, title, value, detail, to }: { icon: ReactNode; title: string; value: string; detail: string; to: string }) {
  return <Link className="tlg-overview-operation" to={to}><span className="icon">{icon}</span><div><strong>{title}</strong><small>{detail}</small></div><b>{value}</b><ChevronRight size={14} /></Link>
}

function EmptyCard({ text }: { text: string }) {
  return <div className="tlg-overview-empty"><CalendarDays size={20} /><span>{text}</span></div>
}

function QuickLink({ to, icon, title, subtitle }: { to: string; icon: ReactNode; title: string; subtitle: string }) {
  return (
    <Link to={to} className="tlg-overview-quick-link">
      <span>{icon}</span><div><strong>{title}</strong><small>{subtitle}</small></div><ChevronRight size={14} />
    </Link>
  )
}
