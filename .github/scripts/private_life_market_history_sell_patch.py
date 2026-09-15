from pathlib import Path
import re

# ---------- PrivateLife transaction history ----------
pl = Path('src/pages/dashboard/PrivateLife.tsx')
s = pl.read_text()

s = s.replace("const SALE_META: Record<SaleMode, { label: string; detail: string }> = {", "const ASSET_HISTORY_PAGE_SIZE = 10\n\nconst SALE_META: Record<SaleMode, { label: string; detail: string }> = {", 1)
s = s.replace("  const [assetHistoryLoading, setAssetHistoryLoading] = useState(false)\n", "  const [assetHistoryLoading, setAssetHistoryLoading] = useState(false)\n  const [assetHistoryPage, setAssetHistoryPage] = useState(1)\n", 1)
s = s.replace("    setShowAssetHistory(true)\n", "    setShowAssetHistory(true)\n    setAssetHistoryPage(1)\n", 1)
old_map = "<tbody>{assetHistory.map((row) => {"
assert old_map in s, 'asset history map not found'
s = s.replace(old_map, "<tbody>{assetHistory.slice((assetHistoryPage - 1) * ASSET_HISTORY_PAGE_SIZE, assetHistoryPage * ASSET_HISTORY_PAGE_SIZE).map((row) => {", 1)
old_end = """                      })}</tbody>\n                    </table>\n                  </div>\n                )}"""
new_end = """                      })}</tbody>\n                    </table>\n                  </div>\n                )}\n                {assetHistory.length > ASSET_HISTORY_PAGE_SIZE ? (\n                  <div className=\"private-life-asset-history-pagination\">\n                    <button type=\"button\" disabled={assetHistoryPage <= 1} onClick={() => setAssetHistoryPage((page) => Math.max(1, page - 1))}>Previous</button>\n                    <span>Page <strong>{assetHistoryPage}</strong> of {Math.ceil(assetHistory.length / ASSET_HISTORY_PAGE_SIZE)} · 10 transactions per page</span>\n                    <button type=\"button\" disabled={assetHistoryPage >= Math.ceil(assetHistory.length / ASSET_HISTORY_PAGE_SIZE)} onClick={() => setAssetHistoryPage((page) => Math.min(Math.ceil(assetHistory.length / ASSET_HISTORY_PAGE_SIZE), page + 1))}>Next</button>\n                  </div>\n                ) : null}"""
assert old_end in s, 'asset history table end not found'
s = s.replace(old_end, new_end, 1)
pl.write_text(s)

# ---------- Transaction history CSS ----------
css = Path('src/styles/private-life-history.css')
c = css.read_text()
c = re.sub(r"\.private-life-asset-history-type \{[\s\S]*?\}\n\n\.private-life-asset-history-type\.purchase[^\n]*\n\.private-life-asset-history-type\.sale[^\n]*\n\.private-life-asset-history-type\.running_cost[^\n]*\n\.private-life-asset-history-type\.starter_home[^\n]*\n", ".private-life-asset-history-type {\n  display: inline !important;\n  margin: 0 !important;\n  padding: 0;\n  border: 0;\n  border-radius: 0;\n  background: transparent !important;\n  color: #31465d !important;\n  font-size: 11px !important;\n  font-weight: 750;\n  text-transform: none;\n  letter-spacing: 0;\n}\n\n", c, count=1)
c += """\n.private-life-asset-history-pagination {\n  display: grid;\n  grid-template-columns: auto 1fr auto;\n  align-items: center;\n  gap: 12px;\n  padding: 12px 14px;\n  border-top: 1px solid #e4ebf2;\n  background: #fbfcfe;\n}\n.private-life-asset-history-pagination button {\n  min-height: 30px;\n  padding: 6px 11px;\n  border: 1px solid #d4dee9;\n  border-radius: 8px;\n  background: #fff;\n  color: #435269;\n  cursor: pointer;\n  font: inherit;\n  font-size: 10px;\n  font-weight: 750;\n}\n.private-life-asset-history-pagination button:disabled { opacity: .4; cursor: default; }\n.private-life-asset-history-pagination span { text-align: center; color: #7d899b; font-size: 10px; }\n.private-life-asset-history-pagination span strong { color: #324258; }\n"""
css.write_text(c)

