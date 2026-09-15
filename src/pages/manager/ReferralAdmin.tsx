import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router'
import { ArrowLeft, CheckCircle2, Coins, Flag, RefreshCw, ShieldCheck, Trophy, UsersRound, XCircle } from 'lucide-react'

import GameConfirmDialog from '../../components/common/GameConfirmDialog'
import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/referral-admin.css'

type ReferralStatus = 'registered' | 'pending_activation' | 'active' | 'rewarded' | 'rejected' | 'invalid'
type ContestStatus = 'draft' | 'active' | 'validation' | 'finalized' | 'canceled'

interface ReferralSettings {
  base_reward_coins: number
  coin_purchase_reward_coins: number
  premium_purchase_reward_coins: number
  max_rewardable_referrals: number
  minimum_account_age_hours: number
  minimum_active_days: number
}

interface AdminReferral {
  id: string
  referrer_username: string
  referred_username: string
  status: ReferralStatus
  registered_at: string
  activated_at?: string | null
  review_reason?: string | null
  browser_hash_present?: boolean
  reward_slot?: number | null
  reward_coins?: number
  review_required?: boolean
  admin_approved?: boolean
}

interface ContestPrize {
  rank_from: number
  rank_to: number
  title: string
  coins: number
  premium_days: number
  badge_code: string | null
}

interface ContestLeaderboardRow {
  rank: number
  username: string
  valid_referrals: number
  reached_count_at: string
}

interface ReferralContest {
  id: string
  name: string
  description: string
  starts_at: string
  ends_at: string
  validation_deadline: string
  status: ContestStatus
  max_counted_referrals: number
  finalized_at: string | null
  prizes: ContestPrize[]
  leaderboard: ContestLeaderboardRow[]
}

interface AdminDashboard {
  settings: ReferralSettings
  summary: {
    total_referrals: number
    review_required: number
    active: number
    rejected: number
    coins_paid: number
  }
  review_queue: AdminReferral[]
  recent_referrals: AdminReferral[]
  contests: ReferralContest[]
}

interface ConfirmState {
  title: string
  message: string
  detail?: string
  label: string
  tone: 'danger' | 'warning' | 'success' | 'neutral'
  run: () => Promise<void>
}

const BADGES = ['', 'referral_champion', 'referral_ambassador', 'community_builder']

function formatDate(value?: string | null) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return new Intl.DateTimeFormat('en', { dateStyle: 'medium', timeStyle: 'short' }).format(date)
}

function isoFromLocal(value: string) {
  if (!value) return ''
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '' : date.toISOString()
}

