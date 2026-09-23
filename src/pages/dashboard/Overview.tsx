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
  ShieldCheck,
  ShoppingBag,
  Trophy,
  Users,
} from 'lucide-react'
import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { Link } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import usePlayerAvatarUrl from '../../hooks/usePlayerAvatarUrl'
import { supabase } from '../../lib/supabase'
import '../../styles/overview-dashboard.css'

const GAME_MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']

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
  title: string
  message: string
  severity: string
  route: string | null
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

function getCountryName(code?: string) {
  if (!code) return 'Country not set'
  try {
    return new Intl.DisplayNames(['en'], { type: 'region' }).of(code) ?? code
  } catch {
    return code
  }
}

function money(value: number | null | undefined) {
  return `$${Math.round(Number(value) || 0).toLocaleString()}`
}

function number(value: number | null | undefined) {
  return Math.round(Number(value) || 0).toLocaleString()
}

function categoryLabel(code?: string | null) {
  if (!code) return 'Tournament'
  return CATEGORY_LABELS[code] ?? code.replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function titleCase(value?: string | null) {
  if (!value) return '—'
  return value.replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function gameDate(day?: GameDay) {
  if (!day) return 'Game date unavailable'
  return `${GAME_MONTHS[day.month - 1] ?? `Month ${day.month}`} ${day.day} · Season ${day.season}`
}

function resultScore(result: LatestResult) {
  if (!result || result.sets.length === 0) return 'Result recorded'
  return result.sets.map((set) => result.player_side === 1 ? `${set.player1_games}–${set.player2_games}` : `${set.player2_games}–${set.player1_games}`).join('  ')
}

export default function OverviewPage() {
  const { player } = useAuth()
  const [dashboard, setDashboard] = useState<OverviewDashboard | null>(null)
  const [rankingProtection, setRankingProtection] = useState<RankingProtectionResponse | null>(null)
  const [rankingProtectionOpen, setRankingProtectionOpen] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const displayName = player ? `${player.first_name} ${player.last_name}`.trim() : 'Tennis Legacy Player'
  const initials = player ? `${player.first_name.charAt(0)}${player.last_name.charAt(0)}`.toUpperCase() : 'TL'
  const countryName = getCountryName(player?.country_code)
  const avatarUrl = usePlayerAvatarUrl(player?.image_path)

  useEffect(() => {
    let mounted = true
    async function load() {
      setLoading(true)
      setError(null)
      const [overviewResponse, rankingProtectionResponse] = await Promise.all([
        supabase.rpc('get_overview_dashboard_v1'),
        supabase.rpc('get_premium_ranking_protection_v1'),
      ])
      if (!mounted) return
      if (overviewResponse.error || !overviewResponse.data) {
        setError(overviewResponse.error?.message ?? 'Unable to load career overview.')
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

  const equipmentAverage = useMemo(() => {
    const values = [equipment?.racket?.condition, equipment?.string?.condition, equipment?.shoes?.condition].filter((value): value is number => typeof value === 'number')
    return values.length ? Math.round(values.reduce((sum, value) => sum + value, 0) / values.length) : 0
  }, [equipment])

  return (
    <GameLayout title="Overview" subtitle="Career command center">
      <section className="tlg-v2-command">
        <div className="tlg-v2-command-inner">
          <div>
            <span className="tlg-v2-command-kicker">Career command center</span>
            <h2>Welcome back, {player?.first_name || 'manager'}.</h2>
            <p>{dashboard ? `${gameDate(dashboard.game_day)} · Season Week ${dashboard.game_day.season_week}. Your tournaments, performance, finances and career operations are summarized below.` : 'Your career dashboard is loading the latest tournament, finance, training and performance data.'}</p>
          </div>

          <div className="tlg-v2-player-card">
            <div className="tlg-v2-player-row">
              <div className="tlg-v2-player-avatar">
                {avatarUrl ? <img src={avatarUrl} alt={displayName} /> : initials}
              </div>
              <div className="tlg-v2-player-copy">
                <span>Professional profile</span>
                <strong>{displayName}</strong>
                <p className="tlg-v7-country-line">
                  <CountryFlag countryCode={player?.country_code} countryName={countryName} width={20} height={15} />
                  <span>{countryName} · {player?.world ?? '—'} World</span>
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {error && <div className="tlg-overview-alert error">{error}</div>}
      {loading && !dashboard ? <div className="tlg-overview-loading">Loading career command center…</div> : null}

      {dashboard && (
        <div className="tlg-overview-dashboard">
          <section className="tlg-overview-kpis">
            <OverviewKpi label="World ranking" value={`#${dashboard.player.current_rank}`} detail={`${number(dashboard.player.ranking_points)} ranking points`} />
            <OverviewKpi label="Season record" value={`${dashboard.season_stats.wins}–${dashboard.season_stats.losses}`} detail={`${dashboard.season_stats.win_pct.toFixed(1)}% win rate`} />
            <OverviewKpi label="Career balance" value={money(dashboard.finance.balance)} detail={`${money(dashboard.finance.season_net)} season net`} />
            <OverviewKpi label="Fatigue" value={`${number(readiness.fatigue)}/100`} detail={`${number(readiness.sharpness)} sharpness`} />
            <OverviewKpi label="Equipment" value={`${equipmentAverage}%`} detail="Average equipped condition" />
            <OverviewKpi label="Team" value={`${dashboard.staff.active_count} staff`} detail={`${money(dashboard.staff.weekly_payroll)}/week payroll`} />
          </section>

          <section className={`tlg-overview-panel tlg-overview-ranking-protection${rankingProtectionOpen ? ' is-open' : ''}`}>
            <div className="tlg-overview-ranking-protection-head">
              <div>
                <span>PREMIUM · RANKING PROTECTION</span>
                <h3>Upcoming Point Expirations</h3>
                <p>Track the next five singles ranking results that will expire and need to be defended.</p>
              </div>
              {rankingProtection?.premium ? (
                <button
                  type="button"
                  className="tlg-overview-ranking-protection-toggle"
                  aria-expanded={rankingProtectionOpen}
                  onClick={() => setRankingProtectionOpen((current) => !current)}
                >
                  {rankingProtectionOpen ? 'Minimize' : 'Expand'}
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
                  <strong>Ranking Protection is a Premium feature</strong>
                  <span>Premium managers can expand this panel to see the next five ranking-point expirations.</span>
                </div>
              </div>
            ) : rankingProtectionOpen ? (
              rankingProtection.contributions.length ? (
                <div className="tlg-overview-ranking-protection-list">
                  {rankingProtection.contributions.slice(0, 5).map((item) => (
                    <article key={item.contribution_id}>
                      <div>
                        <span>{item.next_edition_scheduled ? 'Defending points' : 'Scheduled expiration'}</span>
                        <strong>{item.tournament_name}</strong>
                        <small>{item.source_result_label}</small>
                      </div>
                      <div className="points">
                        <strong>{item.ranking_points.toLocaleString()} pts</strong>
                        <small>{item.days_remaining.toLocaleString()} game days</small>
                      </div>
                      <div className="expires">
                        <span>Expires</span>
                        <strong>Season {item.expiration_season} · Week {item.expiration_week}</strong>
                        <small>Month {item.expiration_month}, Day {item.expiration_day}</small>
                      </div>
                    </article>
                  ))}
                </div>
              ) : (
                <div className="tlg-overview-ranking-protection-empty">No active ranking points are currently waiting to expire.</div>
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
              <div><span>QUICK ACCESS</span><h3>Career operations</h3></div>
            </div>
            <div className="tlg-overview-quick-grid">
              <QuickLink to="/game/calendar" icon={<CalendarDays size={16} />} title="Calendar" subtitle="Tournament season" />
              <QuickLink to="/game/training" icon={<Dumbbell size={16} />} title="Training" subtitle="Development & camps" />
              <QuickLink to="/game/finance" icon={<CircleDollarSign size={16} />} title="Finance" subtitle="Income & expenses" />
              <QuickLink to="/game/equipment" icon={<ShoppingBag size={16} />} title="Equipment" subtitle="Gear & condition" />
              <QuickLink to="/game/tennis-club" icon={<Users size={16} />} title="Tennis Club" subtitle="Members & world clubs" />
              <QuickLink to="/game/statistics" icon={<Activity size={16} />} title="Statistics" subtitle="World & career records" />
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
  return (
    <article className="tlg-overview-panel tlg-overview-next-card">
      <div className="tlg-overview-panel-head">
        <div><span>NEXT TOURNAMENT</span><h3>{tournament?.tournament_name ?? 'No tournament scheduled'}</h3></div>
        {tournament && <Link className="tlg-overview-link" to={`/game/tournaments/${tournament.competition_id}`}>Open tournament <ChevronRight size={14} /></Link>}
      </div>
      {tournament ? (
        <div className="tlg-overview-next-body">
          <div className="tlg-overview-event-meta">
            <CountryFlag countryCode={tournament.country_code} width={24} height={16} />
            <span>{tournament.city}</span><b>{categoryLabel(tournament.category_code)}</b><b>{titleCase(tournament.surface)}</b><b>Week {tournament.season_week}</b>
          </div>
          {match ? (
            <div className="tlg-overview-next-match">
              <div><span>NEXT MATCH</span><strong>{match.round_label}</strong></div>
              <div className="opponent"><CountryFlag countryCode={match.opponent_country_code} width={24} height={16} /><div><span>Opponent</span><Link to={`/game/players/${match.opponent_id}`}>{match.opponent_first_name} {match.opponent_last_name}</Link></div></div>
              <div className="match-date"><span>Tournament Day</span><strong>Week {match.season_week} · Day {match.day}</strong></div>
            </div>
          ) : <p className="tlg-overview-muted">Entry is active. Your next match will appear here when the draw schedules it.</p>}
          <div className="tlg-overview-next-actions"><Link to="/game/schedule">Prepare tournament</Link><Link to="/game/calendar">View calendar</Link></div>
        </div>
      ) : <EmptyCard text="No active or accepted tournament entry is currently scheduled." />}
    </article>
  )
}

function LatestResultCard({ result }: { result: LatestResult }) {
  return (
    <article className="tlg-overview-panel tlg-overview-result-card">
      <div className="tlg-overview-panel-head"><div><span>PREVIOUS RESULT</span><h3>Latest match</h3></div>{result && <span className={`tlg-overview-result-badge ${result.won ? 'win' : 'loss'}`}>{result.won ? 'WIN' : 'LOSS'}</span>}</div>
      {result ? (
        <div className="tlg-overview-result-body">
          <div className="tournament"><CountryFlag countryCode={result.country_code} width={24} height={16} /><div><strong>{result.tournament_name}</strong><span>{result.round_label} · {result.city}</span></div></div>
          <div className="score">{resultScore(result)}</div>
          <div className="opponent"><span>vs.</span><CountryFlag countryCode={result.opponent_country_code} width={22} height={15} /><Link to={`/game/players/${result.opponent_id}`}>{result.opponent_first_name} {result.opponent_last_name}</Link></div>
          <Link className="tlg-overview-link inline" to={`/game/tournaments/${result.competition_id}`}>Tournament details <ChevronRight size={14} /></Link>
        </div>
      ) : <EmptyCard text="No completed official match yet." />}
    </article>
  )
}

function FinanceCard({ finance, transactions }: { finance: FinanceSummary; transactions: FinanceTransaction[] }) {
  return (
    <article className="tlg-overview-panel">
      <div className="tlg-overview-panel-head"><div><span>FINANCE</span><h3>Career money</h3></div><Link className="tlg-overview-link" to="/game/finance">Finance <ChevronRight size={14} /></Link></div>
      <div className="tlg-overview-finance-summary">
        <div><span>Balance</span><strong>{money(finance.balance)}</strong></div>
        <div><span>Season income</span><strong className="positive">{money(finance.season_income)}</strong></div>
        <div><span>Season expenses</span><strong className="negative">{money(finance.season_expenses)}</strong></div>
        <div><span>Net</span><strong>{money(finance.season_net)}</strong></div>
      </div>
      <div className="tlg-overview-mini-list">
        {transactions.length ? transactions.map((transaction) => <div key={transaction.id}><span>{transaction.description}</span><strong className={transaction.amount >= 0 ? 'positive' : 'negative'}>{transaction.amount >= 0 ? '+' : '−'}{money(Math.abs(transaction.amount))}</strong></div>) : <p>No career transactions yet.</p>}
      </div>
      {finance.upcoming_commitments?.[0] && <div className="tlg-overview-commitment"><span>Next commitment</span><strong>{finance.upcoming_commitments[0].description}</strong><b>−{money(finance.upcoming_commitments[0].amount)}</b></div>}
    </article>
  )
}

function TodayTournamentsCard({ tournaments, seasonWeek }: { tournaments: TodayTournament[]; seasonWeek: number }) {
  return (
    <article className="tlg-overview-panel">
      <div className="tlg-overview-panel-head"><div><span>TODAY IN TENNIS LEGACY</span><h3>Today's tournaments</h3><p>Events active in Season Week {seasonWeek}.</p></div><Link className="tlg-overview-link" to="/game/calendar">Calendar <ChevronRight size={14} /></Link></div>
      <div className="tlg-overview-tournament-list">
        {tournaments.length ? tournaments.map((tournament) => (
          <Link to={`/game/tournaments/${tournament.competition_id}`} key={tournament.competition_id}>
            <CountryFlag countryCode={tournament.country_code} width={22} height={15} />
            <div><strong>{tournament.tournament_name}</strong><span>{tournament.city} · {categoryLabel(tournament.category_code)}</span></div>
            <b>{titleCase(tournament.surface)}</b>
          </Link>
        )) : <EmptyCard text="No tournaments are active in the current competition week." />}
      </div>
    </article>
  )
}

function PlayerFormCard({ stats }: { stats: SeasonStats }) {
  return (
    <article className="tlg-overview-panel tlg-overview-compact-panel">
      <div className="tlg-overview-panel-head"><div><span>PLAYER STATISTICS</span><h3>Season form</h3></div><Link className="tlg-overview-link" to="/game/statistics">Stats <ChevronRight size={14} /></Link></div>
      <div className="tlg-overview-record"><strong>{stats.wins}–{stats.losses}</strong><span>{stats.win_pct.toFixed(1)}% wins</span></div>
      <div className="tlg-overview-stat-grid">
        <SmallStat label="Matches" value={number(stats.matches)} />
        <SmallStat label="Titles" value={number(stats.titles)} />
        <SmallStat label="Aces" value={number(stats.aces)} />
        <SmallStat label="Winners" value={number(stats.winners)} />
        <SmallStat label="Unforced errors" value={number(stats.unforced_errors)} />
        <SmallStat label="Points won" value={number(stats.total_points_won)} />
      </div>
    </article>
  )
}

function ReadinessCard({ training }: { training: TrainingSummary }) {
  const values = [
    ['Fatigue', training.skills?.fatigue ?? 0],
    ['Sharpness', training.skills?.sharpness ?? 0],
    ['Morale', training.skills?.morale ?? 0],
    ['Confidence', training.skills?.confidence ?? 0],
    ['Focus', training.skills?.focus ?? 0],
  ] as const
  return (
    <article className="tlg-overview-panel tlg-overview-compact-panel">
      <div className="tlg-overview-panel-head"><div><span>READINESS</span><h3>Training & condition</h3></div><Link className="tlg-overview-link" to="/game/training">Training <ChevronRight size={14} /></Link></div>
      <div className="tlg-overview-readiness-status"><span>{titleCase(training.activity_type)}</span><strong>{training.eligible ? 'Training available' : training.block_reason ?? 'Training unavailable'}</strong></div>
      <div className="tlg-overview-bars">
        {values.map(([label, value]) => <MetricBar key={label} label={label} value={value} inverse={label === 'Fatigue'} />)}
      </div>
      <div className="tlg-overview-plan"><span>Current plan</span><strong>{titleCase(training.plan?.training_type)}</strong><small>{training.plan?.focus_attribute ? `Focus: ${titleCase(training.plan.focus_attribute)} · ` : ''}{titleCase(training.plan?.intensity)}</small></div>
    </article>
  )
}

function OperationsCard({ dashboard, equipmentAverage }: { dashboard: OverviewDashboard; equipmentAverage: number }) {
  const loadout = dashboard.equipment?.loadout
  const club = dashboard.club?.club
  return (
    <article className="tlg-overview-panel tlg-overview-compact-panel">
      <div className="tlg-overview-panel-head"><div><span>CAREER OPERATIONS</span><h3>Gear, team & club</h3></div></div>
      <OperationRow icon={<ShoppingBag size={15} />} title="Equipment" value={`${equipmentAverage}% condition`} detail={loadout?.racket ? `${loadout.racket.item.brand} ${loadout.racket.item.model}` : 'No racket equipped'} to="/game/equipment" />
      <OperationRow icon={<Users size={15} />} title="Staff" value={`${dashboard.staff.active_count} active`} detail={`${money(dashboard.staff.weekly_payroll)} weekly payroll`} to="/game/staff" />
      <OperationRow icon={<ShieldCheck size={15} />} title="Tennis Club" value={club?.name ?? 'No club'} detail={club ? `${number(club.points)} pts · ${club.member_count} members` : `${number(dashboard.club.coins_balance)} coins available`} to="/game/tennis-club" />
    </article>
  )
}

function GameNewsCard({ items }: { items: GameNewsItem[] }) {
  return (
    <article className="tlg-overview-panel">
      <div className="tlg-overview-panel-head"><div><span>GAME NEWS</span><h3>Latest results around the tour</h3><p>Recent completed official matches from your professional world.</p></div></div>
      <div className="tlg-overview-news-list">
        {items.length ? items.map((item) => (
          <div key={item.match_id} className="tlg-overview-news-row">
            <div className="winner"><CountryFlag countryCode={item.winner_country_code} width={22} height={15} /><Link to={`/game/players/${item.winner_id}`}>{item.winner_first_name} {item.winner_last_name}</Link></div>
            <span>defeated</span>
            <div><CountryFlag countryCode={item.loser_country_code} width={22} height={15} /><Link to={`/game/players/${item.loser_id}`}>{item.loser_first_name} {item.loser_last_name}</Link></div>
            <small>{item.tournament_name} · {item.round_label}</small>
          </div>
        )) : <EmptyCard text="No completed tour matches are available yet." />}
      </div>
    </article>
  )
}

function CareerNewsCard({ items }: { items: CareerNewsItem[] }) {
  return (
    <article className="tlg-overview-panel">
      <div className="tlg-overview-panel-head"><div><span>CAREER NEWS</span><h3>Your latest updates</h3></div><Link className="tlg-overview-link" to="/game/notifications">Notifications <ChevronRight size={14} /></Link></div>
      <div className="tlg-overview-career-news">
        {items.length ? items.map((item) => (
          <div key={item.id} className={item.read_at ? '' : 'unread'}>
            <span>{item.read_at ? 'UPDATE' : 'NEW'}</span>
            <strong>{item.title}</strong>
            <p>{item.message}</p>
            {item.route && <Link to={item.route}>Open <ChevronRight size={13} /></Link>}
          </div>
        )) : <div className="tlg-overview-no-news"><ShieldCheck size={22} /><strong>All caught up</strong><p>No new personal career notifications.</p></div>}
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
