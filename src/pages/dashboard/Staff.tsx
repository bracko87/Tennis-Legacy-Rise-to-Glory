import { useEffect, useMemo, useState } from 'react'

import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import {
  contractWeeklySalary,
  type StaffCandidate,
  type StaffContract,
  type StaffQuality,
  type StaffRole,
  useStaff,
} from '../../hooks/useStaff'
import '../../styles/staff.css'

const ROLES: Array<{ role: StaffRole; label: string; description: string }> = [
  { role: 'head_coach', label: 'Head Coach', description: 'Technical development, tactics and match preparation.' },
  { role: 'fitness_coach', label: 'Fitness Coach', description: 'Physical development, conditioning and workload control.' },
  { role: 'physiotherapist', label: 'Physiotherapist', description: 'Fatigue recovery, injury prevention and rehabilitation.' },
  { role: 'sports_psychologist', label: 'Sports Psychologist', description: 'Morale, confidence, focus and pressure management.' },
  { role: 'performance_analyst', label: 'Performance Analyst', description: 'Opponent estimates, tactical analysis and match preparation.' },
  { role: 'agent_manager', label: 'Agent / Manager', description: 'Negotiation, sponsorship network and career management.' },
]

const QUALITY_OPTIONS: Array<{ value: StaffQuality | ''; label: string }> = [
  { value: '', label: 'All quality levels' },
  { value: 'developing', label: 'Developing' },
  { value: 'professional', label: 'Professional' },
  { value: 'advanced', label: 'Advanced' },
  { value: 'elite', label: 'Elite' },
  { value: 'world_class', label: 'World Class' },
]

const ATTRIBUTE_LABELS: Record<string, string> = {
  technical_coaching: 'Technical Coaching', tactical_knowledge: 'Tactical Knowledge', player_development: 'Player Development', motivation: 'Motivation',
  conditioning: 'Conditioning', physical_development: 'Physical Development', workload_management: 'Workload Management', recovery_knowledge: 'Recovery Knowledge',
  recovery: 'Recovery', injury_prevention: 'Injury Prevention', rehabilitation: 'Rehabilitation', treatment: 'Treatment',
  morale: 'Morale', confidence: 'Confidence', focus: 'Focus', pressure_management: 'Pressure Management',
  opponent_analysis: 'Opponent Analysis', tactical_analysis: 'Tactical Analysis', match_preparation: 'Match Preparation', scouting: 'Scouting',
  negotiation: 'Negotiation', sponsorship_network: 'Sponsorship Network', commercial_reputation: 'Commercial Reputation', career_management: 'Career Management',
}

function pct(multiplier: number) {
  return `${Math.max(0, (multiplier - 1) * 100).toFixed(1)}%`
}

function roleEffect(role: StaffRole, effects: NonNullable<ReturnType<typeof useStaff>['dashboard']>['effects']) {
  switch (role) {
    case 'head_coach': return `Technical training +${pct(effects.technical_training_multiplier)} · camps +${pct(effects.technical_camp_multiplier)}`
    case 'fitness_coach': return `Physical training +${pct(effects.physical_training_multiplier)} · fatigue −${(effects.training_fatigue_reduction * 100).toFixed(1)}%`
    case 'physiotherapist': return `Recovery +${pct(effects.recovery_multiplier)} · injury risk −${(effects.injury_prevention_reduction * 100).toFixed(1)}%`
    case 'sports_psychologist': return `Morale +${pct(effects.morale_recovery_multiplier)} · Focus +${pct(effects.focus_recovery_multiplier)}`
    case 'performance_analyst': return `Opponent estimates ±${effects.scouting_margin} · match preparation +${pct(effects.analyst_match_preparation_multiplier)}`
    case 'agent_manager': return `Sponsorship +${pct(effects.sponsorship_multiplier)} · negotiation +${pct(effects.negotiation_multiplier)}`
  }
}

function StaffIdentity({ staff }: { staff: StaffCandidate }) {
  return (
    <div className="tlg-staff-identity">
      <CountryFlag countryCode={staff.country_code} countryName={staff.country_code} width={24} height={16} />
      <div><strong>{staff.first_name} {staff.last_name}</strong><span>{staff.country_code} · {staff.specialty}</span></div>
    </div>
  )
}

