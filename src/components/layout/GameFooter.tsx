import { Clock3 } from 'lucide-react'

import { useGameClock } from '../../hooks/useGameClock'

export default function GameFooter() {
  const clock = useGameClock()

  return (
    <footer className="tlg-v2-footer tlg-v4-footer tlg-v6-footer">
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
    </footer>
  )
}
