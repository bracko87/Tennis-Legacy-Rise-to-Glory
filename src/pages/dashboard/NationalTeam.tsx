import {
  BadgeCheck,
  ChevronDown,
  ChevronUp,
  Crown,
  Flag,
  RefreshCw,
  ShieldCheck,
  UsersRound,
  Vote,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { Link } from 'react-router'

import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import NationalTeamCompetition from '../../components/national-team/NationalTeamCompetition'
import NationalTeamChat from '../../components/national-team/NationalTeamChat'
import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import '../../styles/shared-segmented-tabs.css'
import '../../styles/national-team.css'

type AssociationStatus = 'inactive' | 'activation_funding' | 'active' | 'renewal_required' | 'suspended'
type ElectionStatus = 'candidate_registration' | 'campaign' | 'voting' | 'runoff' | 'completed' | 'cancelled'

interface FundSummary {
  id?: string
  season_number?: number
  target?: number
  contributed?: number
  status?: 'open' | 'completed' | 'expired'
  opens_game_day?: number
  deadline_game_day?: number
  completed_game_day?: number
  deadline_date?: {
    season: number
    month: number
    day: number
  }
}

interface DivisionSummary {
  entry_id?: string
  division_id?: string
  division_code?: string
  label?: string
  tier_level?: number
  region_code?: string
  entry_reason?: string
  status?: string
  final_position?: number | null
}

interface CaptainSummary {
  term_id?: string
  season_number?: number
  player_id?: string
  first_name?: string
  last_name?: string
  status?: string
  term_kind?: 'elected' | 'carryover'
  is_me?: boolean
  term_start_game_day?: number
  term_end_game_day?: number
}

interface ElectionCandidate {
  candidate_id: string
  player_id: string
  first_name: string
  last_name: string
  manifesto: string
  in_current_runoff: boolean
  vote_total: number | null
}

interface ElectionSummary {
  id?: string
  season_number?: number
  status?: ElectionStatus
  election_kind?: 'annual' | 'activation' | 'special'
  reason?: string | null
  runoff_registration_open?: boolean
  current_round?: number
  registration_start_game_day?: number
  registration_end_game_day?: number
  campaign_end_game_day?: number
  voting_start_game_day?: number
  voting_end_game_day?: number
  runoff_start_game_day?: number | null
  runoff_end_game_day?: number | null
  winning_candidate_id?: string | null
  my_candidate_id?: string | null
  my_vote_candidate_id?: string | null
  candidates?: ElectionCandidate[]
}

interface RosterMember {
  membership_id: string
  player_id: string
  first_name: string
  last_name: string
  captain_eligible: boolean
  joined_game_day: number
  national_appearances: number
}

interface AssociationHistoryEvent {
  id: string
  season_number: number
  game_day: number
  event_type: string
  details: Record<string, unknown>
}

interface NationalAssociationSnapshot {
  available: boolean
  reason?: string
  game_day: number
  season_number: number
  association: {
    id: string
    name: string
    country_code: string
    world: 'ATP' | 'WTA'
    region_code: string
    status: AssociationStatus
    activated_game_day: number | null
    activated_season: number | null
    member_count: number
    minimum_activation_members: number
    is_member: boolean
    can_join?: boolean
    captain_eligible: boolean
  }
  activation_fund: FundSummary
  renewal_fund: FundSummary
  division: DivisionSummary
  captain: CaptainSummary
  election: ElectionSummary
  roster: RosterMember[]
  history: AssociationHistoryEvent[]
  my_total_contributions: number
  rules: {
    activation_cost: number
    activation_min_members: number
    renewal_cost: number
    voting_days?: number
    runoff_days: number
    renewal_opens_game_day?: number
    renewal_deadline_game_day?: number
    annual_election_start_game_day?: number
    annual_election_first_round_end_game_day?: number
    annual_candidate_registration_start_game_day?: number
    annual_voting_start_game_day?: number
    annual_voting_end_game_day?: number
  }
}

type PageTab = 'overview' | 'competition' | 'members' | 'elections' | 'chat' | 'history'

const MONTH_LENGTHS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

function absoluteGameDateParts(absoluteDay?: number | null) {
  if (absoluteDay === null || absoluteDay === undefined || absoluteDay < 0) return null
  const season = Math.floor(absoluteDay / 366) + 1
  let remaining = absoluteDay % 366
  let month = 0
  while (month < MONTH_LENGTHS.length - 1 && remaining >= MONTH_LENGTHS[month]) {
    remaining -= MONTH_LENGTHS[month]
    month += 1
  }
  return { season, month, day: remaining + 1 }
}

function localizedMonths(t: TFunction) {
  return t('nationalTeamPage.monthsShort', { returnObjects: true }) as string[]
}

function formatAbsoluteGameDay(t: TFunction, absoluteDay?: number | null) {
  const date = absoluteGameDateParts(absoluteDay)
  if (!date) return '—'
  const months = localizedMonths(t)
  return `${t('nationalTeamPage.common.season', { season: date.season })} · ${date.day} ${months[date.month]}`
}

function formatAbsoluteGameDayShort(t: TFunction, absoluteDay?: number | null) {
  const date = absoluteGameDateParts(absoluteDay)
  if (!date) return '—'
  const months = localizedMonths(t)
  return `${date.day} ${months[date.month]}`
}

function formatAbsoluteGameRange(t: TFunction, start?: number | null, end?: number | null) {
  const startDate = absoluteGameDateParts(start)
  const endDate = absoluteGameDateParts(end)
  if (!startDate || !endDate) return t('nationalTeamPage.common.notScheduled')
  const months = localizedMonths(t)
  if (startDate.season === endDate.season && startDate.month === endDate.month) {
    return `${startDate.day}–${endDate.day} ${months[startDate.month]}`
  }
  return `${formatAbsoluteGameDayShort(t, start)} – ${formatAbsoluteGameDayShort(t, end)}`
}

function initialNationalTab(): PageTab {
  if (typeof window === 'undefined') return 'overview'
  const requested = new URLSearchParams(window.location.search).get('tab')
  return requested === 'competition'
    || requested === 'members'
    || requested === 'elections'
    || requested === 'chat'
    || requested === 'history'
    ? requested
    : 'overview'
}

function statusLabel(status: AssociationStatus, t: TFunction) {
  return t(`nationalTeamPage.status.${status}`)
}

function statusCopy(status: AssociationStatus, t: TFunction) {
  return t(`nationalTeamPage.statusBody.${status}`)
}

function eventLabel(type: string) {
  return type
    .replaceAll('_', ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function formatGameDate(t: TFunction, date?: FundSummary['deadline_date']) {
  if (!date) return t('nationalTeamPage.common.notScheduled')
  const months = localizedMonths(t)
  const month = months[Math.max(0, date.month - 1)] ?? t('nationalTeamPage.common.monthFallback', { month: date.month })
  return `${t('nationalTeamPage.common.season', { season: date.season })} · ${date.day} ${month}`
}

function progressPercent(fund?: FundSummary) {
  const target = Number(fund?.target ?? 0)
  if (target <= 0) return 0
  return Math.min(100, Math.round((Number(fund?.contributed ?? 0) / target) * 100))
}

function electionStageLabel(status: ElectionStatus | undefined, t: TFunction) {
  return t(`nationalTeamPage.electionStatus.${status ?? 'none'}`)
}

export default function NationalTeamPage() {
  const { t } = useTranslation()
  const { coins, refresh: refreshCommerce } = useCommerce()
  const [snapshot, setSnapshot] = useState<NationalAssociationSnapshot | null>(null)
  const [loading, setLoading] = useState(true)
  const [working, setWorking] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [tab, setTab] = useState<PageTab>(initialNationalTab)
  const [customContribution, setCustomContribution] = useState('5')
  const [manifesto, setManifesto] = useState('')
  const [candidatePanelOpen, setCandidatePanelOpen] = useState(false)
  const [electionHelpOpen, setElectionHelpOpen] = useState(false)

  const load = useCallback(async (background = false) => {
    if (!background) setLoading(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('get_my_national_association_v1')
    if (rpcError) {
      setError(rpcError.message)
      if (!background) setSnapshot(null)
    } else {
      setSnapshot((data ?? null) as NationalAssociationSnapshot | null)
    }
    if (!background) setLoading(false)
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  useEffect(() => {
    const myCandidateId = snapshot?.election?.my_candidate_id
    if (!myCandidateId) return
    const myCandidate = snapshot?.election?.candidates?.find((candidate) => candidate.candidate_id === myCandidateId)
    if (myCandidate) setManifesto(myCandidate.manifesto ?? '')
  }, [snapshot?.election?.id, snapshot?.election?.my_candidate_id])

  const currentFund = useMemo(() => {
    if (!snapshot?.available) return null
    if (snapshot.association.activated_game_day === null) return snapshot.activation_fund
    if (snapshot.renewal_fund?.id && snapshot.renewal_fund.status === 'open') return snapshot.renewal_fund
    return null
  }, [snapshot])

  async function joinAssociation() {
    if (working) return
    setWorking(true)
    setError(null)
    setNotice(null)

    const { data, error: rpcError } = await supabase.rpc('join_my_national_association_v1')

    if (rpcError) setError(rpcError.message)
    else {
      const result = data as { association_name?: string } | null
      setNotice(t('nationalTeamPage.notices.joined', { name: result?.association_name ?? t('nationalTeamPage.eyebrow') }))
      await load(true)
    }

    setWorking(false)
  }

  async function resignCaptain() {
    if (working) return
    setWorking(true)
    setError(null)
    setNotice(null)

    const { error: rpcError } = await supabase.rpc('resign_national_captain_v1')

    if (rpcError) setError(rpcError.message)
    else {
      setNotice(t('nationalTeamPage.notices.resigned'))
      await load(true)
    }

    setWorking(false)
  }

  async function contribute(amount: number) {
    if (!currentFund?.id || amount <= 0 || working) return
    setWorking(true)
    setError(null)
    setNotice(null)

    const { data, error: rpcError } = await supabase.rpc('contribute_national_association_fund_v1', {
      p_fund_id: currentFund.id,
      p_amount: Math.floor(amount),
    })

    if (rpcError) {
      setError(rpcError.message)
    } else {
      const result = data as { accepted_amount?: number } | null
      setNotice(t('nationalTeamPage.notices.contributed', { count: Number(result?.accepted_amount ?? amount) }))
      await Promise.all([load(), refreshCommerce()])
    }

    setWorking(false)
  }

  async function registerCandidate() {
    if (!snapshot?.election?.id || working) return
    setWorking(true)
    setError(null)
    setNotice(null)

    const { error: rpcError } = await supabase.rpc('register_national_captain_candidate_v1', {
      p_election_id: snapshot.election.id,
      p_manifesto: manifesto.trim(),
    })

    if (rpcError) setError(rpcError.message)
    else {
      setNotice(t('nationalTeamPage.notices.candidacyRegistered'))
      setCandidatePanelOpen(false)
      await load(true)
    }

    setWorking(false)
  }

  async function withdrawCandidate() {
    if (!snapshot?.election?.id || working) return
    setWorking(true)
    setError(null)
    setNotice(null)

    const { error: rpcError } = await supabase.rpc('withdraw_national_captain_candidate_v1', {
      p_election_id: snapshot.election.id,
    })

    if (rpcError) setError(rpcError.message)
    else {
      setNotice(t('nationalTeamPage.notices.candidacyWithdrawn'))
      setCandidatePanelOpen(false)
      await load(true)
    }

    setWorking(false)
  }

  async function castVote(candidateId: string) {
    if (!snapshot?.election?.id || working) return
    setWorking(true)
    setError(null)
    setNotice(null)

    const { error: rpcError } = await supabase.rpc('cast_national_captain_vote_v1', {
      p_election_id: snapshot.election.id,
      p_candidate_id: candidateId,
    })

    if (rpcError) setError(rpcError.message)
    else {
      setNotice(t('nationalTeamPage.notices.voteRecorded'))
      await load(true)
    }

    setWorking(false)
  }

  if (loading) {
    return (
      <GameLayout title={t('nationalTeamPage.title')} subtitle={t('nationalTeamPage.subtitle')}>
        <section className="tlg-v2-panel nt-loading">
          <RefreshCw size={20} className="nt-spin" />
          <strong>{t('nationalTeamPage.loading')}</strong>
        </section>
      </GameLayout>
    )
  }

  if (!snapshot?.available) {
    return (
      <GameLayout title={t('nationalTeamPage.title')} subtitle={t('nationalTeamPage.subtitle')}>
        <section className="tlg-v2-panel nt-empty">
          <Flag size={28} />
          <h2>{t('nationalTeamPage.unavailableTitle')}</h2>
          <p>{t('nationalTeamPage.unavailableBody')}</p>
        </section>
      </GameLayout>
    )
  }

  const { association, activation_fund: activationFund, renewal_fund: renewalFund, election } = snapshot
  const membersReady = association.member_count >= association.minimum_activation_members
  const activationReady = Number(activationFund.contributed ?? 0) >= Number(activationFund.target ?? snapshot.rules.activation_cost)
  const candidates = (election.candidates ?? []).filter((candidate) => election.status !== 'runoff' || candidate.in_current_runoff)
  const canRegister = association.captain_eligible && (
    election.status === 'candidate_registration'
    || (election.status === 'runoff' && Boolean(election.runoff_registration_open))
  )
  const canVote = (election.status === 'voting' || election.status === 'runoff') && !election.my_vote_candidate_id
  const canWithdrawCandidate = canRegister && Boolean(election.my_candidate_id)
  const electionInProgress = election.status === 'candidate_registration'
    || election.status === 'campaign'
    || election.status === 'voting'
    || election.status === 'runoff'
  const captainName = snapshot.captain.first_name
    ? `${snapshot.captain.first_name} ${snapshot.captain.last_name}`
    : null
  const captainHeadline = captainName
    ?? (electionInProgress
      ? t('nationalTeamPage.common.electionInProgress')
      : association.activated_game_day !== null
        ? t('nationalTeamPage.common.electionPending')
        : t('nationalTeamPage.common.notElected'))
  const captainDetail = captainName
    ? electionInProgress
      ? t('nationalTeamPage.common.actingElection')
      : snapshot.captain.term_kind === 'carryover'
        ? t('nationalTeamPage.common.actingCaptain')
        : t('nationalTeamPage.common.currentCaptain')
    : electionInProgress
      ? electionStageLabel(election.status, t)
      : association.activated_game_day !== null
        ? t('nationalTeamPage.common.annualRegistration')
        : t('nationalTeamPage.common.startsAfterActivation')

  const registrationDisplayEnd = election.registration_end_game_day
  const expectedRunoffStart = election.runoff_start_game_day ?? (
    election.voting_end_game_day !== undefined ? election.voting_end_game_day + 1 : undefined
  )
  const expectedRunoffEnd = election.runoff_end_game_day ?? (
    election.voting_end_game_day !== undefined ? election.voting_end_game_day + snapshot.rules.runoff_days : undefined
  )
  const currentPhaseEnd = election.status === 'candidate_registration'
    ? election.registration_end_game_day
    : election.status === 'voting' || election.status === 'campaign'
      ? election.voting_end_game_day
      : election.status === 'runoff'
        ? election.runoff_end_game_day
        : election.completed_game_day

  const registrationPhaseState = election.status === 'candidate_registration'
    ? 'active'
    : election.id ? 'complete' : 'upcoming'
  const votingPhaseState = election.status === 'voting' || election.status === 'campaign'
    ? 'active'
    : election.status === 'runoff' || election.status === 'completed'
      ? 'complete'
      : 'upcoming'
  const runoffPhaseState = election.status === 'runoff'
    ? 'active'
    : election.status === 'completed' && (election.current_round ?? 1) > 1
      ? 'complete'
      : 'upcoming'

  return (
    <GameLayout title={t('nationalTeamPage.title')} subtitle={`${association.world} · ${association.name}`}>
      <header className="tlg-v2-page-head tlg-page-head-with-tabs nt-page-head">
        <div className="tlg-v2-page-head-copy">
          <div className="tlg-v2-page-eyebrow">{t('nationalTeamPage.eyebrow')}</div>
          <div className="nt-title-line">
            <CountryFlag
              countryCode={association.country_code}
              countryName={association.country_code}
              width={38}
              height={26}
            />
            <h2 className="tlg-v2-page-title">{association.name}</h2>
          </div>
          <p className="tlg-v2-page-description">{statusCopy(association.status, t)}</p>
          <div className="nt-head-meta">
            <span className={`nt-status nt-status-${association.status}`}>{statusLabel(association.status, t)}</span>
            <span>{t('nationalTeamPage.common.season', { season: snapshot.season_number })}</span>
            <span>{t('nationalTeamPage.common.nationalWorld', { world: association.world })}</span>
            {association.is_member ? (
              <span className="nt-member-chip">{t('nationalTeamPage.member')}</span>
            ) : association.can_join ? (
              <button type="button" className="nt-join-association" disabled={working} onClick={() => void joinAssociation()}>
                {working ? t('nationalTeamPage.common.joining') : t('nationalTeamPage.common.join')}
              </button>
            ) : null}
          </div>
          {!association.is_member && association.can_join && (
            <p className="nt-join-copy">{t('nationalTeamPage.joinCopy')}</p>
          )}
        </div>

        <div className="nt-tabs tlg-standard-tabs" role="tablist" aria-label={t('nationalTeamPage.tabsAria')}>
          {([
            ['overview', 'Overview'],
            ['competition', 'Competition'],
            ['members', `Members (${association.member_count})`],
            ['elections', 'Elections'],
            ['chat', 'Team Chat'],
            ['history', 'History'],
          ] as const).map(([key, label]) => (
            <button key={key} type="button" role="tab" aria-selected={tab === key} className={tab === key ? 'active' : ''} onClick={() => setTab(key)}>
              {label}
            </button>
          ))}
        </div>
      </header>


      {error && <div className="nt-alert nt-alert-error">{error}</div>}
      {notice && <div className="nt-alert nt-alert-success">{notice}</div>}

      {tab === 'overview' && (
        <div className="nt-overview-grid">
          <section className="tlg-v2-panel nt-hero-card">
            <header>
              <div>
                <span>COMMUNITY GOVERNANCE</span>
                <h3>Association status</h3>
              </div>
            </header>

            <div className="nt-metric-grid">
              <div><span>Eligible members</span><strong>{association.member_count}</strong><small>Minimum {association.minimum_activation_members} for activation</small></div>
              <div><span>Current division</span><strong>{snapshot.division.label ?? 'Not assigned'}</strong><small>{snapshot.division.tier_level ? `Tier ${snapshot.division.tier_level}` : 'Competition structure ready for configuration'}</small></div>
              <div><span>Captain</span><strong>{captainHeadline}</strong><small>{captainDetail}</small></div>
              <div><span>Annual renewal</span><strong>{snapshot.rules.renewal_cost} coins every January</strong><small>Complete by 31 January · inactive from 1 February if unpaid</small></div>
            </div>
          </section>

          {association.activated_game_day === null ? (
            <section className="tlg-v2-panel nt-fund-card">
              <header>
                <div>
                  <span>ACTIVATION FUND</span>
                  <h3>{Number(activationFund.contributed ?? 0)} / {Number(activationFund.target ?? snapshot.rules.activation_cost)} coins</h3>
                </div>
              </header>

              <div className="nt-progress"><span style={{ width: `${progressPercent(activationFund)}%` }} /></div>

              <div className="nt-requirements">
                <div className={activationReady ? 'done' : ''}>
                  <BadgeCheck size={16} />
                  <span>Community funding</span>
                  <strong>{activationReady ? 'Complete' : `${Number(activationFund.target ?? snapshot.rules.activation_cost) - Number(activationFund.contributed ?? 0)} coins remaining`}</strong>
                </div>
                <div className={membersReady ? 'done' : ''}>
                  <UsersRound size={16} />
                  <span>Eligible members</span>
                  <strong>{association.member_count} / {association.minimum_activation_members}</strong>
                </div>
              </div>

              <p className="nt-rule-note">
                Contributions are permanent and never create ownership, extra votes, captaincy rights or permanent administration powers.
              </p>

              {activationFund.status === 'open' && association.is_member && (
                <div className="nt-contribution-box">
                  <div className="nt-wallet"><span>Your balance</span><strong>{coins.toLocaleString()} coins</strong></div>
                  <div className="nt-quick-coins">
                    {[1, 5, 10].map((amount) => (
                      <button key={amount} type="button" disabled={working || coins < amount} onClick={() => void contribute(amount)}>
                        +{amount}
                      </button>
                    ))}
                  </div>
                  <div className="nt-custom-contribution">
                    <input
                      type="number"
                      min="1"
                      max={Math.max(1, coins)}
                      value={customContribution}
                      onChange={(event) => setCustomContribution(event.target.value)}
                      aria-label="Custom coin contribution"
                    />
                    <button type="button" disabled={working || Number(customContribution) <= 0 || coins <= 0} onClick={() => void contribute(Number(customContribution))}>
                      {working ? 'Contributing…' : 'Contribute'}
                    </button>
                  </div>
                  <small>The server automatically caps the charge to the amount still required.</small>
                </div>
              )}

              {activationReady && !membersReady && (
                <div className="nt-waiting">
                  Funding is complete. Activation will happen automatically when the association reaches five eligible members.
                </div>
              )}
            </section>
          ) : (
            <section className="tlg-v2-panel nt-fund-card">
              <header>
                <div>
                  <span>SEASON RENEWAL</span>
                  <h3>{renewalFund.id ? `Season ${renewalFund.season_number}` : 'No renewal currently open'}</h3>
                </div>
              </header>

              {renewalFund.id ? (
                <>
                  <div className="nt-progress"><span style={{ width: `${progressPercent(renewalFund)}%` }} /></div>
                  <div className="nt-fund-summary">
                    <div><span>Community total</span><strong>{Number(renewalFund.contributed ?? 0)} / {Number(renewalFund.target ?? snapshot.rules.renewal_cost)} coins</strong></div>
                    <div><span>Deadline</span><strong>{formatGameDate(renewalFund.deadline_date)}</strong></div>
                    <div><span>Status</span><strong>{renewalFund.status ?? '—'}</strong></div>
                  </div>

                  {renewalFund.status === 'open' && association.is_member && (
                    <div className="nt-contribution-box">
                      <div className="nt-wallet"><span>Your balance</span><strong>{coins.toLocaleString()} coins</strong></div>
                      <div className="nt-quick-coins">
                        {[1, 5, 10].map((amount) => (
                          <button key={amount} type="button" disabled={working || coins < amount} onClick={() => void contribute(amount)}>
                            +{amount}
                          </button>
                        ))}
                      </div>
                      <div className="nt-custom-contribution">
                        <input type="number" min="1" max={Math.max(1, coins)} value={customContribution} onChange={(event) => setCustomContribution(event.target.value)} />
                        <button type="button" disabled={working || Number(customContribution) <= 0 || coins <= 0} onClick={() => void contribute(Number(customContribution))}>
                          {working ? 'Contributing…' : 'Contribute'}
                        </button>
                      </div>
                    </div>
                  )}
                </>
              ) : (
                <div className="nt-placeholder">
                  <ShieldCheck size={20} />
                  <div><strong>Association is currently covered</strong><span>The {snapshot.rules.renewal_cost}-coin community renewal opens on 1 January each season and must be completed by 31 January.</span></div>
                </div>
              )}

              <p className="nt-rule-note">
                Annual renewal must be completed during January. If it is still unpaid on 1 February, the association becomes inactive, loses its sporting place and later re-enters through the lower competition structure.
              </p>
            </section>
          )}

          <section className="tlg-v2-panel nt-membership-status-card">
            <header className="nt-section-header">
              <div>
                <span>ASSOCIATION MEMBERSHIP</span>
                <h3>{association.is_member ? 'You are already a member' : 'Join your national association'}</h3>
              </div>
            </header>

            <div className="nt-membership-status-content">
              <div>
                <strong>{association.is_member ? association.name + ' membership is active' : 'Eligible for ' + association.name}</strong>
                <p>
                  {association.is_member
                    ? 'Your player is already part of the association. You can be considered by the national captain for future call-ups, participate in captain elections and use the private Team Chat. Membership does not guarantee selection for a national fixture.'
                    : 'Membership is voluntary. Join once and your player is immediately added to the association member pool, where the national captain can consider you for future call-ups. Members can also vote, stand for captain and use the private Team Chat.'}
                </p>
              </div>
              {association.is_member ? (
                <span className="nt-membership-confirmed">Member</span>
              ) : association.can_join ? (
                <button type="button" disabled={working} onClick={() => void joinAssociation()}>
                  {working ? 'Joining…' : 'Join association'}
                </button>
              ) : (
                <span className="nt-membership-unavailable">Not currently eligible</span>
              )}
            </div>
          </section>

          <section className="tlg-v2-panel nt-rules-card">
            <header><div><span>GOVERNANCE RULES</span><h3>Community, not ownership</h3></div></header>
            <div className="nt-rule-list">
              <div><strong>1 member = 1 vote</strong><span>Donation amount never changes voting power.</span></div>
              <div><strong>Founding status is cosmetic</strong><span>The activation initiator receives no permanent control.</span></div>
              <div><strong>Annual captain process: 1–20 January</strong><span>Candidate registration runs first; voting opens on 10 January and closes on 20 January. Tied leaders then continue into seven-day runoffs.</span></div>
              <div><strong>Playing captain uses a normal squad place</strong><span>Captaincy never guarantees selection or protects a player from fatigue/calendar rules.</span></div>
            </div>
          </section>

          <section className="tlg-v2-panel nt-contribution-history">
            <header><div><span>YOUR SUPPORT</span><h3>Personal contribution history</h3></div></header>
            <strong className="nt-big-number">{snapshot.my_total_contributions.toLocaleString()}</strong>
            <span>coins contributed across activation and renewal funds</span>
            <small>Recognition only — this total carries no governance weight.</small>
          </section>

          <section className="tlg-v2-panel nt-governance-timeline">
            <header className="nt-section-header">
              <div>
                <span>SEASON GOVERNANCE TIMELINE</span>
                <h3>What happens every January</h3>
              </div>
            </header>

            <p className="nt-section-copy">
              Renewal and captain elections are separate processes. Renewal keeps the association active in national competition; elections decide who leads the team.
            </p>

            <div className="nt-governance-steps">
              <article>
                <b>1 Jan</b>
                <div>
                  <strong>Annual renewal + candidate registration open</strong>
                  <span>Members collectively fund {snapshot.rules.renewal_cost} coins, while eligible members have until voting opens on 10 January to register a candidacy and manifesto.</span>
                </div>
              </article>
              <article>
                <b>10 Jan</b>
                <div>
                  <strong>Main captain vote opens</strong>
                  <span>Candidate registration has closed. Every active association member can now cast exactly one vote in the main election round.</span>
                </div>
              </article>
              <article>
                <b>20 Jan</b>
                <div>
                  <strong>First election round closes</strong>
                  <span>A candidate is elected only when they have at least one vote and strictly more votes than every other candidate.</span>
                </div>
              </article>
              <article>
                <b>21–27 Jan</b>
                <div>
                  <strong>First runoff when no unique winner exists</strong>
                  <span>If leaders are tied, only the tied leaders continue. If nobody stood for election, a new seven-day round opens with candidate registration available again.</span>
                </div>
              </article>
              <article>
                <b>Every 7 days</b>
                <div>
                  <strong>Runoffs repeat until somebody wins</strong>
                  <span>If the runoff is tied again, another seven-day round begins. There is no random winner and no fixed maximum number of runoff rounds.</span>
                </div>
              </article>
              <article>
                <b>31 Jan</b>
                <div>
                  <strong>Renewal deadline</strong>
                  <span>The association must have completed the full {snapshot.rules.renewal_cost}-coin community renewal before February begins.</span>
                </div>
              </article>
              <article>
                <b>1 Feb</b>
                <div>
                  <strong>Unpaid association becomes inactive</strong>
                  <span>If renewal is incomplete, the association loses its sporting place. History remains, but a later return follows the lower-tier re-entry rules rather than restoring the old division.</span>
                </div>
              </article>
            </div>

            <div className="nt-governance-continuity">
              <div>
                <strong>Captain continuity</strong>
                <span>The previous elected captain remains acting captain while the annual election or runoffs are unresolved. As soon as a new candidate wins with a unique lead, the new captain takes office.</span>
              </div>
              <div>
                <strong>Resignation or inactivity</strong>
                <span>If the captain resigns or is no longer an eligible active member, the position is vacated and a new 10-game-day replacement election begins immediately. Seven-day runoffs repeat if needed.</span>
              </div>
              <div>
                <strong>Inbox notifications</strong>
                <span>Association members are informed in-game when renewal opens, an election starts, a runoff is required, a captain resigns or becomes inactive, and when a new captain is elected.</span>
              </div>
            </div>
          </section>

        </div>
      )}

      {tab === 'competition' && <NationalTeamCompetition />}

      {tab === 'chat' && <NationalTeamChat isMember={association.is_member} associationName={association.name} />}

      {tab === 'members' && (
        <section className="tlg-v2-panel nt-members-panel">
          <header className="nt-section-header">
            <div><span>ASSOCIATION MEMBERSHIP</span><h3>{association.member_count} eligible player{association.member_count === 1 ? '' : 's'}</h3></div>
          </header>

          <p className="nt-section-copy">
            Membership is voluntary. Once you join your country's association, your player immediately enters the captain's eligible call-up pool. Membership never guarantees squad selection.
          </p>

          {association.is_member ? (
            <div className="nt-membership-join-card nt-membership-already-joined">
              <div>
                <strong>You are already an association member</strong>
                <span>Your player is in the captain's eligible call-up pool and can participate in association elections and Team Chat.</span>
              </div>
              <span className="nt-membership-confirmed">Member</span>
            </div>
          ) : association.can_join ? (
            <div className="nt-membership-join-card">
              <div>
                <strong>Become an association member</strong>
                <span>Join {association.name} to become eligible for national-team call-ups, captain elections and the private team chat.</span>
              </div>
              <button type="button" disabled={working} onClick={() => void joinAssociation()}>
                {working ? 'Joining…' : 'Join association'}
              </button>
            </div>
          ) : null}

          {snapshot.roster.length === 0 ? (
            <div className="nt-placeholder">No eligible members yet.</div>
          ) : (
            <div className="nt-roster">
              <div className="nt-roster-head"><span>Player</span><span>Captain eligibility</span><span>National appearances</span></div>
              {snapshot.roster.map((member) => (
                <div key={member.membership_id} className="nt-roster-row">
                  <strong>{member.first_name} {member.last_name}</strong>
                  <span>{member.captain_eligible ? 'Eligible' : 'Not eligible'}</span>
                  <span>{member.national_appearances}</span>
                </div>
              ))}
            </div>
          )}
        </section>
      )}

      {tab === 'elections' && (
        <div className="nt-election-grid">
          <section className="tlg-v2-panel nt-election-main">
            <header className="nt-section-header">
              <div><span>CAPTAIN ELECTION</span><h3>{electionStageLabel(election.status)}</h3></div>
            </header>

            {!election.id ? (
              <div className="nt-placeholder">
                <Vote size={20} />
                <div>
                  <strong>No election scheduled yet</strong>
                  <span>The first election opens when the association activates: 10 game days for candidate registration, then 10 game days for the main vote. In later seasons, candidate registration opens on 1 January and voting runs from 10–20 January.</span>
                </div>
              </div>
            ) : (
              <>
                <div className="nt-election-meta">
                  <div><span>Season</span><strong>{election.season_number}</strong></div>
                  <div><span>Election</span><strong>{election.election_kind === 'special' ? 'Replacement' : election.election_kind === 'activation' ? 'First captain' : 'Annual'}</strong></div>
                  <div><span>Current phase</span><strong>{electionStageLabel(election.status)}</strong></div>
                  <div><span>Phase closes</span><strong>{formatAbsoluteGameDay(currentPhaseEnd)}</strong></div>
                </div>

                <div className="nt-election-process">
                  <article className={`nt-election-phase ${registrationPhaseState}`}>
                    <div className="nt-election-phase-number">1</div>
                    <div>
                      <span>CANDIDATE REGISTRATION</span>
                      <strong>{formatAbsoluteGameRange(election.registration_start_game_day, registrationDisplayEnd)}</strong>
                      <p>Eligible members register themselves as candidates and submit a manifesto. Voting is not open during this phase.</p>
                    </div>
                  </article>

                  <article className={`nt-election-phase ${votingPhaseState}`}>
                    <div className="nt-election-phase-number">2</div>
                    <div>
                      <span>MAIN ELECTION</span>
                      <strong>{formatAbsoluteGameRange(election.voting_start_game_day, election.voting_end_game_day)}</strong>
                      <p>Candidate registration is closed. Every active association member has one vote and may choose among the registered candidates.</p>
                    </div>
                  </article>

                  <article className={`nt-election-phase ${runoffPhaseState}`}>
                    <div className="nt-election-phase-number">3</div>
                    <div>
                      <span>RUNOFF · IF NEEDED</span>
                      <strong>{formatAbsoluteGameRange(expectedRunoffStart, expectedRunoffEnd)}</strong>
                      <p>Only needed when there is no unique winner. Tied leaders continue for seven game days; further ties create another seven-day runoff.</p>
                    </div>
                  </article>
                </div>

                {snapshot.captain.is_me && (
                  <div className="nt-captain-resign">
                    <div><strong>You are the current national captain.</strong><span>You may resign at any time. A replacement election will open immediately.</span></div>
                    <button type="button" disabled={working} onClick={() => void resignCaptain()}>Resign captaincy</button>
                  </div>
                )}

                {canRegister && (
                  <div className={`nt-candidacy-action ${candidatePanelOpen ? 'expanded' : ''}`}>
                    <div className="nt-candidacy-action-head">
                      <div>
                        <span>CANDIDATE ACTION</span>
                        <strong>{election.my_candidate_id ? 'Your candidacy is registered' : 'Stand for national captain'}</strong>
                        <small>
                          {election.my_candidate_id
                            ? 'You can update your manifesto until candidate registration closes.'
                            : 'Register yourself and submit a manifesto before the candidate-registration deadline.'}
                        </small>
                      </div>
                      <button type="button" className="nt-candidacy-toggle" onClick={() => setCandidatePanelOpen((open) => !open)}>
                        {candidatePanelOpen ? <ChevronUp size={15} /> : <ChevronDown size={15} />}
                        {candidatePanelOpen ? 'Collapse' : 'Expand'}
                      </button>
                    </div>

                    {candidatePanelOpen && (
                      <div className="nt-manifesto-box">
                        <label htmlFor="captain-manifesto">Your captain manifesto</label>
                        <textarea
                          id="captain-manifesto"
                          maxLength={1000}
                          value={manifesto}
                          onChange={(event) => setManifesto(event.target.value)}
                          placeholder="Explain how you would lead the national team…"
                        />
                        <div>
                          <small>{manifesto.trim().length} / 1000 characters · minimum 10</small>
                          <button type="button" disabled={working || manifesto.trim().length < 10} onClick={() => void registerCandidate()}>
                            {election.my_candidate_id ? 'Update manifesto' : 'Register candidacy'}
                          </button>
                        </div>
                      </div>
                    )}

                    {canWithdrawCandidate && (
                      <div className="nt-candidacy-withdraw">
                        <div>
                          <strong>Withdraw candidacy</strong>
                          <span>You can withdraw while candidate registration is open. Once voting starts, the candidate list is locked for that round.</span>
                        </div>
                        <button type="button" disabled={working} onClick={() => void withdrawCandidate()}>
                          Withdraw
                        </button>
                      </div>
                    )}
                  </div>
                )}

                <div className="nt-candidate-list">
                  {candidates.length === 0 ? (
                    <div className="nt-placeholder">No candidates registered yet.</div>
                  ) : candidates.map((candidate, index) => (
                    <article
                      key={candidate.candidate_id}
                      className={`nt-candidate-row ${candidate.candidate_id === election.winning_candidate_id ? 'winner' : ''}`}
                    >
                      <div className="nt-candidate-number">{index + 1}</div>

                      <div className="nt-candidate-main">
                        <div className="nt-candidate-heading">
                          <div>
                            <span>
                              {candidate.candidate_id === election.winning_candidate_id
                                ? 'ELECTED CAPTAIN'
                                : election.status === 'runoff'
                                  ? 'RUNOFF CANDIDATE'
                                  : 'CANDIDATE'}
                            </span>
                            <Link to={`/game/players/${candidate.player_id}`} className="nt-candidate-player-link">
                              {candidate.first_name} {candidate.last_name}
                            </Link>
                          </div>

                          <div className="nt-candidate-actions">
                            {candidate.vote_total !== null && (
                              <span className="nt-candidate-vote-total">
                                {candidate.vote_total} vote{candidate.vote_total === 1 ? '' : 's'}
                              </span>
                            )}

                            {canVote && (
                              <button type="button" disabled={working} onClick={() => void castVote(candidate.candidate_id)}>
                                Vote #{index + 1}
                              </button>
                            )}

                            {election.my_vote_candidate_id === candidate.candidate_id && (
                              <strong className="nt-your-vote">Your vote · final</strong>
                            )}

                            {candidate.candidate_id === election.winning_candidate_id && <Crown size={18} />}
                          </div>
                        </div>

                        <details className="nt-candidate-manifesto">
                          <summary>Read manifesto</summary>
                          <p>{candidate.manifesto}</p>
                        </details>
                      </div>
                    </article>
                  ))}

                  {election.my_vote_candidate_id && (
                    <div className="nt-vote-final-note">
                      Your vote for this round has been recorded and is final. It cannot be changed or withdrawn.
                      If a runoff is required, you will receive one new vote in that new round.
                    </div>
                  )}
                </div>
              </>
            )}

            <div className={`nt-election-explainer nt-election-explainer-lower ${electionHelpOpen ? 'expanded' : 'collapsed'}`}>
              <div className="nt-election-explainer-head">
                <div>
                  <span>HOW CAPTAIN ELECTIONS WORK</span>
                  <strong>One member, one vote — and a winner must have a unique lead</strong>
                </div>
                <button
                  type="button"
                  className="nt-election-help-toggle"
                  onClick={() => setElectionHelpOpen((open) => !open)}
                >
                  {electionHelpOpen ? <ChevronUp size={15} /> : <ChevronDown size={15} />}
                  {electionHelpOpen ? 'Collapse' : 'Expand'}
                </button>
              </div>

              {electionHelpOpen && (
                <div className="nt-election-explainer-grid">
                <article>
                  <b>Phase 1 · Candidate registration</b>
                  <strong>Annual: 1 January → 10 January</strong>
                  <span>Before voting begins, eligible members can register themselves as candidates and submit or update a manifesto. On first activation or a replacement election, this phase lasts 10 game days from the moment the election opens.</span>
                </article>
                <article>
                  <b>Phase 2 · Main election</b>
                  <strong>Annual: 10 January → 20 January</strong>
                  <span>Candidate registration is closed. Every active member gets exactly one vote for this round, including members who are candidates. A candidate may vote for themselves or any other candidate. Once cast, the vote is final and cannot be changed or withdrawn.</span>
                </article>
                <article>
                  <b>Phase 3 · Runoff</b>
                  <strong>7 game days · only if needed</strong>
                  <span>If the main round has no unique winner, only the tied leaders continue. Every eligible member receives one new vote for that runoff round. A further tie creates another seven-day round with one new vote per member again.</span>
                </article>
                <article>
                  <b>Winning condition</b>
                  <strong>At least 1 vote + unique lead</strong>
                  <span>A candidate wins only when their vote total is strictly higher than every other candidate. A zero-vote candidate cannot become captain automatically.</span>
                </article>
                <article>
                  <b>Candidate withdrawal</b>
                  <strong>Allowed while registration is open</strong>
                  <span>A registered candidate may withdraw before voting begins. Once a voting round starts, the candidate list is locked for that round so already-cast votes cannot be undermined.</span>
                </article>
                <article>
                  <b>Previous captain</b>
                  <strong>Acts until a successor wins</strong>
                  <span>During an unresolved annual election, the previous elected captain remains acting captain until a new candidate wins with a unique lead.</span>
                </article>
                <article>
                  <b>Captain resignation</b>
                  <strong>New three-stage process starts immediately</strong>
                  <span>The captain may resign at any time. Members receive an inbox notification, then a new 10-day candidate-registration phase begins before the 10-day replacement vote.</span>
                </article>
                <article>
                  <b>Captain becomes inactive</b>
                  <strong>Seat automatically becomes vacant</strong>
                  <span>If the captain is no longer an eligible active association member, the game opens the same replacement-election process automatically.</span>
                </article>
                <article>
                  <b>Member notifications</b>
                  <strong>Delivered through the in-game inbox</strong>
                  <span>Members are notified when candidate registration opens, when the main vote opens, when a runoff is required, when a captain resigns or becomes inactive, and when a new captain is elected.</span>
                </article>
                </div>
              )}
            </div>

          </section>

          <aside className="tlg-v2-panel nt-election-rules">
            <span>ELECTION PRINCIPLES</span>
            <h3>No pay-to-govern</h3>
            <ul>
              <li>Every active member receives exactly one vote per election round, including members who are candidates.</li>
              <li>A candidate may vote for themselves or for any other candidate.</li>
              <li>Once a vote is cast, it is final for that round and cannot be changed or withdrawn.</li>
              <li>If a runoff starts, every eligible member receives one new vote for that runoff round.</li>
              <li>Activation and renewal donations never create extra votes.</li>
              <li>Candidate manifestos are required and remain available to all members from the candidate list.</li>
              <li>Candidates may withdraw while candidate registration is open; once voting begins, the candidate list is locked.</li>
              <li>Annual candidate registration runs from 1 January until voting opens on 10 January.</li>
              <li>The annual main vote runs from 10 January through 20 January.</li>
              <li>A tie moves only the tied leaders into a seven-day runoff. Further ties repeat in seven-day rounds until somebody has a unique lead.</li>
              <li>The previous captain remains acting captain while an annual election is unresolved.</li>
              <li>Resignation or captain ineligibility opens 10 days of candidate registration followed by a 10-day replacement vote.</li>
              <li>The captain may be a player but receives no automatic squad position.</li>
            </ul>
          </aside>
        </div>
      )}

      {tab === 'history' && (
        <section className="tlg-v2-panel nt-history-panel">
          <header className="nt-section-header">
            <div><span>ASSOCIATION HISTORY</span><h3>Permanent national record</h3></div>
          </header>
          <p className="nt-section-copy">
            Suspension never deletes association history, captaincies, titles, rankings or previous competition records.
          </p>

          {snapshot.history.length === 0 ? (
            <div className="nt-placeholder">The association has no recorded lifecycle events yet.</div>
          ) : (
            <div className="nt-history-list">
              {snapshot.history.map((event) => (
                <article key={event.id}>
                  <div className="nt-history-dot" />
                  <div>
                    <strong>{eventLabel(event.event_type)}</strong>
                    <span>Season {event.season_number} · Game day {event.game_day}</span>
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>
      )}
    </GameLayout>
  )
}
