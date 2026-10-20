import { Crown, LockKeyhole, Star, BellRing, X } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'
import { useMemo } from 'react'
import { monthDayFromDayOfSeason } from '../../lib/competitionCalendar'
import { tournamentWatchLabels } from '../../lib/tournamentWatchI18n'
import type { WatchedTournament } from '../../hooks/usePremiumTournamentWatchlist'
import '../../styles/premium-tournament-watchlist.css'

type Props = {
  watches: WatchedTournament[]
  isPremium: boolean
  premiumLoading: boolean
  loading: boolean
  busyId: string | null
  error: string | null
  onUnwatch: (competitionId: string) => Promise<boolean>
}

export default function PremiumTournamentWatchlist({
  watches, isPremium, premiumLoading, loading, busyId, error, onUnwatch,
}: Props) {
  const { t, i18n } = useTranslation()
  const l = tournamentWatchLabels(i18n.resolvedLanguage ?? i18n.language)
  const months = t('calendarPage.months', { returnObjects: true }) as string[]
  const gameDate = (seconds: number | null) => {
    if (seconds === null || !Number.isFinite(seconds)) return '—'
    const absoluteDay = Math.floor(seconds / 86400)
    const season = Math.floor(absoluteDay / 366) + 1
    const { monthIndex, day } = monthDayFromDayOfSeason((absoluteDay % 366) + 1)
    return `${t('statisticsPage.season', { season })} · ${months[monthIndex]} ${day}`
  }
  const sorted = useMemo(() => [...watches].sort((a, b) =>
    (a.status === 'open' ? -1 : b.status === 'open' ? 1 : 0) ||
    (a.open_game_second ?? 999999999) - (b.open_game_second ?? 999999999) ||
    a.name.localeCompare(b.name)), [watches])
  const statusLabel = (status: WatchedTournament['status']) => l[status]

  return (
    <section className="tlg-twatch" aria-label={l.title}>
      <header className="tlg-twatch-head">
        <div>
          <span className="tlg-twatch-kicker"><Crown size={15} aria-hidden="true" /> PREMIUM</span>
          <h3><BellRing size={19} aria-hidden="true" /> {l.title}</h3>
          <p>{l.intro}</p>
        </div>
        {isPremium && <strong className="tlg-twatch-count">{watches.length} / 60</strong>}
      </header>
      {premiumLoading ? <p className="tlg-twatch-state">{l.loading}</p>
        : !isPremium ? <div className="tlg-twatch-locked"><LockKeyhole size={18} /><span>{l.locked}</span><Link to="/game/pro-packages">{l.plans}</Link></div>
        : <>
          {loading && <p className="tlg-twatch-state">{l.loading}</p>}
          {error && <p role="alert" className="tlg-twatch-error">{l.error} <small>{error}</small></p>}
          {!loading && sorted.length === 0 && <p className="tlg-twatch-state">{l.empty}</p>}
          {sorted.length > 0 && <div className="tlg-twatch-list">
            {sorted.map(item => <div className="tlg-twatch-item" key={item.competition_id}>
              <span className={`tlg-twatch-star tlg-twatch-${item.status}`}><Star size={17} fill="currentColor" aria-hidden="true" /></span>
              <div className="tlg-twatch-item-copy">
                <strong>{item.name}</strong>
                <small>{item.city} · {item.category_code}</small>
                <span className={`tlg-twatch-status tlg-twatch-${item.status}`}>{statusLabel(item.status)}</span>
                <span className="tlg-twatch-date">{l.opens}: {gameDate(item.open_game_second)} · {l.closes}: {gameDate(item.close_game_second)}</span>
              </div>
              <div className="tlg-twatch-actions">
                <Link to={`/game/tournaments/${item.competition_id}`}>{l.openTournament}</Link>
                <button type="button" disabled={busyId !== null}
                  title={l.unwatch} aria-label={`${l.unwatch}: ${item.name}`}
                  onClick={() => void onUnwatch(item.competition_id)}><X size={17}/></button>
              </div>
            </div>)}
          </div>}
          <p className="tlg-twatch-foot">{l.limit}. {l.note}</p>
        </>}
    </section>
  )
}
