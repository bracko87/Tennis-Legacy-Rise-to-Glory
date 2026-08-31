import { ChevronLeft, ChevronRight, Trophy } from 'lucide-react'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'

export default function RankingsPage() {
  const { player } = useAuth()
  const world = player?.world ?? 'ATP'

  return (
    <GameLayout title="Rankings" subtitle={`${world} singles world ranking`}>
      <header className="tlg-v2-page-head">
        <div className="tlg-v2-page-head-copy">
          <div className="tlg-v2-page-eyebrow">World competition</div>
          <h2 className="tlg-v2-page-title">{world} Ranking</h2>
          <p className="tlg-v2-page-description">
            This ranking is permanently separated by professional world. ATP players will only appear in the ATP singles ranking and WTA players will only appear in the WTA singles ranking.
          </p>
        </div>
      </header>

      <div className="tlg-ranking-layout">
        <section className="tlg-v2-panel">
          <header className="tlg-v2-panel-header">
            <div>
              <span>{world} singles</span>
              <h3>World Top 50</h3>
            </div>
            <div className="tlg-v2-panel-icon"><Trophy size={17} /></div>
          </header>

          <div className="tlg-ranking-table-head">
            <span>Rank</span>
            <span>Player</span>
            <span>Country</span>
            <span>Points</span>
          </div>
          <div className="tlg-ranking-empty">
            <Trophy size={25} />
            <strong>Ranking engine not populated yet</strong>
            <p>The first 50 ranked players will appear here as soon as official tournament results and ranking points are connected.</p>
          </div>
          <div className="tlg-ranking-pagination">
            <button type="button" disabled><ChevronLeft size={15} /> Previous 50</button>
            <span>Positions 1–50</span>
            <button type="button" disabled>Next 50 <ChevronRight size={15} /></button>
          </div>
        </section>

        <aside className="tlg-v2-panel">
          <header className="tlg-v2-panel-header">
            <div>
              <span>Your player</span>
              <h3>Current position</h3>
            </div>
          </header>
          <div className="tlg-ranking-player-position">
            <span>—</span>
            <div>
              <strong>Unranked</strong>
              <small>{player ? `${player.first_name} ${player.last_name}` : 'Current player'}</small>
              <p>Your real position will remain visible here even when you are outside the currently displayed Top 50 page.</p>
            </div>
          </div>
        </aside>
      </div>
    </GameLayout>
  )
}
