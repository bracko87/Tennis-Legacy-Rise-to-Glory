import { Shield } from 'lucide-react'

import ModulePage from '../../components/game/ModulePage'

export default function EquipmentPage() {
  return (
    <ModulePage
      title="Equipment"
      subtitle="Performance gear and sponsor inventory"
      eyebrow="Performance setup"
      intro="Control the equipment your player uses across the season, including rackets, strings, footwear, apparel and future sponsor-linked gear bonuses."
      icon={<Shield size={18} />}
      sideTitle="Equipment database pending"
      sideDescription="The inventory will be populated only after equipment attributes, durability, sponsor rules and performance effects are defined in the game database."
      milestones={[
        { title: 'Player identity linked', detail: 'Equipment will belong to the authenticated professional player.', state: 'ready' },
        { title: 'Racket system', detail: 'Racket models, characteristics, durability and player fit.' },
        { title: 'Strings and setup', detail: 'String choice and setup effects on performance and maintenance.' },
        { title: 'Footwear and apparel', detail: 'Wearable inventory with condition, sponsor and surface context.' },
        { title: 'Sponsor equipment', detail: 'Contract-specific gear requirements, bonuses and restrictions.' },
      ]}
    />
  )
}
