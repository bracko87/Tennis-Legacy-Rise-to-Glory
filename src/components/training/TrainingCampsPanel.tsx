import { useEffect, useMemo, useState } from 'react'

import CountryFlag from '../common/CountryFlag'
import { useStaff } from '../../hooks/useStaff'
import {
  useTrainingCamps,
  type TrainingCampAccommodationTier,
  type TrainingCampProgram,
  type TrainingCampQuote,
} from '../../hooks/useTrainingCamps'
import '../../styles/training-camps.css'
import '../../styles/training-camp-staff.css'

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]
const MONTH_LENGTHS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const PAGE_SIZE = 10

type GameDay = { season: number; month: number; day: number }
type CampFilter = 'all' | 'hard' | 'clay' | 'grass' | 'physical' | 'recovery'
type WeekOption = { season: number; week: number; start: GameDay; end: GameDay }

function absoluteDay(day: GameDay) {
  const prior = MONTH_LENGTHS.slice(0, day.month - 1).reduce((sum, value) => sum + value, 0)
  return (day.season - 1) * 366 + prior + day.day - 1
}

function fromAbsolute(value: number): GameDay {
  const season = Math.floor(value / 366) + 1
  let remaining = value % 366
  let month = 1
  for (let i = 0; i < MONTH_LENGTHS.length; i += 1) {
    if (remaining < MONTH_LENGTHS[i]) {
      month = i + 1
      break
    }
    remaining -= MONTH_LENGTHS[i]
  }
  return { season, month, day: remaining + 1 }
}

function weekStartAbsolute(season: number, week: number) {
  return (season - 1) * 366 + 2 + (week - 1) * 7
}

function formatDay(day: GameDay, includeSeason = false) {
  return `${MONTH_NAMES[day.month - 1]} ${day.day}${includeSeason ? ` · Season ${day.season}` : ''}`
}

function formatWeek(option: WeekOption) {
  const endNeedsMonth = option.start.month !== option.end.month
  const endText = endNeedsMonth ? formatDay(option.end) : `${option.end.day}`
  return `Season ${option.season} · Week ${option.week} · ${formatDay(option.start)}–${endText}`
}

function buildWeekOptions(currentAbsolute: number, count = 52): WeekOption[] {
  const options: WeekOption[] = []
  const currentSeason = Math.floor(currentAbsolute / 366) + 1
  for (let season = currentSeason; season <= currentSeason + 2 && options.length < count; season += 1) {
    for (let week = 1; week <= 52 && options.length < count; week += 1) {
      const startAbsolute = weekStartAbsolute(season, week)
      if (startAbsolute < currentAbsolute) continue
      options.push({ season, week, start: fromAbsolute(startAbsolute), end: fromAbsolute(startAbsolute + 6) })
    }
  }
  return options
}

function categoryLabel(program: TrainingCampProgram) {
  if (program.category === 'physical') return 'Physical Development'
  if (program.category === 'recovery_mindset') return 'Recovery & Mindset'
  return `${program.surface ? program.surface.charAt(0).toUpperCase() + program.surface.slice(1) : ''} Tennis Skills`
}

function qualityLabel(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1)
}

function attributeLabel(value: string) {
  const labels: Record<string, string> = {
    return_skill: 'Return', drop_shot: 'Drop Shot', serve: 'Serve', forehand: 'Forehand', backhand: 'Backhand', volley: 'Volley',
    slice: 'Slice', lob: 'Lob', smash: 'Smash', fitness: 'Fitness', stamina: 'Stamina', recovery: 'Recovery', movement: 'Movement',
    fatigue: 'Fatigue', morale: 'Morale', confidence: 'Confidence', sharpness: 'Sharpness', focus: 'Focus',
  }
  return labels[value] ?? value
}

function filterMatches(program: TrainingCampProgram, filter: CampFilter) {
  if (filter === 'all') return true
  if (filter === 'physical') return program.category === 'physical'
  if (filter === 'recovery') return program.category === 'recovery_mindset'
  return program.category === 'tennis_skills' && program.surface === filter
}

