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
}

type PropertyLocation = {
  code: string
  country_code: string
  country_name: string
  city: string
  apartment_base_price: number
  house_base_price: number
  annual_value_rate_bps: number
  sort_order: number
}

type CategoryTotal = {
  category: AssetCategory
  owned_count: number
  market_value: number
  prestige: number
  annual_running_cost: number
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
  location?: PropertyLocation
}

type PendingAction =
  | { type: 'buy'; listing: MarketplaceListing }
  | { type: 'sell'; asset: OwnedAsset; saleMode: SaleMode; quote: SaleQuote }
  | null

const CATEGORY_META: Record<AssetCategory, { label: string }> = {
  watch: { label: 'Watches' },
  jewelry: { label: 'Jewelry' },
  car: { label: 'Vehicles' },
  apartment: { label: 'Apartments' },
  house_villa: { label: 'Houses & Villas' },
  yacht: { label: 'Yachts' },
  private_jet: { label: 'Private Jets' },
  art: { label: 'Art' },
  collectible: { label: 'Collectibles' },
}

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

function AssetImage({ src, name }: { src: string; name: string }) {
  return <img src={src} alt={name} loading="lazy" onError={(event) => { event.currentTarget.style.opacity = '0' }} />
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
    if (!dashboard || propertyLocationCode) return
    const starter = dashboard.owned_assets.find((asset) => asset.acquisition_type === 'starter_home' && asset.location_code)
    const homeLocation = starter?.location_code ? dashboard.property_locations.find((location) => location.code === starter.location_code) : undefined
    const firstLocation = homeLocation ?? dashboard.property_locations[0]
    if (firstLocation) {
      setPropertyCountry(firstLocation.country_code)
      setPropertyLocationCode(firstLocation.code)
    }
  }, [dashboard, propertyLocationCode])

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
        return [{
          ...asset,
          effective_price: Number(asset.purchase_price),
          effective_annual_cost: Number(asset.annual_running_cost),
          effective_value_rate_bps: Number(asset.annual_value_rate_bps),
          effective_affordable: Boolean(asset.affordable),
          effective_owned: Boolean(asset.owned),
        }]
      }
      if (!selectedPropertyLocation) return []
      const basePrice = asset.category === 'apartment' ? selectedPropertyLocation.apartment_base_price : selectedPropertyLocation.house_base_price
      const multiplier = metadataNumber(asset, 'price_multiplier_bps', 10000)
      const runningCostBps = metadataNumber(asset, 'running_cost_bps', 100)
      const valueAdjustment = metadataNumber(asset, 'value_rate_adjustment_bps', 0)
      const price = Math.round(basePrice * multiplier / 10000)
      const annualCost = Math.round(price * runningCostBps / 10000)
      const valueRate = selectedPropertyLocation.annual_value_rate_bps + valueAdjustment
      const alreadyOwned = (dashboard?.owned_assets ?? []).some((owned) => owned.catalog_code === asset.code && owned.location_code === selectedPropertyLocation.code)
      return [{
        ...asset,
        effective_price: price,
        effective_annual_cost: annualCost,
        effective_value_rate_bps: valueRate,
        effective_affordable: price <= Number(dashboard?.cash_balance ?? 0),
        effective_owned: alreadyOwned,
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
      if (marketSort === 'appreciation_desc') return b.effective_value_rate_bps - a.effective_value_rate_bps || a.effective_price - b.effective_price
      return 0
    })
  }, [filter, marketAffordableOnly, marketPrice, marketRarity, marketSearch, marketSort, marketplaceListings])

  const visibleOwned = useMemo(() => {
    const source = dashboard?.owned_assets ?? []
    if (filter === 'all') return source
    return source.filter((asset) => asset.category === filter)
  }, [dashboard?.owned_assets, filter])

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
          message: `${money(pendingAction.listing.effective_price, currency)} will be taken from your normal career Finance balance.`,
          detail: `Prestige +${pendingAction.listing.prestige} points · Expected annual ownership cost ${money(pendingAction.listing.effective_annual_cost, currency)} · ${trendText(pendingAction.listing.effective_value_rate_bps)}`,
          confirmLabel: `Buy for ${money(pendingAction.listing.effective_price, currency)}`,
          tone: 'warning' as const,
        }
      : {
          eyebrow: 'Sell private asset',
          title: `${SALE_META[pendingAction.saleMode].label}: ${pendingAction.asset.name}?`,
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
          <div className="private-life-metric"><span>Annual ownership cost</span><strong>{money(dashboard.annual_running_cost, currency)}</strong></div>
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
                <article className="private-life-future-card"><div className="private-life-future-card-head"><h4>Property worldwide</h4></div><p>Apartments, houses and villas are now priced by destination. The marketplace contains 50 worldwide locations and different property sizes in each city.</p><small>Your original home city also receives a small starting flat at the beginning of the career.</small></article>
                <article className="private-life-future-card"><div className="private-life-future-card-head"><h4>Resale market</h4></div><p>Owned assets can be sold back to the game. Selling immediately pays less; waiting 7 or 21 game days improves the offer.</p><small>Prestige points disappear when you no longer own the asset.</small></article>
              </div>
            </div>
          </section>
        ) : null}

        {tab === 'assets' ? (
          <section className="private-life-section">
            <div className="private-life-section-head"><div><div className="private-life-section-eyebrow">Collection</div><h3>My physical assets</h3><p>Track current value, prestige points and choose how quickly you want to sell each possession.</p></div></div>
            <CategoryFilters value={filter} onChange={setFilter} />
            {visibleOwned.length === 0 ? <div className="private-life-empty"><strong>No assets in this category yet</strong><p>Visit the Marketplace to start building your private collection.</p></div> : (
              <div className="private-life-owned-grid">
                {visibleOwned.map((asset) => (
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
                        <div className="private-life-owned-value-row"><span>Expected annual cost</span><strong>{money(asset.annual_running_cost, currency)}</strong></div>
                        <div className="private-life-owned-value-row"><span>Value trend</span><strong>{trendText(asset.annual_value_rate_bps)}</strong></div>
                      </div>
                      {asset.pending_sale ? (
                        <div className="private-life-sale-pending"><div><span>Listed for sale</span><strong>{SALE_META[asset.pending_sale.sale_mode].label} · {money(asset.pending_sale.quoted_sale_price, currency)}</strong><small>Settlement game day {asset.pending_sale.settle_absolute_day}</small></div><button type="button" disabled={actionBusy} onClick={() => void cancelSale(asset.pending_sale!.id)}>Cancel sale</button></div>
                      ) : (
                        <div className="private-life-sale-options">
                          {(Object.keys(SALE_META) as SaleMode[]).map((mode) => {
                            const quote = asset.sale_quotes?.[mode]
                            if (!quote) return null
                            return <button key={mode} type="button" onClick={() => setPendingAction({ type: 'sell', asset, saleMode: mode, quote })}><span>{SALE_META[mode].label}</span><strong>{money(quote.price, currency)}</strong><small>{SALE_META[mode].detail}</small></button>
                          })}
                        </div>
                      )}
                    </div>
                  </article>
                ))}
              </div>
            )}
          </section>
        ) : null}

        {tab === 'investments' ? <PrivateLifeInvestments currency={currency} onPortfolioChanged={loadDashboard} /> : null}

        {tab === 'marketplace' ? (
          <section className="private-life-section">
            <div className="private-life-section-head">
              <div><div className="private-life-section-eyebrow">Luxury marketplace</div><h3>Buy physical assets</h3><p>Every item has a game price, value trend and prestige-point value. Watches use fictional brands only. Property prices depend on the selected country and city.</p></div>
              <span className="private-life-market-new-pill">New items</span>
            </div>
            <CategoryFilters value={filter} onChange={setFilter} />

            {(filter === 'all' || filter === 'apartment' || filter === 'house_villa') ? (
              <div className="private-life-property-selector">
                <div><span>Property country</span><select value={propertyCountry} onChange={(event) => { setPropertyCountry(event.target.value); setPropertyLocationCode('') }}>{countries.map((country) => <option key={country.code} value={country.code}>{country.name}</option>)}</select></div>
                <div><span>City</span><select value={propertyLocationCode} onChange={(event) => setPropertyLocationCode(event.target.value)}>{countryLocations.map((location) => <option key={location.code} value={location.code}>{location.city}</option>)}</select></div>
                {selectedPropertyLocation ? <div className="private-life-property-selector-note"><strong>{selectedPropertyLocation.city}</strong><span>Apartment reference {money(selectedPropertyLocation.apartment_base_price, currency)} · House reference {money(selectedPropertyLocation.house_base_price, currency)}</span></div> : null}
              </div>
            ) : null}

            <div className="private-life-marketplace-tools">
              <input value={marketSearch} onChange={(event) => setMarketSearch(event.target.value)} placeholder="Search assets" aria-label="Search marketplace assets" />
              <select value={marketPrice} onChange={(event) => setMarketPrice(event.target.value as MarketplacePrice)} aria-label="Marketplace price filter"><option value="all">All prices</option><option value="under_10k">Under $10K</option><option value="10k_50k">$10K – $50K</option><option value="50k_250k">$50K – $250K</option><option value="250k_1m">$250K – $1M</option><option value="1m_5m">$1M – $5M</option><option value="5m_plus">$5M+</option></select>
              <select value={marketRarity} onChange={(event) => setMarketRarity(event.target.value as MarketplaceRarity)} aria-label="Marketplace rarity filter"><option value="all">All rarities</option><option value="common">Common</option><option value="uncommon">Uncommon</option><option value="rare">Rare</option><option value="very_rare">Very rare</option><option value="legendary">Legendary</option></select>
              <select value={marketSort} onChange={(event) => setMarketSort(event.target.value as MarketplaceSort)} aria-label="Marketplace sort order"><option value="default">Default order</option><option value="price_asc">Price: low to high</option><option value="price_desc">Price: high to low</option><option value="prestige_desc">Prestige: high to low</option><option value="appreciation_desc">Best value trend</option></select>
              <label className="private-life-marketplace-affordable"><input type="checkbox" checked={marketAffordableOnly} onChange={(event) => setMarketAffordableOnly(event.target.checked)} /><span>Affordable only</span></label>
              <button type="button" className="private-life-marketplace-reset" onClick={() => { setMarketSearch(''); setMarketPrice('all'); setMarketRarity('all'); setMarketSort('default'); setMarketAffordableOnly(false); setFilter('all') }}>Reset</button>
            </div>
            <div className="private-life-marketplace-results"><span>{visibleCatalog.length} listings</span><span>{dashboard.catalog.length} base asset types · 50 property destinations</span></div>
            {visibleCatalog.length === 0 ? <div className="private-life-empty"><strong>No marketplace matches</strong><p>Change the category, destination, price or rarity filters to see more assets.</p></div> : (
              <div className="private-life-market-grid">
                {visibleCatalog.map((listing) => {
                  const isPositive = listing.effective_value_rate_bps > 0
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
                          <div className="private-life-card-stat"><span>Annual cost</span><strong>{money(listing.effective_annual_cost, currency)}</strong></div>
                          <div className="private-life-card-stat"><span>Value trend</span><strong className={listing.effective_value_rate_bps < 0 ? 'private-life-trend-negative' : isPositive ? 'private-life-trend-positive' : ''}>{listing.effective_value_rate_bps < 0 ? <TrendingDown size={12} /> : isPositive ? <TrendingUp size={12} /> : null} {trendText(listing.effective_value_rate_bps)}</strong></div>
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

      <GameConfirmDialog open={Boolean(confirmation)} eyebrow={confirmation?.eyebrow} title={confirmation?.title ?? ''} message={confirmation?.message ?? ''} detail={confirmation?.detail} confirmLabel={confirmation?.confirmLabel} cancelLabel="Cancel" busy={actionBusy} tone={confirmation?.tone} onConfirm={confirmAction} onCancel={() => { if (!actionBusy) setPendingAction(null) }} />
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
