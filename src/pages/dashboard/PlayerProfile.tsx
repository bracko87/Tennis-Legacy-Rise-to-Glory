import { ArrowLeft, Mail, Trophy, UserRound } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router'

import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import usePlayerAvatarUrl from '../../hooks/usePlayerAvatarUrl'
import { supabase } from '../../lib/supabase'
import '../../styles/player-public-profile.css'

interface PlayerProfileRow {
  player_id: string
  first_name: string
  last_name: string
  world: 'ATP' | 'WTA'
  country_code: string
  image_path: string | null
  ranking_points: number
  rank_position: number
  is_own_player: boolean
}

export default function PlayerProfilePage() {
  const { playerId } = useParams()
  const navigate = useNavigate()
  const [profile, setProfile] = useState<PlayerProfileRow | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [messageBusy, setMessageBusy] = useState(false)
  const avatarUrl = usePlayerAvatarUrl(profile?.image_path)

  useEffect(() => {
    let active = true
    async function loadProfile() {
      if (!playerId) return
      setLoading(true)
      setError(null)
      const { data, error: loadError } = await supabase.rpc('get_player_profile_v1', { p_player_id: playerId })
      if (!active) return
      const row = (Array.isArray(data) ? data[0] : data) as PlayerProfileRow | undefined
      if (loadError || !row) {
        setProfile(null)
        setError(loadError?.message ?? 'Player profile not found.')
      } else {
        setProfile(row)
      }
      setLoading(false)
    }
    void loadProfile()
    return () => { active = false }
  }, [playerId])

  async function startConversation() {
    if (!profile || profile.is_own_player || messageBusy) return
    setMessageBusy(true)
    const { data, error: conversationError } = await supabase.rpc('get_or_create_player_conversation_v1', {
      p_target_player_id: profile.player_id,
    })
    setMessageBusy(false)
    if (conversationError || !data) {
      setError(conversationError?.message ?? 'Unable to start conversation.')
      return
    }
    navigate(`/game/inbox?conversation=${encodeURIComponent(String(data))}`)
  }

  const name = profile ? `${profile.first_name} ${profile.last_name}` : 'Player'

  return (
    <GameLayout title="Player profile" subtitle="Professional player identity">
      <div className="tlg-public-player-page">
        <Link to="/game/rankings" className="tlg-public-player-back"><ArrowLeft size={15} /> Back to Rankings</Link>

        {loading ? (
          <div className="tlg-public-player-state">Loading player profile…</div>
        ) : error && !profile ? (
          <div className="tlg-public-player-state">{error}</div>
        ) : profile ? (
          <section className="tlg-public-player-card">
            <div className="tlg-public-player-avatar">
              {avatarUrl ? <img src={avatarUrl} alt={`${name} avatar`} /> : <UserRound size={72} />}
            </div>

            <div className="tlg-public-player-main">
              <span className="tlg-public-player-kicker">{profile.world} singles player</span>
              <h1>{name}</h1>
              <div className="tlg-public-player-country">
                <CountryFlag countryCode={profile.country_code} countryName={profile.country_code} width={26} height={17} />
                <span>{profile.country_code}</span>
              </div>

              <div className="tlg-public-player-stats">
                <article><Trophy size={17} /><span>World ranking</span><strong>#{profile.rank_position}</strong></article>
                <article><Trophy size={17} /><span>Ranking points</span><strong>{profile.ranking_points.toLocaleString()}</strong></article>
                <article><UserRound size={17} /><span>Competition world</span><strong>{profile.world}</strong></article>
              </div>

              <div className="tlg-public-player-actions">
                {profile.is_own_player ? (
                  <span className="tlg-public-player-own">This is your player profile.</span>
                ) : (
                  <button type="button" onClick={startConversation} disabled={messageBusy}>
                    <Mail size={17} /> {messageBusy ? 'Opening…' : 'Send message'}
                  </button>
                )}
              </div>

              {error && <p className="tlg-public-player-error">{error}</p>}
            </div>
          </section>
        ) : null}
      </div>
    </GameLayout>
  )
}
