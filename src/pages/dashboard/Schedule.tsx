/**
 * Schedule.tsx
 *
 * Upcoming event schedule placeholder. Shows an actionable list of events
 * with an example opponent and preparation actions.
 *
 * TODO: Integrate with Supabase schedule/events API.
 */

import GameLayout from '../../components/layout/GameLayout'
import PageHeading from '../../components/common/PageHeading'
import AppCard from '../../components/common/AppCard'

/**
 * SchedulePage
 *
 * Displays upcoming events list with placeholders.
 */
export default function SchedulePage() {
  const events = [
    { id: 1, type: 'Practice', info: 'On-court session', date: 'Mar 15 · 10:00', status: 'Planned' },
    { id: 2, type: 'Qualifier', info: 'Qualifier round 1', date: 'Mar 16 · 14:00', status: 'Registered' },
    { id: 3, type: 'Match', info: 'vs Opponent — Match', date: 'Mar 18 · 18:00', status: 'Pending' },
  ]

  return (
    <GameLayout title="Schedule" subtitle="Construct your player's daily sessions, rest and travel.">
      <PageHeading eyebrow="Dashboard" title="Schedule" description="Upcoming events and preparatory actions. Placeholders only." />

      <div className="mt-6 grid gap-4">
        <AppCard title="Upcoming events" eyebrow="Schedule">
          <div className="divide-y">
            {events.map((e) => (
              <div key={e.id} className="py-3 flex items-center justify-between">
                <div>
                  <div className="text-sm font-medium text-slate-700">{e.type} · {e.info}</div>
                  <div className="text-xs text-slate-500">{e.date}</div>
                </div>
                <div className="text-right">
                  <div className="text-xs text-slate-600">{e.status}</div>
                  <div className="mt-2 text-xs text-slate-500">Prepare</div>
                </div>
              </div>
            ))}
          </div>
        </AppCard>

        <AppCard eyebrow="Preparation" title="Preparation actions" muted>
          <div className="text-sm text-slate-600">Select an event to see recommended drills and warm-ups. (Placeholder)</div>
        </AppCard>

        <div className="text-xs text-slate-500">TODO: schedule persistence via Supabase.</div>
      </div>
    </GameLayout>
  )
}