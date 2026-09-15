import { CheckCircle2, Coins, Copy, Link2, Share2, UsersRound } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'

import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/invite-friends.css'

interface ReferralActivityItem {
  id: string
  registered_at: string
  status: 'registered' | 'pending_activation' | 'active' | 'rewarded' | 'rejected' | 'invalid'
  review_required: boolean
  reward_slot: number | null
  reward_coins: number
  base_rewarded: boolean | null
  coin_purchase_rewarded: boolean | null
  premium_purchase_rewarded: boolean | null
}

interface ReferralDashboard {
  code: string
  stats: {
    total: number
    pending: number
    active: number
    rewarded: number
    coins: number
  }
  rules: {
    base_reward_coins: number
    coin_purchase_reward_coins: number
    premium_purchase_reward_coins: number
    max_rewardable_referrals: number
    minimum_account_age_hours: number
    minimum_active_days: number
  }
  activity: ReferralActivityItem[]
}

function formatDate(value: string) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return new Intl.DateTimeFormat('en', { month: 'short', day: 'numeric', year: 'numeric' }).format(date)
}

function statusLabel(item: ReferralActivityItem) {
  if (item.review_required) return 'Under review'
  if (item.status === 'registered') return 'Registered'
  if (item.status === 'pending_activation') return 'Pending activation'
  if (item.status === 'active') return item.reward_slot ? 'Active referral' : 'Active · reward cap reached'
  if (item.status === 'rewarded') return 'Rewarded referral'
  if (item.status === 'rejected') return 'Rejected'
  return 'Invalid'
}

