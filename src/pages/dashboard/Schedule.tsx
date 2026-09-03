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
import '../../styles/schedule-operations.css'

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

type PreparationTab = 'travel' | 'staff' | 'tactics' | 'summary'

type TravelClass = 'Economy' | 'Premium Economy' | 'Business' | 'First Class'
type HotelTier = 'Budget' | 'Standard' | 'Premium' | 'Luxury'

const TRAVEL_CLASSES: TravelClass[] = ['Economy', 'Premium Economy', 'Business', 'First Class']
const HOTEL_TIERS: Array<{ value: HotelTier; label: string; detail: string }> = [
  { value: 'Budget', label: 'Budget Hotel ★★', detail: 'Lowest cost · basic recovery' },
  { value: 'Standard', label: 'Standard Hotel ★★★', detail: 'Balanced cost and recovery' },
  { value: 'Premium', label: 'Premium Hotel ★★★★', detail: 'Improved recovery between matches' },
  { value: 'Luxury', label: 'Luxury Hotel ★★★★★', detail: 'Best comfort and recovery support' },
]

const TACTIC_OPTIONS = {
  approach: ['Defensive', 'Balanced', 'Aggressive'],
  rally: ['Shorten points', 'Balanced rallies', 'Extend rallies'],
  serve: ['Safe first serve', 'Balanced', 'Power serving', 'Serve + 1'],
  returnGame: ['Safe return', 'Balanced', 'Aggressive return', 'Attack second serve'],
  courtPosition: ['Deep baseline', 'Normal baseline', 'Inside baseline', 'Net attack'],
  target: ['Automatic', 'Backhand', 'Forehand', 'Movement', 'Stamina', 'Second serve'],
  risk: ['Safe', 'Balanced', 'Aggressive'],
} as const

function tournamentWeekLabel(item: TournamentSummaryItem) {
  if (item.start_week === item.end_week) return `Season ${item.season} · Week ${item.start_week}`
  return `Season ${item.season} · Weeks ${item.start_week}–${item.end_week}`
}

