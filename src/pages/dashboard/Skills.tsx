import { useEffect, useMemo, useState } from 'react'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/player-skills.css'

type SkillsTab = 'tennis' | 'physical' | 'condition'
type PreferredSurface = 'Hard' | 'Clay' | 'Grass'
type PlayingStyle = 'Aggressive Baseliner' | 'Defensive Baseliner' | 'All-court' | 'Serve & Volley'

interface PlayerSkillsRow {
  player_id: string
  preferred_surface: PreferredSurface | null
  playing_style: PlayingStyle
  serve: number
  forehand: number
  backhand: number
  return_skill: number
  volley: number
  slice: number
  drop_shot: number
  fitness: number
  stamina: number
  recovery: number
  movement: number
  fatigue: number
  sharpness: number
  morale: number
  confidence: number
  focus: number
}

interface SkillHistoryRow {
  id: string
  player_id: string
  recorded_at: string
  source: string
  serve: number
  forehand: number
  backhand: number
  return_skill: number
  volley: number
  slice: number
  drop_shot: number
  fitness: number
  stamina: number
  recovery: number
  movement: number
  fatigue: number
  sharpness: number
  morale: number
  confidence: number
  focus: number
}

interface AttributeItem {
  label: string
  value: number
  note: string
  inverse?: boolean
  change?: number
}

const SURFACE_COPY: Record<PreferredSurface, string> = {
  Hard: 'Balanced court identity with a small emphasis on groundstrokes, serve and return.',
  Clay: 'Rally-oriented identity with extra emphasis on groundstrokes and return.',
  Grass: 'Fast-court identity with extra emphasis on serve, volley and slice.',
}

const STYLE_COPY: Record<PlayingStyle, string> = {
  'Aggressive Baseliner': 'Baseline pressure with extra emphasis on attacking groundstrokes.',
  'Defensive Baseliner': 'Return, backhand stability and defensive resistance are emphasized.',
  'All-court': 'Balanced style with no extra redistribution beyond the preferred surface.',
  'Serve & Volley': 'Serve, volley and forward-court play receive the extra emphasis.',
}

const TAB_COPY: Record<SkillsTab, { label: string; kicker: string; title: string; description: string }> = {
  tennis: {
    label: 'Tennis Skills',
    kicker: 'Developable attributes',
    title: 'Technical profile',
    description: 'The racket skills that define how your player performs on court. Training and match development will improve these values over time.',
  },
  physical: {
    label: 'Physical',
    kicker: 'Athletic development',
    title: 'Physical profile',
    description: 'The permanent athletic base behind movement, endurance and recovery. Every new player begins from the same physical starting point.',
  },
  condition: {
    label: 'Current Condition',
    kicker: 'Live career state',
    title: 'Readiness & mindset',
    description: 'Dynamic values that rise and fall through matches, rest, form, training load and career events rather than permanent skill progression.',
  },
}

function scoreCategory(row: PlayerSkillsRow | SkillHistoryRow, tab: SkillsTab) {
  if (tab === 'tennis') {
    return (row.serve + row.forehand + row.backhand + row.return_skill + row.volley + row.slice + row.drop_shot) / 7
  }
  if (tab === 'physical') {
    return (row.fitness + row.stamina + row.recovery + row.movement) / 4
  }
  const freshness = 100 - row.fatigue
  return (row.morale + row.confidence + row.sharpness + row.focus + freshness) / 5
}

function signed(value: number) {
  if (Math.abs(value) < 0.05) return '0.0'
  return `${value > 0 ? '+' : ''}${value.toFixed(1)}`
}

function readinessLabel(score: number) {
  if (score >= 80) return 'Excellent'
  if (score >= 65) return 'Strong'
  if (score >= 50) return 'Ready'
  if (score >= 35) return 'Managing load'
  return 'Needs recovery'
}

function heatLevel(value: number) {
  if (value >= 75) return 'high'
  if (value >= 60) return 'strong'
  if (value >= 45) return 'balanced'
  return 'development'
}

