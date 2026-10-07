import type { ReactNode } from 'react'
import { Construction, Database } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'

import '../../styles/module-tabs-calendar.css'
import '../../styles/shared-segmented-tabs.css'
import GameLayout from '../layout/GameLayout'

export interface DashboardModuleTab {
  id: string
  label: string
  content: ReactNode
}

export interface TabbedModulePageProps {
  title: string
  subtitle: string
  eyebrow: string
  intro: string
  icon: ReactNode
  tabs: DashboardModuleTab[]
  sideTitle: string
  sideDescription: string
  wide?: boolean
  initialTabId?: string
}

export function PlannedModuleContent({
  title,
  description,
  items,
}: {
  title: string
  description: string
  items: string[]
}) {
  return (
    <div className="tlg-module-tab-content">
      <h4>{title}</h4>
      <p>{description}</p>
      <div className="tlg-module-planned-list">
        {items.map((item) => (
          <div key={item} className="tlg-module-planned-row">
            <span />
            <strong>{item}</strong>
            <small>Planned</small>
          </div>
        ))}
      </div>
    </div>
  )
}

export default function TabbedModulePage({
  title,
  subtitle,
  eyebrow,
  intro,
  tabs,
  sideTitle,
  sideDescription,
  wide = false,
  initialTabId,
}: TabbedModulePageProps) {
  const initialTab = tabs.some((tab) => tab.id === initialTabId)
    ? initialTabId ?? tabs[0]?.id ?? ''
    : tabs[0]?.id ?? ''
  const [activeTabId, setActiveTabId] = useState(initialTab)

  useEffect(() => {
    if (initialTabId && tabs.some((tab) => tab.id === initialTabId)) {
      setActiveTabId(initialTabId)
    }
    // initialTabId is the external navigation signal; normal tab clicks must remain local.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialTabId])

  const activeTab = useMemo(
    () => tabs.find((tab) => tab.id === activeTabId) ?? tabs[0],
    [activeTabId, tabs],
  )

  return (
    <GameLayout title={title} subtitle={subtitle}>
      <header className="tlg-v2-page-head tlg-page-head-with-tabs">
        <div className="tlg-v2-page-head-copy">
          <div className="tlg-v2-page-eyebrow">{eyebrow}</div>
          <h2 className="tlg-v2-page-title">{title}</h2>
          <p className="tlg-v2-page-description">{intro}</p>
        </div>

        <div className="tlg-module-tabs tlg-module-tabs-top tlg-standard-tabs" role="tablist" aria-label={`${title} sections`}>
          {tabs.map((tab) => {
            const active = tab.id === activeTab?.id
            return (
              <button
                key={tab.id}
                type="button"
                role="tab"
                aria-selected={active}
                className={active ? 'tlg-module-tab tlg-module-tab-active active' : 'tlg-module-tab'}
                onClick={() => setActiveTabId(tab.id)}
              >
                {tab.label}
              </button>
            )
          })}
        </div>
      </header>

      <div className={wide ? 'tlg-v2-module-grid tlg-module-grid-wide' : 'tlg-v2-module-grid'}>
        <section className="tlg-v2-panel tlg-module-active-panel">
          <header className="tlg-v2-panel-header">
            <div>
              <span>Career module</span>
              <h3>{activeTab?.label ?? title}</h3>
            </div>
          </header>

          <div className="tlg-v2-panel-body">{activeTab?.content}</div>
        </section>

        {!wide && (
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
                  <strong>Ready for server-backed rules</strong>
                  <p>{sideDescription}</p>
                </div>
              </div>
            </section>

            <section className="tlg-v2-panel">
              <header className="tlg-v2-panel-header">
                <div>
                  <span>Data policy</span>
                  <h3>Live career state only</h3>
                </div>
              </header>
              <div className="tlg-v2-panel-body">
                <div className="tlg-v2-info-row">
                  <span className="tlg-v2-info-row-icon"><Database size={16} /></span>
                  <p>Values will appear only when their Tennis Legacy server systems are implemented. Placeholder career results are not fabricated.</p>
                </div>
              </div>
            </section>
          </aside>
        )}
      </div>
    </GameLayout>
  )
}