function titleCase(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1)
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
  const [tacticPreset, setTacticPreset] = useState('Balanced')
  const [tactics, setTactics] = useState({
    approach: 'Balanced',
    rally: 'Balanced rallies',
    serve: 'Balanced',
    returnGame: 'Balanced',
    courtPosition: 'Normal baseline',
    target: 'Automatic',
    risk: 'Balanced',
  })

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
      const { data, error: rpcError } = await supabase.rpc('get_player_tournament_summary_v1', {
        p_player_id: player.id,
      })

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

  const selectedStaffNames = useMemo(
    () => activeStaff
      .filter((contract) => selectedStaff.includes(contract.contract_id))
      .map((contract) => `${contract.staff.first_name} ${contract.staff.last_name}`),
    [activeStaff, selectedStaff],
  )

  function openPreparation() {
    setActiveTab('travel')
    setPrepareOpen(true)
  }

  function toggleStaff(contractId: string) {
    setSelectedStaff((current) => current.includes(contractId)
      ? current.filter((id) => id !== contractId)
      : [...current, contractId])
  }

  function applyPreset(preset: string) {
    setTacticPreset(preset)
    if (preset === 'Attack') {
      setTactics({ approach: 'Aggressive', rally: 'Shorten points', serve: 'Serve + 1', returnGame: 'Aggressive return', courtPosition: 'Inside baseline', target: 'Automatic', risk: 'Aggressive' })
    } else if (preset === 'Counterpunch') {
      setTactics({ approach: 'Defensive', rally: 'Extend rallies', serve: 'Safe first serve', returnGame: 'Balanced', courtPosition: 'Deep baseline', target: 'Automatic', risk: 'Safe' })
    } else if (preset === 'Serve + 1') {
      setTactics({ approach: 'Aggressive', rally: 'Shorten points', serve: 'Serve + 1', returnGame: 'Attack second serve', courtPosition: 'Inside baseline', target: 'Automatic', risk: 'Aggressive' })
    } else if (preset === 'Defensive / Grind') {
      setTactics({ approach: 'Defensive', rally: 'Extend rallies', serve: 'Safe first serve', returnGame: 'Safe return', courtPosition: 'Deep baseline', target: 'Stamina', risk: 'Safe' })
    } else if (preset === 'Net Attack') {
      setTactics({ approach: 'Aggressive', rally: 'Shorten points', serve: 'Power serving', returnGame: 'Aggressive return', courtPosition: 'Net attack', target: 'Automatic', risk: 'Aggressive' })
    } else {
      setTactics({ approach: 'Balanced', rally: 'Balanced rallies', serve: 'Balanced', returnGame: 'Balanced', courtPosition: 'Normal baseline', target: 'Automatic', risk: 'Balanced' })
    }
  }

  return (
    <GameLayout title="Schedule" subtitle="Tournament operations and player commitments">
      <div className="tlg-schedule-page">
        <section className="tlg-schedule-hero">
          <div className="tlg-schedule-section-head">
            <div>
              <span>Next tournament</span>
              <h2>Your next competition</h2>
              <p>Travel, staff, accommodation and the tournament-wide tactical plan are managed here.</p>
            </div>
          </div>

          {loading || playerLoading ? (
            <div className="tlg-schedule-empty">Loading your tournament schedule…</div>
          ) : error ? (
            <div className="tlg-schedule-error">Unable to load schedule: {error}</div>
          ) : !nextTournament ? (
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

                <div className="tlg-next-tournament-meta">
                  <div><span>Schedule</span><strong>{tournamentWeekLabel(nextTournament)}</strong></div>
                  <div><span>Surface</span><strong>{titleCase(nextTournament.surface)}</strong></div>
                  <div><span>Entry</span><strong>Registered</strong></div>
                  <div><span>Preparation</span><strong>Not booked</strong></div>
                </div>
              </div>

              <div className="tlg-next-tournament-actions">
                <button type="button" className="primary" onClick={openPreparation}>Prepare Tournament</button>
                <Link to={`/game/tournaments/${nextTournament.competition_id}`}>Open Tournament <ChevronRight size={15} /></Link>
              </div>
            </div>
          )}
        </section>

        <section className="tlg-schedule-list-card">
          <div className="tlg-schedule-section-head compact">
            <div>
              <span>Tournament schedule</span>
              <h2>Other upcoming tournaments</h2>
              <p>Only tournaments that belong to your player appear on this page.</p>
            </div>
          </div>

          {!loading && upcoming.length === 0 ? (
            <div className="tlg-schedule-empty">No additional tournament commitments.</div>
          ) : laterTournaments.length === 0 ? (
            <div className="tlg-schedule-empty">No tournaments scheduled after your next event.</div>
          ) : (
            <div className="tlg-schedule-tournament-list">
              {laterTournaments.map((item) => (
                <Link key={item.competition_id} to={`/game/tournaments/${item.competition_id}`} className="tlg-schedule-tournament-row">
                  <div className="tlg-schedule-row-name">
                    <CountryFlag countryCode={item.country_code} countryName={item.country_code} width={24} height={16} />
                    <div><strong>{item.tournament_name}</strong><span>{item.city}, {item.country_code}</span></div>
                  </div>
                  <span>{item.category_code}</span>
                  <span>{titleCase(item.surface)}</span>
                  <span>{tournamentWeekLabel(item)}</span>
                  <ChevronRight size={16} />
                </Link>
              ))}
            </div>
          )}
        </section>
      </div>

      {prepareOpen && nextTournament && (
        <div className="tlg-tournament-prep-backdrop" role="presentation" onMouseDown={(event) => {
          if (event.currentTarget === event.target) setPrepareOpen(false)
        }}>
          <section className="tlg-tournament-prep-dialog" role="dialog" aria-modal="true" aria-label={`Prepare ${nextTournament.tournament_name}`}>
            <header className="tlg-tournament-prep-header">
              <div>
                <span>Tournament preparation</span>
                <h2>{nextTournament.tournament_name}</h2>
                <p>{nextTournament.city}, {nextTournament.country_code} · {titleCase(nextTournament.surface)} · {tournamentWeekLabel(nextTournament)}</p>
              </div>
              <button type="button" className="icon" onClick={() => setPrepareOpen(false)} aria-label="Close tournament preparation"><X size={19} /></button>
            </header>

            <nav className="tlg-tournament-prep-tabs" aria-label="Tournament preparation sections">
              <PrepTab active={activeTab === 'travel'} icon={<Plane size={15} />} label="Travel & Stay" onClick={() => setActiveTab('travel')} />
              <PrepTab active={activeTab === 'staff'} icon={<Users size={15} />} label="Travelling Staff" onClick={() => setActiveTab('staff')} />
              <PrepTab active={activeTab === 'tactics'} icon={<SlidersHorizontal size={15} />} label="Tactics" onClick={() => setActiveTab('tactics')} />
              <PrepTab active={activeTab === 'summary'} icon={<ShieldCheck size={15} />} label="Summary" onClick={() => setActiveTab('summary')} />
            </nav>

            <div className="tlg-tournament-prep-body">
              {activeTab === 'travel' && (
                <div className="tlg-prep-stack">
                  <div className="tlg-prep-rule">
                    <Plane size={18} />
                    <div><strong>Automatic travel timing</strong><p>Arrival is scheduled one day before qualification if you are qualifying, otherwise one day before the main draw. After elimination, the return trip home is scheduled for the following day.</p></div>
                  </div>

                  <ChoiceSection title="Player travel class" subtitle="Travel quality will later affect price and arrival fatigue.">
                    <ChoiceGrid values={TRAVEL_CLASSES} selected={playerTravelClass} onSelect={(value) => setPlayerTravelClass(value as TravelClass)} />
                  </ChoiceSection>

                  <ChoiceSection title="Staff travel class" subtitle="All selected travelling staff use this class in the first version.">
                    <ChoiceGrid values={TRAVEL_CLASSES} selected={staffTravelClass} onSelect={(value) => setStaffTravelClass(value as TravelClass)} />
                  </ChoiceSection>

                  <ChoiceSection title="Hotel" subtitle="Accommodation remains booked automatically while the player is alive in the tournament.">
                    <div className="tlg-prep-hotel-grid">
                      {HOTEL_TIERS.map((tier) => (
                        <button key={tier.value} type="button" className={hotelTier === tier.value ? 'selected' : ''} onClick={() => setHotelTier(tier.value)}>
                          <Hotel size={17} /><strong>{tier.label}</strong><span>{tier.detail}</span>
                        </button>
                      ))}
                    </div>
                  </ChoiceSection>
                </div>
              )}

              {activeTab === 'staff' && (
                <div className="tlg-prep-stack">
                  <div className="tlg-prep-copy"><h3>Choose who travels with the player</h3><p>Only staff currently under contract are shown. Travel and hotel costs will be added to the tournament budget once the booking engine is connected.</p></div>
                  {staffLoading ? (
                    <div className="tlg-schedule-empty">Loading contracted staff…</div>
                  ) : activeStaff.length === 0 ? (
                    <div className="tlg-schedule-empty">You do not currently employ any staff.</div>
                  ) : (
                    <div className="tlg-prep-staff-list">
                      {activeStaff.map((contract) => {
                        const checked = selectedStaff.includes(contract.contract_id)
                        return (
                          <button key={contract.contract_id} type="button" className={checked ? 'selected' : ''} onClick={() => toggleStaff(contract.contract_id)}>
                            <span className="checkbox">{checked ? '✓' : ''}</span>
                            <div><strong>{contract.staff.first_name} {contract.staff.last_name}</strong><span>{contract.role_label} · Rating {contract.staff.overall_rating}</span></div>
                            <small>{checked ? 'Travelling' : 'Stays home'}</small>
                          </button>
                        )
                      })}
                    </div>
                  )}
                </div>
              )}

              {activeTab === 'tactics' && (
                <div className="tlg-prep-stack">
                  <div className="tlg-prep-copy"><h3>Tournament default tactic</h3><p>This plan will be used for every match unless you create a specific tactic after the opponent becomes known.</p></div>

                  <div className="tlg-tactic-presets">
                    {['Balanced', 'Attack', 'Counterpunch', 'Serve + 1', 'Defensive / Grind', 'Net Attack'].map((preset) => (
                      <button key={preset} type="button" className={tacticPreset === preset ? 'selected' : ''} onClick={() => applyPreset(preset)}>{preset}</button>
                    ))}
                  </div>

                  <div className="tlg-tactic-grid">
                    <SelectField label="Overall approach" value={tactics.approach} values={TACTIC_OPTIONS.approach} onChange={(value) => setTactics((current) => ({ ...current, approach: value }))} />
                    <SelectField label="Rally strategy" value={tactics.rally} values={TACTIC_OPTIONS.rally} onChange={(value) => setTactics((current) => ({ ...current, rally: value }))} />
                    <SelectField label="Serve strategy" value={tactics.serve} values={TACTIC_OPTIONS.serve} onChange={(value) => setTactics((current) => ({ ...current, serve: value }))} />
                    <SelectField label="Return strategy" value={tactics.returnGame} values={TACTIC_OPTIONS.returnGame} onChange={(value) => setTactics((current) => ({ ...current, returnGame: value }))} />
                    <SelectField label="Court position" value={tactics.courtPosition} values={TACTIC_OPTIONS.courtPosition} onChange={(value) => setTactics((current) => ({ ...current, courtPosition: value }))} />
                    <SelectField label="Opponent target" value={tactics.target} values={TACTIC_OPTIONS.target} onChange={(value) => setTactics((current) => ({ ...current, target: value }))} />
                    <SelectField label="Risk level" value={tactics.risk} values={TACTIC_OPTIONS.risk} onChange={(value) => setTactics((current) => ({ ...current, risk: value }))} />
                  </div>

                  <div className="tlg-prep-rule soft"><SlidersHorizontal size={18} /><div><strong>Match-specific tactics come later</strong><p>Once the draw exists and an opponent is known, a match-specific plan will override this tournament default for that round only.</p></div></div>
                </div>
              )}

              {activeTab === 'summary' && (
                <div className="tlg-prep-stack">
                  <div className="tlg-prep-summary-grid">
                    <SummaryItem label="Player flight" value={playerTravelClass} />
                    <SummaryItem label="Staff flight" value={staffTravelClass} />
                    <SummaryItem label="Hotel" value={HOTEL_TIERS.find((tier) => tier.value === hotelTier)?.label ?? hotelTier} />
                    <SummaryItem label="Travelling staff" value={selectedStaff.length === 0 ? 'Player only' : `${selectedStaff.length} staff`} />
                    <SummaryItem label="Default tactic" value={tacticPreset} />
                    <SummaryItem label="Return travel" value="Day after elimination" />
                  </div>

                  {selectedStaffNames.length > 0 && (
                    <div className="tlg-prep-selected-staff"><span>Travelling party</span><strong>{selectedStaffNames.join(', ')}</strong></div>
                  )}

                  <div className="tlg-prep-cost-placeholder">
                    <span>Estimated tournament cost</span>
                    <strong>Live quote pending</strong>
                    <p>The visual workflow is live, but no booking or money deduction is created in this first draft. The next backend phase will calculate travel and accommodation from destination, travel class and selected staff.</p>
                  </div>
                </div>
              )}
            </div>

            <footer className="tlg-tournament-prep-footer">
              <span>UI draft only · no booking is saved yet</span>
              <button type="button" onClick={() => setPrepareOpen(false)}>Close Preview</button>
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
