import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router'

import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/statistics.css'

type StatisticsTab = 'players' | 'tournaments' | 'career'
type StatisticsPeriod = 'season' | 'all_time'
type TennisWorld = 'ATP' | 'WTA'

type PlayerStat = {
  player_id: string
  first_name: string
  last_name: string
  country_code: string | null
  world: TennisWorld
  current_rank: number
  current_ranking_points: number
  matches: number
  wins: number
  losses: number
  win_pct: number
  titles: number
  finals: number
  tournament_appearances: number
  aces: number
  double_faults: number
  winners: number
  unforced_errors: number
  total_points_won: number
  ranking_points_earned: number
  stats_rank?: number
}

type RecordPlayer = Partial<PlayerStat> | null

type StatisticsRecords = {
  current_world_no1: RecordPlayer
  performance_leader: RecordPlayer
  wins_leader: RecordPlayer
  losses_leader: RecordPlayer
  win_rate_leader: RecordPlayer
  aces_leader: RecordPlayer
  winners_leader: RecordPlayer
  titles_leader: RecordPlayer
}

type TournamentStat = {
  tournament_series_id: string
  tournament_name: string
  city: string
  country_code: string
  category_code: string
  surface: string
  editions: number
  completed_matches: number
  unique_players: number
  total_aces: number
  total_winners: number
  total_points: number
  avg_aces_per_match: number
  avg_winners_per_match: number
  top_player_id: string | null
  top_player_name: string | null
  top_player_wins: number | null
  stats_rank: number
}

type SurfaceRecord = {
  surface: string
  matches: number
  wins: number
  losses: number
  win_pct: number
}

type CategoryRecord = {
  category_code: string
  tournaments: number
  matches: number
  wins: number
  losses: number
  titles: number
  win_pct: number
}

type SeasonRecord = {
  season: number
  matches: number
  wins: number
  losses: number
  titles: number
  win_pct: number
}

type CareerStats = {
  player: PlayerStat | null
  best_rank: number | null
  best_ranking_points: number | null
  career_prize_money: number
  surface_records: SurfaceRecord[]
  category_records: CategoryRecord[]
  season_records: SeasonRecord[]
}

type StatisticsDashboard = {
  world: TennisWorld
  period: StatisticsPeriod
  season: number
  current_absolute_day: number
  records: StatisticsRecords
  players: PlayerStat[]
  tournaments: TournamentStat[]
  career: CareerStats
}

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

function number(value: number | null | undefined) {
  return Math.round(Number(value) || 0).toLocaleString()
}

function money(value: number | null | undefined) {
  return `$${number(value)}`
}

function playerName(player: RecordPlayer) {
  if (!player) return 'No record yet'
  return `${player.first_name ?? ''} ${player.last_name ?? ''}`.trim() || 'No record yet'
}

