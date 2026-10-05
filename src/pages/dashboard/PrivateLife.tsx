import {
  Crown,
  LockKeyhole,
  RefreshCw,
  TrendingDown,
  TrendingUp,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router'

import GameConfirmDialog from '../../components/common/GameConfirmDialog'
import GameLayout from '../../components/layout/GameLayout'
import PrivateLifeInvestments from '../../components/private-life/PrivateLifeInvestments'
import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import '../../styles/private-life.css'
import '../../styles/private-life-marketplace.css'
import '../../styles/private-life-history.css'

type AssetCategory = 'watch' | 'jewelry' | 'car' | 'apartment' | 'house_villa' | 'yacht' | 'private_jet' | 'art' | 'collectible'
type MainTab = 'overview' | 'assets' | 'investments' | 'marketplace'
type CategoryFilter = 'all' | AssetCategory
type MarketplacePrice = 'all' | 'under_10k' | '10k_50k' | '50k_250k' | '250k_1m' | '1m_5m' | '5m_plus'
type MarketplaceRarity = 'all' | 'common' | 'uncommon' | 'rare' | 'very_rare' | 'legendary'
type MarketplaceSort = 'default' | 'price_asc' | 'price_desc' | 'prestige_desc' | 'appreciation_desc'
type SaleMode = 'urgent' | 'standard' | 'patient'

type CatalogAsset = {
  code: string
  category: AssetCategory
  name: string
  tier: number
  description: string
  purchase_price: number
  prestige: number
  rarity: string
  annual_running_cost: number
  annual_value_rate_bps: number
  resale_discount_bps: number
  image_url: string
  metadata?: Record<string, unknown>
  location_priced?: boolean
  market_monthly_change_bps?: number | null
  previous_market_price?: number | null
  affordable: boolean
  owned: boolean
}

type SaleQuote = { price: number; wait_days: number }
type PendingSale = {
  id: string
  sale_mode: SaleMode
  listed_absolute_day: number
  settle_absolute_day: number
  quoted_sale_price: number
  status: string
}

type OwnedAsset = {
  id: string
  catalog_code: string
  category: AssetCategory
  name: string
  base_name?: string
  description: string
  tier: number
  prestige: number
  rarity: string
  image_url: string
  annual_running_cost: number
  annual_value_rate_bps: number
  resale_discount_bps: number
  purchase_absolute_day: number
  purchase_price: number
  current_market_value: number
  estimated_sale_price: number
  potential_gain_loss: number
  ownership_days: number
  acquisition_type?: 'purchase' | 'starter_home'
  location_code?: string | null
  city?: string | null
  country_code?: string | null
  country_name?: string | null
  sale_quotes?: Record<SaleMode, SaleQuote>
  pending_sale?: PendingSale | null
  asset_monthly_change_bps?: number | null
  property_monthly_change_bps?: number | null
  previous_market_price?: number | null
}

type PropertyLocation = {
  code: string
  country_code: string
  country_name: string
  city: string
  apartment_base_price: number
  house_base_price: number
  annual_value_rate_bps: number
  monthly_change_bps?: number | null
  sort_order: number
}

type CategoryTotal = {
  category: AssetCategory
  owned_count: number
  market_value: number
  prestige: number
  annual_running_cost: number
}

type AssetHistoryRow = {
  id: string
  event_type: string
  transaction_type: string
  event_absolute_day: number
  amount: number
  finance_transaction_id?: string | null
  title: string
  description: string
  catalog_code: string
  category: AssetCategory
  name: string
  base_name: string
  acquisition_type: 'purchase' | 'starter_home'
  city?: string | null
  country_code?: string | null
  country_name?: string | null
}

type PrivateLifeDashboard = {
  player_id: string
  currency: string
  cash_balance: number
  current_absolute_day: number
  season: number
  month: number
  day: number
  prestige: number
  asset_value: number
  investment_value: number
  net_worth: number
  annual_running_cost: number
  category_totals: CategoryTotal[]
  owned_assets: OwnedAsset[]
  catalog: CatalogAsset[]
  property_locations: PropertyLocation[]
}

type MarketplaceListing = CatalogAsset & {
  effective_price: number
  effective_annual_cost: number
  effective_value_rate_bps: number
  effective_affordable: boolean
  effective_owned: boolean
  effective_market_change_bps?: number | null
  location?: PropertyLocation
}

type PendingAction =
  | { type: 'buy'; listing: MarketplaceListing }
  | { type: 'sell'; asset: OwnedAsset; saleMode: SaleMode; quote: SaleQuote }
  | null

const CATEGORY_META: Record<AssetCategory, { label: string }> = {
  watch: { label: 'Watches' },
  jewelry: { label: 'Jewelry' },
  car: { label: 'Cars' },
  apartment: { label: 'Apartments' },
  house_villa: { label: 'Houses & Villas' },
  yacht: { label: 'Yachts' },
  private_jet: { label: 'Private Jets' },
  art: { label: 'Art' },
  collectible: { label: 'Collectibles' },
}

const GAME_MONTHS = [
  ['January', 31], ['February', 29], ['March', 31], ['April', 30],
  ['May', 31], ['June', 30], ['July', 31], ['August', 31],
  ['September', 30], ['October', 31], ['November', 30], ['December', 31],
] as const

const ASSET_HISTORY_PAGE_SIZE = 10

const SALE_META: Record<SaleMode, { label: string; detail: string }> = {
  urgent: { label: 'Sell now', detail: 'Immediate sale · lowest payout' },
  standard: { label: 'Standard sale', detail: '7 game days · normal payout' },
  patient: { label: 'Best-price sale', detail: '21 game days · highest payout' },
}

function money(value: number, currency = 'USD') {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
    maximumFractionDigits: 0,
  }).format(Number(value || 0))
}