# ---------- Investments ----------
ip = Path('src/components/private-life/PrivateLifeInvestments.tsx')
s = ip.read_text()
s = s.replace("const STOCK_PAGE_SIZE = 10\n", "const STOCK_PAGE_SIZE = 10\nconst INVESTMENT_HISTORY_PAGE_SIZE = 10\n", 1)

marker = "type InvestmentTrade = {"
insert = """type DailyHistoryPoint = {\n  game_day_index: number\n  game_total_seconds: number\n  open: number\n  close: number\n  low: number\n  high: number\n  snapshots: number\n}\n\n"""
assert marker in s
s = s.replace(marker, insert + marker, 1)

# Add daily chart component before MarketTrendPanel
marker = "function MarketTrendPanel({ instrument, currency }: { instrument: InvestmentInstrument; currency: string }) {"
daily_component = r'''function DailyMarketChart({ history, currency }: { history: DailyHistoryPoint[]; currency: string }) {
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

'''
assert marker in s, 'MarketTrendPanel marker missing'
s = s.replace(marker, daily_component + "function MarketTrendPanel({ instrument, currency, dailyHistory, dailyLoading }: { instrument: InvestmentInstrument; currency: string; dailyHistory: DailyHistoryPoint[]; dailyLoading: boolean }) {", 1)

# Replace chart label and sparkline area
old = """      <div className=\"private-life-market-chart-label\">{chartLabel}</div>\n      <Sparkline history={chartHistory} currency={currency} />"""
new = """      <div className=\"private-life-market-chart-label\">Daily game-date trend</div>\n      {dailyLoading ? <div className=\"private-life-market-chart-empty\">Loading daily market history…</div> : dailyHistory.length >= 2 ? <DailyMarketChart history={dailyHistory} currency={currency} /> : <Sparkline history={chartHistory} currency={currency} />}"""
assert old in s, 'market chart block missing'
s = s.replace(old, new, 1)

# Add states
needle = "  const [pendingTrade, setPendingTrade] = useState<PendingTrade | null>(null)\n"
add = needle + "  const [dailyHistory, setDailyHistory] = useState<DailyHistoryPoint[]>([])\n  const [dailyHistoryLoading, setDailyHistoryLoading] = useState(false)\n  const [tradeHistory, setTradeHistory] = useState<InvestmentTrade[]>([])\n  const [tradeHistoryLoaded, setTradeHistoryLoaded] = useState(false)\n  const [historyPage, setHistoryPage] = useState(1)\n"
assert needle in s
s = s.replace(needle, add, 1)

# Add effects before stockInstruments
marker = "  const stockInstruments = useMemo(() => dashboard?.instruments.filter((item) => item.asset_type === 'stock') ?? [], [dashboard])"
effects = r'''  useEffect(() => {
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

'''
assert marker in s
s = s.replace(marker, effects + marker, 1)

# Refresh trade history after trade
old = """      setPendingTrade(null)\n      await loadDashboard()\n      await onPortfolioChanged?.()"""
new = """      setPendingTrade(null)\n      setTradeHistoryLoaded(false)\n      await loadDashboard()\n      await onPortfolioChanged?.()"""
assert old in s
s = s.replace(old, new, 1)

# Add direct portfolio sell function before confirmTrade
marker = "  async function confirmTrade() {"
func = r'''  function beginPortfolioSell(position: InvestmentPosition) {
    const instrument = dashboard?.instruments.find((item) => item.code === position.instrument_code)
    if (!instrument || !instrument.tradeable || !instrument.price) {
      setError('A current market reference quote is required before selling this holding.')
      return
    }
    setError(null)
    setPendingTrade({ side: 'sell', instrument, quantity: Number(position.quantity) })
  }

'''
assert marker in s
s = s.replace(marker, func + marker, 1)