export default function SkillsPage() {
  const { player } = useAuth()
  const [tab, setTab] = useState<SkillsTab>('tennis')
  const [skills, setSkills] = useState<PlayerSkillsRow | null>(null)
  const [history, setHistory] = useState<SkillHistoryRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [historyError, setHistoryError] = useState<string | null>(null)

  useEffect(() => {
    let active = true

    async function loadSkills() {
      if (!player?.id) {
        setSkills(null)
        setHistory([])
        setLoading(false)
        return
      }

      setLoading(true)
      setError(null)
      setHistoryError(null)

      const [skillsResult, historyResult] = await Promise.all([
        supabase
          .from('player_skills')
          .select('player_id, preferred_surface, playing_style, serve, forehand, backhand, return_skill, volley, slice, drop_shot, fitness, stamina, recovery, movement, fatigue, sharpness, morale, confidence, focus')
          .eq('player_id', player.id)
          .maybeSingle(),
        supabase
          .from('player_skill_history')
          .select('id, player_id, recorded_at, source, serve, forehand, backhand, return_skill, volley, slice, drop_shot, fitness, stamina, recovery, movement, fatigue, sharpness, morale, confidence, focus')
          .eq('player_id', player.id)
          .order('recorded_at', { ascending: true })
          .limit(120),
      ])

      if (!active) return

      if (skillsResult.error) {
        setError(skillsResult.error.message)
        setSkills(null)
      } else {
        setSkills((skillsResult.data ?? null) as PlayerSkillsRow | null)
      }

      if (historyResult.error) {
        setHistoryError(historyResult.error.message)
        setHistory([])
      } else {
        setHistory((historyResult.data ?? []) as SkillHistoryRow[])
      }

      setLoading(false)
    }

    void loadSkills()
    return () => { active = false }
  }, [player?.id])

  const previousSnapshot = history.length > 1 ? history[history.length - 2] : null

  const tennis = useMemo<AttributeItem[]>(() => skills ? [
    { label: 'Serve', value: skills.serve, note: 'Power, placement and reliability', change: previousSnapshot ? skills.serve - previousSnapshot.serve : 0 },
    { label: 'Forehand', value: skills.forehand, note: 'Primary attacking groundstroke', change: previousSnapshot ? skills.forehand - previousSnapshot.forehand : 0 },
    { label: 'Backhand', value: skills.backhand, note: 'Quality, control and stability', change: previousSnapshot ? skills.backhand - previousSnapshot.backhand : 0 },
    { label: 'Return', value: skills.return_skill, note: 'Neutralizing and attacking serve', change: previousSnapshot ? skills.return_skill - previousSnapshot.return_skill : 0 },
    { label: 'Volley', value: skills.volley, note: 'Net play and finishing ability', change: previousSnapshot ? skills.volley - previousSnapshot.volley : 0 },
    { label: 'Slice', value: skills.slice, note: 'Variation and low-ball control', change: previousSnapshot ? skills.slice - previousSnapshot.slice : 0 },
    { label: 'Drop Shot', value: skills.drop_shot, note: 'Touch and short-court variation', change: previousSnapshot ? skills.drop_shot - previousSnapshot.drop_shot : 0 },
  ] : [], [skills, previousSnapshot])

  const physical = useMemo<AttributeItem[]>(() => skills ? [
    { label: 'Fitness', value: skills.fitness, note: 'General athletic readiness', change: previousSnapshot ? skills.fitness - previousSnapshot.fitness : 0 },
    { label: 'Stamina', value: skills.stamina, note: 'Maintaining quality in long matches', change: previousSnapshot ? skills.stamina - previousSnapshot.stamina : 0 },
    { label: 'Recovery', value: skills.recovery, note: 'Recovery between matches and sessions', change: previousSnapshot ? skills.recovery - previousSnapshot.recovery : 0 },
    { label: 'Movement', value: skills.movement, note: 'Court coverage, speed and balance', change: previousSnapshot ? skills.movement - previousSnapshot.movement : 0 },
  ] : [], [skills, previousSnapshot])

  const condition = useMemo<AttributeItem[]>(() => skills ? [
    { label: 'Morale', value: skills.morale, note: 'Current motivation and emotional state', change: previousSnapshot ? skills.morale - previousSnapshot.morale : 0 },
    { label: 'Confidence', value: skills.confidence, note: 'Belief shaped by form and results', change: previousSnapshot ? skills.confidence - previousSnapshot.confidence : 0 },
    { label: 'Sharpness', value: skills.sharpness, note: 'Competitive rhythm and match readiness', change: previousSnapshot ? skills.sharpness - previousSnapshot.sharpness : 0 },
    { label: 'Focus', value: skills.focus, note: 'Concentration and mental stability', change: previousSnapshot ? skills.focus - previousSnapshot.focus : 0 },
    { label: 'Fatigue', value: skills.fatigue, note: 'Accumulated tiredness · lower is better', inverse: true, change: previousSnapshot ? skills.fatigue - previousSnapshot.fatigue : 0 },
  ] : [], [skills, previousSnapshot])

  const tennisTotal = useMemo(() => tennis.reduce((sum, item) => sum + item.value, 0), [tennis])
  const physicalTotal = useMemo(() => physical.reduce((sum, item) => sum + item.value, 0), [physical])
  const activeCopy = TAB_COPY[tab]
  const activeItems = tab === 'tennis' ? tennis : tab === 'physical' ? physical : condition
  const activeScore = skills ? scoreCategory(skills, tab) : 0
  const baselineScore = history.length ? scoreCategory(history[0], tab) : activeScore
  const scoreChange = activeScore - baselineScore
  const categoryDetail = tab === 'tennis'
    ? `${tennisTotal} total points · 7 skills`
    : tab === 'physical'
      ? `${physicalTotal} total points · 4 skills`
      : '5 live values · fatigue counts as freshness'

  return (
    <GameLayout title="Skills" subtitle="Player development center">
      <section className="tlg-v2-command tlg-skills-command">
        <div className="tlg-v2-command-inner tlg-skills-command-inner">
          <div className="tlg-skills-command-copy">
            <span className="tlg-v2-command-kicker">Player development center</span>
            <h2>Player skills</h2>
            <p>
              Build your professional through technical and physical development while monitoring the current condition that changes throughout the season.
            </p>
          </div>
        </div>
      </section>

      <section className="tlg-skills-workspace">
        <nav className="tlg-skills-side-tabs" role="tablist" aria-label="Player skill categories">
          <div className="tlg-skills-side-heading">
            <span>Development</span>
          </div>

          {(Object.keys(TAB_COPY) as SkillsTab[]).map((tabId) => {
            const item = TAB_COPY[tabId]
            const active = tab === tabId
            return (
              <button
                key={tabId}
                type="button"
                role="tab"
                aria-selected={active}
                className={active ? 'tlg-skills-side-tab active' : 'tlg-skills-side-tab'}
                onClick={() => setTab(tabId)}
              >
                <strong>{item.label}</strong>
                <small>{item.kicker}</small>
              </button>
            )
          })}
        </nav>

        <div className="tlg-skills-main">
          {loading ? (
            <div className="tlg-skills-state">Loading player attributes…</div>
          ) : error ? (
            <div className="tlg-skills-state tlg-skills-state-error">Unable to load player skills: {error}</div>
          ) : !skills ? (
            <div className="tlg-skills-state">Player skill profile has not been initialized yet.</div>
          ) : (
            <>
              <header className="tlg-skills-section-head">
                <div>
                  <span>{activeCopy.kicker}</span>
                  <h3>{activeCopy.title}</h3>
                  <p>{activeCopy.description}</p>
                </div>
                <div className="tlg-skills-section-score">
                  <span>{tab === 'condition' ? 'Readiness score' : 'Category average'}</span>
                  <div><strong>{activeScore.toFixed(1)}</strong><small>/ 100</small></div>
                  <p>{categoryDetail}</p>
                  <em className={scoreChange > 0.05 ? 'positive' : scoreChange < -0.05 ? 'negative' : ''}>{signed(scoreChange)} since start</em>
                </div>
              </header>

              <div className={`tlg-skill-card-grid tlg-skill-card-grid-${tab}`}>
                {activeItems.map((item) => (
                  <SkillCard key={item.label} item={item} />
                ))}
              </div>

              {tab === 'tennis' && (
                <div className="tlg-skill-build-row">
                  <BuildCard
                    label="Preferred surface"
                    value={skills.preferred_surface ?? 'Neutral'}
                    description={skills.preferred_surface ? SURFACE_COPY[skills.preferred_surface] : 'Neutral surface profile.'}
                  />
                  <BuildCard
                    label="Playing style · fixed identity"
                    value={skills.playing_style}
                    description={`${STYLE_COPY[skills.playing_style]} Chosen at career creation and it does not change automatically.`}
                  />
                  <BuildCard
                    label="Starting balance"
                    value={`${tennisTotal} points`}
                    description="Surface and style change distribution, never the total starting tennis strength."
                  />
                </div>
              )}

              {tab === 'physical' && (
                <div className="tlg-skills-info-strip">
                  Every new player begins at 50 in each physical attribute. Training will later create the long-term differences between careers.
                </div>
              )}

              {tab === 'condition' && (
                <div className="tlg-skills-info-strip">
                  Morale, confidence, sharpness and focus begin at 50. Fatigue begins at 0 because lower fatigue represents a fresher player.
                </div>
              )}
            </>
          )}
        </div>
      </section>

      {!loading && skills && (
        <PerformanceCentre skills={skills} history={history} historyError={historyError} />
      )}
    </GameLayout>
  )
}

