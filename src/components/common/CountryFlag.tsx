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
 * Renders flat rectangular national flags from FlagCDN so the game does not
 * depend on operating-system emoji/waving flag rendering or an extra CSS package.
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
    objectFit: 'cover',
    objectPosition: 'center',
    borderRadius: 1,
    boxShadow: '0 0 0 1px rgba(20, 39, 58, 0.14)',
    verticalAlign: 'middle',
  }

  return (
    <img
      src={`https://flagcdn.com/${code}.svg`}
      alt={label}
      className={className}
      style={style}
      loading="lazy"
      decoding="async"
      title={countryName ?? countryCode.toUpperCase()}
    />
  )
}
