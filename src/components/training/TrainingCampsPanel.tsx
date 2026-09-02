import { useEffect, useMemo, useState } from 'react'

import { useTrainingCamps, type TrainingCampProgram } from '../../hooks/useTrainingCamps'
import '../../styles/training-camps.css'

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]
const MONTH_LENGTHS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const PAGE_SIZE = 10

type GameDay = { season: number; month: number; day: number }
type CampFilter = 'all' | 'hard' | 'clay' | 'grass' | 'physical' | 'recovery'

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

function formatDay(day: GameDay, includeSeason = false) {
  return `${MONTH_NAMES[day.month - 1]} ${day.day}${includeSeason ? ` · Season ${day.season}` : ''}`
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
    return_skill: 'Return',
    drop_shot: 'Drop Shot',
    serve: 'Serve', forehand: 'Forehand', backhand: 'Backhand', volley: 'Volley',
    slice: 'Slice', lob: 'Lob', smash: 'Smash', fitness: 'Fitness', stamina: 'Stamina',
    recovery: 'Recovery', movement: 'Movement', fatigue: 'Fatigue', morale: 'Morale',
    confidence: 'Confidence', sharpness: 'Sharpness', focus: 'Focus',
  }
  return labels[value] ?? value
}

function filterMatches(program: TrainingCampProgram, filter: CampFilter) {
  if (filter === 'all') return true
  if (filter === 'physical') return program.category === 'physical'
  if (filter === 'recovery') return program.category === 'recovery_mindset'
  return program.category === 'tennis_skills' && program.surface === filter
}

function CampArtwork({ program, large = false }: { program: TrainingCampProgram; large?: boolean }) {
  const image = large ? (program.location.image_url ?? program.location.thumbnail_url) : (program.location.thumbnail_url ?? program.location.image_url)
  if (image) return <img src={image} alt="" />

  return (
    <div className={`tlg-camp-art-placeholder ${program.category} ${program.surface ?? ''}`}>
      <span>{program.location.country_code}</span>
      <strong>{program.location.city}</strong>
      <small>{categoryLabel(program)}</small>
    </div>
  )
}

