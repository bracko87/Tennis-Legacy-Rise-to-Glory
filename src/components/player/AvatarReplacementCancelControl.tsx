import { useEffect, useState } from 'react'
import { XCircle } from 'lucide-react'

import { useAuth } from '../../auth/AuthContext'
import { supabase } from '../../lib/supabase'

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

  async function cancelRequest() {
    if (!request || busy) return

    const confirmed = window.confirm(
      'Cancel this avatar replacement request? Your current avatar will stay unchanged and you will be able to submit a new request.'
    )
    if (!confirmed) return

    setBusy(true)
    setError(null)

    const { error: cancelError } = await supabase.rpc('cancel_avatar_replacement_request_v1', {
      p_request_id: request.id,
    })

    if (cancelError) {
      setError(cancelError.message)
      setBusy(false)
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

  return (
    <section className="tlg-account-section">
      <header className="tlg-account-section-head tlg-account-section-head-icon">
        <div>
          <span>Avatar request</span>
          <h3>Withdraw active request</h3>
          <p>Cancel the current request if you want to correct it or submit it again. Your existing avatar will not be changed.</p>
        </div>
        <XCircle size={20} />
      </header>

      <div className="tlg-account-password-body">
        <button
          type="button"
          className="tlg-account-secondary-button"
          onClick={() => void cancelRequest()}
          disabled={busy}
        >
          <XCircle size={16} /> {busy ? 'Cancelling…' : 'Cancel avatar request'}
        </button>
        <small>The request will be marked as cancelled in the database, its linked support request will be closed, and the private reference image will be queued for deletion.</small>
        {error && <p className="tlg-account-status">{error}</p>}
      </div>
    </section>
  )
}
