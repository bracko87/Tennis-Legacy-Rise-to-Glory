import { createPortal } from 'react-dom'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router'

import CountryFlag from '../common/CountryFlag'
import { supabase } from '../../lib/supabase'
import '../../styles/tournament-experience-enhancements.css'

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

interface LifecycleData {
  phase: string
  timeline: {
    applications_open: GameMoment
    normal_applications_close: GameMoment
    draw_publish: GameMoment
  }
  user: {
    application_status: string | null
    entry_draw_type: 'main_draw' | 'qualification' | null
    entry_status: string | null
  }
}

interface ApplicantRow {
  application_id: string
  player_id: string
  first_name: string
  last_name: string
  country_code: string | null
  player_type: 'human' | 'ai'
  world_rank: number
  priority: number | null
  accept_qualification: boolean
  application_source: string
  application_status: string
  decision_reason: string | null
  entry_draw_type: 'main_draw' | 'qualification' | null
  entry_status: string | null
  is_user: boolean
  projected_group: 'main_draw' | 'qualification' | 'outside'
}

interface ApplicationFieldData {
  tournament_name: string
  world: 'ATP' | 'WTA'
  phase: string
  main_draw_total_capacity: number
  direct_main_draw_slots: number
  qualifier_slots: number
  qualification_capacity: number
  applicant_count: number
  applicants: ApplicantRow[]
}

