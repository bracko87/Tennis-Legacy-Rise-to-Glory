import { useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router'

import GameConfirmDialog from '../../components/common/GameConfirmDialog'
import TechnicalSponsorsPanel from '../../components/equipment/TechnicalSponsorsPanel'
import GameLayout from '../../components/layout/GameLayout'
import { lockBodyScroll } from '../../lib/bodyScrollLock'
import { supabase } from '../../lib/supabase'
import '../../styles/equipment.css'
import '../../styles/equipment-marketplace-v2.css'
import '../../styles/equipment-technical-sponsor.css'

type EquipmentTab = 'gear' | 'inventory' | 'market' | 'sponsors'
type EquipmentType = 'racket' | 'shoes' | 'apparel' | 'accessory'
type EquipSlot = 'racket' | 'shoes' | 'apparel' | 'accessory'
type AccessoryKind = 'bag' | 'bottle' | 'cap' | 'towel' | 'wristband'
type CourtSurface = 'hard' | 'clay' | 'grass'
type MarketFilter = 'all' | EquipmentType
type MarketSort = 'featured' | 'price-low' | 'price-high' | 'tier-high' | 'durability-high'
type InventoryFilter = 'all' | EquipmentType
type InventorySort = 'recent' | 'condition-high' | 'condition-low' | 'tier-high' | 'value-high'
type SponsorTier = 'entry' | 'established' | 'premium' | 'elite'
type EffectMap = Record<string, number>

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
  technical_brand_id?: string | null
  technical_brand_code?: string | null
  technical_brand_tier?: SponsorTier | null
  brand_logo_url?: string | null
  product_profile?: string | null
  gameplay_effects?: EffectMap | null
  effective_gameplay_effects?: EffectMap | null
  wear_per_match?: number | null
  wrong_surface_wear_multiplier?: number | null
  weather_profile?: string | null
  accessory_kind?: AccessoryKind | null
  estimated_uses?: number | null
  technical_sponsor_contract_id?: string | null
  technical_sponsor_discount_pct?: number | null
  sponsor_final_price_usd?: number | null
  sponsor_free_equipment_remaining?: number | null
  sponsor_free_claim_available?: boolean
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
  sponsor_replacements_remaining?: number
  sponsor_replacement_available?: boolean
  item: CatalogItem
}

interface EquippedSlot {
  inventory_id: string
  condition: number
  item: CatalogItem
}

interface EquippedAccessory extends EquippedSlot {
  accessory_kind: AccessoryKind
}

interface EquipmentLoadout {
  racket?: EquippedSlot | null
  shoes?: EquippedSlot | null
  apparel?: EquippedSlot | null
  accessories?: EquippedAccessory[]
  apparel_brand?: string | null
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
  serve_pct: number
  return_pct: number
  rally_pct: number
  net_pct: number
  stamina_pct: number
  focus_pct: number
  heat_resistance_pct: number
  cold_resistance_pct: number
  racket_wear_reduction_pct: number
  racket_condition: number
  shoes_condition: number
  apparel_condition: number
  accessory_count: number
  shoe_surface: string
}