function SkillCard({ item }: { item: AttributeItem }) {
  const normalized = Math.max(0, Math.min(100, item.value))
  const displayFill = item.inverse ? 100 - normalized : normalized
  const change = item.change ?? 0
  const hasChange = change !== 0
  const improved = item.inverse ? change < 0 : change > 0
  const previousValue = item.value - change

  return (
    <article className={`tlg-skill-card ${item.inverse ? 'inverse' : ''} ${hasChange ? improved ? 'skill-change-positive' : 'skill-change-negative' : ''}`}>
      <div className="tlg-skill-card-top">
        <div>
          <span>{item.label}</span>
          <p>{item.note}</p>
        </div>
        {hasChange ? (
          <div className="tlg-skill-change-value">
            <small>{previousValue}</small>
            <strong>{item.value}</strong>
            <em>{change > 0 ? '+' : ''}{change}</em>
          </div>
        ) : (
          <strong>{item.value}</strong>
        )}
      </div>
      <div className="tlg-skill-card-meter" aria-label={`${item.label}: ${item.value} out of 100`}>
        <span style={{ width: `${displayFill}%` }} />
      </div>
      <div className="tlg-skill-card-scale" aria-hidden="true">
        <span>{item.inverse ? 'Fresh' : '0'}</span>
        <span>{item.inverse ? 'Tired' : '100'}</span>
      </div>
      {hasChange && (
        <div className="tlg-skill-change-note">
          <strong>{improved ? 'Latest improvement' : 'Latest change'}</strong>
          <span>{previousValue} → {item.value}</span>
        </div>
      )}
    </article>
  )
}

