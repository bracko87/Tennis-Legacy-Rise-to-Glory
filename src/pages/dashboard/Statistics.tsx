import { BarChart3 } from 'lucide-react'

import ModulePage from '../../components/game/ModulePage'

export default function StatisticsPage() {
  return (
    <ModulePage
      title="Statistics"
      subtitle="Career analytics and historical performance"
      eyebrow="Performance intelligence"
      intro="Turn every official match into a long-term career record with rankings, win-loss splits, tournament performance, surface analysis and milestone tracking."
      icon={<BarChart3 size={18} />}
      sideTitle="Match analytics pending"
      sideDescription="Statistics will be generated exclusively from official simulation results so this page never displays fabricated career numbers."
      milestones={[
        { title: 'Player identity linked', detail: 'Statistics will be scoped to the authenticated Tennis Legacy professional.', state: 'ready' },
        { title: 'Career record', detail: 'Official wins, losses, matches played and retirement history.' },
        { title: 'Ranking history', detail: 'Ranking and points progression across every game season.' },
        { title: 'Surface splits', detail: 'Performance across hard, clay, grass and future surface types.' },
        { title: 'Tournament history', detail: 'Draw progress, titles, finals and event-category performance.' },
      ]}
    />
  )
}
