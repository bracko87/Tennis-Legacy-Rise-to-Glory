import { createPortal } from 'react-dom'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useParams } from 'react-router'

import { supabase } from '../../lib/supabase'
import '../../styles/tournament-entry-lifecycle.css'

interface GameMoment {
  game_second: number
  absolute_day: number
  season: number
  month: number
  day: number
  season_week: number
  minute_of_day: number
  hour: number
  minute: number
}

interface EntryWave {
  fixed_wave: number
  position: number
  wave_count: number
  label: string
}

interface PendingApplication {
  competition_id: string
  tournament_name: string
}

interface WeekApplication {
  competition_id: string
  tournament_name: string
  accept_qualification: boolean
  status: string
  decision_reason: string | null
}

interface TournamentEntryLifecycleData {
  competition_id: string
  world: 'ATP' | 'WTA'
  phase: string
  field_locked: boolean
  draw_published: boolean
  entry_wave: EntryWave
  timeline: {
    applications_open: GameMoment
    normal_applications_close: GameMoment
    field_announcement: GameMoment
    late_entry_open: GameMoment
    late_entry_close: GameMoment
    draw_publish: GameMoment
    tournament_start: GameMoment
    target_season_week: number
    tournament_start_week: number
  }
  vacancies: {
    main_draw: number
    qualification: number
    main_draw_capacity: number
    qualification_capacity: number
  }
  user: {
    application_status: string | null
    accept_qualification: boolean | null
    application_source: string | null
    entry_draw_type: 'main_draw' | 'qualification' | null
    entry_status: string | null
    week_applications: WeekApplication[]
    pending_application: PendingApplication | null
    pending_application_locked: boolean
    can_apply_normal: boolean
    can_apply_late: boolean
    preparation_deadline: GameMoment | null
  }
  rules: {
    entry_model: string
    max_active_applications: number
    qualification_opt_in: boolean
    final_vacancy_entry: boolean
    match_tactic_lock_minutes: number
    preparation_lock_hours_before_departure: number
  }
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function formatMoment(moment: GameMoment | null | undefined) {
  if (!moment) return 'TBD'
  return `${MONTHS[moment.month - 1] ?? `M${moment.month}`} ${moment.day} · ${String(moment.hour).padStart(2, '0')}:${String(moment.minute).padStart(2, '0')}`
}

function phaseLabel(phase: string) {
  switch (phase) {
    case 'applications_not_open': return 'Applications not open'
    case 'applications_open': return 'Applications open'
    case 'selection_complete': return 'Selection complete'
    case 'final_vacancies_open': return 'Final vacancies open'
    case 'field_locked': return 'Final field locked'
    case 'draw_published': return 'Draw published'
    case 'in_progress': return 'Tournament in progress'
    case 'completed': return 'Tournament completed'
    default: return phase.replaceAll('_', ' ')
  }
}

function personalStatus(data: TournamentEntryLifecycleData) {
  const user = data.user
  if (user.entry_status === 'eliminated') return 'Eliminated'
  if (user.entry_draw_type === 'main_draw' && user.entry_status === 'active') return 'Accepted · Main Draw'
  if (user.entry_draw_type === 'qualification' && user.entry_status === 'active') return 'Accepted · Qualification'
  switch (user.application_status) {
    case 'accepted_main_draw': return 'Accepted · Main Draw'
    case 'accepted_qualification': return 'Accepted · Qualification'
    case 'applied': return 'Application pending'
    case 'rejected': return 'Application rejected'
    case 'superseded': return 'Application replaced'
    case 'withdrawn': return 'Application withdrawn'
    default: return 'Not applied'
  }
}

function milestoneIndex(phase: string) {
  switch (phase) {
    case 'applications_not_open': return -1
    case 'applications_open': return 0
    case 'selection_complete': return 1
    case 'final_vacancies_open': return 2
    case 'field_locked': return 3
    case 'draw_published': return 4
    case 'in_progress': return 5
    case 'completed': return 6
    default: return -1
  }
}

export default function TournamentEntryLifecycle() {
  const { competitionId } = useParams()
  const [target, setTarget] = useState<HTMLElement | null>(null)
  const [data, setData] = useState<TournamentEntryLifecycleData | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [acceptQualification, setAcceptQualification] = useState(true)

  useEffect(() => {
    let frame = 0
    let cancelled = false
    let host: HTMLElement | null = null

    const findTarget = () => {
      if (cancelled) return
      const page = document.querySelector<HTMLElement>('.tlg-detail-page')
      const stats = document.querySelector<HTMLElement>('.tlg-detail-stats-grid')
      if (page && stats) {
        page.classList.add('tlg-entry-lifecycle-enabled')
        const existing = page.querySelector<HTMLElement>('[data-tlg-entry-lifecycle-host="true"]')
        host = existing ?? document.createElement('div')
        if (!existing) {
          host.dataset.tlgEntryLifecycleHost = 'true'
          host.className = 'tlg-entry-lifecycle-host'
          stats.insertAdjacentElement('afterend', host)
        }
        setTarget(host)
        return
      }
      frame = window.requestAnimationFrame(findTarget)
    }

    frame = window.requestAnimationFrame(findTarget)
    return () => {
      cancelled = true
      window.cancelAnimationFrame(frame)
      const page = document.querySelector<HTMLElement>('.tlg-detail-page')
      page?.classList.remove('tlg-entry-lifecycle-enabled')
      host?.remove()
      setTarget(null)
    }
  }, [competitionId])

  const load = useCallback(async () => {
    if (!competitionId) return
    const { data: lifecycle, error: loadError } = await supabase.rpc('get_tournament_entry_lifecycle_v2', { p_competition_id: competitionId })
    if (loadError) {
      setError(loadError.message)
      setLoading(false)
      return
    }
    const next = lifecycle as TournamentEntryLifecycleData
    setData(next)
    setError(null)
    setLoading(false)
    if (typeof next?.user?.accept_qualification === 'boolean') setAcceptQualification(next.user.accept_qualification)
  }, [competitionId])

  useEffect(() => {
    void load()
    const timer = window.setInterval(() => void load(), 15000)
    return () => window.clearInterval(timer)
  }, [load])

  async function applyNormal() {
    if (!competitionId) return
    setBusy(true)
    setError(null)
    const { error: mutationError } = await supabase.rpc('apply_to_tournament_v3', {
      p_competition_id: competitionId,
      p_accept_qualification: acceptQualification,
    })
    if (mutationError) setError(mutationError.message)
    await load()
    setBusy(false)
  }

  async function withdraw() {
    if (!competitionId) return
    setBusy(true)
    setError(null)
    const { error: mutationError } = await supabase.rpc('withdraw_tournament_application_v1', { p_competition_id: competitionId })
    if (mutationError) setError(mutationError.message)
    await load()
    setBusy(false)
  }

  async function applyLate() {
    if (!competitionId) return
    setBusy(true)
    setError(null)
    const { error: mutationError } = await supabase.rpc('apply_late_tournament_entry_v1', {
      p_competition_id: competitionId,
      p_accept_qualification: acceptQualification,
    })
    if (mutationError) setError(mutationError.message)
    await load()
    setBusy(false)
  }

  const milestones = useMemo(() => data ? [
    { label: 'Applications open', moment: data.timeline.applications_open },
    { label: `${data.entry_wave.label} selection`, moment: data.timeline.normal_applications_close },
    { label: 'Final vacancy window', moment: data.timeline.late_entry_open },
    { label: 'Final field locked', moment: data.timeline.late_entry_close },
    { label: 'Draw published', moment: data.timeline.draw_publish },
    { label: 'Tournament begins', moment: data.timeline.tournament_start },
  ] : [], [data])

  if (!target) return null

  const currentMilestone = data ? milestoneIndex(data.phase) : -1
  const currentApplicationIsPending = data?.user.application_status === 'applied'
  const pendingApplication = data?.user.pending_application ?? null
  const hasOtherPending = Boolean(pendingApplication && pendingApplication.competition_id !== data?.competition_id)
  const pendingIsCurrent = Boolean(pendingApplication && pendingApplication.competition_id === data?.competition_id)

  return createPortal(
    <section className="tlg-detail-panel tlg-entry-lifecycle-panel">
      <header className="tlg-detail-panel-head tlg-entry-lifecycle-head">
        <div>
          <span>Tournament entry</span>
          <h2>Application & entry timeline</h2>
          <p>One active application is allowed per target week. Higher tournament levels resolve first; if you miss the field, lower entry waves remain available. Acceptance uses the latest published Monday ranking.</p>
        </div>
        {data && <strong className={`tlg-entry-phase phase-${data.phase}`}>{phaseLabel(data.phase)}</strong>}
      </header>

      {loading ? <div className="tlg-entry-loading">Loading tournament entry timeline…</div> : error && !data ? <div className="tlg-entry-error">{error}</div> : data ? (
        <>
          <div className="tlg-entry-milestones">
            {milestones.map((item, index) => (
              <article key={item.label} className={index < currentMilestone ? 'done' : index === currentMilestone ? 'current' : ''}>
                <span>{index + 1}</span>
                <div><strong>{item.label}</strong><small>{formatMoment(item.moment)}</small></div>
              </article>
            ))}
          </div>

          <div className="tlg-entry-content-grid">
            <div className="tlg-entry-personal-card">
              <div className="tlg-entry-personal-head">
                <div><span>Your status</span><strong>{personalStatus(data)}</strong></div>
                <div className="tlg-entry-vacancy-mini"><span>Main vacancies {data.vacancies.main_draw}</span><span>Qualifying vacancies {data.vacancies.qualification}</span></div>
              </div>

              {pendingApplication && (
                <div className={`tlg-entry-current-application ${pendingIsCurrent ? 'current' : ''}`}>
                  <span>Current Week {data.timeline.target_season_week} application</span>
                  <strong>{pendingApplication.tournament_name}</strong>
                  <small>{pendingIsCurrent
                    ? 'This tournament is your active application.'
                    : data.user.pending_application_locked
                      ? 'That tournament is currently in selection. Wait for its decision before choosing another event.'
                      : 'Applying here will replace that still-open application.'}</small>
                </div>
              )}

              {data.user.can_apply_normal && (
                <div className="tlg-entry-application-controls">
                  <div className="tlg-entry-deadline-callout">
                    <span>{data.entry_wave.label}</span>
                    <strong>Selection closes {formatMoment(data.timeline.normal_applications_close)}</strong>
                    <small>Entry wave {data.entry_wave.position} of {data.entry_wave.wave_count} for this tournament group. Missing higher levels are skipped automatically.</small>
                  </div>
                  <label className="tlg-entry-qual-toggle">
                    <input type="checkbox" checked={acceptQualification} onChange={(event) => setAcceptQualification(event.target.checked)} disabled={busy} />
                    <span><strong>Accept Qualification</strong><small>If Main Draw is unavailable, keep this tournament as an option through qualifying.</small></span>
                  </label>
                  <div className="tlg-entry-actions">
                    <button type="button" className="primary" disabled={busy} onClick={() => void applyNormal()}>
                      {currentApplicationIsPending ? 'Update application' : hasOtherPending ? 'Switch application' : 'Apply to tournament'}
                    </button>
                    {currentApplicationIsPending && <button type="button" disabled={busy} onClick={() => void withdraw()}>Withdraw</button>}
                  </div>
                </div>
              )}

              {data.user.can_apply_late && (
                <div className="tlg-entry-late-box">
                  <div><strong>Final Vacancy is open</strong><span>You have no commitment for this tournament week. Only genuine remaining Main Draw or Qualification vacancies can be taken.</span></div>
                  <label><input type="checkbox" checked={acceptQualification} onChange={(event) => setAcceptQualification(event.target.checked)} disabled={busy} /> Accept Qualification</label>
                  <button type="button" disabled={busy} onClick={() => void applyLate()}>Take available vacancy</button>
                </div>
              )}

              {!data.user.can_apply_normal && !data.user.can_apply_late && data.user.entry_status == null && !currentApplicationIsPending && (
                <p className="tlg-entry-passive-note">No entry action is available for this tournament at this stage. Follow the selection timeline above or choose another tournament whose entry wave is still open.</p>
              )}

              {error && <div className="tlg-entry-error inline">{error}</div>}
            </div>

            <aside className="tlg-entry-deadlines-card">
              <span>Personal deadlines</span>
              <div><strong>Tournament preparation</strong><small>{data.user.preparation_deadline ? `${formatMoment(data.user.preparation_deadline)} · locks 24h before planned departure` : 'Calculated once your tournament trip is scheduled · locks 24h before departure'}</small></div>
              <div><strong>Match-specific tactic</strong><small>Locks 60 minutes before the scheduled match start. If a match time changes, this deadline moves with it.</small></div>
              <div><strong>Ranking basis</strong><small>Entry decisions use the official published Monday ranking. Pending weekly ranking points do not reseed an already decided field.</small></div>
            </aside>
          </div>
        </>
      ) : null}
    </section>,
    target,
  )
}
