import type { ReactNode } from 'react'
import { Navigate } from 'react-router'

import { useAuth } from './AuthContext'

function LoadingScreen() {
  return (
    <div className="min-h-screen bg-[var(--tlg-deep)] text-[var(--tlg-white)] flex items-center justify-center px-6">
      <div className="text-center">
        <p className="tlg-page-heading-eyebrow">Tennis Legacy</p>
        <p className="mt-2 text-sm text-[var(--tlg-text-muted)]">Loading your manager session…</p>
      </div>
    </div>
  )
}

export function AnonymousOnly({ children }: { readonly children: ReactNode }) {
  const { user, player, isAdmin, authLoading, playerLoading, adminLoading } = useAuth()

  if (authLoading || (user && (playerLoading || adminLoading))) return <LoadingScreen />

  if (user) {
    if (isAdmin && !player) return <Navigate to="/game/admin/analytics" replace />
    return <Navigate to={player ? '/game/overview' : '/create-player'} replace />
  }

  return <>{children}</>
}

export function RequireAuth({ children }: { readonly children: ReactNode }) {
  const { user, authLoading } = useAuth()

  if (authLoading) return <LoadingScreen />
  if (!user) return <Navigate to="/login" replace />

  return <>{children}</>
}

export function RequirePlayer({ children }: { readonly children: ReactNode }) {
  const { user, player, authLoading, playerLoading } = useAuth()

  if (authLoading || (user && playerLoading)) return <LoadingScreen />
  if (!user) return <Navigate to="/login" replace />
  if (!player) return <Navigate to="/create-player" replace />

  return <>{children}</>
}

export function RequireAdmin({ children }: { readonly children: ReactNode }) {
  const { user, isAdmin, authLoading, adminLoading } = useAuth()

  if (authLoading || (user && adminLoading)) return <LoadingScreen />
  if (!user) return <Navigate to="/login" replace />
  if (!isAdmin) return <Navigate to="/game/overview" replace />

  return <>{children}</>
}

export function RequireNoPlayer({ children }: { readonly children: ReactNode }) {
  const { user, player, authLoading, playerLoading } = useAuth()

  if (authLoading || (user && playerLoading)) return <LoadingScreen />
  if (!user) return <Navigate to="/login" replace />
  if (player) return <Navigate to="/game/overview" replace />

  return <>{children}</>
}
