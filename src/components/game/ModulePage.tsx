import type { ReactNode } from 'react'
import { CheckCircle2, Clock3, Construction, Sparkles } from 'lucide-react'

import GameLayout from '../layout/GameLayout'
import PageHeading from '../common/PageHeading'

export interface ModuleMilestone {
  title: string
  detail: string
  state?: 'ready' | 'planned'
}

export interface ModulePageProps {
  title: string
  subtitle: string
  eyebrow: string
  intro: string
  icon: ReactNode
  milestones: ModuleMilestone[]
  sideTitle: string
  sideDescription: string
  children?: ReactNode
}

export default function ModulePage({
  title,
  subtitle,
  eyebrow,
  intro,
  icon,
  milestones,
  sideTitle,
  sideDescription,
  children,
}: ModulePageProps) {
  return (
    <GameLayout title={title} subtitle={subtitle}>
      <PageHeading
        eyebrow={eyebrow}
        title={title}
        description={intro}
      />

      <div className="mt-6 grid gap-4 xl:grid-cols-[minmax(0,1.2fr)_minmax(300px,.8fr)]">
        <section className="tlg-overview-panel">
          <header className="tlg-overview-panel-header">
            <div>
              <span>Module roadmap</span>
              <h3>{title} systems</h3>
            </div>
            <span className="inline-flex h-9 w-9 items-center justify-center rounded-xl border border-[rgba(89,174,238,.13)] bg-[rgba(14,89,153,.12)] text-[color:#69c2fb]">
              {icon}
            </span>
          </header>
          <div className="tlg-overview-panel-body">
            <div className="grid gap-2">
              {milestones.map((milestone) => {
                const ready = milestone.state === 'ready'
                return (
                  <div
                    key={milestone.title}
                    className="grid grid-cols-[34px_1fr_auto] items-center gap-3 rounded-xl border border-[rgba(115,169,212,.08)] bg-[rgba(4,16,29,.4)] px-3 py-3"
                  >
                    <span className={`inline-flex h-8 w-8 items-center justify-center rounded-lg ${ready ? 'bg-[rgba(41,138,81,.11)] text-[color:#73d89a]' : 'bg-[rgba(14,89,153,.12)] text-[color:#67bdf7]'}`}>
                      {ready ? <CheckCircle2 size={16} /> : <Clock3 size={15} />}
                    </span>
                    <div className="min-w-0">
                      <strong className="block text-[0.76rem] font-semibold text-[color:#cbddea]">{milestone.title}</strong>
                      <span className="mt-0.5 block text-[0.65rem] leading-relaxed text-[color:#627c92]">{milestone.detail}</span>
                    </div>
                    <span className="text-[0.58rem] font-bold uppercase tracking-[.08em] text-[color:#557189]">
                      {ready ? 'Ready' : 'Planned'}
                    </span>
                  </div>
                )
              })}
            </div>

            {children && <div className="mt-4">{children}</div>}
          </div>
        </section>

        <div className="grid content-start gap-4">
          <section className="tlg-overview-panel">
            <header className="tlg-overview-panel-header">
              <div>
                <span>System status</span>
                <h3>{sideTitle}</h3>
              </div>
            </header>
            <div className="tlg-overview-panel-body">
              <div className="tlg-overview-empty">
                <Construction size={25} />
                <strong>Designed for live game data</strong>
                <p>{sideDescription}</p>
              </div>
            </div>
          </section>

          <section className="tlg-overview-panel">
            <header className="tlg-overview-panel-header">
              <div>
                <span>Design principle</span>
                <h3>No fake career data</h3>
              </div>
            </header>
            <div className="tlg-overview-panel-body">
              <div className="flex gap-3 rounded-xl border border-[rgba(115,169,212,.08)] bg-[rgba(4,16,29,.4)] p-3">
                <span className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[rgba(14,89,153,.12)] text-[color:#67bdf7]">
                  <Sparkles size={17} />
                </span>
                <p className="text-[0.69rem] leading-relaxed text-[color:#70899f]">
                  This page intentionally shows clear system states until its Supabase-backed simulation data exists. Live values will replace these states as each engine is implemented.
                </p>
              </div>
            </div>
          </section>
        </div>
      </div>
    </GameLayout>
  )
}
