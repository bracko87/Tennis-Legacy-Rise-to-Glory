import { createPortal } from 'react-dom'
import { useEffect, useMemo, useState } from 'react'

import { supabase } from '../../lib/supabase'
import '../../styles/equipment-refinement-v2.css'

type Json = Record<string, any>
const ACCESSORIES = ['bag','cap','towel','bottle','dampener','overgrip','wristband'] as const

function itemLabel(entry: Json) {
  return `${entry.item?.brand ?? 'Item'} ${entry.item?.model ?? ''} · ${Number(entry.condition ?? 0).toFixed(0)}%`
}

export default function EquipmentMatchSetupsEnhancement() {
  const [host, setHost] = useState<HTMLElement | null>(null)
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
    if (!equipment.error) setInventory(((equipment.data as Json)?.inventory ?? []) as Json[])
    if (!setupResponse.error) {
      const rows = (((setupResponse.data as Json)?.setups ?? []) as Json[]).sort((a,b) => a.slot_index-b.slot_index)
      setSetups(rows)
      const next: Record<number, Json> = {}
      rows.forEach((row) => { next[row.slot_index] = { ...row, accessories: { ...(row.accessories ?? {}) } } })
      setDrafts(next)
    }
  }

  useEffect(() => { void load() }, [])

  useEffect(() => {
    let currentHost: HTMLElement | null = null
    const syncDom = () => {
      const gearView = document.querySelector<HTMLElement>('.tlg-equipment-gear-view')
      const defaultPanel = gearView?.querySelector<HTMLElement>(':scope > .tlg-equipment-panel') ?? null
      if (defaultPanel) {
        const label = defaultPanel.querySelector<HTMLElement>('.tlg-equipment-panel-head span')
        if (label?.textContent?.trim() === 'CURRENT MATCH SETUP') label.textContent = 'DEFAULT MATCH SETUP'
        if (!currentHost || !document.body.contains(currentHost)) {
          currentHost = document.createElement('div')
          currentHost.dataset.tlgMatchSetupsHost = 'true'
          defaultPanel.insertAdjacentElement('afterend', currentHost)
          setHost(currentHost)
        }
      } else if (currentHost) {
        currentHost.remove(); currentHost = null; setHost(null)
      }

      const market = document.querySelector<HTMLElement>('.tlg-equipment-market-panel')
      const activeCategory = market?.querySelector<HTMLButtonElement>('.tlg-equipment-category-tabs button.active')
      const tagRow = market?.querySelector<HTMLElement>('.tlg-equipment-tag-filter')
      if (tagRow) tagRow.style.display = activeCategory?.textContent?.trim() === 'All' ? 'none' : ''
    }
    syncDom()
    const observer = new MutationObserver(syncDom)
    observer.observe(document.body,{childList:true,subtree:true,attributes:true,attributeFilter:['class']})
    return () => { observer.disconnect(); currentHost?.remove(); setHost(null) }
  }, [])

  const byType = useMemo(() => ({
    racket: inventory.filter((x) => x.item?.item_type === 'racket'),
    shoes: inventory.filter((x) => x.item?.item_type === 'shoes'),
    apparel: inventory.filter((x) => x.item?.item_type === 'apparel'),
    accessory: inventory.filter((x) => x.item?.item_type === 'accessory'),
  }), [inventory])

  function updateDraft(slot: number, patch: Json) {
    setDrafts((current) => ({ ...current, [slot]: { ...(current[slot] ?? {}), ...patch } }))
  }

  async function save(slot: number) {
    const d = drafts[slot]
    if (!d?.racket_inventory_id || !d?.shoes_inventory_id || !d?.apparel_inventory_id) {
      setMessage(`Match Setup ${slot}: choose a racquet, shoes and clothing first.`)
      return
    }
    setBusy(slot); setMessage(null)
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
      const rows = (((data as Json)?.setups ?? []) as Json[]).sort((a,b) => a.slot_index-b.slot_index)
      setSetups(rows)
      const next: Record<number, Json> = {}
      rows.forEach((row) => { next[row.slot_index] = { ...row, accessories: { ...(row.accessories ?? {}) } } })
      setDrafts(next)
      setMessage(`${d.name || `Match Setup ${slot}`} saved.`)
    }
  }

  if (!host || setups.length === 0) return null

  const select = (label: string, value: string, options: Json[], onChange: (value:string)=>void) => <label key={label} className="tlg-match-setup-field"><span>{label}</span><select value={value ?? ''} onChange={(e)=>onChange(e.target.value)}><option value="">Choose…</option>{options.map((entry)=><option key={entry.inventory_id} value={entry.inventory_id}>{itemLabel(entry)}</option>)}</select></label>

  return createPortal(
    <section className="tlg-equipment-panel tlg-custom-match-setups-panel">
      <header className="tlg-equipment-panel-head"><div><span>CUSTOM MATCH SETUPS</span><h2>Four reusable equipment configurations</h2><p>Save alternative gear combinations and choose one on a match tactic screen. The same owned item may appear in several saved setups because only one setup is used in a match.</p></div></header>
      {message && <div className="tlg-equipment-alert tlg-custom-setup-message">{message}</div>}
      <div className="tlg-custom-match-setups-grid">{setups.map((setup) => {
        const d = drafts[setup.slot_index] ?? setup
        return <article className="tlg-custom-match-setup-card" key={setup.slot_index}>
          <div className="tlg-custom-match-setup-head"><span>SETUP {setup.slot_index}</span><input value={d.name ?? ''} maxLength={40} onChange={(e)=>updateDraft(setup.slot_index,{name:e.target.value})} /></div>
          <div className="tlg-custom-match-setup-main">
            {select('Racquet',d.racket_inventory_id,byType.racket,(v)=>updateDraft(setup.slot_index,{racket_inventory_id:v||null}))}
            {select('Shoes',d.shoes_inventory_id,byType.shoes,(v)=>updateDraft(setup.slot_index,{shoes_inventory_id:v||null}))}
            {select('Clothing',d.apparel_inventory_id,byType.apparel,(v)=>updateDraft(setup.slot_index,{apparel_inventory_id:v||null}))}
          </div>
          <details><summary>Accessories</summary><div className="tlg-custom-match-setup-accessories">{ACCESSORIES.map((kind) => select(kind.charAt(0).toUpperCase()+kind.slice(1),d.accessories?.[kind] ?? '',byType.accessory.filter((x)=>x.item?.accessory_kind===kind),(v)=>updateDraft(setup.slot_index,{accessories:{...(d.accessories??{}),[kind]:v}})))}</div></details>
          <button type="button" onClick={()=>void save(setup.slot_index)} disabled={busy===setup.slot_index}>{busy===setup.slot_index?'Saving…':'Save setup'}</button>
        </article>
      })}</div>
    </section>, host,
  )
}
