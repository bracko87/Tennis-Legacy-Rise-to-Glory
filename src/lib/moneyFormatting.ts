/** Display in-game career finances in whole currency units only.
 * Financial values remain unrounded in storage and calculations. */
export function formatGameCurrency(
  value: number,
  localeTag: string,
  currency = 'USD',
): string {
  const amount = Number.isFinite(value) ? value : 0
  const rounded = Math.round(amount)
  return new Intl.NumberFormat(localeTag, {
    style: 'currency',
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(rounded === 0 ? 0 : rounded)
}

/** Real-money checkout amounts need exact cents (e.g. €3.29), not rounding. */
export function formatPurchasePrice(
  value: number,
  localeTag: string,
  currency = 'EUR',
): string {
  return new Intl.NumberFormat(localeTag, {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value)
}

/** Fractional market-unit prices must retain meaningful digits but not .00. */
export function formatMarketQuote(
  value: number,
  localeTag: string,
  currency = 'USD',
  decimalPlaces = 2,
): string {
  return new Intl.NumberFormat(localeTag, {
    style: 'currency',
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: decimalPlaces,
  }).format(value)
}
