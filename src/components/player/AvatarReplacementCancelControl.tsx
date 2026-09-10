import { useEffect, useState } from 'react'
import { createPortal } from 'react-dom'
import { AlertTriangle, X, XCircle } from 'lucide-react'

import { useAuth } from '../../auth/AuthContext'
import { supabase } from '../../lib/supabase'
import '../../styles/avatar-replacement-cancel.css'

const PRIVATE_BUCKET = 'avatar-replacement-submissions'
const ACTIVE_STATUSES = new Set(['submitted', 'under_review', 'preparing', 'ready_for_review', 'revision_requested'])

type ActiveRequest = {
  id: string
  status: string
}

export default function AvatarReplacementCancelControl() {
  const { user } = useAuth()
  const [request, setRequest] = useState<ActiveRequest | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [confirmOpen, setConfirmOpen] = useState(false)

  useEffect(() => {
    let cancelled = false

    async function loadActiveRequest() {
      if (!user?.id) {
        if (!cancelled) setRequest(null)
        return
      }

      const { data } = await supabase
        .from('avatar_replacement_requests')
        .select('id, status')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()

      if (!cancelled) {
        const row = data as ActiveRequest | null
        setRequest(row && ACTIVE_STATUSES.has(row.status) ? row : null)
      }
    }

    void loadActiveRequest()
    const timer = window.setInterval(() => void loadActiveRequest(), 30000)
    return () => {
      cancelled = true
      window.clearInterval(timer)
    }
  }, [user?.id])

  useEffect(() => {
    if (!confirmOpen) return

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape' && !busy) setConfirmOpen(false)
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [busy, confirmOpen])

  async function cancelRequest() {
    if (!request || busy) return

    setBusy(true)
    setError(null)

    const { error: cancelError } = await supabase.rpc('cancel_avatar_replacement_request_v1', {
      p_request_id: request.id,
    })

    if (cancelError) {
      setError(cancelError.message)
      setBusy(false)
      setConfirmOpen(false)
      return
    }

    const { data: cleanupPath } = await supabase.rpc('get_avatar_reference_cleanup_path_v1', {
      p_request_id: request.id,
    })

    if (cleanupPath) {
      const { error: removeError } = await supabase.storage.from(PRIVATE_BUCKET).remove([String(cleanupPath)])
      if (!removeError) {
        await supabase.rpc('confirm_avatar_reference_deleted_v1', { p_request_id: request.id })
      }
    }

    window.location.reload()
  }

  if (!request) return null

  const modal = confirmOpen ? createPortal(
    <div
      className="tlg-avatar-confirm-backdrop"
      role="presentation"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !busy) setConfirmOpen(false)
      }}
    >
      <div className="tlg-avatar-confirm-dialog" role="dialog" aria-modal="true" aria-labelledby="tlg-avatar-cancel-title">
        <header className="tlg-avatar-confirm-head">
          <span className="tlg-avatar-confirm-icon"><AlertTriangle size={19} /></span>
          <div>
            <span>Avatar request</span>
            <h3 id="tlg-avatar-cancel-title">Cancel this request?</h3>
          </div>
          <button type="button" onClick={() => setConfirmOpen(false)} disabled={busy} aria-label="Close cancellation dialog">
            <X size={18} />
          </button>
        </header>

        <div className="tlg-avatar-confirm-body">
          <p>Your current avatar will stay unchanged. The request will be closed, the private reference image will be queued for deletion, and you will be able to submit a new avatar request immediately.</p>
          <div className="tlg-avatar-confirm-request-id"><span>Request ID</span><code>{request.id}</code></div>
        </div>

        <footer className="tlg-avatar-confirm-actions">
          <button type="button" className="tlg-avatar-confirm-secondary" onClick={() => setConfirmOpen(false)} disabled={busy}>
            Keep request
          </button>
          <button type="button" className="tlg-avatar-confirm-danger" onClick={() => void cancelRequest()} disabled={busy}>
            <XCircle size={16} /> {busy ? 'Cancelling…' : 'Cancel request'}
          </button>
        </footer>
      </div>
    </div>,
    document.body,
  ) : null

  return (
    <>
      <div className="tlg-avatar-cancel-inline">
        <div className="tlg-avatar-cancel-copy">
          <span>Need to change this request?</span>
          <p>You can cancel it and submit a new one. Your existing avatar will not be changed.</p>
        </div>
        <button
          type="button"
          className="tlg-avatar-cancel-button"
          onClick={() => {
            setError(null)
            setConfirmOpen(true)
          }}
          disabled={busy}
        >
          <XCircle size={16} /> Cancel avatar request
        </button>
        {error && <p className="tlg-avatar-cancel-error" role="alert">{error}</p>}
      </div>
      {modal}
    </>
  )
}
