import { useEffect, useMemo, useState } from 'react'

import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/equipment.css'

type EquipmentTab = 'gear' | 'market' | 'sponsors'
type EquipmentType = 'racket' | 'string' | 'shoes'
type CourtSurface = 'hard' | 'clay' | 'grass'
type MarketFilter = 'all' | EquipmentType

interface CatalogItem {
  id: string
  sku: string
  item_type: EquipmentType
  brand: string
  model: string
  description: string
  price_usd: number
  tier: number
  surface?: 'all' | CourtSurface | null
  power: number
  control: number
  spin: number
  comfort: number
  traction: number
  stability: number
  durability: number
}

interface InventoryItem {
  inventory_id: string
  condition: number
  acquired_source: string
  acquired_absolute_day: number
  item: CatalogItem
}

interface EquippedSlot {
  inventory_id: string
  condition: number
  item: CatalogItem
}

interface EquipmentLoadout {
  racket?: EquippedSlot | null
  string?: EquippedSlot | null
  shoes?: EquippedSlot | null
  string_tension_kg: number
  apparel_brand: string
  racket_sponsor_name?: string | null
  apparel_sponsor_name?: string | null
  footwear_sponsor_name?: string | null
}

interface EquipmentEffects {
  surface: CourtSurface
  power_pct: number
  control_pct: number
  spin_pct: number
  movement_pct: number
  comfort_pct: number
  string_tension_kg: number
  racket_condition: number
  string_condition: number
  shoes_condition: number
  shoe_surface: string
}

interface EquipmentDashboard {
  player_id: string
  currency: 'USD'
  balance: number
  loadout: EquipmentLoadout
  inventory: InventoryItem[]
  catalog: CatalogItem[]
  effects: Record<CourtSurface, EquipmentEffects>
  wear_rules: {
    racket_per_match: number
    strings_per_match: number
    shoes_surface_specific: number
    shoes_all_court: number
    shoes_wrong_surface: number
  }
}

const TYPE_LABELS: Record<EquipmentType, string> = {
  racket: 'Racket',
  string: 'Strings',
  shoes: 'Shoes',
}

function money(value: number) {
  return `$${Math.round(Number(value) || 0).toLocaleString()}`
}

function pct(value: number) {
  const numeric = Number(value) || 0
  if (Math.abs(numeric) < 0.005) return '±0.00%'
  return `${numeric > 0 ? '+' : ''}${numeric.toFixed(2)}%`
}

function conditionLabel(value: number) {
  if (value >= 80) return 'Excellent'
  if (value >= 60) return 'Good'
  if (value >= 40) return 'Worn'
  return 'Replace soon'
}

function surfaceLabel(surface?: string | null) {
  if (!surface || surface === 'all') return 'All Court'
  return `${surface.charAt(0).toUpperCase()}${surface.slice(1)} Court`
}

function mainStats(item: CatalogItem) {
  if (item.item_type === 'shoes') {
    return [
      ['Traction', item.traction],
      ['Stability', item.stability],
      ['Comfort', item.comfort],
      ['Durability', item.durability],
    ] as const
  }
  return [
    ['Power', item.power],
    ['Control', item.control],
    ['Spin', item.spin],
    ['Comfort', item.comfort],
  ] as const
}

