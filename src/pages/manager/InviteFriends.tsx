import { CheckCircle2, Coins, Copy, Link2, Share2, ShieldCheck, Trophy, UsersRound } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { Link } from 'react-router'

import GameLayout from '../../components/layout/GameLayout'
import { useLocalization } from '../../i18n/LocalizationProvider'
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

interface ContestPrize {
  rank_from: number
  rank_to: number
  title: string
  coins: number
  premium_days: number
  badge_code: string | null
}

interface ReferralContest {
  id: string
  name: string
  description: string
  starts_at: string
  ends_at: string
  validation_deadline: string
  status: 'active' | 'validation' | 'finalized'
  your_rank: number | null
  your_valid_referrals: number | null
  prizes: ContestPrize[]
}

interface ReferralDashboard {
  code: string
  is_admin?: boolean
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
  contests?: ReferralContest[]
}

function formatDate(value: string, localeTag: string) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return new Intl.DateTimeFormat(localeTag, { month: 'short', day: 'numeric', year: 'numeric' }).format(date)
}

function statusLabel(item: ReferralActivityItem, t: TFunction) {
  if (item.review_required) return t('referrals.status.underReview')
  if (item.status === 'registered') return t('referrals.status.registered')
  if (item.status === 'pending_activation') return t('referrals.status.pendingActivation')
  if (item.status === 'active') return item.reward_slot ? t('referrals.status.activeReferral') : t('referrals.status.rewardCapReached')
  if (item.status === 'rewarded') return t('referrals.status.rewarded')
  if (item.status === 'rejected') return t('referrals.status.rejected')
  return t('referrals.status.invalid')
}

function contestStatusLabel(status: ReferralContest['status'], t: TFunction) {
  if (status === 'active') return t('referrals.contestStatus.active')
  if (status === 'validation') return t('referrals.contestStatus.validation')
  return t('referrals.contestStatus.finalized')
}

function prizeLabel(prize: ContestPrize, t: TFunction) {
  const parts: string[] = []
  if (prize.coins) parts.push(t('referrals.prizeCoins', { count: prize.coins }))
  if (prize.premium_days) parts.push(t('referrals.premiumDays', { count: prize.premium_days }))
  if (prize.badge_code) parts.push(prize.badge_code.replace(/_/g, ' '))
  return parts.join(' + ')
}

