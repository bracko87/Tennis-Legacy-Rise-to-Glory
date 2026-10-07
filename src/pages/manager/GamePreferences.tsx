import { Bell, GraduationCap, SlidersHorizontal } from 'lucide-react'

import GameLayout from '../../components/layout/GameLayout'
import { useTutorial } from '../../tutorial/TutorialProvider'
import '../../styles/game-preferences.css'

export default function GamePreferencesPage() {
  const { status: tutorialStatus, restartTutorial } = useTutorial()

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

        <section className="tlg-preferences-section">
          <header className="tlg-preferences-section-head">
            <div>
              <span>Guided help</span>
              <h3>Game Tutorial</h3>
              <p>Run the complete page-by-page tutorial again whenever you want a guided refresher.</p>
            </div>
            <GraduationCap size={21} aria-hidden="true" />
          </header>

          <div className="tlg-tutorial-preferences-card">
            <div>
              <strong>{tutorialStatus === 'completed' ? 'Tutorial completed' : tutorialStatus === 'skipped' ? 'Tutorial previously skipped' : 'Interactive tutorial available'}</strong>
              <p>Progress is saved to your player, so you can pause the tutorial on one device and continue later.</p>
            </div>
            <button type="button" className="tlg-tutorial-launcher" onClick={() => void restartTutorial()}>
              <GraduationCap size={16} />
              {tutorialStatus === 'completed' || tutorialStatus === 'skipped' ? 'Restart Tutorial' : 'Start Tutorial'}
            </button>
          </div>
        </section>
      </div>
    </GameLayout>
  )
}
