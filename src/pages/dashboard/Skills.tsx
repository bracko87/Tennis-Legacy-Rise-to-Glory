import { Activity } from 'lucide-react'

import ModulePage from '../../components/game/ModulePage'

export default function SkillsPage() {
  return (
    <ModulePage
      title="Skills"
      subtitle="Player development and training intelligence"
      eyebrow="Career development"
      intro="Build the technical, physical, tactical and mental profile that defines your player. This module will become the central training and progression workspace."
      icon={<Activity size={18} />}
      sideTitle="Development engine pending"
      sideDescription="Skill values, training effects, fatigue interaction and development curves will be loaded from the career simulation database once that engine is introduced."
      milestones={[
        { title: 'Player identity linked', detail: 'The authenticated professional profile is already available to the development module.', state: 'ready' },
        { title: 'Technical attributes', detail: 'Serve, forehand, backhand, return, volley and related tennis skills.' },
        { title: 'Physical attributes', detail: 'Movement, stamina, recovery and athletic development.' },
        { title: 'Mental and tactical model', detail: 'Composure, consistency, tactical intelligence and match adaptation.' },
        { title: 'Training progression', detail: 'Training focus, workload, gains, plateaus and long-term development.' },
      ]}
    />
  )
}
