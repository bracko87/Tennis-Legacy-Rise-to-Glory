import { useEffect, useMemo, useState, type CSSProperties } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'
import PlayerDevelopmentIntelligence from '../../components/premium/PlayerDevelopmentIntelligence'
import { supabase } from '../../lib/supabase'
import { weeklySkillSnapshots, gameWeekText } from '../../lib/skillGameWeeks'
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
  lob: number
  smash: number
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
  game_season: number | null
  game_week: number | null
  source: string
  serve: number
  forehand: number
  backhand: number
  return_skill: number
  volley: number
  slice: number
  drop_shot: number
  lob: number
  smash: number
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

const SURFACE_COPY_KEYS: Record<PreferredSurface, string> = {
  Hard: 'skillsPage.surfaces.Hard',
  Clay: 'skillsPage.surfaces.Clay',
  Grass: 'skillsPage.surfaces.Grass',
}

const STYLE_COPY_KEYS: Record<PlayingStyle, string> = {
  'Aggressive Baseliner': 'skillsPage.styles.aggressive',
  'Defensive Baseliner': 'skillsPage.styles.defensive',
  'All-court': 'skillsPage.styles.allCourt',
  'Serve & Volley': 'skillsPage.styles.serveVolley',
}

function scoreCategory(row: PlayerSkillsRow | SkillHistoryRow, tab: SkillsTab) {
  if (tab === 'tennis') {
    return (
      row.serve + row.forehand + row.backhand + row.return_skill + row.volley +
      row.slice + row.drop_shot + row.lob + row.smash
    ) / 9
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

function readinessLabel(score: number, t: TFunction) {
  if (score >= 80) return t('skillsPage.readinessLabels.excellent')
  if (score >= 65) return t('skillsPage.readinessLabels.strong')
  if (score >= 50) return t('skillsPage.readinessLabels.ready')
  if (score >= 35) return t('skillsPage.readinessLabels.managingLoad')
  return t('skillsPage.readinessLabels.needsRecovery')
}

function heatLevel(value: number) {
  if (value >= 75) return 'high'
  if (value >= 60) return 'strong'
  if (value >= 45) return 'balanced'
  return 'development'
}

function developmentDirection(history: SkillHistoryRow[], t: TFunction) {
  const updates = Math.max(0, history.length - 1)
  if (!updates) return t('skillsPage.developmentDirection.baseline')
  const latest = history[history.length - 1]
  const previous = history[history.length - 2]
  const technicalMove = scoreCategory(latest, 'tennis') - scoreCategory(previous, 'tennis')
  const physicalMove = scoreCategory(latest, 'physical') - scoreCategory(previous, 'physical')
  if (technicalMove > 0.05 || physicalMove > 0.05) return t('skillsPage.developmentDirection.improving')
  if (technicalMove < -0.05 || physicalMove < -0.05) return t('skillsPage.developmentDirection.declining')
  return t('skillsPage.developmentDirection.stable')
}

export default function SkillsPage() {
  const { t } = useTranslation()
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
          .select('player_id, preferred_surface, playing_style, serve, forehand, backhand, return_skill, volley, slice, drop_shot, lob, smash, fitness, stamina, recovery, movement, fatigue, sharpness, morale, confidence, focus')
          .eq('player_id', player.id)
          .maybeSingle(),
        supabase
          .from('player_skill_history')
          .select('id, player_id, recorded_at, game_season, game_week, source, serve, forehand, backhand, return_skill, volley, slice, drop_shot, lob, smash, fitness, stamina, recovery, movement, fatigue, sharpness, morale, confidence, focus')
          .eq('player_id', player.id)
          .order('recorded_at', { ascending: false })
          .limit(240),
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
        setHistory([...(historyResult.data ?? [])].reverse() as SkillHistoryRow[])
      }

      setLoading(false)
    }

    void loadSkills()
    return () => { active = false }
  }, [player?.id])

  const tabCopy: Record<SkillsTab, { label: string; kicker: string; title: string; description: string }> = {
    tennis: {
      label: t('skillsPage.tabs.tennis.label'),
      kicker: t('skillsPage.tabs.tennis.kicker'),
      title: t('skillsPage.tabs.tennis.title'),
      description: t('skillsPage.tabs.tennis.description'),
    },
    physical: {
      label: t('skillsPage.tabs.physical.label'),
      kicker: t('skillsPage.tabs.physical.kicker'),
      title: t('skillsPage.tabs.physical.title'),
      description: t('skillsPage.tabs.physical.description'),
    },
    condition: {
      label: t('skillsPage.tabs.condition.label'),
      kicker: t('skillsPage.tabs.condition.kicker'),
      title: t('skillsPage.tabs.condition.title'),
      description: t('skillsPage.tabs.condition.description'),
    },
  }

  const previousSnapshot = history.length > 1 ? history[history.length - 2] : null

  const tennis = useMemo<AttributeItem[]>(() => skills ? [
    { label: t('skillsPage.attributes.serve.label'), value: skills.serve, note: t('skillsPage.attributes.serve.note'), change: previousSnapshot ? skills.serve - previousSnapshot.serve : 0 },
    { label: t('skillsPage.attributes.forehand.label'), value: skills.forehand, note: t('skillsPage.attributes.forehand.note'), change: previousSnapshot ? skills.forehand - previousSnapshot.forehand : 0 },
    { label: t('skillsPage.attributes.backhand.label'), value: skills.backhand, note: t('skillsPage.attributes.backhand.note'), change: previousSnapshot ? skills.backhand - previousSnapshot.backhand : 0 },
    { label: t('skillsPage.attributes.return.label'), value: skills.return_skill, note: t('skillsPage.attributes.return.note'), change: previousSnapshot ? skills.return_skill - previousSnapshot.return_skill : 0 },
    { label: t('skillsPage.attributes.volley.label'), value: skills.volley, note: t('skillsPage.attributes.volley.note'), change: previousSnapshot ? skills.volley - previousSnapshot.volley : 0 },
    { label: t('skillsPage.attributes.slice.label'), value: skills.slice, note: t('skillsPage.attributes.slice.note'), change: previousSnapshot ? skills.slice - previousSnapshot.slice : 0 },
    { label: t('skillsPage.attributes.dropShot.label'), value: skills.drop_shot, note: t('skillsPage.attributes.dropShot.note'), change: previousSnapshot ? skills.drop_shot - previousSnapshot.drop_shot : 0 },
    { label: t('skillsPage.attributes.lob.label'), value: skills.lob, note: t('skillsPage.attributes.lob.note'), change: previousSnapshot ? skills.lob - previousSnapshot.lob : 0 },
    { label: t('skillsPage.attributes.smash.label'), value: skills.smash, note: t('skillsPage.attributes.smash.note'), change: previousSnapshot ? skills.smash - previousSnapshot.smash : 0 },
  ] : [], [skills, previousSnapshot, t])

  const physical = useMemo<AttributeItem[]>(() => skills ? [
    { label: t('skillsPage.attributes.fitness.label'), value: skills.fitness, note: t('skillsPage.attributes.fitness.note'), change: previousSnapshot ? skills.fitness - previousSnapshot.fitness : 0 },
    { label: t('skillsPage.attributes.stamina.label'), value: skills.stamina, note: t('skillsPage.attributes.stamina.note'), change: previousSnapshot ? skills.stamina - previousSnapshot.stamina : 0 },
    { label: t('skillsPage.attributes.recovery.label'), value: skills.recovery, note: t('skillsPage.attributes.recovery.note'), change: previousSnapshot ? skills.recovery - previousSnapshot.recovery : 0 },
    { label: t('skillsPage.attributes.movement.label'), value: skills.movement, note: t('skillsPage.attributes.movement.note'), change: previousSnapshot ? skills.movement - previousSnapshot.movement : 0 },
  ] : [], [skills, previousSnapshot, t])

  const condition = useMemo<AttributeItem[]>(() => skills ? [
    { label: t('skillsPage.attributes.morale.label'), value: skills.morale, note: t('skillsPage.attributes.morale.note'), change: previousSnapshot ? skills.morale - previousSnapshot.morale : 0 },
    { label: t('skillsPage.attributes.confidence.label'), value: skills.confidence, note: t('skillsPage.attributes.confidence.note'), change: previousSnapshot ? skills.confidence - previousSnapshot.confidence : 0 },
    { label: t('skillsPage.attributes.sharpness.label'), value: skills.sharpness, note: t('skillsPage.attributes.sharpness.note'), change: previousSnapshot ? skills.sharpness - previousSnapshot.sharpness : 0 },
    { label: t('skillsPage.attributes.focus.label'), value: skills.focus, note: t('skillsPage.attributes.focus.note'), change: previousSnapshot ? skills.focus - previousSnapshot.focus : 0 },
    { label: t('skillsPage.attributes.fatigue.label'), value: skills.fatigue, note: t('skillsPage.attributes.fatigue.note'), inverse: true, change: previousSnapshot ? skills.fatigue - previousSnapshot.fatigue : 0 },
  ] : [], [skills, previousSnapshot, t])

  const tennisTotal = useMemo(() => tennis.reduce((sum, item) => sum + item.value, 0), [tennis])
  const physicalTotal = useMemo(() => physical.reduce((sum, item) => sum + item.value, 0), [physical])
  const activeCopy = tabCopy[tab]
  const activeItems = tab === 'tennis' ? tennis : tab === 'physical' ? physical : condition
  const activeScore = skills ? scoreCategory(skills, tab) : 0
  const baselineScore = history.length ? scoreCategory(history[0], tab) : activeScore
  const scoreChange = activeScore - baselineScore
  const categoryDetail = tab === 'tennis'
    ? t('skillsPage.tennisDetail', { points: tennisTotal })
    : tab === 'physical'
      ? t('skillsPage.physicalDetail', { points: physicalTotal })
      : t('skillsPage.conditionDetail')

  const technical = skills ? scoreCategory(skills, 'tennis') : 0
  const physicalScore = skills ? scoreCategory(skills, 'physical') : 0
  const readiness = skills ? scoreCategory(skills, 'condition') : 0
  const baseline = history[0] ?? null
  const baselineTechnicalTotal = baseline
    ? baseline.serve + baseline.forehand + baseline.backhand + baseline.return_skill + baseline.volley + baseline.slice + baseline.drop_shot + baseline.lob + baseline.smash
    : tennisTotal
  const technicalChange = baseline && skills ? technical - scoreCategory(baseline, 'tennis') : 0
  const physicalChange = baseline && skills ? physicalScore - scoreCategory(baseline, 'physical') : 0
  const recordedGains = history.reduce((total, row, index) => {
    if (!index) return total
    const previous = history[index - 1]
    const skillsToCount = ['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash','fitness','stamina','recovery','movement'] as const
    return total + skillsToCount.reduce((gain,key)=>gain+Math.max(0,row[key]-previous[key]),0)
  },0)
  const direction = developmentDirection(history, t)

  return (
    <GameLayout title={t('skillsPage.title')} subtitle={t('skillsPage.subtitle')}>
      <section className="tlg-v2-command tlg-skills-command">
        <div className="tlg-v2-command-inner tlg-skills-command-inner">
          <div className="tlg-skills-command-copy">
            <span className="tlg-v2-command-kicker">{t('skillsPage.kicker')}</span>
            <h2>{t('skillsPage.heading')}</h2>
            <p>
              {t('skillsPage.intro')}
            </p>
          </div>
        </div>
      </section>

      <section className="tlg-skills-workspace">
        <nav className="tlg-skills-side-tabs" role="tablist" aria-label={t('skillsPage.categoriesAria')}>
          <div className="tlg-skills-side-heading">
            <span>{t('skillsPage.development')}</span>
          </div>

          {(Object.keys(tabCopy) as SkillsTab[]).map((tabId) => {
            const item = tabCopy[tabId]
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

          {!loading && skills && (
            <div
              style={{
                gridColumn: '1 / -1',
                padding: '14px 13px 15px',
                borderTop: '1px solid #e7eef4',
                background: '#f8fbfd',
              }}
            >
              <span
                style={{
                  display: 'block',
                  marginBottom: 9,
                  color: '#0874d1',
                  fontSize: '.58rem',
                  fontWeight: 700,
                  letterSpacing: '.09em',
                  textTransform: 'uppercase',
                }}
              >
                {t('skillsPage.performanceSnapshot')}
              </span>
              <div style={{ display: 'grid', gap: 8 }}>
                <SidebarMetric label={t('skillsPage.technical')} value={technical.toFixed(1)} detail={t('skillsPage.sinceStart', { change: signed(technicalChange) })} />
                <SidebarMetric label={t('skillsPage.physical')} value={physicalScore.toFixed(1)} detail={t('skillsPage.sinceStart', { change: signed(physicalChange) })} />
                <SidebarMetric label={t('skillsPage.readiness')} value={readiness.toFixed(1)} detail={readinessLabel(readiness, t)} />
                <SidebarMetric label={t('skillsPage.recordedDevelopment')} value={String(recordedGains)} detail={direction} />
              </div>
            </div>
          )}
        </nav>

        <div className="tlg-skills-main">
          {loading ? (
            <div className="tlg-skills-state">{t('skillsPage.loading')}</div>
          ) : error ? (
            <div className="tlg-skills-state tlg-skills-state-error">{t('skillsPage.loadError', { error })}</div>
          ) : !skills ? (
            <div className="tlg-skills-state">{t('skillsPage.notInitialized')}</div>
          ) : (
            <>
              <header className="tlg-skills-section-head">
                <div>
                  <span>{activeCopy.kicker}</span>
                  <h3>{activeCopy.title}</h3>
                  <p>{activeCopy.description}</p>
                </div>
                <div className="tlg-skills-section-score">
                  <span>{tab === 'condition' ? t('skillsPage.readinessScore') : t('skillsPage.categoryAverage')}</span>
                  <div><strong>{activeScore.toFixed(1)}</strong><small>/ 100</small></div>
                  <p>{categoryDetail}</p>
                  <em className={scoreChange > 0.05 ? 'positive' : scoreChange < -0.05 ? 'negative' : ''}>{t('skillsPage.sinceStart', { change: signed(scoreChange) })}</em>
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
                    label={t('skillsPage.preferredSurface')}
                    value={skills.preferred_surface ?? t('skillsPage.neutral')}
                    description={skills.preferred_surface ? t(SURFACE_COPY_KEYS[skills.preferred_surface]) : t('skillsPage.neutralSurface')}
                  />
                  <BuildCard
                    label={t('skillsPage.playingStyle')}
                    value={skills.playing_style}
                    description={t('skillsPage.styleFixed', { description: t(STYLE_COPY_KEYS[skills.playing_style]) })}
                  />
                  <BuildCard
                    label={t('skillsPage.startingProfile')}
                    value={t('skillsPage.startingPoints', { points: baselineTechnicalTotal })}
                    description={t('skillsPage.startingProfileBody')}
                  />
                </div>
              )}

              {tab === 'physical' && (
                <div className="tlg-skills-info-strip">
                  {t('skillsPage.physicalStartNote')}
                </div>
              )}

              {tab === 'condition' && (
                <div className="tlg-skills-info-strip">
                  {t('skillsPage.conditionStartNote')}
                </div>
              )}
            </>
          )}
        </div>
      </section>

      {!loading && skills && (
        <PlayerDevelopmentIntelligence playerId={player?.id ?? null} />
      )}

      {!loading && skills && (
        <PerformanceCentre skills={skills} history={history} historyError={historyError} />
      )}
    </GameLayout>
  )
}

