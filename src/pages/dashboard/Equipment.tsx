import { useEffect, useMemo, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { useSearchParams } from 'react-router'

import GameConfirmDialog from '../../components/common/GameConfirmDialog'
import TechnicalSponsorsPanel from '../../components/equipment/TechnicalSponsorsPanel'
import GameLayout from '../../components/layout/GameLayout'
import { useLocalization } from '../../i18n/LocalizationProvider'
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

const TYPE_ORDER: EquipmentType[] = ['racket', 'shoes', 'apparel', 'accessory']
const ACCESSORY_ORDER: AccessoryKind[] = ['bag', 'bottle', 'cap', 'towel', 'wristband']

const TIER_KEYS: Record<number, string> = {
  1: 'starter',
  2: 'advanced',
  3: 'tour',
  4: 'elite',
  5: 'legend',
}

const EFFECT_KEYS: Record<string, string> = {
  power_pct: 'power',
  control_pct: 'control',
  spin_pct: 'spin',
  movement_pct: 'movement',
  comfort_pct: 'comfort',
  serve_pct: 'serve',
  return_pct: 'return',
  rally_pct: 'rally',
  net_pct: 'net',
  stamina_pct: 'stamina',
  focus_pct: 'focus',
  heat_resistance_pct: 'heatResistance',
  cold_resistance_pct: 'coldResistance',
  racket_wear_reduction_pct: 'racketProtection',
  forehand_pct: 'forehand',
  backhand_pct: 'backhand',
  stability_pct: 'stability',
}

function typeLabel(t: TFunction, type: EquipmentType) {
  return t(`equipmentPage.ui.types.${type}`)
}

function tierLabel(t: TFunction, tier: number) {
  const key = TIER_KEYS[tier]
  return key ? t(`equipmentPage.ui.tiers.${key}`) : t('equipmentPage.ui.tiers.tier')
}

function effectLabel(t: TFunction, key: string) {
  const mapped = EFFECT_KEYS[key]
  return mapped ? t(`equipmentPage.ui.stats.${mapped}`) : titleCase(key.replace('_pct', ''))
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

function conditionLabel(t: TFunction, value: number) {
  if (value >= 80) return t('equipmentPage.ui.conditions.excellent')
  if (value >= 60) return t('equipmentPage.ui.conditions.used')
  if (value >= 40) return t('equipmentPage.ui.conditions.worn')
  return t('equipmentPage.ui.conditions.replaceSoon')
}

function surfaceLabel(t: TFunction, surface?: string | null) {
  const key = !surface || surface === 'all' ? 'all' : surface
  return t(`equipmentPage.ui.surfaces.${key}`, { defaultValue: titleCase(key) })
}

function availabilityLabel(t: TFunction, status: CatalogItem['availability_status']) {
  return t(`equipmentPage.ui.availability.${status}`, { defaultValue: titleCase(status) })
}

function effectScopeLabel(t: TFunction, scope: CatalogItem['effect_scope']) {
  return t(`equipmentPage.ui.scopes.${scope}`)
}

function titleCase(value: string) {
  return value.replaceAll('-', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function sponsorTierLabel(t: TFunction, tier: SponsorTier) {
  return t(`equipmentPage.ui.sponsorTiers.${tier}`, { defaultValue: titleCase(tier) })
}

function playerPrice(item: CatalogItem) {
  const sponsorPrice = Number(item.sponsor_final_price_usd)
  return Number.isFinite(sponsorPrice) && sponsorPrice > 0 ? sponsorPrice : Number(item.price_usd) || 0
}

function sponsorDiscount(item: CatalogItem) {
  return Math.max(0, Number(item.technical_sponsor_discount_pct) || 0)
}

function mainStats(t: TFunction, item: CatalogItem) {
  if (item.item_type === 'shoes') return [[t('equipmentPage.ui.stats.traction'), item.traction], [t('equipmentPage.ui.stats.stability'), item.stability], [t('equipmentPage.ui.stats.comfort'), item.comfort], [t('equipmentPage.ui.stats.durability'), item.durability]] as const
  if (item.item_type === 'racket') return [[t('equipmentPage.ui.stats.power'), item.power], [t('equipmentPage.ui.stats.control'), item.control], [t('equipmentPage.ui.stats.spin'), item.spin], [t('equipmentPage.ui.stats.comfort'), item.comfort]] as const
  return [[t('equipmentPage.ui.stats.comfort'), item.comfort], [t('equipmentPage.ui.stats.durability'), item.durability]] as const
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

function acquisitionLabel(t: TFunction, item: InventoryItem) {
  if (item.acquired_source === 'starter') return t('equipmentPage.ui.acquisition.starter')
  if (item.acquired_source === 'sponsor') return t('equipmentPage.ui.acquisition.sponsor')
  if (item.acquired_source === 'reward') return t('equipmentPage.ui.acquisition.reward')
  return t('equipmentPage.ui.acquisition.purchased', { day: item.acquired_absolute_day })
}

function makeRequestKey() {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID()
  return `equipment-${Date.now()}-${Math.random().toString(36).slice(2)}`
}

export default function EquipmentPage() {
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()
  const money = (value: number) => formatCurrency(Number(value) || 0, 'USD')
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
    // Abort an unresponsive request instead of leaving the Equipment page loading forever.
    const controller = new AbortController()
    const timeout = window.setTimeout(() => controller.abort(), 15000)
    try {
      const { data, error: loadError } = await supabase.rpc('get_equipment_dashboard_v1').abortSignal(controller.signal)
      if (loadError || !data) setError(loadError?.message ?? t('equipmentPage.loadError'))
      else setDashboard(data as EquipmentDashboard)
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : t('equipmentPage.loadError'))
    } finally {
      window.clearTimeout(timeout)
      setLoading(false)
    }
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
      setMessage(t('equipmentPage.ui.actions.purchased', { name: `${item.brand} ${item.model}`, amount: money(paid) }))
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
      setMessage(t('equipmentPage.ui.actions.sold', { name: `${item.item.brand} ${item.item.model}`, amount: money(item.resale_value_usd) }))
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
      setMessage(t('equipmentPage.ui.actions.discarded', { name: `${item.item.brand} ${item.item.model}` }))
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
      const suffix = item.item.item_type === 'accessory' && item.item.accessory_kind
        ? t('equipmentPage.ui.actions.accessorySlot', { kind: t(`equipmentPage.accessories.${item.item.accessory_kind}`) })
        : ''
      setMessage(t('equipmentPage.ui.actions.equipped', { name: `${item.item.brand} ${item.item.model}`, suffix }))
      setSelectedInventoryItem(null)
      await loadEquipment()
    }
    setBusy(null)
  }

  const inventoryItems = useMemo(() => {
    const items = (dashboard?.inventory ?? []).filter((entry) => inventoryFilter === 'all' || entry.item.item_type === inventoryFilter)
    return [...items].sort((a, b) => {
      const aTypeIndex = TYPE_ORDER.indexOf(a.item.item_type as EquipmentType)
      const bTypeIndex = TYPE_ORDER.indexOf(b.item.item_type as EquipmentType)
      const aTypeRank = aTypeIndex >= 0 ? aTypeIndex : TYPE_ORDER.length
      const bTypeRank = bTypeIndex >= 0 ? bTypeIndex : TYPE_ORDER.length
      if (aTypeRank !== bTypeRank) return aTypeRank - bTypeRank

      if (a.item.item_type === 'accessory' && b.item.item_type === 'accessory') {
        const aAccessoryIndex = a.item.accessory_kind ? ACCESSORY_ORDER.indexOf(a.item.accessory_kind) : -1
        const bAccessoryIndex = b.item.accessory_kind ? ACCESSORY_ORDER.indexOf(b.item.accessory_kind) : -1
        const aAccessoryRank = aAccessoryIndex >= 0 ? aAccessoryIndex : ACCESSORY_ORDER.length
        const bAccessoryRank = bAccessoryIndex >= 0 ? bAccessoryIndex : ACCESSORY_ORDER.length
        if (aAccessoryRank !== bAccessoryRank) return aAccessoryRank - bAccessoryRank
      }

      if (inventorySort === 'condition-high') return b.condition - a.condition || b.acquired_absolute_day - a.acquired_absolute_day
      if (inventorySort === 'condition-low') return a.condition - b.condition || b.acquired_absolute_day - a.acquired_absolute_day
      if (inventorySort === 'tier-high') return b.item.tier - a.item.tier || b.condition - a.condition
      if (inventorySort === 'value-high') return b.resale_value_usd - a.resale_value_usd || b.purchase_price_usd - a.purchase_price_usd
      return b.acquired_absolute_day - a.acquired_absolute_day || b.item.sort_order - a.item.sort_order
    })
  }, [dashboard?.inventory, inventoryFilter, inventorySort])

  const inventoryGroups = useMemo(() => {
    const groups: Array<{ key: string; label: string; items: InventoryItem[] }> = []

    for (const type of TYPE_ORDER) {
      const items = inventoryItems.filter((entry) => entry.item.item_type === type)
      if (items.length > 0) groups.push({ key: type, label: typeLabel(t, type), items })
    }

    const otherItems = inventoryItems.filter((entry) => !TYPE_ORDER.includes(entry.item.item_type as EquipmentType))
    if (otherItems.length > 0) groups.push({ key: 'other', label: t('equipmentPage.ui.types.other'), items: otherItems })

    return groups
  }, [inventoryItems, t])

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

  if (!dashboard) return <GameLayout title={t('equipmentPage.title')} subtitle={t('equipmentPage.subtitle')}>
    <div className="tlg-equipment-state" role={error ? 'alert' : 'status'}>
      <p>{loading ? t('equipmentPage.ui.loadingCenter') : error ?? t('equipmentPage.loadError')}</p>
      {!loading && <button type="button" onClick={() => void loadEquipment()}>{t('privateLifePage.tryAgain', { defaultValue: 'Try again' })}</button>}
    </div>
  </GameLayout>

  const effects = dashboard?.effects?.[surface]

  return (
    <GameLayout title={t('equipmentPage.title')} subtitle={t('equipmentPage.subtitle')}>
      <div className="tlg-equipment-page">
        <section className="tlg-equipment-hero"><div className="tlg-equipment-hero-copy"><span>{t('equipmentPage.ui.heroKicker')}</span><h1>{t('equipmentPage.heading')}</h1><p>{t('equipmentPage.ui.heroBody')}</p></div></section>

        <div className="tlg-equipment-tabs" role="tablist" aria-label={t('equipmentPage.tabsAria')}><button type="button" className={tab === 'gear' ? 'active' : ''} onClick={() => setTab('gear')}>{t('equipmentPage.tabs.gear')}</button><button type="button" className={tab === 'inventory' ? 'active' : ''} onClick={() => setTab('inventory')}>{t('equipmentPage.tabs.inventory')}</button><button type="button" className={tab === 'market' ? 'active' : ''} onClick={() => setTab('market')}>{t('equipmentPage.ui.tabs.market')}</button><button type="button" className={tab === 'sponsors' ? 'active' : ''} onClick={() => setTab('sponsors')}>{t('equipmentPage.tabs.sponsors')}</button></div>

        {error && <div className="tlg-equipment-alert error">{error}</div>}
        {message && <div className="tlg-equipment-alert">{message}</div>}

        {dashboard && <section className="tlg-equipment-summary-strip tlg-equipment-summary-strip-v3"><div><span>{t('equipmentPage.ui.summary.cash')}</span><strong>{money(dashboard.balance)}</strong><small>{t('equipmentPage.ui.summary.cashNote')}</small></div><div><span>{t('equipmentPage.ui.summary.racket')}</span><strong>{dashboard.loadout.racket ? `${dashboard.loadout.racket.item.brand} ${dashboard.loadout.racket.item.model}` : t('equipmentPage.ui.summary.notEquipped')}</strong><small>{dashboard.loadout.racket ? `${conditionText(dashboard.loadout.racket.condition)} condition` : t('equipmentPage.ui.summary.chooseInventory')}</small></div><div><span>{t('equipmentPage.ui.summary.shoes')}</span><strong>{dashboard.loadout.shoes ? `${dashboard.loadout.shoes.item.brand} ${dashboard.loadout.shoes.item.model}` : t('equipmentPage.ui.summary.notEquipped')}</strong><small>{dashboard.loadout.shoes ? `${conditionText(dashboard.loadout.shoes.condition)} · ${surfaceLabel(t, dashboard.loadout.shoes.item.surface)}` : t('equipmentPage.ui.summary.chooseInventory')}</small></div><div><span>{t('equipmentPage.ui.summary.clothing')}</span><strong>{dashboard.loadout.apparel ? `${dashboard.loadout.apparel.item.brand} ${dashboard.loadout.apparel.item.model}` : t('equipmentPage.ui.summary.notEquipped')}</strong><small>{dashboard.loadout.apparel ? `${conditionText(dashboard.loadout.apparel.condition)} condition` : t('equipmentPage.ui.summary.chooseInventory')}</small></div></section>}

        {dashboard && tab === 'gear' && <div className="tlg-equipment-gear-view">
          <section className="tlg-equipment-panel"><header className="tlg-equipment-panel-head"><div><span>{t('equipmentPage.ui.gear.kicker')}</span><h2>{t('equipmentPage.ui.gear.title')}</h2><p>{t('equipmentPage.ui.gear.body')}</p></div><button type="button" className="tlg-equipment-panel-link" onClick={() => setTab('inventory')}>{t('equipmentPage.ui.gear.openInventory')}</button></header><div className="tlg-equipment-slot-grid tlg-equipment-slot-grid-three"><EquipmentSlot title={typeLabel(t, 'racket')} slot={dashboard.loadout.racket} detail={t('equipmentPage.ui.gear.racketDetail')} /><EquipmentSlot title={typeLabel(t, 'shoes')} slot={dashboard.loadout.shoes} detail={dashboard.loadout.shoes ? `${surfaceLabel(t, dashboard.loadout.shoes.item.surface)} · ${dashboard.loadout.shoes.item.product_profile ?? 'footwear'}` : t('equipmentPage.ui.gear.shoeFallback')} /><EquipmentSlot title={typeLabel(t, 'apparel')} slot={dashboard.loadout.apparel} detail={dashboard.loadout.apparel ? `${titleCase(dashboard.loadout.apparel.item.product_profile ?? 'balanced')} · ${titleCase(dashboard.loadout.apparel.item.weather_profile ?? 'all')} weather` : t('equipmentPage.ui.gear.clothingFallback')} /></div><div className="tlg-equipment-accessory-loadout"><div className="tlg-equipment-accessory-loadout-head"><span>{t('equipmentPage.ui.gear.activeAccessories')}</span><b>{dashboard.loadout.accessories?.length ?? 0} / {ACCESSORY_ORDER.length} kinds</b></div>{(dashboard.loadout.accessories?.length ?? 0) > 0 ? <div className="tlg-equipment-accessory-slot-grid">{(dashboard.loadout.accessories ?? []).map((entry) => <EquipmentSlot key={entry.accessory_kind} title={titleCase(entry.accessory_kind)} slot={entry} detail={`${entry.item.brand} · ${entry.item.wear_per_match ?? 0}% wear / match`} compact />)}</div> : <p className="tlg-equipment-accessory-empty">{t('equipmentPage.ui.gear.noAccessories')}</p>}</div></section>
          <section className="tlg-equipment-panel"><header className="tlg-equipment-panel-head compact"><div><span>{t('equipmentPage.ui.gear.profileKicker')}</span><h2>{t('equipmentPage.ui.gear.profileTitle')}</h2><p>{t('equipmentPage.ui.gear.profileBody')}</p></div><div className="tlg-equipment-surface-switch">{(['hard', 'clay', 'grass'] as CourtSurface[]).map((value) => <button key={value} type="button" className={surface === value ? 'active' : ''} onClick={() => setSurface(value)}>{surfaceLabel(t, value)}</button>)}</div></header>{effects && <div className="tlg-equipment-effects-grid tlg-equipment-effects-grid-expanded"><Effect name={t('equipmentPage.ui.stats.power')}  value={effects.power_pct} /><Effect name={t('equipmentPage.ui.stats.control')}  value={effects.control_pct} /><Effect name={t('equipmentPage.ui.stats.spin')}  value={effects.spin_pct} /><Effect name={t('equipmentPage.ui.stats.movement')}  value={effects.movement_pct} /><Effect name={t('equipmentPage.ui.stats.comfort')}  value={effects.comfort_pct} /><Effect name={t('equipmentPage.ui.stats.serve')}  value={effects.serve_pct} /><Effect name={t('equipmentPage.ui.stats.return')}  value={effects.return_pct} /><Effect name={t('equipmentPage.ui.stats.rally')}  value={effects.rally_pct} /><Effect name={t('equipmentPage.ui.stats.net')}  value={effects.net_pct} /><Effect name={t('equipmentPage.ui.stats.stamina')}  value={effects.stamina_pct} /><Effect name={t('equipmentPage.ui.stats.focus')}  value={effects.focus_pct} /><Effect name={t('equipmentPage.ui.stats.racketProtection')}  value={effects.racket_wear_reduction_pct} /></div>}</section>
          <section className="tlg-equipment-wear-note tlg-equipment-wear-note-v3"><div><span>{t('equipmentPage.ui.wearSummary.racket')}</span><strong>{t('equipmentPage.ui.wearSummary.racketValue', { value: dashboard.wear_rules.racket_default })}</strong></div><div><span>{t('equipmentPage.ui.wearSummary.shoes')}</span><strong>{t('equipmentPage.ui.wearSummary.shoesValue', { min: dashboard.wear_rules.shoes_surface_specific, max: dashboard.wear_rules.shoes_wrong_surface })}</strong></div><div><span>{t('equipmentPage.ui.wearSummary.clothing')}</span><strong>{t('equipmentPage.ui.wearSummary.clothingValue', { value: dashboard.wear_rules.apparel_typical })}</strong></div><div><span>{t('equipmentPage.ui.wearSummary.accessories')}</span><strong>{t('equipmentPage.ui.wearSummary.accessoriesValue', { min: Math.min(...Object.values(dashboard.wear_rules.accessory_profiles)), max: Math.max(...Object.values(dashboard.wear_rules.accessory_profiles)) })}</strong></div><p>{t('equipmentPage.ui.wearSummary.note', { precision: dashboard.wear_rules.condition_precision })}</p></section>
        </div>}

        {dashboard && tab === 'inventory' && <section className="tlg-equipment-panel tlg-equipment-inventory-panel-v3"><header className="tlg-equipment-panel-head market-head"><div><span>{t('equipmentPage.inventory.kicker')}</span><h2>{t('equipmentPage.inventory.title')}</h2><p>{t('equipmentPage.inventory.body')}</p></div><div className="tlg-equipment-market-balance"><span>{t('equipmentPage.ui.marketplace.owned', { count: dashboard.inventory.length })}</span><strong>{dashboard.inventory.length}</strong></div></header><div className="tlg-equipment-market-toolbar tlg-equipment-inventory-toolbar"><div className="tlg-equipment-category-tabs" role="tablist" aria-label={t('equipmentPage.inventory.category')}><button type="button" className={inventoryFilter === 'all' ? 'active' : ''} onClick={() => setInventoryFilter('all')}>{t('equipmentPage.ui.marketplace.all')} <small>{dashboard.inventory.length}</small></button>{TYPE_ORDER.map((type) => <button key={type} type="button" className={inventoryFilter === type ? 'active' : ''} onClick={() => setInventoryFilter(type)}>{typeLabel(t, type)} <small>{inventoryCounts[type]}</small></button>)}</div><label className="tlg-equipment-sort"><span>{t('equipmentPage.ui.marketplace.sort')}</span><select value={inventorySort} onChange={(event) => setInventorySort(event.target.value as InventorySort)}><option value="recent">{t('equipmentPage.ui.dialogs.acquired')}</option><option value="condition-high">{t('equipmentPage.inventory.condition')} ↓</option><option value="condition-low">{t('equipmentPage.inventory.condition')} ↑</option><option value="tier-high">{t('equipmentPage.ui.marketplace.qualityHigh')}</option><option value="value-high">{t('equipmentPage.inventory.sellValue')} ↓</option></select></label></div>{inventoryItems.length > 0 ? <div className="tlg-equipment-inventory-groups">{inventoryGroups.map((group) => <section className="tlg-equipment-inventory-group" key={group.key}><header className="tlg-equipment-inventory-group-head"><h3>{group.label}</h3><span>{t('equipmentPage.gear.owned', { count: group.items.length })}</span></header><div className="tlg-equipment-inventory-card-grid">{group.items.map((entry) => <article className={`tlg-equipment-owned-card${entry.is_equipped ? ' equipped' : ''}`} key={entry.inventory_id}><ProductImage item={entry.item} large /><div className="tlg-equipment-owned-card-body"><BrandIdentity item={entry.item} /><div className="tlg-equipment-owned-card-top"><span>{typeLabel(t, entry.item.item_type)} · {entry.item.product_profile ? titleCase(entry.item.product_profile) : tierLabel(t, entry.item.tier)}</span><b>{entry.is_equipped ? t('equipmentPage.inventory.equipped') : t('equipmentPage.gear.owned', { count: 1 })}</b></div><h3>{entry.item.brand} {entry.item.model}</h3><p>{entry.item.description}</p><div className="tlg-equipment-owned-condition"><div><span>{t('equipmentPage.inventory.condition')}</span><strong>{conditionText(entry.condition)} · {conditionLabel(t, entry.condition)}</strong></div><div className="tlg-equipment-condition-track"><i style={{ width: `${Math.max(0, Math.min(100, entry.condition))}%` }} /></div></div><div className="tlg-equipment-owned-facts"><span>{t('equipmentPage.gear.wearMatch')} <b>{entry.item.wear_per_match ?? '—'}%</b></span><span>{t('equipmentPage.inventory.sellValue')} <b>{entry.resell_supported ? money(entry.resale_value_usd) : t('equipmentPage.ui.dialogs.notResellable')}</b></span></div><EffectChips effects={activeEffects(entry.item, true)} limit={3} /><div className="tlg-equipment-owned-card-actions"><button type="button" className="secondary" onClick={() => setSelectedInventoryItem(entry)}>{t('equipmentPage.ui.marketplace.viewDetails')}</button><button type="button" disabled={entry.is_equipped || busy === `equip:${entry.inventory_id}`} onClick={() => void equipItem(entry)}>{entry.is_equipped ? t('equipmentPage.inventory.equipped') : busy === `equip:${entry.inventory_id}` ? t('equipmentPage.inventory.equipping') : t('equipmentPage.inventory.equip')}</button></div></div></article>)}</div></section>)}</div> : <div className="tlg-equipment-inventory-empty"><h3>{inventoryFilter === 'all' ? t('equipmentPage.ui.inventory.emptyAll') : t('equipmentPage.ui.inventory.emptyType', { type: typeLabel(t, inventoryFilter).toLowerCase() })}</h3><p>{t('equipmentPage.ui.inventory.marketHint')}</p><button type="button" onClick={() => visitMarket(inventoryFilter)}>{t('equipmentPage.ui.inventory.visitMarket')}</button></div>}</section>}

        {dashboard && tab === 'market' && <section className="tlg-equipment-panel tlg-equipment-market-panel"><header className="tlg-equipment-panel-head market-head"><div><span>{t('equipmentPage.ui.marketplace.kicker')}</span><h2>{t('equipmentPage.ui.marketplace.title')}</h2><p>{t('equipmentPage.ui.marketplace.body')}</p></div><div className="tlg-equipment-market-balance"><span>{t('equipmentPage.ui.marketplace.available')}</span><strong>{money(dashboard.balance)}</strong></div></header><div className="tlg-equipment-market-toolbar"><div className="tlg-equipment-category-tabs" role="tablist" aria-label={t('equipmentPage.ui.marketplace.categoriesAria')}><button type="button" className={marketFilter === 'all' ? 'active' : ''} onClick={() => setMarketFilter('all')}>{t('equipmentPage.ui.marketplace.all')}</button>{TYPE_ORDER.map((type) => <button key={type} type="button" className={marketFilter === type ? 'active' : ''} onClick={() => setMarketFilter(type)}>{typeLabel(t, type)}</button>)}</div><label className="tlg-equipment-sort"><span>{t('equipmentPage.ui.marketplace.sort')}</span><select value={marketSort} onChange={(event) => setMarketSort(event.target.value as MarketSort)}><option value="featured">{t('equipmentPage.ui.marketplace.featured')}</option><option value="price-low">{t('equipmentPage.ui.marketplace.priceLow')}</option><option value="price-high">{t('equipmentPage.ui.marketplace.priceHigh')}</option><option value="tier-high">{t('equipmentPage.ui.marketplace.qualityHigh')}</option><option value="durability-high">{t('equipmentPage.ui.marketplace.durabilityHigh')}</option></select></label></div>{availableTags.length > 0 && <div className="tlg-equipment-tag-filter" aria-label={t('equipmentPage.ui.marketplace.accessoryAria')}><button type="button" className={marketTag === 'all' ? 'active' : ''} onClick={() => setMarketTag('all')}>{t('equipmentPage.ui.marketplace.allAccessories')}</button>{availableTags.map((tag) => <button key={tag} type="button" className={marketTag === tag ? 'active' : ''} onClick={() => setMarketTag(tag)}>{t(`equipmentPage.accessories.${tag}`)}</button>)}</div>}<div className="tlg-equipment-market-grid">{marketItems.map((item) => { const owned = dashboard.inventory.filter((entry) => entry.item.id === item.id).length; const discount = sponsorDiscount(item); return <article className={`tlg-equipment-market-card tlg-equipment-market-card-v2${discount > 0 ? ' sponsor-priced' : ''}`} key={item.id}><ProductImage item={item} large /><BrandIdentity item={item} /><div className="top"><span>{typeLabel(t, item.item_type)} · {item.product_profile ? titleCase(item.product_profile) : `${tierLabel(t, item.tier)} ${item.tier}`}</span><b className={`availability ${item.availability_status}`}>{availabilityLabel(t, item.availability_status)}</b></div><h3>{item.brand}</h3><strong className="model">{item.model}</strong><p>{item.description}</p><EffectChips effects={activeEffects(item)} limit={3} /><div className="tlg-equipment-card-quick"><span>{item.surface ? surfaceLabel(t, item.surface) : item.weather_profile ? t('equipmentPage.ui.marketplace.weather', { profile: titleCase(item.weather_profile) }) : effectScopeLabel(t, item.effect_scope)}</span><span>{t('equipmentPage.ui.marketplace.wear', { value: item.wear_per_match ?? '—' })}</span></div>{discount > 0 && <div className="tlg-equipment-sponsor-price-badge"><strong>{t('equipmentPage.ui.marketplace.sponsorDiscount')}</strong><span>−{discount}%</span></div>}<div className="bottom"><div className="tlg-equipment-market-price-stack">{discount > 0 && <span className="tlg-equipment-list-price">{t('equipmentPage.ui.marketplace.normal', { amount: money(item.price_usd) })}</span>}<strong className={discount > 0 ? 'tlg-equipment-sponsor-final-price' : ''}>{money(playerPrice(item))}</strong>{discount > 0 && <span className="tlg-equipment-sponsor-saving">{t('equipmentPage.ui.marketplace.save', { amount: money(Math.max(0, item.price_usd - playerPrice(item))) })}</span>}<span>{owned > 0 ? t('equipmentPage.ui.marketplace.owned', { count: owned }) : t('equipmentPage.ui.marketplace.estimatedUses', { count: item.estimated_uses ?? '—' })}</span></div><div className="tlg-equipment-market-card-buttons"><button type="button" className="secondary" onClick={() => setSelectedMarketItem(item)}>{t('equipmentPage.ui.marketplace.viewDetails')}</button><button type="button" className="buy" disabled={item.availability_status !== 'available' || dashboard.balance < playerPrice(item)} onClick={() => requestPurchase(item)}>{item.availability_status !== 'available' ? availabilityLabel(t, item.availability_status) : t('equipmentPage.ui.marketplace.buy')}</button></div></div></article> })}</div>{marketItems.length === 0 && <div className="tlg-equipment-empty-market">{t('equipmentPage.ui.marketplace.empty')}</div>}</section>}

        {tab === 'sponsors' && <TechnicalSponsorsPanel onChanged={loadEquipment} />}
      </div>

      {dashboard && selectedMarketItem && <ItemDetailDialog item={selectedMarketItem} balance={dashboard.balance} equipped={getComparableSlot(dashboard.loadout, selectedMarketItem)} onClose={() => setSelectedMarketItem(null)} onBuy={() => requestPurchase(selectedMarketItem)} />}
      {selectedInventoryItem && <InventoryDetailDialog entry={selectedInventoryItem} busy={busy} onClose={() => setSelectedInventoryItem(null)} onSell={() => setPendingSale(selectedInventoryItem)} onDiscard={() => setPendingDiscard(selectedInventoryItem)} />}

      {dashboard && pendingPurchase && <GameConfirmDialog open eyebrow={t('equipmentPage.ui.dialogs.purchaseEyebrow')} title={t('equipmentPage.ui.dialogs.purchaseTitle', { name: `${pendingPurchase.item.brand} ${pendingPurchase.item.model}` })} message={<>{t('equipmentPage.ui.dialogs.purchaseMessage', { amount: money(playerPrice(pendingPurchase.item)) })}</>} detail={sponsorDiscount(pendingPurchase.item) > 0 ? <>{t('equipmentPage.ui.dialogs.normalPrice', { amount: money(pendingPurchase.item.price_usd) })} · {t('equipmentPage.ui.dialogs.sponsorDiscountDetail', { percent: sponsorDiscount(pendingPurchase.item) })} · {t('equipmentPage.ui.dialogs.balanceAfter', { amount: money(dashboard.balance - playerPrice(pendingPurchase.item)) })}</> : dashboard.balance >= playerPrice(pendingPurchase.item) ? <>{t('equipmentPage.ui.dialogs.balanceAfter', { amount: money(dashboard.balance - playerPrice(pendingPurchase.item)) })}</> : <>{t('equipmentPage.ui.dialogs.currentBalance', { amount: money(dashboard.balance) })}</>} confirmLabel={dashboard.balance >= playerPrice(pendingPurchase.item) ? t('equipmentPage.ui.dialogs.buyFor', { amount: money(playerPrice(pendingPurchase.item)) }) : t('equipmentPage.ui.dialogs.insufficientFunds')} tone="neutral" busy={busy === `buy:${pendingPurchase.item.id}`} onCancel={() => { if (!busy) setPendingPurchase(null) }} onConfirm={() => { if (dashboard.balance >= playerPrice(pendingPurchase.item)) return buyItem() }} />}
      {pendingDiscard && <GameConfirmDialog open eyebrow={t('equipmentPage.ui.dialogs.discardEyebrow')} title={t('equipmentPage.ui.dialogs.discardTitle', { name: `${pendingDiscard.item.brand} ${pendingDiscard.item.model}` })} message={<>{t('equipmentPage.ui.dialogs.discardMessage')}</>} detail={pendingDiscard.is_equipped ? <>{t('equipmentPage.ui.dialogs.discardEquipped')}</> : <>{t('equipmentPage.ui.dialogs.discardCondition', { condition: conditionText(pendingDiscard.condition) })}</>} confirmLabel={pendingDiscard.is_equipped ? t('equipmentPage.ui.dialogs.replaceBeforeDiscarding') : t('equipmentPage.ui.dialogs.discardPermanent')} tone="warning" busy={busy === `discard:${pendingDiscard.inventory_id}`} onCancel={() => { if (!busy) setPendingDiscard(null) }} onConfirm={() => { if (!pendingDiscard.is_equipped) return discardItem() }} />}
      {pendingSale && <GameConfirmDialog open eyebrow={t('equipmentPage.ui.dialogs.resaleEyebrow')} title={t('equipmentPage.ui.dialogs.resaleTitle', { name: `${pendingSale.item.brand} ${pendingSale.item.model}` })} message={<>{t('equipmentPage.inventory.condition')}: <strong>{conditionText(pendingSale.condition)} · {conditionLabel(t, pendingSale.condition)}</strong>. {t('equipmentPage.ui.dialogs.equippedStatus')} <strong>{pendingSale.is_equipped ? t('equipmentPage.ui.dialogs.currentlyEquippedShort') : t('equipmentPage.ui.dialogs.notEquipped')}</strong>. {t('equipmentPage.ui.dialogs.resaleMessage')}</>} detail={<>{t('equipmentPage.ui.dialogs.originalPrice', { amount: money(pendingSale.purchase_price_usd) })} · {t('equipmentPage.ui.dialogs.estimatedSale', { amount: money(pendingSale.resale_value_usd) })}</>} confirmLabel={t('equipmentPage.ui.dialogs.sellFor', { amount: money(pendingSale.resale_value_usd) })} tone="warning" busy={busy === `sell:${pendingSale.inventory_id}`} onCancel={() => { if (!busy) setPendingSale(null) }} onConfirm={sellItem} />}
    </GameLayout>
  )
}

function ProductImage({ item, large = false }: { item: CatalogItem; large?: boolean }) {
  const { t } = useTranslation()
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
  return <div className={`tlg-equipment-product-image${large ? ' large' : ''}${typeClass}`}>{item.image_url ? <img src={item.image_url} alt={`${item.brand} ${item.model}`} loading="lazy" /> : <span>{typeLabel(t, item.item_type)}</span>}</div>
}

function BrandIdentity({ item }: { item: CatalogItem }) {
  const { t } = useTranslation()
  if (!item.technical_brand_code && !item.brand_logo_url) return null
  return <div className="tlg-equipment-brand-identity">{item.brand_logo_url && <img src={item.brand_logo_url} alt="" loading="lazy" />}<span>{item.technical_brand_tier ? t('equipmentPage.ui.sponsorTiers.technicalBrandTier', { tier: sponsorTierLabel(t, item.technical_brand_tier) }) : t('equipmentPage.ui.sponsorTiers.technicalBrand')}</span></div>
}

function EffectChips({ effects, limit }: { effects: [string, number][]; limit?: number }) {
  const { t } = useTranslation()
  const visible = typeof limit === 'number' ? effects.slice(0, limit) : effects
  if (!visible.length) return <div className="tlg-equipment-effect-chips"><span>{t('equipmentPage.ui.scopes.none')}</span></div>
  return <div className="tlg-equipment-effect-chips">{visible.map(([key, value]) => <span key={key} className={Number(value) < 0 ? 'negative' : ''}>{effectLabel(t, key)} {pct(Number(value))}</span>)}</div>
}

function EquipmentSlot({ title, slot, detail, compact = false }: { title: string; slot?: EquippedSlot | null; detail: string; compact?: boolean }) {
  const { t } = useTranslation()
  if (!slot) return <article className={`tlg-equipment-slot empty${compact ? ' compact' : ''}`}><span>{title.toUpperCase()}</span><h3>{t('equipmentPage.ui.summary.notEquipped')}</h3><p>{detail}</p></article>
  return <article className={`tlg-equipment-slot tlg-equipment-slot-v2${compact ? ' compact' : ''}`}><div className="tlg-equipment-slot-image"><ProductImage item={slot.item} /></div><div className="slot-head"><span>{title.toUpperCase()}</span><b>{conditionText(slot.condition)}</b></div><h3>{slot.item.brand}</h3><strong>{slot.item.model}</strong><p>{detail}</p><div className="condition-bar"><i style={{ width: `${Math.max(0, Math.min(100, slot.condition))}%` }} /></div><small>{t('equipmentPage.ui.conditions.conditionSuffix', { label: conditionLabel(t, slot.condition) })}</small></article>
}

function ItemDetailDialog({ item, balance, equipped, onClose, onBuy }: { item: CatalogItem; balance: number; equipped?: EquippedSlot | null; onClose: () => void; onBuy: () => void }) {
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()
  const money = (value: number) => formatCurrency(Number(value) || 0, 'USD')
  const price = playerPrice(item)
  const discount = sponsorDiscount(item)
  const canBuy = item.availability_status === 'available' && balance >= price
  return <div className="tlg-equipment-detail-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><section className="tlg-equipment-detail" role="dialog" aria-modal="true" aria-labelledby="equipment-detail-title"><button type="button" className="tlg-equipment-detail-close" onClick={onClose} aria-label={t('equipmentPage.ui.dialogs.closeEquipment')}>×</button><div className="tlg-equipment-detail-media"><ProductImage item={item} large /></div><div className="tlg-equipment-detail-content"><BrandIdentity item={item} /><div className="tlg-equipment-detail-kicker"><span>{typeLabel(t, item.item_type)}{item.accessory_kind ? ` · ${titleCase(item.accessory_kind)}` : ''}</span><b>{availabilityLabel(t, item.availability_status)}</b></div><h2 id="equipment-detail-title">{item.brand} {item.model}</h2><p className="description">{item.description}</p><div className="tlg-equipment-detail-price">{discount > 0 && <span className="tlg-equipment-list-price">{t('equipmentPage.ui.marketplace.normal', { amount: money(item.price_usd) })}</span>}<strong>{money(price)}</strong><span>{discount > 0 ? t('equipmentPage.sponsors.benefitText', { discount, category: typeLabel(t, item.item_type) }) : `${tierLabel(t, item.tier)} · ${t('equipmentPage.ui.tiers.tier')} ${item.tier}`}</span></div><div className="tlg-equipment-detail-tags">{(item.tags ?? []).map((tag) => <span key={tag}>{tag.replaceAll('-', ' ')}</span>)}</div><div className="tlg-equipment-detail-stats">{mainStats(t, item).map(([name, value]) => <div key={name}><span>{name}</span><strong>{value}</strong><div><i style={{ width: `${value}%` }} /></div></div>)}</div><h3 className="tlg-equipment-effect-heading">{t('equipmentPage.ui.dialogs.gameplayModifiers')}</h3><EffectChips effects={activeEffects(item)} /><div className="tlg-equipment-detail-columns"><div className="positive"><h3>{t('equipmentPage.ui.dialogs.benefits')}</h3>{item.advantages?.length ? <ul>{item.advantages.map((value) => <li key={value}>{value}</li>)}</ul> : <p>{t('equipmentPage.ui.dialogs.noAdvantages')}</p>}</div><div className="negative"><h3>{t('equipmentPage.ui.dialogs.tradeoffs')}</h3>{item.disadvantages?.length ? <ul>{item.disadvantages.map((value) => <li key={value}>{value}</li>)}</ul> : <p>{t('equipmentPage.ui.dialogs.noTradeoffs')}</p>}</div></div><dl className="tlg-equipment-detail-meta"><div><dt>{t('equipmentPage.ui.dialogs.productProfile')}</dt><dd>{titleCase(item.product_profile ?? 'standard')}</dd></div><div><dt>{t('equipmentPage.ui.dialogs.surfaceWeather')}</dt><dd>{item.surface ? surfaceLabel(t, item.surface) : item.weather_profile ? t('equipmentPage.ui.marketplace.weather', { profile: titleCase(item.weather_profile) }) : t('equipmentPage.ui.dialogs.notSurfaceSpecific')}</dd></div><div><dt>{t('equipmentPage.ui.dialogs.conditionWear')}</dt><dd>{item.wear_per_match ?? '—'} percentage points per match{item.item_type === 'shoes' && (item.wrong_surface_wear_multiplier ?? 1) > 1 ? ` · wrong-surface multiplier ×${item.wrong_surface_wear_multiplier}` : ''}</dd></div><div><dt>{t('equipmentPage.ui.dialogs.expectedLifespan')}</dt><dd>{item.estimated_uses ? t('equipmentPage.ui.dialogs.aboutUses', { count: item.estimated_uses }) : ''}{item.lifespan_text || t('equipmentPage.ui.dialogs.definedByUse')}</dd></div><div><dt>{t('equipmentPage.ui.dialogs.maintenance')}</dt><dd>{item.maintenance_text || t('equipmentPage.ui.dialogs.noMaintenance')}</dd></div></dl>{equipped && <div className="tlg-equipment-current-compare"><span>{t('equipmentPage.ui.dialogs.currentlyEquipped')}</span><strong>{equipped.item.brand} {equipped.item.model}</strong><small>{conditionText(equipped.condition)} condition · {equipped.item.id === item.id ? t('equipmentPage.ui.dialogs.sameDefinition') : t('equipmentPage.ui.dialogs.compareBeforeBuying')}</small></div>}<div className="tlg-equipment-detail-actions"><button type="button" className="secondary" onClick={onClose}>{t('equipmentPage.ui.dialogs.close')}</button><button type="button" disabled={!canBuy} onClick={onBuy}>{item.availability_status !== 'available' ? availabilityLabel(t, item.availability_status) : balance < price ? t('equipmentPage.ui.dialogs.insufficientFunds') : t('equipmentPage.ui.dialogs.buyFor', { amount: money(price) })}</button></div></div></section></div>
}

function InventoryDetailDialog({ entry, busy, onClose, onSell, onDiscard }: { entry: InventoryItem; busy: string | null; onClose: () => void; onSell: () => void; onDiscard: () => void }) {
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()
  const money = (value: number) => formatCurrency(Number(value) || 0, 'USD')
  return <div className="tlg-equipment-detail-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><section className="tlg-equipment-detail tlg-equipment-inventory-detail" role="dialog" aria-modal="true" aria-labelledby="inventory-detail-title"><button type="button" className="tlg-equipment-detail-close" onClick={onClose} aria-label={t('equipmentPage.ui.dialogs.closeInventory')}>×</button><div className="tlg-equipment-detail-media"><ProductImage item={entry.item} large /></div><div className="tlg-equipment-detail-content"><BrandIdentity item={entry.item} /><div className="tlg-equipment-detail-kicker"><span>{typeLabel(t, entry.item.item_type)}{entry.item.accessory_kind ? ` · ${titleCase(entry.item.accessory_kind)}` : ''}</span><b>{entry.is_equipped ? t('equipmentPage.ui.dialogs.currentlyEquippedShort') : t('equipmentPage.inventory.title')}</b></div><h2 id="inventory-detail-title">{entry.item.brand} {entry.item.model}</h2><p className="description">{entry.item.description}</p><div className="tlg-equipment-inventory-condition-hero"><div><span>{t('equipmentPage.ui.dialogs.currentCondition')}</span><strong>{conditionText(entry.condition)}</strong><small>{conditionLabel(t, entry.condition)}</small></div><div className="tlg-equipment-condition-track"><i style={{ width: `${Math.max(0, Math.min(100, entry.condition))}%` }} /></div></div><h3 className="tlg-equipment-effect-heading">{t('equipmentPage.ui.dialogs.adjustedModifiers')}</h3><EffectChips effects={activeEffects(entry.item, true)} /><div className="tlg-equipment-detail-tags">{(entry.item.tags ?? []).map((tag) => <span key={tag}>{tag.replaceAll('-', ' ')}</span>)}</div><div className="tlg-equipment-detail-stats">{mainStats(t, entry.item).map(([name, value]) => <div key={name}><span>{name}</span><strong>{value}</strong><div><i style={{ width: `${value}%` }} /></div></div>)}</div><div className="tlg-equipment-detail-columns"><div className="positive"><h3>{t('equipmentPage.ui.dialogs.mainBenefits')}</h3>{entry.item.advantages?.length ? <ul>{entry.item.advantages.map((value) => <li key={value}>{value}</li>)}</ul> : <p>{t('equipmentPage.ui.dialogs.noAdvantages')}</p>}</div><div className="negative"><h3>{t('equipmentPage.ui.dialogs.mainDisadvantages')}</h3>{entry.item.disadvantages?.length ? <ul>{entry.item.disadvantages.map((value) => <li key={value}>{value}</li>)}</ul> : <p>{t('equipmentPage.ui.dialogs.noTradeoffs')}</p>}</div></div><dl className="tlg-equipment-detail-meta"><div><dt>{t('equipmentPage.ui.dialogs.quality')}</dt><dd>{tierLabel(t, entry.item.tier)} · {t('equipmentPage.ui.tiers.tier')} {entry.item.tier}</dd></div><div><dt>{t('equipmentPage.ui.dialogs.remainingCondition')}</dt><dd>{conditionText(entry.condition)} · {t('equipmentPage.ui.dialogs.baseDurability', { value: entry.item.durability })}</dd></div><div><dt>{t('equipmentPage.gear.wearMatch')}</dt><dd>{entry.item.wear_per_match ?? '—'} percentage points at base use</dd></div><div><dt>{t('equipmentPage.ui.dialogs.acquired')}</dt><dd>{acquisitionLabel(t, entry)}</dd></div><div><dt>{t('equipmentPage.ui.dialogs.originalPurchase')}</dt><dd>{entry.purchase_price_usd > 0 ? money(entry.purchase_price_usd) : t('equipmentPage.ui.dialogs.noPurchaseCost')}</dd></div><div><dt>{t('equipmentPage.ui.dialogs.resaleValue')}</dt><dd>{entry.resell_supported ? money(entry.resale_value_usd) : entry.sell_block_reason ?? t('equipmentPage.ui.dialogs.notResellable')}</dd></div></dl>{entry.is_equipped && <div className="tlg-equipment-current-compare"><span>{t('equipmentPage.ui.dialogs.gearStatus')}</span><strong>{t('equipmentPage.ui.dialogs.currentlyEquippedBody')}</strong><small>{t('equipmentPage.ui.dialogs.equippedEffectsBody')}</small></div>}<div className="tlg-equipment-detail-actions tlg-equipment-inventory-detail-actions"><button type="button" className="secondary" onClick={onClose}>{t('equipmentPage.ui.dialogs.close')}</button><button type="button" className="danger" disabled={!entry.can_sell || busy === `sell:${entry.inventory_id}`} title={entry.sell_block_reason ?? t('equipmentPage.ui.dialogs.sellFor', { amount: money(entry.resale_value_usd) })} onClick={onSell}>{entry.can_sell ? t('equipmentPage.ui.dialogs.sellFor', { amount: money(entry.resale_value_usd) }) : entry.is_equipped && entry.resell_supported ? t('equipmentPage.ui.dialogs.replaceBeforeSelling') : t('equipmentPage.ui.dialogs.notSellable')}</button><button type="button" className="discard" disabled={entry.is_equipped || entry.acquired_source !== 'purchase' || busy === `discard:${entry.inventory_id}`} title={entry.is_equipped ? t('equipmentPage.ui.dialogs.equipReplacementDiscard') : entry.acquired_source !== 'purchase' ? t('equipmentPage.ui.dialogs.purchasedOnlyDiscard') : t('equipmentPage.ui.dialogs.discardZero')} onClick={onDiscard}>{entry.is_equipped ? t('equipmentPage.ui.dialogs.replaceBeforeDiscarding') : entry.acquired_source !== 'purchase' ? t('equipmentPage.ui.dialogs.cannotDiscard') : t('equipmentPage.ui.dialogs.discard')}</button></div></div></section></div>
}

function Effect({ name, value }: { name: string; value: number }) {
  return <div><span>{name}</span><strong className={value > 0 ? 'positive' : value < 0 ? 'negative' : ''}>{pct(value)}</strong></div>
}
