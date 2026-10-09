import { useEffect, useMemo, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { Link } from 'react-router'

import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import { useLocalization } from '../../i18n/LocalizationProvider'
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

function categoryLabel(code: string) {
  return CATEGORY_LABELS[code] ?? code.replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function surfaceLabel(surface: string, t: TFunction) {
  return t(`statisticsPage.surfaces.${surface}`, {
    defaultValue: surface.charAt(0).toUpperCase() + surface.slice(1),
  })
}

export default function StatisticsPage() {
  const { t } = useTranslation()
  const { formatNumber, formatCurrency } = useLocalization()
  const number = (value: number | null | undefined) => formatNumber(Math.round(Number(value) || 0))
  const money = (value: number | null | undefined) => formatCurrency(Number(value) || 0, 'USD')
  const playerName = (player: RecordPlayer) => {
    if (!player) return t('statisticsPage.noRecord')
    return `${player.first_name ?? ''} ${player.last_name ?? ''}`.trim() || t('statisticsPage.noRecord')
  }
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
      setError(statisticsError?.message ?? t('statisticsPage.loadError'))
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
    <GameLayout title={t('statisticsPage.title')} subtitle={t('statisticsPage.subtitle')}>
      <div className="tlg-statistics-page">
        <section className="tlg-statistics-hero">
          <div>
            <span>{t('statisticsPage.heroKicker')}</span>
            <h1>{t('statisticsPage.heading')}</h1>
            <p>{t('statisticsPage.intro')}</p>
          </div>
        </section>

        <div className="tlg-statistics-tabs" role="tablist" aria-label={t('statisticsPage.tabsAria')}>
          <button type="button" className={tab === 'players' ? 'active' : ''} onClick={() => setTab('players')}>{t('statisticsPage.tabs.players')}</button>
          <button type="button" className={tab === 'tournaments' ? 'active' : ''} onClick={() => setTab('tournaments')}>{t('statisticsPage.tabs.tournaments')}</button>
          <button type="button" className={tab === 'career' ? 'active' : ''} onClick={() => setTab('career')}>{t('statisticsPage.tabs.career')}</button>
        </div>

        {tab !== 'career' && (
          <section className="tlg-statistics-filters">
            <div className="switch-group" aria-label={t('statisticsPage.tennisWorld')}>
              {(['ATP', 'WTA'] as TennisWorld[]).map((value) => (
                <button key={value} type="button" className={world === value ? 'active' : ''} onClick={() => setWorld(value)}>{value}</button>
              ))}
            </div>
            <div className="switch-group" aria-label={t('statisticsPage.period')}>
              <button type="button" className={period === 'season' ? 'active' : ''} onClick={() => setPeriod('season')}>{t('statisticsPage.season', { season: dashboard?.season ?? 1 })}</button>
              <button type="button" className={period === 'all_time' ? 'active' : ''} onClick={() => setPeriod('all_time')}>{t('statisticsPage.allTime')}</button>
            </div>
          </section>
        )}

        {error && <div className="tlg-statistics-alert error">{error}</div>}

        {loading && !dashboard ? (
          <div className="tlg-statistics-state">{t('statisticsPage.loading')}</div>
        ) : dashboard ? (
          <>
            {tab === 'players' && (
              <div className="tlg-statistics-view">
                <section className="tlg-statistics-record-grid">
                  <RecordCard title={t('statisticsPage.records.worldNo1')} player={dashboard.records.current_world_no1} value={dashboard.records.current_world_no1 ? '#1' : '—'} detail={t('statisticsPage.rankingPoints', { count: number(dashboard.records.current_world_no1?.current_ranking_points) })} t={t} />
                  <RecordCard title={period === 'season' ? t('statisticsPage.records.seasonLeader', { season: dashboard.season }) : t('statisticsPage.records.allTimeLeader')} player={dashboard.records.performance_leader} value={dashboard.records.performance_leader ? t('statisticsPage.wins', { count: number(dashboard.records.performance_leader.wins) }) : '—'} detail={dashboard.records.performance_leader ? t('statisticsPage.winRate', { value: number(dashboard.records.performance_leader.win_pct) }) : t('statisticsPage.noCompletedMatches')} t={t} />
                  <RecordCard title={t('statisticsPage.records.mostWins')} player={dashboard.records.wins_leader} value={dashboard.records.wins_leader ? number(dashboard.records.wins_leader.wins) : '—'} detail={period === 'season' ? t('statisticsPage.season', { season: dashboard.season }) : t('statisticsPage.careerRecord')} t={t} />
                  <RecordCard title={t('statisticsPage.records.bestWinRate')} player={dashboard.records.win_rate_leader} value={dashboard.records.win_rate_leader ? `${number(dashboard.records.win_rate_leader.win_pct)}%` : '—'} detail={dashboard.records.win_rate_leader ? t('statisticsPage.matches', { count: number(dashboard.records.win_rate_leader.matches) }) : t('statisticsPage.noCompletedMatches')} t={t} />
                </section>

                <section className="tlg-statistics-mini-records">
                  <MiniRecord title={t('statisticsPage.records.mostAces')} t={t} player={dashboard.records.aces_leader} value={dashboard.records.aces_leader?.aces} />
                  <MiniRecord title={t('statisticsPage.records.mostWinners')} t={t} player={dashboard.records.winners_leader} value={dashboard.records.winners_leader?.winners} />
                  <MiniRecord title={t('statisticsPage.records.mostDefeats')} t={t} player={dashboard.records.losses_leader} value={dashboard.records.losses_leader?.losses} />
                  <MiniRecord title={t('statisticsPage.records.mostTitles')} t={t} player={dashboard.records.titles_leader} value={dashboard.records.titles_leader?.titles} />
                </section>

                <section className="tlg-statistics-panel">
                  <header className="tlg-statistics-panel-head">
                    <div><span>{t('statisticsPage.playersPanel.kicker')}</span><h2>{t('statisticsPage.playersPanel.title', { world: dashboard.world, period: period === 'season' ? t('statisticsPage.season', { season: dashboard.season }) : t('statisticsPage.allTime') })}</h2><p>{t('statisticsPage.playersPanel.body')}</p></div>
                    <small>{t('statisticsPage.playersPanel.shown', { count: dashboard.players.length })}</small>
                  </header>
                  {dashboard.players.length === 0 ? <EmptyState text={t('statisticsPage.playersPanel.empty')} /> : <PlayerStatisticsTable players={dashboard.players} t={t} number={number} />}
                </section>
              </div>
            )}

            {tab === 'tournaments' && (
              <div className="tlg-statistics-view">
                <section className="tlg-statistics-record-grid">
                  <TournamentRecord title={t('statisticsPage.records.mostCompletedMatches')} t={t} tournament={tournamentHighlights.matches} value={tournamentHighlights.matches?.completed_matches} />
                  <TournamentRecord title={t('statisticsPage.records.mostAces')} t={t} tournament={tournamentHighlights.aces} value={tournamentHighlights.aces?.total_aces} />
                  <TournamentRecord title={t('statisticsPage.records.mostWinners')} t={t} tournament={tournamentHighlights.winners} value={tournamentHighlights.winners?.total_winners} />
                  <TournamentRecord title={t('statisticsPage.records.highestAcesMatch')} t={t} tournament={tournamentHighlights.aceRate} value={tournamentHighlights.aceRate?.avg_aces_per_match} decimal />
                </section>

                <section className="tlg-statistics-panel">
                  <header className="tlg-statistics-panel-head">
                    <div><span>{t('statisticsPage.tournamentsPanel.kicker')}</span><h2>{t('statisticsPage.tournamentsPanel.title', { world: dashboard.world, period: period === 'season' ? t('statisticsPage.season', { season: dashboard.season }) : t('statisticsPage.allTime') })}</h2><p>{t('statisticsPage.tournamentsPanel.body')}</p></div>
                    <small>{t('statisticsPage.tournamentsPanel.top50')}</small>
                  </header>
                  {dashboard.tournaments.length === 0 ? <EmptyState text={t('statisticsPage.tournamentsPanel.empty')} /> : <TournamentStatisticsTable tournaments={dashboard.tournaments} t={t} number={number} />}
                </section>
              </div>
            )}

            {tab === 'career' && <CareerRecords career={dashboard.career} t={t} number={number} money={money} />}
          </>
        ) : null}
      </div>
    </GameLayout>
  )
}

function RecordCard({ title, player, value, detail, t }: { title: string; player: RecordPlayer; value: string; detail: string; t: TFunction }) {
  const playerName = (record: RecordPlayer) => record ? (`${record.first_name ?? ''} ${record.last_name ?? ''}`.trim() || t('statisticsPage.noRecord')) : t('statisticsPage.noRecord')
  return (
    <article className="tlg-statistics-record-card">
      <span>{title}</span>
      <strong>{value}</strong>
      <div className="record-player">
        {player?.country_code && <CountryFlag countryCode={player.country_code} width={22} height={15} />}
        {player?.player_id ? <Link to={`/game/players/${player.player_id}`}>{playerName(player)}</Link> : <b>{t('statisticsPage.noRecord')}</b>}
      </div>
      <small>{detail}</small>
    </article>
  )
}

function MiniRecord({ title, player, value, t }: { title: string; player: RecordPlayer; value?: number | null; t: TFunction }) {
  const playerName = (record: RecordPlayer) => record ? (`${record.first_name ?? ''} ${record.last_name ?? ''}`.trim() || t('statisticsPage.noRecord')) : t('statisticsPage.noRecord')
  const number = (numeric: number | null | undefined) => new Intl.NumberFormat().format(Math.round(Number(numeric) || 0))
  return (
    <div>
      <span>{title}</span>
      <strong>{player ? number(value) : '—'}</strong>
      <small>{player?.player_id ? <Link to={`/game/players/${player.player_id}`}>{playerName(player)}</Link> : t('statisticsPage.noRecord')}</small>
    </div>
  )
}

function TournamentRecord({ title, tournament, value, decimal = false, t }: { title: string; tournament: TournamentStat | null; value?: number | null; decimal?: boolean; t: TFunction }) {
  const number = (numeric: number | null | undefined) => new Intl.NumberFormat().format(Math.round(Number(numeric) || 0))
  return (
    <article className="tlg-statistics-record-card tournament-record">
      <span>{title}</span>
      <strong>{tournament ? (decimal ? Number(value ?? 0).toFixed(1) : number(value)) : '—'}</strong>
      <div className="record-tournament">{tournament?.tournament_name ?? t('statisticsPage.noRecord')}</div>
      <small>{tournament ? `${tournament.city} · ${categoryLabel(tournament.category_code)}` : t('statisticsPage.tournamentsPanel.noCompleted')}</small>
    </article>
  )
}

function PlayerStatisticsTable({ players, t, number }: { players: PlayerStat[]; t: TFunction; number: (value: number | null | undefined) => string }) {
  return (
    <div className="tlg-statistics-table-scroll">
      <table className="tlg-statistics-table player-table">
        <thead><tr><th>#</th><th>{t('statisticsPage.tables.player')}</th><th>{t('statisticsPage.tables.worldRank')}</th><th>{t('statisticsPage.tables.points')}</th><th>M</th><th>W</th><th>L</th><th>{t('statisticsPage.tables.winPct')}</th><th>{t('statisticsPage.tables.titles')}</th><th>{t('statisticsPage.tables.aces')}</th><th>{t('statisticsPage.tables.winners')}</th></tr></thead>
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

function TournamentStatisticsTable({ tournaments, t, number }: { tournaments: TournamentStat[]; t: TFunction; number: (value: number | null | undefined) => string }) {
  return (
    <div className="tlg-statistics-table-scroll">
      <table className="tlg-statistics-table tournament-table">
        <thead><tr><th>#</th><th>{t('statisticsPage.tables.tournament')}</th><th>{t('statisticsPage.tables.category')}</th><th>{t('statisticsPage.tables.surface')}</th><th>{t('statisticsPage.tables.editions')}</th><th>{t('statisticsPage.tables.matches')}</th><th>{t('statisticsPage.tables.players')}</th><th>{t('statisticsPage.tables.aces')}</th><th>{t('statisticsPage.tables.winners')}</th><th>{t('statisticsPage.tables.acesMatch')}</th><th>{t('statisticsPage.tables.topPerformer')}</th></tr></thead>
        <tbody>
          {tournaments.map((tournament) => (
            <tr key={tournament.tournament_series_id}>
              <td className="rank">{tournament.stats_rank}</td>
              <td><div className="tournament-cell"><CountryFlag countryCode={tournament.country_code} width={22} height={15} /><div><strong>{tournament.tournament_name}</strong><span>{tournament.city}</span></div></div></td>
              <td>{categoryLabel(tournament.category_code)}</td>
              <td><span className={`surface-pill ${tournament.surface}`}>{surfaceLabel(tournament.surface, t)}</span></td>
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

function CareerRecords({ career, t, number, money }: { career: CareerStats; t: TFunction; number: (value: number | null | undefined) => string; money: (value: number | null | undefined) => string }) {
  const player = career.player
  if (!player) return <EmptyState text={t('statisticsPage.career.unavailable')} />
  return (
    <div className="tlg-statistics-view career-view">
      <section className="tlg-statistics-career-summary">
        <div><span>{t('statisticsPage.career.currentRank')}</span><strong>#{player.current_rank}</strong><small>{t('statisticsPage.rankingPoints', { count: number(player.current_ranking_points) })}</small></div>
        <div><span>{t('statisticsPage.career.careerBest')}</span><strong>{career.best_rank ? `#${career.best_rank}` : '—'}</strong><small>{t('statisticsPage.career.rankingHistory')}</small></div>
        <div><span>{t('statisticsPage.career.matchRecord')}</span><strong>{player.wins}–{player.losses}</strong><small>{t('statisticsPage.winRate', { value: Number(player.win_pct).toFixed(1) })}</small></div>
        <div><span>{t('statisticsPage.career.titlesFinals')}</span><strong>{player.titles} / {player.finals}</strong><small>{t('statisticsPage.career.appearances', { count: player.tournament_appearances })}</small></div>
        <div><span>{t('statisticsPage.career.prizeMoney')}</span><strong>{money(career.career_prize_money)}</strong><small>{t('statisticsPage.career.financeLedger')}</small></div>
      </section>

      <div className="tlg-statistics-career-grid">
        <section className="tlg-statistics-panel">
          <header className="tlg-statistics-panel-head compact"><div><span>{t('statisticsPage.career.courtKicker')}</span><h2>{t('statisticsPage.career.surfaceRecord')}</h2></div></header>
          {career.surface_records.length === 0 ? <EmptyState text={t('statisticsPage.career.noSurface')} /> : (
            <div className="surface-record-grid">
              {career.surface_records.map((record) => (
                <div key={record.surface} className={`surface-record ${record.surface}`}>
                  <span>{surfaceLabel(record.surface, t)}</span><strong>{record.wins}–{record.losses}</strong><small>{Number(record.win_pct).toFixed(1)}% · {t('statisticsPage.matches', { count: record.matches })}</small>
                </div>
              ))}
            </div>
          )}
        </section>

        <section className="tlg-statistics-panel">
          <header className="tlg-statistics-panel-head compact"><div><span>{t('statisticsPage.career.shotKicker')}</span><h2>{t('statisticsPage.career.matchTotals')}</h2></div></header>
          <div className="career-shot-grid">
            <div><span>{t('statisticsPage.tables.aces')}</span><strong>{number(player.aces)}</strong></div>
            <div><span>{t('statisticsPage.tables.winners')}</span><strong>{number(player.winners)}</strong></div>
            <div><span>{t('statisticsPage.tables.unforcedErrors')}</span><strong>{number(player.unforced_errors)}</strong></div>
            <div><span>{t('statisticsPage.tables.totalPointsWon')}</span><strong>{number(player.total_points_won)}</strong></div>
          </div>
        </section>
      </div>

      <section className="tlg-statistics-panel">
        <header className="tlg-statistics-panel-head"><div><span>{t('statisticsPage.career.tournamentKicker')}</span><h2>{t('statisticsPage.career.byCategory')}</h2><p>{t('statisticsPage.career.byCategoryBody')}</p></div></header>
        {career.category_records.length === 0 ? <EmptyState text={t('statisticsPage.career.noCategories')} /> : (
          <div className="tlg-statistics-table-scroll">
            <table className="tlg-statistics-table"><thead><tr><th>{t('statisticsPage.tables.category')}</th><th>{t('statisticsPage.tables.tournaments')}</th><th>{t('statisticsPage.tables.matches')}</th><th>{t('statisticsPage.tables.wins')}</th><th>{t('statisticsPage.tables.losses')}</th><th>{t('statisticsPage.tables.winPct')}</th><th>{t('statisticsPage.tables.titles')}</th></tr></thead><tbody>
              {career.category_records.map((record) => <tr key={record.category_code}><td><strong>{categoryLabel(record.category_code)}</strong></td><td>{record.tournaments}</td><td>{record.matches}</td><td className="positive">{record.wins}</td><td className="negative">{record.losses}</td><td>{Number(record.win_pct).toFixed(1)}%</td><td>{record.titles}</td></tr>)}
            </tbody></table>
          </div>
        )}
      </section>

      <section className="tlg-statistics-panel">
        <header className="tlg-statistics-panel-head"><div><span>{t('statisticsPage.career.timelineKicker')}</span><h2>{t('statisticsPage.career.timeline')}</h2><p>{t('statisticsPage.career.timelineBody')}</p></div></header>
        {career.season_records.length === 0 ? <EmptyState text={t('statisticsPage.career.noSeasons')} /> : (
          <div className="tlg-statistics-table-scroll">
            <table className="tlg-statistics-table"><thead><tr><th>{t('statisticsPage.tables.season')}</th><th>{t('statisticsPage.tables.matches')}</th><th>{t('statisticsPage.tables.wins')}</th><th>{t('statisticsPage.tables.losses')}</th><th>{t('statisticsPage.tables.winPct')}</th><th>{t('statisticsPage.tables.titles')}</th></tr></thead><tbody>
              {career.season_records.map((record) => <tr key={record.season}><td><strong>{t('statisticsPage.season', { season: record.season })}</strong></td><td>{record.matches}</td><td className="positive">{record.wins}</td><td className="negative">{record.losses}</td><td>{Number(record.win_pct).toFixed(1)}%</td><td>{record.titles}</td></tr>)}
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