function SidebarMetric({ label, value, detail }: { label: string; value: string; detail: string }) {
  return (
    <div style={{ padding: '10px 11px', border: '1px solid #dce7ef', borderRadius: 8, background: '#fff' }}>
      <span style={{ display: 'block', color: '#8295a4', fontSize: '.54rem', textTransform: 'uppercase', letterSpacing: '.05em' }}>{label}</span>
      <strong style={{ display: 'block', marginTop: 4, color: '#102f47', fontSize: '.92rem' }}>{value}</strong>
      <small style={{ display: 'block', marginTop: 3, color: '#8295a4', fontSize: '.56rem', lineHeight: 1.35 }}>{detail}</small>
    </div>
  )
}

function SkillCard({ item }: { item: AttributeItem }) {
  const { t } = useTranslation()
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
      <div className="tlg-skill-card-meter" aria-label={t('skillsPage.valueAria', { label: item.label, value: item.value })}>
        <span style={{ width: `${displayFill}%` }} />
      </div>
      <div className="tlg-skill-card-scale" aria-hidden="true">
        <span>{item.inverse ? t('skillsPage.fresh') : '0'}</span>
        <span>{item.inverse ? t('skillsPage.tired') : '100'}</span>
      </div>
      {hasChange && (
        <div className="tlg-skill-change-note">
          <strong>{improved ? t('skillsPage.latestImprovement') : t('skillsPage.latestChange')}</strong>
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

function PerformanceCentre({ skills, history, historyError }: { skills: PlayerSkillsRow; history: SkillHistoryRow[]; historyError: string | null }) {
  const { t } = useTranslation()
  const technical = scoreCategory(skills, 'tennis')
  const physical = scoreCategory(skills, 'physical')
  const readiness = scoreCategory(skills, 'condition')
  const freshness = Math.max(0, Math.min(100, 100 - skills.fatigue))
  const baseline = history[0] ?? null
  const technicalChange = baseline ? technical - scoreCategory(baseline, 'tennis') : 0
  const physicalChange = baseline ? physical - scoreCategory(baseline, 'physical') : 0
  const readinessChange = baseline ? readiness - scoreCategory(baseline, 'condition') : 0
  const updates = Math.max(0,history.length-1)
  const direction = developmentDirection(history, t)
  const weeklyHistory = weeklySkillSnapshots(history)

  const tennisValues = [
    { label: t('skillsPage.attributes.serve.label'), value: skills.serve },
    { label: t('skillsPage.attributes.forehand.label'), value: skills.forehand },
    { label: t('skillsPage.attributes.backhand.label'), value: skills.backhand },
    { label: t('skillsPage.attributes.return.label'), value: skills.return_skill },
    { label: t('skillsPage.attributes.volley.label'), value: skills.volley },
    { label: t('skillsPage.attributes.slice.label'), value: skills.slice },
    { label: t('skillsPage.attributes.dropShot.label'), value: skills.drop_shot },
    { label: t('skillsPage.attributes.lob.label'), value: skills.lob },
    { label: t('skillsPage.attributes.smash.label'), value: skills.smash },
  ]

  const physicalValues = [
    { label: t('skillsPage.attributes.fitness.label'), value: skills.fitness },
    { label: t('skillsPage.attributes.stamina.label'), value: skills.stamina },
    { label: t('skillsPage.attributes.recovery.label'), value: skills.recovery },
    { label: t('skillsPage.attributes.movement.label'), value: skills.movement },
  ]

  const conditionValues = [
    { label: t('skillsPage.attributes.morale.label'), value: skills.morale },
    { label: t('skillsPage.attributes.confidence.label'), value: skills.confidence },
    { label: t('skillsPage.attributes.sharpness.label'), value: skills.sharpness },
    { label: t('skillsPage.attributes.focus.label'), value: skills.focus },
    { label: t('skillsPage.attributes.freshness.label'), value: freshness },
  ]

  const strongestTennis = tennisValues.reduce((best, item) => item.value > best.value ? item : best)
  const priorityTennis = tennisValues.reduce((lowest, item) => item.value < lowest.value ? item : lowest)
  const strongestPhysical = physicalValues.reduce((best, item) => item.value > best.value ? item : best)
  const heatmap = [
    ...tennisValues.map((item) => ({ ...item, group: t('skillsPage.tennisGroup') })),
    ...physicalValues.map((item) => ({ ...item, group: t('skillsPage.physicalGroup') })),
    ...conditionValues.map((item) => ({ ...item, group: t('skillsPage.conditionGroup') })),
  ]

  return (
    <section className="tlg-performance-centre" style={{ marginTop: 14 }}>
      <div className="tlg-performance-top-grid">
        <AnalysisPanel title={t('skillsPage.technicalRadar')} description={t('skillsPage.technicalRadarBody')}>
          <TennisRadar values={tennisValues} />
        </AnalysisPanel>

        <AnalysisPanel title={t('skillsPage.performanceGauges')} description={t('skillsPage.performanceGaugesBody')}>
          <div className="tlg-gauge-grid">
            <Gauge label={t('skillsPage.technicalProfile')} value={technical} detail={t('skillsPage.averageTennisSkill')} />
            <Gauge label={t('skillsPage.physicalProfile')} value={physical} detail={t('skillsPage.athleticBase')} />
            <Gauge label={t('skillsPage.currentReadiness')} value={readiness} detail={readinessLabel(readiness, t)} />
            <Gauge label={t('skillsPage.attributes.freshness.label')} value={freshness} detail={t('skillsPage.fatigueDetail', { value: skills.fatigue })} />
          </div>
        </AnalysisPanel>
      </div>

      <AnalysisPanel title={t('skillsPage.attributeHeatmap')} description={t('skillsPage.attributeHeatmapBody')}>
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
        <AnalysisPanel title={t('skillsPage.developmentIntelligence')} description={t('skillsPage.developmentIntelligenceBody')}>
          <div className="tlg-intelligence-grid">
            <InsightCard label={t('skillsPage.primaryStrength')} value={strongestTennis.label} detail={`${strongestTennis.value}/100`} />
            <InsightCard label={t('skillsPage.technicalPriority')} value={priorityTennis.label} detail={`${priorityTennis.value}/100`} />
            <InsightCard label={t('skillsPage.strongestPhysical')} value={strongestPhysical.label} detail={`${strongestPhysical.value}/100`} />
            <InsightCard label={t('skillsPage.currentStatus')} value={readinessLabel(readiness, t)} detail={t('skillsPage.readinessDetail', { value: readiness.toFixed(1) })} />
            <InsightCard label={t('skillsPage.direction')} value={direction} detail={t('skillsPage.updates', { count: updates })} />
            <InsightCard label={t('skillsPage.careerIdentity')} value={skills.playing_style} detail={t('skillsPage.surfaceDetail', { surface: skills.preferred_surface ?? t('skillsPage.neutral') })} />
          </div>
        </AnalysisPanel>

        <AnalysisPanel title={t('skillsPage.developmentMatrix')} description={t('skillsPage.developmentMatrixBody')}>
          <div className="tlg-development-matrix">
            <MatrixRow label={t('skillsPage.technical')} value={technical} change={technicalChange} />
            <MatrixRow label={t('skillsPage.physical')} value={physical} change={physicalChange} />
            <MatrixRow label={t('skillsPage.readiness')} value={readiness} change={readinessChange} />
          </div>
        </AnalysisPanel>
      </div>

      <AnalysisPanel title={t('skillsPage.developmentHistory')} description={t('skillsPage.developmentHistoryBody')}>
        {historyError ? (
          <div className="tlg-performance-empty">{t('skillsPage.historyError', { error: historyError })}</div>
        ) : (
          <>
            <MultiHistoryChart history={weeklyHistory} />
            {history.some(row=>row.game_season===null || row.game_week===null) && (
              <div className="tlg-performance-empty">{t('developmentPremium.undatedHistory')}</div>
            )}
            {weeklyHistory.length <= 1 && (
              <div className="tlg-performance-empty">
                {t('skillsPage.baselineRecorded')}
              </div>
            )}
            <div className="tlg-history-meta">
              <span>{weeklyHistory.length ? t('skillsPage.firstSnapshot', { date: gameWeekText(weeklyHistory[0],t) }) : t('skillsPage.noSnapshots')}</span>
              <span>{weeklyHistory.length ? t('skillsPage.latestSnapshot', { date: gameWeekText(weeklyHistory[weeklyHistory.length - 1],t) }) : t('skillsPage.scale')}</span>
            </div>
          </>
        )}
      </AnalysisPanel>
    </section>
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
      <div className="tlg-gauge" style={{ '--gauge-value': `${normalized * 3.6}deg` } as CSSProperties}>
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
  const { t } = useTranslation()
  const width = 470
  const height = 350
  const cx = 235
  const cy = 172
  const radius = 105
  const count = values.length

  const pointAt = (index: number, scale: number) => {
    const angle = -Math.PI / 2 + (index / count) * Math.PI * 2
    return { x: cx + Math.cos(angle) * radius * scale, y: cy + Math.sin(angle) * radius * scale }
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
    <svg className="tlg-tennis-radar" viewBox={`0 0 ${width} ${height}`} role="img" aria-label={t('skillsPage.radarAria')}>
      {[0.25, 0.5, 0.75, 1].map((scale) => <polygon key={scale} points={ringPoints(scale)} className="radar-ring" />)}
      {values.map((item, index) => {
        const outer = pointAt(index, 1)
        const label = pointAt(index, 1.3)
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
  const { t } = useTranslation()
  return (
    <div className="tlg-matrix-row">
      <div className="tlg-matrix-copy">
        <strong>{label}</strong>
        <span className={change > 0.05 ? 'positive' : change < -0.05 ? 'negative' : ''}>{t('skillsPage.sinceStart', { change: signed(change) })}</span>
      </div>
      <div className="tlg-matrix-value"><strong>{value.toFixed(1)}</strong><span>/100</span></div>
      <div className="tlg-matrix-meter"><span style={{ width: `${Math.max(0, Math.min(100, value))}%` }} /></div>
    </div>
  )
}

function MultiHistoryChart({ history }: { history: SkillHistoryRow[] }) {
  const { t } = useTranslation()
  const width = 1040
  const height = 300
  const left = 48
  const right = 24
  const top = 26
  const bottom = 42
  const plotWidth = width - left - right
  const plotHeight = height - top - bottom
  const rows = history.map((row) => ({
    date: gameWeekText(row,t),
    technical: scoreCategory(row, 'tennis'),
    physical: scoreCategory(row, 'physical'),
    readiness: scoreCategory(row, 'condition'),
  }))

  const gameWeekOrdinals = history.map(row => (row.game_season ?? 1) * 53 + (row.game_week ?? 0))
  const firstGameWeek = gameWeekOrdinals[0] ?? 0
  const lastGameWeek = gameWeekOrdinals[gameWeekOrdinals.length - 1] ?? firstGameWeek
  const coordinate = (value: number, index: number) => ({
    x: lastGameWeek === firstGameWeek
      ? left + plotWidth / 2
      : left + ((gameWeekOrdinals[index] - firstGameWeek) / (lastGameWeek - firstGameWeek)) * plotWidth,
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
        <span className="technical">{t('skillsPage.technical')}</span>
        <span className="physical">{t('skillsPage.physical')}</span>
        <span className="readiness">{t('skillsPage.readiness')}</span>
      </div>
      <svg className="tlg-multi-history" viewBox={`0 0 ${width} ${height}`} role="img" aria-label={t('skillsPage.historyAria')}>
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

        {rows.map((row, index) => {
          const technicalPoint = coordinate(row.technical, index)
          const physicalPoint = coordinate(row.physical, index)
          const readinessPoint = coordinate(row.readiness, index)
          return (
            <g key={`${row.date}-${index}`}>
              <circle cx={technicalPoint.x} cy={technicalPoint.y} r="4" className="trend-point technical" />
              <circle cx={physicalPoint.x} cy={physicalPoint.y} r="4" className="trend-point physical" />
              <circle cx={readinessPoint.x} cy={readinessPoint.y} r="4" className="trend-point readiness" />
            </g>
          )
        })}

        {labelIndexes.map((index) => {
          const row = rows[index]
          if (!row) return null
          const point = coordinate(row.technical, index)
          return <text key={`date-${index}`} x={point.x} y={height - 12} textAnchor="middle" className="date-label">{row.date}</text>
        })}
      </svg>
    </div>
  )
}

