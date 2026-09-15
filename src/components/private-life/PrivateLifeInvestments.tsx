import { useCallback, useEffect, useMemo, useState } from 'react'

import GameConfirmDialog from '../common/GameConfirmDialog'
import { supabase } from '../../lib/supabase'
import '../../styles/private-life-investments.css'

type InvestmentTab = 'stocks' | 'crypto' | 'portfolio' | 'history'
type TradeSide = 'buy' | 'sell'
type MarketSort = 'default' | 'move_desc' | 'price_asc' | 'price_desc' | 'symbol'

const STOCK_PAGE_SIZE = 10
const INVESTMENT_HISTORY_PAGE_SIZE = 10

type QuoteMetadata = {
  change_1d_pct?: number | null
  change_1w_pct?: number | null
  change_1m_pct?: number | null
  change_3m_pct?: number | null
  change_1y_pct?: number | null
  high_52w?: number | null
  low_52w?: number | null
  high_24h?: number | null
  low_24h?: number | null
  volume?: number | null
  total_volume?: number | null
  market_cap?: number | null
  market_cap_rank?: number | null
  market_state?: string | null
  history?: unknown[]
  intraday_history?: unknown[]
  game_checked_total_seconds?: number | null
  game_last_change_total_seconds?: number | null
  provider_quote_as_of?: string | null
  price_changed_on_last_check?: boolean | null
  refresh_cadence_game_minutes?: number | null
  refresh_cadence_real_minutes?: number | null
  [key: string]: unknown
}

type InvestmentInstrument = {
  code: string
  asset_type: 'stock' | 'crypto'
  symbol: string
  name: string
  exchange: string | null
  sort_order: number
  metadata: Record<string, unknown>
  price: number | null
  previous_price: number | null
  quote_as_of: string | null
  fetched_at: string | null
  quote_source: string | null
  quote_metadata?: QuoteMetadata | null
  quote_stale: boolean
  tradeable: boolean
  owned_quantity: number
  cost_basis: number
  market_value: number
}

type InvestmentPosition = {
  instrument_code: string
  asset_type: 'stock' | 'crypto'
  symbol: string
  name: string
  exchange: string | null
  quantity: number
  cost_basis: number
  price: number | null
  previous_price?: number | null
  quote_as_of: string | null
  fetched_at: string | null
  quote_source: string | null
  quote_metadata?: QuoteMetadata | null
  market_value: number
  market_value_precise?: number
  unrealized_pnl: number
  unrealized_pnl_precise?: number
  average_buy_price: number
  return_pct?: number
  daily_move_pct?: number | null
}

type DailyHistoryPoint = {
  game_day_index: number
  game_total_seconds: number
  open: number
  close: number
  low: number
  high: number
  snapshots: number
}

type InvestmentTrade = {
  id: string
  instrument_code: string
  asset_type: 'stock' | 'crypto'
  symbol: string
  name: string
  side: TradeSide
  quantity: number
  unit_price: number
  gross_amount: number
  realized_pnl: number
  game_absolute_day: number
  quote_as_of: string
  created_at: string
}

type InvestmentDashboard = {
  player_id: string
  currency: string
  cash_balance: number
  portfolio_value: number
  cost_basis: number
  unrealized_pnl: number
  realized_pnl: number
  positions: InvestmentPosition[]
  instruments: InvestmentInstrument[]
  trades: InvestmentTrade[]
}

type PendingTrade = {
  side: TradeSide
  instrument: InvestmentInstrument
  cashAmount?: number
  quantity?: number
}

type QuoteRefreshResult = {
  ok?: boolean
  updated?: number
  expected?: number
  stock_updated?: number
  crypto_updated?: number
  errors?: string[]
  refreshed_at?: string
}

function money(value: number, currency = 'USD', decimals = 0) {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(Number(value || 0))
}

function marketPrice(value: number | null, currency = 'USD') {
  if (value === null || !Number.isFinite(Number(value))) return '—'
  const numeric = Number(value)
  const decimals = numeric >= 1 ? 2 : numeric >= 0.01 ? 4 : 6
  return money(numeric, currency, decimals)
}

function quantity(value: number, assetType: 'stock' | 'crypto') {
  const digits = assetType === 'crypto' ? 8 : 4
  return Number(value || 0).toLocaleString('en-US', { maximumFractionDigits: digits })
}

function signedMoney(value: number, currency = 'USD', decimals = 0) {
  const prefix = value > 0 ? '+' : value < 0 ? '−' : ''
  return `${prefix}${money(Math.abs(Number(value || 0)), currency, decimals)}`
}

function finiteNumber(value: unknown): number | null {
  const numeric = Number(value)
  return Number.isFinite(numeric) ? numeric : null
}

function pctChange(current: number | null, previous: number | null) {
  const now = Number(current)
  const before = Number(previous)
  if (!Number.isFinite(now) || !Number.isFinite(before) || before <= 0) return null
  return ((now - before) / before) * 100
}

function instrumentMove(instrument: InvestmentInstrument) {
  return finiteNumber(instrument.quote_metadata?.change_1d_pct) ?? pctChange(instrument.price, instrument.previous_price)
}

function percentText(value: number | null) {
  if (value === null || !Number.isFinite(value)) return '—'
  return `${value > 0 ? '+' : ''}${value.toFixed(2)}%`
}

function quoteSource(source: string | null) {
  if (source === 'coingecko') return 'CoinGecko'
  if (source === 'yahoo') return 'Yahoo Finance'
  if (source === 'stooq') return 'Stooq'
  return source || 'Market reference'
}

const GAME_MONTHS = [
  ['January', 31], ['February', 29], ['March', 31], ['April', 30],
  ['May', 31], ['June', 30], ['July', 31], ['August', 31],
  ['September', 30], ['October', 31], ['November', 30], ['December', 31],
] as const

