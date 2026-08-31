import { CalendarDays } from 'lucide-react'

import TabbedModulePage, { PlannedModuleContent } from '../../components/game/TabbedModulePage'

export default function CalendarPage() {
  return (
    <TabbedModulePage
      title="Calendar"
      subtitle="Season calendar and tournament calendar"
      eyebrow="Competition planning"
      intro="Use the calendar for your complete season timeline, while the Tournament Calendar focuses specifically on official ATP or WTA singles events available in your professional world."
      icon={<CalendarDays size={18} />}
      sideTitle="Calendar engine pending"
      sideDescription="Both calendar views will use the global Tennis Legacy game clock and server-backed tournament data rather than local browser dates."
      tabs={[
        {
          id: 'season-calendar',
          label: 'Calendar',
          content: (
            <PlannedModuleContent
              title="Season calendar"
              description="Your complete career calendar will combine tournaments with training, travel, recovery, staff commitments and deadlines."
              items={[
                'Full season date view',
                'Training and training-camp blocks',
                'Travel and recovery periods',
                'Personal commitments',
                'Important career deadlines',
              ]}
            />
          ),
        },
        {
          id: 'tournament-calendar',
          label: 'Tournament Calendar',
          content: (
            <PlannedModuleContent
              title="Tournament calendar"
              description="Browse official singles tournaments belonging only to your player's world: ATP for male professionals or WTA for female professionals."
              items={[
                'ATP or WTA events only',
                'Tournament category and surface',
                'Entry and withdrawal deadlines',
                'Qualifying and main-draw dates',
                'Travel and scheduling conflicts',
              ]}
            />
          ),
        },
      ]}
    />
  )
}