function hotelWeeklyEstimate(tier: TrainingCampAccommodationTier, program: TrainingCampProgram) {
  return Math.round((tier.base_weekly_cost * program.location.cost_index) / 10) * 10
}

function campRoleBenefit(role: string, program: TrainingCampProgram) {
  if (role === 'head_coach') return program.category === 'tennis_skills' ? 'Boosts tennis-skill camp development.' : 'No direct development bonus at this camp.'
  if (role === 'fitness_coach') return program.category === 'physical' ? 'Boosts physical camp development and manages workload.' : 'Can reduce training fatigue when travelling.'
  if (role === 'physiotherapist') return 'Improves recovery on the camp recovery day.'
  if (role === 'sports_psychologist') return 'Improves mental recovery during the camp.'
  if (role === 'performance_analyst') return 'Travels with the team; match-analysis benefits apply later in competition.'
  return 'Travels with the team; no direct camp sporting bonus.'
}

function CampArtwork({ program, large = false }: { program: TrainingCampProgram; large?: boolean }) {
  const image = large ? (program.location.image_url ?? program.location.thumbnail_url) : (program.location.thumbnail_url ?? program.location.image_url)
  if (image) return <img src={image} alt="" />
  return (
    <div className={`tlg-camp-art-placeholder ${program.category} ${program.surface ?? ''}`}>
      <span>{program.location.country_code}</span><strong>{program.location.city}</strong><small>{categoryLabel(program)}</small>
    </div>
  )
}