function gameTimeFromSeconds(value: unknown) {
  const raw = finiteNumber(value)
  if (raw === null || raw < 0) return 'Game time unavailable'
  const total = Math.floor(raw)
  const secondsPerDay = 86400
  const secondsPerSeason = 366 * secondsPerDay
  const season = Math.floor(total / secondsPerSeason) + 1
  let dayIndex = Math.floor((total % secondsPerSeason) / secondsPerDay)
  const secondOfDay = total % secondsPerDay
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
  const hour = Math.floor(secondOfDay / 3600)
  const minute = Math.floor((secondOfDay % 3600) / 60)
  return `Season ${season} · ${monthName} ${day} · ${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`
}

function gameDayFromAbsolute(value: number) {
  const raw = Math.max(0, Math.floor(Number(value || 0)))
  const season = Math.floor(raw / 366) + 1
  let dayIndex = raw % 366
  let monthName = 'January'
  let day = 1
  for (const [name, days] of GAME_MONTHS) {
    if (dayIndex < days) { monthName = name; day = dayIndex + 1; break }
    dayIndex -= days
  }
  return `Season ${season} · ${monthName} ${day}`
}

function gameTimeLabel(metadata?: QuoteMetadata | null, mode: 'change' | 'checked' = 'change') {
  return gameTimeFromSeconds(mode === 'checked' ? metadata?.game_checked_total_seconds : metadata?.game_last_change_total_seconds)
}

function compactNumber(value: number | null) {
  if (value === null || !Number.isFinite(value)) return '—'
  return new Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 1 }).format(value)
}

