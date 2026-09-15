import { useEffect, useMemo, useState } from 'react'

import GameConfirmDialog from '../../components/common/GameConfirmDialog'
import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/equipment.css'
import '../../styles/equipment-marketplace-v2.css'

type EquipmentTab = 'gear' | 'inventory' | 'market' | 'sponsors'
type EquipmentType = 'racket' | 'shoes' | 'apparel' | 'accessory'
type EquipSlot = 'racket' | 'shoes'
type CourtSurface = 'hard' | 'clay' | 'grass'
type MarketFilter = 'all' | EquipmentType
type MarketSort = 'featured' | 'price-low' | 'price-high' | 'tier-high' | 'durability-high'
type InventoryFilter = 'all' | EquipmentType
type InventorySort = 'recent' | 'condition-high' | 'condition-low' | 'tier-high' | 'value-high'

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
  image_url: string
  tags: string[]
  advantages: string[]
  disadvantages: string[]
  maintenance_text: string
  lifespan_text: string
  effect_scope: 'match' | 'cosmetic' | 'none'
  availability_status: 'available' | 'unavailable' | 'limited' | 'sponsor_only'
  equip_slot?: EquipSlot | null
  is_resellable: boolean
  resale_modifier: number
  sort_order: number
}

interface InventoryItem {
  inventory_id: string
  condition: number
  acquired_source: string
  acquired_absolute_day: number
  purchase_price_usd: number
  resale_value_usd: number
  is_equipped: boolean
  resell_supported: boolean
  can_sell: boolean
  sell_block_reason?: string | null
  item: CatalogItem
}

interface EquippedSlot {
  inventory_id: string
  condition: number
  item: CatalogItem
}

interface EquipmentLoadout {
  racket?: EquippedSlot | null
  shoes?: EquippedSlot | null
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
  racket_condition: number
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
  resale_base_percent: number
  effects: Record<CourtSurface, EquipmentEffects>
  wear_rules: {
    racket_per_match: number
    shoes_surface_specific: number
    shoes_all_court: number
    shoes_wrong_surface: number
  }
}

interface PendingPurchase {
  item: CatalogItem
  requestKey: string
}

const TYPE_LABELS: Record<EquipmentType, string> = {
  racket: 'Racquets',
  shoes: 'Shoes',
  apparel: 'Clothing',
  accessory: 'Accessories',
}

const TYPE_ORDER: EquipmentType[] = ['racket', 'shoes', 'apparel', 'accessory']

const TIER_LABELS: Record<number, string> = {
  1: 'Starter',
  2: 'Advanced',
  3: 'Tour',
  4: 'Elite',
  5: 'Legend',
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
  if (value >= 60) return 'Used'
  if (value >= 40) return 'Worn'
  return 'Replace soon'
}

function surfaceLabel(surface?: string | null) {
  if (!surface || surface === 'all') return 'All Court'
  return `${surface.charAt(0).toUpperCase()}${surface.slice(1)} Court`
}

function availabilityLabel(status: CatalogItem['availability_status']) {
  if (status === 'sponsor_only') return 'Sponsor only'
  return `${status.charAt(0).toUpperCase()}${status.slice(1)}`
}

function effectScopeLabel(scope: CatalogItem['effect_scope']) {
  if (scope === 'match') return 'Match performance'
  if (scope === 'cosmetic') return 'Identity / cosmetic'
  return 'No gameplay effect'
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
  if (item.item_type === 'racket') {
    return [
      ['Power', item.power],
      ['Control', item.control],
      ['Spin', item.spin],
      ['Comfort', item.comfort],
    ] as const
  }
  return [['Durability', item.durability]] as const
}

function getEquippedSlot(loadout: EquipmentLoadout, slot?: EquipSlot | null) {
  if (slot === 'racket') return loadout.racket
  if (slot === 'shoes') return loadout.shoes
  return null
}

function acquisitionLabel(item: InventoryItem) {
  if (item.acquired_source === 'starter') return 'Starter equipment'
  if (item.acquired_source === 'sponsor') return 'Sponsor supplied'
  if (item.acquired_source === 'reward') return 'Reward equipment'
  return `Purchased · Career day ${item.acquired_absolute_day}`
}

function makeRequestKey() {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID()
  return `equipment-${Date.now()}-${Math.random().toString(36).slice(2)}`
}

