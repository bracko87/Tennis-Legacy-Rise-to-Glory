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
 * Uses high-resolution FlagCDN raster assets with contain-fit rendering so
 * national flags stay sharp and keep their proper aspect ratio instead of being
 * cropped or stretched inside small UI slots.
 */
export default function CountryFlag({
  countryCode,
  countryName,
  width = 24,
  height = 16,
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
    objectFit: 'contain',
    objectPosition: 'center',
    borderRadius: 2,
    boxShadow: '0 0 0 1px rgba(20, 39, 58, 0.16)',
    backgroundColor: '#fff',
    verticalAlign: 'middle',
    imageRendering: 'auto',
  }

  return (
    <img
      src={`https://flagcdn.com/w160/${code}.png`}
      srcSet={`https://flagcdn.com/w80/${code}.png 1x, https://flagcdn.com/w160/${code}.png 2x, https://flagcdn.com/w320/${code}.png 3x`}
      alt={label}
      className={className}
      style={style}
      loading="lazy"
      decoding="async"
      draggable={false}
      title={countryName ?? countryCode.toUpperCase()}
    />
  )
}