# MarketTrendPanel invocation
old = "{selectedInstrument ? <MarketTrendPanel instrument={selectedInstrument} currency={currency} /> : null}"
new = "{selectedInstrument ? <MarketTrendPanel instrument={selectedInstrument} currency={currency} dailyHistory={dailyHistory} dailyLoading={dailyHistoryLoading} /> : null}"
assert old in s
s = s.replace(old, new, 1)

# Portfolio table action column
old = "<thead><tr><th>Asset</th><th>Quantity</th><th>Avg. buy</th><th>Current price</th><th>Daily move</th><th>Market value</th><th>Since buy</th></tr></thead>"
new = "<thead><tr><th>Asset</th><th>Quantity</th><th>Avg. buy</th><th>Current price</th><th>Daily move</th><th>Market value</th><th>Since buy</th><th>Action</th></tr></thead>"
assert old in s
s = s.replace(old, new, 1)
old = """                      <td><strong className={precisePnl >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{signedMoney(precisePnl, currency, 2)}</strong><span className={returnPct >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{percentText(returnPct)}</span></td>\n                    </tr>"""
new = """                      <td><strong className={precisePnl >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{signedMoney(precisePnl, currency, 2)}</strong><span className={returnPct >= 0 ? 'private-life-trend-positive' : 'private-life-trend-negative'}>{percentText(returnPct)}</span></td>\n                      <td><button type=\"button\" className=\"private-life-portfolio-sell\" onClick={(event) => { event.stopPropagation(); beginPortfolioSell(position) }}>Sell</button></td>\n                    </tr>"""
assert old in s
s = s.replace(old, new, 1)

# Replace history tab block with forever paginated history
pattern = r"\{activeTab === 'history' \? \([\s\S]*?\n      \) : null\}\n\n      <div className=\"private-life-investment-disclaimer\">"
replacement = r'''{activeTab === 'history' ? (
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

      <div className="private-life-investment-disclaimer">'''
s, count = re.subn(pattern, replacement, s, count=1)
assert count == 1, 'history block not replaced'

# add gameDayFromAbsolute helper after gameTimeFromSeconds
marker = "function gameTimeLabel(metadata?: QuoteMetadata | null, mode: 'change' | 'checked' = 'change') {"
helper = r'''function gameDayFromAbsolute(value: number) {
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

'''
assert marker in s
s = s.replace(marker, helper + marker, 1)

ip.write_text(s)

# ---------- Investments CSS ----------
css = Path('src/styles/private-life-investments.css')
c = css.read_text()
c += r'''
.private-life-daily-market-chart{display:block;width:100%;height:128px;margin:5px 0 7px;border-radius:10px;background:linear-gradient(180deg,#fbfcfe,#f6f8fb)}
.private-life-daily-market-chart .grid-line{stroke:#e2e8f0;stroke-width:.7;vector-effect:non-scaling-stroke}
.private-life-daily-market-chart .grid-line.vertical{stroke-dasharray:2 3}
.private-life-daily-market-chart polyline{stroke-width:2;vector-effect:non-scaling-stroke}
.private-life-daily-market-chart.positive polyline{stroke:#168154}.private-life-daily-market-chart.negative polyline{stroke:#b7443a}
.private-life-daily-market-chart text{fill:#8a95a5;font-size:7px;font-weight:700}
.private-life-portfolio-sell{min-width:64px;padding:7px 10px;border:1px solid #e8c6c1;border-radius:8px;background:#fff8f7;color:#a33f38;cursor:pointer;font:inherit;font-size:10px;font-weight:800}
.private-life-portfolio-sell:hover{background:#fff0ee}
'''
css.write_text(c)
