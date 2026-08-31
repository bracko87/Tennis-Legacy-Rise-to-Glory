import { Crown, House, LockKeyhole } from 'lucide-react'
import { useNavigate } from 'react-router'

import GameLayout from '../../components/layout/GameLayout'
import { useCommerce } from '../../hooks/useCommerce'

export default function PrivateLifePage() {
  const navigate = useNavigate()
  const { isPremium, loading } = useCommerce()

  if (loading) {
    return (
      <GameLayout title="Private Life" subtitle="Premium lifestyle and personal spending">
        <div className="tlg-premium-lock"><span>Checking Premium membership…</span></div>
      </GameLayout>
    )
  }

  if (!isPremium) {
    return (
      <GameLayout title="Private Life" subtitle="Premium lifestyle and personal spending">
        <section className="tlg-premium-lock">
          <div className="tlg-premium-lock-icon"><LockKeyhole size={28} /></div>
          <span>Premium feature</span>
          <h2>Private Life</h2>
          <p>This optional career-life module is available only to Tennis Legacy Premium members. It will use career money won and earned inside the tennis simulation, not Premium coins.</p>
          <button type="button" onClick={() => navigate('/game/pro-packages')}><Crown size={16} /> View Premium</button>
        </section>
      </GameLayout>
    )
  }

  return (
    <GameLayout title="Private Life" subtitle="Premium lifestyle and personal spending">
      <header className="tlg-v2-page-head">
        <div className="tlg-v2-page-head-copy">
          <div className="tlg-v2-page-eyebrow">Premium career life</div>
          <h2 className="tlg-v2-page-title">Private Life</h2>
          <p className="tlg-v2-page-description">Use money earned through your professional tennis career for optional lifestyle choices outside competition. The detailed categories and effects will be designed later.</p>
        </div>
      </header>
      <section className="tlg-v2-panel">
        <header className="tlg-v2-panel-header">
          <div><span>Premium module</span><h3>Lifestyle system</h3></div>
          <div className="tlg-v2-panel-icon"><House size={17} /></div>
        </header>
        <div className="tlg-v2-panel-body">
          <div className="tlg-v2-empty"><House size={24} /><strong>Private Life categories coming later</strong><p>The page is now reserved and Premium-gated. We can define homes, transport, leisure, investments and other lifestyle systems in a later phase.</p></div>
        </div>
      </section>
    </GameLayout>
  )
}
