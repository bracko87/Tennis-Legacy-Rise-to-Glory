import { useEffect, useState } from 'react'

import CountryFlag from '../../components/common/CountryFlag'
import GameConfirmDialog from '../../components/common/GameConfirmDialog'
import GameLayout from '../../components/layout/GameLayout'
import StaffTeamRoles from '../../components/staff/StaffTeamRoles'
import {
  contractWeeklySalary,
  type StaffCandidate,
  type StaffContract,
  type StaffNegotiationQuote,
  type StaffQuality,
  type StaffRole,
  type StaffTerminationQuote,
  useStaff,
} from '../../hooks/useStaff'
import '../../styles/staff.css'
import '../../styles/staff-interactions.css'
import '../../styles/shared-segmented-tabs.css'

const ROLES: Array<{ role: StaffRole; label: string; description: string }> = [
  { role: 'head_coach', label: 'Head Coach', description: 'Technical development, tactics and match preparation.' },
  { role: 'fitness_coach', label: 'Fitness Coach', description: 'Physical development, conditioning and workload control.' },
  { role: 'physiotherapist', label: 'Physiotherapist', description: 'Fatigue recovery, injury prevention and rehabilitation.' },
  { role: 'sports_psychologist', label: 'Sports Psychologist', description: 'Morale, confidence, focus and pressure management.' },
  { role: 'performance_analyst', label: 'Performance Analyst', description: 'Opponent estimates, tactical analysis and match preparation.' },
  { role: 'agent_manager', label: 'Career Manager', description: 'Sponsorship, commercial representation and career management.' },
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

interface PendingStaffContract {
  negotiation_id: string
  staff_id: string
  staff_name: string
  duration_weeks: 13 | 26 | 52
  weekly_salary: number
  signing_fee: number
  salary_total: number
  total_commitment: number
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
        <div key={key} title={ATTRIBUTE_LABELS[key] ?? key}>
          <div><span>{ATTRIBUTE_LABELS[key] ?? key}</span><strong>{value}</strong></div>
          <div className="bar"><i style={{ width: `${value}%` }} /></div>
        </div>
      ))}
    </div>
  )
}

function pendingContractFromQuote(selected: StaffCandidate, quote: StaffNegotiationQuote): PendingStaffContract | null {
  if (!quote.pending_confirmation || !quote.negotiation_id || !quote.duration_weeks || !quote.offered_weekly_salary) return null
  const signingFee = quote.signing_fee ?? selected.signing_fee
  const salaryTotal = quote.salary_total ?? quote.offered_weekly_salary * quote.duration_weeks
  return {
    negotiation_id: quote.negotiation_id,
    staff_id: selected.id,
    staff_name: `${selected.first_name} ${selected.last_name}`,
    duration_weeks: quote.duration_weeks,
    weekly_salary: quote.offered_weekly_salary,
    signing_fee: signingFee,
    salary_total: salaryTotal,
    total_commitment: quote.total_commitment ?? signingFee + salaryTotal,
  }
}