function BuildCard({ label, value, description }: { label: string; value: string; description: string }) {
  return (
    <article className="tlg-skill-build-card">
      <span>{label}</span>
      <strong>{value}</strong>
      <p>{description}</p>
    </article>
  )
}

function PerformanceCentre({
  skills,
  history,
  historyError,
}: {
  skills: PlayerSkillsRow
  history: SkillHistoryRow[]
  historyError: string | null
}) {
  const technical = scoreCategory(skills, 'tennis')
  const physical = scoreCategory(skills, 'physical')
  const readiness = scoreCategory(skills, 'condition')
  const freshness = Math.max(0, Math.min(100, 100 - skills.fatigue))
  const baseline = history[0] ?? null
  const technicalChange = baseline ? technical - scoreCategory(baseline, 'tennis') : 0
  const physicalChange = baseline ? physical - scoreCategory(baseline, 'physical') : 0
  const readinessChange = baseline ? readiness - scoreCategory(baseline, 'condition') : 0
  const updates = Math.max(0, history.length - 1)

  const tennisValues = [
    { label: 'Serve', value: skills.serve },
    { label: 'Forehand', value: skills.forehand },
    { label: 'Backhand', value: skills.backhand },
    { label: 'Return', value: skills.return_skill },
    { label: 'Volley', value: skills.volley },
    { label: 'Slice', value: skills.slice },
    { label: 'Drop Shot', value: skills.drop_shot },
  ]

  const physicalValues = [
    { label: 'Fitness', value: skills.fitness },
    { label: 'Stamina', value: skills.stamina },
    { label: 'Recovery', value: skills.recovery },
    { label: 'Movement', value: skills.movement },
  ]

  const conditionValues = [
    { label: 'Morale', value: skills.morale },
    { label: 'Confidence', value: skills.confidence },
    { label: 'Sharpness', value: skills.sharpness },
    { label: 'Focus', value: skills.focus },
    { label: 'Freshness', value: freshness },
  ]

  const strongestTennis = tennisValues.reduce((best, item) => item.value > best.value ? item : best)
  const priorityTennis = tennisValues.reduce((lowest, item) => item.value < lowest.value ? item : lowest)
  const strongestPhysical = physicalValues.reduce((best, item) => item.value > best.value ? item : best)
  const latestHistory = history.length > 1 ? history[history.length - 1] : null
  const previousHistory = history.length > 1 ? history[history.length - 2] : null
  const latestTechnicalMovement = latestHistory && previousHistory
    ? scoreCategory(latestHistory, 'tennis') - scoreCategory(previousHistory, 'tennis')
    : 0
  const latestPhysicalMovement = latestHistory && previousHistory
    ? scoreCategory(latestHistory, 'physical') - scoreCategory(previousHistory, 'physical')
    : 0
  const developmentDirection = updates === 0
    ? 'Baseline established'
    : latestTechnicalMovement > 0.05 || latestPhysicalMovement > 0.05
      ? 'Improving'
      : latestTechnicalMovement < -0.05 || latestPhysicalMovement < -0.05
        ? 'Declining'
        : 'Stable'

  const heatmap = [
    ...tennisValues.map((item) => ({ ...item, group: 'Tennis' })),
    ...physicalValues.map((item) => ({ ...item, group: 'Physical' })),
    ...conditionValues.map((item) => ({ ...item, group: 'Condition' })),
  ]

  return (
    <section className="tlg-performance-centre">
      <header className="tlg-performance-hero">
        <div>
          <span>Performance analysis</span>
          <h3>Player Performance Centre</h3>
          <p>Live analysis built from your real skills, physical profile and current condition. No estimated or fictional performance values are used.</p>
        </div>
        <div className="tlg-performance-kpis">
          <PerformanceKpi label="Technical" value={technical.toFixed(1)} detail={`${signed(technicalChange)} since start`} />
          <PerformanceKpi label="Physical" value={physical.toFixed(1)} detail={`${signed(physicalChange)} since start`} />
          <PerformanceKpi label="Readiness" value={readiness.toFixed(1)} detail={readinessLabel(readiness)} />
          <PerformanceKpi label="Recorded development" value={String(updates)} detail={developmentDirection} />
        </div>
      </header>

      <div className="tlg-performance-top-grid">
        <AnalysisPanel title="Technical radar" description="Seven-dimensional view of the player's current tennis profile.">
          <TennisRadar values={tennisValues} />
        </AnalysisPanel>

        <AnalysisPanel title="Performance gauges" description="High-level technical, athletic and readiness indicators.">
          <div className="tlg-gauge-grid">
            <Gauge label="Technical profile" value={technical} detail="Average tennis skill" />
            <Gauge label="Physical profile" value={physical} detail="Athletic base" />
            <Gauge label="Current readiness" value={readiness} detail={readinessLabel(readiness)} />
            <Gauge label="Freshness" value={freshness} detail={`${skills.fatigue}/100 fatigue`} />
          </div>
        </AnalysisPanel>
      </div>

      <AnalysisPanel title="Attribute heatmap" description="Instant view of strong, balanced and developing areas across the complete player profile.">
        <div className="tlg-attribute-heatmap">
          {heatmap.map((item) => (
            <div key={`${item.group}-${item.label}`} className={`tlg-heat-cell ${heatLevel(item.value)}`}>
              <span>{item.group}</span>
              <strong>{item.label}</strong>
              <b>{item.value.toFixed(0)}</b>
            </div>
          ))}
        </div>
      </AnalysisPanel>

      <div className="tlg-performance-bottom-grid">
        <AnalysisPanel title="Development intelligence" description="Automatic coaching-style interpretation of the current profile.">
          <div className="tlg-intelligence-grid">
            <InsightCard label="Primary technical strength" value={strongestTennis.label} detail={`${strongestTennis.value}/100`} />
            <InsightCard label="Technical priority area" value={priorityTennis.label} detail={`${priorityTennis.value}/100`} />
            <InsightCard label="Strongest physical area" value={strongestPhysical.label} detail={`${strongestPhysical.value}/100`} />
            <InsightCard label="Current status" value={readinessLabel(readiness)} detail={`${readiness.toFixed(1)}/100 readiness`} />
            <InsightCard label="Development direction" value={developmentDirection} detail={`${updates} recorded update${updates === 1 ? '' : 's'}`} />
            <InsightCard label="Career identity" value={skills.playing_style} detail={`${skills.preferred_surface ?? 'Neutral'} surface`} />
          </div>
        </AnalysisPanel>

        <AnalysisPanel title="Development matrix" description="Current category levels compared with the career starting baseline.">
          <div className="tlg-development-matrix">
            <MatrixRow label="Technical" value={technical} change={technicalChange} />
            <MatrixRow label="Physical" value={physical} change={physicalChange} />
            <MatrixRow label="Readiness" value={readiness} change={readinessChange} />
          </div>
        </AnalysisPanel>
      </div>

      <AnalysisPanel title="Development history" description="Technical, physical and readiness history on one timeline. Every point comes from an automatically recorded database snapshot.">
        {historyError ? (
          <div className="tlg-performance-empty">Development history could not be loaded: {historyError}</div>
        ) : (
          <>
            <MultiHistoryChart history={history} />
            {history.length <= 1 && (
              <div className="tlg-performance-empty">
                Career baseline recorded. The three trend lines will begin moving after Training, matches or another career system changes real player values.
              </div>
            )}
            <div className="tlg-history-meta">
              <span>{history.length ? `First snapshot: ${formatHistoryDate(history[0].recorded_at)}` : 'No snapshots yet'}</span>
              <span>{history.length ? `Latest snapshot: ${formatHistoryDate(history[history.length - 1].recorded_at)}` : 'Scale: 0–100'}</span>
            </div>
          </>
        )}
      </AnalysisPanel>
    </section>
  )
}

