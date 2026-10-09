import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useSearchParams } from 'react-router'

import CountryFlag from '../../components/common/CountryFlag'
import GameConfirmDialog from '../../components/common/GameConfirmDialog'
import GameLayout from '../../components/layout/GameLayout'
import StaffTeamRoles from '../../components/staff/StaffTeamRoles'
import { useLocalization } from '../../i18n/LocalizationProvider'
import {
  staffAttributeLabel,
  staffBackendText,
  staffChanceLabel,
  staffQualityLabel,
  staffRoleLabel,
  staffSpecialty,
} from '../../i18n/staffLocalization'
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

const ROLES: StaffRole[] = [
  'head_coach',
  'fitness_coach',
  'physiotherapist',
  'sports_psychologist',
  'performance_analyst',
  'agent_manager',
]

const QUALITY_OPTIONS: Array<StaffQuality | ''> = [
  '',
  'developing',
  'professional',
  'advanced',
  'elite',
  'world_class',
]

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
  const { t } = useTranslation()
  return (
    <div className="tlg-staff-identity">
      <CountryFlag countryCode={staff.country_code} countryName={staff.country_code} width={24} height={16} />
      <div><strong>{staff.first_name} {staff.last_name}</strong><span>{staff.country_code} · {staffSpecialty(t, staff.specialty)}</span></div>
    </div>
  )
}

