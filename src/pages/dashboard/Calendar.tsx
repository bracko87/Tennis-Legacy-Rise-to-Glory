/**
 * Calendar.tsx
 *
 * In-game season calendar placeholder. Month header intentionally excludes a real-world year.
 * Days are marked with placeholder event indicators (tournament, training, travel, rest, match).
 *
 * TODO: Replace placeholders with Supabase-driven calendar events.
 */

import GameLayout from '../../components/layout/GameLayout'
import PageHeading from '../../components/common/PageHeading'
import AppCard from '../../components/common/AppCard'

/**
 * CalendarPage
 *
 * Renders a simple month grid with placeholder event badges.
 */
export default function CalendarPage() {
  const days = Array.from({ length: 30 }, (_, i) => i + 1)

  function badgeForDay(day: number) {
    if (day === 6 || day === 20) return { label: 'Tournament', color: 'bg-amber-200 text-amber-800' }
    if (day === 10 || day === 24) return { label: 'Training', color: 'bg-sky-100 text-sky-800' }
    if (day === 14) return { label: 'Match', color: 'bg-rose-100 text-rose-800' }
    if (day === 18) return { label: 'Travel', color: 'bg-violet-100 text-violet-800' }
    if (day % 7 === 0) return { label: 'Rest', color: 'bg-gray-100 text-slate-700' }
    return null
  }

  return (
    <GameLayout title="Season Calendar" subtitle="Map your tournaments, travel and key milestones across the season.">
      <PageHeading eyebrow="Dashboard" title="Calendar" description="Month view (no real-world year). Event badges are placeholders." />

      <div className="mt-6 grid gap-4">
        <AppCard title="Month · March" eyebrow="Game calendar">
          <div className="grid grid-cols-7 gap-2 text-sm">
            {days.map((d) => {
              const badge = badgeForDay(d)
              return (
                <div key={d} className="border rounded-md p-2 bg-white">
                  <div className="flex items-start justify-between">
                    <div className="text-xs font-medium text-slate-700">{d}</div>
                    {badge && <div className={`px-2 py-0.5 rounded text-[0.65rem] ${badge.color}`}>{badge.label}</div>}
                  </div>
                </div>
              )
            })}
          </div>
        </AppCard>

        <div className="text-xs text-slate-500">Event types: Tournament, Training, Match, Travel, Rest. TODO: Wire to Supabase.</div>
      </div>
    </GameLayout>
  )
}