export default function EquipmentPage() {
  const [tab, setTab] = useState<EquipmentTab>('gear')
  const [dashboard, setDashboard] = useState<EquipmentDashboard | null>(null)
  const [surface, setSurface] = useState<CourtSurface>('hard')
  const [marketFilter, setMarketFilter] = useState<MarketFilter>('all')
  const [marketTag, setMarketTag] = useState('all')
  const [marketSort, setMarketSort] = useState<MarketSort>('featured')
  const [inventoryFilter, setInventoryFilter] = useState<InventoryFilter>('all')
  const [inventorySort, setInventorySort] = useState<InventorySort>('recent')
  const [selectedMarketItem, setSelectedMarketItem] = useState<CatalogItem | null>(null)
  const [selectedInventoryItem, setSelectedInventoryItem] = useState<InventoryItem | null>(null)
  const [pendingPurchase, setPendingPurchase] = useState<PendingPurchase | null>(null)
  const [pendingSale, setPendingSale] = useState<InventoryItem | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)

  async function loadEquipment() {
    setLoading(true)
    setError(null)
    const { data, error: equipmentError } = await supabase.rpc('get_equipment_dashboard_v1')
    if (equipmentError || !data) setError(equipmentError?.message ?? 'Unable to load equipment.')
    else setDashboard(data as EquipmentDashboard)
    setLoading(false)
  }

  useEffect(() => {
    void loadEquipment()
  }, [])

  useEffect(() => {
    setMarketTag('all')
  }, [marketFilter])

  useEffect(() => {
    if (!selectedMarketItem && !selectedInventoryItem) return
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key !== 'Escape' || pendingPurchase || pendingSale) return
      setSelectedMarketItem(null)
      setSelectedInventoryItem(null)
    }
    window.addEventListener('keydown', closeOnEscape)
    return () => {
      document.body.style.overflow = previousOverflow
      window.removeEventListener('keydown', closeOnEscape)
    }
  }, [selectedMarketItem, selectedInventoryItem, pendingPurchase, pendingSale])

  function requestPurchase(item: CatalogItem) {
    if (item.availability_status !== 'available') return
    setPendingPurchase({ item, requestKey: makeRequestKey() })
  }

  async function buyItem() {
    if (!pendingPurchase) return
    const { item, requestKey } = pendingPurchase
    setBusy(`buy:${item.id}`)
    setError(null)
    setMessage(null)

    const { error: purchaseError } = await supabase.rpc('purchase_equipment_item_v2', {
      p_catalog_item_id: item.id,
      p_request_key: requestKey,
    })

    if (purchaseError) setError(purchaseError.message)
    else {
      setMessage(`${item.brand} ${item.model} purchased for ${money(item.price_usd)} and added to Inventory.`)
      setPendingPurchase(null)
      setSelectedMarketItem(null)
      await loadEquipment()
    }
    setBusy(null)
  }

  async function sellItem() {
    if (!pendingSale) return
    const item = pendingSale
    setBusy(`sell:${item.inventory_id}`)
    setError(null)
    setMessage(null)

    const { error: saleError } = await supabase.rpc('sell_equipment_item_v1', {
      p_inventory_id: item.inventory_id,
    })

    if (saleError) setError(saleError.message)
    else {
      setMessage(`${item.item.brand} ${item.item.model} sold for ${money(item.resale_value_usd)}.`)
      setPendingSale(null)
      setSelectedInventoryItem(null)
      await loadEquipment()
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
      setMessage(`${item.item.brand} ${item.item.model} is now equipped in Gear Room.`)
      setSelectedInventoryItem(null)
      await loadEquipment()
    }
    setBusy(null)
  }

  const inventoryItems = useMemo(() => {
    const items = (dashboard?.inventory ?? []).filter((entry) => inventoryFilter === 'all' || entry.item.item_type === inventoryFilter)
    return [...items].sort((a, b) => {
      if (inventorySort === 'condition-high') return b.condition - a.condition || b.acquired_absolute_day - a.acquired_absolute_day
      if (inventorySort === 'condition-low') return a.condition - b.condition || b.acquired_absolute_day - a.acquired_absolute_day
      if (inventorySort === 'tier-high') return b.item.tier - a.item.tier || b.condition - a.condition
      if (inventorySort === 'value-high') return b.resale_value_usd - a.resale_value_usd || b.purchase_price_usd - a.purchase_price_usd
      return b.acquired_absolute_day - a.acquired_absolute_day || b.item.sort_order - a.item.sort_order
    })
  }, [dashboard?.inventory, inventoryFilter, inventorySort])

  const inventoryCounts = useMemo(() => {
    const counts: Record<EquipmentType, number> = { racket: 0, shoes: 0, apparel: 0, accessory: 0 }
    for (const entry of dashboard?.inventory ?? []) counts[entry.item.item_type] += 1
    return counts
  }, [dashboard?.inventory])

  const availableTags = useMemo(() => {
    const tags = new Set<string>()
    for (const item of dashboard?.catalog ?? []) {
      if (marketFilter !== 'all' && item.item_type !== marketFilter) continue
      for (const tag of item.tags ?? []) tags.add(tag)
    }
    return [...tags].sort((a, b) => a.localeCompare(b))
  }, [dashboard?.catalog, marketFilter])

  const marketItems = useMemo(() => {
    const items = (dashboard?.catalog ?? [])
      .filter((item) => marketFilter === 'all' || item.item_type === marketFilter)
      .filter((item) => marketTag === 'all' || item.tags?.includes(marketTag))

    return [...items].sort((a, b) => {
      if (marketSort === 'price-low') return a.price_usd - b.price_usd
      if (marketSort === 'price-high') return b.price_usd - a.price_usd
      if (marketSort === 'tier-high') return b.tier - a.tier || a.sort_order - b.sort_order
      if (marketSort === 'durability-high') return b.durability - a.durability || a.sort_order - b.sort_order
      return a.sort_order - b.sort_order
    })
  }, [dashboard?.catalog, marketFilter, marketSort, marketTag])

  function visitMarket(type: InventoryFilter = 'all') {
    setMarketFilter(type)
    setMarketTag('all')
    setTab('market')
  }

  if (loading && !dashboard) {
    return (
      <GameLayout title="Equipment" subtitle="Racquets, shoes, clothing and accessories">
        <div className="tlg-equipment-state">Loading Equipment Center…</div>
      </GameLayout>
    )
  }

  const effects = dashboard?.effects?.[surface]

  return (
    <GameLayout title="Equipment" subtitle="Racquets, shoes, clothing and accessories">
      <div className="tlg-equipment-page">
        <section className="tlg-equipment-hero">
          <div className="tlg-equipment-hero-copy">
            <span>EQUIPMENT</span>
            <h1>Equipment Center</h1>
            <p>Gear Room shows what you are currently using. Inventory stores everything you own. Market handles purchases, while the existing sponsor area remains separate for the technical-sponsor task.</p>
          </div>
        </section>

        <div className="tlg-equipment-tabs" role="tablist" aria-label="Equipment sections">
          <button type="button" className={tab === 'gear' ? 'active' : ''} onClick={() => setTab('gear')}>Gear Room</button>
          <button type="button" className={tab === 'inventory' ? 'active' : ''} onClick={() => setTab('inventory')}>Inventory</button>
          <button type="button" className={tab === 'market' ? 'active' : ''} onClick={() => setTab('market')}>Market</button>
          <button type="button" className={tab === 'sponsors' ? 'active' : ''} onClick={() => setTab('sponsors')}>Sponsors</button>
        </div>

        {error && <div className="tlg-equipment-alert error">{error}</div>}
        {message && <div className="tlg-equipment-alert">{message}</div>}

        {dashboard && (
          <section className="tlg-equipment-summary-strip tlg-equipment-summary-strip-four-types">
            <div><span>CAREER CASH</span><strong>{money(dashboard.balance)}</strong><small>Market uses Career Finance</small></div>
            <div><span>RACQUET</span><strong>{dashboard.loadout.racket ? `${dashboard.loadout.racket.item.brand} ${dashboard.loadout.racket.item.model}` : 'Not equipped'}</strong><small>{dashboard.loadout.racket ? `${dashboard.loadout.racket.condition}% condition` : 'Choose from Inventory'}</small></div>
            <div><span>SHOES</span><strong>{dashboard.loadout.shoes ? dashboard.loadout.shoes.item.model : 'Not equipped'}</strong><small>{dashboard.loadout.shoes ? surfaceLabel(dashboard.loadout.shoes.item.surface) : 'Choose from Inventory'}</small></div>
          </section>
        )}

        {dashboard && tab === 'gear' && (
          <div className="tlg-equipment-gear-view">
            <section className="tlg-equipment-panel">
              <header className="tlg-equipment-panel-head">
                <div><span>CURRENT MATCH SETUP</span><h2>Your gear room</h2><p>Gear Room is only for equipment currently in use. Change racquets or shoes from Inventory; the previous item stays owned unless you sell it.</p></div>
                <button type="button" className="tlg-equipment-panel-link" onClick={() => setTab('inventory')}>Open Inventory</button>
              </header>
              <div className="tlg-equipment-slot-grid tlg-equipment-slot-grid-two">
                <EquipmentSlot title="Racquet" slot={dashboard.loadout.racket} detail="Power · control · spin · comfort" />
                <EquipmentSlot title="Shoes" slot={dashboard.loadout.shoes} detail={dashboard.loadout.shoes ? surfaceLabel(dashboard.loadout.shoes.item.surface) : 'Surface-specific footwear'} />
              </div>
            </section>

            <section className="tlg-equipment-panel">
              <header className="tlg-equipment-panel-head compact">
                <div><span>MATCH PROFILE</span><h2>Equipment effect</h2><p>These modifiers are the authoritative contribution from the equipped racquet and shoes for the selected court surface.</p></div>
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

            <section className="tlg-equipment-wear-note tlg-equipment-wear-note-two">
              <div><span>RACQUET WEAR</span><strong>−{dashboard.wear_rules.racket_per_match}% / match</strong></div>
              <div><span>SHOE WEAR</span><strong>−{dashboard.wear_rules.shoes_surface_specific}% to −{dashboard.wear_rules.shoes_wrong_surface}% / match</strong></div>
              <p>Condition is stored on each owned item and updates Inventory automatically after match wear.</p>
            </section>
          </div>
        )}

        {dashboard && tab === 'inventory' && (
          <section className="tlg-equipment-panel tlg-equipment-inventory-panel-v3">
            <header className="tlg-equipment-panel-head market-head tlg-equipment-market-head-v2">
              <div><span>OWNED EQUIPMENT</span><h2>Inventory</h2><p>Everything you own lives here. Inspect condition, durability, benefits, resale value and equipped status, then equip or sell supported items.</p></div>
              <div className="tlg-equipment-market-balance"><span>OWNED ITEMS</span><strong>{dashboard.inventory.length}</strong></div>
            </header>

            <div className="tlg-equipment-market-toolbar tlg-equipment-inventory-toolbar">
              <div className="tlg-equipment-category-tabs" role="tablist" aria-label="Inventory categories">
                <button type="button" className={inventoryFilter === 'all' ? 'active' : ''} onClick={() => setInventoryFilter('all')}>All <small>{dashboard.inventory.length}</small></button>
                {TYPE_ORDER.map((type) => <button key={type} type="button" className={inventoryFilter === type ? 'active' : ''} onClick={() => setInventoryFilter(type)}>{TYPE_LABELS[type]} <small>{inventoryCounts[type]}</small></button>)}
              </div>
              <label className="tlg-equipment-sort">
                <span>Sort</span>
                <select value={inventorySort} onChange={(event) => setInventorySort(event.target.value as InventorySort)}>
                  <option value="recent">Recently acquired</option>
                  <option value="condition-high">Condition: high first</option>
                  <option value="condition-low">Condition: low first</option>
                  <option value="tier-high">Quality: high first</option>
                  <option value="value-high">Resale value: high first</option>
                </select>
              </label>
            </div>

            {inventoryItems.length > 0 ? (
              <div className="tlg-equipment-inventory-card-grid">
                {inventoryItems.map((entry) => {
                  const equippable = Boolean(entry.item.equip_slot)
                  return (
                    <article className={`tlg-equipment-owned-card${entry.is_equipped ? ' equipped' : ''}`} key={entry.inventory_id}>
                      <ProductImage item={entry.item} large />
                      <div className="tlg-equipment-owned-card-body">
                        <div className="tlg-equipment-owned-card-top"><span>{TYPE_LABELS[entry.item.item_type]} · {TIER_LABELS[entry.item.tier] ?? 'Tier'} {entry.item.tier}</span><b>{entry.is_equipped ? 'Equipped' : 'Owned'}</b></div>
                        <h3>{entry.item.brand} {entry.item.model}</h3>
                        <p>{entry.item.description}</p>
                        <div className="tlg-equipment-owned-condition"><div><span>Condition</span><strong>{entry.condition}% · {conditionLabel(entry.condition)}</strong></div><div className="tlg-equipment-condition-track"><i style={{ width: `${entry.condition}%` }} /></div></div>
                        <div className="tlg-equipment-owned-facts"><span>Durability rating <b>{entry.item.durability}</b></span><span>Resale <b>{entry.resell_supported ? money(entry.resale_value_usd) : 'Not supported'}</b></span></div>
                        <div className="tlg-equipment-owned-highlights">
                          <span className="positive">{entry.item.advantages?.[0] ?? effectScopeLabel(entry.item.effect_scope)}</span>
                          <span className="negative">{entry.item.disadvantages?.[0] ?? 'No defined trade-off'}</span>
                        </div>
                        <div className="tlg-equipment-owned-card-actions">
                          <button type="button" className="secondary" onClick={() => setSelectedInventoryItem(entry)}>View details</button>
                          {equippable && <button type="button" disabled={entry.is_equipped || busy === `equip:${entry.inventory_id}`} onClick={() => void equipItem(entry)}>{entry.is_equipped ? 'Equipped' : busy === `equip:${entry.inventory_id}` ? 'Equipping…' : 'Equip'}</button>}
                        </div>
                      </div>
                    </article>
                  )
                })}
              </div>
            ) : (
              <div className="tlg-equipment-inventory-empty">
                <h3>{inventoryFilter === 'all' ? 'Your inventory is empty.' : `No ${TYPE_LABELS[inventoryFilter].toLowerCase()} in your inventory.`}</h3>
                <p>Visit the Equipment Market to purchase equipment for this category.</p>
                <button type="button" onClick={() => visitMarket(inventoryFilter)}>Visit Market</button>
              </div>
            )}
          </section>
        )}

        {dashboard && tab === 'market' && (
          <section className="tlg-equipment-panel tlg-equipment-market-panel">
            <header className="tlg-equipment-panel-head market-head tlg-equipment-market-head-v2">
              <div><span>EQUIPMENT MARKET</span><h2>Professional equipment</h2><p>The market uses the finalized four equipment types: Racquets, Shoes, Clothing and Accessories.</p></div>
              <div className="tlg-equipment-market-balance"><span>AVAILABLE</span><strong>{money(dashboard.balance)}</strong></div>
            </header>

            <div className="tlg-equipment-market-toolbar">
              <div className="tlg-equipment-category-tabs" role="tablist" aria-label="Market categories">
                <button type="button" className={marketFilter === 'all' ? 'active' : ''} onClick={() => setMarketFilter('all')}>All</button>
                {TYPE_ORDER.map((type) => <button key={type} type="button" className={marketFilter === type ? 'active' : ''} onClick={() => setMarketFilter(type)}>{TYPE_LABELS[type]}</button>)}
              </div>
              <label className="tlg-equipment-sort">
                <span>Sort</span>
                <select value={marketSort} onChange={(event) => setMarketSort(event.target.value as MarketSort)}>
                  <option value="featured">Featured</option>
                  <option value="price-low">Price: low to high</option>
                  <option value="price-high">Price: high to low</option>
                  <option value="tier-high">Quality: high first</option>
                  <option value="durability-high">Durability: high first</option>
                </select>
              </label>
            </div>

            {availableTags.length > 0 && (
              <div className="tlg-equipment-tag-filter" aria-label="Equipment tags">
                <button type="button" className={marketTag === 'all' ? 'active' : ''} onClick={() => setMarketTag('all')}>All tags</button>
                {availableTags.map((tag) => <button key={tag} type="button" className={marketTag === tag ? 'active' : ''} onClick={() => setMarketTag(tag)}>{tag.replaceAll('-', ' ')}</button>)}
              </div>
            )}

            <div className="tlg-equipment-market-grid">
              {marketItems.map((item) => {
                const owned = dashboard.inventory.filter((entry) => entry.item.id === item.id).length
                return (
                  <article className="tlg-equipment-market-card tlg-equipment-market-card-v2" key={item.id}>
                    <ProductImage item={item} large />
                    <div className="top"><span>{TYPE_LABELS[item.item_type]} · {TIER_LABELS[item.tier] ?? 'Tier'} {item.tier}</span><b className={`availability ${item.availability_status}`}>{availabilityLabel(item.availability_status)}</b></div>
                    <h3>{item.brand}</h3>
                    <strong className="model">{item.model}</strong>
                    <p>{item.description}</p>
                    <div className="tlg-equipment-card-tags">{(item.tags ?? []).slice(0, 3).map((tag) => <span key={tag}>{tag.replaceAll('-', ' ')}</span>)}</div>
                    <div className="tlg-equipment-card-quick"><span>{item.surface ? surfaceLabel(item.surface) : effectScopeLabel(item.effect_scope)}</span><span>Durability {item.durability}</span></div>
                    <div className="bottom"><div><strong>{money(item.price_usd)}</strong><span>{owned > 0 ? `${owned} owned` : 'Not owned'}</span></div><button type="button" onClick={() => setSelectedMarketItem(item)}>View details</button></div>
                  </article>
                )
              })}
            </div>
            {marketItems.length === 0 && <div className="tlg-equipment-empty-market">No {marketFilter === 'all' ? 'equipment' : TYPE_LABELS[marketFilter].toLowerCase()} items have been added to the catalogue yet.</div>}
          </section>
        )}

        {dashboard && tab === 'sponsors' && (
          <div className="tlg-equipment-sponsor-view">
            <section className="tlg-equipment-panel">
              <header className="tlg-equipment-panel-head">
                <div><span>TECHNICAL PARTNERS</span><h2>Equipment & clothing sponsors</h2><p>Sponsor-controlled equipment can use the same central catalogue and image data. The sponsor rename and expanded technical-sponsor functionality remain for the separate sponsor ticket.</p></div>
              </header>
              <div className="tlg-equipment-sponsor-grid">
                <SponsorSlot title="Racquet partner" sponsor={dashboard.loadout.racket_sponsor_name} current={dashboard.loadout.racket ? dashboard.loadout.racket.item.brand : 'No racquet'} detail="Future contracts can supply racquets and remove purchase costs." />
                <SponsorSlot title="Clothing partner" sponsor={dashboard.loadout.apparel_sponsor_name} current={dashboard.loadout.apparel_brand || 'Independent'} detail="All match clothing stays together as one Clothing equipment type." />
                <SponsorSlot title="Footwear partner" sponsor={dashboard.loadout.footwear_sponsor_name} current={dashboard.loadout.shoes ? dashboard.loadout.shoes.item.brand : 'No shoes'} detail="Future contracts can supply surface-specific shoes." />
              </div>
            </section>
          </div>
        )}
      </div>

      {dashboard && selectedMarketItem && <ItemDetailDialog item={selectedMarketItem} balance={dashboard.balance} equipped={getEquippedSlot(dashboard.loadout, selectedMarketItem.equip_slot)} onClose={() => setSelectedMarketItem(null)} onBuy={() => requestPurchase(selectedMarketItem)} />}

      {selectedInventoryItem && (
        <InventoryDetailDialog
          entry={selectedInventoryItem}
          busy={busy}
          onClose={() => setSelectedInventoryItem(null)}
          onEquip={() => void equipItem(selectedInventoryItem)}
          onSell={() => setPendingSale(selectedInventoryItem)}
        />
      )}

      {dashboard && pendingPurchase && (
        <GameConfirmDialog open eyebrow="Equipment purchase" title={`Buy ${pendingPurchase.item.brand} ${pendingPurchase.item.model}?`} message={<>This purchase will deduct <strong>{money(pendingPurchase.item.price_usd)}</strong> from Career Finance and add a new 100% condition item to Inventory.</>} detail={dashboard.balance >= pendingPurchase.item.price_usd ? <>Balance after purchase: <strong>{money(dashboard.balance - pendingPurchase.item.price_usd)}</strong></> : <>You currently have <strong>{money(dashboard.balance)}</strong>. This purchase requires {money(pendingPurchase.item.price_usd)}.</>} confirmLabel={dashboard.balance >= pendingPurchase.item.price_usd ? `Buy for ${money(pendingPurchase.item.price_usd)}` : 'Insufficient funds'} tone="neutral" busy={busy === `buy:${pendingPurchase.item.id}`} onCancel={() => { if (!busy) setPendingPurchase(null) }} onConfirm={() => { if (dashboard.balance >= pendingPurchase.item.price_usd) return buyItem() }} />
      )}

      {pendingSale && (
        <GameConfirmDialog open eyebrow="Equipment resale" title={`Sell ${pendingSale.item.brand} ${pendingSale.item.model}?`} message={<>Condition: <strong>{pendingSale.condition}% · {conditionLabel(pendingSale.condition)}</strong>. Equipped status: <strong>{pendingSale.is_equipped ? 'Currently equipped' : 'Not equipped'}</strong>. The item will be removed from Inventory after sale.</>} detail={<>Original recorded purchase price: {money(pendingSale.purchase_price_usd)} · Current estimated sale value: <strong>{money(pendingSale.resale_value_usd)}</strong>.</>} confirmLabel={`Sell for ${money(pendingSale.resale_value_usd)}`} tone="warning" busy={busy === `sell:${pendingSale.inventory_id}`} onCancel={() => { if (!busy) setPendingSale(null) }} onConfirm={sellItem} />
      )}
    </GameLayout>
  )
}

