import { CalendarDays } from 'lucide-react'

import ModulePage from '../../components/game/ModulePage'

export default function CalendarPage() {
  return (
    <ModulePage
      title="Calendar"
      subtitle="Season planning and tournament visibility"
      eyebrow="Competition planning"
      intro="See the entire career season in one place: tournament windows, travel periods, training blocks, recovery days and important deadlines."
      icon={<CalendarDays size={18} />}
      sideTitle="Season calendar pending"
      sideDescription="The calendar will be driven by the global Tennis Legacy clock and tournament database rather than browser-local dates or hardcoded events."
      milestones={[
        { title: 'Season framework', detail: 'Tennis Legacy uses numbered seasons instead of real-world years.', state: 'ready' },
        { title: 'Global game clock', detail: 'Synchronize every manager to the same season date and time.' },
        { title: 'Tournament calendar', detail: 'Publish ATP and WTA events, entry windows, qualifying and main draws.' },
        { title: 'Personal commitments', detail: 'Overlay training, travel, recovery and match obligations.' },
        { title: 'Deadline intelligence', detail: 'Surface registration cutoffs and upcoming manager decisions.' },
      ]}
    />
  )
}