export default function InviteFriendsPage() {
  const { t } = useTranslation()
  const { localeTag } = useLocalization()
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
        setError(t('referrals.loadError'))
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
          text: t('referrals.shareText'),
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
  const contests = dashboard?.contests ?? []
  const overviewItems = [
    [t('referrals.totalReferrals'), stats?.total ?? 0],
    [t('referrals.pending'), stats?.pending ?? 0],
    [t('referrals.activePlayers'), stats?.active ?? 0],
    [t('referrals.rewardedReferrals'), stats?.rewarded ?? 0],
    [t('referrals.referralCoins'), stats?.coins ?? 0],
  ] as const

  return (
    <GameLayout title={t('referrals.title')} subtitle={t('referrals.subtitle')}>
      <div className="tlg-invite-page">
        <section className="tlg-invite-intro">
          <div>
            <span>{t('referrals.eyebrow')}</span>
            <h2>{t('referrals.title')}</h2>
            <p>
              {t('referrals.intro')}
            </p>
          </div>
          <div className="tlg-invite-intro-actions">
            <span className="tlg-invite-status tlg-invite-status-live">{t('referrals.trackingLive')}</span>
            {dashboard?.is_admin && <Link className="tlg-invite-admin-link" to="/game/referral-admin"><ShieldCheck size={15} /> {t('referrals.adminControls')}</Link>}
          </div>
        </section>

        <section className="tlg-invite-panel">
          <header>
            <div>
              <h3>{t('referrals.linkTitle')}</h3>
              <p>{t('referrals.linkBody')}</p>
            </div>
          </header>

          <div className="tlg-invite-link-row">
            <div className="tlg-invite-link-placeholder tlg-invite-link-live" aria-label={t('referrals.linkAria')}>
              <Link2 size={17} />
              <span>{loading ? t('referrals.loadingLink') : inviteLink || t('referrals.unavailableLink')}</span>
            </div>
            <button type="button" disabled={!inviteLink} onClick={() => void copyInviteLink()}>
              <Copy size={15} /> {copied ? t('referrals.copied') : t('referrals.copy')}
            </button>
            <button type="button" className="tlg-invite-secondary-button" disabled={!inviteLink} onClick={() => void shareInviteLink()}>
              <Share2 size={15} /> {t('referrals.share')}
            </button>
          </div>
          <small className="tlg-invite-note">{t('referrals.betaNote')}</small>
        </section>

        <section className="tlg-invite-panel">
          <header>
            <div>
              <h3>{t('referrals.overviewTitle')}</h3>
              <p>{t('referrals.overviewBody')}</p>
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

        {contests.length > 0 && (
          <section className="tlg-invite-panel">
            <header>
              <div>
                <h3>{t('referrals.contestsTitle')}</h3>
                <p>{t('referrals.contestsBody')}</p>
              </div>
            </header>
            <div className="tlg-invite-contest-grid">
              {contests.map((contest) => (
                <article key={contest.id}>
                  <div className="tlg-invite-contest-head">
                    <span><Trophy size={15} /> {contestStatusLabel(contest.status, t)}</span>
                    <strong>{contest.name}</strong>
                    <p>{contest.description || t('referrals.fallbackContestName')}</p>
                  </div>
                  <div className="tlg-invite-contest-dates">
                    <span>{formatDate(contest.starts_at, localeTag)} – {formatDate(contest.ends_at, localeTag)}</span>
                    <small>{t('referrals.validationUntil', { date: formatDate(contest.validation_deadline, localeTag) })}</small>
                  </div>
                  <div className="tlg-invite-contest-you">
                    <div><span>{t('referrals.yourRank')}</span><strong>{contest.your_rank ? `#${contest.your_rank}` : '—'}</strong></div>
                    <div><span>{t('referrals.yourValidReferrals')}</span><strong>{contest.your_valid_referrals ?? 0}</strong></div>
                  </div>
                  <div className="tlg-invite-contest-prizes">
                    {contest.prizes.map((prize, index) => (
                      <div key={`${contest.id}-${index}`}>
                        <span>#{prize.rank_from}{prize.rank_to !== prize.rank_from ? `–${prize.rank_to}` : ''}</span>
                        <strong>{prizeLabel(prize, t)}</strong>
                      </div>
                    ))}
                  </div>
                </article>
              ))}
            </div>
          </section>
        )}

        <section className="tlg-invite-panel">
          <header>
            <div>
              <h3>{t('referrals.rewardsTitle')}</h3>
              <p>{t('referrals.rewardsBody', { count: rules?.max_rewardable_referrals ?? 10 })}</p>
            </div>
          </header>

          <div className="tlg-invite-reward-grid">
            <article><Coins size={20} /><div><strong>{t('referrals.prizeCoins', { count: rules?.base_reward_coins ?? 3 })}</strong><span>{t('referrals.validReward')}</span></div></article>
            <article><Coins size={20} /><div><strong>+{t('referrals.prizeCoins', { count: rules?.coin_purchase_reward_coins ?? 15 })}</strong><span>{t('referrals.coinPurchaseReward')}</span></div></article>
            <article><Coins size={20} /><div><strong>+{t('referrals.prizeCoins', { count: rules?.premium_purchase_reward_coins ?? 30 })}</strong><span>{t('referrals.premiumPurchaseReward')}</span></div></article>
          </div>

          <div className="tlg-invite-info-box">
            <strong>{t('referrals.maximumPool', { count: rules?.max_rewardable_referrals ?? 10 })}</strong>
            <p>{t('referrals.rewardRules')}</p>
          </div>
        </section>

        <section className="tlg-invite-panel">
          <header>
            <div>
              <h3>{t('referrals.activityTitle')}</h3>
              <p>{t('referrals.activityBody')}</p>
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
                      <strong>{t('referrals.invitedPlayer', { number: dashboard!.activity.length - index })}</strong>
                      <span>{formatDate(item.registered_at, localeTag)} · {statusLabel(item, t)}</span>
                    </div>
                  </div>
                  <div className="tlg-invite-activity-rewards">
                    {item.base_rewarded && <span>{t('referrals.validReferralReward', { count: rules?.base_reward_coins ?? 3 })}</span>}
                    {item.coin_purchase_rewarded && <span>{t('referrals.coinPurchase', { count: rules?.coin_purchase_reward_coins ?? 15 })}</span>}
                    {item.premium_purchase_rewarded && <span>{t('referrals.premiumReward', { count: rules?.premium_purchase_reward_coins ?? 30 })}</span>}
                    {!item.reward_coins && <span>{t('referrals.noRewardYet')}</span>}
                    {item.reward_coins > 0 && <strong>{t('referrals.totalCoinsReward', { count: item.reward_coins })}</strong>}
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <div className="tlg-invite-empty">
              <UsersRound size={30} />
              <strong>{loading ? t('referrals.loadingActivity') : t('referrals.noActivity')}</strong>
              <p>{t('referrals.noActivityBody')}</p>
            </div>
          )}
        </section>

        <section className="tlg-invite-panel tlg-invite-how-it-works">
          <header>
            <div>
              <h3>{t('referrals.validityTitle')}</h3>
              <p>{t('referrals.validityBody')}</p>
            </div>
          </header>

          <ol>
            <li>{t('referrals.validityStep1')}</li>
            <li>{t('referrals.validityStep2')}</li>
            <li>{t('referrals.validityStep3', { hours: rules?.minimum_account_age_hours ?? 72, days: rules?.minimum_active_days ?? 2 })}</li>
            <li>{t('referrals.validityStep4')}</li>
            <li>{t('referrals.validityStep5')}</li>
          </ol>

          <div className="tlg-invite-success-box">
            <CheckCircle2 size={18} />
            <div><strong>{t('referrals.idempotentTitle')}</strong><p>{t('referrals.idempotentBody')}</p></div>
          </div>
        </section>
      </div>
    </GameLayout>
  )
}
