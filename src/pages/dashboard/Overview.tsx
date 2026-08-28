import {
  Activity,
  CalendarDays,
  Check,
  ChevronRight,
  CircleDollarSign,
  Clock3,
  Dumbbell,
  Medal,
  ShieldCheck,
  Trophy,
} from 'lucide-react'
import { Link } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import CountryFlag from '../../components/common/CountryFlag'
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
    <GameLayout title="Overview" subtitle="Career command center">
      <section className="tlg-v2-command">
        <div className="tlg-v2-command-inner">
          <div>
            <span className="tlg-v2-command-kicker">Career command center</span>
            <h2>Welcome back, {player?.first_name || 'manager'}.</h2>
            <p>
              Your player account is active and connected. This dashboard will become the
              central decision point for tournaments, training, finance, equipment and
              performance as those career engines are introduced.
            </p>
          </div>

          <div className="tlg-v2-player-card">
            <div className="tlg-v2-player-row">
              <div className="tlg-v2-player-avatar">
                {avatarUrl ? <img src={avatarUrl} alt={displayName} /> : initials}
              </div>
              <div className="tlg-v2-player-copy">
                <span>Professional profile</span>
                <strong>{displayName}</strong>
                <p className="tlg-v7-country-line">
                  <CountryFlag
                    countryCode={player?.country_code}
                    countryName={countryName}
                    width={20}
                    height={15}
                  />
                  <span>{countryName} · {player?.world ?? '—'} World</span>
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <div className="tlg-v2-kpi-grid">
        <Kpi icon={<Medal size={15} />} label="World ranking" value="Unranked" detail="Ranking engine pending" />
        <Kpi icon={<Activity size={15} />} label="Career record" value="0–0" detail="No official matches yet" />
        <Kpi icon={<Trophy size={15} />} label="Titles" value="0" detail="Career begins here" />
        <Kpi icon={<CircleDollarSign size={15} />} label="Career balance" value="—" detail="Economy engine pending" />
      </div>

      <div className="tlg-v2-overview-grid">
        <div className="tlg-v2-stack">
          <section className="tlg-v2-panel">
            <header className="tlg-v2-panel-header">
              <div>
                <span>Readiness</span>
                <h3>Career launch checklist</h3>
              </div>
              <div className="tlg-v2-panel-icon"><Check size={17} /></div>
            </header>
            <div className="tlg-v2-panel-body">
              <div className="tlg-v2-checklist">
                <CheckRow title="Manager account verified" detail={user?.email ?? 'Authenticated manager account'} done />
                <CheckRow title="Professional player created" detail={`${displayName} · ${player?.world ?? 'World'}`} done />
                <CheckRow title="Country registered" detail={countryName} done />
                <CheckRow title="Enter first tournament" detail="Competition entry system is the next career milestone" />
              </div>
            </div>
          </section>

          <section className="tlg-v2-panel">
            <header className="tlg-v2-panel-header">
              <div>
                <span>Competition</span>
                <h3>Upcoming tournament operations</h3>
              </div>
              <div className="tlg-v2-panel-icon"><CalendarDays size={17} /></div>
            </header>
            <div className="tlg-v2-panel-body">
              <div className="tlg-v2-empty">
                <CalendarDays size={24} />
                <strong>No active tournament</strong>
                <p>
                  Tournament entries, draws, deadlines, travel and match preparation will
                  appear here when the competition engine is connected.
                </p>
              </div>
            </div>
          </section>
        </div>

        <aside className="tlg-v2-stack">
          <section className="tlg-v2-panel">
            <header className="tlg-v2-panel-header">
              <div>
                <span>Quick access</span>
                <h3>Career operations</h3>
              </div>
            </header>
            <div className="tlg-v2-panel-body">
              <div className="tlg-v2-quick-grid">
                <QuickLink to="/game/skills" icon={<Dumbbell size={16} />} title="Skills" subtitle="Development and training" />
                <QuickLink to="/game/calendar" icon={<CalendarDays size={16} />} title="Calendar" subtitle="Season planning" />
                <QuickLink to="/game/schedule" icon={<Clock3 size={16} />} title="Schedule" subtitle="Events and commitments" />
                <QuickLink to="/game/finance" icon={<CircleDollarSign size={16} />} title="Finance" subtitle="Career income and expenses" />
              </div>
            </div>
          </section>

          <section className="tlg-v2-panel">
            <header className="tlg-v2-panel-header">
              <div>
                <span>System state</span>
                <h3>Career simulation</h3>
              </div>
              <div className="tlg-v2-panel-icon"><ShieldCheck size={17} /></div>
            </header>
            <div className="tlg-v2-panel-body">
              <div className="tlg-v2-info-row">
                <span className="tlg-v2-info-row-icon"><ShieldCheck size={16} /></span>
                <p>
                  Authentication and player identity are live. Rankings, skills, finance,
                  tournaments and statistics will remain clearly marked until their real
                  server-backed systems are ready.
                </p>
              </div>
            </div>
          </section>
        </aside>
      </div>
    </GameLayout>
  )
}

function Kpi({ icon, label, value, detail }: { icon: JSX.Element; label: string; value: string; detail: string }) {
  return (
    <div className="tlg-v2-kpi">
      <div className="tlg-v2-kpi-head">
        <span>{label}</span>
        <span className="tlg-v2-kpi-icon">{icon}</span>
      </div>
      <strong>{value}</strong>
      <p>{detail}</p>
    </div>
  )
}

function CheckRow({ title, detail, done = false }: { title: string; detail: string; done?: boolean }) {
  return (
    <div className={`tlg-v2-check ${done ? '' : 'tlg-v2-check-pending'}`}>
      <span className="tlg-v2-check-icon">{done ? <Check size={14} /> : <Clock3 size={14} />}</span>
      <div className="tlg-v2-check-copy">
        <strong>{title}</strong>
        <span>{detail}</span>
      </div>
      <span className="tlg-v2-check-state">{done ? 'Complete' : 'Upcoming'}</span>
    </div>
  )
}

function QuickLink({ to, icon, title, subtitle }: { to: string; icon: JSX.Element; title: string; subtitle: string }) {
  return (
    <Link to={to} className="tlg-v2-quick-link">
      <span className="tlg-v2-quick-icon">{icon}</span>
      <span className="tlg-v2-quick-copy">
        <strong>{title}</strong>
        <span>{subtitle}</span>
      </span>
      <ChevronRight size={15} />
    </Link>
  )
}
