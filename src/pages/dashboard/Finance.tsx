import { CircleDollarSign } from 'lucide-react'

import ModulePage from '../../components/game/ModulePage'

export default function FinancePage() {
  return (
    <ModulePage
      title="Finance"
      subtitle="Career income, costs and commercial growth"
      eyebrow="Career economy"
      intro="Manage the financial side of a professional tennis career: prize money, sponsorships, travel costs, coaching expenses, equipment and long-term career sustainability."
      icon={<CircleDollarSign size={18} />}
      sideTitle="Economy engine pending"
      sideDescription="Balances and transactions will remain empty until the game economy rules are finalized. We are intentionally not inventing placeholder money values that could later conflict with game balance."
      milestones={[
        { title: 'Authenticated owner linked', detail: 'Financial records will be isolated to the manager who owns the player.', state: 'ready' },
        { title: 'Career ledger', detail: 'Immutable history of income, costs, rewards and adjustments.' },
        { title: 'Prize money', detail: 'Tournament earnings based on event category and result.' },
        { title: 'Sponsorship contracts', detail: 'Commercial offers, obligations, bonuses and duration.' },
        { title: 'Operating costs', detail: 'Travel, training, coaching, equipment and career services.' },
      ]}
    />
  )
}
