import { useNavigate } from 'react-router'
import { ShieldAlert } from 'lucide-react'
import { useAuth } from '../../auth/AuthContext'
import { useGuestTrialDisplay } from '../../hooks/useGuestTrialDisplay'

/** Presentation only. Database RPC guards enforce expiry independently. */
export default function GuestExpiryNotice() {
  const { user } = useAuth()
  const trial = useGuestTrialDisplay()
  const navigate = useNavigate()
  if (!user?.is_anonymous || (trial.state !== 'expired' && trial.state !== 'retired' && trial.state !== 'not_enrolled')) return null

  return (
    <div className="tlg-guest-expiry-backdrop">
      <section className="tlg-guest-expiry-modal" role="alertdialog"
        aria-modal="true" aria-labelledby="tlg-guest-expiry-heading"
        aria-describedby="tlg-guest-expiry-description">
        <ShieldAlert size={30} aria-hidden="true"/>
        <h2 id="tlg-guest-expiry-heading">
          {trial.state === 'retired' ? 'Your test player has been retired' : trial.state === 'expired' ? 'Your 14-day test period has ended' : 'Test session unavailable'}
        </h2>
        <p id="tlg-guest-expiry-description">
          {trial.state === 'retired'
            ? 'Your test period ended without permanent registration. Your player has been withdrawn from future competitions; opponents receive walkover wins for unstarted scheduled matches. You can create a new permanent account.'
            : trial.state === 'expired'
              ? 'Your test period has ended. If automatic retirement has not yet been completed, you can still register to save your player.'
              : 'This test session is unavailable. Open the account page to check your options.'}
        </p>
        <button type="button" onClick={() => navigate('/guest/register')}>
          {trial.state === 'retired' ? 'View Account Options' : 'Register & Continue'}
        </button>
        <small>Register before your 14-day deadline to preserve the player. Completed tournament history remains unchanged.</small>
      </section>
    </div>
  )
}
