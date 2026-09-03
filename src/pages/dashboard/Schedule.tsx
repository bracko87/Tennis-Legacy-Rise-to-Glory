import {
  CalendarDays,
  ChevronRight,
  Hotel,
  MapPin,
  Plane,
  ShieldCheck,
  SlidersHorizontal,
  Users,
  X,
} from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import { useStaff } from '../../hooks/useStaff'
import { supabase } from '../../lib/supabase'
import {
  BALANCED_TACTIC,
  TACTIC_OPTIONS,
  TACTIC_PRESETS,
  tacticFromPreset,
  type TournamentTactic,
} from '../../lib/tournamentTactics'
import '../../styles/schedule-operations.css'
import '../../styles/schedule-operations-v2.css'

interface TournamentSummaryItem {
  competition_id: string
  season: number
  start_week: number
  end_week: number
  tournament_name: string
  city: string
  country_code: string
  category_code: string
  category_label: string
  surface: string
  logo_url: string | null
}

interface PlayerTournamentSummary {
  next_tournaments: TournamentSummaryItem[]
}

interface PreparationPlanResponse {
  saved: boolean
  player_travel_class: TravelClass
  staff_travel_class: TravelClass
  hotel_tier: HotelTier
  selected_staff_contract_ids: string[]
  tactic: TournamentTactic
  updated_at?: string
}

type PreparationTab = 'travel' | 'staff' | 'tactics' | 'summary'
type TravelClass = 'Economy' | 'Premium Economy' | 'Business' | 'First Class'
type HotelTier = 'Budget' | 'Standard' | 'Premium' | 'Luxury'

const TRAVEL_CLASSES: TravelClass[] = ['Economy', 'Premium Economy', 'Business', 'First Class']
const TRAVEL_CLASS_INFO: Record<TravelClass, { multiplier: number; effect: string }> = {
  Economy: { multiplier: 1, effect: 'Standard arrival fatigue' },
  'Premium Economy': { multiplier: 1.45, effect: 'About 15% less travel fatigue' },
  Business: { multiplier: 2.4, effect: 'About 35% less travel fatigue' },
  'First Class': { multiplier: 4, effect: 'About 50% less travel fatigue' },
}

const HOTEL_TIERS: Array<{ value: HotelTier; label: string; detail: string; nightly: number; effect: string }> = [
  { value: 'Budget', label: 'Budget Hotel ★★', detail: 'Lowest cost', nightly: 90, effect: 'Standard recovery' },
  { value: 'Standard', label: 'Standard Hotel ★★★', detail: 'Balanced option', nightly: 150, effect: '+5% recovery support' },
  { value: 'Premium', label: 'Premium Hotel ★★★★', detail: 'Higher comfort', nightly: 240, effect: '+10% recovery support' },
  { value: 'Luxury', label: 'Luxury Hotel ★★★★★', detail: 'Maximum comfort', nightly: 420, effect: '+15% recovery support' },
]

const EUROPE = new Set(['AL','AD','AT','BY','BE','BA','BG','HR','CY','CZ','DK','EE','FI','FR','DE','GR','HU','IS','IE','IT','LV','LI','LT','LU','MT','MD','MC','ME','NL','MK','NO','PL','PT','RO','SM','RS','SK','SI','ES','SE','CH','UA','GB'])
const NORTH_AMERICA = new Set(['US','CA','MX'])
const OCEANIA = new Set(['AU','NZ'])

function tournamentWeekLabel(item: TournamentSummaryItem) {
  if (item.start_week === item.end_week) return `Season ${item.season} · Week ${item.start_week}`
  return `Season ${item.season} · Weeks ${item.start_week}–${item.end_week}`
}

function titleCase(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1)
}

function baseRoundTrip(countryCode: string) {
  if (EUROPE.has(countryCode)) return 280
  if (NORTH_AMERICA.has(countryCode)) return 950
  if (OCEANIA.has(countryCode)) return 1250
  return 780
}

function money(value: number) {
  return `$${Math.round(value).toLocaleString()}`
}

