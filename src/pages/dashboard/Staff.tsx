import { UsersRound } from 'lucide-react'

import ModulePage from '../../components/game/ModulePage'

export default function StaffPage() {
  return (
    <ModulePage
      title="Staff"
      subtitle="Build the team around your professional player"
      eyebrow="Career support team"
      intro="Hire and manage the specialists who support your player's development, recovery, preparation and professional career. Staff roles will have their own quality, cost, availability and contract rules."
      icon={<UsersRound size={18} />}
      sideTitle="Staff market pending"
      sideDescription="Staff hiring will be connected to the career economy, contracts and player-development systems before real candidates become available."
      milestones={[
        { title: 'Head coach', detail: 'Primary tennis development, tactics and match preparation.' },
        { title: 'Physiotherapist', detail: 'Recovery, injury prevention and rehabilitation support.' },
        { title: 'Fitness coach', detail: 'Conditioning, athletic development and workload management.' },
        { title: 'Sports psychologist', detail: 'Mental preparation, confidence and pressure management.' },
        { title: 'Agent / manager', detail: 'Commercial opportunities, negotiations and career planning.' },
      ]}
    />
  )
}
