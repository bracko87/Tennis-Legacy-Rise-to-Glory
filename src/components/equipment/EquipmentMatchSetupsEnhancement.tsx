import { createPortal } from 'react-dom'
import { useEffect, useMemo, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'

import { supabase } from '../../lib/supabase'
import '../../styles/equipment-refinement-v2.css'
import '../../styles/equipment-match-setups-polish.css'

type Json = Record<string, any>
type EffectEntry = [string, number]

const ACCESSORIES = ['bag', 'cap', 'towel', 'bottle', 'dampener', 'overgrip', 'wristband'] as const
const EFFECT_KEYS: Record<string, string> = {
  power_pct: 'power', control_pct: 'control', spin_pct: 'spin', movement_pct: 'movement',
  comfort_pct: 'comfort', serve_pct: 'serve', return_pct: 'return', rally_pct: 'rally',
  net_pct: 'net', stamina_pct: 'stamina', focus_pct: 'focus', heat_resistance_pct: 'heat',
  cold_resistance_pct: 'cold', racket_wear_reduction_pct: 'protection', forehand_pct: 'forehand',
  backhand_pct: 'backhand', stability_pct: 'stability',
}

function titleCase(value: string) {
  return value.replaceAll('-', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function itemLabel(entry: Json, t: TFunction) {
  return `${entry.item?.brand ?? t('equipmentPage.matchSetups.itemFallback')} ${entry.item?.model ?? ''} · ${Number(entry.condition ?? 0).toFixed(0)}%`
}

function formatEffect(value: number) {
  if (Math.abs(value) < 0.005) return '±0.00%'
  return `${value > 0 ? '+' : ''}${value.toFixed(2)}%`
}

function entriesForSetup(setup: Json | null | undefined, inventory: Json[]) {
  if (!setup) return []
  const inventoryById = new Map(inventory.map((entry) => [entry.inventory_id, entry]))
  const ids = [
    setup.racket_inventory_id,
    setup.shoes_inventory_id,
    setup.apparel_inventory_id,
    ...ACCESSORIES.map((kind) => setup.accessories?.[kind]),
  ].filter(Boolean) as string[]
  return ids.map((id) => inventoryById.get(id)).filter(Boolean) as Json[]
}

function aggregateEffects(entries: Json[]): EffectEntry[] {
  const totals: Record<string, number> = {}

  entries.forEach((entry) => {
    const effects = entry.item?.effective_gameplay_effects ?? entry.item?.gameplay_effects ?? {}
    Object.entries(effects).forEach(([key, rawValue]) => {
      const value = Number(rawValue)
      if (!Number.isFinite(value)) return
      totals[key] = (totals[key] ?? 0) + value
    })
  })

  return Object.entries(totals)
    .map(([key, value]) => [key, Number(value.toFixed(2))] as EffectEntry)
    .filter(([, value]) => Math.abs(value) >= 0.005)
    .sort((a, b) => Math.abs(b[1]) - Math.abs(a[1]))
}

function SetupBonusRow({ entries, title }: { entries: Json[]; title?: string }) {
  const { t } = useTranslation()
  const effects = aggregateEffects(entries)
  const displayTitle = title ?? t('equipmentPage.matchSetups.setupBonuses')
  const bonusCount = effects.filter(([, value]) => value > 0).length
  const tradeoffCount = effects.filter(([, value]) => value < 0).length

  return (
    <div className="tlg-match-setup-bonus-row">
      <div className="tlg-match-setup-bonus-head">
        <span>{displayTitle.toUpperCase()}</span>
        <b>
          {t('equipmentPage.matchSetups.bonus', { count: bonusCount })}
          {tradeoffCount > 0 ? ` · ${t('equipmentPage.matchSetups.tradeoff', { count: tradeoffCount })}` : ''}
        </b>
      </div>
      <div className="tlg-match-setup-bonus-chips">
        {effects.length > 0 ? effects.map(([key, value]) => (
          <span key={key} className={value < 0 ? 'negative' : 'positive'}>
            {EFFECT_KEYS[key] ? t(`equipmentPage.matchSetups.stats.${EFFECT_KEYS[key]}`) : titleCase(key.replace('_pct', ''))} {formatEffect(value)}
          </span>
        )) : <span className="neutral">{t('equipmentPage.matchSetups.noModifiers')}</span>}
      </div>
    </div>
  )
}

export default function EquipmentMatchSetupsEnhancement() {
  const { t } = useTranslation()
  const [customHost, setCustomHost] = useState<HTMLElement | null>(null)
  const [defaultHost, setDefaultHost] = useState<HTMLElement | null>(null)
  const [dashboard, setDashboard] = useState<Json | null>(null)
  const [inventory, setInventory] = useState<Json[]>([])
  const [setups, setSetups] = useState<Json[]>([])
  const [drafts, setDrafts] = useState<Record<number, Json>>({})
  const [busy, setBusy] = useState<number | null>(null)
  const [message, setMessage] = useState<string | null>(null)

  async function load() {
    const [equipment, setupResponse] = await Promise.all([
      supabase.rpc('get_equipment_dashboard_v1'),
      supabase.rpc('get_player_equipment_match_setups_v1'),
    ])

    if (!equipment.error) {
      const nextDashboard = (equipment.data as Json) ?? null
      setDashboard(nextDashboard)
      setInventory(((nextDashboard as Json)?.inventory ?? []) as Json[])
    }

    if (!setupResponse.error) {
      const rows = (((setupResponse.data as Json)?.setups ?? []) as Json[]).sort((a, b) => a.slot_index - b.slot_index)
      setSetups(rows)
      const next: Record<number, Json> = {}
      rows.forEach((row) => {
        next[row.slot_index] = { ...row, accessories: { ...(row.accessories ?? {}) } }
      })
      setDrafts(next)
    }
  }

  useEffect(() => { void load() }, [t])

  useEffect(() => {
    let currentCustomHost: HTMLElement | null = null
    let currentDefaultHost: HTMLElement | null = null

    const syncDom = () => {
      const gearView = document.querySelector<HTMLElement>('.tlg-equipment-gear-view')
      const defaultPanel = gearView?.querySelector<HTMLElement>(':scope > .tlg-equipment-panel') ?? null

      if (defaultPanel) {
        const label = defaultPanel.querySelector<HTMLElement>('.tlg-equipment-panel-head span')
        if (label?.textContent?.trim()) label.textContent = t('equipmentPage.matchSetups.defaultLabel')

        if (!currentDefaultHost || !document.body.contains(currentDefaultHost)) {
          currentDefaultHost = document.createElement('div')
          currentDefaultHost.dataset.tlgDefaultMatchSetupExtras = 'true'
          defaultPanel.appendChild(currentDefaultHost)
          setDefaultHost(currentDefaultHost)
        }

        if (!currentCustomHost || !document.body.contains(currentCustomHost)) {
          currentCustomHost = document.createElement('div')
          currentCustomHost.dataset.tlgMatchSetupsHost = 'true'
          defaultPanel.insertAdjacentElement('afterend', currentCustomHost)
          setCustomHost(currentCustomHost)
        }
      } else {
        if (currentDefaultHost) {
          currentDefaultHost.remove()
          currentDefaultHost = null
          setDefaultHost(null)
        }
        if (currentCustomHost) {
          currentCustomHost.remove()
          currentCustomHost = null
          setCustomHost(null)
        }
      }

      const market = document.querySelector<HTMLElement>('.tlg-equipment-market-panel')
      const activeCategory = market?.querySelector<HTMLButtonElement>('.tlg-equipment-category-tabs button.active')
      const tagRow = market?.querySelector<HTMLElement>('.tlg-equipment-tag-filter')
      if (tagRow) tagRow.style.display = activeCategory?.textContent?.trim() === 'All' ? 'none' : ''
    }

    syncDom()
    const observer = new MutationObserver(syncDom)
    observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['class'] })

    return () => {
      observer.disconnect()
      currentDefaultHost?.remove()
      currentCustomHost?.remove()
      setDefaultHost(null)
      setCustomHost(null)
    }
  }, [])

  const byType = useMemo(() => ({
    racket: inventory.filter((x) => x.item?.item_type === 'racket'),
    shoes: inventory.filter((x) => x.item?.item_type === 'shoes'),
    apparel: inventory.filter((x) => x.item?.item_type === 'apparel'),
    accessory: inventory.filter((x) => x.item?.item_type === 'accessory'),
  }), [inventory])

  const defaultEntries = useMemo(() => {
    const loadout = dashboard?.loadout
    if (!loadout) return []
    return [
      loadout.racket,
      loadout.shoes,
      loadout.apparel,
      ...((loadout.accessories ?? []) as Json[]),
    ].filter(Boolean) as Json[]
  }, [dashboard])

  function updateDraft(slot: number, patch: Json) {
    setDrafts((current) => ({ ...current, [slot]: { ...(current[slot] ?? {}), ...patch } }))
  }

  async function save(slot: number) {
    const d = drafts[slot]
    if (!d?.racket_inventory_id || !d?.shoes_inventory_id || !d?.apparel_inventory_id) {
      setMessage(t('equipmentPage.matchSetups.incomplete', { slot }))
      return
    }

    setBusy(slot)
    setMessage(null)
    const { data, error } = await supabase.rpc('save_player_equipment_match_setup_v1', {
      p_slot_index: slot,
      p_name: d.name || `Match Setup ${slot}`,
      p_racket_inventory_id: d.racket_inventory_id,
      p_shoes_inventory_id: d.shoes_inventory_id,
      p_apparel_inventory_id: d.apparel_inventory_id,
      p_accessories: d.accessories ?? {},
    })
    setBusy(null)

    if (error) {
      setMessage(error.message)
      return
    }

    const rows = (((data as Json)?.setups ?? []) as Json[]).sort((a, b) => a.slot_index - b.slot_index)
    setSetups(rows)
    const next: Record<number, Json> = {}
    rows.forEach((row) => {
      next[row.slot_index] = { ...row, accessories: { ...(row.accessories ?? {}) } }
    })
    setDrafts(next)
    setMessage(t('equipmentPage.matchSetups.saved', { name: d.name || `Match Setup ${slot}` }))
  }

  const select = (label: string, value: string, options: Json[], onChange: (value: string) => void) => (
    <label key={label} className="tlg-match-setup-field">
      <span>{label}</span>
      <select value={value ?? ''} onChange={(event) => onChange(event.target.value)}>
        <option value="">{t('equipmentPage.matchSetups.choose')}</option>
        {options.map((entry) => (
          <option key={entry.inventory_id} value={entry.inventory_id}>{itemLabel(entry, t)}</option>
        ))}
      </select>
    </label>
  )

  return (
    <>
      {defaultHost && createPortal(
        <div className="tlg-default-match-setup-extras">
          <SetupBonusRow entries={defaultEntries} title={t('equipmentPage.matchSetups.defaultBonuses')} />
        </div>,
        defaultHost,
      )}

      {customHost && setups.length > 0 && createPortal(
        <section className="tlg-equipment-panel tlg-custom-match-setups-panel">
          <header className="tlg-equipment-panel-head">
            <div>
              <span>{t('equipmentPage.matchSetups.kicker')}</span>
              <h2>{t('equipmentPage.matchSetups.title')}</h2>
              <p>{t('equipmentPage.matchSetups.body')}</p>
            </div>
          </header>

          {message && <div className="tlg-equipment-alert tlg-custom-setup-message">{message}</div>}

          <div className="tlg-custom-match-setups-grid">
            {setups.map((setup) => {
              const d = drafts[setup.slot_index] ?? setup
              const setupEntries = entriesForSetup(d, inventory)

              return (
                <article className="tlg-custom-match-setup-card" key={setup.slot_index}>
                  <div className="tlg-custom-match-setup-head">
                    <span>{t('equipmentPage.matchSetups.setupNumber', { slot: setup.slot_index })}</span>
                    <input value={d.name ?? ''} maxLength={40} onChange={(event) => updateDraft(setup.slot_index, { name: event.target.value })} />
                  </div>

                  <div className="tlg-custom-match-setup-main">
                    {select(t('equipmentPage.matchSetups.racquet'), d.racket_inventory_id, byType.racket, (value) => updateDraft(setup.slot_index, { racket_inventory_id: value || null }))}
                    {select(t('equipmentPage.matchSetups.shoes'), d.shoes_inventory_id, byType.shoes, (value) => updateDraft(setup.slot_index, { shoes_inventory_id: value || null }))}
                    {select(t('equipmentPage.matchSetups.clothing'), d.apparel_inventory_id, byType.apparel, (value) => updateDraft(setup.slot_index, { apparel_inventory_id: value || null }))}
                  </div>

                  <details>
                    <summary>{t('equipmentPage.matchSetups.accessories')}</summary>
                    <div className="tlg-custom-match-setup-accessories">
                      {ACCESSORIES.map((kind) => select(
                        titleCase(kind),
                        d.accessories?.[kind] ?? '',
                        byType.accessory.filter((x) => x.item?.accessory_kind === kind),
                        (value) => updateDraft(setup.slot_index, { accessories: { ...(d.accessories ?? {}), [kind]: value } }),
                      ))}
                    </div>
                  </details>

                  <button type="button" onClick={() => void save(setup.slot_index)} disabled={busy === setup.slot_index}>
                    {busy === setup.slot_index ? t('equipmentPage.matchSetups.saving') : t('equipmentPage.matchSetups.save')}
                  </button>

                  <SetupBonusRow entries={setupEntries} />
                </article>
              )
            })}
          </div>
        </section>,
        customHost,
      )}
    </>
  )
}
