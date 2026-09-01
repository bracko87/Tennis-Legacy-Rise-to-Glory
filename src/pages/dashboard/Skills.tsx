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
  note?: string
  inverse?: boolean
}

const SURFACE_COPY: Record<PreferredSurface, string> = {
  Hard: 'Balanced court identity with a small starting emphasis on groundstrokes, serve and return.',
  Clay: 'Court identity favors rally tolerance, groundstrokes and return over serve-and-volley play.',
  Grass: 'Court identity favors serve, volley and slice while giving up some return and baseline tolerance.',
}

const STYLE_COPY: Record<PlayingStyle, string> = {
  'Aggressive Baseliner': 'Adds a small starting emphasis to forehand pressure and attacking from the baseline.',
  'Defensive Baseliner': 'Adds a small starting emphasis to return, backhand stability and defensive resistance.',
  'All-court': 'Neutral style. No additional redistribution is applied beyond the preferred surface.',
  'Serve & Volley': 'Adds a small starting emphasis to serve, volley and forward-court play.',
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
    { label: 'Serve', value: skills.serve, note: 'Power, placement and reliability on serve' },
    { label: 'Forehand', value: skills.forehand, note: 'Primary baseline attacking stroke' },
    { label: 'Backhand', value: skills.backhand, note: 'Backhand quality and stability' },
    { label: 'Return', value: skills.return_skill, note: 'Ability to neutralize and attack serve' },
    { label: 'Volley', value: skills.volley, note: 'Net play and finishing ability' },
    { label: 'Slice', value: skills.slice, note: 'Variation, control and low-ball handling' },
    { label: 'Drop Shot', value: skills.drop_shot, note: 'Touch and short-court variation' },
  ] : [], [skills])

  const physical = useMemo<AttributeItem[]>(() => skills ? [
    { label: 'Fitness', value: skills.fitness, note: 'General athletic readiness and physical base' },
    { label: 'Stamina', value: skills.stamina, note: 'Ability to maintain quality over long matches' },
    { label: 'Recovery', value: skills.recovery, note: 'How efficiently the body recovers between efforts' },
    { label: 'Movement', value: skills.movement, note: 'Court coverage, speed and athletic movement' },
  ] : [], [skills])

  const condition = useMemo<AttributeItem[]>(() => skills ? [
    { label: 'Morale', value: skills.morale, note: 'Current motivation and emotional state' },
    { label: 'Confidence', value: skills.confidence, note: 'Current belief shaped by form and results' },
    { label: 'Sharpness', value: skills.sharpness, note: 'Current competitive rhythm and match readiness' },
    { label: 'Focus', value: skills.focus, note: 'Current concentration and mental stability' },
    { label: 'Fatigue', value: skills.fatigue, note: 'Accumulated tiredness · lower is better', inverse: true },
  ] : [], [skills])

  const tennisTotal = useMemo(() => tennis.reduce((sum, item) => sum + item.value, 0), [tennis])

  return (
    <GameLayout title="Skills" subtitle="Attributes, condition and development">
      <header className="tlg-v2-page-head">
        <div className="tlg-v2-page-head-copy">
          <div className="tlg-v2-page-eyebrow">Career development</div>
          <h2 className="tlg-v2-page-title">Player Skills</h2>
          <p className="tlg-v2-page-description">
            Every new player begins with the same overall starting strength. Preferred surface and playing style only redistribute the starting tennis points; joining later never gives a stronger starting player.
          </p>
        </div>
      </header>

      <section className="tlg-skills-shell">
        <div className="tlg-skills-tabs" role="tablist" aria-label="Player skill categories">
          <button type="button" className={tab === 'tennis' ? 'active' : ''} onClick={() => setTab('tennis')} role="tab" aria-selected={tab === 'tennis'}>
            Tennis Skills
          </button>
          <button type="button" className={tab === 'physical' ? 'active' : ''} onClick={() => setTab('physical')} role="tab" aria-selected={tab === 'physical'}>
            Physical
          </button>
          <button type="button" className={tab === 'condition' ? 'active' : ''} onClick={() => setTab('condition')} role="tab" aria-selected={tab === 'condition'}>
            Current Condition
          </button>
        </div>

        {loading ? (
          <div className="tlg-skills-state">Loading player attributes…</div>
        ) : error ? (
          <div className="tlg-skills-state tlg-skills-state-error">Unable to load player skills: {error}</div>
        ) : !skills ? (
          <div className="tlg-skills-state">Player skill profile has not been initialized yet.</div>
        ) : tab === 'tennis' ? (
          <div className="tlg-skills-grid tlg-skills-grid-tennis">
            <SkillPanel
              eyebrow="Developable attributes"
              title="Tennis Skills"
              description="These are permanent career attributes. Training and match development will change them later."
              items={tennis}
            />

            <aside className="tlg-player-build-profile">
              <section>
                <span>Starting tennis strength</span>
                <strong>{tennisTotal}</strong>
                <p>New players always begin with 350 total tennis-skill points. Future development can move the total above the starting baseline.</p>
              </section>
              <section>
                <span>Preferred surface</span>
                <strong>{skills.preferred_surface ?? 'Neutral'}</strong>
                <p>{skills.preferred_surface ? SURFACE_COPY[skills.preferred_surface] : 'Neutral surface profile.'}</p>
              </section>
              <section>
                <span>Playing style</span>
                <strong>{skills.playing_style}</strong>
                <p>{STYLE_COPY[skills.playing_style]}</p>
              </section>
              <div className="tlg-surface-rule">
                Surface and style are starting identity choices only. They redistribute points but do not create a stronger player and do not depend on ranking position or join date.
              </div>
            </aside>
          </div>
        ) : tab === 'physical' ? (
          <div className="tlg-skills-grid tlg-skills-grid-single">
            <SkillPanel
              eyebrow="Developable attributes"
              title="Physical"
              description="Fitness, stamina, recovery and movement start equally for every new player. Training will develop them over the career."
              items={physical}
            />
            <aside className="tlg-skill-explainer">
              <span>Development rule</span>
              <strong>Same starting base</strong>
              <p>Every new player starts at 50 in all four physical attributes. Surface and playing style do not change physical starting strength.</p>
            </aside>
          </div>
        ) : (
          <div className="tlg-skills-grid tlg-skills-grid-single">
            <SkillPanel
              eyebrow="Dynamic values"
              title="Current Condition"
              description="These values are not permanent skills. They will move up or down with matches, rest, results, training load and career events."
              items={condition}
            />
            <aside className="tlg-skill-explainer">
              <span>Dynamic state</span>
              <strong>Changes during the season</strong>
              <p>Morale, confidence, sharpness and focus currently start at 50. Fatigue starts at 0 because lower fatigue is better.</p>
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
