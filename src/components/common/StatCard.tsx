/**
 * StatCard.tsx
 *
 * Reusable statistics panel.
 */

import type { ReactNode } from 'react'

export interface StatCardProps {
  readonly label: string
  readonly value: string
  readonly helper?: string
  readonly icon?: ReactNode
  readonly className?: string
  readonly status?: string
}

export default function StatCard({
  label,
  value,
  helper,
  icon,
  className,
  status,
}: StatCardProps) {
  const classes = [
    'tlg-stat-card',
    className,
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <article className={classes}>
      <div className="tlg-stat-card-top">
        {icon && (
          <div className="tlg-stat-card-icon">
            {icon}
          </div>
        )}

        {status && (
          <span className="tlg-stat-card-status">
            <span
              className="tlg-status-dot"
              aria-hidden="true"
            />
            {status}
          </span>
        )}
      </div>

      <div className="tlg-stat-card-content">
        <span className="tlg-stat-card-label">
          {label}
        </span>

        <strong className="tlg-stat-card-value">
          {value}
        </strong>

        {helper && (
          <span className="tlg-stat-card-helper">
            {helper}
          </span>
        )}
      </div>
    </article>
  )
}