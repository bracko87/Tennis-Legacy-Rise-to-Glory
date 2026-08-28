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
 * Uses the flag-icons SVG set so every flag is rendered as a clean, flat,
 * rectangular national flag rather than an operating-system emoji/waving flag.
 * All country displays in Tennis Legacy should use this component.
 */
export default function CountryFlag({
  countryCode,
  countryName,
  width = 22,
  height = 15,
  className = '',
}: CountryFlagProps) {
  if (!countryCode || countryCode.length !== 2) return null

  const code = countryCode.toLowerCase()
  const label = countryName ? `${countryName} flag` : `${countryCode.toUpperCase()} flag`

  const style: CSSProperties = {
    width,
    height,
    flex: `0 0 ${width}px`,
    display: 'inline-block',
    lineHeight: 1,
    borderRadius: 2,
    boxShadow: '0 0 0 1px rgba(20, 39, 58, 0.12)',
    backgroundSize: 'cover',
    backgroundPosition: 'center',
    backgroundRepeat: 'no-repeat',
    verticalAlign: 'middle',
  }

  return (
    <span
      className={`fi fi-${code} ${className}`.trim()}
      style={style}
      role="img"
      aria-label={label}
      title={countryName ?? countryCode.toUpperCase()}
    />
  )
}