function PerformanceKpi({ label, value, detail }: { label: string; value: string; detail: string }) {
  return (
    <div className="tlg-performance-kpi">
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{detail}</small>
    </div>
  )
}

function AnalysisPanel({ title, description, children }: { title: string; description: string; children: JSX.Element | JSX.Element[] }) {
  return (
    <section className="tlg-analysis-panel">
      <header>
        <h4>{title}</h4>
        <p>{description}</p>
      </header>
      <div className="tlg-analysis-body">{children}</div>
    </section>
  )
}

function Gauge({ label, value, detail }: { label: string; value: number; detail: string }) {
  const normalized = Math.max(0, Math.min(100, value))
  return (
    <div className="tlg-gauge-card">
      <div className="tlg-gauge" style={{ '--gauge-value': `${normalized * 3.6}deg` } as React.CSSProperties}>
        <div>
          <strong>{normalized.toFixed(0)}</strong>
          <span>/100</span>
        </div>
      </div>
      <strong>{label}</strong>
      <span>{detail}</span>
    </div>
  )
}

function TennisRadar({ values }: { values: Array<{ label: string; value: number }> }) {
  const width = 470
  const height = 330
  const cx = 235
  const cy = 162
  const radius = 108
  const count = values.length

  const pointAt = (index: number, scale: number) => {
    const angle = -Math.PI / 2 + (index / count) * Math.PI * 2
    return {
      x: cx + Math.cos(angle) * radius * scale,
      y: cy + Math.sin(angle) * radius * scale,
    }
  }

  const ringPoints = (scale: number) => values.map((_, index) => {
    const point = pointAt(index, scale)
    return `${point.x},${point.y}`
  }).join(' ')

  const valuePoints = values.map((item, index) => {
    const point = pointAt(index, Math.max(0, Math.min(100, item.value)) / 100)
    return `${point.x},${point.y}`
  }).join(' ')

  return (
    <svg className="tlg-tennis-radar" viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Current tennis skill radar">
      {[0.25, 0.5, 0.75, 1].map((scale) => (
        <polygon key={scale} points={ringPoints(scale)} className="radar-ring" />
      ))}
      {values.map((item, index) => {
        const outer = pointAt(index, 1)
        const label = pointAt(index, 1.27)
        const anchor = label.x < cx - 10 ? 'end' : label.x > cx + 10 ? 'start' : 'middle'
        return (
          <g key={item.label}>
            <line x1={cx} y1={cy} x2={outer.x} y2={outer.y} className="radar-axis" />
            <text x={label.x} y={label.y} textAnchor={anchor} dominantBaseline="middle" className="radar-label">{item.label}</text>
          </g>
        )
      })}
      <polygon points={valuePoints} className="radar-value" />
      {values.map((item, index) => {
        const point = pointAt(index, Math.max(0, Math.min(100, item.value)) / 100)
        return <circle key={`point-${item.label}`} cx={point.x} cy={point.y} r="4" className="radar-point" />
      })}
    </svg>
  )
}