export default function TrainingCampsPanel({ gameDay }: { gameDay: GameDay }) {
  const {
    programs, accommodations, bookings, loading, saving, processing, error,
    quoteCamp, bookCamp, cancelCamp, processToday,
  } = useTrainingCamps()
  const { dashboard: staffDashboard, loading: staffLoading } = useStaff()

  const [continent, setContinent] = useState('all')
  const [campType, setCampType] = useState<CampFilter>('all')
  const [maxCost, setMaxCost] = useState(3400)
  const [page, setPage] = useState(1)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [startKey, setStartKey] = useState('')
  const [durationWeeks, setDurationWeeks] = useState(1)
  const [accommodationSlug, setAccommodationSlug] = useState('standard-3-star')
  const [selectedStaffIds, setSelectedStaffIds] = useState<string[]>([])
  const [quote, setQuote] = useState<TrainingCampQuote | null>(null)
  const [quoteError, setQuoteError] = useState<string | null>(null)
  const [quoteLoading, setQuoteLoading] = useState(false)
  const [actionMessage, setActionMessage] = useState<string | null>(null)

  const currentAbsolute = absoluteDay(gameDay)
  const weekOptions = useMemo(() => buildWeekOptions(currentAbsolute), [currentAbsolute])
  const selectedWeek = weekOptions.find((option) => `${option.season}-${option.week}` === startKey) ?? weekOptions[0] ?? null
  const continents = useMemo(() => Array.from(new Set(programs.map((program) => program.location.continent))).sort(), [programs])
  const activeStaff = staffDashboard?.contracts ?? []

  const filtered = useMemo(() => programs.filter((program) => (
    (continent === 'all' || program.location.continent === continent) && filterMatches(program, campType) && program.weekly_cost <= maxCost
  )), [programs, continent, campType, maxCost])

  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const visiblePrograms = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)
  const selected = programs.find((program) => program.id === selectedId) ?? visiblePrograms[0] ?? null
  const activeOrPlanned = bookings.find((booking) => booking.status === 'active' || (booking.status === 'booked' && currentAbsolute <= booking.end_absolute_day)) ?? null
  const maxDuration = selectedWeek ? Math.min(4, 53 - selectedWeek.week) : 1

  useEffect(() => { if (!startKey && weekOptions[0]) setStartKey(`${weekOptions[0].season}-${weekOptions[0].week}`) }, [startKey, weekOptions])
  useEffect(() => { if (durationWeeks > maxDuration) setDurationWeeks(maxDuration) }, [durationWeeks, maxDuration])
  useEffect(() => {
    if (!accommodations.some((tier) => tier.slug === accommodationSlug) && accommodations[0]) {
      const preferred = accommodations.find((tier) => tier.slug === 'standard-3-star') ?? accommodations[0]
      setAccommodationSlug(preferred.slug)
    }
  }, [accommodations, accommodationSlug])
  useEffect(() => { setPage(1) }, [continent, campType, maxCost])
  useEffect(() => { if (!selectedId || !filtered.some((program) => program.id === selectedId)) setSelectedId(filtered[0]?.id ?? null) }, [filtered, selectedId])
  useEffect(() => { if (page > pageCount) setPage(pageCount) }, [page, pageCount])
  useEffect(() => {
    const available = new Set(activeStaff.map((contract) => contract.contract_id))
    setSelectedStaffIds((current) => current.filter((id) => available.has(id)))
  }, [activeStaff])

  useEffect(() => {
    let cancelled = false
    if (!selected || !selectedWeek || !accommodationSlug) { setQuote(null); return }
    setQuoteLoading(true); setQuoteError(null)
    void quoteCamp(selected.id, selectedWeek.season, selectedWeek.week, durationWeeks, accommodationSlug, selectedStaffIds)
      .then((result) => { if (!cancelled) { setQuote(result.quote); setQuoteError(result.error) } })
      .finally(() => { if (!cancelled) setQuoteLoading(false) })
    return () => { cancelled = true }
  }, [selected, selectedWeek, durationWeeks, accommodationSlug, selectedStaffIds, quoteCamp])

  function toggleStaff(contractId: string) {
    setSelectedStaffIds((current) => current.includes(contractId) ? current.filter((id) => id !== contractId) : [...current, contractId])
  }

  async function handleBook() {
    if (!selected || !selectedWeek) return
    setActionMessage(null)
    const result = await bookCamp(selected.id, selectedWeek.season, selectedWeek.week, durationWeeks, accommodationSlug, selectedStaffIds)
    if (result) setActionMessage(`${selected.name} booked successfully with ${selectedStaffIds.length} travelling staff member${selectedStaffIds.length === 1 ? '' : 's'}.`)
  }

  async function handleCancel() {
    if (!activeOrPlanned) return
    setActionMessage(null)
    const result = await cancelCamp(activeOrPlanned.id)
    if (result) setActionMessage('Training camp booking cancelled.')
  }

  async function handleProcessToday() {
    setActionMessage(null)
    const result = await processToday()
    if (!result) return
    if (result.status === 'already_processed') setActionMessage('Today’s camp session has already been processed.')
    else if (result.status === 'completed') setActionMessage(`Camp day ${result.camp_day_number ?? ''} completed. Development has been stored in the database.`)
    else setActionMessage(result.reason ?? 'The camp session could not be processed.')
  }

  if (loading && programs.length === 0) return <div className="tlg-camp-loading">Loading training camp destinations…</div>

  return (
    <div className="tlg-camp-page">
      {error && <div className="tlg-training-alert tlg-training-alert-error">{error}</div>}
      {actionMessage && <div className="tlg-training-alert">{actionMessage}</div>}

      <section className="tlg-camp-current">
        <div>
          <span>CURRENT / PLANNED TRAINING CAMP</span>
          {activeOrPlanned ? <><h2>{activeOrPlanned.program.name}</h2><p>{activeOrPlanned.program.location.city}, {activeOrPlanned.program.location.country} · Season {activeOrPlanned.start_season} · Week {activeOrPlanned.start_season_week ?? '—'} · {activeOrPlanned.duration_weeks} week{activeOrPlanned.duration_weeks === 1 ? '' : 's'} · {activeOrPlanned.staff_count} travelling staff</p></> : <><h2>No training camp booked</h2><p>Select a destination, choose a starting competition week and reserve up to four consecutive weeks.</p></>}
        </div>
        {activeOrPlanned && <div className="tlg-camp-current-actions"><span className={`status ${activeOrPlanned.status}`}>{activeOrPlanned.status}</span><strong>${activeOrPlanned.total_cost.toLocaleString()}</strong>{currentAbsolute < activeOrPlanned.start_absolute_day && <button type="button" onClick={handleCancel} disabled={saving}>Cancel booking</button>}{currentAbsolute >= activeOrPlanned.start_absolute_day && currentAbsolute <= activeOrPlanned.end_absolute_day && <button type="button" className="primary" onClick={handleProcessToday} disabled={processing}>{processing ? 'Processing…' : 'Process today’s camp session'}</button>}</div>}
      </section>

      <section className="tlg-camp-filters">
        <label><span>Region</span><select value={continent} onChange={(event) => setContinent(event.target.value)}><option value="all">All regions</option>{continents.map((item) => <option value={item} key={item}>{item}</option>)}</select></label>
        <label><span>Camp type</span><select value={campType} onChange={(event) => setCampType(event.target.value as CampFilter)}><option value="all">All camp types</option><option value="hard">Hard Tennis Skills</option><option value="clay">Clay Tennis Skills</option><option value="grass">Grass Tennis Skills</option><option value="physical">Physical Development</option><option value="recovery">Recovery & Mindset</option></select></label>
        <label className="cost"><span>Max training fee / week: <strong>${maxCost.toLocaleString()}</strong></span><input type="range" min="1200" max="3400" step="100" value={maxCost} onChange={(event) => setMaxCost(Number(event.target.value))} /><small><span>$1,200</span><span>$3,400</span></small></label>
      </section>

      <div className="tlg-camp-browser">
        <section className="tlg-camp-list-panel">
          <header><div><span>AVAILABLE CAMPS</span><h2>Training camp destinations</h2></div><small>{filtered.length} offers · Page {page}/{pageCount}</small></header>
          <div className="tlg-camp-list">
            {visiblePrograms.map((program) => <button type="button" className={selected?.id === program.id ? 'selected' : ''} key={program.id} onClick={() => setSelectedId(program.id)}><div className="art"><CampArtwork program={program} /></div><div className="copy"><div className="title-row"><div><strong>{program.name}</strong><span>{program.location.city}, {program.location.country_code} · {qualityLabel(program.quality_tier)} training center</span></div><b>{qualityLabel(program.quality_tier)}</b></div><p>{program.description}</p><div className="price">Training fee from <strong>${program.weekly_cost.toLocaleString()}</strong> / week</div><div className="best">Best for: {program.benefit_summary}</div><div className="tags"><span>{categoryLabel(program)}</span><span>{program.quality_multiplier.toFixed(2)}× training quality</span></div></div></button>)}
            {visiblePrograms.length === 0 && <div className="empty">No camps match the selected filters.</div>}
          </div>
          <footer><button type="button" disabled={page <= 1} onClick={() => setPage((value) => Math.max(1, value - 1))}>Previous</button><span>Page {page} of {pageCount}</span><button type="button" disabled={page >= pageCount} onClick={() => setPage((value) => Math.min(pageCount, value + 1))}>Next</button></footer>
        </section>

        <aside className="tlg-camp-detail">
          {selected ? <><div className="hero"><CampArtwork program={selected} large /></div><div className="detail-body">
            <div className="detail-title"><div><h2>{selected.name}</h2><p>{selected.location.city}, {selected.location.country} · {selected.location.continent}</p></div><div className="rating"><strong>{qualityLabel(selected.quality_tier)}</strong><span>Training quality</span><b>{selected.quality_multiplier.toFixed(2)}× development</b></div></div>
            <div className="tlg-camp-information"><section><span>ABOUT {selected.location.city.toUpperCase()}</span><p>{selected.location.description}</p></section><section><span>ABOUT THIS CAMP</span><p>{selected.description}</p></section></div>
            <div className="benefits"><div><span>BEST FOR</span><strong>{selected.benefit_summary}</strong></div><div><span>PROGRAM</span><strong>{categoryLabel(selected)}</strong><small>{selected.quality_multiplier.toFixed(2)}× development quality</small></div></div>
            <div className="profile-grid">{Object.entries(selected.category === 'recovery_mindset' ? selected.condition_profile : selected.development_profile).sort((a, b) => Math.abs(Number(b[1])) - Math.abs(Number(a[1]))).slice(0, 6).map(([key, value]) => <div key={key}><span>{attributeLabel(key)}</span><strong>{Number(value) > 0 ? '+' : ''}{selected.category === 'recovery_mindset' ? Number(value) : `${Math.round(Number(value) * 100)}%`}</strong></div>)}</div>

            <div className="booking-grid"><label><span>Start week</span><select value={selectedWeek ? `${selectedWeek.season}-${selectedWeek.week}` : ''} onChange={(event) => setStartKey(event.target.value)}>{weekOptions.map((option) => <option value={`${option.season}-${option.week}`} key={`${option.season}-${option.week}`}>{formatWeek(option)}</option>)}</select></label><label><span>Duration</span><select value={durationWeeks} onChange={(event) => setDurationWeeks(Number(event.target.value))}>{Array.from({ length: maxDuration }, (_, index) => index + 1).map((weeks) => <option key={weeks} value={weeks}>{weeks} week{weeks === 1 ? '' : 's'} · {weeks * 7} days</option>)}</select></label></div>
            <div className="date-warning"><strong>Whole-week booking only</strong><p>Training camps always begin on Monday at the start of a competition week. Camp weeks take ownership of the calendar and are rejected if they overlap travel, injury, processed training or a tournament commitment.</p>{quote && <span>Selected period: Season {quote.start_season} · Week {quote.start_week} · {formatDay(quote.start)} – {formatDay(quote.end, quote.end.season !== quote.start.season)}</span>}</div>

            <section className="tlg-camp-accommodation"><header><div><span>ACCOMMODATION</span><h3>Choose hotel rating</h3></div><small>Stars belong to the hotel only. Better accommodation improves rest and recovery; it never directly increases permanent tennis skills.</small></header><div className="tlg-camp-hotel-grid">{accommodations.map((tier) => { const weekly = hotelWeeklyEstimate(tier, selected); return <button type="button" key={tier.id} className={accommodationSlug === tier.slug ? 'selected' : ''} onClick={() => setAccommodationSlug(tier.slug)}><span>{'★'.repeat(tier.star_rating)}</span><strong>{tier.name}</strong><b>${weekly.toLocaleString()} / week</b><p>{tier.description}</p><small>Rest {Math.round(tier.rest_quality * 100)}% · Fatigue mitigation {tier.fatigue_mitigation}/day{tier.weekly_morale_bonus > 0 ? ` · Morale +${tier.weekly_morale_bonus}/week` : ''}{tier.weekly_focus_bonus > 0 ? ` · Focus +${tier.weekly_focus_bonus}/week` : ''}</small></button> })}</div></section>

            <section className="tlg-camp-staff-selector">
              <header><div><span>TRAVELLING STAFF</span><h3>Choose who joins the camp</h3></div><small>Selected staff add one round-trip ticket and the same hotel accommodation to the quote. Camp bonuses apply only when the relevant staff member travels.</small></header>
              {staffLoading ? <div className="tlg-camp-staff-empty">Loading your staff…</div> : activeStaff.length === 0 ? <div className="tlg-camp-staff-empty">No staff employed. You can still book the camp without staff.</div> : <div className="tlg-camp-staff-options">{activeStaff.map((contract) => {
                const checked = selectedStaffIds.includes(contract.contract_id)
                const priced = quote?.staff?.find((item) => item.contract_id === contract.contract_id)
                return <label key={contract.contract_id} className={checked ? 'selected' : ''}><input type="checkbox" checked={checked} onChange={() => toggleStaff(contract.contract_id)} /><CountryFlag countryCode={contract.staff.country_code} countryName={contract.staff.country_code} width={24} height={16} /><div className="identity"><strong>{contract.staff.first_name} {contract.staff.last_name}</strong><span>{contract.role_label} · {contract.staff.overall_rating} · {contract.staff.specialty}</span><small>{campRoleBenefit(contract.role, selected)}</small></div><div className="cost">{checked ? <><strong>{priced ? `$${priced.total_cost.toLocaleString()}` : 'Calculating…'}</strong><span>{priced ? `$${priced.travel_cost.toLocaleString()} travel + $${priced.accommodation_cost.toLocaleString()} hotel` : 'travel + hotel'}</span></> : <span>Not travelling</span>}</div></label>
              })}</div>}
            </section>

            <section className="tlg-camp-cost-card"><header><div><span>BOOKING COST</span><h3>Transparent camp quote</h3></div>{quoteLoading && <small>Updating quote…</small>}</header>{quoteError && <div className="tlg-camp-quote-error">{quoteError}</div>}{quote && <><div className="tlg-camp-travel-summary"><div><span>TRAVEL FROM</span><strong>{quote.origin.city}, {quote.origin.country_code}</strong><small>{quote.travel.basis === 'country_centroid_distance' ? 'Country-based distance estimate. Exact city coordinates can replace this later automatically.' : quote.travel.basis === 'same_country_estimate' ? 'Domestic estimate because exact city distance is not available.' : quote.travel.basis === 'exact_city_match' ? 'Same-city local transfer.' : 'Fallback regional estimate.'}</small></div><div><span>DESTINATION</span><strong>{quote.destination.city}, {quote.destination.country_code}</strong><small>{quote.travel.one_way_km !== null ? `Approx. ${quote.travel.one_way_km.toLocaleString()} km one way · ${quote.travel.band}` : `${quote.travel.band} travel`}</small></div></div><div className="tlg-camp-cost-lines"><div><span>Training program</span><small>${quote.training_fee_weekly.toLocaleString()} × {quote.duration_weeks} week{quote.duration_weeks === 1 ? '' : 's'} · {qualityLabel(quote.training_quality.tier)} {quote.training_quality.multiplier.toFixed(2)}×</small><strong>${quote.training_fee_total.toLocaleString()}</strong></div><div><span>{quote.accommodation.stars}★ {quote.accommodation.name}</span><small>${quote.accommodation.base_weekly_cost.toLocaleString()} base × {quote.accommodation.destination_cost_index.toFixed(2)} city index = ${quote.accommodation.weekly_cost.toLocaleString()}/week</small><strong>${quote.accommodation.total.toLocaleString()}</strong></div><div><span>Player transfer</span><small>{quote.travel.formula}{quote.travel.round_trip_km !== null ? ` · ${quote.travel.round_trip_km.toLocaleString()} km round trip` : ''} · expected arrival fatigue +{quote.travel.arrival_fatigue}</small><strong>${quote.travel_cost.toLocaleString()}</strong></div><div><span>Staff travel & hotel</span><small>{quote.staff_count === 0 ? 'No travelling staff selected' : `${quote.staff_count} staff · $${quote.staff_travel_cost.toLocaleString()} travel + $${quote.staff_accommodation_cost.toLocaleString()} accommodation`}</small><strong>${quote.staff_cost.toLocaleString()}</strong></div></div><div className="tlg-camp-grand-total"><span>FINAL CAMP COST</span><strong>${quote.grand_total.toLocaleString()}</strong></div></>}</section>

            <button type="button" className="book" onClick={handleBook} disabled={saving || Boolean(activeOrPlanned) || quoteLoading || !quote || Boolean(quoteError)}>{saving ? 'Booking…' : activeOrPlanned ? 'Another camp is already planned' : quote ? `Book Training Camp · $${quote.grand_total.toLocaleString()}` : 'Book Training Camp'}</button>
            <small className="diminishing">Development remains strongest in week 1. Longer camps use the agreed diminishing-return factors: 100% · 95% · 85% · 75%.</small>
          </div></> : <div className="detail-empty">Choose a training camp to see its details.</div>}
        </aside>
      </div>
    </div>
  )
}
