/**
 * AppButton.tsx
 *
 * Shared button component for Tennis Legacy: Rise to Glory.
 */

import type {
  ButtonHTMLAttributes,
  ReactNode,
} from 'react'

export type AppButtonVariant =
  | 'primary'
  | 'secondary'
  | 'ghost'

export type AppButtonSize =
  | 'small'
  | 'medium'
  | 'large'

export interface AppButtonProps
  extends ButtonHTMLAttributes<HTMLButtonElement> {
  readonly variant?: AppButtonVariant
  readonly size?: AppButtonSize
  readonly fullWidth?: boolean
  readonly leftIcon?: ReactNode
  readonly rightIcon?: ReactNode
  readonly loading?: boolean
}

export default function AppButton({
  variant = 'primary',
  size = 'medium',
  fullWidth = false,
  leftIcon,
  rightIcon,
  loading = false,
  className,
  children,
  disabled,
  type = 'button',
  ...rest
}: AppButtonProps) {
  const classes = [
    'tlg-btn',
    `tlg-btn-${variant}`,
    `tlg-btn-${size}`,
    fullWidth ? 'tlg-btn-full' : '',
    loading ? 'tlg-btn-loading' : '',
    className,
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <button
      type={type}
      className={classes}
      disabled={disabled || loading}
      aria-busy={loading}
      {...rest}
    >
      {loading ? (
        <span
          className="tlg-btn-spinner"
          aria-hidden="true"
        />
      ) : (
        leftIcon && (
          <span className="tlg-btn-icon">
            {leftIcon}
          </span>
        )
      )}

      <span>{children}</span>

      {!loading && rightIcon && (
        <span className="tlg-btn-icon">
          {rightIcon}
        </span>
      )}
    </button>
  )
}