export default function StaffPage() {
  const {
    dashboard, market, loading, marketLoading, saving, error,
    loadStaffProfile, loadMarket, quoteNegotiation, negotiateStaff, confirmStaffOffer,
    quoteStaffTermination, terminateContract,
  } = useStaff()
  const [view, setView] = useState<'team' | 'market'>('team')
  const [role, setRole] = useState<StaffRole | ''>('')
  const [quality, setQuality] = useState<StaffQuality | ''>('')
  const [country, setCountry] = useState('')
  const [maxSalary, setMaxSalary] = useState(4000)
  const [page, setPage] = useState(0)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [duration, setDuration] = useState<13 | 26 | 52>(26)
  const [salaryMultiplier, setSalaryMultiplier] = useState(1)
  const [negotiationQuote, setNegotiationQuote] = useState<StaffNegotiationQuote | null>(null)
  const [quoteLoading, setQuoteLoading] = useState(false)
  const [quoteError, setQuoteError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [offerNotice, setOfferNotice] = useState<{ tone: 'error' | 'success'; text: string } | null>(null)
  const [pendingContract, setPendingContract] = useState<PendingStaffContract | null>(null)
  const [hireConfirmOpen, setHireConfirmOpen] = useState(false)
  const [terminationTarget, setTerminationTarget] = useState<StaffContract | null>(null)
  const [terminationQuote, setTerminationQuote] = useState<StaffTerminationQuote | null>(null)
  const [terminationLoading, setTerminationLoading] = useState(false)

  useEffect(() => {
    if (view !== 'market') return
    void loadMarket({ role, qualityTier: quality, countryCode: country, maxWeeklySalary: maxSalary, offset: page * 25, limit: 25 })
  }, [view, role, quality, country, maxSalary, page, loadMarket])

  useEffect(() => setPage(0), [role, quality, country, maxSalary])

  useEffect(() => {
    if (!market.items.some((item) => item.id === selectedId)) setSelectedId(market.items[0]?.id ?? null)
  }, [market.items, selectedId])

  useEffect(() => {
    setSalaryMultiplier(1)
    setNegotiationQuote(null)
    setQuoteError(null)
    setOfferNotice(null)
    setPendingContract(null)
    setHireConfirmOpen(false)
  }, [selectedId])

  const selected = market.items.find((item) => item.id === selectedId) ?? market.items[0] ?? null
  const pageCount = Math.max(1, Math.ceil(market.total / 25))

  useEffect(() => {
    let cancelled = false
    if (view !== 'market' || !selected) {
      setNegotiationQuote(null)
      return
    }
    setQuoteLoading(true)
    setQuoteError(null)
    void quoteNegotiation(selected.id, duration, salaryMultiplier)
      .then(({ quote, error: nextError }) => {
        if (cancelled) return
        if (nextError) {
          setNegotiationQuote(null)
          setQuoteError(nextError)
          return
        }
        if (quote?.pending_confirmation) {
          const pending = pendingContractFromQuote(selected, quote)
          if (pending) setPendingContract(pending)
          if (quote.duration_weeks && quote.duration_weeks !== duration) setDuration(quote.duration_weeks)
        } else if (quote?.available && quote.minimum_next_multiplier && salaryMultiplier < quote.minimum_next_multiplier) {
          setSalaryMultiplier(quote.minimum_next_multiplier)
          return
        }
        setNegotiationQuote(quote)
      })
      .finally(() => { if (!cancelled) setQuoteLoading(false) })
    return () => { cancelled = true }
  }, [view, selected, duration, salaryMultiplier, quoteNegotiation])

  async function refreshNegotiationQuote(multiplier = salaryMultiplier) {
    if (!selected) return
    setQuoteLoading(true)
    const { quote, error: nextError } = await quoteNegotiation(selected.id, duration, multiplier)
    setNegotiationQuote(quote)
    setQuoteError(nextError)
    if (quote?.pending_confirmation) {
      const pending = pendingContractFromQuote(selected, quote)
      if (pending) setPendingContract(pending)
    }
    setQuoteLoading(false)
  }

  async function handleOffer() {
    if (!selected) return
    if (pendingContract || negotiationQuote?.pending_confirmation) {
      const pending = pendingContract ?? (negotiationQuote ? pendingContractFromQuote(selected, negotiationQuote) : null)
      if (pending) {
        setPendingContract(pending)
        setHireConfirmOpen(true)
      }
      return
    }
    if (!negotiationQuote?.available) return

    setMessage(null)
    setOfferNotice(null)
    const result = await negotiateStaff(selected.id, duration, salaryMultiplier)
    if (!result) return

    if (result.accepted && result.negotiation_id && result.duration_weeks && result.offered_weekly_salary) {
      const signingFee = result.signing_fee ?? selected.signing_fee
      const salaryTotal = result.salary_total ?? result.offered_weekly_salary * result.duration_weeks
      setPendingContract({
        negotiation_id: result.negotiation_id,
        staff_id: selected.id,
        staff_name: `${selected.first_name} ${selected.last_name}`,
        duration_weeks: result.duration_weeks,
        weekly_salary: result.offered_weekly_salary,
        signing_fee: signingFee,
        salary_total: salaryTotal,
        total_commitment: result.total_commitment ?? signingFee + salaryTotal,
      })
      setOfferNotice({ tone: 'success', text: `${selected.first_name} accepted the offer. Review the contract before the hire becomes official.` })
      setHireConfirmOpen(true)
      await refreshNegotiationQuote(salaryMultiplier)
      return
    }

    if (result.remaining_rounds && result.remaining_rounds > 0) {
      const nextMultiplier = result.minimum_next_multiplier ?? Math.min(2, salaryMultiplier + .1)
      setSalaryMultiplier(nextMultiplier)
      setOfferNotice({
        tone: 'error',
        text: `${selected.first_name} ${selected.last_name} rejected the offer. ${result.remaining_rounds} negotiation round${result.remaining_rounds === 1 ? '' : 's'} remain. Improve the salary offer and try again.`,
      })
      await refreshNegotiationQuote(nextMultiplier)
    } else {
      setOfferNotice({
        tone: 'error',
        text: `${selected.first_name} ${selected.last_name} rejected the final offer. Negotiations are closed for 14 in-game days.`,
      })
      await refreshNegotiationQuote(salaryMultiplier)
    }
  }

  async function handleConfirmHire() {
    if (!pendingContract) return
    const result = await confirmStaffOffer(pendingContract.negotiation_id)
    if (!result) return
    setHireConfirmOpen(false)
    setOfferNotice(null)
    setMessage(`${pendingContract.staff_name} has joined your team.`)
    setPendingContract(null)
    await loadMarket({ role, qualityTier: quality, countryCode: country, maxWeeklySalary: maxSalary, offset: page * 25, limit: 25 })
    setView('team')
  }

  async function handleTerminateRequest(contract: StaffContract) {
    setMessage(null)
    setTerminationTarget(contract)
    setTerminationQuote(null)
    setTerminationLoading(true)
    const { quote, error: quoteError } = await quoteStaffTermination(contract.contract_id)
    setTerminationLoading(false)
    if (quoteError || !quote) {
      setTerminationTarget(null)
      setMessage(quoteError ?? 'Could not calculate the termination cost.')
      return
    }
    setTerminationQuote(quote)
  }

  async function handleConfirmTermination() {
    if (!terminationTarget || !terminationQuote) return
    const staffName = `${terminationTarget.staff.first_name} ${terminationTarget.staff.last_name}`
    const result = await terminateContract(terminationTarget.contract_id)
    if (!result) return
    setTerminationTarget(null)
    setTerminationQuote(null)
    setMessage(`${staffName}'s contract has been terminated.`)
  }

  const pendingConfirmation = Boolean(pendingContract || negotiationQuote?.pending_confirmation)
  const roleOccupied = selected ? dashboard?.contracts.some((contract) => contract.role === selected.role) ?? false : false
  const effectiveSigningFee = pendingContract?.signing_fee ?? negotiationQuote?.signing_fee ?? selected?.signing_fee ?? 0
  const financeBlocked = Boolean(selected && dashboard?.finance.is_live && dashboard.finance.balance !== null && dashboard.finance.balance < effectiveSigningFee)
  const baseContractSalary = selected ? contractWeeklySalary(selected.base_weekly_salary, duration) : 0
  const weeklyOffer = pendingContract?.weekly_salary ?? negotiationQuote?.offered_weekly_salary ?? Math.round((baseContractSalary * salaryMultiplier) / 10) * 10
  const effectiveDuration = pendingContract?.duration_weeks ?? negotiationQuote?.duration_weeks ?? duration
  const salaryTotal = pendingContract?.salary_total ?? negotiationQuote?.salary_total ?? weeklyOffer * effectiveDuration
  const contractTotal = pendingContract?.total_commitment ?? negotiationQuote?.total_commitment ?? effectiveSigningFee + salaryTotal
  const acceptanceChance = negotiationQuote?.acceptance_chance ?? 0
  const hardRefusal = Boolean(negotiationQuote?.hard_refusal)
  const negotiationUnavailable = negotiationQuote ? !negotiationQuote.available && !pendingConfirmation : false
  const sliderMin = Math.max(100, Math.round((negotiationQuote?.minimum_next_multiplier ?? 1) * 100))

  return (
    <GameLayout title="Staff" subtitle="Build the team around your professional player">
      <div className="tlg-staff-page">
        <header className="tlg-staff-page-head">
          <div>
            <span>CAREER SUPPORT TEAM</span>
            <h1>Staff</h1>
            <p>Build a six-role support team with transparent, capped career effects. Staff strengthen development, recovery, analysis and commercial management without replacing player attributes or career decisions.</p>
          </div>
          <div className="tlg-staff-tabs tlg-standard-tabs">
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
              <div><span>STAFF EFFECT MODEL</span><strong>Capped & transparent</strong><small>Current and maximum effects shown per role</small></div>
            </section>

            {!dashboard.finance.is_live && (
              <div className="tlg-staff-finance-note"><strong>Career finance bridge:</strong> salaries, signing fees and termination fees are calculated and recorded now. They are not deducted from Premium Coins. Automatic affordability enforcement activates when the Career Finance balance goes live.</div>
            )}

            {view === 'team' ? (
              <StaffTeamRoles
                dashboard={dashboard}
                saving={saving || terminationLoading}
                loadProfile={loadStaffProfile}
                onHire={(nextRole) => { setRole(nextRole); setView('market') }}
                onTerminate={(contract) => { void handleTerminateRequest(contract) }}
              />
            ) : (
              <>
                <section className="tlg-staff-market-filters">
                  <label><span>Role</span><select value={role} onChange={(event) => setRole(event.target.value as StaffRole | '')}><option value="">All staff roles</option>{ROLES.map((item) => <option key={item.role} value={item.role}>{item.label}</option>)}</select></label>
                  <label><span>Quality</span><select value={quality} onChange={(event) => setQuality(event.target.value as StaffQuality | '')}>{QUALITY_OPTIONS.map((item) => <option key={item.value || 'all'} value={item.value}>{item.label}</option>)}</select></label>
                  <label><span>Country code</span><input value={country} maxLength={2} placeholder="All" onChange={(event) => setCountry(event.target.value.toUpperCase())} /></label>
                  <label className="salary"><span>Max base salary: <strong>${maxSalary.toLocaleString()}</strong></span><input type="range" min="100" max="4000" step="50" value={maxSalary} onChange={(event) => setMaxSalary(Number(event.target.value))} /></label>
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
                        <div className="tlg-staff-eligibility"><div><span>YOUR WORLD RANK</span><strong>#{dashboard.rank_position}</strong></div><div><span>SIGNING FEE</span><strong>${effectiveSigningFee.toLocaleString()}</strong></div></div>

                        <section className="tlg-staff-contract-options">
                          <header><span>CONTRACT</span><h3>Choose contract length</h3></header>
                          <div>{([13, 26, 52] as const).map((weeks) => { const salary = contractWeeklySalary(selected.base_weekly_salary, weeks); return <button type="button" key={weeks} disabled={pendingConfirmation} className={effectiveDuration === weeks ? 'selected' : ''} onClick={() => setDuration(weeks)}><strong>{weeks} weeks</strong><span>${salary.toLocaleString()} / week</span><small>{weeks === 13 ? 'Base rate' : weeks === 26 ? '7% weekly discount' : '14% weekly discount'}</small></button> })}</div>
                        </section>

                        <section className="tlg-staff-salary-offer">
                          <header><div><span>SALARY OFFER</span><h3>{pendingConfirmation ? 'Accepted terms' : 'Improve the proposal'}</h3></div><strong>{Math.round((pendingContract ? (pendingContract.weekly_salary / Math.max(1, contractWeeklySalary(selected.base_weekly_salary, pendingContract.duration_weeks))) : salaryMultiplier) * 100)}%</strong></header>
                          <input type="range" min={sliderMin} max="200" step="5" disabled={pendingConfirmation} value={Math.round(salaryMultiplier * 100)} onChange={(event) => setSalaryMultiplier(Number(event.target.value) / 100)} />
                          <div className="scale"><span>{sliderMin}% minimum</span><span>200% maximum</span></div>
                          <p>{pendingConfirmation ? 'The staff member has accepted these terms. Review the final contract before confirming the hire.' : 'Higher salary increases willingness, but sporting reputation still matters. Money cannot persuade a World Class staff member to join a player outside the Top 500.'}</p>
                        </section>

                        <section className={`tlg-staff-chance ${hardRefusal ? 'refusal' : ''}`}>
                          <header>
                            <div><span>ACCEPTANCE CHANCE</span><h3>{pendingConfirmation ? 'Accepted' : quoteLoading ? 'Calculating…' : negotiationQuote?.chance_label ?? 'Unavailable'}</h3></div>
                            <strong>{pendingConfirmation ? '✓' : quoteLoading ? '—' : `${acceptanceChance}%`}</strong>
                          </header>
                          <div className="chance-track"><i style={{ width: `${pendingConfirmation ? 100 : acceptanceChance}%` }} /></div>
                          {negotiationQuote?.available && <p>{negotiationQuote.explanation} · Round {negotiationQuote.round_number ?? 1} of {negotiationQuote.max_rounds ?? 3}.</p>}
                          {pendingConfirmation && <p>Your offer was accepted. The staff member is not hired until you confirm the final contract.</p>}
                          {!negotiationQuote?.available && !pendingConfirmation && negotiationQuote?.reason && <p>{negotiationQuote.reason}{negotiationQuote.cooldown_days_remaining ? ` Try again in ${negotiationQuote.cooldown_days_remaining} in-game days.` : ''}</p>}
                          {quoteError && <p>{quoteError}</p>}
                        </section>

                        <div className="tlg-staff-offer-total"><div><span>Negotiated weekly salary</span><strong>${weeklyOffer.toLocaleString()}</strong></div><div><span>Full salary over {effectiveDuration} weeks</span><strong>${salaryTotal.toLocaleString()}</strong></div><div><span>Signing fee</span><strong>${effectiveSigningFee.toLocaleString()}</strong></div><div><span>Full contract commitment</span><strong>${contractTotal.toLocaleString()}</strong></div></div>
                        {roleOccupied && <div className="tlg-staff-blocked">You already employ a {selected.role_label.toLowerCase()}. End that contract before negotiating with a replacement.</div>}
                        {financeBlocked && <div className="tlg-staff-blocked">Your career balance cannot cover this signing fee.</div>}
                        {hardRefusal && <div className="tlg-staff-blocked">This staff member will not enter negotiations at your current sporting reputation, regardless of salary.</div>}
                        {offerNotice && <div className={`tlg-staff-offer-notice ${offerNotice.tone}`}>{offerNotice.text}</div>}
                        <button type="button" className="tlg-staff-hire" disabled={saving || quoteLoading || roleOccupied || financeBlocked || hardRefusal || negotiationUnavailable || !negotiationQuote} onClick={() => void handleOffer()}>
                          {saving ? 'Processing…' : pendingConfirmation ? `Review accepted offer · ${effectiveDuration} weeks` : hardRefusal ? 'Staff will not negotiate' : `Make offer to ${selected.first_name} · ${duration} weeks`}
                        </button>
                      </>
                    ) : <div className="tlg-staff-loading">Select a candidate to see the full profile.</div>}
                  </aside>
                </div>
              </>
            )}
          </>
        )}
      </div>

      <GameConfirmDialog
        open={hireConfirmOpen && Boolean(pendingContract)}
        tone="success"
        eyebrow="Offer accepted"
        title={pendingContract ? `Confirm ${pendingContract.staff_name}'s contract` : 'Confirm staff contract'}
        message="The staff member accepted your offer. Review the complete financial commitment before making the hire official."
        detail={pendingContract ? (
          <div className="tlg-game-confirm-summary">
            <div><span>Signing fee</span><strong>${pendingContract.signing_fee.toLocaleString()}</strong></div>
            <div><span>Weekly salary</span><strong>${pendingContract.weekly_salary.toLocaleString()}</strong></div>
            <div><span>Contract length</span><strong>{pendingContract.duration_weeks} weeks</strong></div>
            <div><span>Salary over full contract</span><strong>${pendingContract.salary_total.toLocaleString()}</strong></div>
            <div className="total"><span>Total contract commitment</span><strong>${pendingContract.total_commitment.toLocaleString()}</strong></div>
          </div>
        ) : undefined}
        confirmLabel="Confirm contract"
        cancelLabel="Not now"
        busy={saving}
        onCancel={() => setHireConfirmOpen(false)}
        onConfirm={handleConfirmHire}
      />

      <GameConfirmDialog
        open={Boolean(terminationTarget && terminationQuote)}
        tone="danger"
        eyebrow="End staff contract"
        title={terminationQuote ? `Terminate ${terminationQuote.staff_name}?` : 'Terminate contract?'}
        message="Ending a staff contract early requires a settlement equal to 65% of the unpaid salary still remaining on the contract."
        detail={terminationQuote ? (
          <div className="tlg-game-confirm-summary">
            <div><span>Weekly salary</span><strong>${terminationQuote.weekly_salary.toLocaleString()}</strong></div>
            <div><span>Unpaid weeks remaining</span><strong>{terminationQuote.remaining_weeks}</strong></div>
            <div><span>Remaining salary value</span><strong>${terminationQuote.remaining_salary.toLocaleString()}</strong></div>
            <div><span>Termination settlement rate</span><strong>{terminationQuote.termination_rate}%</strong></div>
            <div className="danger total"><span>Termination fee charged now</span><strong>${terminationQuote.termination_fee.toLocaleString()}</strong></div>
          </div>
        ) : undefined}
        confirmLabel="Terminate contract"
        cancelLabel="Keep staff member"
        busy={saving}
        onCancel={() => { setTerminationTarget(null); setTerminationQuote(null) }}
        onConfirm={handleConfirmTermination}
      />
    </GameLayout>
  )
}