export default function EquipmentPage() {
  const [tab, setTab] = useState<EquipmentTab>('gear')
  const [dashboard, setDashboard] = useState<EquipmentDashboard | null>(null)
  const [surface, setSurface] = useState<CourtSurface>('hard')
  const [marketFilter, setMarketFilter] = useState<MarketFilter>('all')
  const [tension, setTension] = useState('24.0')
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)

  async function loadEquipment() {
    setLoading(true)
    setError(null)
    const { data, error: equipmentError } = await supabase.rpc('get_equipment_dashboard_v1')
    if (equipmentError || !data) {
      setError(equipmentError?.message ?? 'Unable to load equipment.')
    } else {
      const next = data as EquipmentDashboard
      setDashboard(next)
      setTension(Number(next.loadout?.string_tension_kg ?? 24).toFixed(1))
    }
    setLoading(false)
  }

  useEffect(() => {
    void loadEquipment()
  }, [])

  async function buyItem(item: CatalogItem) {
    setBusy(`buy:${item.id}`)
    setError(null)
    setMessage(null)
    const { data, error: purchaseError } = await supabase.rpc('purchase_equipment_item_v1', { p_catalog_item_id: item.id })
    if (purchaseError) {
      setError(purchaseError.message)
    } else {
      setMessage(`${item.brand} ${item.model} purchased for ${money(item.price_usd)}.`)
      await loadEquipment()
      if (data && typeof data === 'object') setTab('gear')
    }
    setBusy(null)
  }

  async function equipItem(item: InventoryItem) {
    setBusy(`equip:${item.inventory_id}`)
    setError(null)
    setMessage(null)
    const { error: equipError } = await supabase.rpc('equip_equipment_item_v1', { p_inventory_id: item.inventory_id })
    if (equipError) setError(equipError.message)
    else {
      setMessage(`${item.item.brand} ${item.item.model} is now in your match setup.`)
      await loadEquipment()
    }
    setBusy(null)
  }

  async function saveTension() {
    const parsed = Number(tension)
    if (!Number.isFinite(parsed) || parsed < 20 || parsed > 28) {
      setError('String tension must be between 20 and 28 kg.')
      return
    }
    setBusy('tension')
    setError(null)
    setMessage(null)
    const { error: tensionError } = await supabase.rpc('set_equipment_string_tension_v1', { p_tension_kg: parsed })
    if (tensionError) setError(tensionError.message)
    else {
      setMessage(`String tension saved at ${parsed.toFixed(1)} kg.`)
      await loadEquipment()
    }
    setBusy(null)
  }

  const inventoryByType = useMemo(() => {
    const grouped: Record<EquipmentType, InventoryItem[]> = { racket: [], string: [], shoes: [] }
    for (const item of dashboard?.inventory ?? []) grouped[item.item.item_type].push(item)
    return grouped
  }, [dashboard?.inventory])

  const marketItems = useMemo(
    () => (dashboard?.catalog ?? []).filter((item) => marketFilter === 'all' || item.item_type === marketFilter),
    [dashboard?.catalog, marketFilter],
  )

  if (loading && !dashboard) {
    return (
      <GameLayout title="Equipment" subtitle="Match gear, wear and technical sponsors">
        <div className="tlg-equipment-state">Loading Equipment Center…</div>
      </GameLayout>
    )
  }

  const effects = dashboard?.effects?.[surface]

  return (
    <GameLayout title="Equipment" subtitle="Match gear, wear and technical sponsors">
      <div className="tlg-equipment-page">
        <section className="tlg-equipment-hero">
          <div className="tlg-equipment-hero-copy">
            <span>PERFORMANCE SETUP</span>
            <h1>Equipment Center</h1>
            <p>Manage the small but meaningful performance edge from your racket, strings and shoes. Apparel remains a sponsor and player-identity choice rather than a stat item.</p>
          </div>
        </section>

        <div className="tlg-equipment-tabs" role="tablist" aria-label="Equipment sections">
          <button type="button" className={tab === 'gear' ? 'active' : ''} onClick={() => setTab('gear')}>Gear Room</button>
          <button type="button" className={tab === 'market' ? 'active' : ''} onClick={() => setTab('market')}>Market</button>
          <button type="button" className={tab === 'sponsors' ? 'active' : ''} onClick={() => setTab('sponsors')}>Sponsors</button>
        </div>

        {error && <div className="tlg-equipment-alert error">{error}</div>}
        {message && <div className="tlg-equipment-alert">{message}</div>}

        {dashboard && (
          <section className="tlg-equipment-summary-strip">
            <div><span>CAREER CASH</span><strong>{money(dashboard.balance)}</strong><small>All purchases use Finance</small></div>
            <div><span>RACKET</span><strong>{dashboard.loadout.racket ? `${dashboard.loadout.racket.item.brand} ${dashboard.loadout.racket.item.model}` : 'Not equipped'}</strong><small>{dashboard.loadout.racket ? `${dashboard.loadout.racket.condition}% condition` : 'Choose from inventory'}</small></div>
            <div><span>STRING SETUP</span><strong>{dashboard.loadout.string ? dashboard.loadout.string.item.model : 'Not equipped'}</strong><small>{Number(dashboard.loadout.string_tension_kg).toFixed(1)} kg tension</small></div>
            <div><span>FOOTWEAR</span><strong>{dashboard.loadout.shoes ? dashboard.loadout.shoes.item.model : 'Not equipped'}</strong><small>{dashboard.loadout.shoes ? surfaceLabel(dashboard.loadout.shoes.item.surface) : 'Choose from inventory'}</small></div>
          </section>
        )}

        {dashboard && tab === 'gear' && (
          <div className="tlg-equipment-gear-view">
            <section className="tlg-equipment-panel">
              <header className="tlg-equipment-panel-head">
                <div><span>CURRENT MATCH SETUP</span><h2>Your gear room</h2><p>Only three equipment choices influence performance. Apparel is kept separate for sponsor identity.</p></div>
              </header>
              <div className="tlg-equipment-slot-grid">
                <EquipmentSlot title="Racket" slot={dashboard.loadout.racket} detail="Power · control · spin · comfort" />
                <EquipmentSlot title="Strings" slot={dashboard.loadout.string} detail={`${Number(dashboard.loadout.string_tension_kg).toFixed(1)} kg tension`} />
                <EquipmentSlot title="Shoes" slot={dashboard.loadout.shoes} detail={dashboard.loadout.shoes ? surfaceLabel(dashboard.loadout.shoes.item.surface) : 'Surface-specific footwear'} />
              </div>
            </section>

            <div className="tlg-equipment-two-column">
              <section className="tlg-equipment-panel tlg-equipment-tension-panel">
                <header className="tlg-equipment-panel-head compact">
                  <div><span>STRING SETUP</span><h2>Tension</h2><p>Lower tension favors power and comfort; higher tension favors control. Effects stay intentionally small.</p></div>
                </header>
                <div className="tlg-equipment-tension-control">
                  <input type="range" min="20" max="28" step="0.5" value={tension} onChange={(event) => setTension(event.target.value)} />
                  <div><strong>{Number(tension).toFixed(1)} kg</strong><span>20 kg · power</span><span>28 kg · control</span></div>
                  <button type="button" onClick={() => void saveTension()} disabled={busy === 'tension'}>{busy === 'tension' ? 'Saving…' : 'Save tension'}</button>
                </div>
              </section>

              <section className="tlg-equipment-panel">
                <header className="tlg-equipment-panel-head compact">
                  <div><span>MATCH PROFILE</span><h2>Equipment effect</h2><p>These modifiers are the authoritative gear contribution for the selected court surface.</p></div>
                  <div className="tlg-equipment-surface-switch">
                    {(['hard', 'clay', 'grass'] as CourtSurface[]).map((value) => <button key={value} type="button" className={surface === value ? 'active' : ''} onClick={() => setSurface(value)}>{value.charAt(0).toUpperCase() + value.slice(1)}</button>)}
                  </div>
                </header>
                {effects && (
                  <div className="tlg-equipment-effects-grid">
                    <Effect name="Power" value={effects.power_pct} />
                    <Effect name="Control" value={effects.control_pct} />
                    <Effect name="Spin" value={effects.spin_pct} />
                    <Effect name="Movement" value={effects.movement_pct} />
                    <Effect name="Comfort" value={effects.comfort_pct} />
                  </div>
                )}
              </section>
            </div>

            <section className="tlg-equipment-panel">
              <header className="tlg-equipment-panel-head">
                <div><span>OWNED GEAR</span><h2>Inventory</h2><p>Use another owned item without paying again. Wear belongs to each individual item.</p></div>
              </header>
              <div className="tlg-equipment-inventory-groups">
                {(['racket', 'string', 'shoes'] as EquipmentType[]).map((type) => (
                  <div className="tlg-equipment-inventory-group" key={type}>
                    <h3>{TYPE_LABELS[type]}</h3>
                    {inventoryByType[type].map((item) => {
                      const equippedId = type === 'racket' ? dashboard.loadout.racket?.inventory_id : type === 'string' ? dashboard.loadout.string?.inventory_id : dashboard.loadout.shoes?.inventory_id
                      const equipped = equippedId === item.inventory_id
                      return (
                        <div className={`tlg-equipment-inventory-row${equipped ? ' equipped' : ''}`} key={item.inventory_id}>
                          <div><strong>{item.item.brand} {item.item.model}</strong><span>{item.acquired_source === 'starter' ? 'Starter gear' : 'Owned'} · {type === 'shoes' ? surfaceLabel(item.item.surface) : `Tier ${item.item.tier}`}</span></div>
                          <div className="condition"><span>{conditionLabel(item.condition)}</span><div><i style={{ width: `${item.condition}%` }} /></div><b>{item.condition}%</b></div>
                          <button type="button" disabled={equipped || busy === `equip:${item.inventory_id}`} onClick={() => void equipItem(item)}>{equipped ? 'Equipped' : busy === `equip:${item.inventory_id}` ? 'Equipping…' : 'Use'}</button>
                        </div>
                      )
                    })}
                  </div>
                ))}
              </div>
            </section>

            <section className="tlg-equipment-wear-note">
              <div><span>RACKET WEAR</span><strong>−{dashboard.wear_rules.racket_per_match}% / match</strong></div>
              <div><span>STRING WEAR</span><strong>−{dashboard.wear_rules.strings_per_match}% / match</strong></div>
              <div><span>SHOE WEAR</span><strong>−{dashboard.wear_rules.shoes_surface_specific}% to −{dashboard.wear_rules.shoes_wrong_surface}% / match</strong></div>
              <p>Completed tournament matches automatically apply wear once. Using the correct surface shoe reduces footwear wear and improves movement slightly.</p>
            </section>
          </div>
        )}

        {dashboard && tab === 'market' && (
          <section className="tlg-equipment-panel tlg-equipment-market-panel">
            <header className="tlg-equipment-panel-head market-head">
              <div><span>EQUIPMENT MARKET</span><h2>Professional gear</h2><p>A deliberately small market: rackets, strings and shoes only. No shirts with artificial stat bonuses.</p></div>
              <div className="tlg-equipment-market-controls">
                <strong>{money(dashboard.balance)}</strong>
                <div>{(['all', 'racket', 'string', 'shoes'] as MarketFilter[]).map((value) => <button key={value} type="button" className={marketFilter === value ? 'active' : ''} onClick={() => setMarketFilter(value)}>{value === 'all' ? 'All' : TYPE_LABELS[value]}</button>)}</div>
              </div>
            </header>
            <div className="tlg-equipment-market-grid">
              {marketItems.map((item) => {
                const owned = dashboard.inventory.filter((entry) => entry.item.id === item.id).length
                return (
                  <article className="tlg-equipment-market-card" key={item.id}>
                    <div className="top"><span>{TYPE_LABELS[item.item_type]} · Tier {item.tier}</span>{item.item_type === 'shoes' && <b>{surfaceLabel(item.surface)}</b>}</div>
                    <h3>{item.brand}</h3>
                    <strong className="model">{item.model}</strong>
                    <p>{item.description}</p>
                    <div className="tlg-equipment-stat-grid">
                      {mainStats(item).map(([name, value]) => <div key={name}><span>{name}</span><strong>{value}</strong><div><i style={{ width: `${value}%` }} /></div></div>)}
                    </div>
                    <div className="bottom"><div><strong>{money(item.price_usd)}</strong><span>{owned > 0 ? `${owned} owned` : 'Not owned'}</span></div><button type="button" disabled={busy === `buy:${item.id}`} onClick={() => void buyItem(item)}>{busy === `buy:${item.id}` ? 'Buying…' : 'Buy'}</button></div>
                  </article>
                )
              })}
            </div>
          </section>
        )}

        {dashboard && tab === 'sponsors' && (
          <div className="tlg-equipment-sponsor-view">
            <section className="tlg-equipment-panel">
              <header className="tlg-equipment-panel-head">
                <div><span>TECHNICAL PARTNERS</span><h2>Equipment & apparel sponsors</h2><p>These slots are sponsor-controlled. Until a technical contract is signed, equipment is self-funded through your career Finance account.</p></div>
              </header>
              <div className="tlg-equipment-sponsor-grid">
                <SponsorSlot title="Racket partner" sponsor={dashboard.loadout.racket_sponsor_name} current={dashboard.loadout.racket ? dashboard.loadout.racket.item.brand : 'No racket'} detail="Future contracts can supply rackets and remove purchase costs." />
                <SponsorSlot title="Apparel partner" sponsor={dashboard.loadout.apparel_sponsor_name} current={dashboard.loadout.apparel_brand || 'Independent'} detail="Apparel is identity and commercial value only; it has no artificial match bonus." />
                <SponsorSlot title="Footwear partner" sponsor={dashboard.loadout.footwear_sponsor_name} current={dashboard.loadout.shoes ? dashboard.loadout.shoes.item.brand : 'No shoes'} detail="Future contracts can supply surface-specific shoes." />
              </div>
            </section>

            <section className="tlg-equipment-sponsor-roadmap">
              <span>SPONSOR-READY SYSTEM</span>
              <h2>One contract can connect Equipment and Finance</h2>
              <p>When the sponsorship engine is built, a technical sponsor will be able to pay income into the existing USD career ledger, require a brand in this Equipment Center, and provide sponsored gear at zero purchase cost. No second wallet or duplicate equipment system will be needed.</p>
            </section>
          </div>
        )}
      </div>
    </GameLayout>
  )
}

