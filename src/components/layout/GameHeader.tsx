import { Bell, LogOut, Menu } from 'lucide-react'
import { useNavigate } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import { supabase } from '../../lib/supabase'

export interface GameHeaderProps {
  title: string
  subtitle?: string
  onToggleSidebarMobile?: () => void
}

export default function GameHeader({
  title,
  subtitle,
  onToggleSidebarMobile,
}: GameHeaderProps) {
  const navigate = useNavigate()
  const { player, signOut } = useAuth()

  const displayName = player
    ? `${player.first_name} ${player.last_name}`.trim()
    : 'Player Account'
  const initials = player
    ? `${player.first_name.charAt(0)}${player.last_name.charAt(0)}`.toUpperCase()
    : 'TL'
  const avatarUrl = player?.image_path
    ? supabase.storage.from('player-avatars').getPublicUrl(player.image_path).data.publicUrl
    : null

  async function handleSignOut() {
    try {
      await signOut()
    } finally {
      navigate('/login', { replace: true })
    }
  }

  return (
    <header className="tlg-v2-header">
      <div className="tlg-v2-header-left">
        <button
          type="button"
          className="tlg-v2-mobile-menu"
          onClick={onToggleSidebarMobile}
          aria-label="Open navigation"
        >
          <Menu size={18} />
        </button>

        <div className="min-w-0">
          <div className="tlg-v2-header-kicker">
            <i /> Manager center
          </div>
          <div className="tlg-v2-header-title">{title}</div>
          {subtitle && <div className="tlg-v2-header-subtitle">{subtitle}</div>}
        </div>
      </div>

      <div className="tlg-v2-header-right">
        <div className="tlg-v2-header-chip">
          <span className="tlg-v2-header-chip-badge">{player?.world ?? '—'}</span>
          <div className="tlg-v2-header-chip-copy">
            <span>Career world</span>
            <strong>Season 1</strong>
          </div>
        </div>

        <button type="button" className="tlg-v2-header-icon" aria-label="Notifications">
          <Bell size={16} />
        </button>

        <div className="tlg-v2-profile-chip">
          <span className="tlg-v2-profile-avatar">
            {avatarUrl ? <img src={avatarUrl} alt="" /> : initials}
          </span>
          <div className="tlg-v2-profile-copy">
            <span>{player?.world ?? '—'} professional</span>
            <strong>{displayName}</strong>
          </div>
        </div>

        <button
          type="button"
          className="tlg-v2-signout"
          onClick={() => void handleSignOut()}
          aria-label="Sign out"
          title="Sign out"
        >
          <LogOut size={15} />
        </button>
      </div>
    </header>
  )
}