function categoryLabel(category: AssetCategory) {
  return CATEGORY_META[category]?.label ?? category
}

function rarityLabel(rarity: string) {
  return rarity.replaceAll('_', ' ')
}

function trendText(rateBps: number) {
  if (rateBps === 0) return 'Stable'
  const percent = Math.abs(rateBps) / 100
  return `${rateBps > 0 ? '+' : '-'}${percent.toFixed(percent % 1 === 0 ? 0 : 1)}% / year`
}

function marketMoveText(rateBps: number | null | undefined) {
  if (rateBps === null || rateBps === undefined || !Number.isFinite(Number(rateBps))) return 'No monthly move yet'
  const numeric = Number(rateBps)
  if (numeric === 0) return 'Stable this month'
  const percent = Math.abs(numeric) / 100
  return `${numeric > 0 ? '+' : '-'}${percent.toFixed(percent % 1 === 0 ? 0 : 1)}% this month`
}

function gameDayLabel(absoluteDay: number | null | undefined) {
  const raw = Number(absoluteDay)
  if (!Number.isFinite(raw) || raw < 0) return 'Game date unavailable'
  const totalDays = Math.floor(raw)
  const season = Math.floor(totalDays / 366) + 1
  let dayIndex = totalDays % 366
  let monthName = 'January'
  let day = 1
  for (const [name, days] of GAME_MONTHS) {
    if (dayIndex < days) {
      monthName = name
      day = dayIndex + 1
      break
    }
    dayIndex -= days
  }
  return `Season ${season} · ${monthName} ${day}`
}


function assetTransactionLabel(type: string) {
  if (type === 'starter_home') return 'Starting residence'
  if (type === 'purchase') return 'Purchase'
  if (type === 'sale') return 'Sale'
  if (type === 'running_cost') return 'Ownership cost'
  return type.replaceAll('_', ' ')
}

function assetTransactionAmount(row: AssetHistoryRow, currency: string) {
  const amount = Number(row.amount || 0)
  if (row.transaction_type === 'starter_home') return `Value ${money(Math.abs(amount), currency)}`
  const prefix = amount > 0 ? '+' : amount < 0 ? '−' : ''
  return `${prefix}${money(Math.abs(amount), currency)}`
}

function matchesPriceBand(price: number, band: MarketplacePrice) {
  if (band === 'under_10k') return price < 10000
  if (band === '10k_50k') return price >= 10000 && price < 50000
  if (band === '50k_250k') return price >= 50000 && price < 250000
  if (band === '250k_1m') return price >= 250000 && price < 1000000
  if (band === '1m_5m') return price >= 1000000 && price < 5000000
  if (band === '5m_plus') return price >= 5000000
  return true
}

function metadataNumber(asset: CatalogAsset, key: string, fallback: number) {
  const numeric = Number(asset.metadata?.[key])
  return Number.isFinite(numeric) ? numeric : fallback
}

function monthlyOwnershipCost(category: AssetCategory, value: number) {
  const price = Math.max(0, Number(value || 0))
  if (category === 'car') return Math.max(150, Math.round(price * 0.006))
  if (category === 'apartment') return Math.max(1000, Math.round(price * 0.01))
  if (category === 'house_villa') return Math.max(1500, Math.round(price * 0.01))
  if (category === 'yacht') return Math.max(2500, Math.round(price * 0.008))
  if (category === 'private_jet') return Math.max(15000, Math.round(price * 0.0075))
  return 0
}

function ownershipCostLabel(category: AssetCategory) {
  if (category === 'apartment' || category === 'house_villa') return 'Monthly living cost'
  if (category === 'car' || category === 'yacht' || category === 'private_jet') return 'Monthly maintenance'
  return 'Maintenance'
}

const privateLifeImageUrlCache = new Map<string, string>()

function parsePrivateStorageSource(src: string) {
  if (!src.startsWith('storage://')) return null
  const source = src.slice('storage://'.length)
  const slashIndex = source.indexOf('/')
  if (slashIndex <= 0 || slashIndex >= source.length - 1) return null
  return {
    bucket: source.slice(0, slashIndex),
    path: source.slice(slashIndex + 1),
  }
}

function AssetImage({ src, name }: { src: string; name: string }) {
  const storageSource = useMemo(() => parsePrivateStorageSource(src), [src])
  const [resolvedSrc, setResolvedSrc] = useState(() => {
    if (!storageSource) return src
    return privateLifeImageUrlCache.get(src) || ''
  })

  useEffect(() => {
    let cancelled = false

    if (!storageSource) {
      setResolvedSrc(src)
      return () => {
        cancelled = true
      }
    }

    const cachedUrl = privateLifeImageUrlCache.get(src)
    if (cachedUrl) {
      setResolvedSrc(cachedUrl)
      return () => {
        cancelled = true
      }
    }

    setResolvedSrc('')
    void supabase.storage
      .from(storageSource.bucket)
      .createSignedUrl(storageSource.path, 60 * 60 * 24)
      .then(({ data, error }) => {
        if (cancelled) return
        if (error || !data?.signedUrl) {
          setResolvedSrc('')
          return
        }
        privateLifeImageUrlCache.set(src, data.signedUrl)
        setResolvedSrc(data.signedUrl)
      })

    return () => {
      cancelled = true
    }
  }, [src, storageSource])

  return (
    <img
      src={resolvedSrc || undefined}
      alt={name}
      loading="lazy"
      style={resolvedSrc ? undefined : { opacity: 0 }}
      onError={(event) => {
        event.currentTarget.style.opacity = '0'
      }}
    />
  )
}