function categoryLabel(code: string) {
  return CATEGORY_LABELS[code] ?? code.replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function surfaceLabel(surface: string) {
  return surface.charAt(0).toUpperCase() + surface.slice(1)
}

export default function StatisticsPage() {
  const [tab, setTab] = useState<StatisticsTab>('players')
  const [period, setPeriod] = useState<StatisticsPeriod>('season')
  const [world, setWorld] = useState<TennisWorld | null>(null)
  const [dashboard, setDashboard] = useState<StatisticsDashboard | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  async function loadStatistics(nextWorld = world, nextPeriod = period) {
    setLoading(true)
    setError(null)
    const { data, error: statisticsError } = await supabase.rpc('get_world_statistics_v1', {
      p_world: nextWorld,
      p_period: nextPeriod,
    })
    if (statisticsError || !data) {
      setError(statisticsError?.message ?? 'Unable to load world statistics.')
    } else {
      const next = data as StatisticsDashboard
      setDashboard(next)
      setWorld(next.world)
    }
    setLoading(false)
  }

  useEffect(() => {
    void loadStatistics(world, period)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [world, period])

  const tournamentHighlights = useMemo(() => {
    const tournaments = dashboard?.tournaments ?? []
    const pick = (key: keyof TournamentStat) => tournaments.reduce<TournamentStat | null>((best, item) => {
      if (!best) return item
      return Number(item[key] ?? 0) > Number(best[key] ?? 0) ? item : best
    }, null)
    return {
      matches: pick('completed_matches'),
      aces: pick('total_aces'),
      winners: pick('total_winners'),
      aceRate: pick('avg_aces_per_match'),
    }
  }, [dashboard?.tournaments])

  return (
    <GameLayout title="Statistics" subtitle="World records, tournament leaders and career analytics">
      <div className="tlg-statistics-page">
        <section className="tlg-statistics-hero">
          <div>
            <span>PERFORMANCE INTELLIGENCE</span>
            <h1>World Statistics</h1>
            <p>Official Tennis Legacy records built from completed matches, tournament results and rankings. ATP and WTA statistics stay separate, while your Career Records follow your own professional world.</p>
          </div>
        </section>

        <div className="tlg-statistics-tabs" role="tablist" aria-label="Statistics sections">
          <button type="button" className={tab === 'players' ? 'active' : ''} onClick={() => setTab('players')}>Player Statistics</button>
          <button type="button" className={tab === 'tournaments' ? 'active' : ''} onClick={() => setTab('tournaments')}>Tournament Statistics</button>
          <button type="button" className={tab === 'career' ? 'active' : ''} onClick={() => setTab('career')}>Career Records</button>
        </div>

        {tab !== 'career' && (
          <section className="tlg-statistics-filters">
            <div className="switch-group" aria-label="Tennis world">
              {(['ATP', 'WTA'] as TennisWorld[]).map((value) => (
                <button key={value} type="button" className={world === value ? 'active' : ''} onClick={() => setWorld(value)}>{value}</button>
              ))}
            </div>
            <div className="switch-group" aria-label="Statistics period">
              <button type="button" className={period === 'season' ? 'active' : ''} onClick={() => setPeriod('season')}>Season {dashboard?.season ?? 1}</button>
              <button type="button" className={period === 'all_time' ? 'active' : ''} onClick={() => setPeriod('all_time')}>All-Time</button>
            </div>
          </section>
        )}

        {error && <div className="tlg-statistics-alert error">{error}</div>}

        {loading && !dashboard ? (
          <div className="tlg-statistics-state">Loading world statistics…</div>
        ) : dashboard ? (
          <>
            {tab === 'players' && (
              <div className="tlg-statistics-view">
                <section className="tlg-statistics-record-grid">
                  <RecordCard title="Current World #1" player={dashboard.records.current_world_no1} value={dashboard.records.current_world_no1 ? '#1' : '—'} detail={`${number(dashboard.records.current_world_no1?.current_ranking_points)} ranking points`} />
                  <RecordCard title={period === 'season' ? `Season ${dashboard.season} Leader` : 'All-Time Performance Leader'} player={dashboard.records.performance_leader} value={dashboard.records.performance_leader ? `${number(dashboard.records.performance_leader.wins)} wins` : '—'} detail={dashboard.records.performance_leader ? `${number(dashboard.records.performance_leader.win_pct)}% win rate` : 'No completed matches'} />
                  <RecordCard title="Most Match Wins" player={dashboard.records.wins_leader} value={dashboard.records.wins_leader ? number(dashboard.records.wins_leader.wins) : '—'} detail={period === 'season' ? `Season ${dashboard.season}` : 'Career record'} />
                  <RecordCard title="Best Win Rate" player={dashboard.records.win_rate_leader} value={dashboard.records.win_rate_leader ? `${number(dashboard.records.win_rate_leader.win_pct)}%` : '—'} detail={dashboard.records.win_rate_leader ? `${number(dashboard.records.win_rate_leader.matches)} matches` : 'No completed matches'} />
                </section>

                <section className="tlg-statistics-mini-records">
                  <MiniRecord title="Most Aces" player={dashboard.records.aces_leader} value={dashboard.records.aces_leader?.aces} />
                  <MiniRecord title="Most Winners" player={dashboard.records.winners_leader} value={dashboard.records.winners_leader?.winners} />
                  <MiniRecord title="Most Defeats" player={dashboard.records.losses_leader} value={dashboard.records.losses_leader?.losses} />
                  <MiniRecord title="Most Titles" player={dashboard.records.titles_leader} value={dashboard.records.titles_leader?.titles} />
                </section>

                <section className="tlg-statistics-panel">
                  <header className="tlg-statistics-panel-head">
                    <div><span>WORLD LEADERBOARD</span><h2>{dashboard.world} {period === 'season' ? `Season ${dashboard.season}` : 'All-Time'} player statistics</h2><p>Top 50 players with at least one completed official match in the selected period.</p></div>
                    <small>{dashboard.players.length} players shown</small>
                  </header>
                  {dashboard.players.length === 0 ? <EmptyState text="No completed matches are available for this world and period yet." /> : <PlayerStatisticsTable players={dashboard.players} />}
                </section>
              </div>
            )}

            {tab === 'tournaments' && (
              <div className="tlg-statistics-view">
                <section className="tlg-statistics-record-grid">
                  <TournamentRecord title="Most Completed Matches" tournament={tournamentHighlights.matches} value={tournamentHighlights.matches?.completed_matches} />
                  <TournamentRecord title="Most Aces" tournament={tournamentHighlights.aces} value={tournamentHighlights.aces?.total_aces} />
                  <TournamentRecord title="Most Winners" tournament={tournamentHighlights.winners} value={tournamentHighlights.winners?.total_winners} />
                  <TournamentRecord title="Highest Aces / Match" tournament={tournamentHighlights.aceRate} value={tournamentHighlights.aceRate?.avg_aces_per_match} decimal />
                </section>

                <section className="tlg-statistics-panel">
                  <header className="tlg-statistics-panel-head">
                    <div><span>TOURNAMENT DATABASE</span><h2>{dashboard.world} {period === 'season' ? `Season ${dashboard.season}` : 'All-Time'} tournament statistics</h2><p>Official completed-match totals, shot production and the player with the most wins at each event.</p></div>
                    <small>Top 50 tournaments</small>
                  </header>
                  {dashboard.tournaments.length === 0 ? <EmptyState text="No tournament match statistics are available for this world and period yet." /> : <TournamentStatisticsTable tournaments={dashboard.tournaments} />}
                </section>
              </div>
            )}

            {tab === 'career' && <CareerRecords career={dashboard.career} />}
          </>
        ) : null}
      </div>
    </GameLayout>
  )
}

function RecordCard({ title, player, value, detail }: { title: string; player: RecordPlayer; value: string; detail: string }) {
  return (
    <article className="tlg-statistics-record-card">
      <span>{title}</span>
      <strong>{value}</strong>
      <div className="record-player">
        {player?.country_code && <CountryFlag countryCode={player.country_code} width={22} height={15} />}
        {player?.player_id ? <Link to={`/game/players/${player.player_id}`}>{playerName(player)}</Link> : <b>No record yet</b>}
      </div>
      <small>{detail}</small>
    </article>
  )
}

function MiniRecord({ title, player, value }: { title: string; player: RecordPlayer; value?: number | null }) {
  return (
    <div>
      <span>{title}</span>
      <strong>{player ? number(value) : '—'}</strong>
      <small>{player?.player_id ? <Link to={`/game/players/${player.player_id}`}>{playerName(player)}</Link> : 'No record yet'}</small>
    </div>
  )
}

function TournamentRecord({ title, tournament, value, decimal = false }: { title: string; tournament: TournamentStat | null; value?: number | null; decimal?: boolean }) {
  return (
    <article className="tlg-statistics-record-card tournament-record">
      <span>{title}</span>
      <strong>{tournament ? (decimal ? Number(value ?? 0).toFixed(1) : number(value)) : '—'}</strong>
      <div className="record-tournament">{tournament?.tournament_name ?? 'No record yet'}</div>
      <small>{tournament ? `${tournament.city} · ${categoryLabel(tournament.category_code)}` : 'No completed tournament matches'}</small>
    </article>
  )
}

function PlayerStatisticsTable({ players }: { players: PlayerStat[] }) {
  return (
    <div className="tlg-statistics-table-scroll">
      <table className="tlg-statistics-table player-table">
        <thead><tr><th>#</th><th>Player</th><th>World Rank</th><th>Points</th><th>M</th><th>W</th><th>L</th><th>Win %</th><th>Titles</th><th>Aces</th><th>Winners</th></tr></thead>
        <tbody>
          {players.map((player) => (
            <tr key={player.player_id}>
              <td className="rank">{player.stats_rank}</td>
              <td><div className="player-cell"><CountryFlag countryCode={player.country_code} width={22} height={15} /><Link to={`/game/players/${player.player_id}`}>{player.first_name} {player.last_name}</Link></div></td>
              <td>#{player.current_rank}</td>
              <td>{number(player.current_ranking_points)}</td>
              <td>{number(player.matches)}</td>
              <td className="positive">{number(player.wins)}</td>
              <td className="negative">{number(player.losses)}</td>
              <td>{Number(player.win_pct).toFixed(1)}%</td>
              <td>{number(player.titles)}</td>
              <td>{number(player.aces)}</td>
              <td>{number(player.winners)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function TournamentStatisticsTable({ tournaments }: { tournaments: TournamentStat[] }) {
  return (
    <div className="tlg-statistics-table-scroll">
      <table className="tlg-statistics-table tournament-table">
        <thead><tr><th>#</th><th>Tournament</th><th>Category</th><th>Surface</th><th>Editions</th><th>Matches</th><th>Players</th><th>Aces</th><th>Winners</th><th>Aces / Match</th><th>Top Performer</th></tr></thead>
        <tbody>
          {tournaments.map((tournament) => (
            <tr key={tournament.tournament_series_id}>
              <td className="rank">{tournament.stats_rank}</td>
              <td><div className="tournament-cell"><CountryFlag countryCode={tournament.country_code} width={22} height={15} /><div><strong>{tournament.tournament_name}</strong><span>{tournament.city}</span></div></div></td>
              <td>{categoryLabel(tournament.category_code)}</td>
              <td><span className={`surface-pill ${tournament.surface}`}>{surfaceLabel(tournament.surface)}</span></td>
              <td>{number(tournament.editions)}</td>
              <td>{number(tournament.completed_matches)}</td>
              <td>{number(tournament.unique_players)}</td>
              <td>{number(tournament.total_aces)}</td>
              <td>{number(tournament.total_winners)}</td>
              <td>{Number(tournament.avg_aces_per_match).toFixed(1)}</td>
              <td>{tournament.top_player_id ? <Link to={`/game/players/${tournament.top_player_id}`}>{tournament.top_player_name} · {number(tournament.top_player_wins)} W</Link> : '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function CareerRecords({ career }: { career: CareerStats }) {
  const player = career.player
  if (!player) return <EmptyState text="Career statistics are not available yet." />
  return (
    <div className="tlg-statistics-view career-view">
      <section className="tlg-statistics-career-summary">
        <div><span>CURRENT RANK</span><strong>#{player.current_rank}</strong><small>{number(player.current_ranking_points)} ranking points</small></div>
        <div><span>CAREER BEST</span><strong>{career.best_rank ? `#${career.best_rank}` : '—'}</strong><small>Ranking history snapshot</small></div>
        <div><span>MATCH RECORD</span><strong>{player.wins}–{player.losses}</strong><small>{Number(player.win_pct).toFixed(1)}% win rate</small></div>
        <div><span>TITLES / FINALS</span><strong>{player.titles} / {player.finals}</strong><small>{player.tournament_appearances} tournament appearances</small></div>
        <div><span>PRIZE MONEY</span><strong>{money(career.career_prize_money)}</strong><small>Career Finance ledger</small></div>
      </section>

      <div className="tlg-statistics-career-grid">
        <section className="tlg-statistics-panel">
          <header className="tlg-statistics-panel-head compact"><div><span>COURT PERFORMANCE</span><h2>Surface record</h2></div></header>
          {career.surface_records.length === 0 ? <EmptyState text="No completed surface records yet." /> : (
            <div className="surface-record-grid">
              {career.surface_records.map((record) => (
                <div key={record.surface} className={`surface-record ${record.surface}`}>
                  <span>{surfaceLabel(record.surface)}</span><strong>{record.wins}–{record.losses}</strong><small>{Number(record.win_pct).toFixed(1)}% · {record.matches} matches</small>
                </div>
              ))}
            </div>
          )}
        </section>

        <section className="tlg-statistics-panel">
          <header className="tlg-statistics-panel-head compact"><div><span>SHOT PRODUCTION</span><h2>Career match totals</h2></div></header>
          <div className="career-shot-grid">
            <div><span>Aces</span><strong>{number(player.aces)}</strong></div>
            <div><span>Winners</span><strong>{number(player.winners)}</strong></div>
            <div><span>Unforced Errors</span><strong>{number(player.unforced_errors)}</strong></div>
            <div><span>Total Points Won</span><strong>{number(player.total_points_won)}</strong></div>
          </div>
        </section>
      </div>

      <section className="tlg-statistics-panel">
        <header className="tlg-statistics-panel-head"><div><span>TOURNAMENT PROFILE</span><h2>Career by tournament category</h2><p>How your player performs at each competitive level.</p></div></header>
        {career.category_records.length === 0 ? <EmptyState text="No tournament-category records yet." /> : (
          <div className="tlg-statistics-table-scroll">
            <table className="tlg-statistics-table"><thead><tr><th>Category</th><th>Tournaments</th><th>Matches</th><th>Wins</th><th>Losses</th><th>Win %</th><th>Titles</th></tr></thead><tbody>
              {career.category_records.map((record) => <tr key={record.category_code}><td><strong>{categoryLabel(record.category_code)}</strong></td><td>{record.tournaments}</td><td>{record.matches}</td><td className="positive">{record.wins}</td><td className="negative">{record.losses}</td><td>{Number(record.win_pct).toFixed(1)}%</td><td>{record.titles}</td></tr>)}
            </tbody></table>
          </div>
        )}
      </section>

      <section className="tlg-statistics-panel">
        <header className="tlg-statistics-panel-head"><div><span>CAREER TIMELINE</span><h2>Season-by-season record</h2><p>This becomes the long-term historical record as the career advances through multiple seasons.</p></div></header>
        {career.season_records.length === 0 ? <EmptyState text="No completed season match history yet." /> : (
          <div className="tlg-statistics-table-scroll">
            <table className="tlg-statistics-table"><thead><tr><th>Season</th><th>Matches</th><th>Wins</th><th>Losses</th><th>Win %</th><th>Titles</th></tr></thead><tbody>
              {career.season_records.map((record) => <tr key={record.season}><td><strong>Season {record.season}</strong></td><td>{record.matches}</td><td className="positive">{record.wins}</td><td className="negative">{record.losses}</td><td>{Number(record.win_pct).toFixed(1)}%</td><td>{record.titles}</td></tr>)}
            </tbody></table>
          </div>
        )}
      </section>
    </div>
  )
}

function EmptyState({ text }: { text: string }) {
  return <div className="tlg-statistics-empty">{text}</div>
}
