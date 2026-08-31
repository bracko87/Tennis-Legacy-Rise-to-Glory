import type { CSSProperties } from 'react'
import { useEffect, useState } from 'react'
import { useParams } from 'react-router'

import { supabase } from '../../lib/supabase'
import '../../styles/tournament-logo.css'
import TournamentPageV3 from './TournamentV3'

interface TournamentLogoRow {
  logo_url: string | null
  tournament_name: string
}

export default function TournamentPage() {
  const { competitionId } = useParams()
  const [logoUrl, setLogoUrl] = useState<string | null>(null)
  const [logoReady, setLogoReady] = useState(false)
  const [tournamentName, setTournamentName] = useState('Tournament')

  useEffect(() => {
    if (!competitionId) {
      setLogoUrl(null)
      setLogoReady(false)
      return
    }

    let cancelled = false

    async function loadLogo() {
      const { data, error } = await supabase.rpc('get_tournament_detail_v1', {
        p_competition_id: competitionId,
      })

      if (cancelled || error) return

      const row = (Array.isArray(data) ? data[0] : data) as TournamentLogoRow | null
      setLogoUrl(row?.logo_url ?? null)
      setTournamentName(row?.tournament_name ?? 'Tournament')
      setLogoReady(false)
    }

    void loadLogo()

    return () => {
      cancelled = true
    }
  }, [competitionId])

  const logoStyle = logoReady && logoUrl
    ? ({ '--tlg-tournament-logo': `url("${logoUrl}")` } as CSSProperties)
    : undefined

  return (
    <div
      className={logoReady && logoUrl ? 'tlg-tournament-logo-context' : undefined}
      style={logoStyle}
    >
      {logoUrl && (
        <img
          className="tlg-tournament-logo-preload"
          src={logoUrl}
          alt=""
          aria-hidden="true"
          onLoad={() => setLogoReady(true)}
          onError={() => setLogoReady(false)}
        />
      )}
      <TournamentPageV3 />
      {logoReady && logoUrl && (
        <span className="sr-only">Official in-game logo for {tournamentName}</span>
      )}
    </div>
  )
}
