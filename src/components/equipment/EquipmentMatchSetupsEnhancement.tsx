import { createPortal } from 'react-dom'
import { useEffect, useMemo, useState } from 'react'

import { supabase } from '../../lib/supabase'
import '../../styles/equipment-refinement-v2.css'
import '../../styles/equipment-match-setups-polish.css'

type Json = Record<string, any>
type EffectEntry = [string, number]

const ACCESSORIES = ['bag', 'cap', 'towel', 'bottle', 'dampener', 'overgrip', 'wristband'] as const
const EFFECT_LABELS: Record<string, string> = {
  power_pct: 'Power',
  control_pct: 'Control',
  spin_pct: 'Spin',
  movement_pct: 'Movement',
  comfort_pct: 'Comfort',
  serve_pct: 'Serve',
  return_pct: 'Return',
  rally_pct: 'Rally',
  net_pct: 'Net play',
  stamina_pct: 'Stamina',
  focus_pct: 'Focus',
  heat_resistance_pct: 'Heat resistance',
  cold_resistance_pct: 'Cold resistance',
  racket_wear_reduction_pct: 'Racquet protection',
  forehand_pct: 'Forehand',
  backhand_pct: 'Backhand',
  stability_pct: 'Stability',
}

function titleCase(value: string) {
  return value.replaceAll('-', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function itemLabel(entry: Json) {
  return `${entry.item?.brand ?? 'Item'} ${entry.item?.model ?? ''} · ${Number(entry.condition ?? 0).toFixed(0)}%`
}

function itemTypeLabel(entry: Json) {
  if (entry.item?.item_type === 'racket') return 'Racquet'
  if (entry.item?.item_type === 'shoes') return 'Shoes'
  if (entry.item?.item_type === 'apparel') return 'Clothing'
  if (entry.item?.item_type === 'accessory') return titleCase(entry.item?.accessory_kind ?? 'Accessory')
  return 'Equipment'
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

function SetupPreview({ entries, label = 'Equipment preview' }: { entries: Json[]; label?: string }) {
  return (
    <div className="tlg-match-setup-preview">
      <div className="tlg-match-setup-preview-head"><span>{label}</span><b>{entries.length} items</b></div>
      {entries.length > 0 ? (
        <div className="tlg-match-setup-preview-items">
          {entries.map((entry) => (
            <div className="tlg-match-setup-preview-item" key={entry.inventory_id}>
              <div className="tlg-match-setup-preview-media">
                {entry.item?.image_url ? <img src={entry.item.image_url} alt={`${entry.item?.brand ?? ''} ${entry.item?.model ?? ''}`.trim()} /> : <span>{(entry.item?.brand ?? '?').slice(0, 2).toUpperCase()}</span>}
              </div>
              <div><small>{itemTypeLabel(entry)}</small><strong>{entry.item?.brand ?? 'Equipment'} {entry.item?.model ?? ''}</strong><em>{Number(entry.condition ?? 0).toFixed(0)}% condition</em></div>
            </div>
          ))}
        </div>
      ) : <p className="tlg-match-setup-preview-empty">Choose equipment to build this setup.</p>}
    </div>
  )
}

function SetupBonusRow({ entries }: { entries: Json[] }) {
  const effects = aggregateEffects(entries)
  const bonusCount = effects.filter(([, value]) => value > 0).length
  const tradeoffCount = effects.filter(([, value]) => value < 0).length
  return (
    <div className="tlg-match-setup-bonus-row">
      <div className="tlg-match-setup-bonus-head">
        <span>SETUP BONUSES</span>
        <b>{bonusCount} {bonusCount === 1 ? 'bonus' : 'bonuses'}{tradeoffCount > 0 ? ` · ${tradeoffCount} ${tradeoffCount === 1 ? 'trade-off' : 'trade-offs'}` : ''}</b>
      </div>
      <div className="tlg-match-setup-bonus-chips">
        {effects.length > 0 ? effects.map(([key, value]) => <span key={key} className={value < 0 ? 'negative' : 'positive'}>{EFFECT_LABELS[key] ?? titleCase(key.replace('_pct', ''))} {formatEffect(value)}</span>) : <span className="neutral">No direct gameplay modifiers</span>}
      </div>
    </div>
  )
}

export default function EquipmentMatchSetupsEnhancement() {
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
      rows.forEach((row) => { next[row.slot_index] = { ...row, accessories: { ...(row.accessories ?? {}) } } })
      setDrafts(next)
    }
  }

  useEffect(() => { void load() }, [])

  useEffect(() => {
    let currentCustomHost: HTMLElement | null = null
    let currentDefaultHost: HTMLElement | null = null
    const syncDom = () => {
      const gearView = document.querySelector<HTMLElement>('.tlg-equipment-gear-view')
      const defaultPanel = gearView?.querySelector<HTMLElement>(':scope > .tlg-equipment-panel') ?? null
      if (defaultPanel) {
        const label = defaultPanel.querySelector<HTMLElement>('.tlg-equipment-panel-head span')
        if (label?.textContent?.trim() === 'CURRENT MATCH SETUP') label.textContent = 'DEFAULT MATCH SETUP'

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
        if (currentDefaultHost) { currentDefaultHost.remove(); currentDefaultHost = null; setDefaultHost(null) }
        if (currentCustomHost) { currentCustomHost.remove(); currentCustomHost = null; setCustomHost(null) }
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

  const defaultSetup = useMemo(() => {
    const loadout = dashboard?.loadout
    if (!loadout) return null
    const accessories: Record<string, string> = {}
    ;((loadout.accessories ?? []) as Json[]).forEach((entry) => {
      if (entry.accessory_kind && entry.inventory_id) accessories[entry.accessory_kind] = entry.inventory_id
    })
    return {
      racket_inventory_id: loadout.racket?.inventory_id ?? null,
      shoes_inventory_id: loadout.shoes?.inventory_id ?? null,
      apparel_inventory_id: loadout.apparel?.inventory_id ?? null,
      accessories,
    }
  }, [dashboard])

  const defaultEntries = useMemo(() => entriesForSetup(defaultSetup, inventory), [defaultSetup, inventory])

  function updateDraft(slot: number, patch: Json) {
    setDrafts((current) => ({ ...current, [slot]: { ...(current[slot] ?? {}), ...patch } }))
  }

  async function save(slot: number) {
    const d = drafts[slot]
    if (!d?.racket_inventory_id || !d?.shoes_inventory_id || !d?.apparel_inventory_id) {
      setMessage(`Match Setup ${slot}: choose a racquet, shoes and clothing first.`)
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
    if (error) setMessage(error.message)
    else {
      const rows = (((data as Json)?.setups ?? []) as Json[]).sort((a, b) => a.slot_index - b.slot_index)
      setSetups(rows)
      const next: Record<number, Json> = {}
      rows.forEach((row) => { next[row.slot_index] = { ...row, accessories: { ...(row.accessories ?? {}) } } })
      setDrafts(next)
      setMessage(`${d.name || `Match Setup ${slot}`} saved.`)
    }
  }

  const select = (label: string, value: string, options: Json[], onChange: (value: string) => void) => (
    <label key={label} className="tlg-match-setup-field">
      <span>{label}</span>
      <select value={value ?? ''} onChange={(event) => onChange(event.target.value)}>
        <option value="">Choose…</option>
        {options.map((entry) => <option key={entry.inventory_id} value={entry.inventory_id}>{itemLabel(entry)}</option>)}
      </select>
    </label>
  )

  return (
    <>
      {defaultHost && createPortal(
        <div className="tlg-default-match-setup-extras">
          <SetupPreview entries={defaultEntries} label="Default setup preview" />
          <SetupBonusRow entries={defaultEntries} />
        </div>,
        defaultHost,
      )}

      {customHost && setups.length > 0 && createPortal(
        <section className="tlg-equipment-panel tlg-custom-match-setups-panel">
          <header className="tlg-equipment-panel-head"><div><span>CUSTOM MATCH SETUPS</span><h2>Four reusable equipment configurations</h2><p>Save alternative gear combinations and choose one on a match tactic screen. The same owned item may appear in several saved setups because only one setup is used in a match.</p></div></header>
          {message && <div className="tlg-equipment-alert tlg-custom-setup-message">{message}</div>}
          <div className="tlg-custom-match-setups-grid">{setups.map((setup) => {
            const d = drafts[setup.slot_index] ?? setup
            const previewEntries = entriesForSetup(d, inventory)
            return (
              <article className="tlg-custom-match-setup-card" key={setup.slot_index}>
                <div className="tlg-custom-match-setup-head"><span>SETUP {setup.slot_index}</span><input value={d.name ?? ''} maxLength={40} onChange={(event) => updateDraft(setup.slot_index, { name: event.target.value })} /></div>
                <SetupPreview entries={previewEntries} />
                <div className="tlg-custom-match-setup-main">
                  {select('Racquet', d.racket_inventory_id, byType.racket, (value) => updateDraft(setup.slot_index, { racket_inventory_id: value || null }))}
                  {select('Shoes', d.shoes_inventory_id, byType.shoes, (value) => updateDraft(setup.slot_index, { shoes_inventory_id: value || null }))}
                  {select('Clothing', d.apparel_inventory_id, byType.apparel, (value) => updateDraft(setup.slot_index, { apparel_inventory_id: value || null }))}
                </div>
                <details><summary>Accessories</summary><div className="tlg-custom-match-setup-accessories">{ACCESSORIES.map((kind) => select(titleCase(kind), d.accessories?.[kind] ?? '', byType.accessory.filter((x) => x.item?.accessory_kind === kind), (value) => updateDraft(setup.slot_index, { accessories: { ...(d.accessories ?? {}), [kind]: value } })))}</div></details>
                <button type="button" onClick={() => void save(setup.slot_index)} disabled={busy === setup.slot_index}>{busy === setup.slot_index ? 'Saving…' : 'Save setup'}</button>
                <SetupBonusRow entries={previewEntries} />
              </article>
            )
          })}</div>
        </section>,
        customHost,
      )}
    </>
  )
}