export default function SchedulePage() {
  const { player, playerLoading } = useAuth()
  const { dashboard: staffDashboard, loading: staffLoading } = useStaff()
  const [upcoming, setUpcoming] = useState<TournamentSummaryItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [prepareOpen, setPrepareOpen] = useState(false)
  const [activeTab, setActiveTab] = useState<PreparationTab>('travel')
  const [playerTravelClass, setPlayerTravelClass] = useState<TravelClass>('Economy')
  const [staffTravelClass, setStaffTravelClass] = useState<TravelClass>('Economy')
  const [hotelTier, setHotelTier] = useState<HotelTier>('Standard')
  const [selectedStaff, setSelectedStaff] = useState<string[]>([])
  const [tactics, setTactics] = useState<TournamentTactic>({ ...BALANCED_TACTIC })
  const [planSaved, setPlanSaved] = useState(false)
  const [planLoading, setPlanLoading] = useState(false)
  const [planSaving, setPlanSaving] = useState(false)
  const [planMessage, setPlanMessage] = useState<string | null>(null)

  useEffect(() => {
    if (!player?.id) {
      setUpcoming([])
      setLoading(false)
      return
    }

    let cancelled = false
    async function loadSchedule() {
      setLoading(true)
      setError(null)
      const { data, error: rpcError } = await supabase.rpc('get_player_tournament_summary_v1', { p_player_id: player.id })
      if (cancelled) return
      if (rpcError) {
        setUpcoming([])
        setError(rpcError.message)
      } else {
        const summary = (data ?? { next_tournaments: [] }) as PlayerTournamentSummary
        setUpcoming(summary.next_tournaments ?? [])
      }
      setLoading(false)
    }
    void loadSchedule()
    return () => { cancelled = true }
  }, [player?.id])

  const nextTournament = upcoming[0] ?? null
  const laterTournaments = upcoming.slice(1)
  const activeStaff = staffDashboard?.contracts ?? []

  useEffect(() => {
    if (!player?.id || !nextTournament?.competition_id) {
      setPlanSaved(false)
      return
    }

    let cancelled = false
    async function loadPreparation() {
      setPlanLoading(true)
      setPlanMessage(null)
      const { data, error: planError } = await supabase.rpc('get_tournament_preparation_v1', {
        p_player_id: player!.id,
        p_competition_id: nextTournament!.competition_id,
      })
      if (cancelled) return
      setPlanLoading(false)
      if (planError || !data) {
        setPlanMessage(planError?.message ?? 'Unable to load tournament preparation.')
        return
      }
      const plan = data as PreparationPlanResponse
      setPlayerTravelClass(plan.player_travel_class ?? 'Economy')
      setStaffTravelClass(plan.staff_travel_class ?? 'Economy')
      setHotelTier(plan.hotel_tier ?? 'Standard')
      setSelectedStaff(plan.selected_staff_contract_ids ?? [])
      setTactics(plan.tactic ?? { ...BALANCED_TACTIC })
      setPlanSaved(Boolean(plan.saved))
    }
    void loadPreparation()
    return () => { cancelled = true }
  }, [nextTournament?.competition_id, player?.id])

  const selectedStaffNames = useMemo(
    () => activeStaff.filter((contract) => selectedStaff.includes(contract.contract_id)).map((contract) => `${contract.staff.first_name} ${contract.staff.last_name}`),
    [activeStaff, selectedStaff],
  )

  const hotel = HOTEL_TIERS.find((tier) => tier.value === hotelTier) ?? HOTEL_TIERS[1]
  const estimate = useMemo(() => {
    if (!nextTournament) return null
    const base = baseRoundTrip(nextTournament.country_code)
    const playerFlight = base * TRAVEL_CLASS_INFO[playerTravelClass].multiplier
    const staffFlight = base * TRAVEL_CLASS_INFO[staffTravelClass].multiplier * selectedStaff.length
    const partySize = 1 + selectedStaff.length
    const minimumNights = 2
    const maximumNights = 6
    const minimum = playerFlight + staffFlight + hotel.nightly * partySize * minimumNights
    const maximum = playerFlight + staffFlight + hotel.nightly * partySize * maximumNights
    return { playerFlight, staffFlight, partySize, minimumNights, maximumNights, minimum, maximum }
  }, [hotel.nightly, nextTournament, playerTravelClass, selectedStaff.length, staffTravelClass])

  function openPreparation() {
    setActiveTab('travel')
    setPlanMessage(null)
    setPrepareOpen(true)
  }

  function toggleStaff(contractId: string) {
    setSelectedStaff((current) => current.includes(contractId) ? current.filter((id) => id !== contractId) : [...current, contractId])
  }

  function applyPreset(preset: string) {
    setTactics(tacticFromPreset(preset))
  }

  async function savePreparation() {
    if (!player?.id || !nextTournament) return
    setPlanSaving(true)
    setPlanMessage(null)
    const { data, error: saveError } = await supabase.rpc('save_tournament_preparation_v1', {
      p_player_id: player.id,
      p_competition_id: nextTournament.competition_id,
      p_player_travel_class: playerTravelClass,
      p_staff_travel_class: staffTravelClass,
      p_hotel_tier: hotelTier,
      p_selected_staff_contract_ids: selectedStaff,
      p_tactic_preset: tactics.preset,
      p_tactic_approach: tactics.approach,
      p_tactic_rally: tactics.rally,
      p_tactic_serve: tactics.serve,
      p_tactic_return: tactics.returnGame,
      p_tactic_court_position: tactics.courtPosition,
      p_tactic_target: tactics.target,
      p_tactic_risk: tactics.risk,
    })
    setPlanSaving(false)
    if (saveError || !data) {
      setPlanMessage(saveError?.message ?? 'Unable to save tournament preparation.')
      return
    }
    const saved = data as PreparationPlanResponse
    setPlanSaved(true)
    setPlanMessage('Tournament preparation saved.')
    setPlayerTravelClass(saved.player_travel_class)
    setStaffTravelClass(saved.staff_travel_class)
    setHotelTier(saved.hotel_tier)
    setSelectedStaff(saved.selected_staff_contract_ids ?? [])
    setTactics(saved.tactic ?? tactics)
  }

  const planSummary = `${playerTravelClass} · ${hotel.label} · ${selectedStaff.length === 0 ? 'Player only' : `${selectedStaff.length} staff`} · ${tactics.preset} tactic`

  return (
    <GameLayout title="Schedule" subtitle="Tournament operations and player commitments">
      <div className="tlg-schedule-page">
        <section className="tlg-schedule-hero">
          <div className="tlg-schedule-section-head">
            <div>
              <span>Next tournament</span>
              <h2>Your next tournament</h2>
              <p>Prepare travel, staff, accommodation and your default match plan in advance. If you do nothing, the automatic defaults are used.</p>
            </div>
          </div>

          {loading || playerLoading ? <div className="tlg-schedule-empty">Loading your tournament schedule…</div> : error ? <div className="tlg-schedule-error">Unable to load schedule: {error}</div> : !nextTournament ? (
            <div className="tlg-schedule-empty tlg-schedule-empty-large">
              <CalendarDays size={28} />
              <strong>No tournament is on your schedule yet</strong>
              <p>Apply for or register in a tournament from the Tournament Calendar. Once an entry is confirmed, the next event and its preparation controls will appear here automatically.</p>
              <Link to="/game/calendar?tab=tournament-calendar">Open Tournament Calendar</Link>
            </div>
          ) : (
            <div className="tlg-next-tournament-card">
              <div className="tlg-next-tournament-main">
                <div className="tlg-next-tournament-location">
                  <CountryFlag countryCode={nextTournament.country_code} countryName={nextTournament.country_code} width={34} height={23} />
                  <div>
                    <span>{nextTournament.category_label}</span>
                    <h3>{nextTournament.tournament_name}</h3>
                    <p><MapPin size={14} /> {nextTournament.city}, {nextTournament.country_code}</p>
                  </div>
                </div>

                <div className="tlg-next-tournament-actions">
                  <button type="button" className="primary" onClick={openPreparation}>Prepare Tournament</button>
                  <Link to={`/game/tournaments/${nextTournament.competition_id}`}>Open Tournament <ChevronRight size={15} /></Link>
                </div>

                <div className={`tlg-default-plan-strip${planSaved ? ' saved' : ''}`}>
                  <div><span>{planSaved ? 'Saved preparation' : 'Automatic default'}</span><strong>{planSaved ? planSummary : 'Economy · Standard Hotel ★★★ · Player only · Balanced tactic'}</strong></div>
                  <p>{planSaved ? 'This saved plan will be used for Palm Springs unless you change and save it again.' : 'Used automatically if you make no changes. Travel is the day before your first required draw and return is the day after elimination.'}</p>
                </div>

                <div className="tlg-next-tournament-meta">
                  <div><span>Schedule</span><strong>{tournamentWeekLabel(nextTournament)}</strong></div>
                  <div><span>Surface</span><strong>{titleCase(nextTournament.surface)}</strong></div>
                  <div><span>Entry</span><strong>Registered</strong></div>
                  <div><span>Preparation</span><strong>{planLoading ? 'Loading…' : planSaved ? 'Saved plan' : 'Defaults active'}</strong></div>
                </div>
              </div>
            </div>
          )}
        </section>

        <section className="tlg-schedule-list-card">
          <div className="tlg-schedule-section-head compact"><div><span>Tournament schedule</span><h2>Other upcoming tournaments</h2><p>Only tournaments that belong to your player appear on this page.</p></div></div>
          {!loading && upcoming.length === 0 ? <div className="tlg-schedule-empty">No additional tournament commitments.</div> : laterTournaments.length === 0 ? <div className="tlg-schedule-empty">No tournaments scheduled after your next event.</div> : (
            <div className="tlg-schedule-tournament-list">
              {laterTournaments.map((item) => (
                <Link key={item.competition_id} to={`/game/tournaments/${item.competition_id}`} className="tlg-schedule-tournament-row">
                  <div className="tlg-schedule-row-name"><CountryFlag countryCode={item.country_code} countryName={item.country_code} width={24} height={16} /><div><strong>{item.tournament_name}</strong><span>{item.city}, {item.country_code}</span></div></div>
                  <span>{item.category_code}</span><span>{titleCase(item.surface)}</span><span>{tournamentWeekLabel(item)}</span><ChevronRight size={16} />
                </Link>
              ))}
            </div>
          )}
        </section>
      </div>

      {prepareOpen && nextTournament && (
        <div className="tlg-tournament-prep-backdrop" role="presentation" onMouseDown={(event) => { if (event.currentTarget === event.target) setPrepareOpen(false) }}>
          <section className="tlg-tournament-prep-dialog" role="dialog" aria-modal="true" aria-label={`Prepare ${nextTournament.tournament_name}`}>
            <header className="tlg-tournament-prep-header">
              <div><span>Tournament preparation</span><h2>{nextTournament.tournament_name}</h2><p>{nextTournament.city}, {nextTournament.country_code} · {titleCase(nextTournament.surface)} · {tournamentWeekLabel(nextTournament)}</p></div>
              <button type="button" className="icon" onClick={() => setPrepareOpen(false)} aria-label="Close tournament preparation"><X size={19} /></button>
            </header>

            <nav className="tlg-tournament-prep-tabs" aria-label="Tournament preparation sections">
              <PrepTab active={activeTab === 'travel'} icon={<Plane size={15} />} label="Travel & Stay" onClick={() => setActiveTab('travel')} />
              <PrepTab active={activeTab === 'staff'} icon={<Users size={15} />} label="Travelling Staff" onClick={() => setActiveTab('staff')} />
              <PrepTab active={activeTab === 'tactics'} icon={<SlidersHorizontal size={15} />} label="Default Tactic" onClick={() => setActiveTab('tactics')} />
              <PrepTab active={activeTab === 'summary'} icon={<ShieldCheck size={15} />} label="Cost Summary" onClick={() => setActiveTab('summary')} />
            </nav>

            <div className="tlg-tournament-prep-body">
              {activeTab === 'travel' && (
                <div className="tlg-prep-stack">
                  <div className="tlg-prep-rule"><Plane size={18} /><div><strong>Automatic travel timing</strong><p>Arrive one day before qualification if you are qualifying, otherwise one day before the main draw. Return home the day after elimination.</p></div></div>
                  <ChoiceSection title="Player travel class" subtitle="Changing class changes both cost and arrival fatigue."><ChoiceGrid values={TRAVEL_CLASSES} selected={playerTravelClass} onSelect={(value) => setPlayerTravelClass(value as TravelClass)} /></ChoiceSection>
                  <PlanImpact label="Player travel effect" value={TRAVEL_CLASS_INFO[playerTravelClass].effect} cost={estimate ? money(estimate.playerFlight) : '—'} />
                  <ChoiceSection title="Staff travel class" subtitle="Applied to every staff member you select on the Staff tab."><ChoiceGrid values={TRAVEL_CLASSES} selected={staffTravelClass} onSelect={(value) => setStaffTravelClass(value as TravelClass)} /></ChoiceSection>
                  <PlanImpact label="Staff travel effect" value={selectedStaff.length > 0 ? `${TRAVEL_CLASS_INFO[staffTravelClass].effect} · ${selectedStaff.length} traveller${selectedStaff.length === 1 ? '' : 's'}` : 'No travelling staff selected'} cost={estimate ? money(estimate.staffFlight) : '—'} />
                  <ChoiceSection title="Hotel" subtitle="The hotel stays booked automatically only while you remain in the tournament.">
                    <div className="tlg-prep-hotel-grid">{HOTEL_TIERS.map((tier) => <button key={tier.value} type="button" className={hotelTier === tier.value ? 'selected' : ''} onClick={() => setHotelTier(tier.value)}><Hotel size={17} /><strong>{tier.label}</strong><span>{tier.detail} · {tier.effect}</span><small>{money(tier.nightly)} / person / night</small></button>)}</div>
                  </ChoiceSection>
                  <PlanImpact label="Selected hotel effect" value={hotel.effect} cost={`${money(hotel.nightly)} per person/night`} />
                </div>
              )}

              {activeTab === 'staff' && (
                <div className="tlg-prep-stack">
                  <div className="tlg-prep-copy"><h3>Choose who travels with the player</h3><p>The default is player-only travel. Every selected staff member adds a flight and hotel cost.</p></div>
                  {staffLoading ? <div className="tlg-schedule-empty">Loading contracted staff…</div> : activeStaff.length === 0 ? <div className="tlg-schedule-empty">You do not currently employ any staff.</div> : (
                    <div className="tlg-prep-staff-list">{activeStaff.map((contract) => { const checked = selectedStaff.includes(contract.contract_id); return <button key={contract.contract_id} type="button" className={checked ? 'selected' : ''} onClick={() => toggleStaff(contract.contract_id)}><span className="checkbox">{checked ? '✓' : ''}</span><div><strong>{contract.staff.first_name} {contract.staff.last_name}</strong><span>{contract.role_label} · Rating {contract.staff.overall_rating}</span></div><small>{checked ? 'Travelling' : 'Stays home'}</small></button> })}</div>
                  )}
                  {estimate && <PlanImpact label="Current travelling party" value={`${estimate.partySize} total traveller${estimate.partySize === 1 ? '' : 's'}`} cost={`${money(estimate.staffFlight)} staff flights`} />}
                </div>
              )}

              {activeTab === 'tactics' && (
                <div className="tlg-prep-stack">
                  <div className="tlg-prep-copy"><h3>Tournament default tactic</h3><p>This saved plan is used in every match unless you create a specific override from an upcoming match window.</p></div>
                  <div className="tlg-tactic-presets">{TACTIC_PRESETS.map((preset) => <button key={preset} type="button" className={tactics.preset === preset ? 'selected' : ''} onClick={() => applyPreset(preset)}>{preset}</button>)}</div>
                  <div className="tlg-tactic-grid">
                    <SelectField label="Overall approach" value={tactics.approach} values={TACTIC_OPTIONS.approach} onChange={(value) => setTactics((current) => ({ ...current, preset: 'Custom', approach: value }))} />
                    <SelectField label="Rally strategy" value={tactics.rally} values={TACTIC_OPTIONS.rally} onChange={(value) => setTactics((current) => ({ ...current, preset: 'Custom', rally: value }))} />
                    <SelectField label="Serve strategy" value={tactics.serve} values={TACTIC_OPTIONS.serve} onChange={(value) => setTactics((current) => ({ ...current, preset: 'Custom', serve: value }))} />
                    <SelectField label="Return strategy" value={tactics.returnGame} values={TACTIC_OPTIONS.returnGame} onChange={(value) => setTactics((current) => ({ ...current, preset: 'Custom', returnGame: value }))} />
                    <SelectField label="Court position" value={tactics.courtPosition} values={TACTIC_OPTIONS.courtPosition} onChange={(value) => setTactics((current) => ({ ...current, preset: 'Custom', courtPosition: value }))} />
                    <SelectField label="Opponent target" value={tactics.target} values={TACTIC_OPTIONS.target} onChange={(value) => setTactics((current) => ({ ...current, preset: 'Custom', target: value }))} />
                    <SelectField label="Risk level" value={tactics.risk} values={TACTIC_OPTIONS.risk} onChange={(value) => setTactics((current) => ({ ...current, preset: 'Custom', risk: value }))} />
                  </div>
                  <div className="tlg-prep-rule soft"><SlidersHorizontal size={18} /><div><strong>Match-specific override</strong><p>When the opponent is known, open your scheduled match on the Tournament page. You can keep this default or save a one-match tactic specifically for that opponent.</p></div></div>
                </div>
              )}

              {activeTab === 'summary' && estimate && (
                <div className="tlg-prep-stack">
                  <div className="tlg-prep-summary-grid">
                    <SummaryItem label="Player flight" value={`${playerTravelClass} · ${money(estimate.playerFlight)}`} />
                    <SummaryItem label="Staff flight" value={selectedStaff.length === 0 ? 'No staff travel' : `${staffTravelClass} · ${money(estimate.staffFlight)}`} />
                    <SummaryItem label="Hotel" value={`${hotel.label} · ${hotel.effect}`} />
                    <SummaryItem label="Travelling staff" value={selectedStaff.length === 0 ? 'Player only' : `${selectedStaff.length} staff`} />
                    <SummaryItem label="Default tactic" value={tactics.preset} />
                    <SummaryItem label="Return travel" value="Day after elimination" />
                  </div>
                  {selectedStaffNames.length > 0 && <div className="tlg-prep-selected-staff"><span>Travelling party</span><strong>{selectedStaffNames.join(', ')}</strong></div>}
                  <div className="tlg-prep-cost-placeholder tlg-prep-cost-live"><span>Estimated tournament trip cost</span><strong>{money(estimate.minimum)} – {money(estimate.maximum)}</strong><div className="tlg-prep-cost-breakdown"><small>Flights: {money(estimate.playerFlight + estimate.staffFlight)}</small><small>Hotel: {money(hotel.nightly * estimate.partySize)} / night for the party</small><small>Planning range: {estimate.minimumNights}–{estimate.maximumNights} nights</small></div><p>You do not choose stay length. Hotel usage ends automatically after elimination.</p></div>
                </div>
              )}
            </div>

            <footer className="tlg-tournament-prep-footer">
              <span>{planMessage ?? (planSaved ? 'Saved plan is active for this tournament.' : 'Automatic defaults remain active until you save a plan.')}</span>
              <button type="button" onClick={savePreparation} disabled={planSaving || planLoading}>{planSaving ? 'Saving…' : 'Save Tournament Plan'}</button>
            </footer>
          </section>
        </div>
      )}
    </GameLayout>
  )
}