function requestKey(prefix: string) {
  const uuid = globalThis.crypto?.randomUUID?.()
  return `${prefix}-${uuid ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`}`
}

type ChartHistoryPoint = { price: number; gameSeconds: number | null }

function historyPoints(history?: unknown[]): ChartHistoryPoint[] {
  return (history ?? []).map((point) => {
    if (typeof point === 'number') {
      const price = finiteNumber(point)
      return price !== null && price > 0 ? { price, gameSeconds: null } : null
    }
    if (point && typeof point === 'object' && 'p' in point) {
      const raw = point as { p?: unknown; g?: unknown }
      const price = finiteNumber(raw.p)
      if (price === null || price <= 0) return null
      return { price, gameSeconds: finiteNumber(raw.g) }
    }
    return null
  }).filter((point): point is ChartHistoryPoint => point !== null)
}

function historyValues(history?: unknown[]) {
  return historyPoints(history).map((point) => point.price)
}

function Sparkline({ history, currency }: { history?: unknown[]; currency: string }) {
  const historyData = historyPoints(history)
  if (historyData.length < 2) return <div className="private-life-market-chart-empty">Trend data will appear as market-price snapshots accumulate.</div>

  const width = 300
  const height = 82
  const padding = 5
  const values = historyData.map((point) => point.price)
  const min = Math.min(...values)
  const max = Math.max(...values)
  const spread = Math.max(max - min, Math.abs(max) * 0.002, 0.000001)
  const coordinates = historyData.map((point, index) => {
    const x = padding + (index / (historyData.length - 1)) * (width - padding * 2)
    const y = height - padding - ((point.price - min) / spread) * (height - padding * 2)
    return { x, y, point }
  })
  const positive = values[values.length - 1] >= values[0]

  return (
    <svg className={`private-life-market-sparkline ${positive ? 'positive' : 'negative'}`} viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Recent reference price trend. Move the mouse across points to see game dates and prices.">
      <polyline points={coordinates.map(({ x, y }) => `${x.toFixed(2)},${y.toFixed(2)}`).join(' ')} fill="none" vectorEffect="non-scaling-stroke" />
      {coordinates.map(({ x, y, point }, index) => (
        <circle key={`${index}-${x}`} cx={x} cy={y} r="7" fill="transparent">
          <title>{`${gameTimeFromSeconds(point.gameSeconds)} · ${marketPrice(point.price, currency)}`}</title>
        </circle>
      ))}
    </svg>
  )
}

function DailyMarketChart({ history, currency }: { history: DailyHistoryPoint[]; currency: string }) {
  if (history.length < 2) return <div className="private-life-market-chart-empty">Daily trend will appear after prices have been captured on at least two game days.</div>
  const data = history.slice(-30)
  const width = 320
  const height = 126
  const left = 34
  const right = 8
  const top = 8
  const bottom = 28
  const values = data.map((point) => Number(point.close))
  const min = Math.min(...values)
  const max = Math.max(...values)
  const spread = Math.max(max - min, Math.abs(max) * 0.002, 0.000001)
  const coords = data.map((point, index) => ({
    point,
    x: left + (index / Math.max(1, data.length - 1)) * (width - left - right),
    y: height - bottom - ((Number(point.close) - min) / spread) * (height - top - bottom),
  }))
  const positive = values[values.length - 1] >= values[0]
  const labelEvery = Math.max(1, Math.ceil(data.length / 6))
  return (
    <svg className={`private-life-daily-market-chart ${positive ? 'positive' : 'negative'}`} viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Daily game-date market trend">
      {[0, 1, 2, 3, 4].map((line) => {
        const y = top + (line / 4) * (height - top - bottom)
        return <line key={`h-${line}`} x1={left} x2={width - right} y1={y} y2={y} className="grid-line" />
      })}
      {coords.map(({ x }, index) => index % labelEvery === 0 || index === coords.length - 1 ? <line key={`v-${index}`} x1={x} x2={x} y1={top} y2={height - bottom} className="grid-line vertical" /> : null)}
      <polyline points={coords.map(({ x, y }) => `${x.toFixed(2)},${y.toFixed(2)}`).join(' ')} fill="none" vectorEffect="non-scaling-stroke" />
      {coords.map(({ x, y, point }, index) => (
        <g key={`${point.game_day_index}-${index}`}>
          <circle cx={x} cy={y} r="7" fill="transparent"><title>{`${gameTimeFromSeconds(point.game_total_seconds)} · Close ${marketPrice(Number(point.close), currency)} · Open ${marketPrice(Number(point.open), currency)} · Low ${marketPrice(Number(point.low), currency)} · High ${marketPrice(Number(point.high), currency)}`}</title></circle>
          {(index % labelEvery === 0 || index === coords.length - 1) ? <text x={x} y={height - 8} textAnchor="middle">D{point.game_day_index + 1}</text> : null}
        </g>
      ))}
    </svg>
  )
}

function MarketTrendPanel({ instrument, currency, dailyHistory, dailyLoading }: { instrument: InvestmentInstrument; currency: string; dailyHistory: DailyHistoryPoint[]; dailyLoading: boolean }) {
  const stats = instrument.quote_metadata ?? {}
  const intraday = Array.isArray(stats.intraday_history) ? stats.intraday_history : []
  const chartHistory = historyValues(intraday).length >= 2 ? intraday : stats.history
  const chartLabel = historyValues(intraday).length >= 2 ? '15-minute game snapshots' : instrument.asset_type === 'stock' ? 'Recent market sessions' : 'Recent market trend'
  const oneDay = finiteNumber(stats.change_1d_pct) ?? pctChange(instrument.price, instrument.previous_price)
  const oneWeek = finiteNumber(stats.change_1w_pct)
  const oneMonth = finiteNumber(stats.change_1m_pct)
  const oneYear = finiteNumber(stats.change_1y_pct)
  const sector = typeof instrument.metadata?.sector === 'string' ? instrument.metadata.sector : null
  const rangeLow = instrument.asset_type === 'stock' ? finiteNumber(stats.low_52w) : finiteNumber(stats.low_24h)
  const rangeHigh = instrument.asset_type === 'stock' ? finiteNumber(stats.high_52w) : finiteNumber(stats.high_24h)
  const activity = instrument.asset_type === 'stock' ? finiteNumber(stats.volume) : finiteNumber(stats.total_volume)

  return (
    <section className="private-life-market-trends">
      <div className="private-life-market-trends-head">
        <div><span>Market statistics</span><strong>{instrument.symbol} reference trend</strong></div>
        {sector ? <small>{sector}</small> : null}
      </div>
      <div className="private-life-market-chart-label">Daily game-date trend</div>
      {dailyLoading ? <div className="private-life-market-chart-empty">Loading daily market history…</div> : dailyHistory.length >= 2 ? <DailyMarketChart history={dailyHistory} currency={currency} /> : <Sparkline history={chartHistory} currency={currency} />}
      <div className="private-life-market-stat-grid">
        <div><span>{instrument.asset_type === 'crypto' ? '24H' : '1D'}</span><strong className={oneDay !== null && oneDay >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{percentText(oneDay)}</strong></div>
        <div><span>1W</span><strong className={oneWeek !== null && oneWeek >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{percentText(oneWeek)}</strong></div>
        <div><span>1M</span><strong className={oneMonth !== null && oneMonth >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{percentText(oneMonth)}</strong></div>
        <div><span>1Y</span><strong className={oneYear !== null && oneYear >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{percentText(oneYear)}</strong></div>
      </div>
      <div className="private-life-market-range-grid">
        <div><span>{instrument.asset_type === 'stock' ? '52W low' : '24H low'}</span><strong>{marketPrice(rangeLow, currency)}</strong></div>
        <div><span>{instrument.asset_type === 'stock' ? '52W high' : '24H high'}</span><strong>{marketPrice(rangeHigh, currency)}</strong></div>
        <div><span>{instrument.asset_type === 'stock' ? 'Volume' : '24H volume'}</span><strong>{compactNumber(activity)}</strong></div>
        <div><span>Last checked (game time)</span><strong>{gameTimeLabel(instrument.quote_metadata, 'checked')}</strong></div>
        <div><span>Last price change (game time)</span><strong>{gameTimeLabel(instrument.quote_metadata)}</strong></div>
        <div><span>Automatic check cadence</span><strong>Every 15 real minutes</strong></div>
      </div>
      <p>Reference prices are checked every 15 real-world minutes. All timestamps shown to players use Tennis Legacy game time. Stocks only change when the external market provides a new price; crypto can change continuously.</p>
    </section>
  )
}

export default function PrivateLifeInvestments({
  currency = 'USD',
  onPortfolioChanged,
}: {
  currency?: string
  onPortfolioChanged?: () => void | Promise<void>
}) {
  const [dashboard, setDashboard] = useState<InvestmentDashboard | null>(null)
  const [activeTab, setActiveTab] = useState<InvestmentTab>('stocks')
  const [selectedCode, setSelectedCode] = useState<string | null>(null)
  const [tradeSide, setTradeSide] = useState<TradeSide>('buy')
  const [buyAmount, setBuyAmount] = useState('100')
  const [sellQuantity, setSellQuantity] = useState('')
  const [marketSearch, setMarketSearch] = useState('')
  const [marketSector, setMarketSector] = useState('all')
  const [marketSort, setMarketSort] = useState<MarketSort>('default')
  const [marketPage, setMarketPage] = useState(1)
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [tradeBusy, setTradeBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [pendingTrade, setPendingTrade] = useState<PendingTrade | null>(null)
  const [dailyHistory, setDailyHistory] = useState<DailyHistoryPoint[]>([])
  const [dailyHistoryLoading, setDailyHistoryLoading] = useState(false)
  const [tradeHistory, setTradeHistory] = useState<InvestmentTrade[]>([])
  const [tradeHistoryLoaded, setTradeHistoryLoaded] = useState(false)
  const [historyPage, setHistoryPage] = useState(1)

  const loadDashboard = useCallback(async () => {
    const { data, error: rpcError } = await supabase.rpc('get_private_life_investments_dashboard_v1')
    if (rpcError || !data) throw new Error(rpcError?.message ?? 'Unable to load investments.')
    const raw = data as unknown as InvestmentDashboard
    const next: InvestmentDashboard = {
      ...raw,
      positions: Array.isArray(raw.positions) ? raw.positions : [],
      instruments: Array.isArray(raw.instruments) ? raw.instruments : [],
      trades: Array.isArray(raw.trades) ? raw.trades : [],
    }
    setDashboard(next)
    return next
  }, [])

  const refreshQuotes = useCallback(async (showStatus = true) => {
    if (showStatus) setRefreshing(true)
    setError(null)
    try {
      const { data, error: functionError } = await supabase.functions.invoke('refresh-private-life-investment-quotes', { body: {} })
      if (functionError) throw new Error(functionError.message)
      const result = (data ?? {}) as QuoteRefreshResult
      const next = await loadDashboard()
      if (result.errors?.length) {
        setNotice(`Market prices refreshed for ${result.updated ?? 0} instruments (${result.stock_updated ?? 0} stocks, ${result.crypto_updated ?? 0} crypto). Some reference quotes are temporarily unavailable.`)
      } else if (showStatus) {
        setNotice(`Market prices refreshed for ${result.updated ?? next.instruments.filter((item) => item.price !== null).length} instruments.`)
      }
      await onPortfolioChanged?.()
      return next
    } catch (refreshError) {
      setError(refreshError instanceof Error ? refreshError.message : 'Unable to refresh market prices.')
      return null
    } finally {
      if (showStatus) setRefreshing(false)
    }
  }, [loadDashboard, onPortfolioChanged])

  useEffect(() => {
    let cancelled = false
    async function initialise() {
      setLoading(true)
      setError(null)
      try {
        const first = await loadDashboard()
        if (cancelled) return
        const needsQuotes = first.instruments.some((item) => item.price === null || item.quote_stale)
        if (needsQuotes) await refreshQuotes(false)
      } catch (loadError) {
        if (!cancelled) setError(loadError instanceof Error ? loadError.message : 'Unable to load investments.')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    void initialise()
    return () => { cancelled = true }
  }, [loadDashboard, refreshQuotes])

  useEffect(() => {
    let cancelled = false
    async function loadDailyHistory() {
      if (!selectedCode) { setDailyHistory([]); return }
      setDailyHistoryLoading(true)
      const { data, error: rpcError } = await supabase.rpc('get_private_life_investment_daily_history_v1', { p_instrument_code: selectedCode })
      if (!cancelled) {
        if (rpcError) setDailyHistory([])
        else setDailyHistory(Array.isArray(data) ? data as unknown as DailyHistoryPoint[] : [])
        setDailyHistoryLoading(false)
      }
    }
    void loadDailyHistory()
    return () => { cancelled = true }
  }, [selectedCode])

  useEffect(() => {
    if (activeTab !== 'history' || tradeHistoryLoaded) return
    let cancelled = false
    async function loadTradeHistory() {
      const { data, error: rpcError } = await supabase.rpc('get_private_life_investment_trade_history_v1')
      if (cancelled) return
      if (rpcError) setError(rpcError.message)
      else {
        setTradeHistory(Array.isArray(data) ? data as unknown as InvestmentTrade[] : [])
        setTradeHistoryLoaded(true)
        setHistoryPage(1)
      }
    }
    void loadTradeHistory()
    return () => { cancelled = true }
  }, [activeTab, tradeHistoryLoaded])

  const stockInstruments = useMemo(() => dashboard?.instruments.filter((item) => item.asset_type === 'stock') ?? [], [dashboard])
  const cryptoInstruments = useMemo(() => dashboard?.instruments.filter((item) => item.asset_type === 'crypto') ?? [], [dashboard])
  const stockSectors = useMemo(() => Array.from(new Set(stockInstruments.map((item) => typeof item.metadata?.sector === 'string' ? item.metadata.sector : null).filter((value): value is string => Boolean(value)))).sort(), [stockInstruments])

  const visibleMarket = useMemo(() => {
    const source = activeTab === 'crypto' ? cryptoInstruments : stockInstruments
    const search = marketSearch.trim().toLowerCase()
    const filtered = source.filter((instrument) => {
      if (search && !`${instrument.symbol} ${instrument.name}`.toLowerCase().includes(search)) return false
      if (activeTab === 'stocks' && marketSector !== 'all' && instrument.metadata?.sector !== marketSector) return false
      return true
    })
    return [...filtered].sort((a, b) => {
      if (marketSort === 'symbol') return a.symbol.localeCompare(b.symbol)
      if (marketSort === 'price_asc') return Number(a.price ?? Number.POSITIVE_INFINITY) - Number(b.price ?? Number.POSITIVE_INFINITY)
      if (marketSort === 'price_desc') return Number(b.price ?? -1) - Number(a.price ?? -1)
      if (marketSort === 'move_desc') return Number(instrumentMove(b) ?? -9999) - Number(instrumentMove(a) ?? -9999)
      return a.sort_order - b.sort_order
    })
  }, [activeTab, cryptoInstruments, marketSearch, marketSector, marketSort, stockInstruments])

  useEffect(() => {
    setMarketPage(1)
  }, [activeTab, marketSearch, marketSector, marketSort])

  const marketPageCount = activeTab === 'stocks' ? Math.max(1, Math.ceil(visibleMarket.length / STOCK_PAGE_SIZE)) : 1
  const pagedMarket = useMemo(
    () => activeTab === 'stocks' ? visibleMarket.slice((marketPage - 1) * STOCK_PAGE_SIZE, marketPage * STOCK_PAGE_SIZE) : visibleMarket,
    [activeTab, marketPage, visibleMarket],
  )

  useEffect(() => {
    if (marketPage > marketPageCount) setMarketPage(marketPageCount)
  }, [marketPage, marketPageCount])

  useEffect(() => {
    if (activeTab !== 'stocks' && activeTab !== 'crypto') return
    if (!pagedMarket.length) {
      setSelectedCode(null)
      return
    }
    if (!selectedCode || !pagedMarket.some((item) => item.code === selectedCode)) {
      setSelectedCode(pagedMarket[0].code)
      setTradeSide('buy')
      setSellQuantity('')
    }
  }, [activeTab, pagedMarket, selectedCode])

  const selectedInstrument = dashboard?.instruments.find((item) => item.code === selectedCode) ?? null
  const selectedPosition = dashboard?.positions.find((item) => item.instrument_code === selectedCode) ?? null
  const parsedBuyAmount = Math.floor(Number(buyAmount))
  const parsedSellQuantity = Number(sellQuantity)
  const estimatedBuyQuantity = selectedInstrument?.price && parsedBuyAmount > 0 ? parsedBuyAmount / Number(selectedInstrument.price) : 0
  const estimatedSaleValue = selectedInstrument?.price && parsedSellQuantity > 0 ? Math.round(parsedSellQuantity * Number(selectedInstrument.price)) : 0
  const safePositions = dashboard?.positions ?? []
  const portfolioValuePrecise = safePositions.reduce((sum, position) => sum + Number(position.market_value_precise ?? position.market_value ?? 0), 0)
  const unrealizedPrecise = safePositions.reduce((sum, position) => sum + Number(position.unrealized_pnl_precise ?? position.unrealized_pnl ?? 0), 0)

  function beginBuy() {
    if (!selectedInstrument) return
    if (!selectedInstrument.tradeable || !selectedInstrument.price) {
      setError('A current market reference quote is required before trading.')
      return
    }
    if (!Number.isFinite(parsedBuyAmount) || parsedBuyAmount < 10) {
      setError('Minimum investment is $10.')
      return
    }
    if (parsedBuyAmount > Number(dashboard?.cash_balance ?? 0)) {
      setError('This investment is higher than your available career cash balance.')
      return
    }
    setError(null)
    setPendingTrade({ side: 'buy', instrument: selectedInstrument, cashAmount: parsedBuyAmount })
  }

  function beginSell() {
    if (!selectedInstrument || !selectedPosition) return
    if (!selectedInstrument.tradeable || !selectedInstrument.price) {
      setError('A current market reference quote is required before trading.')
      return
    }
    if (!Number.isFinite(parsedSellQuantity) || parsedSellQuantity <= 0) {
      setError('Enter a quantity to sell.')
      return
    }
    if (parsedSellQuantity > Number(selectedPosition.quantity) + 0.0000000001) {
      setError('The sell quantity is higher than your current holding.')
      return
    }
    setError(null)
    setPendingTrade({ side: 'sell', instrument: selectedInstrument, quantity: parsedSellQuantity })
  }

  function beginPortfolioSell(position: InvestmentPosition) {
    const instrument = dashboard?.instruments.find((item) => item.code === position.instrument_code)
    if (!instrument || !instrument.tradeable || !instrument.price) {
      setError('A current market reference quote is required before selling this holding.')
      return
    }
    setError(null)
    setPendingTrade({ side: 'sell', instrument, quantity: Number(position.quantity) })
  }

  async function confirmTrade() {
    if (!pendingTrade) return
    setTradeBusy(true)
    setError(null)
    setNotice(null)
    try {
      if (pendingTrade.side === 'buy') {
        const cashAmount = Number(pendingTrade.cashAmount ?? 0)
        const { error: rpcError } = await supabase.rpc('buy_private_life_investment_v1', {
          p_instrument_code: pendingTrade.instrument.code,
          p_cash_amount: cashAmount,
          p_request_key: requestKey('buy'),
        })
        if (rpcError) throw new Error(rpcError.message)
        setNotice(`${pendingTrade.instrument.symbol} added to your simulated portfolio. ${money(cashAmount, currency)} was posted to Finance.`)
      } else {
        const sellQty = Number(pendingTrade.quantity ?? 0)
        const { error: rpcError } = await supabase.rpc('sell_private_life_investment_v1', {
          p_instrument_code: pendingTrade.instrument.code,
          p_quantity: sellQty,
          p_request_key: requestKey('sell'),
        })
        if (rpcError) throw new Error(rpcError.message)
        setNotice(`${quantity(sellQty, pendingTrade.instrument.asset_type)} ${pendingTrade.instrument.symbol} sold and the proceeds were posted to Finance.`)
        setSellQuantity('')
      }
      setPendingTrade(null)
      setTradeHistoryLoaded(false)
      await loadDashboard()
      await onPortfolioChanged?.()
    } catch (tradeError) {
      setError(tradeError instanceof Error ? tradeError.message : 'The investment trade could not be completed.')
      setPendingTrade(null)
    } finally {
      setTradeBusy(false)
    }
  }

  if (loading && !dashboard) return <div className="private-life-loading">Loading investment markets and portfolio…</div>

  if (!dashboard) {
    return <div className="private-life-error"><strong>Investments could not be loaded</strong><p>{error ?? 'Please try again.'}</p><button type="button" className="private-life-refresh" onClick={() => void loadDashboard()}>Try again</button></div>
  }

  const pendingConfirmation = pendingTrade
    ? pendingTrade.side === 'buy'
      ? {
          title: `Buy ${pendingTrade.instrument.symbol}?`,
          message: `${money(Number(pendingTrade.cashAmount ?? 0), currency)} will be taken from your career Finance balance.`,
          detail: `Reference quote ${marketPrice(pendingTrade.instrument.price, currency)} · Estimated holding ${quantity((Number(pendingTrade.cashAmount ?? 0) / Number(pendingTrade.instrument.price || 1)), pendingTrade.instrument.asset_type)} ${pendingTrade.instrument.symbol}.`,
          confirmLabel: 'Confirm purchase',
        }
      : {
          title: `Sell ${pendingTrade.instrument.symbol}?`,
          message: `${quantity(Number(pendingTrade.quantity ?? 0), pendingTrade.instrument.asset_type)} ${pendingTrade.instrument.symbol} will be sold at the current game reference quote.`,
          detail: `Reference quote ${marketPrice(pendingTrade.instrument.price, currency)} · Estimated proceeds ${money(Math.round(Number(pendingTrade.quantity ?? 0) * Number(pendingTrade.instrument.price || 0)), currency)}.`,
          confirmLabel: 'Confirm sale',
        }
    : null

  return (
    <section className="private-life-investments">
      <div className="private-life-section-head">
        <div>
          <div className="private-life-section-eyebrow">Investments</div>
          <h3>Stocks & cryptocurrencies</h3>
          <p>Build simulated holdings using your normal career cash. Market prices are external reference quotes only — no real brokerage account, shares, crypto wallet or real-money trading is involved.</p>
        </div>
        <button type="button" className="private-life-refresh" disabled={refreshing} onClick={() => void refreshQuotes(true)}>{refreshing ? 'Refreshing prices…' : 'Refresh market prices'}</button>
      </div>

      <div className="private-life-market-update-note"><strong>Automatic market cache:</strong> prices are checked every 15 real-world minutes. Stocks can only change while their external market provides a new quote; crypto can move continuously 24/7. The displayed check/change timestamps are always Tennis Legacy game time.</div>

      <div className="private-life-investment-summary" aria-label="Investment portfolio summary">
        <div><span>Career cash</span><strong>{money(dashboard.cash_balance, currency)}</strong></div>
        <div><span>Portfolio value</span><strong>{money(portfolioValuePrecise, currency, 2)}</strong></div>
        <div><span>Cost basis</span><strong>{money(dashboard.cost_basis, currency)}</strong></div>
        <div><span>Unrealized P/L</span><strong className={unrealizedPrecise >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{signedMoney(unrealizedPrecise, currency, 2)}</strong></div>
        <div><span>Realized P/L</span><strong className={dashboard.realized_pnl >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{signedMoney(dashboard.realized_pnl, currency)}</strong></div>
      </div>

      <nav className="private-life-investment-tabs" aria-label="Investment sections">
        <button type="button" className={activeTab === 'stocks' ? 'active' : ''} onClick={() => setActiveTab('stocks')}>Stocks ({stockInstruments.length})</button>
        <button type="button" className={activeTab === 'crypto' ? 'active' : ''} onClick={() => setActiveTab('crypto')}>Crypto ({cryptoInstruments.length})</button>
        <button type="button" className={activeTab === 'portfolio' ? 'active' : ''} onClick={() => setActiveTab('portfolio')}>Portfolio ({dashboard.positions.length})</button>
        <button type="button" className={activeTab === 'history' ? 'active' : ''} onClick={() => setActiveTab('history')}>History</button>
      </nav>

      {notice ? <div className="private-life-investment-message success">{notice}</div> : null}
      {error ? <div className="private-life-investment-message error">{error}</div> : null}

      {activeTab === 'stocks' || activeTab === 'crypto' ? (
        <div className="private-life-investment-market-layout">
          <div className="private-life-investment-table-panel">
            <div className="private-life-investment-table-head">
              <div><strong>{activeTab === 'stocks' ? 'Stock market' : 'Crypto market'}</strong><span>{activeTab === 'stocks' ? 'Yahoo Finance reference quotes; exchange delay may apply.' : '24/7 CoinGecko reference prices.'}</span></div>
              <span>{visibleMarket.filter((item) => item.price !== null).length}/{visibleMarket.length} priced</span>
            </div>
            <div className="private-life-investment-market-tools">
              <input value={marketSearch} onChange={(event) => setMarketSearch(event.target.value)} placeholder={`Search ${activeTab === 'stocks' ? 'companies or tickers' : 'crypto'}`} aria-label="Search investment market" />
              {activeTab === 'stocks' ? <select value={marketSector} onChange={(event) => setMarketSector(event.target.value)} aria-label="Stock sector filter"><option value="all">All sectors</option>{stockSectors.map((sector) => <option key={sector} value={sector}>{sector}</option>)}</select> : null}
              <select value={marketSort} onChange={(event) => setMarketSort(event.target.value as MarketSort)} aria-label="Investment sort order"><option value="default">Default order</option><option value="move_desc">Best daily move</option><option value="price_asc">Price: low to high</option><option value="price_desc">Price: high to low</option><option value="symbol">Ticker A–Z</option></select>
            </div>
            <div className="private-life-investment-table-wrap">
              <table className="private-life-investment-table">
                <thead><tr><th>Asset</th><th>Price</th><th>Move</th><th>Owned</th><th>Value</th><th>Status</th></tr></thead>
                <tbody>
                  {pagedMarket.map((instrument) => {
                    const move = instrumentMove(instrument)
                    return (
                      <tr key={instrument.code} className={selectedCode === instrument.code ? 'selected' : ''} onClick={() => setSelectedCode(instrument.code)}>
                        <td><strong>{instrument.symbol}</strong><span>{instrument.name}{instrument.exchange ? ` · ${instrument.exchange}` : ''}</span></td>
                        <td><strong>{marketPrice(instrument.price, currency)}</strong><span>{quoteSource(instrument.quote_source)}</span></td>
                        <td>{move === null ? <span>—</span> : <strong className={move >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{percentText(move)}</strong>}</td>
                        <td>{quantity(Number(instrument.owned_quantity || 0), instrument.asset_type)}</td>
                        <td>{money(Number(instrument.market_value || 0), currency)}</td>
                        <td><span className={`private-life-quote-status ${instrument.tradeable ? instrument.quote_stale ? 'stale' : 'ready' : 'unavailable'}`}>{instrument.tradeable ? instrument.quote_stale ? 'Delayed' : 'Ready' : 'Unavailable'}</span></td>
                      </tr>
                    )
                  })}
                  {visibleMarket.length === 0 ? <tr><td colSpan={6}><div className="private-life-empty"><strong>No market matches</strong><p>Change your search or filters to see more instruments.</p></div></td></tr> : null}
                </tbody>
              </table>
            </div>
            {activeTab === 'stocks' && visibleMarket.length > STOCK_PAGE_SIZE ? (
              <div className="private-life-market-pagination">
                <button type="button" disabled={marketPage <= 1} onClick={() => setMarketPage((page) => Math.max(1, page - 1))}>Previous</button>
                <span>Page <strong>{marketPage}</strong> of {marketPageCount} · {STOCK_PAGE_SIZE} stocks per page</span>
                <button type="button" disabled={marketPage >= marketPageCount} onClick={() => setMarketPage((page) => Math.min(marketPageCount, page + 1))}>Next</button>
              </div>
            ) : null}
          </div>

          <div className="private-life-investment-side">
            <aside className="private-life-trade-ticket">
              {selectedInstrument ? (
                <>
                  <div className="private-life-trade-ticket-heading"><div><span>{selectedInstrument.asset_type === 'stock' ? 'Stock' : 'Cryptocurrency'}</span><h4>{selectedInstrument.symbol} · {selectedInstrument.name}</h4></div><strong>{marketPrice(selectedInstrument.price, currency)}</strong></div>
                  <div className="private-life-trade-quote-meta"><span>{quoteSource(selectedInstrument.quote_source)}</span><span>{gameTimeLabel(selectedInstrument.quote_metadata, 'checked')}</span></div>
                  <div className="private-life-trade-side-tabs"><button type="button" className={tradeSide === 'buy' ? 'active' : ''} onClick={() => setTradeSide('buy')}>Buy</button><button type="button" className={tradeSide === 'sell' ? 'active' : ''} disabled={Number(selectedInstrument.owned_quantity || 0) <= 0} onClick={() => setTradeSide('sell')}>Sell</button></div>
                  {tradeSide === 'buy' ? (
                    <div className="private-life-trade-form">
                      <label>Amount from Finance</label><div className="private-life-trade-input"><span>$</span><input type="number" min="10" step="10" value={buyAmount} onChange={(event) => setBuyAmount(event.target.value)} /></div>
                      <div className="private-life-trade-helper"><span>Cash available</span><strong>{money(dashboard.cash_balance, currency)}</strong></div>
                      <div className="private-life-trade-helper"><span>Estimated quantity</span><strong>{quantity(estimatedBuyQuantity, selectedInstrument.asset_type)} {selectedInstrument.symbol}</strong></div>
                      <button type="button" className="private-life-action" disabled={!selectedInstrument.tradeable || parsedBuyAmount < 10 || parsedBuyAmount > dashboard.cash_balance} onClick={beginBuy}>Buy {selectedInstrument.symbol}</button>
                    </div>
                  ) : (
                    <div className="private-life-trade-form">
                      <label>Quantity to sell</label><div className="private-life-trade-input"><input type="number" min="0" step="any" value={sellQuantity} onChange={(event) => setSellQuantity(event.target.value)} /></div>
                      <div className="private-life-trade-helper"><span>You own</span><strong>{quantity(Number(selectedInstrument.owned_quantity || 0), selectedInstrument.asset_type)} {selectedInstrument.symbol}</strong></div>
                      <div className="private-life-trade-quick-actions"><button type="button" onClick={() => setSellQuantity(String(Number(selectedInstrument.owned_quantity || 0) * 0.25))}>25%</button><button type="button" onClick={() => setSellQuantity(String(Number(selectedInstrument.owned_quantity || 0) * 0.5))}>50%</button><button type="button" onClick={() => setSellQuantity(String(Number(selectedInstrument.owned_quantity || 0)))}>All</button></div>
                      <div className="private-life-trade-helper"><span>Estimated proceeds</span><strong>{money(estimatedSaleValue, currency)}</strong></div>
                      <button type="button" className="private-life-action secondary" disabled={!selectedInstrument.tradeable || !selectedPosition || parsedSellQuantity <= 0 || parsedSellQuantity > Number(selectedPosition.quantity)} onClick={beginSell}>Sell {selectedInstrument.symbol}</button>
                    </div>
                  )}
                </>
              ) : <div className="private-life-empty"><strong>Select an investment</strong><p>Choose a market row to open the trade ticket.</p></div>}
            </aside>
            {selectedInstrument ? <MarketTrendPanel instrument={selectedInstrument} currency={currency} dailyHistory={dailyHistory} dailyLoading={dailyHistoryLoading} /> : null}
          </div>
        </div>
      ) : null}

      {activeTab === 'portfolio' ? (
        <div className="private-life-investment-table-panel">
          <div className="private-life-investment-table-head"><div><strong>Your simulated portfolio</strong><span>Current price, daily market move and your gain/loss since purchase. Click a holding to open its market statistics.</span></div></div>
          {dashboard.positions.length === 0 ? <div className="private-life-empty"><strong>No investments yet</strong><p>Use the Stocks or Crypto tab to make your first game-only investment.</p></div> : (
            <div className="private-life-investment-table-wrap">
              <table className="private-life-investment-table portfolio private-life-portfolio-movement-table">
                <thead><tr><th>Asset</th><th>Quantity</th><th>Avg. buy</th><th>Current price</th><th>Daily move</th><th>Market value</th><th>Since buy</th><th>Action</th></tr></thead>
                <tbody>{dashboard.positions.map((position) => {
                  const preciseValue = Number(position.market_value_precise ?? position.market_value ?? 0)
                  const precisePnl = Number(position.unrealized_pnl_precise ?? position.unrealized_pnl ?? 0)
                  const dailyMove = finiteNumber(position.daily_move_pct) ?? pctChange(position.price, position.previous_price ?? null)
                  const returnPct = finiteNumber(position.return_pct) ?? (position.cost_basis > 0 ? (precisePnl / position.cost_basis) * 100 : 0)
                  return (
                    <tr key={position.instrument_code} className="private-life-portfolio-row" onClick={() => { setSelectedCode(position.instrument_code); setMarketPage(1); setActiveTab(position.asset_type === 'stock' ? 'stocks' : 'crypto') }}>
                      <td><strong>{position.symbol}</strong><span>{position.name}</span></td>
                      <td>{quantity(Number(position.quantity), position.asset_type)}</td>
                      <td>{marketPrice(Number(position.average_buy_price), currency)}</td>
                      <td><strong>{marketPrice(position.price, currency)}</strong><span>{gameTimeLabel(position.quote_metadata, 'checked')}</span></td>
                      <td><strong className={dailyMove !== null && dailyMove >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{percentText(dailyMove)}</strong></td>
                      <td>{money(preciseValue, currency, 2)}</td>
                      <td><strong className={precisePnl >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{signedMoney(precisePnl, currency, 2)}</strong><span className={returnPct >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{percentText(returnPct)}</span></td>
                      <td><button type="button" className="private-life-portfolio-sell" onClick={(event) => { event.stopPropagation(); beginPortfolioSell(position) }}>Sell</button></td>
                    </tr>
                  )
                })}</tbody>
              </table>
            </div>
          )}
        </div>
      ) : null}

      {activeTab === 'history' ? (
        <div className="private-life-investment-table-panel">
          <div className="private-life-investment-table-head"><div><strong>Investment history</strong><span>Permanent trade history. Older seasons remain available and can be archived by season later.</span></div></div>
          {tradeHistory.length === 0 ? <div className="private-life-empty"><strong>No investment trades yet</strong><p>Your completed buys and sells will appear here.</p></div> : (
            <>
              <div className="private-life-investment-table-wrap"><table className="private-life-investment-table history"><thead><tr><th>Game date</th><th>Trade</th><th>Asset</th><th>Quantity</th><th>Unit price</th><th>Cash value</th><th>Realized P/L</th></tr></thead><tbody>{tradeHistory.slice((historyPage - 1) * INVESTMENT_HISTORY_PAGE_SIZE, historyPage * INVESTMENT_HISTORY_PAGE_SIZE).map((trade) => <tr key={trade.id}><td><strong>{gameDayFromAbsolute(trade.game_absolute_day)}</strong></td><td><span className={`private-life-trade-side ${trade.side}`}>{trade.side}</span></td><td><strong>{trade.symbol}</strong><span>{trade.name}</span></td><td>{quantity(Number(trade.quantity), trade.asset_type)}</td><td>{marketPrice(Number(trade.unit_price), currency)}</td><td>{money(trade.gross_amount, currency)}</td><td>{trade.side === 'sell' ? <strong className={trade.realized_pnl >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{signedMoney(trade.realized_pnl, currency)}</strong> : <span>—</span>}</td></tr>)}</tbody></table></div>
              {tradeHistory.length > INVESTMENT_HISTORY_PAGE_SIZE ? <div className="private-life-market-pagination"><button type="button" disabled={historyPage <= 1} onClick={() => setHistoryPage((page) => Math.max(1, page - 1))}>Previous</button><span>Page <strong>{historyPage}</strong> of {Math.ceil(tradeHistory.length / INVESTMENT_HISTORY_PAGE_SIZE)} · 10 trades per page</span><button type="button" disabled={historyPage >= Math.ceil(tradeHistory.length / INVESTMENT_HISTORY_PAGE_SIZE)} onClick={() => setHistoryPage((page) => Math.min(Math.ceil(tradeHistory.length / INVESTMENT_HISTORY_PAGE_SIZE), page + 1))}>Next</button></div> : null}
            </>
          )}
        </div>
      ) : null}

      <div className="private-life-investment-disclaimer">Market data is used only as a reference for this game simulation. Stock quotes can be delayed and only change when the real underlying market trades; crypto quotes are external reference prices. Tennis Legacy never buys real securities or cryptocurrency on your behalf.</div>

      <GameConfirmDialog open={Boolean(pendingConfirmation)} eyebrow="Simulated investment trade" title={pendingConfirmation?.title ?? ''} message={pendingConfirmation?.message ?? ''} detail={pendingConfirmation?.detail} confirmLabel={pendingConfirmation?.confirmLabel} cancelLabel="Cancel" busy={tradeBusy} tone="warning" onConfirm={confirmTrade} onCancel={() => { if (!tradeBusy) setPendingTrade(null) }} />
    </section>
  )
}