export default function PrivateLifePage() {
  const navigate = useNavigate()
  const { isPremium, loading: commerceLoading } = useCommerce()
  const [dashboard, setDashboard] = useState<PrivateLifeDashboard | null>(null)
  const [loading, setLoading] = useState(false)
  const [actionBusy, setActionBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [tab, setTab] = useState<MainTab>('overview')
  const [filter, setFilter] = useState<CategoryFilter>('all')
  const [pendingAction, setPendingAction] = useState<PendingAction>(null)
  const [marketSearch, setMarketSearch] = useState('')
  const [marketPrice, setMarketPrice] = useState<MarketplacePrice>('all')
  const [marketRarity, setMarketRarity] = useState<MarketplaceRarity>('all')
  const [marketSort, setMarketSort] = useState<MarketplaceSort>('default')
  const [marketAffordableOnly, setMarketAffordableOnly] = useState(false)
  const [propertyCountry, setPropertyCountry] = useState('')
  const [propertyLocationCode, setPropertyLocationCode] = useState('')
  const [assetHistory, setAssetHistory] = useState<AssetHistoryRow[]>([])
  const [showAssetHistory, setShowAssetHistory] = useState(false)
  const [assetHistoryLoading, setAssetHistoryLoading] = useState(false)
  const [assetHistoryPage, setAssetHistoryPage] = useState(1)
  const [assetHistoryError, setAssetHistoryError] = useState<string | null>(null)

  const loadDashboard = useCallback(async () => {
    if (!isPremium) return
    setLoading(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('get_private_life_dashboard_v1')
    if (rpcError) {
      setError(rpcError.message)
      setLoading(false)
      return
    }
    setDashboard(data as unknown as PrivateLifeDashboard)
    setLoading(false)
  }, [isPremium])

  useEffect(() => {
    if (!commerceLoading && isPremium) void loadDashboard()
  }, [commerceLoading, isPremium, loadDashboard])

  useEffect(() => {
    if (!dashboard || propertyCountry || propertyLocationCode) return
    const starter = dashboard.owned_assets.find((asset) => asset.acquisition_type === 'starter_home' && asset.location_code)
    const homeLocation = starter?.location_code ? dashboard.property_locations.find((location) => location.code === starter.location_code) : undefined
    const firstLocation = homeLocation ?? dashboard.property_locations[0]
    if (firstLocation) {
      setPropertyCountry(firstLocation.country_code)
      setPropertyLocationCode(firstLocation.code)
    }
  }, [dashboard, propertyCountry, propertyLocationCode])

  const countries = useMemo(() => {
    const rows = dashboard?.property_locations ?? []
    const map = new Map<string, string>()
    rows.forEach((location) => map.set(location.country_code, location.country_name))
    return [...map.entries()].map(([code, name]) => ({ code, name })).sort((a, b) => a.name.localeCompare(b.name))
  }, [dashboard?.property_locations])

  const countryLocations = useMemo(() => {
    const rows = dashboard?.property_locations ?? []
    return rows.filter((location) => !propertyCountry || location.country_code === propertyCountry)
  }, [dashboard?.property_locations, propertyCountry])

  useEffect(() => {
    if (!propertyCountry || !countryLocations.length) return
    if (!countryLocations.some((location) => location.code === propertyLocationCode)) setPropertyLocationCode(countryLocations[0].code)
  }, [countryLocations, propertyCountry, propertyLocationCode])

  const selectedPropertyLocation = useMemo(
    () => dashboard?.property_locations.find((location) => location.code === propertyLocationCode),
    [dashboard?.property_locations, propertyLocationCode],
  )

  const marketplaceListings = useMemo<MarketplaceListing[]>(() => {
    const source = dashboard?.catalog ?? []
    return source.flatMap((asset) => {
      const isProperty = Boolean(asset.location_priced || asset.metadata?.location_priced)
      if (!isProperty) {
        const annualCost = monthlyOwnershipCost(asset.category, Number(asset.purchase_price)) * 12
        return [{
          ...asset,
          effective_price: Number(asset.purchase_price),
          effective_annual_cost: annualCost,
          effective_value_rate_bps: Number(asset.annual_value_rate_bps),
          effective_affordable: Boolean(asset.affordable),
          effective_owned: Boolean(asset.owned),
          effective_market_change_bps: asset.market_monthly_change_bps ?? null,
        }]
      }
      if (!selectedPropertyLocation) return []
      const basePrice = asset.category === 'apartment' ? selectedPropertyLocation.apartment_base_price : selectedPropertyLocation.house_base_price
      const multiplier = metadataNumber(asset, 'price_multiplier_bps', 10000)
      const valueAdjustment = metadataNumber(asset, 'value_rate_adjustment_bps', 0)
      const price = Math.round(basePrice * multiplier / 10000)
      const annualCost = monthlyOwnershipCost(asset.category, price) * 12
      const valueRate = selectedPropertyLocation.annual_value_rate_bps + valueAdjustment
      const alreadyOwned = (dashboard?.owned_assets ?? []).some((owned) => owned.catalog_code === asset.code && owned.location_code === selectedPropertyLocation.code)
      return [{
        ...asset,
        effective_price: price,
        effective_annual_cost: annualCost,
        effective_value_rate_bps: valueRate,
        effective_affordable: price <= Number(dashboard?.cash_balance ?? 0),
        effective_owned: alreadyOwned,
        effective_market_change_bps: selectedPropertyLocation.monthly_change_bps ?? null,
        location: selectedPropertyLocation,
      }]
    })
  }, [dashboard?.catalog, dashboard?.cash_balance, dashboard?.owned_assets, selectedPropertyLocation])

  const visibleCatalog = useMemo(() => {
    const search = marketSearch.trim().toLowerCase()
    const filtered = marketplaceListings.filter((listing) => {
      if (filter !== 'all' && listing.category !== filter) return false
      const locationText = listing.location ? `${listing.location.city} ${listing.location.country_name}` : ''
      if (search && !`${listing.name} ${listing.description} ${categoryLabel(listing.category)} ${locationText}`.toLowerCase().includes(search)) return false
      if (!matchesPriceBand(listing.effective_price, marketPrice)) return false
      if (marketRarity !== 'all' && listing.rarity !== marketRarity) return false
      if (marketAffordableOnly && (!listing.effective_affordable || listing.effective_owned)) return false
      return true
    })
    return [...filtered].sort((a, b) => {
      if (marketSort === 'price_asc') return a.effective_price - b.effective_price
      if (marketSort === 'price_desc') return b.effective_price - a.effective_price
      if (marketSort === 'prestige_desc') return b.prestige - a.prestige || a.effective_price - b.effective_price
      if (marketSort === 'appreciation_desc') return Number(b.effective_market_change_bps ?? -9999) - Number(a.effective_market_change_bps ?? -9999) || b.effective_value_rate_bps - a.effective_value_rate_bps || a.effective_price - b.effective_price
      return 0
    })
  }, [filter, marketAffordableOnly, marketPrice, marketRarity, marketSearch, marketSort, marketplaceListings])

  const visibleOwned = useMemo(() => {
    const source = dashboard?.owned_assets ?? []
    if (filter === 'all') return source
    return source.filter((asset) => asset.category === filter)
  }, [dashboard?.owned_assets, filter])

  const availableResidenceCount = useMemo(
    () => (dashboard?.owned_assets ?? []).filter((asset) => (asset.category === 'apartment' || asset.category === 'house_villa') && !asset.pending_sale).length,
    [dashboard?.owned_assets],
  )

  async function toggleAssetHistory() {
    if (showAssetHistory) {
      setShowAssetHistory(false)
      return
    }
    setShowAssetHistory(true)
    setAssetHistoryPage(1)
    if (assetHistory.length > 0) return
    setAssetHistoryLoading(true)
    setAssetHistoryError(null)
    const { data, error: rpcError } = await supabase.rpc('get_private_life_asset_transaction_history_v1')
    if (rpcError) setAssetHistoryError(rpcError.message)
    else setAssetHistory(Array.isArray(data) ? data as unknown as AssetHistoryRow[] : [])
    setAssetHistoryLoading(false)
  }

  async function cancelSale(listingId: string) {
    setActionBusy(true)
    setError(null)
    const { error: rpcError } = await supabase.rpc('cancel_private_life_asset_sale_v1', { p_listing_id: listingId })
    if (rpcError) setError(rpcError.message)
    else setNotice('Sale listing cancelled. The asset remains in your collection.')
    setActionBusy(false)
    await loadDashboard()
  }

  async function confirmAction() {
    if (!pendingAction) return
    setActionBusy(true)
    setError(null)
    setNotice(null)

    if (pendingAction.type === 'buy') {
      const listing = pendingAction.listing
      const { error: rpcError } = await supabase.rpc('buy_private_life_asset_v2', {
        p_catalog_code: listing.code,
        p_location_code: listing.location?.code ?? null,
      })
      if (rpcError) {
        setError(rpcError.message)
        setActionBusy(false)
        setPendingAction(null)
        return
      }
      setNotice(`${listing.name}${listing.location ? ` in ${listing.location.city}` : ''} is now part of your private collection. The payment was posted to Finance.`)
    } else {
      const { asset, saleMode } = pendingAction
      const { data, error: rpcError } = await supabase.rpc('list_private_life_asset_for_sale_v1', {
        p_owned_asset_id: asset.id,
        p_sale_mode: saleMode,
      })
      if (rpcError) {
        setError(rpcError.message)
        setActionBusy(false)
        setPendingAction(null)
        return
      }
      const result = data as { status?: string; wait_days?: number; quoted_sale_price?: number; sale_price?: number } | null
      if (result?.status === 'sold') setNotice(`${asset.name} was sold immediately. ${money(Number(result.sale_price ?? pendingAction.quote.price), dashboard?.currency ?? 'USD')} was posted to Finance.`)
      else setNotice(`${asset.name} is listed for sale. Expected settlement in ${Number(result?.wait_days ?? pendingAction.quote.wait_days)} game days.`)
    }

    setPendingAction(null)
    setActionBusy(false)
    await loadDashboard()
  }

  if (commerceLoading) {
    return <GameLayout title="Private Life" subtitle="Lifestyle, assets and personal wealth"><div className="tlg-premium-lock"><span>Checking Premium membership…</span></div></GameLayout>
  }

  if (!isPremium) {
    return (
      <GameLayout title="Private Life" subtitle="Lifestyle, assets and personal wealth">
        <section className="tlg-premium-lock">
          <div className="tlg-premium-lock-icon"><LockKeyhole size={28} /></div>
          <span>Premium feature</span><h2>Private Life</h2>
          <p>Build an off-court lifestyle with the money earned in your tennis career. Purchases and investments use the same Finance balance — never Premium coins.</p>
          <button type="button" onClick={() => navigate('/game/pro-packages')}><Crown size={16} /> View Premium</button>
        </section>
      </GameLayout>
    )
  }

  if (loading && !dashboard) {
    return <GameLayout title="Private Life" subtitle="Lifestyle, assets and personal wealth"><div className="private-life-loading"><RefreshCw size={20} /> Loading your private-life portfolio…</div></GameLayout>
  }

  if (error && !dashboard) {
    return (
      <GameLayout title="Private Life" subtitle="Lifestyle, assets and personal wealth">
        <div className="private-life-error"><strong>Private Life could not be loaded</strong><p>{error}</p><button className="private-life-refresh" type="button" onClick={() => void loadDashboard()}><RefreshCw size={14} /> Try again</button></div>
      </GameLayout>
    )
  }

  if (!dashboard) return null

  const currency = dashboard.currency || 'USD'
  const categoryTotals = new Map(dashboard.category_totals.map((row) => [row.category, row]))

  const confirmation = pendingAction
    ? pendingAction.type === 'buy'
      ? {
          eyebrow: 'Private Life purchase',
          title: `Buy ${pendingAction.listing.name}${pendingAction.listing.location ? ` in ${pendingAction.listing.location.city}` : ''}?`,
          hero: <AssetImage src={pendingAction.listing.image_url} name={pendingAction.listing.name} />,
          size: 'wide' as const,
          message: (
            <div className="private-life-purchase-copy">
              <p>{pendingAction.listing.description}</p>
              {pendingAction.listing.location ? (
                <div className="private-life-purchase-location">
                  {pendingAction.listing.location.city}, {pendingAction.listing.location.country_name}
                </div>
              ) : null}
            </div>
          ),
          detail: (
            <div className="private-life-purchase-summary">
              <div className="private-life-purchase-price-row">
                <span>Purchase price</span>
                <strong>{money(pendingAction.listing.effective_price, currency)}</strong>
              </div>
              <div className="private-life-purchase-info-grid">
                <div><span>Category</span><strong>{categoryLabel(pendingAction.listing.category)}</strong></div>
                <div><span>Rarity</span><strong>{rarityLabel(pendingAction.listing.rarity)}</strong></div>
                <div><span>Prestige points</span><strong>+{pendingAction.listing.prestige}</strong></div>
                <div><span>Monthly market move</span><strong className={Number(pendingAction.listing.effective_market_change_bps ?? 0) < 0 ? 'private-life-trend-negative' : Number(pendingAction.listing.effective_market_change_bps ?? 0) > 0 ? 'private-life-trend-positive' : ''}>{marketMoveText(pendingAction.listing.effective_market_change_bps)}</strong></div>
                <div><span>{ownershipCostLabel(pendingAction.listing.category)}</span><strong>{pendingAction.listing.effective_annual_cost > 0 ? money(pendingAction.listing.effective_annual_cost / 12, currency) : 'None'}</strong></div>
                <div><span>Annual ownership cost</span><strong>{pendingAction.listing.effective_annual_cost > 0 ? money(pendingAction.listing.effective_annual_cost, currency) : 'None'}</strong></div>
                <div><span>Annual value trend</span><strong className={pendingAction.listing.effective_value_rate_bps < 0 ? 'private-life-trend-negative' : pendingAction.listing.effective_value_rate_bps > 0 ? 'private-life-trend-positive' : ''}>{trendText(pendingAction.listing.effective_value_rate_bps)}</strong></div>
                <div><span>Finance balance after purchase</span><strong>{money(dashboard.cash_balance - pendingAction.listing.effective_price, currency)}</strong></div>
              </div>
              <div className="private-life-purchase-finance-note">
                {money(pendingAction.listing.effective_price, currency)} will be taken from your normal career Finance balance. Private Life purchases never use Premium coins.
              </div>
            </div>
          ),
          confirmLabel: `Buy for ${money(pendingAction.listing.effective_price, currency)}`,
          tone: 'warning' as const,
        }
      : {
          eyebrow: 'Sell private asset',
          title: `${SALE_META[pendingAction.saleMode].label}: ${pendingAction.asset.name}?`,
          hero: null,
          size: 'default' as const,
          message: `${money(pendingAction.quote.price, currency)} is the current game sale quote.`,
          detail: `${SALE_META[pendingAction.saleMode].detail} · Current market value ${money(pendingAction.asset.current_market_value, currency)} · Original value ${money(pendingAction.asset.purchase_price, currency)}.`,
          confirmLabel: pendingAction.saleMode === 'urgent' ? `Sell now for ${money(pendingAction.quote.price, currency)}` : `List for ${money(pendingAction.quote.price, currency)}`,
          tone: 'danger' as const,
        }
    : null

  return (
    <GameLayout title="Private Life" subtitle="Lifestyle, assets and personal wealth">
      <div className="private-life-page">
        <section className="private-life-hero private-life-hero-compact">
          <div className="private-life-hero-copy">
            <div className="private-life-eyebrow">Your life outside tennis</div>
            <h2>Build wealth, collect assets and grow your prestige.</h2>
            <p>Every owned asset contributes prestige points. There are no prestige levels — your total is simply the sum of the prestige points attached to the things you currently own.</p>
          </div>
          <div className="private-life-prestige-banner"><span>Prestige points</span><strong>{dashboard.prestige.toLocaleString()}</strong><small>From currently owned assets</small></div>
        </section>

        <section className="private-life-metrics" aria-label="Private wealth summary">
          <div className="private-life-metric"><span>Cash balance</span><strong>{money(dashboard.cash_balance, currency)}</strong></div>
          <div className="private-life-metric"><span>Physical assets</span><strong>{money(dashboard.asset_value, currency)}</strong></div>
          <div className="private-life-metric"><span>Investments</span><strong>{money(dashboard.investment_value, currency)}</strong></div>
          <div className="private-life-metric"><span>Current net worth</span><strong>{money(dashboard.net_worth, currency)}</strong></div>
          <div className="private-life-metric"><span>Prestige points</span><strong>{dashboard.prestige}</strong></div>
          <div className="private-life-metric"><span>Monthly ownership cost</span><strong>{money(dashboard.annual_running_cost / 12, currency)}</strong></div>
        </section>

        <nav className="private-life-tabs" aria-label="Private Life sections">
          <button className={tab === 'overview' ? 'active' : ''} type="button" onClick={() => setTab('overview')}>Overview</button>
          <button className={tab === 'assets' ? 'active' : ''} type="button" onClick={() => setTab('assets')}>Collection ({dashboard.owned_assets.length})</button>
          <button className={tab === 'investments' ? 'active' : ''} type="button" onClick={() => setTab('investments')}>Investments</button>
          <button className={tab === 'marketplace' ? 'active' : ''} type="button" onClick={() => setTab('marketplace')}>Marketplace</button>
        </nav>

        {notice ? <div className="private-life-notice"><span>{notice}</span></div> : null}
        {error ? <div className="private-life-error"><strong>Action could not be completed</strong><p>{error}</p></div> : null}

        {tab === 'overview' ? (
          <section className="private-life-section">
            <div className="private-life-section-head">
              <div><div className="private-life-section-eyebrow">Private Life dashboard</div><h3>Your off-court world</h3><p>Prestige, physical assets and investments all live here, while Finance remains the source of truth for money.</p></div>
              <button type="button" className="private-life-refresh" disabled={loading} onClick={() => void loadDashboard()}><RefreshCw size={14} /> {loading ? 'Refreshing…' : 'Refresh'}</button>
            </div>
            <div className="private-life-overview-grid">
              <div className="private-life-panel">
                <h4>Physical collection</h4>
                <div className="private-life-category-list">
                  {(Object.keys(CATEGORY_META) as AssetCategory[]).map((category) => {
                    const total = categoryTotals.get(category)
                    return <div key={category} className="private-life-category-row"><div className="private-life-category-name"><span>{CATEGORY_META[category].label}</span></div><span>{total?.owned_count ?? 0} owned</span><strong>{money(total?.market_value ?? 0, currency)}</strong><span>+{total?.prestige ?? 0} prestige pts</span></div>
                  })}
                </div>
              </div>
              <div className="private-life-future-stack">
                <article className="private-life-future-card private-life-investment-preview"><div className="private-life-future-card-head"><h4>Investments</h4><span className="private-life-status-pill active">Active</span></div><p>Trade simulated stocks and cryptocurrencies with your career cash. External market quotes provide the game reference price.</p><button type="button" className="private-life-inline-action" onClick={() => setTab('investments')}>Open investments</button></article>
                <article className="private-life-future-card"><div className="private-life-future-card-head"><h4>Residence rule</h4></div><p>You must always keep at least one apartment, house or villa. A residence cannot be sold until another residence is available.</p><small>Property living costs are charged monthly through the career Finance ledger.</small></article>
                <article className="private-life-future-card"><div className="private-life-future-card-head"><h4>Ownership costs</h4></div><p>Vehicles, homes, yachts and private jets carry recurring monthly costs. Watches, jewelry, art and collectibles do not.</p><small>Higher-value assets have higher maintenance or living costs.</small></article>
              </div>
            </div>
          </section>
        ) : null}

        {tab === 'assets' ? (
          <section className="private-life-section">
            <div className="private-life-section-head"><div><div className="private-life-section-eyebrow">Collection</div><h3>My physical assets</h3><p>Track current value, prestige points, monthly ownership costs and choose how quickly you want to sell each possession.</p></div><button type="button" className="private-life-refresh" onClick={() => void toggleAssetHistory()}>Transaction history</button></div>
            <CategoryFilters value={filter} onChange={setFilter} />

            {showAssetHistory ? (
              <div className="private-life-asset-history" role="dialog" aria-modal="true" aria-labelledby="private-life-transaction-history-title">
                <div className="private-life-asset-history-head">
                  <div><strong id="private-life-transaction-history-title">Transaction history</strong><span>Every physical-asset purchase, sale and ownership charge in game-date order.</span></div>
                  <button type="button" className="private-life-asset-history-close" aria-label="Close transaction history" onClick={() => setShowAssetHistory(false)}>×</button>
                </div>
                {assetHistoryLoading ? <div className="private-life-asset-history-state">Loading transaction history…</div> : assetHistoryError ? <div className="private-life-asset-history-state error">{assetHistoryError}</div> : assetHistory.length === 0 ? <div className="private-life-asset-history-state">No asset transactions yet.</div> : (
                  <div className="private-life-asset-history-table-wrap">
                    <table className="private-life-asset-history-table">
                      <thead><tr><th>Game date</th><th>Transaction</th><th>Asset</th><th>Amount</th><th>Details</th></tr></thead>
                      <tbody>{assetHistory.slice((assetHistoryPage - 1) * ASSET_HISTORY_PAGE_SIZE, assetHistoryPage * ASSET_HISTORY_PAGE_SIZE).map((row) => {
                        const amount = Number(row.amount || 0)
                        const amountTone = row.transaction_type === 'starter_home' ? 'neutral' : amount > 0 ? 'positive' : amount < 0 ? 'negative' : 'neutral'
                        return (
                          <tr key={row.id}>
                            <td><strong>{gameDayLabel(row.event_absolute_day)}</strong></td>
                            <td><span className={`private-life-asset-history-type ${row.transaction_type}`}>{assetTransactionLabel(row.transaction_type)}</span></td>
                            <td><strong>{row.name}</strong><span>{categoryLabel(row.category)}{row.city && row.country_name ? ` · ${row.city}, ${row.country_name}` : ''}</span></td>
                            <td><strong className={`private-life-asset-history-amount ${amountTone}`}>{assetTransactionAmount(row, currency)}</strong></td>
                            <td><strong>{row.transaction_type === 'starter_home' ? 'Starting residence assigned' : row.title}</strong><span>{row.transaction_type === 'starter_home' ? 'Initial home value; not a marketplace purchase.' : row.description}</span></td>
                          </tr>
                        )
                      })}</tbody>
                    </table>
                  </div>
                )}
                {assetHistory.length > ASSET_HISTORY_PAGE_SIZE ? (
                  <div className="private-life-asset-history-pagination">
                    <button type="button" disabled={assetHistoryPage <= 1} onClick={() => setAssetHistoryPage((page) => Math.max(1, page - 1))}>Previous</button>
                    <span>Page <strong>{assetHistoryPage}</strong> of {Math.ceil(assetHistory.length / ASSET_HISTORY_PAGE_SIZE)} · 10 transactions per page</span>
                    <button type="button" disabled={assetHistoryPage >= Math.ceil(assetHistory.length / ASSET_HISTORY_PAGE_SIZE)} onClick={() => setAssetHistoryPage((page) => Math.min(Math.ceil(assetHistory.length / ASSET_HISTORY_PAGE_SIZE), page + 1))}>Next</button>
                  </div>
                ) : null}
              </div>
            ) : null}
            {visibleOwned.length === 0 ? <div className="private-life-empty"><strong>No assets in this category yet</strong><p>Visit the Marketplace to start building your private collection.</p></div> : (
              <div className="private-life-owned-grid">
                {visibleOwned.map((asset) => {
                  const isResidence = asset.category === 'apartment' || asset.category === 'house_villa'
                  const canSellResidence = !isResidence || availableResidenceCount >= 2
                  return (
                    <article className="private-life-owned-card" key={asset.id}>
                      <div className="private-life-card-image"><AssetImage src={asset.image_url} name={asset.name} /><div className="private-life-image-badges"><span className="private-life-badge">{rarityLabel(asset.rarity)}</span><span className="private-life-badge level">+{asset.prestige} prestige pts</span></div></div>
                      <div className="private-life-card-body">
                        <div className="private-life-card-title-row"><h4>{asset.name}</h4><div className="private-life-price">{money(asset.current_market_value, currency)}</div></div>
                        {asset.acquisition_type === 'starter_home' ? <div className="private-life-starter-home-label">Starting home residence</div> : null}
                        <p className="private-life-description">{asset.description}</p>
                        <div className="private-life-owned-value-grid">
                          <div className="private-life-owned-value-row"><span>Original value</span><strong>{money(asset.purchase_price, currency)}</strong></div>
                          <div className="private-life-owned-value-row"><span>Current market value</span><strong>{money(asset.current_market_value, currency)}</strong></div>
                          <div className="private-life-owned-value-row"><span>Prestige points</span><strong>+{asset.prestige}</strong></div>
                          <div className="private-life-owned-value-row"><span>Ownership</span><strong>{asset.ownership_days} game days</strong></div>
                          <div className="private-life-owned-value-row"><span>{ownershipCostLabel(asset.category)}</span><strong>{asset.annual_running_cost > 0 ? money(asset.annual_running_cost / 12, currency) : 'None'}</strong></div>
                          <div className="private-life-owned-value-row"><span>Market move</span><strong className={Number(asset.property_monthly_change_bps ?? asset.asset_monthly_change_bps ?? 0) < 0 ? 'private-life-trend-negative' : Number(asset.property_monthly_change_bps ?? asset.asset_monthly_change_bps ?? 0) > 0 ? 'private-life-trend-positive' : ''}>{marketMoveText(asset.property_monthly_change_bps ?? asset.asset_monthly_change_bps)}</strong></div>
                        </div>
                        {asset.pending_sale ? (
                          <div className="private-life-sale-pending"><div><span>Listed for sale</span><strong>{SALE_META[asset.pending_sale.sale_mode].label} · {money(asset.pending_sale.quoted_sale_price, currency)}</strong><small>Settlement game day {asset.pending_sale.settle_absolute_day}</small></div><button type="button" disabled={actionBusy} onClick={() => void cancelSale(asset.pending_sale!.id)}>Cancel sale</button></div>
                        ) : canSellResidence ? (
                          <div className="private-life-sale-options">
                            {(Object.keys(SALE_META) as SaleMode[]).map((mode) => {
                              const quote = asset.sale_quotes?.[mode]
                              if (!quote) return null
                              return <button key={mode} type="button" onClick={() => setPendingAction({ type: 'sell', asset, saleMode: mode, quote })}><span>{SALE_META[mode].label}</span><strong>{money(quote.price, currency)}</strong><small>{SALE_META[mode].detail}</small></button>
                            })}
                          </div>
                        ) : (
                          <div className="private-life-residence-lock"><strong>Primary residence</strong><span>Buy another apartment, house or villa before selling this residence.</span></div>
                        )}
                      </div>
                    </article>
                  )
                })}
              </div>
            )}
          </section>
        ) : null}

        {tab === 'investments' ? <PrivateLifeInvestments currency={currency} onPortfolioChanged={loadDashboard} /> : null}

        {tab === 'marketplace' ? (
          <section className="private-life-section">
            <div className="private-life-section-head">
              <div><div className="private-life-section-eyebrow">Luxury marketplace</div><h3>Buy physical assets</h3><p>Every item has a game price, value trend and prestige-point value. Property prices depend on the selected country and city.</p></div>
              <span className="private-life-market-new-pill">New items</span>
            </div>
            <CategoryFilters value={filter} onChange={setFilter} />

            {(filter === 'apartment' || filter === 'house_villa') ? (
              <div className="private-life-property-selector">
                <div><span>Property country</span><select value={propertyCountry} onChange={(event) => {
                  const countryCode = event.target.value
                  const firstLocation = dashboard.property_locations.find((location) => location.country_code === countryCode)
                  setPropertyCountry(countryCode)
                  setPropertyLocationCode(firstLocation?.code ?? '')
                }}>{countries.map((country) => <option key={country.code} value={country.code}>{country.name}</option>)}</select></div>
                <div><span>City</span><select value={propertyLocationCode} onChange={(event) => setPropertyLocationCode(event.target.value)}>{countryLocations.map((location) => <option key={location.code} value={location.code}>{location.city}</option>)}</select></div>
              </div>
            ) : null}

            <div className="private-life-marketplace-tools">
              <input value={marketSearch} onChange={(event) => setMarketSearch(event.target.value)} placeholder="Search assets" aria-label="Search marketplace assets" />
              <select value={marketPrice} onChange={(event) => setMarketPrice(event.target.value as MarketplacePrice)} aria-label="Marketplace price filter"><option value="all">All prices</option><option value="under_10k">Under $10K</option><option value="10k_50k">$10K – $50K</option><option value="50k_250k">$50K – $250K</option><option value="250k_1m">$250K – $1M</option><option value="1m_5m">$1M – $5M</option><option value="5m_plus">$5M+</option></select>
              <select value={marketRarity} onChange={(event) => setMarketRarity(event.target.value as MarketplaceRarity)} aria-label="Marketplace rarity filter"><option value="all">All rarities</option><option value="common">Common</option><option value="uncommon">Uncommon</option><option value="rare">Rare</option><option value="very_rare">Very rare</option><option value="legendary">Legendary</option></select>
              <select value={marketSort} onChange={(event) => setMarketSort(event.target.value as MarketplaceSort)} aria-label="Marketplace sort order"><option value="default">Default order</option><option value="price_asc">Price: low to high</option><option value="price_desc">Price: high to low</option><option value="prestige_desc">Prestige: high to low</option><option value="appreciation_desc">Best market move</option></select>
              <label className="private-life-marketplace-affordable"><input type="checkbox" checked={marketAffordableOnly} onChange={(event) => setMarketAffordableOnly(event.target.checked)} /><span>Affordable only</span></label>
              <button type="button" className="private-life-marketplace-reset" onClick={() => { setMarketSearch(''); setMarketPrice('all'); setMarketRarity('all'); setMarketSort('default'); setMarketAffordableOnly(false); setFilter('all') }}>Reset</button>
            </div>
            <div className="private-life-marketplace-results"><span>{visibleCatalog.length} listings</span><span>{dashboard.catalog.length} base asset types · 50 property destinations</span></div>
            {visibleCatalog.length === 0 ? <div className="private-life-empty"><strong>No marketplace matches</strong><p>Change the category, destination, price or rarity filters to see more assets.</p></div> : (
              <div className="private-life-market-grid">
                {visibleCatalog.map((listing) => {
                  const marketMove = listing.effective_market_change_bps
                  const isPositive = Number(marketMove ?? 0) > 0
                  const canBuy = listing.effective_affordable && !listing.effective_owned
                  return (
                    <article className="private-life-card" key={`${listing.code}:${listing.location?.code ?? 'global'}`}>
                      <div className="private-life-card-image"><AssetImage src={listing.image_url} name={listing.name} /><div className="private-life-image-badges"><span className="private-life-badge">{rarityLabel(listing.rarity)}</span><span className="private-life-badge new">New</span></div></div>
                      <div className="private-life-card-body">
                        <div className="private-life-card-title-row"><h4>{listing.name}</h4><div className="private-life-price">{money(listing.effective_price, currency)}</div></div>
                        {listing.location ? <div className="private-life-property-location">{listing.location.city}, {listing.location.country_name}</div> : null}
                        <p className="private-life-description">{listing.description}</p>
                        <div className="private-life-card-stats">
                          <div className="private-life-card-stat"><span>Prestige points</span><strong>+{listing.prestige}</strong></div>
                          <div className="private-life-card-stat"><span>{ownershipCostLabel(listing.category)}</span><strong>{listing.effective_annual_cost > 0 ? money(listing.effective_annual_cost / 12, currency) : 'None'}</strong></div>
                          <div className="private-life-card-stat"><span>Market move</span><strong className={Number(marketMove ?? 0) < 0 ? 'private-life-trend-negative' : isPositive ? 'private-life-trend-positive' : ''}>{Number(marketMove ?? 0) < 0 ? <TrendingDown size={12} /> : isPositive ? <TrendingUp size={12} /> : null} {marketMoveText(marketMove)}</strong></div>
                          <div className="private-life-card-stat"><span>Category</span><strong>{categoryLabel(listing.category)}</strong></div>
                        </div>
                        <button type="button" className="private-life-action" disabled={!canBuy} onClick={() => setPendingAction({ type: 'buy', listing })}>{listing.effective_owned ? 'Already owned here' : !listing.effective_affordable ? 'Insufficient funds' : 'Purchase asset'}</button>
                      </div>
                    </article>
                  )
                })}
              </div>
            )}
          </section>
        ) : null}

        <div className="private-life-notice"><span>Private Life uses your existing career Finance account. Prestige is a point total from currently owned assets; there are no prestige levels and no direct tennis-skill bonuses.</span></div>
      </div>

      <GameConfirmDialog open={Boolean(confirmation)} eyebrow={confirmation?.eyebrow} title={confirmation?.title ?? ''} hero={confirmation?.hero} size={confirmation?.size} message={confirmation?.message ?? ''} detail={confirmation?.detail} confirmLabel={confirmation?.confirmLabel} cancelLabel="Cancel" busy={actionBusy} tone={confirmation?.tone} onConfirm={confirmAction} onCancel={() => { if (!actionBusy) setPendingAction(null) }} />
    </GameLayout>
  )
}

function CategoryFilters({ value, onChange }: { value: CategoryFilter; onChange: (value: CategoryFilter) => void }) {
  return (
    <div className="private-life-filter-bar" aria-label="Asset category filters">
      <button type="button" className={value === 'all' ? 'active' : ''} onClick={() => onChange('all')}>All</button>
      {(Object.keys(CATEGORY_META) as AssetCategory[]).map((category) => <button key={category} type="button" className={value === category ? 'active' : ''} onClick={() => onChange(category)}>{CATEGORY_META[category].label}</button>)}
    </div>
  )
}