interface DrawMatch {
  match_id: string
  draw_type: 'main_draw' | 'qualification'
  round_number: number
  round_label: string
  match_number: number
  match_status: string
  player1_id: string | null
  player1_first_name: string | null
  player1_last_name: string | null
  player1_country_code: string | null
  player1_seed: number | null
  player1_set_scores: number[]
  player2_id: string | null
  player2_first_name: string | null
  player2_last_name: string | null
  player2_country_code: string | null
  player2_seed: number | null
  player2_set_scores: number[]
  winner_id: string | null
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function formatMoment(moment?: GameMoment | null) {
  if (!moment) return 'TBD'
  return `${MONTHS[moment.month - 1] ?? `M${moment.month}`} ${moment.day} · ${String(moment.hour).padStart(2, '0')}:${String(moment.minute).padStart(2, '0')}`
}

function phaseLabel(value: string) {
  return value.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function personalStatus(data: LifecycleData | null) {
  if (!data) return 'Loading…'
  if (data.user.entry_status === 'eliminated') return 'Eliminated'
  if (data.user.entry_draw_type === 'main_draw' && data.user.entry_status === 'active') return 'Accepted · Main Draw'
  if (data.user.entry_draw_type === 'qualification' && data.user.entry_status === 'active') return 'Accepted · Qualification'
  if (data.user.application_status === 'accepted_main_draw') return 'Accepted · Main Draw'
  if (data.user.application_status === 'accepted_qualification') return 'Accepted · Qualification'
  if (data.user.application_status === 'applied') return 'Application pending'
  if (data.user.application_status === 'rejected') return 'Application rejected'
  if (data.user.application_status === 'withdrawn') return 'Application withdrawn'
  return 'Not applied'
}

function groupLabel(group: ApplicantRow['projected_group']) {
  if (group === 'main_draw') return 'Main Draw'
  if (group === 'qualification') return 'Qualification'
  return 'Outside current field'
}

function drawPlayerName(match: DrawMatch, side: 1 | 2) {
  const first = side === 1 ? match.player1_first_name : match.player2_first_name
  const last = side === 1 ? match.player1_last_name : match.player2_last_name
  return `${first ?? ''} ${last ?? ''}`.trim() || 'TBD'
}

function setScore(match: DrawMatch, side: 1 | 2) {
  const scores = side === 1 ? match.player1_set_scores : match.player2_set_scores
  return Array.isArray(scores) && scores.length ? scores.join(' ') : '—'
}

function QualificationPlayer({ match, side }: { match: DrawMatch; side: 1 | 2 }) {
  const playerId = side === 1 ? match.player1_id : match.player2_id
  const countryCode = side === 1 ? match.player1_country_code : match.player2_country_code
  const seed = side === 1 ? match.player1_seed : match.player2_seed
  const winner = Boolean(playerId && playerId === match.winner_id)
  const name = drawPlayerName(match, side)
  return (
    <div className={`tlg-qualification-player${winner ? ' winner' : ''}`}>
      <span className="flag">{countryCode ? <CountryFlag countryCode={countryCode} countryName={countryCode} width={19} height={13} /> : null}</span>
      {playerId ? <Link to={`/game/players/${playerId}`}>{name}</Link> : <strong>{name}</strong>}
      <span className="seed">{seed ? `(${seed})` : ''}</span>
      <b>{setScore(match, side)}</b>
    </div>
  )
}

export default function TournamentExperienceEnhancements() {
  const { competitionId } = useParams()
  const [lifecycle, setLifecycle] = useState<LifecycleData | null>(null)
  const [field, setField] = useState<ApplicationFieldData | null>(null)
  const [drawMatches, setDrawMatches] = useState<DrawMatch[]>([])
  const [drawView, setDrawView] = useState<'main_draw' | 'qualification'>('main_draw')
  const [heroHost, setHeroHost] = useState<HTMLElement | null>(null)
  const [fieldHost, setFieldHost] = useState<HTMLElement | null>(null)
  const [drawControlHost, setDrawControlHost] = useState<HTMLElement | null>(null)
  const [drawBodyHost, setDrawBodyHost] = useState<HTMLElement | null>(null)

  const load = useCallback(async () => {
    if (!competitionId) return
    const [lifecycleResponse, fieldResponse, drawResponse] = await Promise.all([
      supabase.rpc('get_tournament_entry_lifecycle_v2', { p_competition_id: competitionId }),
      supabase.rpc('get_tournament_application_field_v1', { p_competition_id: competitionId }),
      supabase.rpc('get_tournament_draw_v1', { p_competition_id: competitionId }),
    ])
    if (!lifecycleResponse.error && lifecycleResponse.data) setLifecycle(lifecycleResponse.data as LifecycleData)
    if (!fieldResponse.error && fieldResponse.data) setField(fieldResponse.data as ApplicationFieldData)
    if (!drawResponse.error) setDrawMatches((drawResponse.data ?? []) as DrawMatch[])
  }, [competitionId])

  useEffect(() => {
    void load()
    const timer = window.setInterval(() => void load(), 10000)
    return () => window.clearInterval(timer)
  }, [load])

  useEffect(() => {
    let frame = 0
    let cancelled = false
    const created: HTMLElement[] = []

    function hostAfter(anchor: Element | null, attr: string, className: string) {
      if (!anchor || !anchor.parentElement) return null
      const selector = `[data-${attr}="true"]`
      const existing = anchor.parentElement.querySelector<HTMLElement>(selector)
      if (existing) return existing
      const host = document.createElement('div')
      host.dataset[attr.replace(/-([a-z])/g, (_, letter) => letter.toUpperCase())] = 'true'
      host.className = className
      anchor.insertAdjacentElement('afterend', host)
      created.push(host)
      return host
    }

    function findTargets() {
      if (cancelled) return
      const tags = document.querySelector('.tlg-detail-hero-copy .tlg-detail-tags')
      if (tags && !heroHost) setHeroHost(hostAfter(tags, 'tlg-hero-entry-host', 'tlg-hero-entry-host'))

      const personalHead = document.querySelector('.tlg-entry-personal-card .tlg-entry-personal-head')
      if (personalHead && !fieldHost) setFieldHost(hostAfter(personalHead, 'tlg-applicant-field-host', 'tlg-applicant-field-host'))

      const drawPanel = document.querySelector<HTMLElement>('.tlg-live-draw-panel')
      const drawHead = drawPanel?.querySelector<HTMLElement>('.tlg-live-draw-head') ?? null
      if (drawPanel && drawHead) {
        if (!drawControlHost) {
          let control = drawHead.querySelector<HTMLElement>('[data-tlg-draw-switch-host="true"]')
          if (!control) {
            control = document.createElement('div')
            control.dataset.tlgDrawSwitchHost = 'true'
            control.className = 'tlg-draw-switch-host'
            const status = drawHead.querySelector('.tlg-live-draw-status')
            if (status) drawHead.insertBefore(control, status)
            else drawHead.appendChild(control)
            created.push(control)
          }
          setDrawControlHost(control)
        }
        if (!drawBodyHost) {
          let body = drawPanel.querySelector<HTMLElement>('[data-tlg-qualification-body-host="true"]')
          if (!body) {
            body = document.createElement('div')
            body.dataset.tlgQualificationBodyHost = 'true'
            body.className = 'tlg-qualification-body-host'
            drawHead.insertAdjacentElement('afterend', body)
            created.push(body)
          }
          setDrawBodyHost(body)
        }
      }

      if (!tags || !personalHead || !drawPanel) frame = window.requestAnimationFrame(findTargets)
    }

    frame = window.requestAnimationFrame(findTargets)
    return () => {
      cancelled = true
      window.cancelAnimationFrame(frame)
      document.querySelector<HTMLElement>('.tlg-live-draw-panel')?.classList.remove('tlg-live-draw-show-qualification')
      created.forEach((element) => element.remove())
      setHeroHost(null)
      setFieldHost(null)
      setDrawControlHost(null)
      setDrawBodyHost(null)
    }
  }, [competitionId, drawControlHost, drawBodyHost, fieldHost, heroHost])

  const qualificationMatches = useMemo(() => drawMatches.filter((match) => match.draw_type === 'qualification'), [drawMatches])
  const qualificationRounds = useMemo(() => {
    const map = new Map<number, DrawMatch[]>()
    for (const match of qualificationMatches) {
      const rows = map.get(match.round_number) ?? []
      rows.push(match)
      map.set(match.round_number, rows)
    }
    return Array.from(map.entries()).sort(([a], [b]) => a - b).map(([round, matches]) => ({
      round,
      label: matches[0]?.round_label ?? `Qualification Round ${round}`,
      matches: matches.sort((a, b) => a.match_number - b.match_number),
    }))
  }, [qualificationMatches])

  useEffect(() => {
    const panel = document.querySelector<HTMLElement>('.tlg-live-draw-panel')
    if (!panel) return
    panel.classList.toggle('tlg-live-draw-show-qualification', drawView === 'qualification')
    const title = panel.querySelector<HTMLElement>('.tlg-live-draw-head h2')
    const copy = panel.querySelector<HTMLElement>('.tlg-live-draw-head p')
    if (title) title.textContent = drawView === 'qualification' ? 'Qualification bracket' : 'Knockout bracket'
    if (copy && drawView === 'qualification') copy.textContent = qualificationMatches.length ? `${qualificationMatches.length} qualification matches · completed results remain available after qualification ends` : 'Qualification bracket history'
  }, [drawView, qualificationMatches.length])

  const groupedApplicants = useMemo(() => ({
    main_draw: field?.applicants.filter((row) => row.projected_group === 'main_draw') ?? [],
    qualification: field?.applicants.filter((row) => row.projected_group === 'qualification') ?? [],
    outside: field?.applicants.filter((row) => row.projected_group === 'outside') ?? [],
  }), [field])

  return (
    <>
      {heroHost && lifecycle && createPortal(
        <div className="tlg-hero-entry-summary">
          <div className="tlg-hero-entry-dates">
            <article><span>Applications open</span><strong>{formatMoment(lifecycle.timeline.applications_open)}</strong></article>
            <article><span>Applications close</span><strong>{formatMoment(lifecycle.timeline.normal_applications_close)}</strong></article>
            <article><span>Draw published</span><strong>{formatMoment(lifecycle.timeline.draw_publish)}</strong></article>
          </div>
          <div className="tlg-hero-entry-status"><span>{phaseLabel(lifecycle.phase)}</span><strong>You: <b>{personalStatus(lifecycle)}</b></strong></div>
        </div>,
        heroHost,
      )}

      {fieldHost && field && createPortal(
        <div className="tlg-applicant-field">
          <div className="tlg-applicant-field-head">
            <div><span>Live application field</span><strong>{field.applicant_count} applicants</strong></div>
            <p>Main Draw {field.main_draw_total_capacity}: {field.direct_main_draw_slots} direct places + {field.qualifier_slots} qualifier places · Qualification capacity {field.qualification_capacity}.</p>
          </div>
          <div className="tlg-applicant-scroll">
            {(['main_draw', 'qualification', 'outside'] as const).map((group) => {
              const rows = groupedApplicants[group]
              if (!rows.length && group === 'outside') return null
              return (
                <section key={group} className={`tlg-applicant-group ${group}`}>
                  <header>
                    <strong>{groupLabel(group)}</strong>
                    <span>{group === 'main_draw' ? `${field.direct_main_draw_slots} direct places` : group === 'qualification' ? `up to ${field.qualification_capacity} places` : 'below the current cut'}</span>
                  </header>
                  {rows.map((row) => (
                    <div key={row.application_id} className={`tlg-applicant-row${row.is_user ? ' is-user' : ''}`}>
                      <b>#{row.world_rank}</b>
                      <CountryFlag countryCode={row.country_code ?? ''} countryName={row.country_code ?? ''} width={19} height={13} />
                      <strong>{row.first_name} {row.last_name}{row.is_user ? ' · You' : ''}</strong>
                      <span>{row.priority ? `Priority #${row.priority}` : row.application_source.includes('late') ? 'Late Entry' : '—'}</span>
                      <small>{row.application_status.replaceAll('_', ' ')}</small>
                    </div>
                  ))}
                </section>
              )
            })}
          </div>
        </div>,
        fieldHost,
      )}

      {drawControlHost && field && createPortal(
        <label className="tlg-draw-view-switch">
          <span>Draw</span>
          <select value={drawView} onChange={(event) => setDrawView(event.target.value as 'main_draw' | 'qualification')}>
            <option value="main_draw">Main Draw</option>
            <option value="qualification">Qualification</option>
          </select>
        </label>,
        drawControlHost,
      )}

      {drawBodyHost && drawView === 'qualification' && createPortal(
        <div className="tlg-qualification-history">
          {qualificationRounds.length ? (
            <div className="tlg-qualification-columns">
              {qualificationRounds.map((round) => (
                <section key={round.round} className="tlg-qualification-round">
                  <header><strong>{round.label}</strong><span>{round.matches.length} matches</span></header>
                  <div>
                    {round.matches.map((match) => (
                      <article key={match.match_id} className={`tlg-qualification-match status-${match.match_status}`}>
                        <QualificationPlayer match={match} side={1} />
                        <QualificationPlayer match={match} side={2} />
                      </article>
                    ))}
                  </div>
                </section>
              ))}
            </div>
          ) : (
            <div className="tlg-qualification-empty">No stored qualification bracket exists for this legacy/test competition. Future published draws retain qualification results here permanently.</div>
          )}
        </div>,
        drawBodyHost,
      )}
    </>
  )
}
