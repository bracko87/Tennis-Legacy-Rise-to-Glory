import { useCallback, useEffect, useMemo, useState } from 'react'

import GameConfirmDialog from '../common/GameConfirmDialog'
import { supabase } from '../../lib/supabase'
import '../../styles/private-life-investments.css'

type InvestmentTab = 'stocks' | 'crypto' | 'portfolio' | 'history'
type TradeSide = 'buy' | 'sell'

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
  quote_as_of: string | null
  fetched_at: string | null
  quote_source: string | null
  market_value: number
  unrealized_pnl: number
  average_buy_price: number
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

function signedMoney(value: number, currency = 'USD') {
  const prefix = value > 0 ? '+' : value < 0 ? '−' : ''
  return `${prefix}${money(Math.abs(Number(value || 0)), currency)}`
}

function pctChange(current: number | null, previous: number | null) {
  const now = Number(current)
  const before = Number(previous)
  if (!Number.isFinite(now) || !Number.isFinite(before) || before <= 0) return null
  return ((now - before) / before) * 100
}

function quoteSource(source: string | null) {
  if (source === 'coingecko') return 'CoinGecko'
  if (source === 'stooq') return 'Stooq'
  return source || 'Market reference'
}

function quoteTime(value: string | null) {
  if (!value) return 'No quote yet'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'Quote time unavailable'
  return date.toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })
}

