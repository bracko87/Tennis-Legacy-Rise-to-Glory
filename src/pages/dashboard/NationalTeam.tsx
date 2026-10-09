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
            ['overview', t('nationalTeamPage.common.tabs.overview')],
            ['competition', t('nationalTeamPage.common.tabs.competition')],
            ['members', `${t('nationalTeamPage.common.tabs.members')} (${association.member_count})`],
            ['elections', t('nationalTeamPage.common.tabs.elections')],
            ['chat', t('nationalTeamPage.common.tabs.chat')],
            ['history', t('nationalTeamPage.common.tabs.history')],
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
                <span>{t('nationalTeamPage.overview.governance')}</span>
                <h3>{t('nationalTeamPage.overview.statusTitle')}</h3>
              </div>
            </header>

            <div className="nt-metric-grid">
              <div><span>{t('nationalTeamPage.overview.eligibleMembers')}</span><strong>{association.member_count}</strong><small>{t('nationalTeamPage.overview.activationMinimum', { count: association.minimum_activation_members })}</small></div>
              <div><span>{t('nationalTeamPage.overview.division')}</span><strong>{snapshot.division.label ?? t('nationalTeamPage.overview.notAssigned')}</strong><small>{snapshot.division.tier_level ? t('nationalTeamPage.overview.tier', { tier: snapshot.division.tier_level }) : t('nationalTeamPage.overview.structureReady')}</small></div>
              <div><span>{t('nationalTeamPage.overview.captain')}</span><strong>{captainHeadline}</strong><small>{captainDetail}</small></div>
              <div><span>{t('nationalTeamPage.overview.annualRenewal')}</span><strong>{t('nationalTeamPage.overview.annualRenewalValue', { coins: snapshot.rules.renewal_cost })}</strong><small>{t('nationalTeamPage.overview.annualRenewalNote')}</small></div>
            </div>
          </section>

          {association.activated_game_day === null ? (
            <section className="tlg-v2-panel nt-fund-card">
              <header>
                <div>
                  <span>{t('nationalTeamPage.overview.activationFund')}</span>
                  <h3>{t('nationalTeamPage.overview.communityTotalValue', { current: Number(activationFund.contributed ?? 0), target: Number(activationFund.target ?? snapshot.rules.activation_cost) })}</h3>
                </div>
              </header>

              <div className="nt-progress"><span style={{ width: `${progressPercent(activationFund)}%` }} /></div>

              <div className="nt-requirements">
                <div className={activationReady ? 'done' : ''}>
                  <BadgeCheck size={16} />
                  <span>{t('nationalTeamPage.overview.communityFunding')}</span>
                  <strong>{activationReady ? t('nationalTeamPage.fundingExtra.complete') : t('nationalTeamPage.fundingExtra.remaining', { count: Number(activationFund.target ?? snapshot.rules.activation_cost) - Number(activationFund.contributed ?? 0) })}</strong>
                </div>
                <div className={membersReady ? 'done' : ''}>
                  <UsersRound size={16} />
                  <span>{t('nationalTeamPage.overview.eligibleMembers')}</span>
                  <strong>{association.member_count} / {association.minimum_activation_members}</strong>
                </div>
              </div>

              <p className="nt-rule-note">
                Contributions are permanent and never create ownership, extra votes, captaincy rights or permanent administration powers.
              </p>

              {activationFund.status === 'open' && association.is_member && (
                <div className="nt-contribution-box">
                  <div className="nt-wallet"><span>{t('nationalTeamPage.overview.yourBalance')}</span><strong>{t('nationalTeamPage.overview.coins', { count: coins.toLocaleString() })}</strong></div>
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
                      aria-label={t('nationalTeamPage.overview.contributionAria')}
                    />
                    <button type="button" disabled={working || Number(customContribution) <= 0 || coins <= 0} onClick={() => void contribute(Number(customContribution))}>
                      {working ? t('nationalTeamPage.fundingExtra.contributing') : t('nationalTeamPage.fundingExtra.contribute')}
                    </button>
                  </div>
                  <small>{t('nationalTeamPage.overview.capNote')}</small>
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
                  <span>{t('nationalTeamPage.overview.seasonRenewal')}</span>
                  <h3>{renewalFund.id ? t('nationalTeamPage.common.season', { season: renewalFund.season_number }) : t('nationalTeamPage.fundingExtra.noRenewal')}</h3>
                </div>
              </header>

              {renewalFund.id ? (
                <>
                  <div className="nt-progress"><span style={{ width: `${progressPercent(renewalFund)}%` }} /></div>
                  <div className="nt-fund-summary">
                    <div><span>{t('nationalTeamPage.overview.communityTotal')}</span><strong>{t('nationalTeamPage.overview.communityTotalValue', { current: Number(renewalFund.contributed ?? 0), target: Number(renewalFund.target ?? snapshot.rules.renewal_cost) })}</strong></div>
                    <div><span>{t('nationalTeamPage.overview.deadline')}</span><strong>{formatGameDate(t, renewalFund.deadline_date)}</strong></div>
                    <div><span>{t('nationalTeamPage.overview.status')}</span><strong>{renewalFund.status ?? '—'}</strong></div>
                  </div>

                  {renewalFund.status === 'open' && association.is_member && (
                    <div className="nt-contribution-box">
                      <div className="nt-wallet"><span>{t('nationalTeamPage.overview.yourBalance')}</span><strong>{t('nationalTeamPage.overview.coins', { count: coins.toLocaleString() })}</strong></div>
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
                          {working ? t('nationalTeamPage.fundingExtra.contributing') : t('nationalTeamPage.fundingExtra.contribute')}
                        </button>
                      </div>
                    </div>
                  )}
                </>
              ) : (
                <div className="nt-placeholder">
                  <ShieldCheck size={20} />
                  <div><strong>{t('nationalTeamPage.overview.covered')}</strong><span>{t('nationalTeamPage.overview.coveredBody', { coins: snapshot.rules.renewal_cost })}</span></div>
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
                <span>{t('nationalTeamPage.overview.membership')}</span>
                <h3>{association.is_member ? t('nationalTeamPage.fundingExtra.memberAlreadyTitle') : t('nationalTeamPage.fundingExtra.memberJoinTitle')}</h3>
              </div>
            </header>

            <div className="nt-membership-status-content">
              <div>
                <strong>{association.is_member ? t('nationalTeamPage.fundingExtra.membershipActive', { name: association.name }) : t('nationalTeamPage.fundingExtra.eligibleFor', { name: association.name })}</strong>
                <p>
                  {association.is_member ? t('nationalTeamPage.fundingExtra.activeBody') : t('nationalTeamPage.fundingExtra.eligibleBody')}
                </p>
              </div>
              {association.is_member ? (
                <span className="nt-membership-confirmed">{t('nationalTeamPage.fundingExtra.memberBadge')}</span>
              ) : association.can_join ? (
                <button type="button" disabled={working} onClick={() => void joinAssociation()}>
                  {working ? 'Joining…' : 'Join association'}
                </button>
              ) : (
                <span className="nt-membership-unavailable">{t('nationalTeamPage.overview.notEligible')}</span>
              )}
            </div>
          </section>

          <section className="tlg-v2-panel nt-rules-card">
            <header><div><span>{t('nationalTeamPage.overview.governanceRules')}</span><h3>{t('nationalTeamPage.overview.communityNotOwnership')}</h3></div></header>
            <div className="nt-rule-list">
              <div><strong>{t('nationalTeamPage.overview.oneVote')}</strong><span>{t('nationalTeamPage.overview.oneVoteBody')}</span></div>
              <div><strong>{t('nationalTeamPage.overview.founding')}</strong><span>{t('nationalTeamPage.overview.foundingBody')}</span></div>
              <div><strong>{t('nationalTeamPage.overview.annualProcess')}</strong><span>{t('nationalTeamPage.overview.annualProcessBody')}</span></div>
              <div><strong>{t('nationalTeamPage.overview.captainSquad')}</strong><span>{t('nationalTeamPage.overview.captainSquadBody')}</span></div>
            </div>
          </section>

          <section className="tlg-v2-panel nt-contribution-history">
            <header><div><span>{t('nationalTeamPage.overview.yourSupport')}</span><h3>{t('nationalTeamPage.overview.contributionHistory')}</h3></div></header>
            <strong className="nt-big-number">{snapshot.my_total_contributions.toLocaleString()}</strong>
            <span>{t('nationalTeamPage.overview.contributedAcross')}</span>
            <small>{t('nationalTeamPage.overview.recognitionOnly')}</small>
          </section>

          <section className="tlg-v2-panel nt-governance-timeline">
            <header className="nt-section-header">
              <div>
                <span>{t('nationalTeamPage.overview.timeline')}</span>
                <h3>{t('nationalTeamPage.overview.timelineTitle')}</h3>
              </div>
            </header>

            <p className="nt-section-copy">
              Renewal and captain elections are separate processes. Renewal keeps the association active in national competition; elections decide who leads the team.
            </p>

            <div className="nt-governance-steps">
              <article>
                <b>{t('nationalTeamPage.overview.jan1')}</b>
                <div>
                  <strong>{t('nationalTeamPage.overview.jan1Title')}</strong>
                  <span>{t('nationalTeamPage.fundingExtra.jan1Body', { coins: snapshot.rules.renewal_cost })}</span>
                </div>
              </article>
              <article>
                <b>{t('nationalTeamPage.overview.jan10')}</b>
                <div>
                  <strong>{t('nationalTeamPage.overview.jan10Title')}</strong>
                  <span>{t('nationalTeamPage.overview.jan10Body')}</span>
                </div>
              </article>
              <article>
                <b>{t('nationalTeamPage.overview.jan20')}</b>
                <div>
                  <strong>{t('nationalTeamPage.overview.jan20Title')}</strong>
                  <span>{t('nationalTeamPage.overview.jan20Body')}</span>
                </div>
              </article>
              <article>
                <b>{t('nationalTeamPage.overview.jan21')}</b>
                <div>
                  <strong>{t('nationalTeamPage.overview.jan21Title')}</strong>
                  <span>{t('nationalTeamPage.overview.jan21Body')}</span>
                </div>
              </article>
              <article>
                <b>{t('nationalTeamPage.overview.every7')}</b>
                <div>
                  <strong>{t('nationalTeamPage.overview.every7Title')}</strong>
                  <span>{t('nationalTeamPage.overview.every7Body')}</span>
                </div>
              </article>
              <article>
                <b>{t('nationalTeamPage.overview.jan31')}</b>
                <div>
                  <strong>{t('nationalTeamPage.overview.jan31Title')}</strong>
                  <span>{t('nationalTeamPage.fundingExtra.jan31Body', { coins: snapshot.rules.renewal_cost })}</span>
                </div>
              </article>
              <article>
                <b>{t('nationalTeamPage.overview.feb1')}</b>
                <div>
                  <strong>{t('nationalTeamPage.overview.feb1Title')}</strong>
                  <span>{t('nationalTeamPage.overview.feb1Body')}</span>
                </div>
              </article>
            </div>

            <div className="nt-governance-continuity">
              <div>
                <strong>{t('nationalTeamPage.overview.continuity')}</strong>
                <span>{t('nationalTeamPage.overview.continuityBody')}</span>
              </div>
              <div>
                <strong>{t('nationalTeamPage.overview.resignation')}</strong>
                <span>{t('nationalTeamPage.overview.resignationBody')}</span>
              </div>
              <div>
                <strong>{t('nationalTeamPage.overview.inbox')}</strong>
                <span>{t('nationalTeamPage.overview.inboxBody')}</span>
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
            <div><span>{t('nationalTeamPage.overview.membership')}</span><h3>{association.member_count} eligible player{association.member_count === 1 ? '' : 's'}</h3></div>
          </header>

          <p className="nt-section-copy">
            Membership is voluntary. Once you join your country's association, your player immediately enters the captain's eligible call-up pool. Membership never guarantees squad selection.
          </p>

          {association.is_member ? (
            <div className="nt-membership-join-card nt-membership-already-joined">
              <div>
                <strong>{t('nationalTeamPage.members.already')}</strong>
                <span>{t('nationalTeamPage.members.alreadyBody')}</span>
              </div>
              <span className="nt-membership-confirmed">{t('nationalTeamPage.fundingExtra.memberBadge')}</span>
            </div>
          ) : association.can_join ? (
            <div className="nt-membership-join-card">
              <div>
                <strong>{t('nationalTeamPage.members.become')}</strong>
                <span>{t('nationalTeamPage.common.joinNamed', { name: association.name })}</span>
              </div>
              <button type="button" disabled={working} onClick={() => void joinAssociation()}>
                {working ? 'Joining…' : 'Join association'}
              </button>
            </div>
          ) : null}

          {snapshot.roster.length === 0 ? (
            <div className="nt-placeholder">{t('nationalTeamPage.members.none')}</div>
          ) : (
            <div className="nt-roster">
              <div className="nt-roster-head"><span>{t('nationalTeamPage.members.player')}</span><span>{t('nationalTeamPage.members.captainEligibility')}</span><span>{t('nationalTeamPage.members.appearances')}</span></div>
              {snapshot.roster.map((member) => (
                <div key={member.membership_id} className="nt-roster-row">
                  <strong>{member.first_name} {member.last_name}</strong>
                  <span>{member.captain_eligible ? t('nationalTeamPage.common.eligible') : t('nationalTeamPage.common.notEligible')}</span>
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
              <div><span>{t('nationalTeamPage.election.kicker')}</span><h3>{electionStageLabel(election.status, t)}</h3></div>
            </header>

            {!election.id ? (
              <div className="nt-placeholder">
                <Vote size={20} />
                <div>
                  <strong>{t('nationalTeamPage.election.none')}</strong>
                  <span>{t('nationalTeamPage.election.noneBody')}</span>
                </div>
              </div>
            ) : (
              <>
                <div className="nt-election-meta">
                  <div><span>{t('nationalTeamPage.election.season')}</span><strong>{election.season_number}</strong></div>
                  <div><span>{t('nationalTeamPage.election.election')}</span><strong>{election.election_kind === 'special' ? t('nationalTeamPage.election.replacement') : election.election_kind === 'activation' ? t('nationalTeamPage.election.firstCaptain') : t('nationalTeamPage.election.annual')}</strong></div>
                  <div><span>{t('nationalTeamPage.election.currentPhase')}</span><strong>{electionStageLabel(election.status, t)}</strong></div>
                  <div><span>{t('nationalTeamPage.election.closes')}</span><strong>{formatAbsoluteGameDay(t, currentPhaseEnd)}</strong></div>
                </div>

                <div className="nt-election-process">
                  <article className={`nt-election-phase ${registrationPhaseState}`}>
                    <div className="nt-election-phase-number">1</div>
                    <div>
                      <span>{t('nationalTeamPage.election.registration')}</span>
                      <strong>{formatAbsoluteGameRange(t, election.registration_start_game_day, registrationDisplayEnd)}</strong>
                      <p>{t('nationalTeamPage.election.registrationBody')}</p>
                    </div>
                  </article>

                  <article className={`nt-election-phase ${votingPhaseState}`}>
                    <div className="nt-election-phase-number">2</div>
                    <div>
                      <span>{t('nationalTeamPage.election.main')}</span>
                      <strong>{formatAbsoluteGameRange(t, election.voting_start_game_day, election.voting_end_game_day)}</strong>
                      <p>{t('nationalTeamPage.election.mainBody')}</p>
                    </div>
                  </article>

                  <article className={`nt-election-phase ${runoffPhaseState}`}>
                    <div className="nt-election-phase-number">3</div>
                    <div>
                      <span>{t('nationalTeamPage.election.runoff')}</span>
                      <strong>{formatAbsoluteGameRange(t, expectedRunoffStart, expectedRunoffEnd)}</strong>
                      <p>{t('nationalTeamPage.election.runoffBody')}</p>
                    </div>
                  </article>
                </div>

                {snapshot.captain.is_me && (
                  <div className="nt-captain-resign">
                    <div><strong>{t('nationalTeamPage.election.captainNow')}</strong><span>{t('nationalTeamPage.election.captainNowBody')}</span></div>
                    <button type="button" disabled={working} onClick={() => void resignCaptain()}>{t('nationalTeamPage.election.resign')}</button>
                  </div>
                )}

                {canRegister && (
                  <div className={`nt-candidacy-action ${candidatePanelOpen ? 'expanded' : ''}`}>
                    <div className="nt-candidacy-action-head">
                      <div>
                        <span>{t('nationalTeamPage.election.candidateAction')}</span>
                        <strong>{election.my_candidate_id ? t('nationalTeamPage.electionExtra.candidacyRegistered') : t('nationalTeamPage.electionExtra.stand')}</strong>
                        <small>
                          {election.my_candidate_id
                            ? t('nationalTeamPage.electionExtra.updateHint')
                            : t('nationalTeamPage.electionExtra.registerHint')}
                        </small>
                      </div>
                      <button type="button" className="nt-candidacy-toggle" onClick={() => setCandidatePanelOpen((open) => !open)}>
                        {candidatePanelOpen ? <ChevronUp size={15} /> : <ChevronDown size={15} />}
                        {candidatePanelOpen ? t('nationalTeamPage.electionExtra.collapse') : t('nationalTeamPage.electionExtra.expand')}
                      </button>
                    </div>

                    {candidatePanelOpen && (
                      <div className="nt-manifesto-box">
                        <label htmlFor="captain-manifesto">{t('nationalTeamPage.election.manifesto')}</label>
                        <textarea
                          id="captain-manifesto"
                          maxLength={1000}
                          value={manifesto}
                          onChange={(event) => setManifesto(event.target.value)}
                          placeholder={t('nationalTeamPage.election.manifestoPlaceholder')}
                        />
                        <div>
                          <small>{t('nationalTeamPage.electionExtra.characters', { count: manifesto.trim().length })}</small>
                          <button type="button" disabled={working || manifesto.trim().length < 10} onClick={() => void registerCandidate()}>
                            {election.my_candidate_id ? t('nationalTeamPage.electionExtra.update') : t('nationalTeamPage.electionExtra.register')}
                          </button>
                        </div>
                      </div>
                    )}

                    {canWithdrawCandidate && (
                      <div className="nt-candidacy-withdraw">
                        <div>
                          <strong>{t('nationalTeamPage.election.withdraw')}</strong>
                          <span>{t('nationalTeamPage.election.withdrawBody')}</span>
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
                    <div className="nt-placeholder">{t('nationalTeamPage.election.noCandidates')}</div>
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
                                ? t('nationalTeamPage.electionExtra.elected')
                                : election.status === 'runoff'
                                  ? t('nationalTeamPage.electionExtra.runoffCandidate')
                                  : t('nationalTeamPage.electionExtra.candidate')}
                            </span>
                            <Link to={`/game/players/${candidate.player_id}`} className="nt-candidate-player-link">
                              {candidate.first_name} {candidate.last_name}
                            </Link>
                          </div>

                          <div className="nt-candidate-actions">
                            {candidate.vote_total !== null && (
                              <span className="nt-candidate-vote-total">
                                {t('nationalTeamPage.electionExtra.votes', { count: candidate.vote_total })}
                              </span>
                            )}

                            {canVote && (
                              <button type="button" disabled={working} onClick={() => void castVote(candidate.candidate_id)}>
                                Vote #{index + 1}
                              </button>
                            )}

                            {election.my_vote_candidate_id === candidate.candidate_id && (
                              <strong className="nt-your-vote">{t('nationalTeamPage.election.yourVote')}</strong>
                            )}

                            {candidate.candidate_id === election.winning_candidate_id && <Crown size={18} />}
                          </div>
                        </div>

                        <details className="nt-candidate-manifesto">
                          <summary>{t('nationalTeamPage.election.readManifesto')}</summary>
                          <p>{candidate.manifesto}</p>
                        </details>
                      </div>
                    </article>
                  ))}

                  {election.my_vote_candidate_id && (
                    <div className="nt-vote-final-note">
                      {t('nationalTeamPage.electionExtra.voteFinalNote')}
                    </div>
                  )}
                </div>
              </>
            )}

            <div className={`nt-election-explainer nt-election-explainer-lower ${electionHelpOpen ? 'expanded' : 'collapsed'}`}>
              <div className="nt-election-explainer-head">
                <div>
                  <span>{t('nationalTeamPage.election.howKicker')}</span>
                  <strong>{t('nationalTeamPage.election.howTitle')}</strong>
                </div>
                <button
                  type="button"
                  className="nt-election-help-toggle"
                  onClick={() => setElectionHelpOpen((open) => !open)}
                >
                  {electionHelpOpen ? <ChevronUp size={15} /> : <ChevronDown size={15} />}
                  {electionHelpOpen ? t('nationalTeamPage.electionExtra.collapse') : t('nationalTeamPage.electionExtra.expand')}
                </button>
              </div>

              {electionHelpOpen && (
                <div className="nt-election-explainer-grid">
                <article>
                  <b>{t('nationalTeamPage.election.phase1')}</b>
                  <strong>{t('nationalTeamPage.election.phase1When')}</strong>
                  <span>{t('nationalTeamPage.election.phase1Body')}</span>
                </article>
                <article>
                  <b>{t('nationalTeamPage.election.phase2')}</b>
                  <strong>{t('nationalTeamPage.election.phase2When')}</strong>
                  <span>{t('nationalTeamPage.election.phase2Body')}</span>
                </article>
                <article>
                  <b>{t('nationalTeamPage.election.phase3')}</b>
                  <strong>{t('nationalTeamPage.election.phase3When')}</strong>
                  <span>{t('nationalTeamPage.election.phase3Body')}</span>
                </article>
                <article>
                  <b>{t('nationalTeamPage.election.winning')}</b>
                  <strong>{t('nationalTeamPage.election.winningWhen')}</strong>
                  <span>{t('nationalTeamPage.election.winningBody')}</span>
                </article>
                <article>
                  <b>{t('nationalTeamPage.election.withdrawal')}</b>
                  <strong>{t('nationalTeamPage.election.withdrawalWhen')}</strong>
                  <span>{t('nationalTeamPage.election.withdrawalBody')}</span>
                </article>
                <article>
                  <b>{t('nationalTeamPage.election.previous')}</b>
                  <strong>{t('nationalTeamPage.election.previousWhen')}</strong>
                  <span>{t('nationalTeamPage.election.previousBody')}</span>
                </article>
                <article>
                  <b>{t('nationalTeamPage.election.resignation')}</b>
                  <strong>{t('nationalTeamPage.election.resignationWhen')}</strong>
                  <span>{t('nationalTeamPage.election.resignationBody')}</span>
                </article>
                <article>
                  <b>{t('nationalTeamPage.election.inactive')}</b>
                  <strong>{t('nationalTeamPage.election.inactiveWhen')}</strong>
                  <span>{t('nationalTeamPage.election.inactiveBody')}</span>
                </article>
                <article>
                  <b>{t('nationalTeamPage.election.notifications')}</b>
                  <strong>{t('nationalTeamPage.election.notificationsWhen')}</strong>
                  <span>{t('nationalTeamPage.election.notificationsBody')}</span>
                </article>
                </div>
              )}
            </div>

          </section>

          <aside className="tlg-v2-panel nt-election-rules">
            <span>{t('nationalTeamPage.election.principles')}</span>
            <h3>{t('nationalTeamPage.election.noPay')}</h3>
            <ul>
              {(t('nationalTeamPage.electionExtra.principles', { returnObjects: true }) as string[]).map((item) => <li key={item}>{item}</li>)}
            </ul>
          </aside>
        </div>
      )}

      {tab === 'history' && (
        <section className="tlg-v2-panel nt-history-panel">
          <header className="nt-section-header">
            <div><span>{t('nationalTeamPage.history.kicker')}</span><h3>{t('nationalTeamPage.history.title')}</h3></div>
          </header>
          <p className="nt-section-copy">
            Suspension never deletes association history, captaincies, titles, rankings or previous competition records.
          </p>

          {snapshot.history.length === 0 ? (
            <div className="nt-placeholder">{t('nationalTeamPage.history.empty')}</div>
          ) : (
            <div className="nt-history-list">
              {snapshot.history.map((event) => (
                <article key={event.id}>
                  <div className="nt-history-dot" />
                  <div>
                    <strong>{eventLabel(event.event_type)}</strong>
                    <span>{t('nationalTeamPage.common.season', { season: event.season_number })} · {t('nationalTeamPage.common.gameDay', { day: event.game_day })}</span>
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
