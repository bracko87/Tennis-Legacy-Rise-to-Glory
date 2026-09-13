import { createPortal } from 'react-dom'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useLocation, useParams } from 'react-router'

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
  current_world_rank: number
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

interface QualificationRound {
  round: number
  label: string
  matches: DrawMatch[]
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const QUALIFICATION_MATCH_WIDTH = 240
const QUALIFICATION_MATCH_HEIGHT = 68
const QUALIFICATION_COLUMN_GAP = 72
const QUALIFICATION_FIRST_ROUND_GAP = 12
const QUALIFICATION_STEP = QUALIFICATION_MATCH_HEIGHT + QUALIFICATION_FIRST_ROUND_GAP
const OPEN_TOURNAMENT_MATCH_EVENT = 'tlg-open-tournament-match'

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

function qualificationMatchCenter(roundIndex: number, matchIndex: number) {
  const firstRoundMatchSpan = 2 ** roundIndex
  const representedFirstMatchCenter = matchIndex * firstRoundMatchSpan + (firstRoundMatchSpan - 1) / 2
  return QUALIFICATION_MATCH_HEIGHT / 2 + representedFirstMatchCenter * QUALIFICATION_STEP
}

function openTournamentMatch(matchId: string) {
  window.dispatchEvent(new CustomEvent(OPEN_TOURNAMENT_MATCH_EVENT, { detail: { matchId } }))
}

function QualificationPlayer({
  match,
  side,
  returnPath,
  tournamentName,
}: {
  match: DrawMatch
  side: 1 | 2
  returnPath: string
  tournamentName: string
}) {
  const playerId = side === 1 ? match.player1_id : match.player2_id
  const countryCode = side === 1 ? match.player1_country_code : match.player2_country_code
  const seed = side === 1 ? match.player1_seed : match.player2_seed
  const winner = Boolean(playerId && playerId === match.winner_id)
  const name = drawPlayerName(match, side)

  if (!playerId) {
    const placeholder = match.match_status === 'bye' ? 'BYE' : name
    return (
      <div className={`tlg-live-tree-player${match.match_status === 'bye' ? ' tlg-live-tree-bye' : ''}`}>
        <span className="flag-slot" />
        <strong className="player-name">{placeholder}</strong>
        <span className="seed-slot" />
        <span className="score-slot">—</span>
      </div>
    )
  }

  return (
    <div className={`tlg-live-tree-player${winner ? ' tlg-live-tree-winner' : ''}`}>
      <span className="flag-slot">{countryCode ? <CountryFlag countryCode={countryCode} countryName={countryCode} width={19} height={13} /> : null}</span>
      <Link
        className="player-name"
        to={`/game/players/${playerId}`}
        state={{ playerProfileReturn: returnPath, playerProfileReturnLabel: `Back to ${tournamentName}` }}
        onClick={(event) => event.stopPropagation()}
      >
        {name}
      </Link>
      <span className="seed-slot">{seed ? <strong>{seed}</strong> : null}</span>
      <span className="score-slot">{setScore(match, side)}</span>
    </div>
  )
}

function QualificationBracketTree({
  rounds,
  returnPath,
  tournamentName,
}: {
  rounds: QualificationRound[]
  returnPath: string
  tournamentName: string
}) {
  if (!rounds.length) {
    return <div className="tlg-qualification-empty">No stored qualification bracket exists for this legacy/test competition. Future published draws retain qualification results here permanently.</div>
  }

  const width = rounds.length * QUALIFICATION_MATCH_WIDTH + Math.max(0, rounds.length - 1) * QUALIFICATION_COLUMN_GAP
  const firstRoundMatchCount = Math.max(1, rounds[0]?.matches.length ?? 1)
  const height = Math.max(QUALIFICATION_MATCH_HEIGHT, (firstRoundMatchCount - 1) * QUALIFICATION_STEP + QUALIFICATION_MATCH_HEIGHT)

  return (
    <div className="tlg-qualification-history">
      <div className="tlg-detail-bracket-scroll tlg-live-bracket-scroll">
        <div className="tlg-detail-bracket-headings" style={{ width }}>
          {rounds.map((round, roundIndex) => (
            <header
              key={`${round.round}:${round.label}`}
              style={{ left: roundIndex * (QUALIFICATION_MATCH_WIDTH + QUALIFICATION_COLUMN_GAP), width: QUALIFICATION_MATCH_WIDTH }}
            >
              <strong>{round.label}</strong>
              <span>{round.matches.length} {round.matches.length === 1 ? 'match' : 'matches'}</span>
            </header>
          ))}
        </div>

        <div className="tlg-detail-bracket-tree" style={{ width, height }}>
          <svg className="tlg-detail-bracket-connectors" width={width} height={height} viewBox={`0 0 ${width} ${height}`} aria-hidden="true">
            {rounds.slice(0, -1).map((_, roundIndex) => {
              const boundaryX = (roundIndex + 1) * (QUALIFICATION_MATCH_WIDTH + QUALIFICATION_COLUMN_GAP) - QUALIFICATION_COLUMN_GAP / 2
              return <line key={`qualification-round-separator-${roundIndex}`} x1={boundaryX} x2={boundaryX} y1={0} y2={height} stroke="#0b6fc8" strokeWidth="1.4" opacity="0.72" vectorEffect="non-scaling-stroke" />
            })}
            {rounds.slice(0, -1).flatMap((_, roundIndex) => {
              const parentRound = rounds[roundIndex + 1]
              const startX = roundIndex * (QUALIFICATION_MATCH_WIDTH + QUALIFICATION_COLUMN_GAP) + QUALIFICATION_MATCH_WIDTH
              const middleX = startX + QUALIFICATION_COLUMN_GAP / 2
              const endX = (roundIndex + 1) * (QUALIFICATION_MATCH_WIDTH + QUALIFICATION_COLUMN_GAP)
              return parentRound.matches.map((_, parentIndex) => {
                const firstY = qualificationMatchCenter(roundIndex, parentIndex * 2)
                const secondY = qualificationMatchCenter(roundIndex, parentIndex * 2 + 1)
                const parentY = qualificationMatchCenter(roundIndex + 1, parentIndex)
                return <path key={`qualification-connector-${roundIndex}-${parentIndex}`} d={`M ${startX} ${firstY} H ${middleX} M ${startX} ${secondY} H ${middleX} M ${middleX} ${firstY} V ${secondY} M ${middleX} ${parentY} H ${endX}`} />
              })
            })}
          </svg>

          {rounds.map((round, roundIndex) => (
            <section
              key={`${round.round}:${round.label}`}
              className="tlg-detail-bracket-round"
              style={{ left: roundIndex * (QUALIFICATION_MATCH_WIDTH + QUALIFICATION_COLUMN_GAP), width: QUALIFICATION_MATCH_WIDTH }}
            >
              {round.matches.map((match, matchIndex) => {
                const top = qualificationMatchCenter(roundIndex, matchIndex) - QUALIFICATION_MATCH_HEIGHT / 2
                return (
                  <div
                    key={match.match_id}
                    className={`tlg-detail-bracket-match tlg-live-tree-match tlg-qualification-tree-match clickable status-${match.match_status}`}
                    style={{ top, width: QUALIFICATION_MATCH_WIDTH, height: QUALIFICATION_MATCH_HEIGHT }}
                    role="button"
                    tabIndex={0}
                    aria-label={`Open ${match.round_label} match ${match.match_number}`}
                    onClick={() => openTournamentMatch(match.match_id)}
                    onKeyDown={(event) => {
                      if (event.key === 'Enter' || event.key === ' ') {
                        event.preventDefault()
                        openTournamentMatch(match.match_id)
                      }
                    }}
                  >
                    <QualificationPlayer match={match} side={1} returnPath={returnPath} tournamentName={tournamentName} />
                    <QualificationPlayer match={match} side={2} returnPath={returnPath} tournamentName={tournamentName} />
                  </div>
                )
              })}
            </section>
          ))}
        </div>
      </div>
    </div>
  )
}

export default function TournamentExperienceEnhancements() {
  const { competitionId } = useParams()
  const location = useLocation()
  const [lifecycle, setLifecycle] = useState<LifecycleData | null>(null)
  const [field, setField] = useState<ApplicationFieldData | null>(null)
  const [drawMatches, setDrawMatches] = useState<DrawMatch[]>([])
  const [drawView, setDrawView] = useState<'main_draw' | 'qualification'>('main_draw')
  const [heroHost, setHeroHost] = useState<HTMLElement | null>(null)
  const [fieldHost, setFieldHost] = useState<HTMLElement | null>(null)
  const [drawControlHost, setDrawControlHost] = useState<HTMLElement | null>(null)
  const [drawBodyHost, setDrawBodyHost] = useState<HTMLElement | null>(null)
  const [fieldExpandedOverride, setFieldExpandedOverride] = useState<boolean | null>(null)

  useEffect(() => {
    setFieldExpandedOverride(null)
  }, [competitionId])

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
    if (!competitionId) return
    const timer = window.setInterval(() => void load(), 10000)
    const channel = supabase.channel(`tournament-entry-experience:${competitionId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_applications', filter: `competition_id=eq.${competitionId}` }, () => void load())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tournament_entries', filter: `competition_id=eq.${competitionId}` }, () => void load())
      .subscribe()
    return () => {
      window.clearInterval(timer)
      void supabase.removeChannel(channel)
    }
  }, [competitionId, load])

  useEffect(() => {
    let frame = 0
    let cancelled = false
    const created: HTMLElement[] = []
    let localHero: HTMLElement | null = null
    let localField: HTMLElement | null = null
    let localControl: HTMLElement | null = null
    let localBody: HTMLElement | null = null

    function makeHostAfter(anchor: Element | null, attr: string, className: string) {
      if (!anchor || !anchor.parentElement) return null
      const selector = `[data-${attr}="true"]`
      const existing = anchor.parentElement.querySelector<HTMLElement>(selector)
      if (existing) return existing
      const host = document.createElement('div')
      host.setAttribute(`data-${attr}`, 'true')
      host.className = className
      anchor.insertAdjacentElement('afterend', host)
      created.push(host)
      return host
    }

    function findTargets() {
      if (cancelled) return
      const tags = document.querySelector('.tlg-detail-hero-copy .tlg-detail-tags')
      if (!localHero && tags) {
        localHero = makeHostAfter(tags, 'tlg-hero-entry-host', 'tlg-hero-entry-host')
        setHeroHost(localHero)
      }

      const personalHead = document.querySelector('.tlg-entry-personal-card .tlg-entry-personal-head')
      if (!localField && personalHead) {
        localField = makeHostAfter(personalHead, 'tlg-applicant-field-host', 'tlg-applicant-field-host')
        setFieldHost(localField)
      }

      const drawPanel = document.querySelector<HTMLElement>('.tlg-live-draw-panel')
      const drawHead = drawPanel?.querySelector<HTMLElement>('.tlg-live-draw-head') ?? null
      if (drawPanel && drawHead) {
        if (!localControl) {
          localControl = drawHead.querySelector<HTMLElement>('[data-tlg-draw-switch-host="true"]')
          if (!localControl) {
            localControl = document.createElement('div')
            localControl.dataset.tlgDrawSwitchHost = 'true'
            localControl.className = 'tlg-draw-switch-host'
            const status = drawHead.querySelector('.tlg-live-draw-status')
            if (status) drawHead.insertBefore(localControl, status)
            else drawHead.appendChild(localControl)
            created.push(localControl)
          }
          setDrawControlHost(localControl)
        }
        if (!localBody) {
          localBody = drawPanel.querySelector<HTMLElement>('[data-tlg-qualification-body-host="true"]')
          if (!localBody) {
            localBody = document.createElement('div')
            localBody.dataset.tlgQualificationBodyHost = 'true'
            localBody.className = 'tlg-qualification-body-host'
            drawHead.insertAdjacentElement('afterend', localBody)
            created.push(localBody)
          }
          setDrawBodyHost(localBody)
        }
      }

      if (!localHero || !localField || !localControl || !localBody) frame = window.requestAnimationFrame(findTargets)
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
  }, [competitionId])

  const qualificationMatches = useMemo(() => drawMatches.filter((match) => match.draw_type === 'qualification'), [drawMatches])
  const qualificationRounds = useMemo<QualificationRound[]>(() => {
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
    if (copy && !copy.dataset.mainDrawCopy) copy.dataset.mainDrawCopy = copy.textContent ?? ''
    if (title) title.textContent = drawView === 'qualification' ? 'Qualification bracket' : 'Knockout bracket'
    if (copy) copy.textContent = drawView === 'qualification'
      ? (qualificationMatches.length ? `${qualificationMatches.length} qualification matches · completed results remain available after qualification ends` : 'Qualification bracket history')
      : (copy.dataset.mainDrawCopy ?? '')
  }, [drawView, qualificationMatches.length])

  const groupedApplicants = useMemo(() => ({
    main_draw: field?.applicants.filter((row) => row.projected_group === 'main_draw') ?? [],
    qualification: field?.applicants.filter((row) => row.projected_group === 'qualification') ?? [],
    outside: field?.applicants.filter((row) => row.projected_group === 'outside') ?? [],
  }), [field])

  const fieldExpanded = fieldExpandedOverride ?? !['draw_published', 'in_progress', 'completed'].includes(lifecycle?.phase ?? '')
  const returnPath = `${location.pathname}${location.search}${location.hash}`
  const tournamentName = field?.tournament_name ?? 'Tournament'

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
        </div>, heroHost)}

      {fieldHost && field && createPortal(
        <div className={`tlg-applicant-field${fieldExpanded ? '' : ' collapsed'}`}>
          <div className="tlg-applicant-field-head">
            <div><span>Live application field</span><strong>{field.applicant_count} current applicant{field.applicant_count === 1 ? '' : 's'}</strong></div>
            <div className="tlg-applicant-field-head-actions">
              {fieldExpanded && <p>Main Draw {field.main_draw_total_capacity}: {field.direct_main_draw_slots} direct places + {field.qualifier_slots} qualifier places · Qualification capacity {field.qualification_capacity}.</p>}
              <button type="button" className="tlg-applicant-field-toggle" aria-expanded={fieldExpanded} onClick={() => setFieldExpandedOverride(!fieldExpanded)}>
                {fieldExpanded ? 'Hide field' : 'Show field'}
              </button>
            </div>
          </div>
          {fieldExpanded && <div className="tlg-applicant-scroll">
            {(['main_draw', 'qualification', 'outside'] as const).map((group) => {
              const rows = groupedApplicants[group]
              if (!rows.length && group === 'outside') return null
              return (
                <section key={group} className={`tlg-applicant-group ${group}`}>
                  <header><strong>{groupLabel(group)}</strong><span>{group === 'main_draw' ? `${field.direct_main_draw_slots} direct places` : group === 'qualification' ? `up to ${field.qualification_capacity} places` : 'below the current cut'}</span></header>
                  {rows.map((row) => (
                    <div key={row.application_id} className={`tlg-applicant-row${row.is_user ? ' is-user' : ''}`}>
                      <b title={row.current_world_rank !== row.world_rank ? `Current ranking: #${row.current_world_rank}` : undefined}>#{row.world_rank}</b>
                      <CountryFlag countryCode={row.country_code ?? ''} countryName={row.country_code ?? ''} width={19} height={13} />
                      <Link
                        className="tlg-applicant-player-link"
                        to={`/game/players/${row.player_id}`}
                        state={{ playerProfileReturn: returnPath, playerProfileReturnLabel: 'Back to Tournament' }}
                      >
                        {row.first_name} {row.last_name}{row.is_user ? ' · You' : ''}
                      </Link>
                      <span>{row.priority ? `Priority #${row.priority}` : row.application_source.includes('late') ? 'Late Entry' : '—'}</span>
                      <small>{row.application_status.replaceAll('_', ' ')}</small>
                    </div>
                  ))}
                </section>
              )
            })}
          </div>}
        </div>, fieldHost)}

      {drawControlHost && field && createPortal(
        <label className="tlg-draw-view-switch"><span>Draw</span><select value={drawView} onChange={(event) => setDrawView(event.target.value as 'main_draw' | 'qualification')}><option value="main_draw">Main Draw</option><option value="qualification">Qualification</option></select></label>, drawControlHost)}

      {drawBodyHost && drawView === 'qualification' && createPortal(
        <QualificationBracketTree rounds={qualificationRounds} returnPath={returnPath} tournamentName={tournamentName} />,
        drawBodyHost)}
    </>
  )
}