function ProductImage({ item, large = false }: { item: CatalogItem; large?: boolean }) {
  return <div className={`tlg-equipment-product-image${large ? ' large' : ''}`}>{item.image_url ? <img src={item.image_url} alt={`${item.brand} ${item.model}`} loading="lazy" /> : <span>{TYPE_LABELS[item.item_type]}</span>}</div>
}

function EquipmentSlot({ title, slot, detail }: { title: string; slot?: EquippedSlot | null; detail: string }) {
  if (!slot) return <article className="tlg-equipment-slot empty"><span>{title.toUpperCase()}</span><h3>Not equipped</h3><p>{detail}</p></article>
  return (
    <article className="tlg-equipment-slot tlg-equipment-slot-v2">
      <div className="tlg-equipment-slot-image"><ProductImage item={slot.item} /></div>
      <div className="slot-head"><span>{title.toUpperCase()}</span><b>{slot.condition}%</b></div>
      <h3>{slot.item.brand}</h3><strong>{slot.item.model}</strong><p>{detail}</p>
      <div className="condition-bar"><i style={{ width: `${slot.condition}%` }} /></div><small>{conditionLabel(slot.condition)} condition</small>
    </article>
  )
}

function ItemDetailDialog({ item, balance, equipped, onClose, onBuy }: { item: CatalogItem; balance: number; equipped?: EquippedSlot | null; onClose: () => void; onBuy: () => void }) {
  const canBuy = item.availability_status === 'available' && balance >= item.price_usd
  return (
    <div className="tlg-equipment-detail-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}>
      <section className="tlg-equipment-detail" role="dialog" aria-modal="true" aria-labelledby="equipment-detail-title">
        <button type="button" className="tlg-equipment-detail-close" onClick={onClose} aria-label="Close equipment details">×</button>
        <div className="tlg-equipment-detail-media"><ProductImage item={item} large /></div>
        <div className="tlg-equipment-detail-content">
          <div className="tlg-equipment-detail-kicker"><span>{TYPE_LABELS[item.item_type]}</span><b>{availabilityLabel(item.availability_status)}</b></div>
          <h2 id="equipment-detail-title">{item.brand} {item.model}</h2><p className="description">{item.description}</p>
          <div className="tlg-equipment-detail-price"><strong>{money(item.price_usd)}</strong><span>{TIER_LABELS[item.tier] ?? 'Tier'} · Tier {item.tier}</span></div>
          <div className="tlg-equipment-detail-tags">{(item.tags ?? []).map((tag) => <span key={tag}>{tag.replaceAll('-', ' ')}</span>)}</div>
          <div className="tlg-equipment-detail-stats">{mainStats(item).map(([name, value]) => <div key={name}><span>{name}</span><strong>{value}</strong><div><i style={{ width: `${value}%` }} /></div></div>)}</div>
          <div className="tlg-equipment-detail-columns">
            <div className="positive"><h3>Benefits</h3>{item.advantages?.length ? <ul>{item.advantages.map((value) => <li key={value}>{value}</li>)}</ul> : <p>No special advantages defined.</p>}</div>
            <div className="negative"><h3>Trade-offs</h3>{item.disadvantages?.length ? <ul>{item.disadvantages.map((value) => <li key={value}>{value}</li>)}</ul> : <p>No special trade-offs defined.</p>}</div>
          </div>
          <dl className="tlg-equipment-detail-meta"><div><dt>Gameplay scope</dt><dd>{effectScopeLabel(item.effect_scope)}</dd></div><div><dt>Surface</dt><dd>{item.surface ? surfaceLabel(item.surface) : 'Not surface-specific'}</dd></div><div><dt>Expected lifespan</dt><dd>{item.lifespan_text || 'Defined by condition and use.'}</dd></div><div><dt>Maintenance</dt><dd>{item.maintenance_text || 'No special maintenance requirement.'}</dd></div></dl>
          {equipped && <div className="tlg-equipment-current-compare"><span>CURRENTLY EQUIPPED</span><strong>{equipped.item.brand} {equipped.item.model}</strong><small>{equipped.condition}% condition · {equipped.item.id === item.id ? 'Same equipment definition' : 'Compare the stat bars before buying'}</small></div>}
          <div className="tlg-equipment-detail-actions"><button type="button" className="secondary" onClick={onClose}>Close</button><button type="button" disabled={!canBuy} onClick={onBuy}>{item.availability_status !== 'available' ? availabilityLabel(item.availability_status) : balance < item.price_usd ? 'Insufficient funds' : `Buy for ${money(item.price_usd)}`}</button></div>
        </div>
      </section>
    </div>
  )
}