function InsightCard({ label, value, detail }: { label: string; value: string; detail: string }) {
  return (
    <div className="tlg-insight-card">
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{detail}</small>
    </div>
  )
}

function MatrixRow({ label, value, change }: { label: string; value: number; change: number }) {
  return (
    <div className="tlg-matrix-row">
      <div className="tlg-matrix-copy">
        <strong>{label}</strong>
        <span className={change > 0.05 ? 'positive' : change < -0.05 ? 'negative' : ''}>{signed(change)} since start</span>
      </div>
      <div className="tlg-matrix-value"><strong>{value.toFixed(1)}</strong><span>/100</span></div>
      <div className="tlg-matrix-meter"><span style={{ width: `${Math.max(0, Math.min(100, value))}%` }} /></div>
    </div>
  )
}

function MultiHistoryChart({ history }: { history: SkillHistoryRow[] }) {
  const width = 1040
  const height = 300
  const left = 48
  const right = 24
  const top = 26
  const bottom = 42
  const plotWidth = width - left - right
  const plotHeight = height - top - bottom
  const rows = history.map((row) => ({
    date: row.recorded_at,
    technical: scoreCategory(row, 'tennis'),
    physical: scoreCategory(row, 'physical'),
    readiness: scoreCategory(row, 'condition'),
  }))

  const coordinate = (value: number, index: number) => ({
    x: rows.length <= 1 ? left + plotWidth / 2 : left + (index / (rows.length - 1)) * plotWidth,
    y: top + ((100 - Math.max(0, Math.min(100, value))) / 100) * plotHeight,
  })

  const linePoints = (key: 'technical' | 'physical' | 'readiness') => rows.map((row, index) => {
    const point = coordinate(row[key], index)
    return `${point.x},${point.y}`
  }).join(' ')

  const labelIndexes = rows.length <= 6
    ? rows.map((_, index) => index)
    : Array.from(new Set([0, Math.floor((rows.length - 1) / 4), Math.floor((rows.length - 1) / 2), Math.floor(((rows.length - 1) * 3) / 4), rows.length - 1]))

  return (
    <div className="tlg-multi-history-wrap">
      <div className="tlg-history-legend" aria-hidden="true">
        <span className="technical">Technical</span>
        <span className="physical">Physical</span>
        <span className="readiness">Readiness</span>
      </div>
      <svg className="tlg-multi-history" viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Technical, physical and readiness development history">
        {[100, 75, 50, 25, 0].map((value) => {
          const y = top + ((100 - value) / 100) * plotHeight
          return (
            <g key={value}>
              <line x1={left} x2={width - right} y1={y} y2={y} className="grid-line" />
              <text x={left - 10} y={y + 4} textAnchor="end" className="axis-label">{value}</text>
            </g>
          )
        })}

        {rows.length > 1 && <polyline points={linePoints('technical')} className="trend technical" />}
        {rows.length > 1 && <polyline points={linePoints('physical')} className="trend physical" />}
        {rows.length > 1 && <polyline points={linePoints('readiness')} className="trend readiness" />}

        {rows.map((row, index) => (
          <g key={`${row.date}-${index}`}>
            <circle {...coordinate(row.technical, index)} r="4" className="trend-point technical" />
            <circle {...coordinate(row.physical, index)} r="4" className="trend-point physical" />
            <circle {...coordinate(row.readiness, index)} r="4" className="trend-point readiness" />
          </g>
        ))}

        {labelIndexes.map((index) => {
          const row = rows[index]
          if (!row) return null
          const point = coordinate(row.technical, index)
          return <text key={`date-${index}`} x={point.x} y={height - 12} textAnchor="middle" className="date-label">{formatHistoryDate(row.date, true)}</text>
        })}
      </svg>
    </div>
  )
}

function formatHistoryDate(value: string, short = false) {
  try {
    return new Intl.DateTimeFormat('en', short
      ? { month: 'short', day: 'numeric' }
      : { month: 'short', day: 'numeric', year: 'numeric' }).format(new Date(value))
  } catch {
    return value
  }
}