import { useEffect, useMemo, useState } from 'react'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/player-skills.css'

type SkillsTab = 'condition' | 'tennis'

interface PlayerSkillsRow {
  player_id: string
  preferred_surface: 'Hard' | 'Clay' | 'Grass' | null
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
  note?: string
  inverse?: boolean
}

const SURFACE_COPY: Record<'Hard' | 'Clay' | 'Grass', string> = {
  Hard: 'Balanced starting profile with a small emphasis on groundstrokes, serve and return.',
  Clay: 'Starting profile favors rally tolerance, groundstrokes and return over serve-and-volley play.',
  Grass: 'Starting profile favors serve, volley and slice while sacrificing some return and baseline tolerance.',
}

export default function SkillsPage() {
  const { player } = useAuth()
  const [tab, setTab] = useState<SkillsTab>('condition')
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
        .select('player_id, preferred_surface, serve, forehand, backhand, return_skill, volley, slice, drop_shot, fitness, stamina, recovery, movement, fatigue, sharpness, morale, confidence, focus')
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

  const physical = useMemo<AttributeItem[]>(() => skills ? [
    { label: 'Fitness', value: skills.fitness, note: 'General physical readiness' },
    { label: 'Stamina', value: skills.stamina, note: 'Ability to sustain effort' },
    { label: 'Recovery', value: skills.recovery, note: 'How efficiently the player recovers' },
    { label: 'Movement', value: skills.movement, note: 'Court movement and athletic base' },
    { label: 'Sharpness', value: skills.sharpness, note: 'Competitive rhythm and match readiness' },
    { label: 'Fatigue', value: skills.fatigue, note: 'Accumulated tiredness · lower is better', inverse: true },
  ] : [], [skills])

  const mental = useMemo<AttributeItem[]>(() => skills ? [
    { label: 'Morale', value: skills.morale, note: 'Overall mood and motivation' },
    { label: 'Confidence', value: skills.confidence, note: 'Belief built through results and form' },
    { label: 'Focus', value: skills.focus, note: 'Concentration and mental stability' },
  ] : [], [skills])

  const tennis = useMemo<AttributeItem[]>(() => skills ? [
    { label: 'Serve', value: skills.serve },
    { label: 'Forehand', value: skills.forehand },
    { label: 'Backhand', value: skills.backhand },
    { label: 'Return', value: skills.return_skill },
    { label: 'Volley', value: skills.volley },
    { label: 'Slice', value: skills.slice },
    { label: 'Drop Shot', value: skills.drop_shot },
  ] : [], [skills])

  return (
    <GameLayout title="Skills" subtitle="Attributes, condition and development">
      <header className="tlg-v2-page-head">
        <div className="tlg-v2-page-head-copy">
          <div className="tlg-v2-page-eyebrow">Career development</div>
          <h2 className="tlg-v2-page-title">Player Skills</h2>
          <p className="tlg-v2-page-description">
            Your player begins at the same overall starting level as every other new professional. Preferred surface changes the distribution of starting tennis attributes, not the total starting strength.
          </p>
        </div>
      </header>

      <section className="tlg-skills-shell">
        <div className="tlg-skills-tabs" role="tablist" aria-label="Player skill categories">
          <button
            type="button"
            className={tab === 'condition' ? 'active' : ''}
            onClick={() => setTab('condition')}
            role="tab"
            aria-selected={tab === 'condition'}
          >
            Condition & Mental
          </button>
          <button
            type="button"
            className={tab === 'tennis' ? 'active' : ''}
            onClick={() => setTab('tennis')}
            role="tab"
            aria-selected={tab === 'tennis'}
          >
            Tennis Skills
          </button>
        </div>

        {loading ? (
          <div className="tlg-skills-state">Loading player attributes…</div>
        ) : error ? (
          <div className="tlg-skills-state tlg-skills-state-error">Unable to load player skills: {error}</div>
        ) : !skills ? (
          <div className="tlg-skills-state">Player skill profile has not been initialized yet.</div>
        ) : tab === 'condition' ? (
          <div className="tlg-skills-grid">
            <SkillPanel
              eyebrow="Physical condition"
              title="Body & readiness"
              description="These values will later react to training, match load, rest and recovery."
              items={physical}
            />
            <SkillPanel
              eyebrow="Mental state"
              title="Mindset"
              description="Morale, confidence and focus will later move with results, form and career events."
              items={mental}
            />
          </div>
        ) : (
          <div className="tlg-skills-grid tlg-skills-grid-tennis">
            <SkillPanel
              eyebrow="Technical profile"
              title="Tennis skills"
              description="These are the first core racket skills. Training and progression rules will be connected later."
              items={tennis}
            />

            <aside className="tlg-surface-profile">
              <span>Preferred surface</span>
              <strong>{skills.preferred_surface ?? 'Neutral'}</strong>
              <p>
                {skills.preferred_surface
                  ? SURFACE_COPY[skills.preferred_surface]
                  : 'This player predates the preferred-surface choice and currently uses a neutral starting profile.'}
              </p>
              <div className="tlg-surface-rule">
                All new players start with the same total tennis-skill points. Surface preference only redistributes those points to create a different playing style.
              </div>
            </aside>
          </div>
        )}
      </section>
    </GameLayout>
  )
}

function SkillPanel({
  eyebrow,
  title,
  description,
  items,
}: {
  eyebrow: string
  title: string
  description: string
  items: AttributeItem[]
}) {
  return (
    <section className="tlg-skill-panel">
      <header>
        <span>{eyebrow}</span>
        <h3>{title}</h3>
        <p>{description}</p>
      </header>
      <div className="tlg-skill-list">
        {items.map((item) => (
          <div className="tlg-skill-row" key={item.label}>
            <div className="tlg-skill-row-head">
              <div>
                <strong>{item.label}</strong>
                {item.note && <small>{item.note}</small>}
              </div>
              <b>{item.value}</b>
            </div>
            <div className={`tlg-skill-meter ${item.inverse ? 'inverse' : ''}`} aria-label={`${item.label}: ${item.value} out of 100`}>
              <span style={{ width: `${Math.max(0, Math.min(100, item.value))}%` }} />
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}
