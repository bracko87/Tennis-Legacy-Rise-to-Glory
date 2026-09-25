let regionNames: Intl.DisplayNames | null = null

try {
  regionNames = new Intl.DisplayNames(['en'], { type: 'region' })
} catch {
  regionNames = null
}

export function nationalCountryName(countryCode?: string | null, fallbackName = '') {
  const code = String(countryCode ?? '').trim().toUpperCase()

  if (code) {
    const displayName = regionNames?.of(code)
    if (displayName && displayName !== code) return displayName
  }

  const fallback = String(fallbackName ?? '').trim()
  if (!fallback) return code || 'Unknown'

  return fallback
    .replace(/\s+Tennis Association$/i, '')
    .replace(/\s+National Tennis Association$/i, '')
    .replace(/\s+National Association$/i, '')
    .replace(/\s+Association$/i, '')
    .trim() || fallback
}
