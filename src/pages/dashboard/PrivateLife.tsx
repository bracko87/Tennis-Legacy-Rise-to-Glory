import {
  Crown,
  ChevronDown,
  LockKeyhole,
  RefreshCw,
  TrendingDown,
  TrendingUp,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { useNavigate } from 'react-router'

import GameConfirmDialog from '../../components/common/GameConfirmDialog'
import GameLayout from '../../components/layout/GameLayout'
import PrivateLifeInvestments from '../../components/private-life/PrivateLifeInvestments'
import { LifestyleCareerPanel, type LifestyleCareer } from '../../components/private-life/LifestyleCareerPanel'
import PrivateJetTravelPreview from '../../components/private-life/PrivateJetTravelPreview'
import { lifestyleCopy } from '../../lib/lifestyleCareerI18n'
import { useCommerce } from '../../hooks/useCommerce'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { supabase } from '../../lib/supabase'
import '../../styles/private-life.css'
import '../../styles/private-life-marketplace.css'
import '../../styles/private-life-history.css'
import '../../styles/private-life-mobile-compact.css'

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
  available_apartment_codes?: string[]
  available_house_codes?: string[]
  is_standard_location?: boolean
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
  career_lifestyle?: LifestyleCareer
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

type DetailTarget =
  | { type: 'market'; listing: MarketplaceListing }
  | { type: 'owned'; asset: OwnedAsset; imageUrl: string }
  | null

const GAME_MONTHS = [
  ['January', 31], ['February', 29], ['March', 31], ['April', 30],
  ['May', 31], ['June', 30], ['July', 31], ['August', 31],
  ['September', 30], ['October', 31], ['November', 30], ['December', 31],
] as const

const ASSET_HISTORY_PAGE_SIZE = 10

// Keep available category and sale-mode identifiers independent of translated labels.
// Translated label maps were removed during localization; these stable keys remain necessary for rendering.
const ASSET_CATEGORIES: AssetCategory[] = ['watch', 'jewelry', 'car', 'apartment', 'house_villa', 'yacht', 'private_jet', 'art', 'collectible']
const SALE_MODES: SaleMode[] = ['urgent', 'standard', 'patient']

function categoryLabel(t: TFunction, category: AssetCategory) {
  return t(`privateLifePage.categories.${category}`, { defaultValue: category })
}

function rarityLabel(t: TFunction, rarity: string) {
  return t(`privateLifePage.rarities.${rarity}`, { defaultValue: rarity.replaceAll('_', ' ') })
}

function trendText(t: TFunction, rateBps: number) {
  if (rateBps === 0) return t('privateLifePage.trends.stable')
  const percent = Math.abs(rateBps) / 100
  const value = `${rateBps > 0 ? '+' : '-'}${percent.toFixed(percent % 1 === 0 ? 0 : 1)}`
  return t('privateLifePage.trends.annual', { value })
}

function marketMoveText(t: TFunction, rateBps: number | null | undefined) {
  if (rateBps === null || rateBps === undefined || !Number.isFinite(Number(rateBps))) return t('privateLifePage.trends.noMonthly')
  const numeric = Number(rateBps)
  if (numeric === 0) return t('privateLifePage.trends.stableMonth')
  const percent = Math.abs(numeric) / 100
  const value = `${numeric > 0 ? '+' : '-'}${percent.toFixed(percent % 1 === 0 ? 0 : 1)}`
  return t('privateLifePage.trends.monthly', { value })
}

function gameDayLabel(t: TFunction, absoluteDay: number | null | undefined) {
  const raw = Number(absoluteDay)
  if (!Number.isFinite(raw) || raw < 0) return t('privateLifePage.dates.unavailable')
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
  return t('privateLifePage.dates.seasonDate', { season, month: monthName, day })
}

function assetTransactionLabel(t: TFunction, type: string) {
  return t(`privateLifePage.transactionTypes.${type}`, { defaultValue: type.replaceAll('_', ' ') })
}

function assetTransactionAmount(row: AssetHistoryRow, currency: string, formatCurrency: (value: number, currency?: string) => string) {
  const amount = Number(row.amount || 0)
  if (row.transaction_type === 'starter_home') return formatCurrency(Math.abs(amount), currency)
  const prefix = amount > 0 ? '+' : amount < 0 ? '−' : ''
  return `${prefix}${formatCurrency(Math.abs(amount), currency)}`
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

function metadataText(asset: CatalogAsset | undefined, key: string) {
  const value = asset?.metadata?.[key]
  if (typeof value === 'string') return value.trim()
  if (typeof value === 'number' && Number.isFinite(value)) return String(value)
  return ''
}

function yachtBuilder(asset: CatalogAsset | undefined) {
  if (!asset || asset.category !== 'yacht') return ''
  return metadataText(asset, 'yacht_builder') || metadataText(asset, 'manufacturer')
}

function yachtDisplayName(asset: CatalogAsset) {
  const builder = yachtBuilder(asset)
  return builder ? `${builder} · ${asset.name}` : asset.name
}

function ownedYachtCatalog(asset: OwnedAsset, catalog: CatalogAsset[]) {
  if (asset.category !== 'yacht') return undefined
  return catalog.find((item) => item.code === asset.catalog_code)
}

function ownedDisplayName(asset: OwnedAsset, catalog: CatalogAsset[]) {
  const yachtCatalog = ownedYachtCatalog(asset, catalog)
  return yachtCatalog ? yachtDisplayName(yachtCatalog) : asset.name
}

function metadataLocationNumber(asset: CatalogAsset, key: string, location: PropertyLocation) {
  const values = asset.metadata?.[key]
  if (!values || typeof values !== 'object' || Array.isArray(values)) return null
  const record = values as Record<string, unknown>
  const candidates = [
    record[location.code],
    record[`${location.country_code}|${location.city}`],
    record[location.city],
  ]
  for (const candidate of candidates) {
    const numeric = Number(candidate)
    if (Number.isFinite(numeric)) return numeric
  }
  return null
}

function propertyEffectivePrice(asset: CatalogAsset, location: PropertyLocation) {
  const basePrice = asset.category === 'apartment' ? location.apartment_base_price : location.house_base_price
  const override = metadataLocationNumber(asset, 'city_price_overrides', location)
  const baseSnapshot = metadataLocationNumber(asset, 'city_price_base_snapshots', location)

  if (override !== null && override > 0) {
    if (baseSnapshot !== null && baseSnapshot > 0) {
      return Math.max(1, Math.round(override * basePrice / baseSnapshot))
    }
    return Math.max(1, Math.round(override))
  }

  const multiplier = metadataNumber(asset, 'price_multiplier_bps', 10000)
  return Math.max(1, Math.round(basePrice * multiplier / 10000))
}

function propertyImageUrl(asset: CatalogAsset, location?: PropertyLocation | null) {
  if (!location) return asset.image_url

  const homeCountryImage = asset.metadata?.home_country_image_url
  if (location.is_standard_location === false && typeof homeCountryImage === 'string' && homeCountryImage.length > 0) {
    return homeCountryImage
  }

  const cityImages = asset.metadata?.city_image_urls
  if (cityImages && typeof cityImages === 'object' && !Array.isArray(cityImages)) {
    const byCountryAndCity = (cityImages as Record<string, unknown>)[`${location.country_code}|${location.city}`]
    if (typeof byCountryAndCity === 'string' && byCountryAndCity.length > 0) return byCountryAndCity

    const byCity = (cityImages as Record<string, unknown>)[location.city]
    if (typeof byCity === 'string' && byCity.length > 0) return byCity
  }

  const locationImages = asset.metadata?.location_image_urls
  if (locationImages && typeof locationImages === 'object' && !Array.isArray(locationImages)) {
    const candidate = (locationImages as Record<string, unknown>)[location.code]
    if (typeof candidate === 'string' && candidate.length > 0) return candidate
  }

  return asset.image_url
}

function propertyAvailabilityCodes(location: PropertyLocation, category: 'apartment' | 'house_villa') {
  const value = category === 'apartment'
    ? location.available_apartment_codes
    : location.available_house_codes
  if (!Array.isArray(value)) return []
  return value.filter((code): code is string => typeof code === 'string' && code.length > 0)
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

function ownershipCostLabel(t: TFunction, category: AssetCategory) {
  if (category === 'apartment' || category === 'house_villa') return t('privateLifePage.costs.living')
  if (category === 'car' || category === 'yacht' || category === 'private_jet') return t('privateLifePage.costs.maintenanceMonthly')
  return t('privateLifePage.costs.maintenance')
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
  const { t, i18n } = useTranslation()
  const careerCopy = lifestyleCopy(i18n.resolvedLanguage ?? i18n.language)
  const { formatCurrency } = useLocalization()
  const money = (value: number, currency = 'USD') => formatCurrency(Number(value || 0), currency)
  const saleLabel = (mode: SaleMode) => t(`privateLifePage.saleModes.${mode}.label`)
  const saleDetail = (mode: SaleMode) => t(`privateLifePage.saleModes.${mode}.detail`)
  const navigate = useNavigate()
  const { isPremium, loading: commerceLoading } = useCommerce()
  const [dashboard, setDashboard] = useState<PrivateLifeDashboard | null>(null)
  const [loading, setLoading] = useState(false)
  const [actionBusy, setActionBusy] = useState(false)
  const [careerBusy, setCareerBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [tab, setTab] = useState<MainTab>('overview')
  const [filter, setFilter] = useState<CategoryFilter>('all')
  const [pendingAction, setPendingAction] = useState<PendingAction>(null)
  const [detailTarget, setDetailTarget] = useState<DetailTarget>(null)
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

  const standardPropertyLocations = useMemo(
    () => (dashboard?.property_locations ?? []).filter((location) => location.is_standard_location !== false),
    [dashboard?.property_locations],
  )

  const selectablePropertyLocations = useMemo(() => {
    if (filter === 'apartment') {
      return standardPropertyLocations.filter((location) => propertyAvailabilityCodes(location, 'apartment').length > 0)
    }
    if (filter === 'house_villa') {
      return standardPropertyLocations.filter((location) => propertyAvailabilityCodes(location, 'house_villa').length > 0)
    }
    return standardPropertyLocations
  }, [filter, standardPropertyLocations])

  useEffect(() => {
    if (!dashboard || selectablePropertyLocations.length === 0) return

    const currentLocation = selectablePropertyLocations.find((location) => location.code === propertyLocationCode)
    if (currentLocation && currentLocation.country_code === propertyCountry) return

    const starter = dashboard.owned_assets.find((asset) => asset.acquisition_type === 'starter_home' && asset.location_code)
    const homeLocation = starter?.location_code ? dashboard.property_locations.find((location) => location.code === starter.location_code) : undefined
    const matchingMarketplaceLocation = homeLocation
      ? selectablePropertyLocations.find((location) =>
          location.country_code === homeLocation.country_code &&
          location.city.localeCompare(homeLocation.city, undefined, { sensitivity: 'base' }) === 0,
        )
      : undefined
    const firstLocation = matchingMarketplaceLocation ?? selectablePropertyLocations[0]
    setPropertyCountry(firstLocation.country_code)
    setPropertyLocationCode(firstLocation.code)
  }, [dashboard, propertyCountry, propertyLocationCode, selectablePropertyLocations])

  const countries = useMemo(() => {
    const map = new Map<string, string>()
    selectablePropertyLocations.forEach((location) => map.set(location.country_code, location.country_name))
    return [...map.entries()].map(([code, name]) => ({ code, name })).sort((a, b) => a.name.localeCompare(b.name))
  }, [selectablePropertyLocations])

  const countryLocations = useMemo(
    () => selectablePropertyLocations.filter((location) => !propertyCountry || location.country_code === propertyCountry),
    [selectablePropertyLocations, propertyCountry],
  )

  useEffect(() => {
    if (!propertyCountry || !countryLocations.length) return
    if (!countryLocations.some((location) => location.code === propertyLocationCode)) setPropertyLocationCode(countryLocations[0].code)
  }, [countryLocations, propertyCountry, propertyLocationCode])

  const selectedPropertyLocation = useMemo(
    () => selectablePropertyLocations.find((location) => location.code === propertyLocationCode),
    [propertyLocationCode, selectablePropertyLocations],
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
      if (asset.category === 'apartment' || asset.category === 'house_villa') {
        const availableCodes = propertyAvailabilityCodes(selectedPropertyLocation, asset.category)
        if (!availableCodes.includes(asset.code)) return []
      }
      const valueAdjustment = metadataNumber(asset, 'value_rate_adjustment_bps', 0)
      const price = propertyEffectivePrice(asset, selectedPropertyLocation)
      const annualCost = monthlyOwnershipCost(asset.category, price) * 12
      const valueRate = selectedPropertyLocation.annual_value_rate_bps + valueAdjustment
      const alreadyOwned = (dashboard?.owned_assets ?? []).some((owned) => owned.catalog_code === asset.code && owned.location_code === selectedPropertyLocation.code)
      return [{
        ...asset,
        image_url: propertyImageUrl(asset, selectedPropertyLocation),
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
      const builderText = yachtBuilder(listing)
      if (search && !`${listing.name} ${builderText} ${listing.description} ${categoryLabel(t, listing.category)} ${locationText}`.toLowerCase().includes(search)) return false
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
    else setNotice(t('privateLifePage.notices.saleCancelled'))
    setActionBusy(false)
    await loadDashboard()
  }

  async function relocateToAsset(asset: OwnedAsset) {
    if (careerBusy || !asset.location_code) return
    setCareerBusy(true);setError(null);setNotice(null)
    const { error: rpcError } = await supabase.rpc('set_private_life_home_base_v1', { p_owned_asset_id: asset.id })
    if (rpcError) setError(rpcError.message)
    else { setNotice(careerCopy.relocationScheduled); await loadDashboard() }
    setCareerBusy(false)
  }

  async function changeTravelPreference(mode: NonNullable<LifestyleCareer['preferred_travel_mode']>) {
    if (careerBusy) return
    setCareerBusy(true);setError(null);setNotice(null)
    const { error: rpcError } = await supabase.rpc('set_private_life_travel_preference_v1', { p_mode: mode })
    if (rpcError) setError(rpcError.message)
    else { setNotice(careerCopy.preferenceSaved); await loadDashboard() }
    setCareerBusy(false)
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
      setNotice(t('privateLifePage.notices.purchased', { name: listing.name, location: listing.location ? ` ${listing.location.city}` : '' }))
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
      if (result?.status === 'sold') setNotice(t('privateLifePage.notices.sold', { name: asset.name, amount: money(Number(result.sale_price ?? pendingAction.quote.price), dashboard?.currency ?? 'USD') }))
      else setNotice(t('privateLifePage.notices.listed', { name: asset.name, days: Number(result?.wait_days ?? pendingAction.quote.wait_days) }))
    }

    setPendingAction(null)
    setActionBusy(false)
    await loadDashboard()
  }

  if (commerceLoading) {
    return <GameLayout title={t('privateLifePage.title')} subtitle={t('privateLifePage.subtitle')}><div className="tlg-premium-lock"><span>{t('privateLifePage.premium.checking')}</span></div></GameLayout>
  }

  if (!isPremium) {
    return (
      <GameLayout title={t('privateLifePage.title')} subtitle={t('privateLifePage.subtitle')}>
        <section className="tlg-premium-lock">
          <div className="tlg-premium-lock-icon"><LockKeyhole size={28} /></div>
          <span>{t('privateLifePage.premium.feature')}</span><h2>{t('privateLifePage.title')}</h2>
          <p>{t('privateLifePage.premium.body')}</p>
          <button type="button" onClick={() => navigate('/game/pro-packages')}><Crown size={16} /> {t('privateLifePage.premium.view')}</button>
        </section>
      </GameLayout>
    )
  }

  if (loading && !dashboard) {
    return <GameLayout title={t('privateLifePage.title')} subtitle={t('privateLifePage.subtitle')}><div className="private-life-loading"><RefreshCw size={20} /> {t('privateLifePage.loading')}</div></GameLayout>
  }

  if (error && !dashboard) {
    return (
      <GameLayout title={t('privateLifePage.title')} subtitle={t('privateLifePage.subtitle')}>
        <div className="private-life-error"><strong>{t('privateLifePage.loadError')}</strong><p>{error}</p><button className="private-life-refresh" type="button" onClick={() => void loadDashboard()}><RefreshCw size={14} /> {t('privateLifePage.tryAgain')}</button></div>
      </GameLayout>
    )
  }

  if (!dashboard) return null

  const currency = dashboard.currency || 'USD'
  const categoryTotals = new Map(dashboard.category_totals.map((row) => [row.category, row]))

  const confirmation = pendingAction
    ? pendingAction.type === 'buy'
      ? {
          eyebrow: t('privateLifePage.purchase.eyebrow'),
          title: t('privateLifePage.purchase.buyTitle', { name: yachtDisplayName(pendingAction.listing), location: pendingAction.listing.location ? ` ${pendingAction.listing.location.city}` : '' }),
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
                <span>{t('privateLifePage.purchase.purchasePrice')}</span>
                <strong>{money(pendingAction.listing.effective_price, currency)}</strong>
              </div>
              <div className="private-life-purchase-info-grid">
                {pendingAction.listing.category === 'yacht' && yachtBuilder(pendingAction.listing) ? <div><span>{t('privateLifePage.purchase.builder')}</span><strong>{yachtBuilder(pendingAction.listing)}</strong></div> : null}
                {pendingAction.listing.category === 'yacht' ? <div><span>{t('privateLifePage.purchase.model')}</span><strong>{pendingAction.listing.name}</strong></div> : null}
                {pendingAction.listing.category === 'yacht' && metadataText(pendingAction.listing, 'yacht_length_m') ? <div><span>{t('privateLifePage.purchase.length')}</span><strong>{metadataText(pendingAction.listing, 'yacht_length_m')} m</strong></div> : null}
                {pendingAction.listing.category === 'yacht' && metadataText(pendingAction.listing, 'yacht_type') ? <div><span>{t('privateLifePage.purchase.yachtType')}</span><strong>{metadataText(pendingAction.listing, 'yacht_type')}</strong></div> : null}
                <div><span>{t('privateLifePage.purchase.category')}</span><strong>{categoryLabel(t, pendingAction.listing.category)}</strong></div>
                <div><span>{t('privateLifePage.purchase.rarity')}</span><strong>{rarityLabel(t, pendingAction.listing.rarity)}</strong></div>
                <div><span>{t('privateLifePage.purchase.prestige')}</span><strong>+{pendingAction.listing.prestige}</strong></div>
                <div><span>{t('privateLifePage.purchase.monthlyMove')}</span><strong className={Number(pendingAction.listing.effective_market_change_bps ?? 0) < 0 ? 'private-life-trend-negative' : Number(pendingAction.listing.effective_market_change_bps ?? 0) > 0 ? 'private-life-trend-positive' : ''}>{marketMoveText(t, pendingAction.listing.effective_market_change_bps)}</strong></div>
                <div><span>{ownershipCostLabel(t, pendingAction.listing.category)}</span><strong>{pendingAction.listing.effective_annual_cost > 0 ? money(pendingAction.listing.effective_annual_cost / 12, currency) : t('privateLifePage.costs.none')}</strong></div>
                <div><span>{t('privateLifePage.costs.annualOwnership')}</span><strong>{pendingAction.listing.effective_annual_cost > 0 ? money(pendingAction.listing.effective_annual_cost, currency) : t('privateLifePage.costs.none')}</strong></div>
                <div><span>{t('privateLifePage.purchase.annualTrend')}</span><strong className={pendingAction.listing.effective_value_rate_bps < 0 ? 'private-life-trend-negative' : pendingAction.listing.effective_value_rate_bps > 0 ? 'private-life-trend-positive' : ''}>{trendText(t, pendingAction.listing.effective_value_rate_bps)}</strong></div>
                <div><span>{t('privateLifePage.purchase.financeAfter')}</span><strong>{money(dashboard.cash_balance - pendingAction.listing.effective_price, currency)}</strong></div>
              </div>
              <div className="private-life-purchase-finance-note">
                {t('privateLifePage.purchase.financeNote', { amount: money(pendingAction.listing.effective_price, currency) })}
              </div>
            </div>
          ),
          confirmLabel: t('privateLifePage.purchase.buyFor', { amount: money(pendingAction.listing.effective_price, currency) }),
          tone: 'warning' as const,
        }
      : {
          eyebrow: t('privateLifePage.purchase.sellEyebrow'),
          title: `${saleLabel(pendingAction.saleMode)}: ${pendingAction.asset.name}?`,
          hero: null,
          size: 'default' as const,
          message: t('privateLifePage.purchase.saleQuote', { amount: money(pendingAction.quote.price, currency) }),
          detail: t('privateLifePage.purchase.saleDetail', { mode: saleDetail(pendingAction.saleMode), current: money(pendingAction.asset.current_market_value, currency), original: money(pendingAction.asset.purchase_price, currency) }),
          confirmLabel: pendingAction.saleMode === 'urgent' ? t('privateLifePage.purchase.sellNow', { amount: money(pendingAction.quote.price, currency) }) : t('privateLifePage.purchase.listFor', { amount: money(pendingAction.quote.price, currency) }),
          tone: 'danger' as const,
        }
    : null

  const detailDialog = detailTarget
    ? detailTarget.type === 'market'
      ? {
          eyebrow: t('privateLifePage.purchase.detailsEyebrow'),
          title: `${yachtDisplayName(detailTarget.listing)}${detailTarget.listing.location ? ` in ${detailTarget.listing.location.city}` : ''}`,
          hero: <AssetImage src={detailTarget.listing.image_url} name={detailTarget.listing.name} />,
          size: 'wide' as const,
          message: (
            <div className="private-life-purchase-copy">
              <p>{detailTarget.listing.description}</p>
              {detailTarget.listing.location ? (
                <div className="private-life-purchase-location">
                  {detailTarget.listing.location.city}, {detailTarget.listing.location.country_name}
                </div>
              ) : null}
            </div>
          ),
          detail: (
            <div className="private-life-purchase-summary">
              <div className="private-life-purchase-price-row">
                <span>{t('privateLifePage.purchase.purchasePrice')}</span>
                <strong>{money(detailTarget.listing.effective_price, currency)}</strong>
              </div>
              <div className="private-life-purchase-info-grid">
                {detailTarget.listing.category === 'yacht' && yachtBuilder(detailTarget.listing) ? <div><span>{t('privateLifePage.purchase.builder')}</span><strong>{yachtBuilder(detailTarget.listing)}</strong></div> : null}
                {detailTarget.listing.category === 'yacht' ? <div><span>{t('privateLifePage.purchase.model')}</span><strong>{detailTarget.listing.name}</strong></div> : null}
                {detailTarget.listing.category === 'yacht' && metadataText(detailTarget.listing, 'yacht_length_m') ? <div><span>{t('privateLifePage.purchase.length')}</span><strong>{metadataText(detailTarget.listing, 'yacht_length_m')} m</strong></div> : null}
                {detailTarget.listing.category === 'yacht' && metadataText(detailTarget.listing, 'yacht_type') ? <div><span>{t('privateLifePage.purchase.yachtType')}</span><strong>{metadataText(detailTarget.listing, 'yacht_type')}</strong></div> : null}
                <div><span>{t('privateLifePage.purchase.category')}</span><strong>{categoryLabel(t, detailTarget.listing.category)}</strong></div>
                <div><span>{t('privateLifePage.purchase.rarity')}</span><strong>{rarityLabel(t, detailTarget.listing.rarity)}</strong></div>
                <div><span>{t('privateLifePage.purchase.prestige')}</span><strong>+{detailTarget.listing.prestige}</strong></div>
                <div><span>{t('privateLifePage.purchase.monthlyMove')}</span><strong className={Number(detailTarget.listing.effective_market_change_bps ?? 0) < 0 ? 'private-life-trend-negative' : Number(detailTarget.listing.effective_market_change_bps ?? 0) > 0 ? 'private-life-trend-positive' : ''}>{marketMoveText(t, detailTarget.listing.effective_market_change_bps)}</strong></div>
                <div><span>{ownershipCostLabel(t, detailTarget.listing.category)}</span><strong>{detailTarget.listing.effective_annual_cost > 0 ? money(detailTarget.listing.effective_annual_cost / 12, currency) : t('privateLifePage.costs.none')}</strong></div>
                <div><span>{t('privateLifePage.costs.annualOwnership')}</span><strong>{detailTarget.listing.effective_annual_cost > 0 ? money(detailTarget.listing.effective_annual_cost, currency) : t('privateLifePage.costs.none')}</strong></div>
                <div><span>{t('privateLifePage.purchase.annualTrend')}</span><strong className={detailTarget.listing.effective_value_rate_bps < 0 ? 'private-life-trend-negative' : detailTarget.listing.effective_value_rate_bps > 0 ? 'private-life-trend-positive' : ''}>{trendText(t, detailTarget.listing.effective_value_rate_bps)}</strong></div>
                <div><span>{t('privateLifePage.purchase.financeAfter')}</span><strong>{money(dashboard.cash_balance - detailTarget.listing.effective_price, currency)}</strong></div>
              </div>
              {detailTarget.listing.category === 'private_jet' && <PrivateJetTravelPreview catalogCode={detailTarget.listing.code} connectedBackendActive={Boolean(dashboard.career_lifestyle)} formatMoney={(value) => money(value, currency)} />}
            </div>
          ),
        }
      : {
          eyebrow: t('privateLifePage.purchase.ownedEyebrow'),
          title: `${ownedDisplayName(detailTarget.asset, dashboard.catalog)}${detailTarget.asset.city ? ` in ${detailTarget.asset.city}` : ''}`,
          hero: <AssetImage src={detailTarget.imageUrl} name={detailTarget.asset.name} />,
          size: 'wide' as const,
          message: (
            <div className="private-life-purchase-copy">
              <p>{detailTarget.asset.description}</p>
              {detailTarget.asset.city && detailTarget.asset.country_name ? (
                <div className="private-life-purchase-location">
                  {detailTarget.asset.city}, {detailTarget.asset.country_name}
                </div>
              ) : null}
            </div>
          ),
          detail: (
            <div className="private-life-purchase-summary">
              <div className="private-life-purchase-price-row">
                <span>{t('privateLifePage.purchase.currentValue')}</span>
                <strong>{money(detailTarget.asset.current_market_value, currency)}</strong>
              </div>
              <div className="private-life-purchase-info-grid">
                {ownedYachtCatalog(detailTarget.asset, dashboard.catalog) && yachtBuilder(ownedYachtCatalog(detailTarget.asset, dashboard.catalog)) ? <div><span>{t('privateLifePage.purchase.builder')}</span><strong>{yachtBuilder(ownedYachtCatalog(detailTarget.asset, dashboard.catalog))}</strong></div> : null}
                {detailTarget.asset.category === 'yacht' ? <div><span>{t('privateLifePage.purchase.model')}</span><strong>{detailTarget.asset.name}</strong></div> : null}
                {ownedYachtCatalog(detailTarget.asset, dashboard.catalog) && metadataText(ownedYachtCatalog(detailTarget.asset, dashboard.catalog), 'yacht_length_m') ? <div><span>{t('privateLifePage.purchase.length')}</span><strong>{metadataText(ownedYachtCatalog(detailTarget.asset, dashboard.catalog), 'yacht_length_m')} m</strong></div> : null}
                {ownedYachtCatalog(detailTarget.asset, dashboard.catalog) && metadataText(ownedYachtCatalog(detailTarget.asset, dashboard.catalog), 'yacht_type') ? <div><span>{t('privateLifePage.purchase.yachtType')}</span><strong>{metadataText(ownedYachtCatalog(detailTarget.asset, dashboard.catalog), 'yacht_type')}</strong></div> : null}
                <div><span>{t('privateLifePage.purchase.category')}</span><strong>{categoryLabel(t, detailTarget.asset.category)}</strong></div>
                <div><span>{t('privateLifePage.purchase.rarity')}</span><strong>{rarityLabel(t, detailTarget.asset.rarity)}</strong></div>
                <div><span>{t('privateLifePage.purchase.prestige')}</span><strong>+{detailTarget.asset.prestige}</strong></div>
                <div><span>{t('privateLifePage.purchase.ownership')}</span><strong>{t('privateLifePage.dates.gameDays', { count: detailTarget.asset.ownership_days })}</strong></div>
                <div><span>{t('privateLifePage.purchase.originalValue')}</span><strong>{money(detailTarget.asset.purchase_price, currency)}</strong></div>
                <div><span>{ownershipCostLabel(t, detailTarget.asset.category)}</span><strong>{detailTarget.asset.annual_running_cost > 0 ? money(detailTarget.asset.annual_running_cost / 12, currency) : t('privateLifePage.costs.none')}</strong></div>
                <div><span>{t('privateLifePage.costs.annualOwnership')}</span><strong>{detailTarget.asset.annual_running_cost > 0 ? money(detailTarget.asset.annual_running_cost, currency) : t('privateLifePage.costs.none')}</strong></div>
                <div><span>{t('privateLifePage.marketplace.marketMove')}</span><strong className={Number(detailTarget.asset.property_monthly_change_bps ?? detailTarget.asset.asset_monthly_change_bps ?? 0) < 0 ? 'private-life-trend-negative' : Number(detailTarget.asset.property_monthly_change_bps ?? detailTarget.asset.asset_monthly_change_bps ?? 0) > 0 ? 'private-life-trend-positive' : ''}>{marketMoveText(t, detailTarget.asset.property_monthly_change_bps ?? detailTarget.asset.asset_monthly_change_bps)}</strong></div>
                <div><span>{t('privateLifePage.purchase.annualTrend')}</span><strong className={detailTarget.asset.annual_value_rate_bps < 0 ? 'private-life-trend-negative' : detailTarget.asset.annual_value_rate_bps > 0 ? 'private-life-trend-positive' : ''}>{trendText(t, detailTarget.asset.annual_value_rate_bps)}</strong></div>
                <div><span>{t('privateLifePage.purchase.estimatedSale')}</span><strong>{money(detailTarget.asset.estimated_sale_price, currency)}</strong></div>
              </div>
              {detailTarget.asset.category === 'private_jet' && <PrivateJetTravelPreview catalogCode={detailTarget.asset.catalog_code} connectedBackendActive={Boolean(dashboard.career_lifestyle)} formatMoney={(value) => money(value, currency)} />}
            </div>
          ),
        }
    : null

  return (
    <GameLayout title={t('privateLifePage.title')} subtitle={t('privateLifePage.subtitle')}>
      <div className="private-life-page">
        <section className="private-life-hero private-life-hero-compact">
          <div className="private-life-hero-copy">
            <div className="private-life-eyebrow">{t('privateLifePage.hero.eyebrow')}</div>
            <h2>{t('privateLifePage.hero.title')}</h2>
            <p>{t('privateLifePage.hero.body')}</p>
          </div>
          <div className="private-life-prestige-banner"><span>{t('privateLifePage.purchase.prestige')}</span><strong>{dashboard.prestige.toLocaleString()}</strong><small>{t('privateLifePage.hero.prestigeNote')}</small></div>
        </section>

        <section className="private-life-metrics" aria-label={t('privateLifePage.metrics.aria')}>
          <div className="private-life-metric"><span>{t('privateLifePage.metrics.cash')}</span><strong>{money(dashboard.cash_balance, currency)}</strong></div>
          <div className="private-life-metric"><span>{t('privateLifePage.metrics.assets')}</span><strong>{money(dashboard.asset_value, currency)}</strong></div>
          <div className="private-life-metric"><span>{t('privateLifePage.metrics.investments')}</span><strong>{money(dashboard.investment_value, currency)}</strong></div>
          <div className="private-life-metric"><span>{t('privateLifePage.metrics.netWorth')}</span><strong>{money(dashboard.net_worth, currency)}</strong></div>
          <div className="private-life-metric"><span>{t('privateLifePage.purchase.prestige')}</span><strong>{dashboard.prestige}</strong></div>
          <div className="private-life-metric"><span>{t('privateLifePage.metrics.monthlyCost')}</span><strong>{money(dashboard.annual_running_cost / 12, currency)}</strong></div>
        </section>

        {dashboard.career_lifestyle && <LifestyleCareerPanel
          data={dashboard.career_lifestyle}
          saving={careerBusy}
          onTravelPreference={(mode) => { void changeTravelPreference(mode) }}
          formatCurrency={(amount) => money(amount, currency)}
        />}

        <nav className="private-life-tabs" aria-label={t('privateLifePage.tabs.aria')}>
          <button className={tab === 'overview' ? 'active' : ''} type="button" onClick={() => setTab('overview')}>{t('privateLifePage.tabs.overview')}</button>
          <button className={tab === 'assets' ? 'active' : ''} type="button" onClick={() => setTab('assets')}>{t('privateLifePage.tabs.assets')} ({dashboard.owned_assets.length})</button>
          <button className={tab === 'investments' ? 'active' : ''} type="button" onClick={() => setTab('investments')}>{t('privateLifePage.tabs.investments')}</button>
          <button className={tab === 'marketplace' ? 'active' : ''} type="button" onClick={() => setTab('marketplace')}>{t('privateLifePage.tabs.marketplace')}</button>
        </nav>

        {notice ? <div className="private-life-notice"><span>{notice}</span></div> : null}
        {error ? <div className="private-life-error"><strong>{t('privateLifePage.actionError')}</strong><p>{error}</p></div> : null}

        {tab === 'overview' ? (
          <section className="private-life-section">
            <div className="private-life-section-head">
              <div><div className="private-life-section-eyebrow">{t('privateLifePage.overview.eyebrow')}</div><h3>{t('privateLifePage.overview.title')}</h3><p>{t('privateLifePage.overview.body')}</p></div>
              <button type="button" className="private-life-refresh" disabled={loading} onClick={() => void loadDashboard()}><RefreshCw size={14} /> {loading ? t('privateLifePage.overview.refreshing') : t('privateLifePage.overview.refresh')}</button>
            </div>
            <div className="private-life-overview-grid">
              <div className="private-life-panel">
                <h4>{t('privateLifePage.overview.physical')}</h4>
                <div className="private-life-category-list">
                  {(ASSET_CATEGORIES).map((category) => {
                    const total = categoryTotals.get(category)
                    return <div key={category} className="private-life-category-row"><div className="private-life-category-name"><span>{categoryLabel(t, category)}</span></div><span>{t('privateLifePage.overview.ownedCount', { count: total?.owned_count ?? 0 })}</span><strong>{money(total?.market_value ?? 0, currency)}</strong><span>+{total?.prestige ?? 0} {t('privateLifePage.purchase.prestige')}</span></div>
                  })}
                </div>
              </div>
              <div className="private-life-future-stack">
                <article className="private-life-future-card private-life-investment-preview"><div className="private-life-future-card-head"><h4>{t('privateLifePage.overview.investmentTitle')}</h4><span className="private-life-status-pill active">{t('privateLifePage.overview.active')}</span></div><p>{t('privateLifePage.overview.investmentBody')}</p><button type="button" className="private-life-inline-action" onClick={() => setTab('investments')}>{t('privateLifePage.overview.openInvestments')}</button></article>
                <article className="private-life-future-card"><div className="private-life-future-card-head"><h4>{t('privateLifePage.overview.residenceTitle')}</h4></div><p>{t('privateLifePage.overview.residenceBody')}</p><small>{t('privateLifePage.overview.residenceNote')}</small></article>
                <article className="private-life-future-card"><div className="private-life-future-card-head"><h4>{t('privateLifePage.overview.costsTitle')}</h4></div><p>{t('privateLifePage.overview.costsBody')}</p><small>{t('privateLifePage.overview.costsNote')}</small></article>
              </div>
            </div>
          </section>
        ) : null}

        {tab === 'assets' ? (
          <section className="private-life-section">
            <div className="private-life-section-head"><div><div className="private-life-section-eyebrow">{t('privateLifePage.assets.eyebrow')}</div><h3>{t('privateLifePage.assets.title')}</h3><p>{t('privateLifePage.assets.body')}</p></div><button type="button" className="private-life-refresh" onClick={() => void toggleAssetHistory()}>{t('privateLifePage.assets.history')}</button></div>
            <CategoryFilters value={filter} onChange={setFilter} />

            {showAssetHistory ? (
              <div className="private-life-asset-history" role="dialog" aria-modal="true" aria-labelledby="private-life-transaction-history-title">
                <div className="private-life-asset-history-head">
                  <div><strong id="private-life-transaction-history-title">{t('privateLifePage.assets.history')}</strong><span>{t('privateLifePage.assets.historyBody')}</span></div>
                  <button type="button" className="private-life-asset-history-close" aria-label={t('privateLifePage.assets.closeHistory')} onClick={() => setShowAssetHistory(false)}>×</button>
                </div>
                {assetHistoryLoading ? <div className="private-life-asset-history-state">{t('privateLifePage.assets.loadingHistory')}</div> : assetHistoryError ? <div className="private-life-asset-history-state error">{assetHistoryError}</div> : assetHistory.length === 0 ? <div className="private-life-asset-history-state">{t('privateLifePage.assets.noTransactions')}</div> : (
                  <div className="private-life-asset-history-table-wrap">
                    <table className="private-life-asset-history-table">
                      <thead><tr><th>{t('privateLifePage.assets.headers.date')}</th><th>{t('privateLifePage.assets.headers.transaction')}</th><th>{t('privateLifePage.assets.headers.asset')}</th><th>{t('privateLifePage.assets.headers.amount')}</th><th>{t('privateLifePage.assets.headers.details')}</th></tr></thead>
                      <tbody>{assetHistory.slice((assetHistoryPage - 1) * ASSET_HISTORY_PAGE_SIZE, assetHistoryPage * ASSET_HISTORY_PAGE_SIZE).map((row) => {
                        const amount = Number(row.amount || 0)
                        const amountTone = row.transaction_type === 'starter_home' ? 'neutral' : amount > 0 ? 'positive' : amount < 0 ? 'negative' : 'neutral'
                        return (
                          <tr key={row.id}>
                            <td><strong>{gameDayLabel(t, row.event_absolute_day)}</strong></td>
                            <td><span className={`private-life-asset-history-type ${row.transaction_type}`}>{assetTransactionLabel(t, row.transaction_type)}</span></td>
                            <td><strong>{row.name}</strong><span>{categoryLabel(t, row.category)}{row.city && row.country_name ? ` · ${row.city}, ${row.country_name}` : ''}</span></td>
                            <td><strong className={`private-life-asset-history-amount ${amountTone}`}>{assetTransactionAmount(row, currency, formatCurrency)}</strong></td>
                            <td><strong>{row.transaction_type === 'starter_home' ? t('privateLifePage.assets.starterAssigned') : row.title}</strong><span>{row.transaction_type === 'starter_home' ? t('privateLifePage.assets.starterDetail') : row.description}</span></td>
                          </tr>
                        )
                      })}</tbody>
                    </table>
                  </div>
                )}
                {assetHistory.length > ASSET_HISTORY_PAGE_SIZE ? (
                  <div className="private-life-asset-history-pagination">
                    <button type="button" disabled={assetHistoryPage <= 1} onClick={() => setAssetHistoryPage((page) => Math.max(1, page - 1))}>{t('privateLifePage.assets.previous')}</button>
                    <span>{t('privateLifePage.assets.page', { page: assetHistoryPage, pages: Math.ceil(assetHistory.length / ASSET_HISTORY_PAGE_SIZE) })}</span>
                    <button type="button" disabled={assetHistoryPage >= Math.ceil(assetHistory.length / ASSET_HISTORY_PAGE_SIZE)} onClick={() => setAssetHistoryPage((page) => Math.min(Math.ceil(assetHistory.length / ASSET_HISTORY_PAGE_SIZE), page + 1))}>{t('privateLifePage.assets.next')}</button>
                  </div>
                ) : null}
              </div>
            ) : null}
            {visibleOwned.length === 0 ? <div className="private-life-empty"><strong>{t('privateLifePage.assets.emptyTitle')}</strong><p>{t('privateLifePage.assets.emptyBody')}</p></div> : (
              <div className="private-life-owned-grid">
                {visibleOwned.map((asset) => {
                  const isResidence = asset.category === 'apartment' || asset.category === 'house_villa'
                  const canSellResidence = !isResidence || (availableResidenceCount >= 2
                    && dashboard.career_lifestyle?.active_residence_asset_id !== asset.id
                    && dashboard.career_lifestyle?.pending_residence_asset_id !== asset.id)
                  const catalogAsset = dashboard.catalog.find((catalog) => catalog.code === asset.catalog_code)
                  const ownedLocation = asset.location_code ? dashboard.property_locations.find((location) => location.code === asset.location_code) : undefined
                  const ownedImageUrl = catalogAsset ? propertyImageUrl(catalogAsset, ownedLocation) : asset.image_url
                  return (
                    <article className="private-life-owned-card" key={asset.id}>
                      <div className="private-life-card-image"><AssetImage src={ownedImageUrl} name={asset.name} /><div className="private-life-image-badges"><span className="private-life-badge">{rarityLabel(t, asset.rarity)}</span><span className="private-life-badge level">+{asset.prestige} {t('privateLifePage.purchase.prestige')}</span></div></div>
                      <div className="private-life-card-body">
                        <div className="private-life-card-compact-summary">
                        <div className="private-life-card-title-row"><div>{catalogAsset && yachtBuilder(catalogAsset) ? <div className="private-life-yacht-builder">{yachtBuilder(catalogAsset)}</div> : null}<h4>{asset.name}</h4></div><div className="private-life-price">{money(asset.current_market_value, currency)}</div></div>
                        {asset.acquisition_type === 'starter_home' ? <div className="private-life-starter-home-label">{t('privateLifePage.assets.startingHome')}</div> : null}
                        <p className="private-life-description">{asset.description}</p>
                        {asset.category === 'private_jet' && <PrivateJetTravelPreview catalogCode={asset.catalog_code} connectedBackendActive={Boolean(dashboard.career_lifestyle)} formatMoney={(value) => money(value, currency)} compact />}
                        </div>
                        <MobileAssetDisclosure>
                        <div className="private-life-owned-value-grid">
                          <div className="private-life-owned-value-row"><span>{t('privateLifePage.purchase.originalValue')}</span><strong>{money(asset.purchase_price, currency)}</strong></div>
                          <div className="private-life-owned-value-row"><span>{t('privateLifePage.purchase.currentValue')}</span><strong>{money(asset.current_market_value, currency)}</strong></div>
                          <div className="private-life-owned-value-row"><span>{t('privateLifePage.purchase.prestige')}</span><strong>+{asset.prestige}</strong></div>
                          <div className="private-life-owned-value-row"><span>{t('privateLifePage.purchase.ownership')}</span><strong>{t('privateLifePage.dates.gameDays', { count: asset.ownership_days })}</strong></div>
                          <div className="private-life-owned-value-row"><span>{ownershipCostLabel(t, asset.category)}</span><strong>{asset.annual_running_cost > 0 ? money(asset.annual_running_cost / 12, currency) : t('privateLifePage.costs.none')}</strong></div>
                          <div className="private-life-owned-value-row"><span>{t('privateLifePage.marketplace.marketMove')}</span><strong className={Number(asset.property_monthly_change_bps ?? asset.asset_monthly_change_bps ?? 0) < 0 ? 'private-life-trend-negative' : Number(asset.property_monthly_change_bps ?? asset.asset_monthly_change_bps ?? 0) > 0 ? 'private-life-trend-positive' : ''}>{marketMoveText(t, asset.property_monthly_change_bps ?? asset.asset_monthly_change_bps)}</strong></div>
                        </div>
                        <button
                          type="button"
                          className="private-life-action details"
                          onClick={() => setDetailTarget({ type: 'owned', asset, imageUrl: ownedImageUrl })}
                        >
                          {t('privateLifePage.assets.details')}
                        </button>
                        {isResidence && asset.location_code && !asset.pending_sale && (
                          <div className="tlg-home-base-control">
                            {dashboard.career_lifestyle?.active_residence_asset_id === asset.id ? (
                              <strong>{careerCopy.selectedResidence}</strong>
                            ) : dashboard.career_lifestyle?.pending_residence_asset_id === asset.id ? (
                              <strong>{careerCopy.movePending}</strong>
                            ) : (
                              <button type="button" disabled={careerBusy || Boolean(dashboard.career_lifestyle?.pending_residence_asset_id)}
                                onClick={() => { void relocateToAsset(asset) }}>{careerCopy.setHomeBase}</button>
                            )}
                            <small>{careerCopy.relocateNote}</small>
                          </div>
                        )}
                        {asset.pending_sale ? (
                          <div className="private-life-sale-pending"><div><span>{t('privateLifePage.assets.listed')}</span><strong>{saleLabel(asset.pending_sale.sale_mode)} · {money(asset.pending_sale.quoted_sale_price, currency)}</strong><small>{t('privateLifePage.dates.settlementDay', { day: asset.pending_sale.settle_absolute_day })}</small></div><button type="button" disabled={actionBusy} onClick={() => void cancelSale(asset.pending_sale!.id)}>{t('privateLifePage.assets.cancelSale')}</button></div>
                        ) : canSellResidence ? (
                          <div className="private-life-sale-options">
                            {(SALE_MODES).map((mode) => {
                              const quote = asset.sale_quotes?.[mode]
                              if (!quote) return null
                              return <button key={mode} type="button" onClick={() => setPendingAction({ type: 'sell', asset, saleMode: mode, quote })}><span>{t(`privateLifePage.saleModes.${mode}.label`)}</span><strong>{money(quote.price, currency)}</strong><small>{t(`privateLifePage.saleModes.${mode}.detail`)}</small></button>
                            })}
                          </div>
                        ) : (
                          <div className="private-life-residence-lock"><strong>{t('privateLifePage.assets.primary')}</strong><span>{t('privateLifePage.assets.primaryBody')}</span></div>
                        )}
                        </MobileAssetDisclosure>
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
              <div><div className="private-life-section-eyebrow">{t('privateLifePage.marketplace.eyebrow')}</div><h3>{t('privateLifePage.marketplace.title')}</h3><p>{t('privateLifePage.marketplace.body')}</p></div>
              <span className="private-life-market-new-pill">{t('privateLifePage.marketplace.newItems')}</span>
            </div>
            <CategoryFilters value={filter} onChange={setFilter} />

            {(filter === 'apartment' || filter === 'house_villa') ? (
              <div className="private-life-property-selector">
                <div><span>{t('privateLifePage.marketplace.country')}</span><select value={propertyCountry} onChange={(event) => {
                  const countryCode = event.target.value
                  const firstLocation = selectablePropertyLocations.find((location) => location.country_code === countryCode)
                  setPropertyCountry(countryCode)
                  setPropertyLocationCode(firstLocation?.code ?? '')
                }}>{countries.map((country) => <option key={country.code} value={country.code}>{country.name}</option>)}</select></div>
                <div><span>{t('privateLifePage.marketplace.city')}</span><select value={propertyLocationCode} onChange={(event) => setPropertyLocationCode(event.target.value)}>{countryLocations.map((location) => <option key={location.code} value={location.code}>{location.city}</option>)}</select></div>
              </div>
            ) : null}

            <div className="private-life-marketplace-tools">
              <input value={marketSearch} onChange={(event) => setMarketSearch(event.target.value)} placeholder={t('privateLifePage.marketplace.search')} aria-label={t('privateLifePage.marketplace.searchAria')} />
              <select value={marketPrice} onChange={(event) => setMarketPrice(event.target.value as MarketplacePrice)} aria-label={t('privateLifePage.marketplace.priceAria')}>{(['all','under_10k','10k_50k','50k_250k','250k_1m','1m_5m','5m_plus'] as MarketplacePrice[]).map((price) => <option key={price} value={price}>{t(`privateLifePage.marketplace.prices.${price}`)}</option>)}</select>
              <select value={marketRarity} onChange={(event) => setMarketRarity(event.target.value as MarketplaceRarity)} aria-label={t('privateLifePage.marketplace.rarityAria')}><option value="all">{t('privateLifePage.marketplace.allRarities')}</option>{(['common','uncommon','rare','very_rare','legendary'] as const).map((rarity) => <option key={rarity} value={rarity}>{rarityLabel(t, rarity)}</option>)}</select>
              <select value={marketSort} onChange={(event) => setMarketSort(event.target.value as MarketplaceSort)} aria-label={t('privateLifePage.marketplace.sortAria')}>{(['default','price_asc','price_desc','prestige_desc','appreciation_desc'] as MarketplaceSort[]).map((sort) => <option key={sort} value={sort}>{t(`privateLifePage.marketplace.sort.${sort}`)}</option>)}</select>
              <label className="private-life-marketplace-affordable"><input type="checkbox" checked={marketAffordableOnly} onChange={(event) => setMarketAffordableOnly(event.target.checked)} /><span>{t('privateLifePage.marketplace.affordable')}</span></label>
              <button type="button" className="private-life-marketplace-reset" onClick={() => { setMarketSearch(''); setMarketPrice('all'); setMarketRarity('all'); setMarketSort('default'); setMarketAffordableOnly(false); setFilter('all') }}>{t('privateLifePage.marketplace.reset')}</button>
            </div>
            <div className="private-life-marketplace-results"><span>{t('privateLifePage.marketplace.listings', { count: visibleCatalog.length })}</span><span>{t('privateLifePage.marketplace.destinations', { assets: dashboard.catalog.length, destinations: (filter === 'apartment' || filter === 'house_villa') ? selectablePropertyLocations.length : standardPropertyLocations.length })}</span></div>
            {visibleCatalog.length === 0 ? <div className="private-life-empty"><strong>{t('privateLifePage.marketplace.emptyTitle')}</strong><p>{t('privateLifePage.marketplace.emptyBody')}</p></div> : (
              <div className="private-life-market-grid">
                {visibleCatalog.map((listing) => {
                  const marketMove = listing.effective_market_change_bps
                  const isPositive = Number(marketMove ?? 0) > 0
                  const canBuy = listing.effective_affordable && !listing.effective_owned
                  return (
                    <article className="private-life-card" key={`${listing.code}:${listing.location?.code ?? 'global'}`}>
                      <div className="private-life-card-image"><AssetImage src={listing.image_url} name={listing.name} /><div className="private-life-image-badges"><span className="private-life-badge">{rarityLabel(t, listing.rarity)}</span><span className="private-life-badge new">{t('privateLifePage.marketplace.new')}</span></div></div>
                      <div className="private-life-card-body">
                        <div className="private-life-card-compact-summary">
                        <div className="private-life-card-title-row"><div>{yachtBuilder(listing) ? <div className="private-life-yacht-builder">{yachtBuilder(listing)}</div> : null}<h4>{listing.name}</h4></div><div className="private-life-price">{money(listing.effective_price, currency)}</div></div>
                        {listing.location ? <div className="private-life-property-location">{listing.location.city}, {listing.location.country_name}</div> : null}
                        <p className="private-life-description">{listing.description}</p>
                        {listing.category === 'private_jet' && <PrivateJetTravelPreview catalogCode={listing.code} connectedBackendActive={Boolean(dashboard.career_lifestyle)} formatMoney={(value) => money(value, currency)} compact />}
                        </div>
                        <MobileAssetDisclosure>
                        <div className="private-life-card-stats">
                          <div className="private-life-card-stat"><span>{t('privateLifePage.purchase.prestige')}</span><strong>+{listing.prestige}</strong></div>
                          <div className="private-life-card-stat"><span>{ownershipCostLabel(t, listing.category)}</span><strong>{listing.effective_annual_cost > 0 ? money(listing.effective_annual_cost / 12, currency) : t('privateLifePage.costs.none')}</strong></div>
                          <div className="private-life-card-stat"><span>{t('privateLifePage.marketplace.marketMove')}</span><strong className={Number(marketMove ?? 0) < 0 ? 'private-life-trend-negative' : isPositive ? 'private-life-trend-positive' : ''}>{Number(marketMove ?? 0) < 0 ? <TrendingDown size={12} /> : isPositive ? <TrendingUp size={12} /> : null} {marketMoveText(t, marketMove)}</strong></div>
                          <div className="private-life-card-stat"><span>{t('privateLifePage.purchase.category')}</span><strong>{categoryLabel(t, listing.category)}</strong></div>
                        </div>
                        <div className="private-life-card-actions">
                          <button type="button" className="private-life-action details" onClick={() => setDetailTarget({ type: 'market', listing })}>{t('privateLifePage.assets.details')}</button>
                          <button type="button" className="private-life-action" disabled={!canBuy} onClick={() => setPendingAction({ type: 'buy', listing })}>{listing.effective_owned ? t('privateLifePage.marketplace.owned') : !listing.effective_affordable ? t('privateLifePage.marketplace.insufficient') : t('privateLifePage.marketplace.purchase')}</button>
                        </div>
                        </MobileAssetDisclosure>
                      </div>
                    </article>
                  )
                })}
              </div>
            )}
          </section>
        ) : null}

        <div className="private-life-notice"><span>{t('privateLifePage.footerNote')}</span></div>
      </div>

      <GameConfirmDialog
        open={Boolean(detailDialog)}
        eyebrow={detailDialog?.eyebrow}
        title={detailDialog?.title ?? ''}
        hero={detailDialog?.hero}
        size={detailDialog?.size}
        message={detailDialog?.message ?? ''}
        detail={detailDialog?.detail}
        cancelLabel={t('privateLifePage.dialogs.close')}
        tone="neutral"
        showConfirm={false}
        onConfirm={() => undefined}
        onCancel={() => setDetailTarget(null)}
      />
      <GameConfirmDialog open={Boolean(confirmation)} eyebrow={confirmation?.eyebrow} title={confirmation?.title ?? ''} hero={confirmation?.hero} size={confirmation?.size} message={confirmation?.message ?? ''} detail={confirmation?.detail} confirmLabel={confirmation?.confirmLabel} cancelLabel={t('common.cancel')} busy={actionBusy} tone={confirmation?.tone} onConfirm={confirmAction} onCancel={() => { if (!actionBusy) setPendingAction(null) }} />
    </GameLayout>
  )
}

function CategoryFilters({ value, onChange }: { value: CategoryFilter; onChange: (value: CategoryFilter) => void }) {
  const { t } = useTranslation()
  return (
    <>
      <label className="private-life-category-select">
        <span>{t('privateLifePage.filters.aria')}</span>
        <select
          value={value}
          onChange={(event) => onChange(event.target.value as CategoryFilter)}
          aria-label={t('privateLifePage.filters.aria')}
        >
          <option value="all">{t('privateLifePage.filters.all')}</option>
          {ASSET_CATEGORIES.map((category) => <option key={category} value={category}>{categoryLabel(t, category)}</option>)}
        </select>
      </label>
      <div className="private-life-filter-bar" aria-label={t('privateLifePage.filters.aria')}>
        <button type="button" className={value === 'all' ? 'active' : ''} onClick={() => onChange('all')}>{t('privateLifePage.filters.all')}</button>
        {ASSET_CATEGORIES.map((category) => <button key={category} type="button" className={value === category ? 'active' : ''} onClick={() => onChange(category)}>{categoryLabel(t, category)}</button>)}
      </div>
    </>
  )
}

/** Desktop keeps full cards; on phones asset values and purchase/sale actions
 * are available by expanding the compact summary. */
function MobileAssetDisclosure({ children }: { children: ReactNode }) {
  const { t } = useTranslation()
  const [expanded, setExpanded] = useState(false)
  return (
    <div className={`private-life-card-disclosure${expanded ? ' is-expanded' : ''}`}>
      <button
        type="button"
        className="private-life-card-disclosure-trigger"
        aria-expanded={expanded}
        onClick={() => setExpanded((current) => !current)}
      >
        <span>{expanded ? t('privateLifePage.dialogs.close') : t('privateLifePage.assets.details')}</span>
        <ChevronDown size={16} aria-hidden="true" />
      </button>
      <div className="private-life-card-disclosure-content">{children}</div>
    </div>
  )
}
