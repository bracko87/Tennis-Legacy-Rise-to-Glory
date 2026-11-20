import { useState } from 'react'
import { Link } from 'react-router'
import { Eye, LockKeyhole, ShieldCheck } from 'lucide-react'
import GameLayout from '../../components/layout/GameLayout'
import TryAsGuestPage from '../auth/TryAsGuest'
import '../../styles/helios-guest-preview.css'

type Stage = 'homepage' | 'guest' | 'player' | 'registration'

const stages: Array<{ id: Stage; label: string }> = [
  { id: 'homepage', label: 'Homepage entry' },
  { id: 'guest', label: 'Test Player entry' },
  { id: 'player', label: 'Create Player' },
  { id: 'registration', label: 'Save Progress' },
]

/**
 * Read-only ADMIN-ONLY UI review. RequireAdmin protects the route in App.
 * No Auth signInAnonymously, no enrollment, no storage or database writes.
 * NOT a substitute for testing actual guest signup and same-user conversion.
 */
export default function GuestModePreviewPage() {
  const [stage, setStage] = useState<Stage>('homepage')
  return (
    <GameLayout title="Helios · Guest UI Preview" subtitle="Admin-only visual review — feature disabled for public users">
      <div className="tlg-helios-preview">
        <div className="tlg-helios-preview-alert" role="status">
          <LockKeyhole size={21} />
          <div>
            <strong>Preview mode — no real guest account is created</strong>
            <p>These screens are for reviewing the onboarding layout. Guest Mode remains OFF in the server, no trial clock starts and no game or account data is changed.</p>
          </div>
        </div>
        <div className="tlg-helios-preview-top">
          <p><Eye size={18}/> Select a screen to inspect</p>
          <Link to="/game/admin/analytics">Return to Admin Analytics</Link>
        </div>
        <nav className="tlg-helios-preview-tabs" aria-label="Guest onboarding preview screens">
          {stages.map(item => (
            <button key={item.id} type="button" onClick={() => setStage(item.id)}
              aria-current={stage === item.id ? 'step' : undefined}
              className={stage === item.id ? 'is-active' : ''}>
              {item.label}
            </button>
          ))}
        </nav>

        <div className="tlg-helios-preview-stage">
          {stage === 'homepage' && (
            <section className="tlg-helios-preview-panel">
              <p className="tlg-helios-preview-kicker">TENNIS LEGACY · RISE TO GLORY</p>
              <h2>Build your tennis career</h2>
              <p>Review how the guest option will be presented alongside existing login and registration options. This is not the public homepage.</p>
              <div className="tlg-helios-preview-actions">
                <button disabled>Sign In</button>
                <button disabled>Explore the Game</button>
                <button className="is-primary" disabled>Try as Test Player</button>
                <button disabled>Create Account</button>
              </div>
              <small>Public homepage does not display the guest button while the server switch is OFF.</small>
            </section>
          )}
          {stage === 'guest' && <TryAsGuestPage previewOnly />}
          {stage === 'player' && (
            <section className="tlg-helios-preview-panel">
              <p className="tlg-helios-preview-kicker">TEST PLAYER · PROFILE SETUP</p>
              <h2>Create your tennis player</h2>
              <p>A guest will choose a player name, country and appearance. No city, email or birthday is required to begin.</p>
              <div className="tlg-helios-preview-fields">
                <label>First name<input disabled placeholder="First name" /></label>
                <label>Last name<input disabled placeholder="Last name" /></label>
                <label>Country<select disabled defaultValue=""><option value="">Choose a country</option></select></label>
                <label>Appearance<select disabled defaultValue=""><option value="">Choose an appearance</option></select></label>
              </div>
              <button className="is-primary" disabled>Create Test Player (Preview Only)</button>
              <small>Visual review only. The actual Create Player wizard must be verified with an enrolled guest in staging before launch.</small>
            </section>
          )}
          {stage === 'registration' && (
            <section className="tlg-helios-preview-panel">
              <p className="tlg-helios-preview-kicker">GUEST ACCOUNT · SAVE PROGRESS</p>
              <h2>Register and keep your tennis player</h2>
              <p>Your 14-day test includes seven days of Premium. Register before expiry to keep your player, rankings, equipment, staff and finances.</p>
              <div className="tlg-helios-preview-balance"><ShieldCheck size={18}/> Existing player and game progress stay on the same account.</div>
              <div className="tlg-helios-preview-fields">
                <label>Email address<input disabled type="email" placeholder="you@example.com" /></label>
              </div>
              <button className="is-primary" disabled>Verify Email &amp; Save My Progress</button>
              <small>Preview only: no email is sent and no identity is linked. Actual conversion still needs email/Google E2E tests.</small>
            </section>
          )}
        </div>
      </div>
    </GameLayout>
  )
}
