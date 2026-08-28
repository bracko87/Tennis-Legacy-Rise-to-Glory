/**
 * Overview.tsx
 *
 * Premium player command center. Identity data comes from the authenticated
 * Tennis Legacy player record; gameplay systems that are not implemented yet
 * are presented as deliberate empty states instead of fake statistics.
 */

import type { ReactNode } from 'react'
import { Link } from 'react-router'
import {
  Activity,
  CalendarDays,
  Check,
  ChevronRight,
  CircleDollarSign,
  Clock3,
  Dumbbell,
  Flag,
  Medal,
  ShieldCheck,
  Sparkles,
  Trophy,
  UserRound,
} from 'lucide-react'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'

function getCountryName(code?: string) {
  if (!code) return 'Country not set'
  try {
    return new Intl.DisplayNames(['en'], { type: 'region' }).of(code) ?? code
  } catch {
    return code
  }
}

export default function OverviewPage() {
  const { player, user } = useAuth()

  const displayName = player
    ? `${player.first_name} ${player.last_name}`.trim()
    : 'Tennis Legacy Player'
  const initials = player
    ? `${player.first_name.charAt(0)}${player.last_name.charAt(0)}`.toUpperCase()
    : 'TL'
  const countryName = getCountryName(player?.country_code)
  const avatarUrl = player?.image_path
    ? supabase.storage.from('player-avatars').getPublicUrl(player.image_path).data.publicUrl
    : null

  return (
    <GameLayout title="Overview" subtitle="Your career command center">
      <section className="tlg-overview-command">
        <div className="tlg-overview-command-inner">
          <div>
            <span className="tlg-overview-command-kicker">Career command center</span>
            <h2>Welcome back, {player?.first_name || 'manager'}.</h2>
            <p>
              This is the operating center for your professional career. Tournament entries,
              training, finance, equipment and performance systems will surface here as the
              persistent world comes online.
            </p>

            <div className="tlg-overview-command-meta">
              <span className="tlg-overview-chip"><GlobeIcon /> {player?.world ?? '—'} World</span>
              <span className="tlg-overview-chip"><Flag size={13} /> {countryName}</span>
              <span className="tlg-overview-chip"><ShieldCheck size={13} /> {player?.moderation_status ?? 'pending'}</span>
            </div>
          </div>

          <div className="tlg-overview-player-lockup">
            <div className="tlg-overview-player-row">
              <div className="tlg-overview-avatar">
                {avatarUrl ? <img src={avatarUrl} alt={displayName} /> : initials}
              </div>
              <div className="tlg-overview-player-copy">
                <span>Professional profile</span>
                <strong>{displayName}</strong>
                <p>{countryName}</p>
              </div>
            </div>

            <div className="tlg-overview-lockup-grid">
              <div><span>World</span><strong>{player?.world ?? '—'}</strong></div>
              <div><span>Ranking</span><strong>Unranked</strong></div>
              <div><span>Season</span><strong>1</strong></div>
            </div>
          </div>
        </div>
      </section>

      <div className="tlg-overview-stat-grid">
        <OverviewStat icon={<Medal size={16} />} label="World ranking" value="Unranked" detail="Ranking engine pending" />
        <OverviewStat icon={<Activity size={16} />} label="Career record" value="0–0" detail="No official matches yet" />
        <OverviewStat icon={<Trophy size={16} />} label="Titles" value="0" detail="Career begins here" />
        <OverviewStat icon={<CircleDollarSign size={16} />} label="Career finance" value="—" detail="Economy system pending" />
      </div>

      <div className="tlg-overview-grid">
        <div className="tlg-overview-stack">
          <OverviewPanel eyebrow="Next objective" title="Career launch checklist">
            <div className="tlg-overview-checklist">
              <ChecklistItem title="Manager account verified" detail={user?.email ?? 'Authenticated account'} done />
              <ChecklistItem title="Professional player created" detail={`${displayName} · ${player?.world ?? 'World'}`} done />
              <ChecklistItem title="Country registered" detail={countryName} done />
              <ChecklistItem title="Enter first tournament" detail="Tournament entry system is the next career milestone" />
            </div>
          </OverviewPanel>

          <OverviewPanel eyebrow="Competition" title="Tournament operations">
            <div className="tlg-overview-empty">
              <CalendarDays size={24} />
              <strong>No active tournament</strong>
              <p>
                Tournament invitations, entries, draws and match preparation will appear here once the competition engine is connected.
              </p>
            </div>
          </OverviewPanel>

          <OverviewPanel eyebrow="Performance" title="Development snapshot">
            <div className="grid gap-4 md:grid-cols-2">
              <ProgressBlock label="Technical development" value={0} note="Skills model not initialized" />
              <ProgressBlock label="Career experience" value={0} note="Earned through official play" />
            </div>
          </OverviewPanel>
        </div>

        <div className="tlg-overview-stack">
          <OverviewPanel eyebrow="Today" title="Manager briefing">
            <div className="space-y-3">
              <BriefingRow icon={<Clock3 size={16} />} title="Career world" value={`${player?.world ?? '—'} · Season 1`} />
              <BriefingRow icon={<UserRound size={16} />} title="Player status" value="Career initialized" />
              <BriefingRow icon={<ShieldCheck size={16} />} title="Identity review" value={capitalize(player?.moderation_status ?? 'pending')} />
            </div>
          </OverviewPanel>

          <OverviewPanel eyebrow="Quick access" title="Career operations">
            <div className="grid gap-2">
              <QuickLink to="/game/skills" icon={<Dumbbell size={17} />} title="Player skills" subtitle="Development and training profile" />
              <QuickLink to="/game/calendar" icon={<CalendarDays size={17} />} title="Calendar" subtitle="Season and tournament planning" />
              <QuickLink to="/game/equipment" icon={<Sparkles size={17} />} title="Equipment" subtitle="Rackets, apparel and performance gear" />
              <QuickLink to="/game/finance" icon={<CircleDollarSign size={17} />} title="Finance" subtitle="Career income and expenses" />
            </div>
          </OverviewPanel>

          <OverviewPanel eyebrow="Next build phase" title="Career systems">
            <div className="tlg-overview-empty">
              <Sparkles size={24} />
              <strong>Foundation ready</strong>
              <p>
                Authentication, player identity, country reference data and avatar storage are connected. The next major phase is the actual career simulation layer.
              </p>
            </div>
          </OverviewPanel>
        </div>
      </div>
    </GameLayout>
  )
}

