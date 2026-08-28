/**
 * FormField.tsx
 *
 * Shared accessible form-field wrapper for Tennis Legacy.
 */

import type { ReactNode } from 'react'
import {
  CircleAlert,
  CircleCheck,
} from 'lucide-react'

export interface FormFieldProps {
  /** ID of the primary form control. */
  readonly id: string

  /** Field label. */
  readonly label: string

  /** Optional supporting information. */
  readonly hint?: string

  /** Optional validation error. */
  readonly error?: string

  /** Optional valid-state message. */
  readonly success?: string

  /** Marks the field as required. */
  readonly required?: boolean

  /** Optional content displayed beside the label. */
  readonly labelAction?: ReactNode

  /** Additional root class name. */
  readonly className?: string

  /** Input, select or grouped controls. */
  readonly children: ReactNode
}

export default function FormField({
  id,
  label,
  hint,
  error,
  success,
  required = false,
  labelAction,
  className,
  children,
}: FormFieldProps) {
  const rootClasses = [
    'tlg-field-root',
    error ? 'tlg-field-root-error' : '',
    success ? 'tlg-field-root-success' : '',
    className,
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <div className={rootClasses}>
      <div className="tlg-field-label-row">
        <label
          htmlFor={id}
          className="tlg-field-label"
        >
          {label}

          {required && (
            <>
              <span
                className="tlg-field-required"
                aria-hidden="true"
              >
                *
              </span>

              <span className="tlg-visually-hidden">
                Required
              </span>
            </>
          )}
        </label>

        {labelAction && (
          <div className="tlg-field-label-action">
            {labelAction}
          </div>
        )}
      </div>

      {children}

      {error ? (
        <p
          id={`${id}-error`}
          className="tlg-field-message tlg-field-error"
          role="alert"
        >
          <CircleAlert
            size={14}
            aria-hidden="true"
          />
          {error}
        </p>
      ) : success ? (
        <p
          id={`${id}-success`}
          className="tlg-field-message tlg-field-success"
        >
          <CircleCheck
            size={14}
            aria-hidden="true"
          />
          {success}
        </p>
      ) : hint ? (
        <p
          id={`${id}-hint`}
          className="tlg-field-hint"
        >
          {hint}
        </p>
      ) : null}
    </div>
  )
}