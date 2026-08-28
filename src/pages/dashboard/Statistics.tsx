/**
 * Statistics.tsx
 *
 * Placeholder statistics page: career matches, wins/losses, win percentage,
 * titles, finals and various performance breakdowns.
 *
 * All statistics are placeholders. TODO: Connect reporting queries to Supabase.
 */

import GameLayout from '../../components/layout/GameLayout'
import PageHeading from '../../components/common/PageHeading'
import AppCard from '../../components/common/AppCard'

/**
 * StatisticsPage
 *
 * Presents a collection of placeholder statistic cards.
 */
export default function StatisticsPage() {
  return (
    <GameLayout title="Statistics" subtitle="Deep performance analytics across matches, seasons and career.">
      <PageHeading eyebrow="Dashboard" title="Statistics" description="All metrics shown are placeholders — will be connected to Supabase in future iterations." />

      <div className="mt-6 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        <AppCard eyebrow="Career" title="Career matches">
          <div className="text-sm text-slate-600">
            <div>Matches: —</div>
            <div>Wins: —</div>
            <div>Losses: —</div>
            <div>Win %: —</div>
          </div>
        </AppCard>

        <AppCard eyebrow="Achievements" title="Titles & finals" muted>
          <div className="text-sm text-slate-600">
            <div>Titles: —</div>
            <div>Finals: —</div>
            <div className="mt-2 text-xs text-slate-500">Historic data will be populated from career records.</div>
          </div>
        </AppCard>

        <AppCard eyebrow="Performance" title="Surface performance">
          <div className="text-sm text-slate-600">
            <div>Clay: —</div>
            <div>Grass: —</div>
            <div>Hard: —</div>
          </div>
        </AppCard>

        <AppCard eyebrow="Serve" title="Serve statistics">
          <div className="text-sm text-slate-600">
            <div>Aces: —</div>
            <div>Double faults: —</div>
            <div>1st serve %: —</div>
          </div>
        </AppCard>

        <AppCard eyebrow="Return" title="Return statistics" muted>
          <div className="text-sm text-slate-600">
            <div>Break points saved: —</div>
            <div>Return winners: —</div>
          </div>
        </AppCard>

        <AppCard eyebrow="History" title="Ranking history">
          <div className="text-sm text-slate-600">Ranking graph placeholder</div>
        </AppCard>
      </div>

      <div className="mt-4 text-xs text-slate-500">All values are placeholders. TODO: implement Supabase reports.</div>
    </GameLayout>
  )
}