/**
 * Finance.tsx
 *
 * Finance dashboard placeholder showing coin balance, incomes and costs.
 *
 * TODO: Hook up Supabase to retrieve transactions, balances and forecasts.
 */

import GameLayout from '../../components/layout/GameLayout'
import PageHeading from '../../components/common/PageHeading'
import AppCard from '../../components/common/AppCard'

/**
 * FinancePage
 *
 * Displays financial placeholders and a recent transaction scaffold.
 */
export default function FinancePage() {
  return (
    <GameLayout title="Finance" subtitle="Track prize money, sponsorships and long-term career investments.">
      <PageHeading eyebrow="Dashboard" title="Finance" description="Financial overview. All numbers are placeholders." />

      <div className="mt-6 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        <AppCard title="Coin balance" eyebrow="Wallet">
          <div>
            <div className="text-sm text-slate-600">Balance</div>
            <div className="text-2xl font-semibold">—</div>
            <div className="mt-2 text-xs text-slate-500">Coins are placeholder and not persisted.</div>
          </div>
        </AppCard>

        <AppCard eyebrow="Income" title="Recent income">
          <div className="text-sm text-slate-600">
            <div>Tournament income: —</div>
            <div>Sponsorship: —</div>
            <div className="mt-2 text-xs text-slate-500">Sums will be computed from server-side records later.</div>
          </div>
        </AppCard>

        <AppCard eyebrow="Costs" title="Recent costs" muted>
          <div className="text-sm text-slate-600">
            <div>Coaching: —</div>
            <div>Travel: —</div>
            <div>Equipment: —</div>
          </div>
        </AppCard>

        <AppCard eyebrow="Transactions" title="Recent transactions">
          <div className="text-sm text-slate-600">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr>
                    <th className="pr-4">Date</th>
                    <th className="pr-4">Description</th>
                    <th className="pr-4">Amount</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td className="pr-4">—</td>
                    <td className="pr-4">Placeholder</td>
                    <td className="pr-4">—</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div className="mt-2 text-xs text-slate-500">No transactions are stored locally. TODO: Supabase</div>
          </div>
        </AppCard>
      </div>
    </GameLayout>
  )
}