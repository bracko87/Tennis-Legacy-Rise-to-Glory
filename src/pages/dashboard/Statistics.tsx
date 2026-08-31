import { BarChart3 } from 'lucide-react'

import TabbedModulePage, { PlannedModuleContent } from '../../components/game/TabbedModulePage'

export default function StatisticsPage() {
  return (
    <TabbedModulePage
      title="Statistics"
      subtitle="Player, tournament and career analytics"
      eyebrow="Performance intelligence"
      intro="Statistics will be generated only from official Tennis Legacy singles matches and tournament results. ATP and WTA records remain separate according to the player's professional world."
      icon={<BarChart3 size={18} />}
      sideTitle="Statistics engine pending"
      sideDescription="No career values are fabricated. Real analytics will populate from official match, tournament and ranking systems."
      tabs={[
        {
          id: 'player',
          label: 'Player Statistics',
          content: (
            <PlannedModuleContent
              title="Player statistics"
              description="Analyse the overall performance profile of your professional player."
              items={[
                'Matches played, wins and losses',
                'Surface performance',
                'Set and game records',
                'Opponent-level splits',
                'Form and performance trends',
              ]}
            />
          ),
        },
        {
          id: 'tournaments',
          label: 'Tournament Statistics',
          content: (
            <PlannedModuleContent
              title="Tournament statistics"
              description="Track how your player performs across official tournaments and event categories."
              items={[
                'Tournament appearances',
                'Titles and finals',
                'Best round reached',
                'Results by tournament category',
                'Tournament win percentage',
              ]}
            />
          ),
        },
        {
          id: 'career',
          label: 'Career Records',
          content: (
            <PlannedModuleContent
              title="Career records"
              description="Preserve the long-term milestones and historical records of the player's entire career."
              items={[
                'Best world ranking',
                'Ranking history',
                'Season-by-season records',
                'Career prize-money records',
                'Major milestones and achievements',
              ]}
            />
          ),
        },
      ]}
    />
  )
}
