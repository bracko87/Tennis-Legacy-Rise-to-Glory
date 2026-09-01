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

interface AttributeItem {
  label: string
  value: number
  note: string
  inverse?: boolean
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
    description: 'Dynamic values that will rise and fall through matches, rest, form, training load and career events rather than permanent skill progression.',
  },
}

export default function SkillsPage() {
  const { player } = useAuth()
  const [tab, setTab] = useState<SkillsTab>('tennis')
  const [skills, setSkills] = useState<PlayerSkillsRow | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let active = true

    async function loadSkills() {
      if (!player?.id) {
        setSkills(null)
        setLoading(false)
        return
      }

      setLoading(true)
      setError(null)

      const { data, error: loadError } = await supabase
        .from('player_skills')
        .select('player_id, preferred_surface, playing_style, serve, forehand, backhand, return_skill, volley, slice, drop_shot, fitness, stamina, recovery, movement, fatigue, sharpness, morale, confidence, focus')
        .eq('player_id', player.id)
        .maybeSingle()

      if (!active) return

      if (loadError) {
        setError(loadError.message)
        setSkills(null)
      } else {
        setSkills((data ?? null) as PlayerSkillsRow | null)
      }
      setLoading(false)
    }

    void loadSkills()
    return () => { active = false }
  }, [player?.id])

  const tennis = useMemo<AttributeItem[]>(() => skills ? [
    { label: 'Serve', value: skills.serve, note: 'Power, placement and reliability' },
    { label: 'Forehand', value: skills.forehand, note: 'Primary attacking groundstroke' },
    { label: 'Backhand', value: skills.backhand, note: 'Quality, control and stability' },
    { label: 'Return', value: skills.return_skill, note: 'Neutralizing and attacking serve' },
    { label: 'Volley', value: skills.volley, note: 'Net play and finishing ability' },
    { label: 'Slice', value: skills.slice, note: 'Variation and low-ball control' },
    { label: 'Drop Shot', value: skills.drop_shot, note: 'Touch and short-court variation' },
  ] : [], [skills])

  const physical = useMemo<AttributeItem[]>(() => skills ? [
    { label: 'Fitness', value: skills.fitness, note: 'General athletic readiness' },
    { label: 'Stamina', value: skills.stamina, note: 'Maintaining quality in long matches' },
    { label: 'Recovery', value: skills.recovery, note: 'Recovery between matches and sessions' },
    { label: 'Movement', value: skills.movement, note: 'Court coverage, speed and balance' },
  ] : [], [skills])

  const condition = useMemo<AttributeItem[]>(() => skills ? [
    { label: 'Morale', value: skills.morale, note: 'Current motivation and emotional state' },
    { label: 'Confidence', value: skills.confidence, note: 'Belief shaped by form and results' },
    { label: 'Sharpness', value: skills.sharpness, note: 'Competitive rhythm and match readiness' },
    { label: 'Focus', value: skills.focus, note: 'Concentration and mental stability' },
    { label: 'Fatigue', value: skills.fatigue, note: 'Accumulated tiredness · lower is better', inverse: true },
  ] : [], [skills])

  const tennisTotal = useMemo(() => tennis.reduce((sum, item) => sum + item.value, 0), [tennis])
  const activeCopy = TAB_COPY[tab]
  const activeItems = tab === 'tennis' ? tennis : tab === 'physical' ? physical : condition

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

          <div className="tlg-skills-command-summary">
            <SummaryItem label="Tennis strength" value={loading || !skills ? '—' : String(tennisTotal)} />
            <SummaryItem label="Preferred surface" value={skills?.preferred_surface ?? '—'} />
            <SummaryItem label="Playing style" value={skills?.playing_style ?? '—'} />
          </div>
        </div>
      </section>

      <section className="tlg-skills-workspace">
        <nav className="tlg-skills-side-tabs" role="tablist" aria-label="Player skill categories">
          <div className="tlg-skills-side-heading">
            <span>Development</span>
            <strong>Player profile</strong>
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
                <div className="tlg-skills-section-count">
                  <strong>{activeItems.length}</strong>
                  <span>{tab === 'condition' ? 'live values' : 'attributes'}</span>
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
                    label="Playing style"
                    value={skills.playing_style}
                    description={STYLE_COPY[skills.playing_style]}
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
    </GameLayout>
  )
}

function SummaryItem({ label, value }: { label: string; value: string }) {
  return (
    <div className="tlg-skills-summary-item">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  )
}

function SkillCard({ item }: { item: AttributeItem }) {
  const normalized = Math.max(0, Math.min(100, item.value))
  const displayFill = item.inverse ? 100 - normalized : normalized

  return (
    <article className={`tlg-skill-card ${item.inverse ? 'inverse' : ''}`}>
      <div className="tlg-skill-card-top">
        <div>
          <span>{item.label}</span>
          <p>{item.note}</p>
        </div>
        <strong>{item.value}</strong>
      </div>
      <div className="tlg-skill-card-meter" aria-label={`${item.label}: ${item.value} out of 100`}>
        <span style={{ width: `${displayFill}%` }} />
      </div>
      <div className="tlg-skill-card-scale" aria-hidden="true">
        <span>{item.inverse ? 'Fresh' : '0'}</span>
        <span>{item.inverse ? 'Tired' : '100'}</span>
      </div>
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
