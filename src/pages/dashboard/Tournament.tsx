import { createPortal } from 'react-dom'
import { useEffect, useState } from 'react'
import { useParams } from 'react-router'

import { supabase } from '../../lib/supabase'
import '../../styles/tournament-logo.css'
import TournamentPageV3 from './TournamentV3'

interface TournamentLogoRow {
  logo_url: string | null
  tournament_name: string
}

type LogoStatus = 'none' | 'loading' | 'ready' | 'error'

export default function TournamentPage() {
  const { competitionId } = useParams()
  const [logoUrl, setLogoUrl] = useState<string | null>(null)
  const [logoStatus, setLogoStatus] = useState<LogoStatus>('none')
  const [logoTarget, setLogoTarget] = useState<HTMLElement | null>(null)
  const [tournamentName, setTournamentName] = useState('Tournament')

  useEffect(() => {
    if (!competitionId) {
      setLogoUrl(null)
      setLogoStatus('none')
      return
    }

    let cancelled = false

    async function loadLogo() {
      const { data, error } = await supabase.rpc('get_tournament_detail_v1', {
        p_competition_id: competitionId,
      })

      if (cancelled || error) return

      const row = (Array.isArray(data) ? data[0] : data) as TournamentLogoRow | null
      const nextLogoUrl = row?.logo_url ?? null

      setLogoUrl(nextLogoUrl)
      setTournamentName(row?.tournament_name ?? 'Tournament')
      setLogoStatus(nextLogoUrl ? 'loading' : 'none')
    }

    void loadLogo()

    return () => {
      cancelled = true
    }
  }, [competitionId])

  useEffect(() => {
    let frame = 0
    let cancelled = false

    function findLogoTarget() {
      if (cancelled) return

      const target = document.querySelector<HTMLElement>('.tlg-detail-logo-slot')
      if (target) {
        setLogoTarget(target)
        return
      }

      frame = window.requestAnimationFrame(findLogoTarget)
    }

    frame = window.requestAnimationFrame(findLogoTarget)

    return () => {
      cancelled = true
      window.cancelAnimationFrame(frame)
      setLogoTarget(null)
    }
  }, [competitionId])

  const showRealLogo = Boolean(logoTarget && logoUrl && logoStatus !== 'error')

  return (
    <div className={logoStatus === 'ready' ? 'tlg-tournament-logo-context' : undefined}>
      <TournamentPageV3 />

      {showRealLogo && logoTarget && logoUrl && createPortal(
        <img
          className={`tlg-tournament-logo-image ${logoStatus === 'ready' ? 'tlg-tournament-logo-image-ready' : ''}`}
          src={logoUrl}
          alt={`${tournamentName} tournament logo`}
          decoding="async"
          fetchPriority="high"
          onLoad={() => setLogoStatus('ready')}
          onError={() => setLogoStatus('error')}
        />,
        logoTarget,
      )}
    </div>
  )
}
