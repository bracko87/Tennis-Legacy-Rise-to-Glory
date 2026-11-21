import { useEffect, useState } from 'react'
import { Link } from 'react-router'
import { Eye, LockKeyhole, RefreshCw, ShieldCheck } from 'lucide-react'
import GameLayout from '../../components/layout/GameLayout'
import TryAsGuestPage from '../auth/TryAsGuest'
import { supabase } from '../../lib/supabase'
import '../../styles/helios-guest-preview.css'

type Stage = 'homepage' | 'guest' | 'player' | 'registration'

const stages: Array<{ id: Stage; label: string }> = [
  { id: 'homepage', label: 'Homepage entry' },
  { id: 'guest', label: 'Guest Player entry' },
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
  const [guestGate, setGuestGate] = useState<'checking' | 'disabled' | 'enabled' | 'error'>('checking')
  const [lastChecked, setLastChecked] = useState<string | null>(null)

  async function checkGuestGate() {
    setGuestGate('checking')
    try {
      const { data, error } = await supabase.rpc('get_public_tennis_guest_test_status_v1')
      if (error) setGuestGate('error')
      else setGuestGate(data === true ? 'enabled' : 'disabled')
    } catch {
      setGuestGate('error')
    } finally {
      setLastChecked(new Date().toLocaleTimeString())
    }
  }

  useEffect(() => {
    void checkGuestGate()
  }, [])
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
        <section className="tlg-helios-preview-readiness" aria-label="Functional testing readiness">
          <div className="tlg-helios-preview-readiness-header">
            <div>
              <strong>Functional test readiness</strong>
              <p>This checks the real server feature gate only; it never creates an account or starts a trial.</p>
            </div>
            <button type="button" onClick={() => void checkGuestGate()} disabled={guestGate === 'checking'}>
              <RefreshCw size={15} /> Refresh server status
            </button>
          </div>
          <dl className="tlg-helios-preview-readiness-grid">
            <div><dt>Public guest enrollment</dt><dd>{guestGate === 'checking' ? 'Checking…' : guestGate === 'enabled' ? 'Enabled — review release gate urgently' : guestGate === 'disabled' ? 'Disabled (safe)' : 'Status unavailable — fail closed'}</dd></div>
            <div><dt>Anonymous Auth provider</dt><dd>Not verified — staging setup required</dd></div>
            <div><dt>Full guest lifecycle E2E</dt><dd>Not yet verified in isolated staging</dd></div>
            <div><dt>Permanent guest erasure</dt><dd>Not implemented — blocked</dd></div>
          </dl>
          {lastChecked && <small>Last server status check: {lastChecked}. The other items are outstanding milestones, not live checks.</small>}
        </section>
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
                <button className="is-primary" disabled>Try as Guest</button>
                <button disabled>Create Account</button>
              </div>
              <small>Public homepage does not display the guest button while the server switch is OFF.</small>
            </section>
          )}
          {stage === 'guest' && <TryAsGuestPage previewOnly />}
          {stage === 'player' && (
            <section className="tlg-helios-preview-panel">
              <p className="tlg-helios-preview-kicker">GUEST PLAYER · PROFILE SETUP</p>
              <h2>Create your tennis player</h2>
              <p>A guest will choose a player name, country and appearance. No city, email or birthday is required to begin.</p>
              <div className="tlg-helios-preview-fields">
                <label>First name<input disabled placeholder="First name" /></label>
                <label>Last name<input disabled placeholder="Last name" /></label>
                <label>Country<select disabled defaultValue=""><option value="">Choose a country</option></select></label>
                <label>Appearance<select disabled defaultValue=""><option value="">Choose an appearance</option></select></label>
              </div>
              <button className="is-primary" disabled>Create Guest Player (Preview Only)</button>
              <small>Visual review only. The actual Create Player wizard must be verified with an enrolled guest in staging before launch.</small>
            </section>
          )}
          {stage === 'registration' && (
            <section className="tlg-helios-preview-panel">
              <p className="tlg-helios-preview-kicker">GUEST ACCOUNT · SAVE PROGRESS</p>
              <h2>Register and keep your tennis player</h2>
              <p>Your 14-day guest trial includes seven days of Premium. Register before expiry to keep your player, rankings, equipment, staff and finances.</p>
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
