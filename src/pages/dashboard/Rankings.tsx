import { ChevronLeft, ChevronRight, Trophy } from 'lucide-react'
import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/rankings-live.css'

interface RankingRow {
  rank_position: number
  player_id: string
  first_name: string
  last_name: string
  country_code: string
  image_path: string | null
  ranking_points: number
}

const PAGE_SIZE = 50

export default function RankingsPage() {
  const { player } = useAuth()
  const world = player?.world ?? 'ATP'
  const [page, setPage] = useState(0)
  const [rows, setRows] = useState<RankingRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const loadRankings = useCallback(async () => {
    setLoading(true)
    setError(null)
    const { data, error: loadError } = await supabase.rpc('get_world_rankings_v1', {
      p_world: world,
      p_offset: page * PAGE_SIZE,
      p_limit: PAGE_SIZE,
    })

    if (loadError) {
      setError(loadError.message)
      setRows([])
    } else {
      setRows((data ?? []) as RankingRow[])
    }
    setLoading(false)
  }, [page, world])

  useEffect(() => {
    setPage(0)
  }, [world])

  useEffect(() => {
    void loadRankings()
  }, [loadRankings])

  return (
    <GameLayout title="Rankings" subtitle={`${world} singles world ranking`}>
      <header className="tlg-v2-page-head">
        <div className="tlg-v2-page-head-copy">
          <div className="tlg-v2-page-eyebrow">World competition</div>
          <h2 className="tlg-v2-page-title">{world} Ranking</h2>
          <p className="tlg-v2-page-description">
            Every created player enters the appropriate singles ranking immediately. ATP and WTA rankings remain completely separate.
          </p>
        </div>
      </header>

      <section className="tlg-v2-panel">
        <header className="tlg-v2-panel-header">
          <div>
            <span>{world} singles</span>
            <h3>World Ranking</h3>
          </div>
          <div className="tlg-v2-panel-icon"><Trophy size={17} /></div>
        </header>

        <div className="tlg-ranking-table-head">
          <span>Rank</span>
          <span>Player</span>
          <span>Country</span>
          <span>Points</span>
        </div>

        {loading ? (
          <div className="tlg-ranking-empty"><strong>Loading ranking…</strong></div>
        ) : error ? (
          <div className="tlg-ranking-empty"><strong>Unable to load ranking</strong><p>{error}</p></div>
        ) : rows.length === 0 ? (
          <div className="tlg-ranking-empty">
            <Trophy size={25} />
            <strong>No ranked players yet</strong>
            <p>Created players will appear here automatically.</p>
          </div>
        ) : (
          <div className="tlg-live-ranking-rows">
            {rows.map((row) => (
              <Link
                key={row.player_id}
                to={`/game/players/${row.player_id}`}
                className={`tlg-live-ranking-row ${row.player_id === player?.id ? 'tlg-live-ranking-row-own' : ''}`}
              >
                <strong className="tlg-live-rank-number">{row.rank_position}</strong>
                <span className="tlg-live-player-name">{row.first_name} {row.last_name}</span>
                <span className="tlg-live-country"><CountryFlag countryCode={row.country_code} countryName={row.country_code} width={22} height={15} /> {row.country_code}</span>
                <strong className="tlg-live-points">{row.ranking_points.toLocaleString()}</strong>
              </Link>
            ))}
          </div>
        )}

        <div className="tlg-ranking-pagination">
          <button type="button" disabled={page === 0 || loading} onClick={() => setPage((value) => Math.max(0, value - 1))}><ChevronLeft size={15} /> Previous 50</button>
          <span>Positions {page * PAGE_SIZE + 1}–{page * PAGE_SIZE + Math.max(rows.length, 1)}</span>
          <button type="button" disabled={rows.length < PAGE_SIZE || loading} onClick={() => setPage((value) => value + 1)}>Next 50 <ChevronRight size={15} /></button>
        </div>
      </section>
    </GameLayout>
  )
}
