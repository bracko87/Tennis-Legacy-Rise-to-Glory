import {
  BadgeCheck,
  CalendarClock,
  Coins,
  Crown,
  Flag,
  Landmark,
  RefreshCw,
  ShieldCheck,
  UsersRound,
  Vote,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'

import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
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
  current_round?: number
  registration_start_game_day?: number
  registration_end_game_day?: number
  campaign_end_game_day?: number
  voting_end_game_day?: number
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
    captain_eligible: boolean
  }
  activation_fund: FundSummary
  renewal_fund: FundSummary
  division: DivisionSummary
  captain: CaptainSummary
  election: ElectionSummary
  roster: RosterMember[]
  history: AssociationHistoryEvent[]
  treasury_balance: number
  my_total_contributions: number
  rules: {
    activation_cost: number
    activation_min_members: number
    renewal_cost: number
    voting_days: number
    runoff_days: number
  }
}

type PageTab = 'overview' | 'members' | 'elections' | 'history'

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function statusLabel(status: AssociationStatus) {
  switch (status) {
    case 'activation_funding': return 'Activation funding'
    case 'renewal_required': return 'Renewal required'
    case 'suspended': return 'Suspended'
    case 'active': return 'Active'
    default: return 'Inactive'
  }
}

function statusCopy(status: AssociationStatus) {
  switch (status) {
    case 'active': return 'The association is active and governed by its player community.'
    case 'renewal_required': return 'The association is active but must complete community renewal for the next national-team season.'
    case 'suspended': return 'The association missed renewal and has lost its sporting place. A future reactivation returns through the bottom active tier.'
    case 'activation_funding': return 'Community activation has started. Funding and the five-member requirement must both be completed.'
    default: return 'This national association is dormant until the player community completes activation.'
  }
}

