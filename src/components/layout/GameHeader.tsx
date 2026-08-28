/**
 * GameHeader.tsx
 *
 * Shared premium command bar for all authenticated game routes.
 */

import { Bell, ChevronDown, LogOut, Menu, Radio } from 'lucide-react'
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
    <header className="tlg-game-header">
      <div className="flex min-h-[72px] items-center justify-between gap-4">
        <div className="flex min-w-0 items-center gap-3">
          <button
            type="button"
            onClick={onToggleSidebarMobile}
            className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-xl border border-[rgba(118,174,218,.12)] bg-[rgba(10,30,50,.7)] text-[color:#8ea9bf] transition hover:border-[rgba(82,172,237,.25)] hover:text-white md:hidden"
            aria-label="Open navigation"
          >
            <Menu size={17} />
          </button>

          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <span className="hidden text-[0.62rem] font-extrabold uppercase tracking-[.15em] text-[color:#5faee8] sm:inline">
                Tennis Legacy
              </span>
              <span className="hidden h-1 w-1 rounded-full bg-[color:#32516b] sm:inline" />
              <span className="hidden items-center gap-1 text-[0.62rem] text-[color:#68839a] sm:inline-flex">
                <Radio size={11} /> Live career world
              </span>
            </div>
            <div className="mt-0.5 flex min-w-0 items-baseline gap-3">
              <h1 className="truncate text-[1rem] font-bold tracking-[-.025em] text-[color:#f0f7fd] md:text-[1.08rem]">
                {title}
              </h1>
              {subtitle && (
                <span className="hidden truncate text-[0.69rem] text-[color:#69849a] lg:inline">
                  {subtitle}
                </span>
              )}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <div className="hidden items-center gap-2 rounded-xl border border-[rgba(116,174,218,.1)] bg-[rgba(6,22,38,.55)] px-3 py-2 md:flex">
            <span className="inline-flex h-6 w-6 items-center justify-center rounded-lg bg-[rgba(15,96,164,.18)] text-[0.62rem] font-extrabold text-[color:#71c4fb]">
              {player?.world ?? '—'}
            </span>
            <div className="leading-tight">
              <span className="block text-[0.56rem] uppercase tracking-[.08em] text-[color:#55738c]">Career world</span>
              <strong className="block text-[0.68rem] font-semibold text-[color:#a9c0d2]">Season 1</strong>
            </div>
          </div>

          <button
            type="button"
            aria-label="Notifications"
            className="relative inline-flex h-9 w-9 items-center justify-center rounded-xl border border-[rgba(116,174,218,.1)] bg-[rgba(6,22,38,.55)] text-[color:#7793a9] transition hover:border-[rgba(82,172,237,.25)] hover:text-white"
          >
            <Bell size={16} />
            <span className="absolute right-2 top-2 h-1.5 w-1.5 rounded-full bg-[color:#2d9be7] shadow-[0_0_0_3px_rgba(45,155,231,.1)]" />
          </button>

          <div className="hidden items-center gap-2 rounded-xl border border-[rgba(116,174,218,.1)] bg-[rgba(6,22,38,.55)] p-1.5 pr-2 sm:flex">
            <span className="inline-flex h-8 w-8 shrink-0 items-center justify-center overflow-hidden rounded-lg border border-[rgba(94,177,235,.14)] bg-[linear-gradient(145deg,rgba(18,101,174,.34),rgba(5,31,55,.72))] text-[0.62rem] font-extrabold text-[color:#b6def6]">
              {avatarUrl ? <img src={avatarUrl} alt="" className="h-full w-full object-cover" /> : initials}
            </span>
            <div className="max-w-[150px] leading-tight">
              <strong className="block truncate text-[0.7rem] font-semibold text-[color:#c9dce9]">{displayName}</strong>
              <span className="block text-[0.58rem] text-[color:#607a91]">{player?.world ?? '—'} professional</span>
            </div>
            <ChevronDown size={13} className="text-[color:#4e6d85]" />
          </div>

          <button
            type="button"
            onClick={() => void handleSignOut()}
            className="inline-flex h-9 items-center gap-1.5 rounded-xl border border-[rgba(116,174,218,.1)] bg-[rgba(6,22,38,.55)] px-2.5 text-[0.67rem] font-semibold text-[color:#7893aa] transition hover:border-[rgba(239,120,120,.22)] hover:bg-[rgba(105,33,41,.16)] hover:text-[color:#ffc2c2]"
          >
            <LogOut size={14} />
            <span className="hidden lg:inline">Sign out</span>
          </button>
        </div>
      </div>
    </header>
  )
}