function GlobeIcon() {
  return <span aria-hidden="true" style={{ fontSize: 12 }}>◎</span>
}

function OverviewStat({
  icon,
  label,
  value,
  detail,
}: {
  icon: JSX.Element
  label: string
  value: string
  detail: string
}) {
  return (
    <div className="tlg-overview-stat">
      <div className="tlg-overview-stat-head">
        <span>{label}</span>
        <span className="tlg-overview-stat-icon">{icon}</span>
      </div>
      <strong>{value}</strong>
      <p>{detail}</p>
    </div>
  )
}

function OverviewPanel({
  eyebrow,
  title,
  children,
}: {
  eyebrow: string
  title: string
  children: ReactNode
}) {
  return (
    <section className="tlg-overview-panel">
      <header className="tlg-overview-panel-header">
        <div>
          <span>{eyebrow}</span>
          <h3>{title}</h3>
        </div>
      </header>
      <div className="tlg-overview-panel-body">{children}</div>
    </section>
  )
}

function ChecklistItem({ title, detail, done = false }: { title: string; detail: string; done?: boolean }) {
  return (
    <div className="tlg-overview-check">
      <span className="tlg-overview-check-icon">{done ? <Check size={15} /> : <Clock3 size={14} />}</span>
      <div className="tlg-overview-check-copy">
        <strong>{title}</strong>
        <span>{detail}</span>
      </div>
      <span className="tlg-overview-check-state">{done ? 'Complete' : 'Upcoming'}</span>
    </div>
  )
}

function ProgressBlock({ label, value, note }: { label: string; value: number; note: string }) {
  return (
    <div>
      <div className="mb-2 flex items-center justify-between gap-3 text-xs">
        <span className="text-[color:#a9bfd2]">{label}</span>
        <span className="text-[color:#607a91]">{value}%</span>
      </div>
      <div className="tlg-overview-progress"><span style={{ width: `${value}%` }} /></div>
      <p className="mt-2 text-[0.66rem] text-[color:#607a91]">{note}</p>
    </div>
  )
}

function BriefingRow({ icon, title, value }: { icon: JSX.Element; title: string; value: string }) {
  return (
    <div className="flex items-center gap-3 rounded-xl border border-[rgba(115,169,212,.08)] bg-[rgba(4,16,29,.4)] px-3 py-3">
      <span className="inline-flex h-8 w-8 items-center justify-center rounded-lg bg-[rgba(14,89,153,.14)] text-[color:#62baf8]">{icon}</span>
      <div className="min-w-0 flex-1">
        <div className="text-[0.64rem] uppercase tracking-[.08em] text-[color:#607a91]">{title}</div>
        <div className="mt-0.5 truncate text-[0.76rem] font-semibold text-[color:#c9dae8]">{value}</div>
      </div>
    </div>
  )
}

function QuickLink({
  to,
  icon,
  title,
  subtitle,
}: {
  to: string
  icon: JSX.Element
  title: string
  subtitle: string
}) {
  return (
    <Link
      to={to}
      className="group flex items-center gap-3 rounded-xl border border-[rgba(115,169,212,.08)] bg-[rgba(4,16,29,.38)] px-3 py-3 transition hover:border-[rgba(82,172,237,.22)] hover:bg-[rgba(11,48,78,.45)]"
    >
      <span className="inline-flex h-9 w-9 items-center justify-center rounded-lg bg-[rgba(14,89,153,.14)] text-[color:#62baf8]">{icon}</span>
      <div className="min-w-0 flex-1">
        <strong className="block text-[0.75rem] text-[color:#cadbe8]">{title}</strong>
        <span className="mt-0.5 block text-[0.64rem] text-[color:#607a91]">{subtitle}</span>
      </div>
      <ChevronRight size={16} className="text-[color:#49677f] transition group-hover:translate-x-0.5 group-hover:text-[color:#70c5ff]" />
    </Link>
  )
}

function capitalize(value: string) {
  return value.length ? value.charAt(0).toUpperCase() + value.slice(1) : value
}