function AttributeGrid({ staff }: { staff: StaffCandidate }) {
  const { t } = useTranslation()
  return (
    <div className="tlg-staff-attributes">
      {Object.entries(staff.attributes).map(([key, value]) => (
        <div key={key} title={staffAttributeLabel(t, key)}>
          <div><span>{staffAttributeLabel(t, key)}</span><strong>{value}</strong></div>
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
  const { t } = useTranslation()
  const { formatCurrency, formatNumber } = useLocalization()
  const [searchParams] = useSearchParams()
  const requestedView = searchParams.get('view')
  const {
    dashboard, market, loading, marketLoading, saving, error,
    loadStaffProfile, loadMarket, quoteNegotiation, negotiateStaff, confirmStaffOffer,
    quoteStaffTermination, terminateContract,
  } = useStaff()
  const [view, setView] = useState<'team' | 'market'>(() => requestedView === 'market' ? 'market' : 'team')
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
    if (requestedView === 'team' || requestedView === 'market') setView(requestedView)
  }, [requestedView])

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
      setOfferNotice({ tone: 'success', text: t('staffPage.notices.accepted', { name: selected.first_name }) })
      setHireConfirmOpen(true)
      await refreshNegotiationQuote(salaryMultiplier)
      return
    }

    if (result.remaining_rounds && result.remaining_rounds > 0) {
      const nextMultiplier = result.minimum_next_multiplier ?? Math.min(2, salaryMultiplier + .1)
      setSalaryMultiplier(nextMultiplier)
      setOfferNotice({
        tone: 'error',
        text: t('staffPage.notices.rejected', { name: `${selected.first_name} ${selected.last_name}`, count: result.remaining_rounds }),
      })
      await refreshNegotiationQuote(nextMultiplier)
    } else {
      setOfferNotice({
        tone: 'error',
        text: t('staffPage.notices.rejectedFinal', { name: `${selected.first_name} ${selected.last_name}` }),
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
    setMessage(t('staffPage.notices.joined', { name: pendingContract.staff_name }))
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
      setMessage(quoteError ?? t('staffPage.notices.terminationCostError'))
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
    setMessage(t('staffPage.notices.terminated', { name: staffName }))
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
    <GameLayout title={t('staffPage.title')} subtitle={t('staffPage.subtitle')}>
      <div className="tlg-staff-page">
        <header className="tlg-staff-page-head tlg-page-head-with-tabs">
          <div>
            <span>{t('staffPage.kicker')}</span>
            <h1>{t('staffPage.heading')}</h1>
            <p>{t('staffPage.intro')}</p>
          </div>

          <div className="tlg-staff-tabs tlg-standard-tabs" role="tablist" aria-label={t('staffPage.tabsAria')}>
            <button type="button" role="tab" aria-selected={view === 'team'} className={view === 'team' ? 'active' : ''} onClick={() => setView('team')}>{t('staffPage.myStaff')}</button>
            <button type="button" role="tab" aria-selected={view === 'market'} className={view === 'market' ? 'active' : ''} onClick={() => setView('market')}>{t('staffPage.market')}</button>
          </div>
        </header>

        {error && <div className="tlg-staff-alert error">{error}</div>}
        {message && <div className="tlg-staff-alert">{message}</div>}

        {loading && !dashboard ? <div className="tlg-staff-loading">{t('staffPage.loadingTeam')}</div> : dashboard && (
          <>
            <section className="tlg-staff-summary">
              <div><span>{t('staffPage.summary.employed')}</span><strong>{dashboard.employed_count} / {dashboard.max_staff}</strong><small>{t('staffPage.summary.employedNote')}</small></div>
              <div><span>{t('staffPage.summary.weeklyCost')}</span><strong>{formatCurrency(dashboard.weekly_cost, 'USD')}</strong><small>{t('staffPage.summary.weeklyCostNote')}</small></div>
              <div><span>{t('staffPage.summary.expiring')}</span><strong>{dashboard.contracts_expiring_4_weeks}</strong><small>{t('staffPage.summary.expiringNote')}</small></div>
              <div><span>{t('staffPage.summary.effectModel')}</span><strong>{t('staffPage.summary.capped')}</strong><small>{t('staffPage.summary.effectModelNote')}</small></div>
            </section>

            {!dashboard.finance.is_live && (
              <div className="tlg-staff-finance-note"><strong>{t('staffPage.financeBridgeTitle')}</strong> {t('staffPage.financeBridge')}</div>
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
                  <label><span>{t('staffPage.filters.role')}</span><select value={role} onChange={(event) => setRole(event.target.value as StaffRole | '')}><option value="">{t('staffPage.filters.allRoles')}</option>{ROLES.map((item) => <option key={item} value={item}>{staffRoleLabel(t, item)}</option>)}</select></label>
                  <label><span>{t('staffPage.filters.quality')}</span><select value={quality} onChange={(event) => setQuality(event.target.value as StaffQuality | '')}>{QUALITY_OPTIONS.map((item) => <option key={item || 'all'} value={item}>{item ? staffQualityLabel(t, item) : t('staffPage.qualities.all')}</option>)}</select></label>
                  <label><span>{t('staffPage.filters.countryCode')}</span><input value={country} maxLength={2} placeholder={t('staffPage.filters.all')} onChange={(event) => setCountry(event.target.value.toUpperCase())} /></label>
                  <label className="salary"><span>{t('staffPage.filters.maxSalary', { amount: formatCurrency(maxSalary, 'USD') })}</span><input type="range" min="100" max="4000" step="50" value={maxSalary} onChange={(event) => setMaxSalary(Number(event.target.value))} /></label>
                </section>

                <div className="tlg-staff-market-layout">
                  <section className="tlg-staff-market-list-panel">
                    <header><div><span>{t('staffPage.marketPanel.availableWorldwide')}</span><h2>{t('staffPage.marketPanel.title')}</h2></div><small>{t('staffPage.marketPanel.candidatesPage', { count: market.total, page: page + 1, pages: pageCount })}</small></header>
                    {marketLoading ? <div className="tlg-staff-loading">{t('staffPage.marketPanel.loading')}</div> : (
                      <div className="tlg-staff-market-list">
                        {market.items.map((candidate) => (
                          <button type="button" key={candidate.id} className={selected?.id === candidate.id ? 'selected' : ''} onClick={() => setSelectedId(candidate.id)}>
                            <StaffIdentity staff={candidate} />
                            <div className="quality"><strong>{candidate.overall_rating}</strong><span>{staffQualityLabel(t, candidate.quality_tier, candidate.quality_label)}</span></div>
                            <div className="cost"><strong>{formatCurrency(candidate.base_weekly_salary, 'USD')}</strong><span>{t('staffPage.marketPanel.weekBase')}</span></div>
                          </button>
                        ))}
                        {market.items.length === 0 && <div className="tlg-staff-loading">{t('staffPage.marketPanel.noCandidates')}</div>}
                      </div>
                    )}
                    <footer><button type="button" disabled={page === 0 || marketLoading} onClick={() => setPage((value) => Math.max(0, value - 1))}>{t('staffPage.marketPanel.previous')}</button><span>{page + 1} / {pageCount}</span><button type="button" disabled={page + 1 >= pageCount || marketLoading} onClick={() => setPage((value) => value + 1)}>{t('staffPage.marketPanel.next')}</button></footer>
                  </section>

                  <aside className="tlg-staff-candidate-detail">
                    {selected ? (
                      <>
                        <div className="tlg-staff-detail-head">
                          <div><span>{staffRoleLabel(t, selected.role, selected.role_label).toUpperCase()}</span><h2>{selected.first_name} {selected.last_name}</h2><div><CountryFlag countryCode={selected.country_code} countryName={selected.country_code} width={26} height={17} /> {selected.country_code}</div></div>
                          <div className="rating"><strong>{selected.overall_rating}</strong><span>{staffQualityLabel(t, selected.quality_tier, selected.quality_label)}</span></div>
                        </div>
                        <div className="tlg-staff-specialty"><span>{t('staffPage.candidate.specialty')}</span><strong>{staffSpecialty(t, selected.specialty)}</strong></div>
                        <AttributeGrid staff={selected} />
                        <div className="tlg-staff-eligibility"><div><span>{t('staffPage.candidate.worldRank')}</span><strong>#{formatNumber(dashboard.rank_position)}</strong></div><div><span>{t('staffPage.candidate.signingFee')}</span><strong>{formatCurrency(effectiveSigningFee, 'USD')}</strong></div></div>

                        <section className="tlg-staff-contract-options">
                          <header><span>{t('staffPage.candidate.contract')}</span><h3>{t('staffPage.candidate.chooseLength')}</h3></header>
                          <div>{([13, 26, 52] as const).map((weeks) => { const salary = contractWeeklySalary(selected.base_weekly_salary, weeks); return <button type="button" key={weeks} disabled={pendingConfirmation} className={effectiveDuration === weeks ? 'selected' : ''} onClick={() => setDuration(weeks)}><strong>{t('staffPage.candidate.weeks', { count: weeks })}</strong><span>{t('staffPage.candidate.perWeek', { amount: formatCurrency(salary, 'USD') })}</span><small>{weeks === 13 ? t('staffPage.candidate.baseRate') : weeks === 26 ? t('staffPage.candidate.discount7') : t('staffPage.candidate.discount14')}</small></button> })}</div>
                        </section>

                        <section className="tlg-staff-salary-offer">
                          <header><div><span>{t('staffPage.candidate.salaryOffer')}</span><h3>{pendingConfirmation ? t('staffPage.candidate.acceptedTerms') : t('staffPage.candidate.improveProposal')}</h3></div><strong>{Math.round((pendingContract ? (pendingContract.weekly_salary / Math.max(1, contractWeeklySalary(selected.base_weekly_salary, pendingContract.duration_weeks))) : salaryMultiplier) * 100)}%</strong></header>
                          <input type="range" min={sliderMin} max="200" step="5" disabled={pendingConfirmation} value={Math.round(salaryMultiplier * 100)} onChange={(event) => setSalaryMultiplier(Number(event.target.value) / 100)} />
                          <div className="scale"><span>{t('staffPage.candidate.minimum', { value: sliderMin })}</span><span>{t('staffPage.candidate.maximum', { value: 200 })}</span></div>
                          <p>{pendingConfirmation ? t('staffPage.candidate.acceptedTermsBody') : t('staffPage.candidate.salaryBody')}</p>
                        </section>

                        <section className={`tlg-staff-chance ${hardRefusal ? 'refusal' : ''}`}>
                          <header>
                            <div><span>{t('staffPage.candidate.acceptanceChance')}</span><h3>{pendingConfirmation ? t('staffPage.candidate.accepted') : quoteLoading ? t('staffPage.candidate.calculating') : staffChanceLabel(t, negotiationQuote?.chance_label)}</h3></div>
                            <strong>{pendingConfirmation ? '✓' : quoteLoading ? '—' : `${acceptanceChance}%`}</strong>
                          </header>
                          <div className="chance-track"><i style={{ width: `${pendingConfirmation ? 100 : acceptanceChance}%` }} /></div>
                          {negotiationQuote?.available && <p>{staffBackendText(t, negotiationQuote.explanation)} · {t('staffPage.candidate.round', { round: negotiationQuote.round_number ?? 1, max: negotiationQuote.max_rounds ?? 3 })}</p>}
                          {pendingConfirmation && <p>{t('staffPage.candidate.acceptedPending')}</p>}
                          {!negotiationQuote?.available && !pendingConfirmation && negotiationQuote?.reason && <p>{staffBackendText(t, negotiationQuote.reason)}{negotiationQuote.cooldown_days_remaining ? t('staffPage.candidate.tryAgainDays', { count: negotiationQuote.cooldown_days_remaining }) : ''}</p>}
                          {quoteError && <p>{quoteError}</p>}
                        </section>

                        <div className="tlg-staff-offer-total"><div><span>{t('staffPage.candidate.negotiatedWeekly')}</span><strong>{formatCurrency(weeklyOffer, 'USD')}</strong></div><div><span>{t('staffPage.candidate.fullSalary', { weeks: effectiveDuration })}</span><strong>{formatCurrency(salaryTotal, 'USD')}</strong></div><div><span>{t('staffPage.hireDialog.signingFee')}</span><strong>{formatCurrency(effectiveSigningFee, 'USD')}</strong></div><div><span>{t('staffPage.candidate.fullContract')}</span><strong>{formatCurrency(contractTotal, 'USD')}</strong></div></div>
                        {roleOccupied && <div className="tlg-staff-blocked">{t('staffPage.candidate.roleOccupied', { role: staffRoleLabel(t, selected.role, selected.role_label).toLowerCase() })}</div>}
                        {financeBlocked && <div className="tlg-staff-blocked">{t('staffPage.candidate.insufficientBalance')}</div>}
                        {hardRefusal && <div className="tlg-staff-blocked">{t('staffPage.candidate.hardRefusal')}</div>}
                        {offerNotice && <div className={`tlg-staff-offer-notice ${offerNotice.tone}`}>{offerNotice.text}</div>}
                        <button type="button" className="tlg-staff-hire" disabled={saving || quoteLoading || roleOccupied || financeBlocked || hardRefusal || negotiationUnavailable || !negotiationQuote} onClick={() => void handleOffer()}>
                          {saving ? t('staffPage.candidate.processing') : pendingConfirmation ? t('staffPage.candidate.reviewAccepted', { weeks: effectiveDuration }) : hardRefusal ? t('staffPage.candidate.willNotNegotiate') : t('staffPage.candidate.makeOffer', { name: selected.first_name, weeks: duration })}
                        </button>
                      </>
                    ) : <div className="tlg-staff-loading">{t('staffPage.marketPanel.selectCandidate')}</div>}
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
        eyebrow={t('staffPage.hireDialog.eyebrow')}
        title={pendingContract ? t('staffPage.hireDialog.title', { name: pendingContract.staff_name }) : t('staffPage.hireDialog.fallbackTitle')}
        message={t('staffPage.hireDialog.message')}
        detail={pendingContract ? (
          <div className="tlg-game-confirm-summary">
            <div><span>{t('staffPage.hireDialog.signingFee')}</span><strong>{formatCurrency(pendingContract.signing_fee, 'USD')}</strong></div>
            <div><span>{t('staffPage.hireDialog.weeklySalary')}</span><strong>{formatCurrency(pendingContract.weekly_salary, 'USD')}</strong></div>
            <div><span>{t('staffPage.hireDialog.contractLength')}</span><strong>{t('staffPage.candidate.weeks', { count: pendingContract.duration_weeks })}</strong></div>
            <div><span>{t('staffPage.hireDialog.salaryFull')}</span><strong>{formatCurrency(pendingContract.salary_total, 'USD')}</strong></div>
            <div className="total"><span>{t('staffPage.hireDialog.total')}</span><strong>{formatCurrency(pendingContract.total_commitment, 'USD')}</strong></div>
          </div>
        ) : undefined}
        confirmLabel={t('staffPage.hireDialog.confirm')}
        cancelLabel={t('staffPage.hireDialog.cancel')}
        busy={saving}
        onCancel={() => setHireConfirmOpen(false)}
        onConfirm={handleConfirmHire}
      />

      <GameConfirmDialog
        open={Boolean(terminationTarget && terminationQuote)}
        tone="danger"
        eyebrow={t('staffPage.terminationDialog.eyebrow')}
        title={terminationQuote ? t('staffPage.terminationDialog.title', { name: terminationQuote.staff_name }) : t('staffPage.terminationDialog.fallbackTitle')}
        message={t('staffPage.terminationDialog.message')}
        detail={terminationQuote ? (
          <div className="tlg-game-confirm-summary">
            <div><span>{t('staffPage.terminationDialog.weeklySalary')}</span><strong>{formatCurrency(terminationQuote.weekly_salary, 'USD')}</strong></div>
            <div><span>{t('staffPage.terminationDialog.unpaidWeeks')}</span><strong>{terminationQuote.remaining_weeks}</strong></div>
            <div><span>{t('staffPage.terminationDialog.remainingSalary')}</span><strong>{formatCurrency(terminationQuote.remaining_salary, 'USD')}</strong></div>
            <div><span>{t('staffPage.terminationDialog.rate')}</span><strong>{terminationQuote.termination_rate}%</strong></div>
            <div className="danger total"><span>{t('staffPage.terminationDialog.fee')}</span><strong>{formatCurrency(terminationQuote.termination_fee, 'USD')}</strong></div>
          </div>
        ) : undefined}
        confirmLabel={t('staffPage.terminationDialog.confirm')}
        cancelLabel={t('staffPage.terminationDialog.cancel')}
        busy={saving}
        onCancel={() => { setTerminationTarget(null); setTerminationQuote(null) }}
        onConfirm={handleConfirmTermination}
      />
    </GameLayout>
  )
}
