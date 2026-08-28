/**
 * Equipment.tsx
 *
 * Equipment management placeholder with categories and condition/performance indicators.
 *
 * TODO: Connect to Supabase to fetch equipment items, equipped status and replacements.
 */

import GameLayout from '../../components/layout/GameLayout'
import PageHeading from '../../components/common/PageHeading'
import AppCard from '../../components/common/AppCard'

/**
 * EquipmentPage
 *
 * Shows equipment categories with placeholder condition and performance effects.
 */
export default function EquipmentPage() {
  const equipment = [
    { key: 'racket', label: 'Racket', condition: 78, equipped: true },
    { key: 'shoes', label: 'Shoes', condition: 62, equipped: true },
    { key: 'apparel', label: 'Apparel', condition: 85, equipped: false },
    { key: 'bag', label: 'Bag', condition: 90, equipped: false },
    { key: 'accessories', label: 'Accessories', condition: 70, equipped: false },
  ]

  return (
    <GameLayout title="Equipment" subtitle="Curate your player's rackets, strings, apparel and setups.">
      <PageHeading eyebrow="Dashboard" title="Equipment" description="Equipment list and simple condition metrics. All data are placeholders." />

      <div className="mt-6 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {equipment.map((e) => (
          <AppCard key={e.key} eyebrow="Category" title={e.label}>
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <div className="text-sm text-slate-600">Condition</div>
                <div className="text-sm font-semibold">{e.condition}%</div>
              </div>
              <div className="w-full bg-gray-100 rounded-full h-3 overflow-hidden">
                <div className="h-3 bg-gradient-to-r from-cyan-500 to-sky-700" style={{ width: `${e.condition}%` }} />
              </div>
              <div className="flex items-center justify-between text-xs text-slate-500">
                <div>{e.equipped ? 'Equipped' : 'Not equipped'}</div>
                <div>Performance effect: —</div>
              </div>
              <div className="mt-2 text-xs text-slate-500">Replacement actions will be added later.</div>
            </div>
          </AppCard>
        ))}
      </div>

      <div className="mt-4 text-xs text-slate-500">TODO: Supabase integration for equipment inventory and equips.</div>
    </GameLayout>
  )
}