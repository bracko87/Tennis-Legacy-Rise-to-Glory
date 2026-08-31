import type { ReactNode } from 'react'
import { CheckCircle2, Clock3, Construction, Database } from 'lucide-react'

import GameLayout from '../layout/GameLayout'

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
  milestones,
  sideTitle,
  sideDescription,
  children,
}: ModulePageProps) {
  return (
    <GameLayout title={title} subtitle={subtitle}>
      <header className="tlg-v2-page-head">
        <div className="tlg-v2-page-head-copy">
          <div className="tlg-v2-page-eyebrow">{eyebrow}</div>
          <h2 className="tlg-v2-page-title">{title}</h2>
          <p className="tlg-v2-page-description">{intro}</p>
        </div>
      </header>

      <div className="tlg-v2-module-grid">
        <section className="tlg-v2-panel">
          <header className="tlg-v2-panel-header">
            <div>
              <span>System roadmap</span>
              <h3>{title} operations</h3>
            </div>
          </header>

          <div className="tlg-v2-panel-body">
            <div className="tlg-v2-roadmap">
              {milestones.map((milestone) => {
                const ready = milestone.state === 'ready'

                return (
                  <div
                    key={milestone.title}
                    className={`tlg-v2-roadmap-row ${ready ? 'tlg-v2-roadmap-row-ready' : ''}`}
                  >
                    <span className="tlg-v2-roadmap-icon">
                      {ready ? <CheckCircle2 size={16} /> : <Clock3 size={15} />}
                    </span>

                    <div className="tlg-v2-roadmap-copy">
                      <strong>{milestone.title}</strong>
                      <span>{milestone.detail}</span>
                    </div>

                    <span className="tlg-v2-roadmap-state">
                      {ready ? 'Ready' : 'Planned'}
                    </span>
                  </div>
                )
              })}
            </div>

            {children && <div className="mt-4">{children}</div>}
          </div>
        </section>

        <aside className="tlg-v2-stack">
          <section className="tlg-v2-panel">
            <header className="tlg-v2-panel-header">
              <div>
                <span>Module status</span>
                <h3>{sideTitle}</h3>
              </div>
            </header>
            <div className="tlg-v2-panel-body">
              <div className="tlg-v2-empty">
                <Construction size={24} />
                <strong>Built for live game data</strong>
                <p>{sideDescription}</p>
              </div>
            </div>
          </section>

          <section className="tlg-v2-panel">
            <header className="tlg-v2-panel-header">
              <div>
                <span>Data policy</span>
                <h3>Server-backed career state</h3>
              </div>
            </header>
            <div className="tlg-v2-panel-body">
              <div className="tlg-v2-info-row">
                <span className="tlg-v2-info-row-icon"><Database size={16} /></span>
                <p>
                  This workspace intentionally avoids fake career values. Live rankings,
                  finances, skills, schedules and results will appear only after their
                  Supabase-backed systems are implemented.
                </p>
              </div>
            </div>
          </section>
        </aside>
      </div>
    </GameLayout>
  )
}