interface WearRules {
  racket_default: number
  shoes_surface_specific: number
  shoes_all_court: number
  shoes_wrong_surface: number
  apparel_typical: number
  accessory_profiles: Record<AccessoryKind, number>
  condition_precision: number
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
  wear_rules: WearRules
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
const ACCESSORY_ORDER: AccessoryKind[] = ['bag', 'bottle', 'cap', 'towel', 'wristband']

const TIER_LABELS: Record<number, string> = {
  1: 'Starter',
  2: 'Advanced',
  3: 'Tour',
  4: 'Elite',
  5: 'Legend',
}

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

function money(value: number) {
  return `$${Math.round(Number(value) || 0).toLocaleString()}`
}

function pct(value: number) {
  const numeric = Number(value) || 0
  if (Math.abs(numeric) < 0.005) return '±0.00%'
  return `${numeric > 0 ? '+' : ''}${numeric.toFixed(2)}%`
}

function conditionText(value: number) {
  const numeric = Number(value) || 0
  return Number.isInteger(numeric) ? `${numeric}%` : `${numeric.toFixed(2).replace(/0+$/, '').replace(/\.$/, '')}%`
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

function titleCase(value: string) {
  return value.replaceAll('-', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function sponsorTierLabel(tier: SponsorTier) {
  if (tier === 'elite') return 'Elite / Global'
  return titleCase(tier)
}

function playerPrice(item: CatalogItem) {
  const sponsorPrice = Number(item.sponsor_final_price_usd)
  return Number.isFinite(sponsorPrice) && sponsorPrice > 0 ? sponsorPrice : Number(item.price_usd) || 0
}

function sponsorDiscount(item: CatalogItem) {
  return Math.max(0, Number(item.technical_sponsor_discount_pct) || 0)
}

function mainStats(item: CatalogItem) {
  if (item.item_type === 'shoes') return [['Traction', item.traction], ['Stability', item.stability], ['Comfort', item.comfort], ['Durability', item.durability]] as const
  if (item.item_type === 'racket') return [['Power', item.power], ['Control', item.control], ['Spin', item.spin], ['Comfort', item.comfort]] as const
  return [['Comfort', item.comfort], ['Durability', item.durability]] as const
}

function activeEffects(item: CatalogItem, owned = false) {
  const source = owned ? item.effective_gameplay_effects ?? item.gameplay_effects : item.gameplay_effects
  return Object.entries(source ?? {})
    .filter(([, value]) => Number.isFinite(Number(value)) && Math.abs(Number(value)) >= 0.005)
    .sort((a, b) => Math.abs(Number(b[1])) - Math.abs(Number(a[1])))
}

function getComparableSlot(loadout: EquipmentLoadout, item: CatalogItem) {
  if (item.item_type === 'racket') return loadout.racket
  if (item.item_type === 'shoes') return loadout.shoes
  if (item.item_type === 'apparel') return loadout.apparel
  if (item.item_type === 'accessory' && item.accessory_kind) return (loadout.accessories ?? []).find((entry) => entry.accessory_kind === item.accessory_kind) ?? null
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
  const [searchParams] = useSearchParams()
  const requestedTab = searchParams.get('tab')
  const [tab, setTab] = useState<EquipmentTab>(() => (
    requestedTab === 'gear' || requestedTab === 'inventory' || requestedTab === 'market' || requestedTab === 'sponsors'
      ? requestedTab
      : 'gear'
  ))
  const [dashboard, setDashboard] = useState<EquipmentDashboard | null>(null)
  const [surface, setSurface] = useState<CourtSurface>('hard')
  const [marketFilter, setMarketFilter] = useState<MarketFilter>('all')
  const [marketTag, setMarketTag] = useState('all')
  const [marketSort, setMarketSort] = useState<MarketSort>('featured')
  const [inventoryFilter, setInventoryFilter] = useState<InventoryFilter>('all')

  useEffect(() => {
    if (requestedTab === 'gear' || requestedTab === 'inventory' || requestedTab === 'market' || requestedTab === 'sponsors') {
      setTab(requestedTab)
    }
  }, [requestedTab])
  const [inventorySort, setInventorySort] = useState<InventorySort>('recent')
  const [selectedMarketItem, setSelectedMarketItem] = useState<CatalogItem | null>(null)
  const [selectedInventoryItem, setSelectedInventoryItem] = useState<InventoryItem | null>(null)
  const [pendingPurchase, setPendingPurchase] = useState<PendingPurchase | null>(null)
  const [pendingSale, setPendingSale] = useState<InventoryItem | null>(null)
  const [pendingDiscard, setPendingDiscard] = useState<InventoryItem | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)

  async function loadEquipment() {
    setLoading(true)
    setError(null)
    const { data, error: loadError } = await supabase.rpc('get_equipment_dashboard_v1')
    if (loadError || !data) setError(loadError?.message ?? 'Unable to load equipment.')
    else setDashboard(data as EquipmentDashboard)
    setLoading(false)
  }

  useEffect(() => { void loadEquipment() }, [])
  useEffect(() => { setMarketTag('all') }, [marketFilter])

  useEffect(() => {
    if (!selectedMarketItem && !selectedInventoryItem) return
    const unlockBodyScroll = lockBodyScroll()
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key !== 'Escape' || pendingPurchase || pendingSale || pendingDiscard) return
      setSelectedMarketItem(null)
      setSelectedInventoryItem(null)
    }
    window.addEventListener('keydown', closeOnEscape)
    return () => {
      window.removeEventListener('keydown', closeOnEscape)
      unlockBodyScroll()
    }
  }, [selectedMarketItem, selectedInventoryItem, pendingPurchase, pendingSale, pendingDiscard])

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
    const { data, error: purchaseError } = await supabase.rpc('purchase_equipment_item_v2', { p_catalog_item_id: item.id, p_request_key: requestKey })
    if (purchaseError) setError(purchaseError.message)
    else {
      const paid = Number((data as { price_usd?: number } | null)?.price_usd ?? playerPrice(item))
      setMessage(`${item.brand} ${item.model} purchased for ${money(paid)} and added to Inventory.`)
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
    const { error: saleError } = await supabase.rpc('sell_equipment_item_v1', { p_inventory_id: item.inventory_id })
    if (saleError) setError(saleError.message)
    else {
      setMessage(`${item.item.brand} ${item.item.model} sold for ${money(item.resale_value_usd)}.`)
      setPendingSale(null)
      setSelectedInventoryItem(null)
      await loadEquipment()
    }
    setBusy(null)
  }

  async function discardItem() {
    if (!pendingDiscard) return
    const item = pendingDiscard
    setBusy(`discard:${item.inventory_id}`)
    setError(null)
    setMessage(null)
    const { error: discardError } = await supabase.rpc('discard_equipment_item_v1', { p_inventory_id: item.inventory_id })
    if (discardError) setError(discardError.message)
    else {
      setMessage(`${item.item.brand} ${item.item.model} was discarded from Inventory.`)
      setPendingDiscard(null)
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
      const suffix = item.item.item_type === 'accessory' && item.item.accessory_kind ? ` (${titleCase(item.item.accessory_kind)} slot)` : ''
      setMessage(`${item.item.brand} ${item.item.model} is now equipped${suffix}.`)
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

  const availableTags = useMemo(
    () => marketFilter === 'accessory' ? ACCESSORY_ORDER : [],
    [marketFilter],
  )

  const marketItems = useMemo(() => {
    const items = (dashboard?.catalog ?? [])
      .filter((item) => marketFilter === 'all' || item.item_type === marketFilter)
      .filter((item) => {
        if (marketTag === 'all') return true
        if (marketFilter === 'accessory') return item.accessory_kind === marketTag
        return true
      })
    return [...items].sort((a, b) => {
      if (marketSort === 'price-low') return playerPrice(a) - playerPrice(b)
      if (marketSort === 'price-high') return playerPrice(b) - playerPrice(a)
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

  if (loading && !dashboard) return <GameLayout title="Equipment" subtitle="Racquets, shoes, clothing and accessories"><div className="tlg-equipment-state">Loading Equipment Center…</div></GameLayout>

  const effects = dashboard?.effects?.[surface]

  return (
    <GameLayout title="Equipment" subtitle="Racquets, shoes, clothing and accessories">
      <div className="tlg-equipment-page">
        <section className="tlg-equipment-hero"><div className="tlg-equipment-hero-copy"><span>EQUIPMENT</span><h1>Equipment Center</h1><p>Build your match setup, manage owned gear, shop the professional market and negotiate technical sponsorships.</p></div></section>

        <div className="tlg-equipment-tabs" role="tablist" aria-label="Equipment sections"><button type="button" className={tab === 'gear' ? 'active' : ''} onClick={() => setTab('gear')}>Gear Room</button><button type="button" className={tab === 'inventory' ? 'active' : ''} onClick={() => setTab('inventory')}>Inventory</button><button type="button" className={tab === 'market' ? 'active' : ''} onClick={() => setTab('market')}>Market</button><button type="button" className={tab === 'sponsors' ? 'active' : ''} onClick={() => setTab('sponsors')}>Technical Sponsors</button></div>

        {error && <div className="tlg-equipment-alert error">{error}</div>}
        {message && <div className="tlg-equipment-alert">{message}</div>}

        {dashboard && <section className="tlg-equipment-summary-strip tlg-equipment-summary-strip-v3"><div><span>CAREER CASH</span><strong>{money(dashboard.balance)}</strong><small>Equipment purchases use Career Finance</small></div><div><span>RACQUET</span><strong>{dashboard.loadout.racket ? `${dashboard.loadout.racket.item.brand} ${dashboard.loadout.racket.item.model}` : 'Not equipped'}</strong><small>{dashboard.loadout.racket ? `${conditionText(dashboard.loadout.racket.condition)} condition` : 'Choose from Inventory'}</small></div><div><span>SHOES</span><strong>{dashboard.loadout.shoes ? `${dashboard.loadout.shoes.item.brand} ${dashboard.loadout.shoes.item.model}` : 'Not equipped'}</strong><small>{dashboard.loadout.shoes ? `${conditionText(dashboard.loadout.shoes.condition)} · ${surfaceLabel(dashboard.loadout.shoes.item.surface)}` : 'Choose from Inventory'}</small></div><div><span>CLOTHING</span><strong>{dashboard.loadout.apparel ? `${dashboard.loadout.apparel.item.brand} ${dashboard.loadout.apparel.item.model}` : 'Not equipped'}</strong><small>{dashboard.loadout.apparel ? `${conditionText(dashboard.loadout.apparel.condition)} condition` : 'Choose from Inventory'}</small></div></section>}

        {dashboard && tab === 'gear' && <div className="tlg-equipment-gear-view">
          <section className="tlg-equipment-panel"><header className="tlg-equipment-panel-head"><div><span>CURRENT MATCH SETUP</span><h2>Your gear room</h2><p>Racquet, shoes and clothing use one active slot each. Accessories use one active slot per accessory kind.</p></div><button type="button" className="tlg-equipment-panel-link" onClick={() => setTab('inventory')}>Open Inventory</button></header><div className="tlg-equipment-slot-grid tlg-equipment-slot-grid-three"><EquipmentSlot title="Racquet" slot={dashboard.loadout.racket} detail="Power · control · spin · style profile" /><EquipmentSlot title="Shoes" slot={dashboard.loadout.shoes} detail={dashboard.loadout.shoes ? `${surfaceLabel(dashboard.loadout.shoes.item.surface)} · ${dashboard.loadout.shoes.item.product_profile ?? 'footwear'}` : 'Surface-specific footwear'} /><EquipmentSlot title="Clothing" slot={dashboard.loadout.apparel} detail={dashboard.loadout.apparel ? `${titleCase(dashboard.loadout.apparel.item.product_profile ?? 'balanced')} · ${titleCase(dashboard.loadout.apparel.item.weather_profile ?? 'all')} weather` : 'Unified match clothing'} /></div><div className="tlg-equipment-accessory-loadout"><div className="tlg-equipment-accessory-loadout-head"><span>ACTIVE ACCESSORIES</span><b>{dashboard.loadout.accessories?.length ?? 0} / {ACCESSORY_ORDER.length} kinds</b></div>{(dashboard.loadout.accessories?.length ?? 0) > 0 ? <div className="tlg-equipment-accessory-slot-grid">{(dashboard.loadout.accessories ?? []).map((entry) => <EquipmentSlot key={entry.accessory_kind} title={titleCase(entry.accessory_kind)} slot={entry} detail={`${entry.item.brand} · ${entry.item.wear_per_match ?? 0}% wear / match`} compact />)}</div> : <p className="tlg-equipment-accessory-empty">No accessories equipped yet. Equip them from Inventory.</p>}</div></section>
          <section className="tlg-equipment-panel"><header className="tlg-equipment-panel-head compact"><div><span>MATCH PROFILE</span><h2>Authoritative equipment effect</h2><p>Current modifiers include racquet, footwear, clothing, accessory condition and court-surface matching.</p></div><div className="tlg-equipment-surface-switch">{(['hard', 'clay', 'grass'] as CourtSurface[]).map((value) => <button key={value} type="button" className={surface === value ? 'active' : ''} onClick={() => setSurface(value)}>{titleCase(value)}</button>)}</div></header>{effects && <div className="tlg-equipment-effects-grid tlg-equipment-effects-grid-expanded"><Effect name="Power" value={effects.power_pct} /><Effect name="Control" value={effects.control_pct} /><Effect name="Spin" value={effects.spin_pct} /><Effect name="Movement" value={effects.movement_pct} /><Effect name="Comfort" value={effects.comfort_pct} /><Effect name="Serve" value={effects.serve_pct} /><Effect name="Return" value={effects.return_pct} /><Effect name="Rally" value={effects.rally_pct} /><Effect name="Net" value={effects.net_pct} /><Effect name="Stamina" value={effects.stamina_pct} /><Effect name="Focus" value={effects.focus_pct} /><Effect name="Racquet protection" value={effects.racket_wear_reduction_pct} /></div>}</section>
          <section className="tlg-equipment-wear-note tlg-equipment-wear-note-v3"><div><span>RACQUET WEAR</span><strong>about −{dashboard.wear_rules.racket_default}% / match</strong></div><div><span>SHOE WEAR</span><strong>−{dashboard.wear_rules.shoes_surface_specific}% to −{dashboard.wear_rules.shoes_wrong_surface}%</strong></div><div><span>CLOTHING WEAR</span><strong>about −{dashboard.wear_rules.apparel_typical}% / match</strong></div><div><span>ACCESSORIES</span><strong>−{Math.min(...Object.values(dashboard.wear_rules.accessory_profiles))}% to −{Math.max(...Object.values(dashboard.wear_rules.accessory_profiles))}%</strong></div><p>Condition is stored to {dashboard.wear_rules.condition_precision}% precision. Bonuses automatically weaken as condition falls.</p></section>
        </div>}

        {dashboard && tab === 'inventory' && <section className="tlg-equipment-panel tlg-equipment-inventory-panel-v3"><header className="tlg-equipment-panel-head market-head"><div><span>OWNED EQUIPMENT</span><h2>Inventory</h2><p>Inspect condition-adjusted bonuses, brand identity, durability and resale value.</p></div><div className="tlg-equipment-market-balance"><span>OWNED ITEMS</span><strong>{dashboard.inventory.length}</strong></div></header><div className="tlg-equipment-market-toolbar tlg-equipment-inventory-toolbar"><div className="tlg-equipment-category-tabs" role="tablist" aria-label="Inventory categories"><button type="button" className={inventoryFilter === 'all' ? 'active' : ''} onClick={() => setInventoryFilter('all')}>All <small>{dashboard.inventory.length}</small></button>{TYPE_ORDER.map((type) => <button key={type} type="button" className={inventoryFilter === type ? 'active' : ''} onClick={() => setInventoryFilter(type)}>{TYPE_LABELS[type]} <small>{inventoryCounts[type]}</small></button>)}</div><label className="tlg-equipment-sort"><span>Sort</span><select value={inventorySort} onChange={(event) => setInventorySort(event.target.value as InventorySort)}><option value="recent">Recently acquired</option><option value="condition-high">Condition: high first</option><option value="condition-low">Condition: low first</option><option value="tier-high">Quality: high first</option><option value="value-high">Resale value: high first</option></select></label></div>{inventoryItems.length > 0 ? <div className="tlg-equipment-inventory-card-grid">{inventoryItems.map((entry) => <article className={`tlg-equipment-owned-card${entry.is_equipped ? ' equipped' : ''}`} key={entry.inventory_id}><ProductImage item={entry.item} large /><div className="tlg-equipment-owned-card-body"><BrandIdentity item={entry.item} /><div className="tlg-equipment-owned-card-top"><span>{TYPE_LABELS[entry.item.item_type]} · {entry.item.product_profile ? titleCase(entry.item.product_profile) : TIER_LABELS[entry.item.tier]}</span><b>{entry.is_equipped ? 'Equipped' : 'Owned'}</b></div><h3>{entry.item.brand} {entry.item.model}</h3><p>{entry.item.description}</p><div className="tlg-equipment-owned-condition"><div><span>Condition</span><strong>{conditionText(entry.condition)} · {conditionLabel(entry.condition)}</strong></div><div className="tlg-equipment-condition-track"><i style={{ width: `${Math.max(0, Math.min(100, entry.condition))}%` }} /></div></div><div className="tlg-equipment-owned-facts"><span>Wear / match <b>{entry.item.wear_per_match ?? '—'}%</b></span><span>Resale <b>{entry.resell_supported ? money(entry.resale_value_usd) : 'Not supported'}</b></span></div><EffectChips effects={activeEffects(entry.item, true)} limit={3} /><div className="tlg-equipment-owned-card-actions"><button type="button" className="secondary" onClick={() => setSelectedInventoryItem(entry)}>View details</button><button type="button" disabled={entry.is_equipped || busy === `equip:${entry.inventory_id}`} onClick={() => void equipItem(entry)}>{entry.is_equipped ? 'Equipped' : busy === `equip:${entry.inventory_id}` ? 'Equipping…' : 'Equip'}</button></div></div></article>)}</div> : <div className="tlg-equipment-inventory-empty"><h3>{inventoryFilter === 'all' ? 'Your inventory is empty.' : `No ${TYPE_LABELS[inventoryFilter].toLowerCase()} in your inventory.`}</h3><p>Visit the Equipment Market to purchase equipment for this category.</p><button type="button" onClick={() => visitMarket(inventoryFilter)}>Visit Market</button></div>}</section>}

        {dashboard && tab === 'market' && <section className="tlg-equipment-panel tlg-equipment-market-panel"><header className="tlg-equipment-panel-head market-head"><div><span>EQUIPMENT MARKET</span><h2>Brand-linked professional equipment</h2><p>Active technical sponsor benefits are applied automatically to matching Clothing, Shoes and Racquets. Accessories always use normal pricing.</p></div><div className="tlg-equipment-market-balance"><span>AVAILABLE</span><strong>{money(dashboard.balance)}</strong></div></header><div className="tlg-equipment-market-toolbar"><div className="tlg-equipment-category-tabs" role="tablist" aria-label="Market categories"><button type="button" className={marketFilter === 'all' ? 'active' : ''} onClick={() => setMarketFilter('all')}>All</button>{TYPE_ORDER.map((type) => <button key={type} type="button" className={marketFilter === type ? 'active' : ''} onClick={() => setMarketFilter(type)}>{TYPE_LABELS[type]}</button>)}</div><label className="tlg-equipment-sort"><span>Sort</span><select value={marketSort} onChange={(event) => setMarketSort(event.target.value as MarketSort)}><option value="featured">Featured</option><option value="price-low">Player price: low to high</option><option value="price-high">Player price: high to low</option><option value="tier-high">Quality: high first</option><option value="durability-high">Durability: high first</option></select></label></div>{availableTags.length > 0 && <div className="tlg-equipment-tag-filter" aria-label="Accessory categories"><button type="button" className={marketTag === 'all' ? 'active' : ''} onClick={() => setMarketTag('all')}>All accessories</button>{availableTags.map((tag) => <button key={tag} type="button" className={marketTag === tag ? 'active' : ''} onClick={() => setMarketTag(tag)}>{titleCase(tag)}</button>)}</div>}<div className="tlg-equipment-market-grid">{marketItems.map((item) => { const owned = dashboard.inventory.filter((entry) => entry.item.id === item.id).length; const discount = sponsorDiscount(item); return <article className={`tlg-equipment-market-card tlg-equipment-market-card-v2${discount > 0 ? ' sponsor-priced' : ''}`} key={item.id}><ProductImage item={item} large /><BrandIdentity item={item} /><div className="top"><span>{TYPE_LABELS[item.item_type]} · {item.product_profile ? titleCase(item.product_profile) : `${TIER_LABELS[item.tier]} ${item.tier}`}</span><b className={`availability ${item.availability_status}`}>{availabilityLabel(item.availability_status)}</b></div><h3>{item.brand}</h3><strong className="model">{item.model}</strong><p>{item.description}</p><EffectChips effects={activeEffects(item)} limit={3} /><div className="tlg-equipment-card-quick"><span>{item.surface ? surfaceLabel(item.surface) : item.weather_profile ? `${titleCase(item.weather_profile)} weather` : effectScopeLabel(item.effect_scope)}</span><span>Wear {item.wear_per_match ?? '—'}% / match</span></div>{discount > 0 && <div className="tlg-equipment-sponsor-price-badge"><strong>SPONSOR DISCOUNT</strong><span>−{discount}%</span></div>}<div className="bottom"><div className="tlg-equipment-market-price-stack">{discount > 0 && <span className="tlg-equipment-list-price">Normal {money(item.price_usd)}</span>}<strong className={discount > 0 ? 'tlg-equipment-sponsor-final-price' : ''}>{money(playerPrice(item))}</strong>{discount > 0 && <span className="tlg-equipment-sponsor-saving">You save {money(Math.max(0, item.price_usd - playerPrice(item)))}</span>}<span>{owned > 0 ? `${owned} owned` : `${item.estimated_uses ?? '—'} est. uses`}</span></div><div className="tlg-equipment-market-card-buttons"><button type="button" className="secondary" onClick={() => setSelectedMarketItem(item)}>View details</button><button type="button" className="buy" disabled={item.availability_status !== 'available' || dashboard.balance < playerPrice(item)} onClick={() => requestPurchase(item)}>{item.availability_status !== 'available' ? availabilityLabel(item.availability_status) : dashboard.balance < playerPrice(item) ? 'Buy' : 'Buy'}</button></div></div></article> })}</div>{marketItems.length === 0 && <div className="tlg-equipment-empty-market">No matching equipment is available.</div>}</section>}

        {tab === 'sponsors' && <TechnicalSponsorsPanel onChanged={loadEquipment} />}
      </div>

      {dashboard && selectedMarketItem && <ItemDetailDialog item={selectedMarketItem} balance={dashboard.balance} equipped={getComparableSlot(dashboard.loadout, selectedMarketItem)} onClose={() => setSelectedMarketItem(null)} onBuy={() => requestPurchase(selectedMarketItem)} />}
      {selectedInventoryItem && <InventoryDetailDialog entry={selectedInventoryItem} busy={busy} onClose={() => setSelectedInventoryItem(null)} onSell={() => setPendingSale(selectedInventoryItem)} onDiscard={() => setPendingDiscard(selectedInventoryItem)} />}

      {dashboard && pendingPurchase && <GameConfirmDialog open eyebrow="Equipment purchase" title={`Buy ${pendingPurchase.item.brand} ${pendingPurchase.item.model}?`} message={<>This purchase will deduct <strong>{money(playerPrice(pendingPurchase.item))}</strong> from Career Finance and add a new 100% condition item to Inventory.</>} detail={sponsorDiscount(pendingPurchase.item) > 0 ? <>Normal price: {money(pendingPurchase.item.price_usd)} · Technical sponsor discount: <strong>−{sponsorDiscount(pendingPurchase.item)}%</strong> · Balance after purchase: <strong>{money(dashboard.balance - playerPrice(pendingPurchase.item))}</strong></> : dashboard.balance >= playerPrice(pendingPurchase.item) ? <>Balance after purchase: <strong>{money(dashboard.balance - playerPrice(pendingPurchase.item))}</strong></> : <>You currently have <strong>{money(dashboard.balance)}</strong>.</>} confirmLabel={dashboard.balance >= playerPrice(pendingPurchase.item) ? `Buy for ${money(playerPrice(pendingPurchase.item))}` : 'Insufficient funds'} tone="neutral" busy={busy === `buy:${pendingPurchase.item.id}`} onCancel={() => { if (!busy) setPendingPurchase(null) }} onConfirm={() => { if (dashboard.balance >= playerPrice(pendingPurchase.item)) return buyItem() }} />}
      {pendingDiscard && <GameConfirmDialog open eyebrow="Discard equipment" title={`Discard ${pendingDiscard.item.brand} ${pendingDiscard.item.model}?`} message={<>This permanently removes the item from Inventory. You will receive <strong>$0</strong>.</>} detail={pendingDiscard.is_equipped ? <>This item is currently equipped. Equip a replacement before discarding it.</> : <>Condition: <strong>{conditionText(pendingDiscard.condition)}</strong>. Purchased equipment can be discarded even when it has no resale value.</>} confirmLabel={pendingDiscard.is_equipped ? 'Replace before discarding' : 'Discard permanently'} tone="warning" busy={busy === `discard:${pendingDiscard.inventory_id}`} onCancel={() => { if (!busy) setPendingDiscard(null) }} onConfirm={() => { if (!pendingDiscard.is_equipped) return discardItem() }} />}
      {pendingSale && <GameConfirmDialog open eyebrow="Equipment resale" title={`Sell ${pendingSale.item.brand} ${pendingSale.item.model}?`} message={<>Condition: <strong>{conditionText(pendingSale.condition)} · {conditionLabel(pendingSale.condition)}</strong>. Equipped status: <strong>{pendingSale.is_equipped ? 'Currently equipped' : 'Not equipped'}</strong>. The item will be removed from Inventory after sale.</>} detail={<>Original recorded purchase price: {money(pendingSale.purchase_price_usd)} · Current estimated sale value: <strong>{money(pendingSale.resale_value_usd)}</strong>.</>} confirmLabel={`Sell for ${money(pendingSale.resale_value_usd)}`} tone="warning" busy={busy === `sell:${pendingSale.inventory_id}`} onCancel={() => { if (!busy) setPendingSale(null) }} onConfirm={sellItem} />}
    </GameLayout>
  )
}

function ProductImage({ item, large = false }: { item: CatalogItem; large?: boolean }) {
  const typeClass = item.item_type === 'shoes'
    ? ' is-shoes'
    : item.item_type === 'racket'
      ? ' is-racket'
      : item.item_type === 'accessory' && item.accessory_kind === 'bag'
        ? ' is-bag'
        : item.item_type === 'accessory' && item.accessory_kind === 'towel'
          ? ' is-towel'
          : item.item_type === 'accessory' && item.accessory_kind === 'cap'
            ? ' is-cap'
            : item.item_type === 'accessory' && item.accessory_kind === 'wristband'
              ? ' is-wristband'
              : ''
  return <div className={`tlg-equipment-product-image${large ? ' large' : ''}${typeClass}`}>{item.image_url ? <img src={item.image_url} alt={`${item.brand} ${item.model}`} loading="lazy" /> : <span>{TYPE_LABELS[item.item_type]}</span>}</div>
}

function BrandIdentity({ item }: { item: CatalogItem }) {
  if (!item.technical_brand_code && !item.brand_logo_url) return null
  return <div className="tlg-equipment-brand-identity">{item.brand_logo_url && <img src={item.brand_logo_url} alt="" loading="lazy" />}<span>{item.technical_brand_tier ? `${sponsorTierLabel(item.technical_brand_tier)} technical brand` : 'Technical brand'}</span></div>
}

function EffectChips({ effects, limit }: { effects: [string, number][]; limit?: number }) {
  const visible = typeof limit === 'number' ? effects.slice(0, limit) : effects
  if (!visible.length) return <div className="tlg-equipment-effect-chips"><span>No direct gameplay modifier</span></div>
  return <div className="tlg-equipment-effect-chips">{visible.map(([key, value]) => <span key={key} className={Number(value) < 0 ? 'negative' : ''}>{EFFECT_LABELS[key] ?? titleCase(key.replace('_pct', ''))} {pct(Number(value))}</span>)}</div>
}

function EquipmentSlot({ title, slot, detail, compact = false }: { title: string; slot?: EquippedSlot | null; detail: string; compact?: boolean }) {
  if (!slot) return <article className={`tlg-equipment-slot empty${compact ? ' compact' : ''}`}><span>{title.toUpperCase()}</span><h3>Not equipped</h3><p>{detail}</p></article>
  return <article className={`tlg-equipment-slot tlg-equipment-slot-v2${compact ? ' compact' : ''}`}><div className="tlg-equipment-slot-image"><ProductImage item={slot.item} /></div><div className="slot-head"><span>{title.toUpperCase()}</span><b>{conditionText(slot.condition)}</b></div><h3>{slot.item.brand}</h3><strong>{slot.item.model}</strong><p>{detail}</p><div className="condition-bar"><i style={{ width: `${Math.max(0, Math.min(100, slot.condition))}%` }} /></div><small>{conditionLabel(slot.condition)} condition</small></article>
}

function ItemDetailDialog({ item, balance, equipped, onClose, onBuy }: { item: CatalogItem; balance: number; equipped?: EquippedSlot | null; onClose: () => void; onBuy: () => void }) {
  const price = playerPrice(item)
  const discount = sponsorDiscount(item)
  const canBuy = item.availability_status === 'available' && balance >= price
  return <div className="tlg-equipment-detail-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><section className="tlg-equipment-detail" role="dialog" aria-modal="true" aria-labelledby="equipment-detail-title"><button type="button" className="tlg-equipment-detail-close" onClick={onClose} aria-label="Close equipment details">×</button><div className="tlg-equipment-detail-media"><ProductImage item={item} large /></div><div className="tlg-equipment-detail-content"><BrandIdentity item={item} /><div className="tlg-equipment-detail-kicker"><span>{TYPE_LABELS[item.item_type]}{item.accessory_kind ? ` · ${titleCase(item.accessory_kind)}` : ''}</span><b>{availabilityLabel(item.availability_status)}</b></div><h2 id="equipment-detail-title">{item.brand} {item.model}</h2><p className="description">{item.description}</p><div className="tlg-equipment-detail-price">{discount > 0 && <span className="tlg-equipment-list-price">Normal {money(item.price_usd)}</span>}<strong>{money(price)}</strong><span>{discount > 0 ? `Technical sponsor −${discount}%` : `${TIER_LABELS[item.tier] ?? 'Tier'} · Tier ${item.tier}`}</span></div><div className="tlg-equipment-detail-tags">{(item.tags ?? []).map((tag) => <span key={tag}>{tag.replaceAll('-', ' ')}</span>)}</div><div className="tlg-equipment-detail-stats">{mainStats(item).map(([name, value]) => <div key={name}><span>{name}</span><strong>{value}</strong><div><i style={{ width: `${value}%` }} /></div></div>)}</div><h3 className="tlg-equipment-effect-heading">Gameplay modifiers at 100% condition</h3><EffectChips effects={activeEffects(item)} /><div className="tlg-equipment-detail-columns"><div className="positive"><h3>Benefits</h3>{item.advantages?.length ? <ul>{item.advantages.map((value) => <li key={value}>{value}</li>)}</ul> : <p>No special advantages defined.</p>}</div><div className="negative"><h3>Trade-offs</h3>{item.disadvantages?.length ? <ul>{item.disadvantages.map((value) => <li key={value}>{value}</li>)}</ul> : <p>No special trade-offs defined.</p>}</div></div><dl className="tlg-equipment-detail-meta"><div><dt>Product profile</dt><dd>{titleCase(item.product_profile ?? 'standard')}</dd></div><div><dt>Surface / weather</dt><dd>{item.surface ? surfaceLabel(item.surface) : item.weather_profile ? `${titleCase(item.weather_profile)} weather` : 'Not surface-specific'}</dd></div><div><dt>Condition wear</dt><dd>{item.wear_per_match ?? '—'} percentage points per match{item.item_type === 'shoes' && (item.wrong_surface_wear_multiplier ?? 1) > 1 ? ` · wrong-surface multiplier ×${item.wrong_surface_wear_multiplier}` : ''}</dd></div><div><dt>Expected lifespan</dt><dd>{item.estimated_uses ? `About ${item.estimated_uses} match uses at base wear. ` : ''}{item.lifespan_text || 'Defined by condition and use.'}</dd></div><div><dt>Maintenance</dt><dd>{item.maintenance_text || 'No special maintenance requirement.'}</dd></div></dl>{equipped && <div className="tlg-equipment-current-compare"><span>CURRENTLY EQUIPPED IN THIS SLOT</span><strong>{equipped.item.brand} {equipped.item.model}</strong><small>{conditionText(equipped.condition)} condition · {equipped.item.id === item.id ? 'Same equipment definition' : 'Compare profile and bonuses before buying'}</small></div>}<div className="tlg-equipment-detail-actions"><button type="button" className="secondary" onClick={onClose}>Close</button><button type="button" disabled={!canBuy} onClick={onBuy}>{item.availability_status !== 'available' ? availabilityLabel(item.availability_status) : balance < price ? 'Insufficient funds' : `Buy for ${money(price)}`}</button></div></div></section></div>
}

function InventoryDetailDialog({ entry, busy, onClose, onSell, onDiscard }: { entry: InventoryItem; busy: string | null; onClose: () => void; onSell: () => void; onDiscard: () => void }) {
  return <div className="tlg-equipment-detail-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><section className="tlg-equipment-detail tlg-equipment-inventory-detail" role="dialog" aria-modal="true" aria-labelledby="inventory-detail-title"><button type="button" className="tlg-equipment-detail-close" onClick={onClose} aria-label="Close inventory details">×</button><div className="tlg-equipment-detail-media"><ProductImage item={entry.item} large /></div><div className="tlg-equipment-detail-content"><BrandIdentity item={entry.item} /><div className="tlg-equipment-detail-kicker"><span>{TYPE_LABELS[entry.item.item_type]}{entry.item.accessory_kind ? ` · ${titleCase(entry.item.accessory_kind)}` : ''}</span><b>{entry.is_equipped ? 'Currently equipped' : 'In Inventory'}</b></div><h2 id="inventory-detail-title">{entry.item.brand} {entry.item.model}</h2><p className="description">{entry.item.description}</p><div className="tlg-equipment-inventory-condition-hero"><div><span>CURRENT CONDITION</span><strong>{conditionText(entry.condition)}</strong><small>{conditionLabel(entry.condition)}</small></div><div className="tlg-equipment-condition-track"><i style={{ width: `${Math.max(0, Math.min(100, entry.condition))}%` }} /></div></div><h3 className="tlg-equipment-effect-heading">Current condition-adjusted modifiers</h3><EffectChips effects={activeEffects(entry.item, true)} /><div className="tlg-equipment-detail-tags">{(entry.item.tags ?? []).map((tag) => <span key={tag}>{tag.replaceAll('-', ' ')}</span>)}</div><div className="tlg-equipment-detail-stats">{mainStats(entry.item).map(([name, value]) => <div key={name}><span>{name}</span><strong>{value}</strong><div><i style={{ width: `${value}%` }} /></div></div>)}</div><div className="tlg-equipment-detail-columns"><div className="positive"><h3>Main benefits</h3>{entry.item.advantages?.length ? <ul>{entry.item.advantages.map((value) => <li key={value}>{value}</li>)}</ul> : <p>No special advantages defined.</p>}</div><div className="negative"><h3>Main disadvantages</h3>{entry.item.disadvantages?.length ? <ul>{entry.item.disadvantages.map((value) => <li key={value}>{value}</li>)}</ul> : <p>No special trade-offs defined.</p>}</div></div><dl className="tlg-equipment-detail-meta"><div><dt>Quality</dt><dd>{TIER_LABELS[entry.item.tier] ?? 'Tier'} · Tier {entry.item.tier}</dd></div><div><dt>Remaining condition</dt><dd>{conditionText(entry.condition)} · Base durability rating {entry.item.durability}</dd></div><div><dt>Wear / match</dt><dd>{entry.item.wear_per_match ?? '—'} percentage points at base use</dd></div><div><dt>Acquired</dt><dd>{acquisitionLabel(entry)}</dd></div><div><dt>Original purchase value</dt><dd>{entry.purchase_price_usd > 0 ? money(entry.purchase_price_usd) : 'No purchase cost recorded'}</dd></div><div><dt>Current resale value</dt><dd>{entry.resell_supported ? money(entry.resale_value_usd) : entry.sell_block_reason ?? 'Not resellable'}</dd></div></dl>{entry.is_equipped && <div className="tlg-equipment-current-compare"><span>GEAR ROOM STATUS</span><strong>This item is currently equipped.</strong><small>Its condition-adjusted effects are already included in the authoritative match profile.</small></div>}<div className="tlg-equipment-detail-actions tlg-equipment-inventory-detail-actions"><button type="button" className="secondary" onClick={onClose}>Close</button><button type="button" className="danger" disabled={!entry.can_sell || busy === `sell:${entry.inventory_id}`} title={entry.sell_block_reason ?? `Sell for ${money(entry.resale_value_usd)}`} onClick={onSell}>{entry.can_sell ? `Sell ${money(entry.resale_value_usd)}` : entry.is_equipped && entry.resell_supported ? 'Replace before selling' : 'Not sellable'}</button><button type="button" className="discard" disabled={entry.is_equipped || entry.acquired_source !== 'purchase' || busy === `discard:${entry.inventory_id}`} title={entry.is_equipped ? 'Equip a replacement before discarding this item.' : entry.acquired_source !== 'purchase' ? 'Only purchased equipment can be discarded.' : 'Discard this item for $0'} onClick={onDiscard}>{entry.is_equipped ? 'Replace before discarding' : entry.acquired_source !== 'purchase' ? 'Cannot discard' : 'Discard'}</button></div></div></section></div>
}

function Effect({ name, value }: { name: string; value: number }) {
  return <div><span>{name}</span><strong className={value > 0 ? 'positive' : value < 0 ? 'negative' : ''}>{pct(value)}</strong></div>
}