function eventLabel(type: string) {
  return type
    .replaceAll('_', ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function formatGameDate(date?: FundSummary['deadline_date']) {
  if (!date) return 'Not scheduled'
  return `Season ${date.season} · ${date.day} ${MONTHS[Math.max(0, date.month - 1)] ?? `Month ${date.month}`}`
}

function progressPercent(fund?: FundSummary) {
  const target = Number(fund?.target ?? 0)
  if (target <= 0) return 0
  return Math.min(100, Math.round((Number(fund?.contributed ?? 0) / target) * 100))
}

function electionStageLabel(status?: ElectionStatus) {
  switch (status) {
    case 'candidate_registration': return 'Candidate registration'
    case 'campaign': return 'Manifesto campaign'
    case 'voting': return 'Voting open'
    case 'runoff': return 'Runoff voting'
    case 'completed': return 'Election completed'
    case 'cancelled': return 'Election cancelled'
    default: return 'Not scheduled'
  }
}

export default function NationalTeamPage() {
  const { coins, refresh: refreshCommerce } = useCommerce()
  const [snapshot, setSnapshot] = useState<NationalAssociationSnapshot | null>(null)
  const [loading, setLoading] = useState(true)
  const [working, setWorking] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [tab, setTab] = useState<PageTab>('overview')
  const [customContribution, setCustomContribution] = useState('5')
  const [manifesto, setManifesto] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('get_my_national_association_v1')
    if (rpcError) {
      setError(rpcError.message)
      setSnapshot(null)
    } else {
      setSnapshot((data ?? null) as NationalAssociationSnapshot | null)
    }
    setLoading(false)
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const currentFund = useMemo(() => {
    if (!snapshot?.available) return null
    if (snapshot.association.activated_game_day === null) return snapshot.activation_fund
    if (snapshot.renewal_fund?.id && snapshot.renewal_fund.status === 'open') return snapshot.renewal_fund
    return null
  }, [snapshot])

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
      setNotice(`${Number(result?.accepted_amount ?? amount)} coin${Number(result?.accepted_amount ?? amount) === 1 ? '' : 's'} contributed to the association fund.`)
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
      setNotice('Your captain candidacy and manifesto have been registered.')
      await load()
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
      setNotice('Your vote has been recorded. Donations never change voting power.')
      await load()
    }

    setWorking(false)
  }

  if (loading) {
    return (
      <GameLayout title="National Team" subtitle="Association & captaincy">
        <section className="tlg-v2-panel nt-loading">
          <RefreshCw size={20} className="nt-spin" />
          <strong>Loading national association…</strong>
        </section>
      </GameLayout>
    )
  }

  if (!snapshot?.available) {
    return (
      <GameLayout title="National Team" subtitle="Association & captaincy">
        <section className="tlg-v2-panel nt-empty">
          <Flag size={28} />
          <h2>National association unavailable</h2>
          <p>Your player needs an eligible ATP or WTA national identity before joining a national association.</p>
        </section>
      </GameLayout>
    )
  }

  const { association, activation_fund: activationFund, renewal_fund: renewalFund, election } = snapshot
  const membersReady = association.member_count >= association.minimum_activation_members
  const activationReady = Number(activationFund.contributed ?? 0) >= Number(activationFund.target ?? snapshot.rules.activation_cost)
  const candidates = (election.candidates ?? []).filter((candidate) => election.status !== 'runoff' || candidate.in_current_runoff)
  const canRegister = election.status === 'candidate_registration' && association.captain_eligible
  const canVote = (election.status === 'voting' || election.status === 'runoff') && !election.my_vote_candidate_id

  return (
    <GameLayout title="National Team" subtitle={`${association.world} · ${association.name}`}>
      <header className="tlg-v2-page-head nt-page-head">
        <div className="tlg-v2-page-head-copy">
          <div className="tlg-v2-page-eyebrow">National association</div>
          <div className="nt-title-line">
            <CountryFlag
              countryCode={association.country_code}
              countryName={association.country_code}
              width={38}
              height={26}
            />
            <h2 className="tlg-v2-page-title">{association.name}</h2>
          </div>
          <p className="tlg-v2-page-description">{statusCopy(association.status)}</p>
        </div>

        <div className="nt-status-card">
          <span className={`nt-status nt-status-${association.status}`}>{statusLabel(association.status)}</span>
          <strong>Season {snapshot.season_number}</strong>
          <small>{association.world} national-team world</small>
        </div>
      </header>

      <div className="nt-tabs" role="tablist" aria-label="National association sections">
        {([
          ['overview', 'Overview'],
          ['members', `Members (${association.member_count})`],
          ['elections', 'Elections'],
          ['history', 'History'],
        ] as const).map(([key, label]) => (
          <button key={key} type="button" role="tab" aria-selected={tab === key} className={tab === key ? 'active' : ''} onClick={() => setTab(key)}>
            {label}
          </button>
        ))}
      </div>

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
              <Landmark size={22} />
            </header>

            <div className="nt-metric-grid">
              <div><span>Eligible members</span><strong>{association.member_count}</strong><small>Minimum {association.minimum_activation_members} for activation</small></div>
              <div><span>Current division</span><strong>{snapshot.division.label ?? 'Not assigned'}</strong><small>{snapshot.division.tier_level ? `Tier ${snapshot.division.tier_level}` : 'Competition structure ready for configuration'}</small></div>
              <div><span>Captain</span><strong>{snapshot.captain.first_name ? `${snapshot.captain.first_name} ${snapshot.captain.last_name}` : 'Not elected'}</strong><small>{snapshot.captain.season_number ? `Season ${snapshot.captain.season_number}` : electionStageLabel(election.status)}</small></div>
              <div><span>Association treasury</span><strong>{snapshot.treasury_balance.toLocaleString()} coins</strong><small>Community institution · no user owner</small></div>
            </div>
          </section>

          {association.activated_game_day === null ? (
            <section className="tlg-v2-panel nt-fund-card">
              <header>
                <div>
                  <span>ACTIVATION FUND</span>
                  <h3>{Number(activationFund.contributed ?? 0)} / {Number(activationFund.target ?? snapshot.rules.activation_cost)} coins</h3>
                </div>
                <Coins size={22} />
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
                <CalendarClock size={22} />
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
                  <div><strong>Association is currently covered</strong><span>The next 30-coin community renewal fund opens automatically before the following national-team season.</span></div>
                </div>
              )}

              <p className="nt-rule-note">
                If renewal fails, the association keeps its history but loses its sporting place. A later return enters through the lowest active regional tier.
              </p>
            </section>
          )}

          <section className="tlg-v2-panel nt-rules-card">
            <header><div><span>GOVERNANCE RULES</span><h3>Community, not ownership</h3></div><ShieldCheck size={22} /></header>
            <div className="nt-rule-list">
              <div><strong>1 member = 1 vote</strong><span>Donation amount never changes voting power.</span></div>
              <div><strong>Founding status is cosmetic</strong><span>The activation initiator receives no permanent control.</span></div>
              <div><strong>Captain is elected each season</strong><span>Manifestos, voting and runoff ties are handled by the game clock.</span></div>
              <div><strong>Playing captain uses a normal squad place</strong><span>Captaincy never guarantees selection or protects a player from fatigue/calendar rules.</span></div>
            </div>
          </section>

          <section className="tlg-v2-panel nt-contribution-history">
            <header><div><span>YOUR SUPPORT</span><h3>Personal contribution history</h3></div><Coins size={22} /></header>
            <strong className="nt-big-number">{snapshot.my_total_contributions.toLocaleString()}</strong>
            <span>coins contributed across activation and renewal funds</span>
            <small>Recognition only — this total carries no governance weight.</small>
          </section>
        </div>
      )}

      {tab === 'members' && (
        <section className="tlg-v2-panel nt-members-panel">
          <header className="nt-section-header">
            <div><span>ASSOCIATION MEMBERSHIP</span><h3>{association.member_count} eligible player{association.member_count === 1 ? '' : 's'}</h3></div>
            <UsersRound size={22} />
          </header>

          <p className="nt-section-copy">
            Membership means national eligibility. It does not mean automatic selection for a fixture or squad.
          </p>

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
              <Vote size={22} />
            </header>

            {!election.id ? (
              <div className="nt-placeholder">
                <Vote size={20} />
                <div>
                  <strong>No election scheduled yet</strong>
                  <span>The first election opens automatically when the association activates. A new election is created for each season.</span>
                </div>
              </div>
            ) : (
              <>
                <div className="nt-election-meta">
                  <div><span>Season</span><strong>{election.season_number}</strong></div>
                  <div><span>Round</span><strong>{election.current_round ?? 1}</strong></div>
                  <div><span>Voting rule</span><strong>1 member · 1 vote</strong></div>
                </div>

                {canRegister && (
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

                <div className="nt-candidates">
                  {candidates.length === 0 ? (
                    <div className="nt-placeholder">No candidates registered yet.</div>
                  ) : candidates.map((candidate) => (
                    <article key={candidate.candidate_id} className={candidate.candidate_id === election.winning_candidate_id ? 'winner' : ''}>
                      <header>
                        <div>
                          <span>{candidate.candidate_id === election.winning_candidate_id ? 'ELECTED CAPTAIN' : election.status === 'runoff' ? 'RUNOFF CANDIDATE' : 'CANDIDATE'}</span>
                          <strong>{candidate.first_name} {candidate.last_name}</strong>
                        </div>
                        {candidate.candidate_id === election.winning_candidate_id && <Crown size={18} />}
                      </header>
                      <p>{candidate.manifesto}</p>
                      <footer>
                        {candidate.vote_total !== null && <span>{candidate.vote_total} vote{candidate.vote_total === 1 ? '' : 's'}</span>}
                        {canVote && (
                          <button type="button" disabled={working} onClick={() => void castVote(candidate.candidate_id)}>
                            Vote
                          </button>
                        )}
                        {election.my_vote_candidate_id === candidate.candidate_id && <strong>Your vote</strong>}
                      </footer>
                    </article>
                  ))}
                </div>
              </>
            )}
          </section>

          <aside className="tlg-v2-panel nt-election-rules">
            <span>ELECTION PRINCIPLES</span>
            <h3>No pay-to-govern</h3>
            <ul>
              <li>Every active member receives exactly one vote.</li>
              <li>Activation and renewal donations never create extra votes.</li>
              <li>Candidate manifestos are required.</li>
              <li>Tied leaders move to a runoff instead of random selection.</li>
              <li>The captain may be a player but receives no automatic squad position.</li>
            </ul>
          </aside>
        </div>
      )}

      {tab === 'history' && (
        <section className="tlg-v2-panel nt-history-panel">
          <header className="nt-section-header">
            <div><span>ASSOCIATION HISTORY</span><h3>Permanent national record</h3></div>
            <Landmark size={22} />
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
