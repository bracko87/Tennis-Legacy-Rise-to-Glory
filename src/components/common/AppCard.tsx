/**
 * AppCard.tsx
 *
 * Shared premium panel component.
 */

import type { ReactNode } from 'react'

export type AppCardVariant =
  | 'default'
  | 'muted'
  | 'light'
  | 'outline'

export interface AppCardProps {
  readonly eyebrow?: string
  readonly title?: string
  readonly description?: string
  readonly actions?: ReactNode
  readonly className?: string
  readonly bodyClassName?: string
  readonly variant?: AppCardVariant
  readonly children: ReactNode
}

export default function AppCard({
  eyebrow,
  title,
  description,
  actions,
  className,
  bodyClassName,
  variant = 'default',
  children,
}: AppCardProps) {
  const classes = [
    'tlg-card',
    `tlg-card-${variant}`,
    className,
  ]
    .filter(Boolean)
    .join(' ')

  const bodyClasses = [
    'tlg-card-body',
    bodyClassName,
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <section className={classes}>
      {(eyebrow ||
        title ||
        description ||
        actions) && (
        <header className="tlg-card-header">
          <div className="tlg-card-heading">
            {eyebrow && (
              <p className="tlg-card-eyebrow">
                {eyebrow}
              </p>
            )}

            {title && (
              <h2 className="tlg-card-title">
                {title}
              </h2>
            )}

            {description && (
              <p className="tlg-card-description">
                {description}
              </p>
            )}
          </div>

          {actions && (
            <div className="tlg-card-actions">
              {actions}
            </div>
          )}
        </header>
      )}

      <div className={bodyClasses}>
        {children}
      </div>
    </section>
  )
}