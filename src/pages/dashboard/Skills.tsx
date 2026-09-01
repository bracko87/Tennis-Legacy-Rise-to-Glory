import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router'

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
          .limit(80),
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

          <div className="tlg-skills-side-note">
            <span>Starting rule</span>
            <p>All new players begin with equal total strength. Surface and style redistribute tennis points only.</p>
          </div>

          <div className="tlg-skills-side-training">
            <span>Training center</span>
            <strong>Regular training</strong>
            <p>Use Training to choose the development work that will eventually drive these attributes.</p>
            <div className="tlg-skills-training-status">
              <span>Current focus</span>
              <b>Not configured yet</b>
            </div>
            <Link to="/game/training">Open Training</Link>
          </div>
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
        <DevelopmentHistory
          tab={tab}
          history={history}
          currentScore={activeScore}
          historyError={historyError}
        />
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

function DevelopmentHistory({
  tab,
  history,
  currentScore,
  historyError,
}: {
  tab: SkillsTab
  history: SkillHistoryRow[]
  currentScore: number
  historyError: string | null
}) {
  const points = history.map((row) => ({
    date: row.recorded_at,
    score: scoreCategory(row, tab),
  }))
  const baseline = points[0]?.score ?? currentScore
  const change = currentScore - baseline
  const updates = Math.max(0, points.length - 1)
  const lastDate = points.length ? points[points.length - 1].date : null

  return (
    <section className="tlg-skills-history">
      <header className="tlg-skills-history-head">
        <div>
          <span>Development history</span>
          <h3>{TAB_COPY[tab].label} progress</h3>
          <p>Every real attribute change is recorded automatically. This chart will build a complete development history as training and matches begin changing your player.</p>
        </div>
        <div className="tlg-skills-history-kpis">
          <HistoryKpi label="Starting level" value={baseline.toFixed(1)} />
          <HistoryKpi label="Current level" value={currentScore.toFixed(1)} />
          <HistoryKpi label="Total change" value={signed(change)} tone={change > 0.05 ? 'positive' : change < -0.05 ? 'negative' : undefined} />
          <HistoryKpi label="Recorded updates" value={String(updates)} />
        </div>
      </header>

      {historyError ? (
        <div className="tlg-skills-history-empty">Development history could not be loaded: {historyError}</div>
      ) : (
        <div className="tlg-skills-history-chart-wrap">
          <HistoryChart points={points} />
          {points.length <= 1 && (
            <div className="tlg-skills-history-empty">
              Baseline recorded. The graph will start moving as soon as Training or another career system changes this category.
            </div>
          )}
          <div className="tlg-skills-history-foot">
            <span>{lastDate ? `Latest snapshot: ${formatHistoryDate(lastDate)}` : 'No snapshots yet'}</span>
            <span>Scale: 0–100</span>
          </div>
        </div>
      )}
    </section>
  )
}

function HistoryKpi({ label, value, tone }: { label: string; value: string; tone?: 'positive' | 'negative' }) {
  return (
    <div className="tlg-skills-history-kpi">
      <span>{label}</span>
      <strong className={tone ?? ''}>{value}</strong>
    </div>
  )
}

function HistoryChart({ points }: { points: Array<{ date: string; score: number }> }) {
  const width = 960
  const height = 230
  const left = 46
  const right = 22
  const top = 18
  const bottom = 34
  const plotWidth = width - left - right
  const plotHeight = height - top - bottom

  const coordinates = points.map((point, index) => {
    const x = points.length <= 1
      ? left + plotWidth / 2
      : left + (index / (points.length - 1)) * plotWidth
    const score = Math.max(0, Math.min(100, point.score))
    const y = top + ((100 - score) / 100) * plotHeight
    return { ...point, x, y }
  })

  const polyline = coordinates.map((point) => `${point.x},${point.y}`).join(' ')
  const gridValues = [100, 75, 50, 25, 0]
  const labelIndexes = points.length <= 6
    ? points.map((_, index) => index)
    : Array.from(new Set([0, Math.floor((points.length - 1) / 4), Math.floor((points.length - 1) / 2), Math.floor(((points.length - 1) * 3) / 4), points.length - 1]))

  return (
    <svg className="tlg-skills-history-chart" viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Player development history from 0 to 100">
      {gridValues.map((value) => {
        const y = top + ((100 - value) / 100) * plotHeight
        return (
          <g key={value}>
            <line x1={left} x2={width - right} y1={y} y2={y} className="grid-line" />
            <text x={left - 10} y={y + 4} textAnchor="end" className="axis-label">{value}</text>
          </g>
        )
      })}

      {coordinates.length > 1 && <polyline points={polyline} className="history-line" />}

      {coordinates.map((point, index) => (
        <circle key={`${point.date}-${index}`} cx={point.x} cy={point.y} r="4.5" className="history-point" />
      ))}

      {labelIndexes.map((index) => {
        const point = coordinates[index]
        if (!point) return null
        return (
          <text key={`label-${index}`} x={point.x} y={height - 10} textAnchor="middle" className="date-label">
            {formatHistoryDate(point.date, true)}
          </text>
        )
      })}
    </svg>
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