export default function ReferralAdminPage() {
  const [dashboard, setDashboard] = useState<AdminDashboard | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [confirm, setConfirm] = useState<ConfirmState | null>(null)

  const [settings, setSettings] = useState<ReferralSettings>({
    base_reward_coins: 3,
    coin_purchase_reward_coins: 15,
    premium_purchase_reward_coins: 30,
    max_rewardable_referrals: 10,
    minimum_account_age_hours: 72,
    minimum_active_days: 2,
  })

  const [contestName, setContestName] = useState('')
  const [contestDescription, setContestDescription] = useState('')
  const [contestStart, setContestStart] = useState('')
  const [contestEnd, setContestEnd] = useState('')
  const [contestValidation, setContestValidation] = useState('')
  const [contestMax, setContestMax] = useState(100)
  const [firstCoins, setFirstCoins] = useState(100)
  const [firstPremium, setFirstPremium] = useState(0)
  const [firstBadge, setFirstBadge] = useState('referral_champion')
  const [topThreeCoins, setTopThreeCoins] = useState(50)
  const [topThreePremium, setTopThreePremium] = useState(0)
  const [topThreeBadge, setTopThreeBadge] = useState('')

  const [adjustReferralId, setAdjustReferralId] = useState('')
  const [adjustCoins, setAdjustCoins] = useState(0)
  const [adjustReason, setAdjustReason] = useState('')

  async function loadDashboard() {
    setLoading(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('get_referral_admin_dashboard_v1')
    if (rpcError || !data) {
      setDashboard(null)
      setError(rpcError?.message || 'Referral admin information could not be loaded.')
      setLoading(false)
      return
    }
    const next = data as AdminDashboard
    setDashboard(next)
    setSettings(next.settings)
    if (!adjustReferralId && next.recent_referrals[0]) setAdjustReferralId(next.recent_referrals[0].id)
    setLoading(false)
  }

  useEffect(() => { void loadDashboard() }, [])

  async function runRpc(name: string, args: Record<string, unknown>, successMessage: string) {
    setBusy(true)
    setError(null)
    setNotice(null)
    const { error: rpcError } = await supabase.rpc(name, args)
    setBusy(false)
    if (rpcError) {
      setError(rpcError.message)
      return false
    }
    setNotice(successMessage)
    await loadDashboard()
    return true
  }

  async function saveSettings() {
    await runRpc('admin_update_referral_settings_v1', {
      p_base_reward_coins: Number(settings.base_reward_coins),
      p_coin_purchase_reward_coins: Number(settings.coin_purchase_reward_coins),
      p_premium_purchase_reward_coins: Number(settings.premium_purchase_reward_coins),
      p_max_rewardable_referrals: Number(settings.max_rewardable_referrals),
      p_minimum_account_age_hours: Number(settings.minimum_account_age_hours),
      p_minimum_active_days: Number(settings.minimum_active_days),
    }, 'Referral settings updated.')
  }

  function queueReviewAction(referral: AdminReferral, action: 'approve' | 'reject' | 'recheck') {
    const rejecting = action === 'reject'
    setConfirm({
      title: rejecting ? 'Reject this referral?' : action === 'approve' ? 'Approve this referral?' : 'Recheck this referral?',
      message: `${referral.referrer_username} → ${referral.referred_username}`,
      detail: rejecting
        ? 'The referral becomes ineligible unless an admin later approves it again. Existing Coin corrections remain auditable.'
        : action === 'approve'
          ? 'Admin approval clears the fraud hold and lets the secure activation engine re-evaluate this account.'
          : 'The automated anti-abuse checks will run again without an admin override.',
      label: rejecting ? 'Reject referral' : action === 'approve' ? 'Approve referral' : 'Run recheck',
      tone: rejecting ? 'danger' : action === 'approve' ? 'success' : 'warning',
      run: async () => {
        await runRpc('admin_review_referral_v1', {
          p_referral_id: referral.id,
          p_action: action,
          p_reason: rejecting ? (referral.review_reason || 'Rejected after admin review') : null,
        }, `Referral ${action} completed.`)
      },
    })
  }

  async function createContest() {
    const startsAt = isoFromLocal(contestStart)
    const endsAt = isoFromLocal(contestEnd)
    const validationAt = isoFromLocal(contestValidation)
    if (!contestName.trim() || !startsAt || !endsAt || !validationAt) {
      setError('Contest name, start, end and validation deadline are required.')
      return
    }
    const prizes = [
      {
        rank_from: 1,
        rank_to: 1,
        title: '1st place',
        coins: Number(firstCoins),
        premium_days: Number(firstPremium),
        badge_code: firstBadge || null,
      },
      {
        rank_from: 2,
        rank_to: 3,
        title: '2nd–3rd place',
        coins: Number(topThreeCoins),
        premium_days: Number(topThreePremium),
        badge_code: topThreeBadge || null,
      },
    ].filter((prize) => prize.coins > 0 || prize.premium_days > 0 || prize.badge_code)

    if (!prizes.length) {
      setError('Add at least one contest prize.')
      return
    }

    const ok = await runRpc('admin_create_referral_contest_v1', {
      p_name: contestName.trim(),
      p_description: contestDescription.trim(),
      p_starts_at: startsAt,
      p_ends_at: endsAt,
      p_validation_deadline: validationAt,
      p_max_counted_referrals: Number(contestMax),
      p_prizes: prizes,
    }, 'Contest created as a draft.')
    if (ok) {
      setContestName('')
      setContestDescription('')
    }
  }

  function queueContestStatus(contest: ReferralContest, status: Exclude<ContestStatus, 'finalized'>) {
    setConfirm({
      title: status === 'canceled' ? 'Cancel referral contest?' : `Set contest to ${status}?`,
      message: contest.name,
      detail: status === 'active'
        ? 'Players will see this contest on the Invite Friends page and valid referrals will count according to its dates.'
        : status === 'validation'
          ? 'The contest is closed to new registrations while final referral validation can continue until the validation deadline.'
          : status === 'canceled'
            ? 'Canceled contests cannot be finalized or pay prizes.'
            : 'The contest returns to draft and is hidden from players.',
      label: status === 'canceled' ? 'Cancel contest' : `Set ${status}`,
      tone: status === 'canceled' ? 'danger' : 'warning',
      run: async () => {
        await runRpc('admin_set_referral_contest_status_v1', { p_contest_id: contest.id, p_status: status }, `Contest status changed to ${status}.`)
      },
    })
  }

  function queueFinalize(contest: ReferralContest) {
    setConfirm({
      title: 'Finalize contest and pay prizes?',
      message: contest.name,
      detail: 'Final ranking is locked. Coin prizes, Premium days and referral badges are granted exactly once. This action is idempotent but the contest cannot be reopened afterward.',
      label: 'Finalize & pay prizes',
      tone: 'warning',
      run: async () => {
        await runRpc('admin_finalize_referral_contest_v1', { p_contest_id: contest.id }, 'Contest finalized and eligible prizes processed.')
      },
    })
  }

  function queueAdjustment() {
    const referral = dashboard?.recent_referrals.find((item) => item.id === adjustReferralId)
    if (!referral || !adjustCoins || !adjustReason.trim()) {
      setError('Choose a referral, enter a non-zero Coin adjustment and provide a reason.')
      return
    }
    setConfirm({
      title: adjustCoins < 0 ? 'Remove referral Coins?' : 'Add referral Coins?',
      message: `${referral.referrer_username} · ${adjustCoins > 0 ? '+' : ''}${adjustCoins} Coins`,
      detail: adjustReason.trim(),
      label: 'Apply correction',
      tone: adjustCoins < 0 ? 'danger' : 'warning',
      run: async () => {
        const ok = await runRpc('admin_adjust_referral_reward_v1', {
          p_referral_id: referral.id,
          p_coin_delta: Number(adjustCoins),
          p_reason: adjustReason.trim(),
        }, 'Referral Coin correction recorded in the ledger.')
        if (ok) {
          setAdjustCoins(0)
          setAdjustReason('')
        }
      },
    })
  }

  const summary = dashboard?.summary
  const recentOptions = useMemo(() => dashboard?.recent_referrals ?? [], [dashboard?.recent_referrals])

  if (!loading && !dashboard) {
    return (
      <GameLayout title="Referral Administration" subtitle="Restricted referral controls">
        <div className="tlg-ref-admin-denied">
          <ShieldCheck size={34} />
          <h2>Referral admin access required</h2>
          <p>{error || 'This page is restricted.'}</p>
          <Link to="/game/invite-friends"><ArrowLeft size={15} /> Back to Invite Friends</Link>
        </div>
      </GameLayout>
    )
  }

  return (
    <GameLayout title="Referral Administration" subtitle="Review referrals, rewards and referral competitions">
      <div className="tlg-ref-admin-page">
        <div className="tlg-ref-admin-topline">
          <Link to="/game/invite-friends"><ArrowLeft size={15} /> Invite Friends</Link>
          <button type="button" onClick={() => void loadDashboard()} disabled={loading || busy}><RefreshCw size={15} /> Refresh</button>
        </div>

        {error && <div className="tlg-ref-admin-message error">{error}</div>}
        {notice && <div className="tlg-ref-admin-message success">{notice}</div>}

        <section className="tlg-ref-admin-summary">
          <article><span>Total referrals</span><strong>{summary?.total_referrals ?? '—'}</strong></article>
          <article><span>Needs review</span><strong>{summary?.review_required ?? '—'}</strong></article>
          <article><span>Active</span><strong>{summary?.active ?? '—'}</strong></article>
          <article><span>Rejected / invalid</span><strong>{summary?.rejected ?? '—'}</strong></article>
          <article><span>Referral Coins paid</span><strong>{summary?.coins_paid ?? '—'}</strong></article>
        </section>

        <section className="tlg-ref-admin-panel">
          <header><div><span>PROGRAM RULES</span><h2>Standard referral rewards</h2><p>These values control the live referral processor.</p></div></header>
          <div className="tlg-ref-admin-form-grid six">
            <label>Valid referral Coins<input type="number" min={0} value={settings.base_reward_coins} onChange={(e) => setSettings({ ...settings, base_reward_coins: Number(e.target.value) })} /></label>
            <label>Coin purchase bonus<input type="number" min={0} value={settings.coin_purchase_reward_coins} onChange={(e) => setSettings({ ...settings, coin_purchase_reward_coins: Number(e.target.value) })} /></label>
            <label>Premium purchase bonus<input type="number" min={0} value={settings.premium_purchase_reward_coins} onChange={(e) => setSettings({ ...settings, premium_purchase_reward_coins: Number(e.target.value) })} /></label>
            <label>Rewardable referrals<input type="number" min={1} max={100} value={settings.max_rewardable_referrals} onChange={(e) => setSettings({ ...settings, max_rewardable_referrals: Number(e.target.value) })} /></label>
            <label>Minimum age · hours<input type="number" min={0} value={settings.minimum_account_age_hours} onChange={(e) => setSettings({ ...settings, minimum_account_age_hours: Number(e.target.value) })} /></label>
            <label>Active real days<input type="number" min={1} value={settings.minimum_active_days} onChange={(e) => setSettings({ ...settings, minimum_active_days: Number(e.target.value) })} /></label>
          </div>
          <button className="tlg-ref-admin-primary" type="button" disabled={busy} onClick={() => void saveSettings()}>Save referral rules</button>
        </section>

        <section className="tlg-ref-admin-panel">
          <header><div><span>ANTI-ABUSE REVIEW</span><h2>Flagged referrals</h2><p>Approve genuine referrals, reject invalid ones, or rerun the automatic checks.</p></div></header>
          {!dashboard?.review_queue.length ? (
            <div className="tlg-ref-admin-empty"><CheckCircle2 size={26} /><strong>No referrals currently need review.</strong></div>
          ) : (
            <div className="tlg-ref-admin-list">
              {dashboard.review_queue.map((referral) => (
                <article key={referral.id}>
                  <div><strong>{referral.referrer_username} → {referral.referred_username}</strong><span>{formatDate(referral.registered_at)} · {referral.status}</span><p>{referral.review_reason || 'Automated anti-abuse review requested.'}</p></div>
                  <div className="tlg-ref-admin-actions">
                    <button type="button" className="approve" onClick={() => queueReviewAction(referral, 'approve')}><CheckCircle2 size={14} /> Approve</button>
                    <button type="button" onClick={() => queueReviewAction(referral, 'recheck')}><RefreshCw size={14} /> Recheck</button>
                    <button type="button" className="danger" onClick={() => queueReviewAction(referral, 'reject')}><XCircle size={14} /> Reject</button>
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>

        <section className="tlg-ref-admin-panel">
          <header><div><span>LEDGER CORRECTION</span><h2>Correct a referral reward</h2><p>Corrections create a compensating Coin-ledger entry; original rewards are never erased.</p></div></header>
          <div className="tlg-ref-admin-form-grid three">
            <label>Referral<select value={adjustReferralId} onChange={(e) => setAdjustReferralId(e.target.value)}><option value="">Choose referral</option>{recentOptions.map((referral) => <option key={referral.id} value={referral.id}>{referral.referrer_username} → {referral.referred_username}</option>)}</select></label>
            <label>Coin adjustment<input type="number" value={adjustCoins} onChange={(e) => setAdjustCoins(Number(e.target.value))} placeholder="e.g. -15 or 15" /></label>
            <label>Reason<input value={adjustReason} onChange={(e) => setAdjustReason(e.target.value)} placeholder="Required audit reason" /></label>
          </div>
          <button className="tlg-ref-admin-secondary" type="button" disabled={busy} onClick={queueAdjustment}>Apply ledger correction</button>
        </section>

        <section className="tlg-ref-admin-panel">
          <header><div><span>REFERRAL CONTESTS</span><h2>Create a competition</h2><p>Ranking rule: most valid referrals registered during the contest. Ties go to the manager who reached the final count first.</p></div></header>
          <div className="tlg-ref-admin-form-grid two">
            <label>Contest name<input value={contestName} onChange={(e) => setContestName(e.target.value)} placeholder="Launch Referral Cup" /></label>
            <label>Maximum counted referrals<input type="number" min={1} max={10000} value={contestMax} onChange={(e) => setContestMax(Number(e.target.value))} /></label>
          </div>
          <label className="tlg-ref-admin-wide-label">Description<textarea value={contestDescription} onChange={(e) => setContestDescription(e.target.value)} rows={3} placeholder="Explain the campaign and eligibility." /></label>
          <div className="tlg-ref-admin-form-grid three">
            <label>Starts<input type="datetime-local" value={contestStart} onChange={(e) => setContestStart(e.target.value)} /></label>
            <label>Ends<input type="datetime-local" value={contestEnd} onChange={(e) => setContestEnd(e.target.value)} /></label>
            <label>Validation deadline<input type="datetime-local" value={contestValidation} onChange={(e) => setContestValidation(e.target.value)} /></label>
          </div>

          <div className="tlg-ref-admin-prize-grid">
            <article><h3><Trophy size={16} /> 1st place</h3><label>Coins<input type="number" min={0} value={firstCoins} onChange={(e) => setFirstCoins(Number(e.target.value))} /></label><label>Premium days<input type="number" min={0} value={firstPremium} onChange={(e) => setFirstPremium(Number(e.target.value))} /></label><label>Badge<select value={firstBadge} onChange={(e) => setFirstBadge(e.target.value)}>{BADGES.map((badge) => <option key={badge || 'none'} value={badge}>{badge || 'No badge'}</option>)}</select></label></article>
            <article><h3><Flag size={16} /> 2nd–3rd place</h3><label>Coins<input type="number" min={0} value={topThreeCoins} onChange={(e) => setTopThreeCoins(Number(e.target.value))} /></label><label>Premium days<input type="number" min={0} value={topThreePremium} onChange={(e) => setTopThreePremium(Number(e.target.value))} /></label><label>Badge<select value={topThreeBadge} onChange={(e) => setTopThreeBadge(e.target.value)}>{BADGES.map((badge) => <option key={badge || 'none'} value={badge}>{badge || 'No badge'}</option>)}</select></label></article>
          </div>
          <button className="tlg-ref-admin-primary" type="button" disabled={busy} onClick={() => void createContest()}>Create draft contest</button>
        </section>

        <section className="tlg-ref-admin-panel">
          <header><div><span>CONTEST CONTROL</span><h2>Referral competitions</h2><p>Review live rankings, move contests through validation, and finalize prize payment only after the validation deadline.</p></div></header>
          {!dashboard?.contests.length ? <div className="tlg-ref-admin-empty"><Trophy size={26} /><strong>No referral contests created yet.</strong></div> : (
            <div className="tlg-ref-admin-contests">
              {dashboard.contests.map((contest) => (
                <article key={contest.id}>
                  <div className="tlg-ref-admin-contest-head"><div><span>{contest.status.toUpperCase()}</span><h3>{contest.name}</h3><p>{contest.description || 'No description.'}</p></div><div><strong>{formatDate(contest.starts_at)}</strong><span>to {formatDate(contest.ends_at)}</span><small>Validation until {formatDate(contest.validation_deadline)}</small></div></div>
                  <div className="tlg-ref-admin-prizes">{contest.prizes.map((prize, index) => <span key={`${contest.id}-${index}`}>#{prize.rank_from}{prize.rank_to !== prize.rank_from ? `–${prize.rank_to}` : ''}: {prize.coins ? `${prize.coins} Coins` : ''}{prize.premium_days ? `${prize.coins ? ' + ' : ''}${prize.premium_days} Premium days` : ''}{prize.badge_code ? `${prize.coins || prize.premium_days ? ' + ' : ''}${prize.badge_code}` : ''}</span>)}</div>
                  <div className="tlg-ref-admin-leaderboard">
                    <strong>Current ranking</strong>
                    {!contest.leaderboard.length ? <span>No valid referrals yet.</span> : contest.leaderboard.slice(0, 10).map((row) => <div key={`${contest.id}-${row.rank}`}><b>#{row.rank}</b><span>{row.username}</span><strong>{row.valid_referrals}</strong></div>)}
                  </div>
                  {contest.status !== 'finalized' && (
                    <div className="tlg-ref-admin-actions contest-actions">
                      <button type="button" onClick={() => queueContestStatus(contest, 'draft')}>Draft</button>
                      <button type="button" className="approve" onClick={() => queueContestStatus(contest, 'active')}>Activate</button>
                      <button type="button" onClick={() => queueContestStatus(contest, 'validation')}>Validation</button>
                      <button type="button" className="danger" onClick={() => queueContestStatus(contest, 'canceled')}>Cancel</button>
                      <button type="button" className="finalize" onClick={() => queueFinalize(contest)}><Coins size={14} /> Finalize & pay</button>
                    </div>
                  )}
                </article>
              ))}
            </div>
          )}
        </section>

        <section className="tlg-ref-admin-panel">
          <header><div><span>RECENT ACTIVITY</span><h2>Recent referral records</h2><p>Latest 90-day referral activity, including status and reward totals.</p></div></header>
          <div className="tlg-ref-admin-table-wrap"><table><thead><tr><th>Registered</th><th>Referrer</th><th>Referred player</th><th>Status</th><th>Slot</th><th>Coins</th></tr></thead><tbody>{dashboard?.recent_referrals.map((referral) => <tr key={referral.id}><td>{formatDate(referral.registered_at)}</td><td>{referral.referrer_username}</td><td>{referral.referred_username}</td><td>{referral.review_required ? 'Review' : referral.status}</td><td>{referral.reward_slot ?? '—'}</td><td>{referral.reward_coins ?? 0}</td></tr>)}</tbody></table></div>
        </section>
      </div>

      <GameConfirmDialog
        open={Boolean(confirm)}
        eyebrow="Referral administration"
        title={confirm?.title ?? ''}
        message={confirm?.message ?? ''}
        detail={confirm?.detail}
        confirmLabel={confirm?.label ?? 'Confirm'}
        busy={busy}
        tone={confirm?.tone ?? 'warning'}
        onCancel={() => { if (!busy) setConfirm(null) }}
        onConfirm={async () => {
          if (!confirm) return
          await confirm.run()
          setConfirm(null)
        }}
      />
    </GameLayout>
  )
}