function EquipmentSlot({ title, slot, detail }: { title: string; slot?: EquippedSlot | null; detail: string }) {
  if (!slot) return <article className="tlg-equipment-slot empty"><span>{title.toUpperCase()}</span><h3>Not equipped</h3><p>{detail}</p></article>
  return (
    <article className="tlg-equipment-slot">
      <div className="slot-head"><span>{title.toUpperCase()}</span><b>{slot.condition}%</b></div>
      <h3>{slot.item.brand}</h3>
      <strong>{slot.item.model}</strong>
      <p>{detail}</p>
      <div className="condition-bar"><i style={{ width: `${slot.condition}%` }} /></div>
      <small>{conditionLabel(slot.condition)} condition</small>
    </article>
  )
}

function Effect({ name, value }: { name: string; value: number }) {
  return <div><span>{name}</span><strong className={value > 0 ? 'positive' : value < 0 ? 'negative' : ''}>{pct(value)}</strong></div>
}

function SponsorSlot({ title, sponsor, current, detail }: { title: string; sponsor?: string | null; current: string; detail: string }) {
  return (
    <article>
      <span>{title.toUpperCase()}</span>
      <strong>{sponsor || 'Independent'}</strong>
      <small>Current gear: {current}</small>
      <p>{detail}</p>
      <b>{sponsor ? 'Contract active' : 'Self-funded'}</b>
    </article>
  )
}