function InventoryDetailDialog({ entry, busy, onClose, onEquip, onSell }: { entry: InventoryItem; busy: string | null; onClose: () => void; onEquip: () => void; onSell: () => void }) {
  const equippable = Boolean(entry.item.equip_slot)
  return (
    <div className="tlg-equipment-detail-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}>
      <section className="tlg-equipment-detail tlg-equipment-inventory-detail" role="dialog" aria-modal="true" aria-labelledby="inventory-detail-title">
        <button type="button" className="tlg-equipment-detail-close" onClick={onClose} aria-label="Close inventory details">×</button>
        <div className="tlg-equipment-detail-media"><ProductImage item={entry.item} large /></div>
        <div className="tlg-equipment-detail-content">
          <div className="tlg-equipment-detail-kicker"><span>{TYPE_LABELS[entry.item.item_type]}</span><b>{entry.is_equipped ? 'Currently equipped' : 'In Inventory'}</b></div>
          <h2 id="inventory-detail-title">{entry.item.brand} {entry.item.model}</h2><p className="description">{entry.item.description}</p>
          <div className="tlg-equipment-inventory-condition-hero"><div><span>CURRENT CONDITION</span><strong>{entry.condition}%</strong><small>{conditionLabel(entry.condition)}</small></div><div className="tlg-equipment-condition-track"><i style={{ width: `${entry.condition}%` }} /></div></div>
          <div className="tlg-equipment-detail-tags">{(entry.item.tags ?? []).map((tag) => <span key={tag}>{tag.replaceAll('-', ' ')}</span>)}</div>
          <div className="tlg-equipment-detail-stats">{mainStats(entry.item).map(([name, value]) => <div key={name}><span>{name}</span><strong>{value}</strong><div><i style={{ width: `${value}%` }} /></div></div>)}</div>
          <div className="tlg-equipment-detail-columns">
            <div className="positive"><h3>Main benefits</h3>{entry.item.advantages?.length ? <ul>{entry.item.advantages.map((value) => <li key={value}>{value}</li>)}</ul> : <p>No special advantages defined.</p>}</div>
            <div className="negative"><h3>Main disadvantages</h3>{entry.item.disadvantages?.length ? <ul>{entry.item.disadvantages.map((value) => <li key={value}>{value}</li>)}</ul> : <p>No special trade-offs defined.</p>}</div>
          </div>
          <dl className="tlg-equipment-detail-meta">
            <div><dt>Quality</dt><dd>{TIER_LABELS[entry.item.tier] ?? 'Tier'} · Tier {entry.item.tier}</dd></div>
            <div><dt>Remaining durability</dt><dd>{entry.condition}% current condition · Base durability rating {entry.item.durability}</dd></div>
            <div><dt>Gameplay scope</dt><dd>{entry.is_equipped ? `${effectScopeLabel(entry.item.effect_scope)} · active from this equipped item where supported` : `${effectScopeLabel(entry.item.effect_scope)} · inactive while unequipped`}</dd></div>
            <div><dt>Surface</dt><dd>{entry.item.surface ? surfaceLabel(entry.item.surface) : 'Not surface-specific'}</dd></div>
            <div><dt>Maintenance</dt><dd>{entry.item.maintenance_text || 'No maintenance action is currently supported for this item.'}</dd></div>
            <div><dt>Expected lifespan</dt><dd>{entry.item.lifespan_text || 'Defined by condition and use.'}</dd></div>
            <div><dt>Acquired</dt><dd>{acquisitionLabel(entry)}</dd></div>
            <div><dt>Original purchase value</dt><dd>{entry.purchase_price_usd > 0 ? money(entry.purchase_price_usd) : 'No purchase cost recorded'}</dd></div>
            <div><dt>Current resale value</dt><dd>{entry.resell_supported ? money(entry.resale_value_usd) : entry.sell_block_reason ?? 'Not resellable'}</dd></div>
          </dl>
          {entry.is_equipped && <div className="tlg-equipment-current-compare"><span>GEAR ROOM STATUS</span><strong>This item is currently equipped.</strong><small>Its current condition is already reflected by the authoritative equipment-effect calculation.</small></div>}
          <div className="tlg-equipment-detail-actions tlg-equipment-inventory-detail-actions">
            <button type="button" className="secondary" onClick={onClose}>Close</button>
            {equippable && <button type="button" disabled={entry.is_equipped || busy === `equip:${entry.inventory_id}`} onClick={onEquip}>{entry.is_equipped ? 'Equipped' : busy === `equip:${entry.inventory_id}` ? 'Equipping…' : 'Equip'}</button>}
            <button type="button" className="danger" disabled={!entry.can_sell || busy === `sell:${entry.inventory_id}`} title={entry.sell_block_reason ?? `Sell for ${money(entry.resale_value_usd)}`} onClick={onSell}>{entry.can_sell ? `Sell ${money(entry.resale_value_usd)}` : entry.is_equipped && entry.resell_supported ? 'Replace before selling' : 'Not sellable'}</button>
          </div>
        </div>
      </section>
    </div>
  )
}

function Effect({ name, value }: { name: string; value: number }) {
  return <div><span>{name}</span><strong className={value > 0 ? 'positive' : value < 0 ? 'negative' : ''}>{pct(value)}</strong></div>
}

function SponsorSlot({ title, sponsor, current, detail }: { title: string; sponsor?: string | null; current: string; detail: string }) {
  return <article><span>{title.toUpperCase()}</span><strong>{sponsor || 'Independent'}</strong><small>Current gear: {current}</small><p>{detail}</p><b>{sponsor ? 'Contract active' : 'Self-funded'}</b></article>
}
