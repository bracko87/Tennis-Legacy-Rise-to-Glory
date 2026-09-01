import { Link2, Share2, UsersRound } from 'lucide-react'

import GameLayout from '../../components/layout/GameLayout'
import '../../styles/invite-friends.css'

const overviewItems = [
  ['Total referrals', '0'],
  ['Pending', '0'],
  ['Active players', '0'],
  ['Rewarded referrals', '0'],
  ['Referral Coins', '0'],
] as const

export default function InviteFriendsPage() {
  return (
    <GameLayout title="Invite Friends" subtitle="Invite other players to Tennis Legacy">
      <div className="tlg-invite-page">
        <section className="tlg-invite-intro">
          <div>
            <span>REFERRALS</span>
            <h2>Invite Friends</h2>
            <p>
              The Tennis Legacy referral program is being prepared. This page shows how your personal invite link,
              referral activity and future rewards will be presented once the system is activated.
            </p>
          </div>
          <span className="tlg-invite-status">Coming later</span>
        </section>

        <section className="tlg-invite-panel">
          <header>
            <div>
              <h3>Your invite link</h3>
              <p>Your unique referral link will appear here when the referral system goes live.</p>
            </div>
          </header>

          <div className="tlg-invite-link-row">
            <div className="tlg-invite-link-placeholder" aria-label="Referral link not yet available">
              <Link2 size={17} />
              <span>Personal referral link will be generated here</span>
            </div>
            <button type="button" disabled>Copy</button>
            <button type="button" className="tlg-invite-secondary-button" disabled><Share2 size={15} /> Share</button>
          </div>
          <small className="tlg-invite-note">Referral links and sharing are not active yet.</small>
        </section>

        <section className="tlg-invite-panel">
          <header>
            <div>
              <h3>Referral overview</h3>
              <p>Your referral statistics will be tracked here after the system is enabled.</p>
            </div>
          </header>

          <div className="tlg-invite-overview-grid">
            {overviewItems.map(([label, value]) => (
              <article key={label}>
                <span>{label}</span>
                <strong>{value}</strong>
              </article>
            ))}
          </div>
        </section>

        <section className="tlg-invite-panel">
          <header>
            <div>
              <h3>Referral activity</h3>
              <p>Invited players, activation status and future rewards will appear in this section.</p>
            </div>
          </header>

          <div className="tlg-invite-empty">
            <UsersRound size={30} />
            <strong>No referral activity yet</strong>
            <p>The referral system has not been activated. Nothing is being tracked on this page yet.</p>
          </div>
        </section>

        <section className="tlg-invite-panel tlg-invite-how-it-works">
          <header>
            <div>
              <h3>How it will work</h3>
              <p>The final reward rules will be confirmed when the referral backend is introduced.</p>
            </div>
          </header>

          <ol>
            <li>Each player will receive a personal Tennis Legacy invite link.</li>
            <li>A friend will use that link to register and create their own ATP or WTA player career.</li>
            <li>The referral will remain pending until the invited account meets the required activity conditions.</li>
            <li>Eligible rewards, if applicable, will be credited automatically after those conditions are met.</li>
          </ol>

          <div className="tlg-invite-info-box">
            <strong>Referral rewards are not active yet.</strong>
            <p>We will publish the exact eligibility rules, activity requirements and Coin rewards before this feature goes live.</p>
          </div>
        </section>
      </div>
    </GameLayout>
  )
}