function PrepTab({ active, icon, label, onClick }: { active: boolean; icon: JSX.Element; label: string; onClick: () => void }) {
  return <button type="button" className={active ? 'active' : ''} onClick={onClick}>{icon}<span>{label}</span></button>
}

function ChoiceSection({ title, subtitle, children }: { title: string; subtitle: string; children: JSX.Element }) {
  return <section className="tlg-prep-choice-section"><div><h3>{title}</h3><p>{subtitle}</p></div>{children}</section>
}

function ChoiceGrid({ values, selected, onSelect }: { values: readonly string[]; selected: string; onSelect: (value: string) => void }) {
  return <div className="tlg-prep-choice-grid">{values.map((value) => <button key={value} type="button" className={selected === value ? 'selected' : ''} onClick={() => onSelect(value)}>{value}</button>)}</div>
}

function SelectField({ label, value, values, onChange }: { label: string; value: string; values: readonly string[]; onChange: (value: string) => void }) {
  return <label className="tlg-tactic-field"><span>{label}</span><select value={value} onChange={(event) => onChange(event.target.value)}>{values.map((option) => <option key={option} value={option}>{option}</option>)}</select></label>
}

function SummaryItem({ label, value }: { label: string; value: string }) {
  return <div className="tlg-prep-summary-item"><span>{label}</span><strong>{value}</strong></div>
}

function PlanImpact({ label, value, cost }: { label: string; value: string; cost: string }) {
  return <div className="tlg-prep-impact"><div><span>{label}</span><strong>{value}</strong></div><b>{cost}</b></div>
}
