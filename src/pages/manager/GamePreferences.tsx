import { Bell, SlidersHorizontal } from 'lucide-react'

import GameLayout from '../../components/layout/GameLayout'
import '../../styles/game-preferences.css'

export default function GamePreferencesPage() {
  return (
    <GameLayout title="Game preferences" subtitle="Personal game experience settings">
      <div className="tlg-preferences-page">
        <header className="tlg-preferences-intro">
          <span>Manager settings</span>
          <h2>Preferences</h2>
          <p>Control how Tennis Legacy communicates important in-game events and career updates.</p>
        </header>

        <section className="tlg-preferences-section">
          <header className="tlg-preferences-section-head">
            <div>
              <span>Notifications</span>
              <h3>In-Game Notifications</h3>
              <p>Choose which game events should create notifications in your manager center.</p>
            </div>
            <Bell size={21} aria-hidden="true" />
          </header>

          <div className="tlg-preferences-empty">
            <span className="tlg-preferences-empty-icon"><SlidersHorizontal size={24} /></span>
            <div>
              <strong>Notification preferences are not configured yet</strong>
              <p>
                This section is ready for the individual notification controls. The options will be added when the corresponding Tennis Legacy notification systems are connected.
              </p>
            </div>
          </div>
        </section>
      </div>
    </GameLayout>
  )
}
