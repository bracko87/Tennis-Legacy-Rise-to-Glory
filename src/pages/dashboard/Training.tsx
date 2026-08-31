import { Dumbbell } from 'lucide-react'

import TabbedModulePage, { PlannedModuleContent } from '../../components/game/TabbedModulePage'

export default function TrainingPage() {
  return (
    <TabbedModulePage
      title="Training"
      subtitle="Regular development and training camps"
      eyebrow="Player development"
      intro="Plan the work that develops your professional player between tournaments. Regular training and training camps are separated so each system can have its own rules, costs and recovery effects."
      icon={<Dumbbell size={18} />}
      sideTitle="Training engine pending"
      sideDescription="Training effects will later be calculated from player skills, staff, workload, fatigue, facilities and the global game clock."
      tabs={[
        {
          id: 'regular',
          label: 'Regular Training',
          content: (
            <PlannedModuleContent
              title="Regular training"
              description="Build weekly and daily development sessions around the player's current competitive schedule."
              items={[
                'Technical training',
                'Physical conditioning',
                'Tactical development',
                'Mental development',
                'Workload and recovery balance',
              ]}
            />
          ),
        },
        {
          id: 'camps',
          label: 'Training Camps',
          content: (
            <PlannedModuleContent
              title="Training camps"
              description="Book focused training periods with stronger development opportunities, travel requirements, costs and fatigue considerations."
              items={[
                'Camp destination and duration',
                'Camp specialization',
                'Travel and accommodation costs',
                'Staff participation',
                'Development and fatigue effects',
              ]}
            />
          ),
        },
      ]}
    />
  )
}
