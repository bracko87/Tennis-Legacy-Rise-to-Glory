import { Clock3, Coins } from 'lucide-react'
import { Link } from 'react-router'

import { useCommerce } from '../../hooks/useCommerce'
import { useGameClock } from '../../hooks/useGameClock'

export default function GameFooter() {
  const clock = useGameClock()
  const commerce = useCommerce()

  return (
    <footer className="tlg-v2-footer tlg-v4-footer tlg-v6-footer tlg-commerce-footer">
      <div className="tlg-v4-game-clock" aria-live="polite">
        <Clock3 size={15} />
        {clock.loading ? (
          <span>Synchronizing game clock…</span>
        ) : clock.error ? (
          <span>Game clock unavailable</span>
        ) : (
          <>
            <strong>Season {clock.season}</strong>
            <span>·</span>
            <span>{clock.month} {clock.day}</span>
            <span>·</span>
            <span>{clock.formattedTime}</span>
          </>
        )}
      </div>

      <Link
        to="/game/pro-packages"
        className="tlg-commerce-coin-balance"
        aria-label={`${commerce.coins} coins. Open Pro Packages.`}
        title="Open Pro Packages and coin store"
      >
        <Coins size={16} />
        <strong>{commerce.loading ? '—' : commerce.coins.toLocaleString()}</strong>
        <span>Coins</span>
      </Link>
    </footer>
  )
}
