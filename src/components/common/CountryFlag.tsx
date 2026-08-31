import type { CSSProperties } from 'react'
import { useEffect, useMemo, useState } from 'react'

export interface CountryFlagProps {
  countryCode?: string | null
  countryName?: string
  width?: number
  height?: number
  className?: string
}

function normalizeCountryCode(countryCode?: string | null) {
  if (!countryCode || countryCode.length !== 2) return null

  const code = countryCode.toUpperCase()
  return code === 'UK' ? 'GB' : code
}

export function getFlagImageUrl(countryCode: string) {
  const code = normalizeCountryCode(countryCode)
  return code ? `https://flagcdn.com/w40/${code.toLowerCase()}.png` : ''
}

/**
 * Shared Tennis Legacy country-flag standard.
 *
 * Matches the ProPeloton Manager flag treatment: ISO alpha-2 codes internally,
 * FlagCDN w40 PNG assets, flat 24x16 presentation, cover fit, subtle border,
 * lazy loading, and a neutral fallback if the image cannot be loaded.
 */
export default function CountryFlag({
  countryCode,
  countryName,
  width = 24,
  height = 16,
  className = '',
}: CountryFlagProps) {
  const normalizedCode = useMemo(() => normalizeCountryCode(countryCode), [countryCode])
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    setFailed(false)
  }, [normalizedCode])

  const style: CSSProperties = {
    width,
    height,
    flex: `0 0 ${width}px`,
    display: 'inline-block',
    objectFit: 'cover',
    objectPosition: 'center',
    borderRadius: 2,
    border: '1px solid rgba(203, 213, 225, 0.9)',
    backgroundColor: '#eef2f6',
    verticalAlign: 'middle',
  }

  if (!normalizedCode || failed) {
    return (
      <span
        className={className}
        style={style}
        role="img"
        aria-label={countryName ? `${countryName} flag unavailable` : 'Country flag unavailable'}
        title={countryName ?? normalizedCode ?? 'Country unavailable'}
      />
    )
  }

  return (
    <img
      src={getFlagImageUrl(normalizedCode)}
      alt={countryName ? `${countryName} flag` : normalizedCode}
      className={className}
      style={style}
      loading="lazy"
      decoding="async"
      draggable={false}
      onError={() => setFailed(true)}
      title={countryName ?? normalizedCode}
    />
  )
}
