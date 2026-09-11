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
import { useCommerce } from '../../hooks/useCommerce'
import { supabase } from '../../lib/supabase'
import '../../styles/private-life.css'

type AssetCategory = 'watch' | 'car' | 'apartment' | 'house_villa' | 'yacht'
type MainTab = 'overview' | 'assets' | 'investments' | 'marketplace'
type CategoryFilter = 'all' | AssetCategory

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
  affordable: boolean
  owned: boolean
}

type OwnedAsset = {
  id: string
  catalog_code: string
  category: AssetCategory
  name: string
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
  net_worth: number
  annual_running_cost: number
  category_totals: CategoryTotal[]
  owned_assets: OwnedAsset[]
  catalog: CatalogAsset[]
}

type PendingAction =
  | { type: 'buy'; asset: CatalogAsset }
  | { type: 'sell'; asset: OwnedAsset }
  | null

const CATEGORY_META: Record<AssetCategory, { label: string }> = {
  watch: { label: 'Watches' },
  car: { label: 'Vehicles' },
  apartment: { label: 'Apartments' },
  house_villa: { label: 'Houses & Villas' },
  yacht: { label: 'Yachts' },
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

function AssetImage({ src, name }: { src: string; name: string }) {
  return (
    <img
      src={src}
      alt={name}
      loading="lazy"
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

  const visibleCatalog = useMemo(() => {
    const source = dashboard?.catalog ?? []
    if (filter === 'all') return source
    return source.filter((asset) => asset.category === filter)
  }, [dashboard?.catalog, filter])

  const visibleOwned = useMemo(() => {
    const source = dashboard?.owned_assets ?? []
    if (filter === 'all') return source
    return source.filter((asset) => asset.category === filter)
  }, [dashboard?.owned_assets, filter])

  async function confirmAction() {
    if (!pendingAction) return
    setActionBusy(true)
    setError(null)
    setNotice(null)

    if (pendingAction.type === 'buy') {
      const asset = pendingAction.asset
      const { error: rpcError } = await supabase.rpc('buy_private_life_asset_v1', {
        p_catalog_code: asset.code,
      })
      if (rpcError) {
        setError(rpcError.message)
        setActionBusy(false)
        setPendingAction(null)
        return
      }
      setNotice(`${asset.name} is now part of your private collection. The payment was posted to Finance.`)
    } else {
      const asset = pendingAction.asset
      const { error: rpcError } = await supabase.rpc('sell_private_life_asset_v1', {
        p_owned_asset_id: asset.id,
      })
      if (rpcError) {
        setError(rpcError.message)
        setActionBusy(false)
        setPendingAction(null)
        return
      }
      setNotice(`${asset.name} was sold. The proceeds were posted to Finance.`)
    }

    setPendingAction(null)
    setActionBusy(false)
    await loadDashboard()
  }

  if (commerceLoading) {
    return (
      <GameLayout title="Private Life" subtitle="Lifestyle, assets and personal wealth">
        <div className="tlg-premium-lock"><span>Checking Premium membership…</span></div>
      </GameLayout>
    )
  }

  if (!isPremium) {
    return (
      <GameLayout title="Private Life" subtitle="Lifestyle, assets and personal wealth">
        <section className="tlg-premium-lock">
          <div className="tlg-premium-lock-icon"><LockKeyhole size={28} /></div>
          <span>Premium feature</span>
          <h2>Private Life</h2>
          <p>Build an off-court lifestyle with the money earned in your tennis career. Purchases and investments use the same Finance balance — never Premium coins.</p>
          <button type="button" onClick={() => navigate('/game/pro-packages')}><Crown size={16} /> View Premium</button>
        </section>
      </GameLayout>
    )
  }

  if (loading && !dashboard) {
    return (
      <GameLayout title="Private Life" subtitle="Lifestyle, assets and personal wealth">
        <div className="private-life-loading"><RefreshCw size={20} /> Loading your private-life portfolio…</div>
      </GameLayout>
    )
  }

  if (error && !dashboard) {
    return (
      <GameLayout title="Private Life" subtitle="Lifestyle, assets and personal wealth">
        <div className="private-life-error">
          <strong>Private Life could not be loaded</strong>
          <p>{error}</p>
          <button className="private-life-refresh" type="button" onClick={() => void loadDashboard()}><RefreshCw size={14} /> Try again</button>
        </div>
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
          title: `Buy ${pendingAction.asset.name}?`,
          message: `${money(pendingAction.asset.purchase_price, currency)} will be taken from your normal career Finance balance.`,
          detail: `Prestige +${pendingAction.asset.prestige} · Expected annual ownership cost ${money(pendingAction.asset.annual_running_cost, currency)} · ${trendText(pendingAction.asset.annual_value_rate_bps)}`,
          confirmLabel: `Buy for ${money(pendingAction.asset.purchase_price, currency)}`,
          tone: 'warning' as const,
        }
      : {
          eyebrow: 'Sell private asset',
          title: `Sell ${pendingAction.asset.name}?`,
          message: `${money(pendingAction.asset.estimated_sale_price, currency)} will be credited to your normal career Finance balance.`,
          detail: `Original price ${money(pendingAction.asset.purchase_price, currency)} · ${pendingAction.asset.potential_gain_loss >= 0 ? 'Potential profit' : 'Potential loss'} ${money(Math.abs(pendingAction.asset.potential_gain_loss), currency)}`,
          confirmLabel: `Sell for ${money(pendingAction.asset.estimated_sale_price, currency)}`,
          tone: 'danger' as const,
        }
    : null

  return (
    <GameLayout title="Private Life" subtitle="Lifestyle, assets and personal wealth">
      <div className="private-life-page">
        <section className="private-life-hero private-life-hero-compact">
          <div className="private-life-hero-copy">
            <div className="private-life-eyebrow">Your life outside tennis</div>
            <h2>Build wealth, collect luxury assets and manage investments.</h2>
            <p>Private Life is your off-court game inside the career: physical possessions, personal wealth and — next — stocks and cryptocurrencies, all connected to the same Finance balance.</p>
          </div>
        </section>

        <section className="private-life-metrics" aria-label="Private wealth summary">
          <div className="private-life-metric"><span>Cash balance</span><strong>{money(dashboard.cash_balance, currency)}</strong></div>
          <div className="private-life-metric"><span>Physical assets</span><strong>{money(dashboard.asset_value, currency)}</strong></div>
          <div className="private-life-metric"><span>Current net worth</span><strong>{money(dashboard.net_worth, currency)}</strong></div>
          <div className="private-life-metric"><span>Prestige</span><strong>{dashboard.prestige}</strong></div>
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
              <div><div className="private-life-section-eyebrow">Private Life dashboard</div><h3>Your off-court world</h3><p>One place for your possessions, investments and future personal-life systems, while Finance remains the source of truth for money.</p></div>
              <button type="button" className="private-life-refresh" disabled={loading} onClick={() => void loadDashboard()}><RefreshCw size={14} /> {loading ? 'Refreshing…' : 'Refresh'}</button>
            </div>

            <div className="private-life-overview-grid">
              <div className="private-life-panel">
                <h4>Physical collection</h4>
                <div className="private-life-category-list">
                  {(Object.keys(CATEGORY_META) as AssetCategory[]).map((category) => {
                    const meta = CATEGORY_META[category]
                    const total = categoryTotals.get(category)
                    return (
                      <div key={category} className="private-life-category-row">
                        <div className="private-life-category-name"><span>{meta.label}</span></div>
                        <span>{total?.owned_count ?? 0} owned</span>
                        <strong>{money(total?.market_value ?? 0, currency)}</strong>
                        <span>+{total?.prestige ?? 0} prestige</span>
                      </div>
                    )
                  })}
                </div>
              </div>

              <div className="private-life-future-stack">
                <article className="private-life-future-card private-life-investment-preview">
                  <div className="private-life-future-card-head"><h4>Investments</h4><span className="private-life-status-pill">Next phase</span></div>
                  <p>Stocks and cryptocurrencies will be part of Private Life, not a separate main-menu system. Trading will use career cash and simulated holdings with real-market prices as reference data.</p>
                  <button type="button" className="private-life-inline-action" onClick={() => setTab('investments')}>View investment area</button>
                </article>
                <article className="private-life-future-card">
                  <div className="private-life-future-card-head"><h4>Value & ownership</h4></div>
                  <p>Cars and yachts usually lose value, while selected property, watches and future collectibles can appreciate over time.</p>
                  <small>Current physical-asset values already follow game-time ownership duration.</small>
                </article>
                <article className="private-life-future-card">
                  <div className="private-life-future-card-head"><h4>Relationships & family</h4></div>
                  <p>Reserved for a later life-stage system. Marriage and children remain outside the simulation until age and career-life rules are defined.</p>
                </article>
              </div>
            </div>
          </section>
        ) : null}

        {tab === 'assets' ? (
          <section className="private-life-section">
            <div className="private-life-section-head">
              <div><div className="private-life-section-eyebrow">Collection</div><h3>My physical assets</h3><p>Track what you paid, what each possession is worth now and the actual resale proceeds before deciding to sell.</p></div>
            </div>
            <CategoryFilters value={filter} onChange={setFilter} />
            {visibleOwned.length === 0 ? (
              <div className="private-life-empty"><strong>No assets in this category yet</strong><p>Visit the Marketplace to start building your private collection.</p></div>
            ) : (
              <div className="private-life-owned-grid">
                {visibleOwned.map((asset) => (
                  <article className="private-life-owned-card" key={asset.id}>
                    <div className="private-life-card-image">
                      <AssetImage src={asset.image_url} name={asset.name} />
                      <div className="private-life-image-badges"><span className="private-life-badge">{rarityLabel(asset.rarity)}</span><span className="private-life-badge level">+{asset.prestige} prestige</span></div>
                    </div>
                    <div className="private-life-card-body">
                      <div className="private-life-card-title-row"><h4>{asset.name}</h4><div className="private-life-price">{money(asset.current_market_value, currency)}</div></div>
                      <p className="private-life-description">{asset.description}</p>
                      <div className="private-life-owned-value-grid">
                        <div className="private-life-owned-value-row"><span>Purchase price</span><strong>{money(asset.purchase_price, currency)}</strong></div>
                        <div className="private-life-owned-value-row"><span>Current market value</span><strong>{money(asset.current_market_value, currency)}</strong></div>
                        <div className="private-life-owned-value-row"><span>Current selling price</span><strong>{money(asset.estimated_sale_price, currency)}</strong></div>
                        <div className="private-life-owned-value-row"><span>Gain / loss if sold</span><strong className={asset.potential_gain_loss >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{asset.potential_gain_loss >= 0 ? '+' : '-'}{money(Math.abs(asset.potential_gain_loss), currency)}</strong></div>
                        <div className="private-life-owned-value-row"><span>Ownership</span><strong>{asset.ownership_days} game days</strong></div>
                        <div className="private-life-owned-value-row"><span>Expected annual cost</span><strong>{money(asset.annual_running_cost, currency)}</strong></div>
                      </div>
                      <button type="button" className="private-life-action secondary" onClick={() => setPendingAction({ type: 'sell', asset })}>Sell asset</button>
                    </div>
                  </article>
                ))}
              </div>
            )}
          </section>
        ) : null}

        {tab === 'investments' ? (
          <section className="private-life-section">
            <div className="private-life-section-head">
              <div><div className="private-life-section-eyebrow">Investments</div><h3>Stocks & cryptocurrencies</h3><p>This area stays inside Private Life. The next implementation phase will add game-only holdings whose prices can follow real external markets, while every buy and sell uses your existing career Finance balance.</p></div>
            </div>

            <div className="private-life-investment-grid">
              <article className="private-life-investment-card">
                <div className="private-life-investment-card-top"><span>Stock market</span><span className="private-life-status-pill">Next phase</span></div>
                <h4>Shares</h4>
                <p>Build a simulated portfolio of recognisable listed companies. Quotes can follow real stock-market prices, but no real shares or brokerage accounts are involved.</p>
                <div className="private-life-investment-features">
                  <span>Buy & sell with career cash</span>
                  <span>Portfolio value and profit / loss</span>
                  <span>Transaction history in Finance</span>
                </div>
                <button type="button" className="private-life-action" disabled>Trading not enabled yet</button>
              </article>

              <article className="private-life-investment-card">
                <div className="private-life-investment-card-top"><span>Crypto market</span><span className="private-life-status-pill">Next phase</span></div>
                <h4>Cryptocurrencies</h4>
                <p>Trade simulated crypto holdings using external market prices as the reference. Holdings remain completely inside the game and never connect to a real wallet.</p>
                <div className="private-life-investment-features">
                  <span>Fractional holdings supported</span>
                  <span>24/7 price reference</span>
                  <span>Portfolio value and profit / loss</span>
                </div>
                <button type="button" className="private-life-action" disabled>Trading not enabled yet</button>
              </article>
            </div>

            <div className="private-life-panel private-life-investment-rules">
              <h4>How investments will fit into the career</h4>
              <div className="private-life-investment-rule-grid">
                <div><span>Money source</span><strong>Existing career Finance balance</strong></div>
                <div><span>Pricing</span><strong>External market prices used only as game reference</strong></div>
                <div><span>Ownership</span><strong>Simulated game holdings only</strong></div>
                <div><span>Accounting</span><strong>Buys, sells and realised gains recorded in Finance</strong></div>
              </div>
            </div>
          </section>
        ) : null}

        {tab === 'marketplace' ? (
          <section className="private-life-section">
            <div className="private-life-section-head">
              <div><div className="private-life-section-eyebrow">Luxury marketplace</div><h3>Buy physical assets</h3><p>Browse possessions across every stage of a career. Everything remains visible, while your Finance balance determines what you can purchase.</p></div>
            </div>
            <CategoryFilters value={filter} onChange={setFilter} />
            <div className="private-life-market-grid">
              {visibleCatalog.map((asset) => {
                const isPositive = asset.annual_value_rate_bps > 0
                const canBuy = asset.affordable && !asset.owned
                return (
                  <article className="private-life-card" key={asset.code}>
                    <div className="private-life-card-image">
                      <AssetImage src={asset.image_url} name={asset.name} />
                      <div className="private-life-image-badges"><span className="private-life-badge">{rarityLabel(asset.rarity)}</span></div>
                    </div>
                    <div className="private-life-card-body">
                      <div className="private-life-card-title-row"><h4>{asset.name}</h4><div className="private-life-price">{money(asset.purchase_price, currency)}</div></div>
                      <p className="private-life-description">{asset.description}</p>
                      <div className="private-life-card-stats">
                        <div className="private-life-card-stat"><span>Prestige</span><strong>+{asset.prestige}</strong></div>
                        <div className="private-life-card-stat"><span>Annual cost</span><strong>{money(asset.annual_running_cost, currency)}</strong></div>
                        <div className="private-life-card-stat"><span>Value trend</span><strong className={asset.annual_value_rate_bps < 0 ? 'private-life-trend-negative' : isPositive ? 'private-life-trend-positive' : ''}>{asset.annual_value_rate_bps < 0 ? <TrendingDown size={12} /> : isPositive ? <TrendingUp size={12} /> : null} {trendText(asset.annual_value_rate_bps)}</strong></div>
                        <div className="private-life-card-stat"><span>Category</span><strong>{categoryLabel(asset.category)}</strong></div>
                      </div>
                      <button
                        type="button"
                        className="private-life-action"
                        disabled={!canBuy}
                        onClick={() => setPendingAction({ type: 'buy', asset })}
                      >
                        {asset.owned ? 'Already owned' : !asset.affordable ? 'Insufficient funds' : 'Purchase asset'}
                      </button>
                    </div>
                  </article>
                )
              })}
            </div>
          </section>
        ) : null}

        <div className="private-life-notice"><span>Private Life uses your existing career Finance account. There is no separate lifestyle currency, and physical assets or investments do not provide direct tennis-skill bonuses.</span></div>
      </div>

      <GameConfirmDialog
        open={Boolean(confirmation)}
        eyebrow={confirmation?.eyebrow}
        title={confirmation?.title ?? ''}
        message={confirmation?.message ?? ''}
        detail={confirmation?.detail}
        confirmLabel={confirmation?.confirmLabel}
        cancelLabel="Cancel"
        busy={actionBusy}
        tone={confirmation?.tone}
        onConfirm={confirmAction}
        onCancel={() => {
          if (!actionBusy) setPendingAction(null)
        }}
      />
    </GameLayout>
  )
}

function CategoryFilters({ value, onChange }: { value: CategoryFilter; onChange: (value: CategoryFilter) => void }) {
  return (
    <div className="private-life-filter-bar" aria-label="Asset category filters">
      <button type="button" className={value === 'all' ? 'active' : ''} onClick={() => onChange('all')}>All</button>
      {(Object.keys(CATEGORY_META) as AssetCategory[]).map((category) => {
        const meta = CATEGORY_META[category]
        return <button key={category} type="button" className={value === category ? 'active' : ''} onClick={() => onChange(category)}>{meta.label}</button>
      })}
    </div>
  )
}
