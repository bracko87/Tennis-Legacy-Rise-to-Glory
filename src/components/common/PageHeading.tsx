/**
 * PageHeading.tsx
 *
 * Shared heading component for marketing and game pages.
 */

import type { ReactNode } from 'react'

export type PageHeadingSize =
  | 'default'
  | 'large'
  | 'hero'

export interface PageHeadingProps {
  readonly eyebrow?: string
  readonly title: string
  readonly description?: string
  readonly actions?: ReactNode
  readonly className?: string
  readonly size?: PageHeadingSize
  readonly centered?: boolean
}

export default function PageHeading({
  eyebrow,
  title,
  description,
  actions,
  className,
  size = 'default',
  centered = false,
}: PageHeadingProps) {
  const classes = [
    'tlg-page-heading',
    `tlg-page-heading-${size}`,
    centered
      ? 'tlg-page-heading-centered'
      : '',
    className,
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <header className={classes}>
      <div className="tlg-page-heading-copy">
        {eyebrow && (
          <p className="tlg-page-heading-eyebrow">
            {eyebrow}
          </p>
        )}

        <h1 className="tlg-page-heading-title">
          {title}
        </h1>

        {description && (
          <p className="tlg-page-heading-description">
            {description}
          </p>
        )}
      </div>

      {actions && (
        <div className="tlg-page-heading-actions">
          {actions}
        </div>
      )}
    </header>
  )
}