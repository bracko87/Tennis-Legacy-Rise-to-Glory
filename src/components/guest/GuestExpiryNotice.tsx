import { useNavigate } from 'react-router'
import { ShieldAlert } from 'lucide-react'
import { useAuth } from '../../auth/AuthContext'
import { useGuestTrialDisplay } from '../../hooks/useGuestTrialDisplay'

/** Presentation only. Database RPC guards enforce expiry independently. */
export default function GuestExpiryNotice() {
  const { user } = useAuth()
  const trial = useGuestTrialDisplay()
  const navigate = useNavigate()
  if (!user?.is_anonymous || (trial.state !== 'expired' && trial.state !== 'not_enrolled')) return null

  return (
    <div className="tlg-guest-expiry-backdrop">
      <section className="tlg-guest-expiry-modal" role="alertdialog"
        aria-modal="true" aria-labelledby="tlg-guest-expiry-heading"
        aria-describedby="tlg-guest-expiry-description">
        <ShieldAlert size={30} aria-hidden="true"/>
        <h2 id="tlg-guest-expiry-heading">
          {trial.state === 'expired' ? 'Your 14-day test period has ended' : 'Test session unavailable'}
        </h2>
        <p id="tlg-guest-expiry-description">
          {trial.state === 'expired'
            ? 'Your testing time is complete. Register your account to continue playing with the same tennis player, equipment, rankings, finances and progress.'
            : 'This anonymous session has no active trial. You can still register to protect any saved player progress.'}
        </p>
        <button type="button" onClick={() => navigate('/guest/register')}>
          Register &amp; Continue
        </button>
        <small>Registration is available after your testing period expires. The existing Premium trial does not restart.</small>
      </section>
    </div>
  )
}