function AttributeGrid({ staff }: { staff: StaffCandidate }) {
  return (
    <div className="tlg-staff-attributes">
      {Object.entries(staff.attributes).map(([key, value]) => (
        <div key={key}>
          <div><span>{ATTRIBUTE_LABELS[key] ?? key}</span><strong>{value}</strong></div>
          <div className="bar"><i style={{ width: `${value}%` }} /></div>
        </div>
      ))}
    </div>
  )
}

export default function StaffPage() {
  const { dashboard, market, loading, marketLoading, saving, error, loadMarket, hireStaff, terminateContract } = useStaff()
  const [view, setView] = useState<'team' | 'market'>('team')
  const [role, setRole] = useState<StaffRole | ''>('')
  const [quality, setQuality] = useState<StaffQuality | ''>('')
  const [country, setCountry] = useState('')
  const [maxSalary, setMaxSalary] = useState(15000)
  const [page, setPage] = useState(0)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [duration, setDuration] = useState<13 | 26 | 52>(26)
  const [message, setMessage] = useState<string | null>(null)

  useEffect(() => {
    if (view !== 'market') return
    void loadMarket({ role, qualityTier: quality, countryCode: country, maxWeeklySalary: maxSalary, offset: page * 25, limit: 25 })
  }, [view, role, quality, country, maxSalary, page, loadMarket])

  useEffect(() => setPage(0), [role, quality, country, maxSalary])

  useEffect(() => {
    if (!market.items.some((item) => item.id === selectedId)) setSelectedId(market.items[0]?.id ?? null)
  }, [market.items, selectedId])

  const selected = market.items.find((item) => item.id === selectedId) ?? market.items[0] ?? null
  const contractsByRole = useMemo(() => new Map((dashboard?.contracts ?? []).map((contract) => [contract.role, contract])), [dashboard?.contracts])
  const pageCount = Math.max(1, Math.ceil(market.total / 25))

  async function handleHire() {
    if (!selected) return
    setMessage(null)
    const result = await hireStaff(selected.id, duration)
    if (!result) return
    setMessage(`${selected.first_name} ${selected.last_name} has joined your team.`)
    await loadMarket({ role, qualityTier: quality, countryCode: country, maxWeeklySalary: maxSalary, offset: page * 25, limit: 25 })
    setView('team')
  }

  async function handleTerminate(contract: StaffContract) {
    if (!window.confirm(`Terminate ${contract.staff.first_name} ${contract.staff.last_name}'s contract? An early-termination fee of up to four weekly salaries is recorded.`)) return
    setMessage(null)
    const result = await terminateContract(contract.contract_id)
    if (result) setMessage(`${contract.staff.first_name} ${contract.staff.last_name}'s contract has been terminated.`)
  }

  const roleOccupied = selected ? contractsByRole.has(selected.role) : false
  const rankingBlocked = Boolean(selected?.required_rank_position && dashboard && dashboard.rank_position > selected.required_rank_position)
  const financeBlocked = Boolean(selected && dashboard?.finance.is_live && dashboard.finance.balance !== null && dashboard.finance.balance < selected.signing_fee)
  const weeklyOffer = selected ? contractWeeklySalary(selected.base_weekly_salary, duration) : 0
  const contractTotal = selected ? selected.signing_fee + weeklyOffer * duration : 0

  return (
    <GameLayout title="Staff" subtitle="Build the team around your professional player">
      <div className="tlg-staff-page">
        <header className="tlg-staff-page-head">
          <div>
            <span>CAREER SUPPORT TEAM</span>
            <h1>Staff</h1>
            <p>Hire specialists from the shared worldwide market. Staff improve development, recovery, analysis and career management without bypassing the game's normal progression limits.</p>
          </div>
          <div className="tlg-staff-tabs">
            <button type="button" className={view === 'team' ? 'active' : ''} onClick={() => setView('team')}>My Staff</button>
            <button type="button" className={view === 'market' ? 'active' : ''} onClick={() => setView('market')}>Staff Market</button>
          </div>
        </header>

        {error && <div className="tlg-staff-alert error">{error}</div>}
        {message && <div className="tlg-staff-alert">{message}</div>}

        {loading && !dashboard ? <div className="tlg-staff-loading">Loading staff team…</div> : dashboard && (
          <>
            <section className="tlg-staff-summary">
              <div><span>EMPLOYED</span><strong>{dashboard.employed_count} / {dashboard.max_staff}</strong><small>One active person per role</small></div>
              <div><span>WEEKLY STAFF COST</span><strong>${dashboard.weekly_cost.toLocaleString()}</strong><small>Contracted weekly salaries</small></div>
              <div><span>EXPIRING SOON</span><strong>{dashboard.contracts_expiring_4_weeks}</strong><small>Contracts with ≤4 weeks left</small></div>
              <div><span>WORLD RANK</span><strong>#{dashboard.rank_position}</strong><small>Used for elite staff eligibility</small></div>
            </section>

            {!dashboard.finance.is_live && (
              <div className="tlg-staff-finance-note"><strong>Career finance bridge:</strong> salaries, signing fees and termination fees are calculated and recorded now. They are not deducted from Premium Coins. Automatic affordability enforcement activates when the Career Finance balance goes live.</div>
            )}

            {view === 'team' ? (
              <section className="tlg-staff-team-grid">
                {ROLES.map((item) => {
                  const contract = contractsByRole.get(item.role)
                  return (
                    <article className={`tlg-staff-role-card ${contract ? 'filled' : 'empty'}`} key={item.role}>
                      <header><div><span>{item.label.toUpperCase()}</span><p>{item.description}</p></div>{contract && <b>{contract.staff.overall_rating}</b>}</header>
                      {contract ? (
                        <>
                          <StaffIdentity staff={contract.staff} />
                          <div className="tlg-staff-role-meta"><span>{contract.staff.quality_label}</span><span>{contract.staff.specialty}</span></div>
                          <AttributeGrid staff={contract.staff} />
                          <div className="tlg-staff-active-effect"><span>CURRENT EFFECT</span><strong>{roleEffect(item.role, dashboard.effects)}</strong></div>
                          <div className="tlg-staff-contract-line"><span>${contract.weekly_salary.toLocaleString()} / week</span><strong>{contract.weeks_remaining} weeks remaining</strong></div>
                          <button type="button" className="secondary danger" disabled={saving} onClick={() => handleTerminate(contract)}>End Contract</button>
                        </>
                      ) : (
                        <div className="tlg-staff-empty-role">
                          <strong>No {item.label.toLowerCase()} hired</strong>
                          <p>This position currently gives no staff bonus.</p>
                          <button type="button" onClick={() => { setRole(item.role); setView('market') }}>Hire {item.label}</button>
                        </div>
                      )}
                    </article>
                  )
                })}
              </section>
            ) : (
              <>
                <section className="tlg-staff-market-filters">
                  <label><span>Role</span><select value={role} onChange={(event) => setRole(event.target.value as StaffRole | '')}><option value="">All staff roles</option>{ROLES.map((item) => <option key={item.role} value={item.role}>{item.label}</option>)}</select></label>
                  <label><span>Quality</span><select value={quality} onChange={(event) => setQuality(event.target.value as StaffQuality | '')}>{QUALITY_OPTIONS.map((item) => <option key={item.value || 'all'} value={item.value}>{item.label}</option>)}</select></label>
                  <label><span>Country code</span><input value={country} maxLength={2} placeholder="All" onChange={(event) => setCountry(event.target.value.toUpperCase())} /></label>
                  <label className="salary"><span>Max base salary: <strong>${maxSalary.toLocaleString()}</strong></span><input type="range" min="300" max="15000" step="100" value={maxSalary} onChange={(event) => setMaxSalary(Number(event.target.value))} /></label>
                </section>

                <div className="tlg-staff-market-layout">
                  <section className="tlg-staff-market-list-panel">
                    <header><div><span>AVAILABLE WORLDWIDE</span><h2>Staff Market</h2></div><small>{market.total.toLocaleString()} candidates · Page {page + 1}/{pageCount}</small></header>
                    {marketLoading ? <div className="tlg-staff-loading">Loading candidates…</div> : (
                      <div className="tlg-staff-market-list">
                        {market.items.map((candidate) => (
                          <button type="button" key={candidate.id} className={selected?.id === candidate.id ? 'selected' : ''} onClick={() => setSelectedId(candidate.id)}>
                            <StaffIdentity staff={candidate} />
                            <div className="quality"><strong>{candidate.overall_rating}</strong><span>{candidate.quality_label}</span></div>
                            <div className="cost"><strong>${candidate.base_weekly_salary.toLocaleString()}</strong><span>/ week base</span></div>
                          </button>
                        ))}
                        {market.items.length === 0 && <div className="tlg-staff-loading">No candidates match these filters.</div>}
                      </div>
                    )}
                    <footer><button type="button" disabled={page === 0 || marketLoading} onClick={() => setPage((value) => Math.max(0, value - 1))}>Previous</button><span>{page + 1} / {pageCount}</span><button type="button" disabled={page + 1 >= pageCount || marketLoading} onClick={() => setPage((value) => value + 1)}>Next</button></footer>
                  </section>

                  <aside className="tlg-staff-candidate-detail">
                    {selected ? (
                      <>
                        <div className="tlg-staff-detail-head">
                          <div><span>{selected.role_label.toUpperCase()}</span><h2>{selected.first_name} {selected.last_name}</h2><div><CountryFlag countryCode={selected.country_code} countryName={selected.country_code} width={26} height={17} /> {selected.country_code}</div></div>
                          <div className="rating"><strong>{selected.overall_rating}</strong><span>{selected.quality_label}</span></div>
                        </div>
                        <div className="tlg-staff-specialty"><span>SPECIALTY</span><strong>{selected.specialty}</strong></div>
                        <AttributeGrid staff={selected} />
                        <div className="tlg-staff-eligibility"><div><span>RANKING REQUIREMENT</span><strong>{selected.required_rank_position ? `Top ${selected.required_rank_position}` : 'Open to all players'}</strong></div><div><span>SIGNING FEE</span><strong>${selected.signing_fee.toLocaleString()}</strong></div></div>
                        <section className="tlg-staff-contract-options">
                          <header><span>CONTRACT</span><h3>Choose contract length</h3></header>
                          <div>{([13, 26, 52] as const).map((weeks) => { const salary = contractWeeklySalary(selected.base_weekly_salary, weeks); return <button type="button" key={weeks} className={duration === weeks ? 'selected' : ''} onClick={() => setDuration(weeks)}><strong>{weeks} weeks</strong><span>${salary.toLocaleString()} / week</span><small>{weeks === 13 ? 'Base rate' : weeks === 26 ? '7% weekly discount' : '14% weekly discount'}</small></button> })}</div>
                        </section>
                        <div className="tlg-staff-offer-total"><div><span>Weekly salary</span><strong>${weeklyOffer.toLocaleString()}</strong></div><div><span>Signing fee</span><strong>${selected.signing_fee.toLocaleString()}</strong></div><div><span>Full contract commitment</span><strong>${contractTotal.toLocaleString()}</strong></div></div>
                        {roleOccupied && <div className="tlg-staff-blocked">You already employ a {selected.role_label.toLowerCase()}. End that contract before hiring a replacement.</div>}
                        {rankingBlocked && <div className="tlg-staff-blocked">This candidate requires a Top {selected.required_rank_position} world ranking.</div>}
                        {financeBlocked && <div className="tlg-staff-blocked">Your career balance cannot cover this signing fee.</div>}
                        <button type="button" className="tlg-staff-hire" disabled={saving || roleOccupied || rankingBlocked || financeBlocked} onClick={handleHire}>{saving ? 'Hiring…' : `Hire ${selected.first_name} · ${duration} weeks`}</button>
                      </>
                    ) : <div className="tlg-staff-loading">Select a candidate to see the full profile.</div>}
                  </aside>
                </div>
              </>
            )}
          </>
        )}
      </div>
    </GameLayout>
  )
}