export default function TrainingCampsPanel({ gameDay }: { gameDay: GameDay }) {
  const {
    programs, bookings, loading, saving, processing, error,
    bookCamp, cancelCamp, processToday,
  } = useTrainingCamps()

  const [continent, setContinent] = useState('all')
  const [campType, setCampType] = useState<CampFilter>('all')
  const [maxCost, setMaxCost] = useState(3400)
  const [page, setPage] = useState(1)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [startOffset, setStartOffset] = useState(0)
  const [durationWeeks, setDurationWeeks] = useState(1)
  const [actionMessage, setActionMessage] = useState<string | null>(null)

  const currentAbsolute = absoluteDay(gameDay)
  const continents = useMemo(() => Array.from(new Set(programs.map((program) => program.location.continent))).sort(), [programs])

  const filtered = useMemo(() => programs.filter((program) => (
    (continent === 'all' || program.location.continent === continent) &&
    filterMatches(program, campType) &&
    program.weekly_cost <= maxCost
  )), [programs, continent, campType, maxCost])

  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const visiblePrograms = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)
  const selected = programs.find((program) => program.id === selectedId) ?? visiblePrograms[0] ?? null

  const activeOrPlanned = bookings.find((booking) => (
    booking.status === 'active' || (booking.status === 'booked' && currentAbsolute <= booking.end_absolute_day)
  )) ?? null

  const startOptions = useMemo(() => Array.from({ length: 85 }, (_, offset) => ({
    offset,
    day: fromAbsolute(currentAbsolute + offset),
  })), [currentAbsolute])

  const selectedStart = fromAbsolute(currentAbsolute + startOffset)
  const selectedEnd = fromAbsolute(currentAbsolute + startOffset + durationWeeks * 7 - 1)
  const totalCost = selected ? selected.weekly_cost * durationWeeks : 0

  useEffect(() => {
    setPage(1)
  }, [continent, campType, maxCost])

  useEffect(() => {
    if (!selectedId || !filtered.some((program) => program.id === selectedId)) {
      setSelectedId(filtered[0]?.id ?? null)
    }
  }, [filtered, selectedId])

  useEffect(() => {
    if (page > pageCount) setPage(pageCount)
  }, [page, pageCount])

  async function handleBook() {
    if (!selected) return
    setActionMessage(null)
    const result = await bookCamp(selected.id, selectedStart, durationWeeks)
    if (result) setActionMessage(`${selected.name} booked successfully.`)
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

  if (loading && programs.length === 0) {
    return <div className="tlg-camp-loading">Loading training camp destinations…</div>
  }

  return (
    <div className="tlg-camp-page">
      {error && <div className="tlg-training-alert tlg-training-alert-error">{error}</div>}
      {actionMessage && <div className="tlg-training-alert">{actionMessage}</div>}

      <section className="tlg-camp-current">
        <div>
          <span>CURRENT / PLANNED TRAINING CAMP</span>
          {activeOrPlanned ? (
            <>
              <h2>{activeOrPlanned.program.name}</h2>
              <p>
                {activeOrPlanned.program.location.city}, {activeOrPlanned.program.location.country} · {formatDay({ season: activeOrPlanned.start_season, month: activeOrPlanned.start_month, day: activeOrPlanned.start_day })}–{formatDay({ season: activeOrPlanned.end_season, month: activeOrPlanned.end_month, day: activeOrPlanned.end_day })} · {activeOrPlanned.duration_weeks} week{activeOrPlanned.duration_weeks === 1 ? '' : 's'}
              </p>
            </>
          ) : (
            <>
              <h2>No training camp booked</h2>
              <p>Select a destination, choose a start day and reserve up to four consecutive weeks.</p>
            </>
          )}
        </div>
        {activeOrPlanned && (
          <div className="tlg-camp-current-actions">
            <span className={`status ${activeOrPlanned.status}`}>{activeOrPlanned.status}</span>
            <strong>${activeOrPlanned.total_cost.toLocaleString()}</strong>
            {currentAbsolute < activeOrPlanned.start_absolute_day && (
              <button type="button" onClick={handleCancel} disabled={saving}>Cancel booking</button>
            )}
            {currentAbsolute >= activeOrPlanned.start_absolute_day && currentAbsolute <= activeOrPlanned.end_absolute_day && (
              <button type="button" className="primary" onClick={handleProcessToday} disabled={processing}>
                {processing ? 'Processing…' : 'Process today’s camp session'}
              </button>
            )}
          </div>
        )}
      </section>

      <section className="tlg-camp-filters">
        <label>
          <span>Region</span>
          <select value={continent} onChange={(event) => setContinent(event.target.value)}>
            <option value="all">All regions</option>
            {continents.map((item) => <option value={item} key={item}>{item}</option>)}
          </select>
        </label>
        <label>
          <span>Camp type</span>
          <select value={campType} onChange={(event) => setCampType(event.target.value as CampFilter)}>
            <option value="all">All camp types</option>
            <option value="hard">Hard Tennis Skills</option>
            <option value="clay">Clay Tennis Skills</option>
            <option value="grass">Grass Tennis Skills</option>
            <option value="physical">Physical Development</option>
            <option value="recovery">Recovery & Mindset</option>
          </select>
        </label>
        <label className="cost">
          <span>Max weekly cost: <strong>${maxCost.toLocaleString()}</strong></span>
          <input type="range" min="1200" max="3400" step="100" value={maxCost} onChange={(event) => setMaxCost(Number(event.target.value))} />
          <small><span>$1,200</span><span>$3,400</span></small>
        </label>
      </section>

      <div className="tlg-camp-browser">
        <section className="tlg-camp-list-panel">
          <header>
            <div><span>AVAILABLE CAMPS</span><h2>Training camp destinations</h2></div>
            <small>{filtered.length} offers · Page {page}/{pageCount}</small>
          </header>

          <div className="tlg-camp-list">
            {visiblePrograms.map((program) => (
              <button type="button" className={selected?.id === program.id ? 'selected' : ''} key={program.id} onClick={() => setSelectedId(program.id)}>
                <div className="art"><CampArtwork program={program} /></div>
                <div className="copy">
                  <div className="title-row">
                    <div>
                      <strong>{program.name}</strong>
                      <span>{program.location.city}, {program.location.country_code} · {qualityLabel(program.quality_tier)}</span>
                    </div>
                    <b>{program.rating.toFixed(1)} ★</b>
                  </div>
                  <p>{program.description}</p>
                  <div className="price">From <strong>${program.weekly_cost.toLocaleString()}</strong> / week</div>
                  <div className="best">Best for: {program.benefit_summary}</div>
                  <div className="tags"><span>{categoryLabel(program)}</span><span>{qualityLabel(program.quality_tier)}</span></div>
                </div>
              </button>
            ))}
            {visiblePrograms.length === 0 && <div className="empty">No camps match the selected filters.</div>}
          </div>

          <footer>
            <button type="button" disabled={page <= 1} onClick={() => setPage((value) => Math.max(1, value - 1))}>Previous</button>
            <span>Page {page} of {pageCount}</span>
            <button type="button" disabled={page >= pageCount} onClick={() => setPage((value) => Math.min(pageCount, value + 1))}>Next</button>
          </footer>
        </section>

        <aside className="tlg-camp-detail">
          {selected ? (
            <>
              <div className="hero"><CampArtwork program={selected} large /></div>
              <div className="detail-body">
                <div className="detail-title">
                  <div><h2>{selected.name}</h2><p>{selected.location.city}, {selected.location.country} · {selected.location.continent}</p></div>
                  <div className="rating"><strong>{selected.rating.toFixed(1)} ★</strong><span>{qualityLabel(selected.quality_tier)}</span></div>
                </div>

                <p className="description">{selected.description}</p>

                <div className="benefits">
                  <div><span>BEST FOR</span><strong>{selected.benefit_summary}</strong></div>
                  <div><span>PROGRAM</span><strong>{categoryLabel(selected)}</strong><small>{selected.quality_multiplier.toFixed(2)}× quality multiplier</small></div>
                </div>

                <div className="profile-grid">
                  {Object.entries(selected.category === 'recovery_mindset' ? selected.condition_profile : selected.development_profile)
                    .sort((a, b) => Math.abs(Number(b[1])) - Math.abs(Number(a[1])))
                    .slice(0, 6)
                    .map(([key, value]) => (
                      <div key={key}><span>{attributeLabel(key)}</span><strong>{Number(value) > 0 ? '+' : ''}{selected.category === 'recovery_mindset' ? Number(value) : `${Math.round(Number(value) * 100)}%`}</strong></div>
                    ))}
                </div>

                <div className="booking-grid">
                  <label>
                    <span>Start day</span>
                    <select value={startOffset} onChange={(event) => setStartOffset(Number(event.target.value))}>
                      {startOptions.map((option) => <option value={option.offset} key={option.offset}>{formatDay(option.day, option.day.season !== gameDay.season)}</option>)}
                    </select>
                  </label>
                  <label>
                    <span>Duration</span>
                    <select value={durationWeeks} onChange={(event) => setDurationWeeks(Number(event.target.value))}>
                      {[1, 2, 3, 4].map((weeks) => <option key={weeks} value={weeks}>{weeks} week{weeks === 1 ? '' : 's'} · {weeks * 7} days</option>)}
                    </select>
                  </label>
                </div>

                <div className="date-warning">
                  <strong>Check the dates before booking</strong>
                  <p>Camp days take ownership of the calendar and block regular training. A reservation is rejected if it overlaps travel, injury, processed training, another camp, or an active tournament application/commitment.</p>
                  <span>Selected period: {formatDay(selectedStart)} – {formatDay(selectedEnd, selectedEnd.season !== selectedStart.season)}</span>
                </div>

                <div className="cost-summary">
                  <div><span>Weekly cost</span><strong>${selected.weekly_cost.toLocaleString()}</strong></div>
                  <div><span>Duration</span><strong>{durationWeeks} week{durationWeeks === 1 ? '' : 's'}</strong></div>
                  <div><span>Total camp cost</span><strong>${totalCost.toLocaleString()}</strong></div>
                </div>

                <button type="button" className="book" onClick={handleBook} disabled={saving || Boolean(activeOrPlanned)}>
                  {saving ? 'Booking…' : activeOrPlanned ? 'Another camp is already planned' : 'Book Training Camp'}
                </button>
                <small className="diminishing">Development remains strongest in week 1. Longer camps use the agreed diminishing-return factors: 100% · 95% · 85% · 75%.</small>
              </div>
            </>
          ) : <div className="detail-empty">Choose a training camp to see its details.</div>}
        </aside>
      </div>
    </div>
  )
}
