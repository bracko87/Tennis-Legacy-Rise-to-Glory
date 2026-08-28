/**
 * Skills.tsx
 *
 * Skills dashboard placeholder showing categories and development progress.
 * Each skill is presented with a linear progress indicator and short helper text.
 *
 * TODO: Connect to Supabase to fetch and update skill values.
 */

import GameLayout from '../../components/layout/GameLayout'
import PageHeading from '../../components/common/PageHeading'
import AppCard from '../../components/common/AppCard'

/**
 * Mini progress bar component
 * @param props - { value } numeric 0-100
 */
function MiniBar({ value = 0 }: { value?: number }) {
  return (
    <div className="w-full bg-gray-100 rounded-full h-3 overflow-hidden">
      <div className="h-3 bg-gradient-to-r from-emerald-500 to-lime-700" style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
    </div>
  )
}

/**
 * SkillsPage
 *
 * Presents a grouped skill view with placeholder progress values.
 */
export default function SkillsPage() {
  const skillGroups = [
    { key: 'serve', label: 'Serve', value: 58 },
    { key: 'forehand', label: 'Forehand', value: 64 },
    { key: 'backhand', label: 'Backhand', value: 59 },
    { key: 'volley', label: 'Volley', value: 45 },
    { key: 'movement', label: 'Movement', value: 52 },
    { key: 'stamina', label: 'Stamina', value: 66 },
    { key: 'mental', label: 'Mental', value: 48 },
    { key: 'tactical', label: 'Tactical', value: 50 },
  ]

  return (
    <GameLayout title="Skills" subtitle="Plan your training focus and long-term player development.">
      <PageHeading eyebrow="Dashboard" title="Skills" description="Technical, tactical and physical attributes. Values below are placeholders." />

      <div className="mt-6 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {skillGroups.map((s) => (
          <AppCard key={s.key} eyebrow="Attribute" title={s.label}>
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <div className="text-sm font-medium text-slate-600">Current</div>
                <div className="text-sm font-semibold">{s.value}%</div>
              </div>
              <MiniBar value={s.value} />
              <div className="text-xs text-slate-500">Training progression and targets will be configurable later.</div>
            </div>
          </AppCard>
        ))}
      </div>

      <div className="mt-6 text-xs text-slate-500">Placeholders only — TODO: fetch skill values from Supabase.</div>
    </GameLayout>
  )
}