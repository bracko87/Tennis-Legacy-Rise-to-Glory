import { Clock3, Coins, ExternalLink } from 'lucide-react'
import { Link } from 'react-router'

import { useCommerce } from '../../hooks/useCommerce'
import { useGameClock } from '../../hooks/useGameClock'
import { weekdayForDate } from '../../lib/competitionCalendar'
import { supabase } from '../../lib/supabase'

const PROPELOTON_URL = 'https://propelotonmanager.com/?source=tennis_legacy'
const PROPELOTON_LOGO_URL =
  'https://okuravitxocyevkexfgi.supabase.co/storage/v1/object/public/Admin%20Staff/Brend%20images/5c3417dc-3924-4423-948a-745ae5902ed0.png'

export default function GameFooter() {
  const clock = useGameClock()
  const commerce = useCommerce()
  const weekday = weekdayForDate(clock.monthIndex, clock.day)

  function recordCrossGameClick() {
    void supabase.rpc('record_cross_game_referral_event_v1', {
      p_event_type: 'outgoing_click',
      p_source_game: 'tennis_legacy',
      p_destination_game: 'propeloton_manager',
      p_surface: 'game_footer',
    })
  }

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
            <span>{weekday}, {clock.month} {clock.day}</span>
            <span>·</span>
            <span>{clock.formattedTime}</span>
          </>
        )}
      </div>

      <a
        href={PROPELOTON_URL}
        target="_blank"
        rel="noreferrer"
        onClick={recordCrossGameClick}
        aria-label="Play ProPeloton Manager, another game from Next Quest Studio"
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: 8,
          marginLeft: 'auto',
          padding: '6px 9px',
          border: '1px solid #d9e5ec',
          borderRadius: 10,
          background: '#fff',
          color: '#17344b',
          textDecoration: 'none',
          minWidth: 0,
        }}
      >
        <img
          src={PROPELOTON_LOGO_URL}
          alt=""
          aria-hidden="true"
          style={{ width: 30, height: 30, objectFit: 'contain', borderRadius: 7, background: '#081224' }}
        />
        <span style={{ display: 'grid', gap: 1, lineHeight: 1.1 }}>
          <small style={{ color: '#718697', fontSize: 8, fontWeight: 800, textTransform: 'uppercase', letterSpacing: '.05em' }}>
            Also from our studio
          </small>
          <strong style={{ fontSize: 11 }}>ProPeloton Manager</strong>
        </span>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: '#1377ad', fontSize: 9, fontWeight: 850 }}>
          Play
          <ExternalLink size={12} />
        </span>
      </a>

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
