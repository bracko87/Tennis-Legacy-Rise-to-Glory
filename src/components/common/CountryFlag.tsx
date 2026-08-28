import type { CSSProperties } from 'react'

export interface CountryFlagProps {
  countryCode?: string | null
  countryName?: string
  width?: number
  height?: number
  className?: string
}

/**
 * Shared Tennis Legacy country-flag standard.
 *
 * All country flags should use this component instead of platform emoji so
 * Windows/macOS/browser rendering stays visually consistent throughout the game.
 */
export default function CountryFlag({
  countryCode,
  countryName,
  width = 22,
  height = 16,
  className,
}: CountryFlagProps) {
  if (!countryCode || countryCode.length !== 2) return null

  const code = countryCode.toLowerCase()
  const label = countryName ? `${countryName} flag` : `${countryCode.toUpperCase()} flag`

  const style: CSSProperties = {
    width,
    height,
    flex: `0 0 ${width}px`,
    display: 'inline-block',
    objectFit: 'cover',
    borderRadius: 2,
    boxShadow: '0 0 0 1px rgba(20, 39, 58, 0.10)',
    verticalAlign: 'middle',
  }

  return (
    <img
      src={`https://flagcdn.com/${width}x${height}/${code}.png`}
      srcSet={`https://flagcdn.com/${width * 2}x${height * 2}/${code}.png 2x`}
      alt={label}
      className={className}
      style={style}
      loading="lazy"
      decoding="async"
    />
  )
}
