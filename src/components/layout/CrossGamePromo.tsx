import { ExternalLink } from 'lucide-react'

import { supabase } from '../../lib/supabase'
import '../../styles/cross-game-promo.css'

const PROPELOTON_URL = 'https://propelotonmanager.com/?source=tennis_legacy'
const PROPELOTON_LOGO_URL =
  'https://okuravitxocyevkexfgi.supabase.co/storage/v1/object/public/Admin%20Staff/Brend%20images/5c3417dc-3924-4423-948a-745ae5902ed0.png'

export interface CrossGamePromoProps {
  surface: string
  variant?: 'compact' | 'card'
}

export default function CrossGamePromo({
  surface,
  variant = 'compact',
}: CrossGamePromoProps) {
  function recordClick() {
    void supabase.rpc('record_cross_game_referral_event_v1', {
      p_event_type: 'outgoing_click',
      p_source_game: 'tennis_legacy',
      p_destination_game: 'propeloton_manager',
      p_surface: surface,
    })
  }

  return (
    <a
      href={PROPELOTON_URL}
      target="_blank"
      rel="noreferrer"
      onClick={recordClick}
      className={`tlg-cross-game-promo ${variant === 'card' ? 'is-card' : 'is-compact'}`}
      aria-label="Play ProPeloton Manager, another game from Next Quest Studio"
    >
      <span className="tlg-cross-game-logo">
        <img src={PROPELOTON_LOGO_URL} alt="" aria-hidden="true" />
      </span>

      <span className="tlg-cross-game-copy">
        <small>Also from our studio</small>
        <strong>ProPeloton Manager</strong>
        {variant === 'card' && (
          <span>Build and manage your own professional cycling team.</span>
        )}
      </span>

      <span className="tlg-cross-game-action">
        Play Now
        <ExternalLink size={14} />
      </span>
    </a>
  )
}
