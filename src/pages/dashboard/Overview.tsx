/**
 * Overview.tsx
 *
 * Rich player overview dashboard placeholder for Tennis Legacy.
 * Provides a composed page with profile summary, next match, form,
 * skills preview, finance summary and notifications.
 *
 * All data presented here are placeholders. TODO: connect Supabase
 * to fetch live player, season and match data.
 */

import { Link } from 'react-router'
import {
  Activity,
  BarChart2,
  CalendarDays,
  Clock3,
  DollarSign,
  LayoutDashboard,
  MessageCircle,
  User,
  TrendingUp,
} from 'lucide-react'
import GameLayout from '../../components/layout/GameLayout'
import PageHeading from '../../components/common/PageHeading'
import AppCard from '../../components/common/AppCard'

/**
 * Renders a small linear progress bar.
 * @param props - { value } progress 0..100
 */
function Progress({ value = 0 }: { value?: number }) {
  return (
    <div className="w-full bg-gray-100 rounded-full h-3 overflow-hidden">
      <div
        className="h-3 bg-gradient-to-r from-sky-600 to-sky-800"
        style={{ width: `${Math.max(0, Math.min(100, value))}%` }}
        aria-valuenow={value}
        role="progressbar"
      />
    </div>
  )
}

/**
 * OverviewPage
 *
 * Main overview dashboard composed of multiple cards and placeholders.
 */
export default function OverviewPage() {
  return (
    <GameLayout
      title="Overview"
      subtitle="High-level snapshot of your player, season and performance."
    >
      <PageHeading
        eyebrow="Dashboard"
        title="Overview"
        description="This is the main in-game dashboard. All displayed values are placeholders."
      />

      <div className="mt-6 grid gap-4 lg:grid-cols-3">
        {/* Left column: profile + ranking + form */}
        <div className="lg:col-span-1 space-y-4">
          <AppCard eyebrow="Profile" title="Player profile">
            <div className="flex items-center gap-4">
              <div className="h-16 w-16 rounded-md bg-slate-200 flex items-center justify-center text-slate-600">
                <User className="h-7 w-7" />
              </div>
              <div className="flex-1">
                <div className="flex items-center justify-between">
                  <div>
                    <div className="text-sm font-semibold">Unnamed Player</div>
                    <div className="text-xs text-slate-600">United States</div>
                  </div>
                  <div className="text-xs font-mono text-slate-500">#—</div>
                </div>
                <div className="mt-3 space-y-2">
                  <div className="text-[0.82rem] text-slate-600">World</div>
                  <div className="inline-flex items-center gap-2">
                    <span className="px-2 py-1 rounded-md bg-[rgba(5,78,152,0.08)] text-xs font-medium border border-[rgba(5,78,152,0.12)]">
                      ATP / WTA
                    </span>
                    <span className="px-2 py-1 rounded-md bg-[rgba(0,7,19,0.03)] text-xs">Future Professional</span>
                  </div>
                </div>
              </div>
            </div>
          </AppCard>

          <AppCard eyebrow="Rank & Form" title="Ranking & current form" muted>
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-xs text-slate-600">Ranking (placeholder)</div>
                  <div className="text-lg font-semibold">—</div>
                </div>
                <div className="text-right">
                  <div className="text-xs text-slate-600">Form</div>
                  <div className="text-sm font-medium">—</div>
                </div>
              </div>

              <div>
                <div className="text-xs text-slate-600 mb-1">Energy</div>
                <Progress value={78} />
              </div>
              <div>
                <div className="text-xs text-slate-600 mb-1">Condition</div>
                <Progress value={64} />
              </div>
            </div>
          </AppCard>

          <AppCard eyebrow="Next event" title="Next match">
            <div className="text-sm text-slate-600">
              <div className="mb-2">No confirmed match — placeholder</div>
              <div className="flex items-center gap-2 text-xs">
                <Clock3 className="h-4 w-4 text-slate-500" />
                <div>Season 1 · March 14 · 18:00</div>
              </div>
            </div>
          </AppCard>
        </div>

        {/* Middle and right: rich grid */}
        <div className="lg:col-span-2 grid gap-4 md:grid-cols-2">
          <AppCard eyebrow="Tournament" title="Current tournament">
            <div className="text-sm text-slate-600">
              Placeholder: no active tournament.
            </div>
          </AppCard>

          <AppCard eyebrow="Upcoming" title="Upcoming schedule">
            <div className="space-y-2 text-sm text-slate-600">
              <div>• Practice session — Season 1 · Mar 15 · 10:00</div>
              <div>• Qualifier — Season 1 · Mar 16 · 14:00</div>
              <div className="mt-3 text-xs text-slate-500">All entries are placeholders.</div>
            </div>
          </AppCard>

          <AppCard eyebrow="Results" title="Recent results">
            <div className="grid gap-2">
              <div className="flex items-center justify-between text-sm text-slate-600">
                <div>vs Opponent — Match 1</div>
                <div>—</div>
              </div>
              <div className="flex items-center justify-between text-sm text-slate-600">
                <div>vs Opponent — Match 2</div>
                <div>—</div>
              </div>
              <div className="mt-2 text-xs text-slate-500">Results are placeholder data.</div>
            </div>
          </AppCard>

          <AppCard eyebrow="Development" title="Skill development summary">
            <div className="space-y-3">
              <div className="text-xs text-slate-600">Serve</div>
              <Progress value={46} />
              <div className="text-xs text-slate-600">Movement</div>
              <Progress value={52} />
              <div className="mt-2 text-xs text-slate-500">Detailed skill trees will be wired in a future step.</div>
            </div>
          </AppCard>

          <AppCard eyebrow="Finance" title="Finance summary" muted>
            <div className="flex items-center justify-between">
              <div>
                <div className="text-xs text-slate-600">Coin balance</div>
                <div className="text-lg font-semibold">—</div>
              </div>
              <div className="text-sm text-slate-600">
                <div>Tournament income: —</div>
                <div>Sponsorship: —</div>
              </div>
            </div>
          </AppCard>

          <AppCard eyebrow="Notifications" title="Alerts">
            <div className="text-sm text-slate-600">
              <MessageCircle className="inline-block mr-2" />
              No notifications — placeholder.
            </div>
          </AppCard>
        </div>
      </div>

      <div className="mt-6 flex items-center justify-between gap-3">
        <Link to="/">
          <button className="px-3 py-1 rounded-md bg-slate-100 text-slate-800 text-sm">Back to Home</button>
        </Link>
        <div className="text-xs text-slate-500">All data shown are placeholders. TODO: connect Supabase.</div>
      </div>
    </GameLayout>
  )
}