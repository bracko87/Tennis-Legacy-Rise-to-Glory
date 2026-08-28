import { Clock3 } from 'lucide-react'

import ModulePage from '../../components/game/ModulePage'

export default function SchedulePage() {
  return (
    <ModulePage
      title="Schedule"
      subtitle="Your operational timeline"
      eyebrow="Daily management"
      intro="Translate the season calendar into a practical player schedule with matches, training, travel, recovery and manager decisions organized by game time."
      icon={<Clock3 size={18} />}
      sideTitle="Personal schedule pending"
      sideDescription="This module will be generated from tournament commitments, the global game clock and the player training plan, so every item represents a real career obligation."
      milestones={[
        { title: 'Player profile available', detail: 'The schedule is already linked to the authenticated Tennis Legacy player.', state: 'ready' },
        { title: 'Daily timeline', detail: 'Chronological view of training, travel, recovery and match commitments.' },
        { title: 'Conflict detection', detail: 'Prevent overlapping activities and impossible travel or tournament choices.' },
        { title: 'Match-day preparation', detail: 'Surface pre-match tasks and readiness before an official match.' },
        { title: 'Manager reminders', detail: 'Highlight deadlines and decisions that require your attention.' },
      ]}
    />
  )
}