export default function InviteFriendsPage() {
  const [dashboard, setDashboard] = useState<ReferralDashboard | null>(null)
  const [loading, setLoading] = useState(true)
  const [copied, setCopied] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let active = true

    async function loadReferralDashboard() {
      setLoading(true)
      setError(null)
      const { data, error: rpcError } = await supabase.rpc('get_referral_dashboard_v1')
      if (!active) return
      if (rpcError || !data) {
        setError('Referral information could not be loaded right now.')
        setLoading(false)
        return
      }
      setDashboard(data as ReferralDashboard)
      setLoading(false)
    }

    void loadReferralDashboard()
    return () => { active = false }
  }, [])

  const inviteLink = useMemo(() => {
    if (!dashboard?.code) return ''
    return `${window.location.origin}/r/${dashboard.code}`
  }, [dashboard?.code])

  async function copyInviteLink() {
    if (!inviteLink) return
    await navigator.clipboard.writeText(inviteLink)
    setCopied(true)
    window.setTimeout(() => setCopied(false), 1800)
  }

  async function shareInviteLink() {
    if (!inviteLink) return
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'Tennis Legacy: Rise to Glory',
          text: 'Join me in Tennis Legacy: Rise to Glory.',
          url: inviteLink,
        })
        return
      } catch {
        // Fall back to copying if the native share sheet is dismissed or unavailable.
      }
    }
    await copyInviteLink()
  }

  const stats = dashboard?.stats
  const rules = dashboard?.rules
  const overviewItems = [
    ['Total referrals', stats?.total ?? 0],
    ['Pending', stats?.pending ?? 0],
    ['Active players', stats?.active ?? 0],
    ['Rewarded referrals', stats?.rewarded ?? 0],
    ['Referral Coins', stats?.coins ?? 0],
  ] as const

  return (
    <GameLayout title="Invite Friends" subtitle="Invite other players to Tennis Legacy">
      <div className="tlg-invite-page">
        <section className="tlg-invite-intro">
          <div>
            <span>REFERRALS</span>
            <h2>Invite Friends</h2>
            <p>
              Share your personal Tennis Legacy invite. Genuine new players can earn you one-time Coin rewards after they verify their account, create a career and complete the activation requirements.
            </p>
          </div>
          <span className="tlg-invite-status tlg-invite-status-live">Referral tracking live</span>
        </section>

        <section className="tlg-invite-panel">
          <header>
            <div>
              <h3>Your invite link</h3>
              <p>This link belongs only to your manager account. One new account can belong to only one referrer.</p>
            </div>
          </header>

          <div className="tlg-invite-link-row">
            <div className="tlg-invite-link-placeholder tlg-invite-link-live" aria-label="Your referral link">
              <Link2 size={17} />
              <span>{loading ? 'Loading your personal invite link…' : inviteLink || 'Invite link unavailable'}</span>
            </div>
            <button type="button" disabled={!inviteLink} onClick={() => void copyInviteLink()}>
              <Copy size={15} /> {copied ? 'Copied' : 'Copy'}
            </button>
            <button type="button" className="tlg-invite-secondary-button" disabled={!inviteLink} onClick={() => void shareInviteLink()}>
              <Share2 size={15} /> Share
            </button>
          </div>
          <small className="tlg-invite-note">New public registrations remain closed during the current beta phase, but referral links and attribution are ready for when registration reopens.</small>
        </section>

        <section className="tlg-invite-panel">
          <header>
            <div>
              <h3>Referral overview</h3>
              <p>Your live referral totals and all Coin rewards earned through the program.</p>
            </div>
          </header>

          <div className="tlg-invite-overview-grid">
            {overviewItems.map(([label, value]) => (
              <article key={label}>
                <span>{label}</span>
                <strong>{loading ? '—' : value}</strong>
              </article>
            ))}
          </div>
        </section>

        <section className="tlg-invite-panel">
          <header>
            <div>
              <h3>One-time rewards</h3>
              <p>Only the first {rules?.max_rewardable_referrals ?? 10} valid referrals are reward-eligible. Referrals after that remain visible for statistics but do not generate standard referral gifts.</p>
            </div>
          </header>

          <div className="tlg-invite-reward-grid">
            <article><Coins size={20} /><div><strong>{rules?.base_reward_coins ?? 3} Coins</strong><span>When a referred player becomes a valid active referral.</span></div></article>
            <article><Coins size={20} /><div><strong>+{rules?.coin_purchase_reward_coins ?? 15} Coins</strong><span>Once, if that reward-eligible referral makes their first paid Coin purchase.</span></div></article>
            <article><Coins size={20} /><div><strong>+{rules?.premium_purchase_reward_coins ?? 30} Coins</strong><span>Once, if that reward-eligible referral makes their first paid Premium monthly purchase.</span></div></article>
          </div>

          <div className="tlg-invite-info-box">
            <strong>Maximum standard reward pool: 10 valid referrals.</strong>
            <p>Each of the three gifts can be paid only once per reward-eligible referred account. Purchase rewards are issued only from successful backend billing transactions.</p>
          </div>
        </section>

        <section className="tlg-invite-panel">
          <header>
            <div>
              <h3>Referral activity</h3>
              <p>Privacy-safe status history. Other users' email addresses and private account information are never shown here.</p>
            </div>
          </header>

          {error ? (
            <div className="tlg-invite-empty"><strong>{error}</strong></div>
          ) : !loading && (dashboard?.activity.length ?? 0) > 0 ? (
            <div className="tlg-invite-activity-list">
              {dashboard!.activity.map((item, index) => (
                <article key={item.id}>
                  <div className="tlg-invite-activity-main">
                    <span className="tlg-invite-activity-icon"><UsersRound size={16} /></span>
                    <div>
                      <strong>Invited player #{dashboard!.activity.length - index}</strong>
                      <span>{formatDate(item.registered_at)} · {statusLabel(item)}</span>
                    </div>
                  </div>
                  <div className="tlg-invite-activity-rewards">
                    {item.base_rewarded && <span>+{rules?.base_reward_coins ?? 3} valid referral</span>}
                    {item.coin_purchase_rewarded && <span>+{rules?.coin_purchase_reward_coins ?? 15} Coin purchase</span>}
                    {item.premium_purchase_rewarded && <span>+{rules?.premium_purchase_reward_coins ?? 30} Premium</span>}
                    {!item.reward_coins && <span>No reward paid yet</span>}
                    {item.reward_coins > 0 && <strong>+{item.reward_coins} Coins total</strong>}
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <div className="tlg-invite-empty">
              <UsersRound size={30} />
              <strong>{loading ? 'Loading referral activity…' : 'No referral activity yet'}</strong>
              <p>Your invited accounts will appear here after they register through your personal referral link.</p>
            </div>
          )}
        </section>

        <section className="tlg-invite-panel tlg-invite-how-it-works">
          <header>
            <div>
              <h3>How a referral becomes valid</h3>
              <p>The activation checks happen on the secure backend, never in the browser.</p>
            </div>
          </header>

          <ol>
            <li>The new manager opens your personal referral link before creating their account.</li>
            <li>The new account verifies its email address and creates a human ATP or WTA career.</li>
            <li>The account must be at least {rules?.minimum_account_age_hours ?? 72} real-world hours old and active on at least {rules?.minimum_active_days ?? 2} separate real-world days.</li>
            <li>Self-referrals, repeated browser installations and suspicious duplicates are blocked or held for review.</li>
            <li>Once valid, the backend grants the referral reward exactly once and records it in the Coin ledger.</li>
          </ol>

          <div className="tlg-invite-success-box">
            <CheckCircle2 size={18} />
            <div><strong>Rewards are idempotent.</strong><p>Reloading pages or repeating backend processing cannot pay the same referral gift twice.</p></div>
          </div>
        </section>
      </div>
    </GameLayout>
  )
}
