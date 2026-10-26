import { AlertTriangle, CheckCircle2, X } from 'lucide-react'
import { createPortal } from 'react-dom'
import { useEffect, useRef, type ReactNode } from 'react'

import { lockBodyScroll } from '../../lib/bodyScrollLock'
import '../../styles/game-confirm-dialog.css'

export interface GameConfirmDialogProps {
  open: boolean
  eyebrow?: string
  title: string
  message: ReactNode
  detail?: ReactNode
  hero?: ReactNode
  size?: 'default' | 'wide'
  confirmLabel?: string
  cancelLabel?: string
  busy?: boolean
  tone?: 'danger' | 'warning' | 'success' | 'neutral'
  showConfirm?: boolean
  onConfirm: () => void | Promise<void>
  onCancel: () => void
}

export default function GameConfirmDialog({
  open,
  eyebrow = 'Please confirm',
  title,
  message,
  detail,
  hero,
  size = 'default',
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  busy = false,
  tone = 'danger',
  showConfirm = true,
  onConfirm,
  onCancel,
}: GameConfirmDialogProps) {
  const cancelButtonRef = useRef<HTMLButtonElement | null>(null)

  useEffect(() => {
    if (!open) return
    const unlockBodyScroll = lockBodyScroll()
    const frame = window.requestAnimationFrame(() => cancelButtonRef.current?.focus())

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !busy) onCancel()
    }
    window.addEventListener('keydown', onKeyDown)

    return () => {
      window.cancelAnimationFrame(frame)
      window.removeEventListener('keydown', onKeyDown)
      unlockBodyScroll()
    }
  }, [open, busy, onCancel])

  if (!open || typeof document === 'undefined') return null

  const Icon = tone === 'success' || tone === 'neutral' ? CheckCircle2 : AlertTriangle

  return createPortal(
    <div
      className="tlg-game-confirm-backdrop"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !busy) onCancel()
      }}
    >
      <section
        className={`tlg-game-confirm-dialog ${tone} ${size === 'wide' ? 'wide' : ''}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby="tlg-game-confirm-title"
      >
        <button
          type="button"
          className="tlg-game-confirm-close"
          aria-label="Close confirmation"
          disabled={busy}
          onClick={onCancel}
        >
          <X size={16} />
        </button>

        <div className="tlg-game-confirm-head">
          <div className="tlg-game-confirm-icon" aria-hidden="true">
            <Icon size={20} />
          </div>
          <div>
            <span>{eyebrow}</span>
            <h2 id="tlg-game-confirm-title">{title}</h2>
          </div>
        </div>

        <div className="tlg-game-confirm-scroll-area" tabIndex={0} aria-label="Dialog content">
          {hero ? <div className="tlg-game-confirm-hero">{hero}</div> : null}
          <div className="tlg-game-confirm-body">
            <div className="tlg-game-confirm-message">{message}</div>
            {detail ? <div className="tlg-game-confirm-detail">{detail}</div> : null}
          </div>
        </div>

        <footer className="tlg-game-confirm-actions">
          <button
            ref={cancelButtonRef}
            type="button"
            className="secondary"
            disabled={busy}
            onClick={onCancel}
          >
            {cancelLabel}
          </button>
          {showConfirm ? (
            <button
              type="button"
              className={tone === 'danger' ? 'danger' : 'primary'}
              disabled={busy}
              onClick={() => void onConfirm()}
            >
              {busy ? 'Processing…' : confirmLabel}
            </button>
          ) : null}
        </footer>
      </section>
    </div>,
    document.body,
  )
}
