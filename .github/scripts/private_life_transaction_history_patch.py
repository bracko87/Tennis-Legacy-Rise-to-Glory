from pathlib import Path
import re

path = Path('src/pages/dashboard/PrivateLife.tsx')
s = path.read_text()

s, count = re.subn(
    r"type AssetHistoryRow = \{[\s\S]*?\n\}\n\ntype PrivateLifeDashboard",
    """type AssetHistoryRow = {
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

type PrivateLifeDashboard""",
    s,
    count=1,
)
assert count == 1, 'AssetHistoryRow type block not found'

s = s.replace("supabase.rpc('get_private_life_asset_history_v1')", "supabase.rpc('get_private_life_asset_transaction_history_v1')")

s = s.replace(
    "<button type=\"button\" className=\"private-life-refresh\" onClick={() => void toggleAssetHistory()}>{showAssetHistory ? 'Hide history' : 'Asset history'}</button>",
    "<button type=\"button\" className=\"private-life-refresh\" onClick={() => void toggleAssetHistory()}>Transaction history</button>",
)

helper = """
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

"""
marker = "function matchesPriceBand(price: number, band: MarketplacePrice) {"
assert marker in s, 'matchesPriceBand marker not found'
s = s.replace(marker, helper + marker, 1)

popup = """
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
                      <tbody>{assetHistory.map((row) => {
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
              </div>
            ) : null}
"""

pattern = r"\n            \{showAssetHistory \? \([\s\S]*?\n            \) : null\}\n            \{visibleOwned.length"
replacement = "\n" + popup + "            {visibleOwned.length"
s, count = re.subn(pattern, replacement, s, count=1)
assert count == 1, 'Inline asset history block not found'

path.write_text(s)