function requestKey(prefix: string) {
  const uuid = globalThis.crypto?.randomUUID?.()
  return `${prefix}-${uuid ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`}`
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
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [tradeBusy, setTradeBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [pendingTrade, setPendingTrade] = useState<PendingTrade | null>(null)

  const loadDashboard = useCallback(async () => {
    const { data, error: rpcError } = await supabase.rpc('get_private_life_investments_dashboard_v1')
    if (rpcError || !data) throw new Error(rpcError?.message ?? 'Unable to load investments.')
    const next = data as unknown as InvestmentDashboard
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
        setNotice(`Market prices refreshed for ${result.updated ?? 0} instruments. Some reference quotes are temporarily unavailable.`)
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

  const stockInstruments = useMemo(() => dashboard?.instruments.filter((item) => item.asset_type === 'stock') ?? [], [dashboard])
  const cryptoInstruments = useMemo(() => dashboard?.instruments.filter((item) => item.asset_type === 'crypto') ?? [], [dashboard])
  const visibleMarket = activeTab === 'crypto' ? cryptoInstruments : stockInstruments

  useEffect(() => {
    if (activeTab !== 'stocks' && activeTab !== 'crypto') return
    if (!visibleMarket.length) return
    if (!selectedCode || !visibleMarket.some((item) => item.code === selectedCode)) {
      setSelectedCode(visibleMarket[0].code)
      setTradeSide('buy')
      setSellQuantity('')
    }
  }, [activeTab, selectedCode, visibleMarket])

  const selectedInstrument = dashboard?.instruments.find((item) => item.code === selectedCode) ?? null
  const selectedPosition = dashboard?.positions.find((item) => item.instrument_code === selectedCode) ?? null
  const parsedBuyAmount = Math.floor(Number(buyAmount))
  const parsedSellQuantity = Number(sellQuantity)
  const estimatedBuyQuantity = selectedInstrument?.price && parsedBuyAmount > 0 ? parsedBuyAmount / Number(selectedInstrument.price) : 0
  const estimatedSaleValue = selectedInstrument?.price && parsedSellQuantity > 0 ? Math.round(parsedSellQuantity * Number(selectedInstrument.price)) : 0

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
      await loadDashboard()
      await onPortfolioChanged?.()
    } catch (tradeError) {
      setError(tradeError instanceof Error ? tradeError.message : 'The investment trade could not be completed.')
      setPendingTrade(null)
    } finally {
      setTradeBusy(false)
    }
  }

  if (loading && !dashboard) {
    return <div className="private-life-loading">Loading investment markets and portfolio…</div>
  }

  if (!dashboard) {
    return (
      <div className="private-life-error">
        <strong>Investments could not be loaded</strong>
        <p>{error ?? 'Please try again.'}</p>
        <button type="button" className="private-life-refresh" onClick={() => void loadDashboard()}>Try again</button>
      </div>
    )
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

      <div className="private-life-investment-summary" aria-label="Investment portfolio summary">
        <div><span>Career cash</span><strong>{money(dashboard.cash_balance, currency)}</strong></div>
        <div><span>Portfolio value</span><strong>{money(dashboard.portfolio_value, currency)}</strong></div>
        <div><span>Cost basis</span><strong>{money(dashboard.cost_basis, currency)}</strong></div>
        <div><span>Unrealized P/L</span><strong className={dashboard.unrealized_pnl >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{signedMoney(dashboard.unrealized_pnl, currency)}</strong></div>
        <div><span>Realized P/L</span><strong className={dashboard.realized_pnl >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{signedMoney(dashboard.realized_pnl, currency)}</strong></div>
      </div>

      <nav className="private-life-investment-tabs" aria-label="Investment sections">
        <button type="button" className={activeTab === 'stocks' ? 'active' : ''} onClick={() => setActiveTab('stocks')}>Stocks</button>
        <button type="button" className={activeTab === 'crypto' ? 'active' : ''} onClick={() => setActiveTab('crypto')}>Crypto</button>
        <button type="button" className={activeTab === 'portfolio' ? 'active' : ''} onClick={() => setActiveTab('portfolio')}>Portfolio ({dashboard.positions.length})</button>
        <button type="button" className={activeTab === 'history' ? 'active' : ''} onClick={() => setActiveTab('history')}>History</button>
      </nav>

      {notice ? <div className="private-life-investment-message success">{notice}</div> : null}
      {error ? <div className="private-life-investment-message error">{error}</div> : null}

      {activeTab === 'stocks' || activeTab === 'crypto' ? (
        <div className="private-life-investment-market-layout">
          <div className="private-life-investment-table-panel">
            <div className="private-life-investment-table-head">
              <div>
                <strong>{activeTab === 'stocks' ? 'Stock market' : 'Crypto market'}</strong>
                <span>{activeTab === 'stocks' ? 'Delayed/reference equity quotes may apply.' : '24/7 crypto reference prices.'}</span>
              </div>
              <span>{visibleMarket.filter((item) => item.price !== null).length}/{visibleMarket.length} priced</span>
            </div>
            <div className="private-life-investment-table-wrap">
              <table className="private-life-investment-table">
                <thead>
                  <tr><th>Asset</th><th>Price</th><th>Move</th><th>Owned</th><th>Value</th><th>Status</th></tr>
                </thead>
                <tbody>
                  {visibleMarket.map((instrument) => {
                    const move = pctChange(instrument.price, instrument.previous_price)
                    return (
                      <tr key={instrument.code} className={selectedCode === instrument.code ? 'selected' : ''} onClick={() => setSelectedCode(instrument.code)}>
                        <td><strong>{instrument.symbol}</strong><span>{instrument.name}{instrument.exchange ? ` · ${instrument.exchange}` : ''}</span></td>
                        <td><strong>{marketPrice(instrument.price, currency)}</strong><span>{quoteSource(instrument.quote_source)}</span></td>
                        <td>{move === null ? <span>—</span> : <strong className={move >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{move >= 0 ? '+' : ''}{move.toFixed(2)}%</strong>}</td>
                        <td>{quantity(Number(instrument.owned_quantity || 0), instrument.asset_type)}</td>
                        <td>{money(Number(instrument.market_value || 0), currency)}</td>
                        <td><span className={`private-life-quote-status ${instrument.tradeable ? instrument.quote_stale ? 'stale' : 'ready' : 'unavailable'}`}>{instrument.tradeable ? instrument.quote_stale ? 'Delayed' : 'Ready' : 'Unavailable'}</span></td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </div>

          <aside className="private-life-trade-ticket">
            {selectedInstrument ? (
              <>
                <div className="private-life-trade-ticket-heading">
                  <div><span>{selectedInstrument.asset_type === 'stock' ? 'Stock' : 'Cryptocurrency'}</span><h4>{selectedInstrument.symbol} · {selectedInstrument.name}</h4></div>
                  <strong>{marketPrice(selectedInstrument.price, currency)}</strong>
                </div>
                <div className="private-life-trade-quote-meta">
                  <span>{quoteSource(selectedInstrument.quote_source)}</span>
                  <span>{quoteTime(selectedInstrument.quote_as_of)}</span>
                </div>

                <div className="private-life-trade-side-tabs">
                  <button type="button" className={tradeSide === 'buy' ? 'active' : ''} onClick={() => setTradeSide('buy')}>Buy</button>
                  <button type="button" className={tradeSide === 'sell' ? 'active' : ''} disabled={Number(selectedInstrument.owned_quantity || 0) <= 0} onClick={() => setTradeSide('sell')}>Sell</button>
                </div>

                {tradeSide === 'buy' ? (
                  <div className="private-life-trade-form">
                    <label>Amount from Finance</label>
                    <div className="private-life-trade-input"><span>$</span><input type="number" min="10" step="10" value={buyAmount} onChange={(event) => setBuyAmount(event.target.value)} /></div>
                    <div className="private-life-trade-helper"><span>Cash available</span><strong>{money(dashboard.cash_balance, currency)}</strong></div>
                    <div className="private-life-trade-helper"><span>Estimated quantity</span><strong>{quantity(estimatedBuyQuantity, selectedInstrument.asset_type)} {selectedInstrument.symbol}</strong></div>
                    <button type="button" className="private-life-action" disabled={!selectedInstrument.tradeable || parsedBuyAmount < 10 || parsedBuyAmount > dashboard.cash_balance} onClick={beginBuy}>Buy {selectedInstrument.symbol}</button>
                  </div>
                ) : (
                  <div className="private-life-trade-form">
                    <label>Quantity to sell</label>
                    <div className="private-life-trade-input"><input type="number" min="0" step="any" value={sellQuantity} onChange={(event) => setSellQuantity(event.target.value)} /></div>
                    <div className="private-life-trade-helper"><span>You own</span><strong>{quantity(Number(selectedInstrument.owned_quantity || 0), selectedInstrument.asset_type)} {selectedInstrument.symbol}</strong></div>
                    <div className="private-life-trade-quick-actions">
                      <button type="button" onClick={() => setSellQuantity(String(Number(selectedInstrument.owned_quantity || 0) * 0.25))}>25%</button>
                      <button type="button" onClick={() => setSellQuantity(String(Number(selectedInstrument.owned_quantity || 0) * 0.5))}>50%</button>
                      <button type="button" onClick={() => setSellQuantity(String(Number(selectedInstrument.owned_quantity || 0)))}>All</button>
                    </div>
                    <div className="private-life-trade-helper"><span>Estimated proceeds</span><strong>{money(estimatedSaleValue, currency)}</strong></div>
                    <button type="button" className="private-life-action secondary" disabled={!selectedInstrument.tradeable || !selectedPosition || parsedSellQuantity <= 0 || parsedSellQuantity > Number(selectedPosition.quantity)} onClick={beginSell}>Sell {selectedInstrument.symbol}</button>
                  </div>
                )}
              </>
            ) : <div className="private-life-empty"><strong>Select an investment</strong><p>Choose a market row to open the trade ticket.</p></div>}
          </aside>
        </div>
      ) : null}

      {activeTab === 'portfolio' ? (
        <div className="private-life-investment-table-panel">
          <div className="private-life-investment-table-head"><div><strong>Your simulated portfolio</strong><span>Current market value versus your total cost basis.</span></div></div>
          {dashboard.positions.length === 0 ? (
            <div className="private-life-empty"><strong>No investments yet</strong><p>Use the Stocks or Crypto tab to make your first game-only investment.</p></div>
          ) : (
            <div className="private-life-investment-table-wrap">
              <table className="private-life-investment-table portfolio">
                <thead><tr><th>Asset</th><th>Quantity</th><th>Avg. buy</th><th>Cost basis</th><th>Market value</th><th>Unrealized P/L</th></tr></thead>
                <tbody>{dashboard.positions.map((position) => (
                  <tr key={position.instrument_code}>
                    <td><strong>{position.symbol}</strong><span>{position.name}</span></td>
                    <td>{quantity(Number(position.quantity), position.asset_type)}</td>
                    <td>{marketPrice(Number(position.average_buy_price), currency)}</td>
                    <td>{money(position.cost_basis, currency)}</td>
                    <td>{money(position.market_value, currency)}</td>
                    <td><strong className={position.unrealized_pnl >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{signedMoney(position.unrealized_pnl, currency)}</strong></td>
                  </tr>
                ))}</tbody>
              </table>
            </div>
          )}
        </div>
      ) : null}

      {activeTab === 'history' ? (
        <div className="private-life-investment-table-panel">
          <div className="private-life-investment-table-head"><div><strong>Investment history</strong><span>Every trade also posts the matching cash movement to career Finance.</span></div></div>
          {dashboard.trades.length === 0 ? (
            <div className="private-life-empty"><strong>No investment trades yet</strong><p>Your completed buys and sells will appear here.</p></div>
          ) : (
            <div className="private-life-investment-table-wrap">
              <table className="private-life-investment-table history">
                <thead><tr><th>Trade</th><th>Asset</th><th>Quantity</th><th>Unit price</th><th>Cash value</th><th>Realized P/L</th></tr></thead>
                <tbody>{dashboard.trades.map((trade) => (
                  <tr key={trade.id}>
                    <td><span className={`private-life-trade-side ${trade.side}`}>{trade.side}</span><small>Game day {trade.game_absolute_day}</small></td>
                    <td><strong>{trade.symbol}</strong><span>{trade.name}</span></td>
                    <td>{quantity(Number(trade.quantity), trade.asset_type)}</td>
                    <td>{marketPrice(Number(trade.unit_price), currency)}</td>
                    <td>{money(trade.gross_amount, currency)}</td>
                    <td>{trade.side === 'sell' ? <strong className={trade.realized_pnl >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{signedMoney(trade.realized_pnl, currency)}</strong> : <span>—</span>}</td>
                  </tr>
                ))}</tbody>
              </table>
            </div>
          )}
        </div>
      ) : null}

      <div className="private-life-investment-disclaimer">Market data is used only as a reference for this game simulation. Stock quotes can be delayed; crypto quotes are external reference prices. Tennis Legacy never buys real securities or cryptocurrency on your behalf.</div>

      <GameConfirmDialog
        open={Boolean(pendingConfirmation)}
        eyebrow="Simulated investment trade"
        title={pendingConfirmation?.title ?? ''}
        message={pendingConfirmation?.message ?? ''}
        detail={pendingConfirmation?.detail}
        confirmLabel={pendingConfirmation?.confirmLabel}
        cancelLabel="Cancel"
        busy={tradeBusy}
        tone="warning"
        onConfirm={confirmTrade}
        onCancel={() => { if (!tradeBusy) setPendingTrade(null) }}
      />
    </section>
  )
}
