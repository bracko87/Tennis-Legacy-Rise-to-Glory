import { CheckCircle2, Clock3, RefreshCcw, ShieldCheck, Upload } from 'lucide-react'
import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react'

import { useAuth } from '../../auth/AuthContext'
import usePlayerAvatarUrl from '../../hooks/usePlayerAvatarUrl'
import { supabase } from '../../lib/supabase'
import '../../styles/avatar-replacement-request.css'

const SUPPORT_EMAIL = 'contact@tennislegacygame.com'
const PRIVATE_BUCKET = 'avatar-replacement-submissions'
const MAX_FILE_BYTES = 8 * 1024 * 1024
const ACTIVE_STATUSES = new Set(['submitted', 'under_review', 'preparing', 'ready_for_review', 'revision_requested'])
interface AvatarRequestRow {
  id: string
  user_id: string
  player_id: string
  submission_type: 'reference_photo' | 'candidate_avatar'
  original_file_name: string
  reason: string
  details: string
  jersey_type: 'sport_jersey' | 'polo_shirt'
  jersey_colors: string[]
  appearance_instructions: string
  status: 'submitted' | 'under_review' | 'preparing' | 'ready_for_review' | 'completed' | 'revision_requested' | 'rejected'
  review_image_path: string | null
  admin_public_message: string | null
  user_revision_message: string | null
  revision_count: number
  ready_for_review_at: string | null
  completed_at: string | null
  rejected_at: string | null
  reference_delete_after: string | null
  reference_deleted_at: string | null
  created_at: string
  updated_at: string
}

const STATUS_COPY: Record<AvatarRequestRow['status'], { label: string; detail: string; tone: string }> = {
  submitted: { label: 'Submitted', detail: 'The private request is in the admin queue.', tone: 'info' },
  under_review: { label: 'Under review', detail: 'The Tennis Legacy team is reviewing your photo.', tone: 'info' },
  preparing: { label: 'Replacement being prepared', detail: 'A replacement avatar is currently being prepared.', tone: 'info' },
  ready_for_review: { label: 'Ready for review', detail: 'Your prepared avatar is ready. Your current avatar stays active until you approve it.', tone: 'success' },
  completed: { label: 'Completed', detail: 'You approved the replacement and it is now active.', tone: 'success' },
  revision_requested: { label: 'Revision requested', detail: 'Your feedback was returned to the admin team for another revision.', tone: 'warning' },
  rejected: { label: 'Rejected / unable to process', detail: 'The request was closed without changing your current avatar.', tone: 'warning' },
}

function detectImageType(bytes: Uint8Array) {
  const isJpeg = bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff
  if (isJpeg) return { mime: 'image/jpeg', extension: 'jpg' }

  const pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
  const isPng = bytes.length >= 8 && pngSignature.every((value, index) => bytes[index] === value)
  if (isPng) return { mime: 'image/png', extension: 'png' }

  const text = String.fromCharCode(...bytes.slice(0, 12))
  if (bytes.length >= 12 && text.startsWith('RIFF') && text.slice(8, 12) === 'WEBP') {
    return { mime: 'image/webp', extension: 'webp' }
  }

  return null
}

function createSecureRequestId() {
  const cryptoApi = globalThis.crypto
  if (!cryptoApi) throw new Error('Secure random number generation is not supported by this browser.')

  if (typeof cryptoApi.randomUUID === 'function') return cryptoApi.randomUUID()
  if (typeof cryptoApi.getRandomValues !== 'function') {
    throw new Error('Secure random number generation is not supported by this browser.')
  }

  const bytes = cryptoApi.getRandomValues(new Uint8Array(16))
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0'))
  return `${hex.slice(0, 4).join('')}-${hex.slice(4, 6).join('')}-${hex.slice(6, 8).join('')}-${hex.slice(8, 10).join('')}-${hex.slice(10, 16).join('')}`
}

async function validateImage(file: File) {
  if (file.size <= 0) throw new Error('Please choose a valid image file.')
  if (file.size > MAX_FILE_BYTES) throw new Error('The image must be 8 MB or smaller.')

  const bytes = new Uint8Array(await file.slice(0, 16).arrayBuffer())
  const detected = detectImageType(bytes)
  if (!detected) throw new Error('Only JPG, PNG and WEBP images are accepted. SVG and executable files are not allowed.')

  if (file.type && file.type !== detected.mime && !(file.type === 'image/jpg' && detected.mime === 'image/jpeg')) {
    throw new Error('The image contents do not match the selected file type.')
  }

  return detected
}

function formatDate(value: string | null) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value))
}

export default function AvatarReplacementRequestPanel() {
  const { player, user, refreshPlayer } = useAuth()
  const [request, setRequest] = useState<AvatarRequestRow | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)
  const [file, setFile] = useState<File | null>(null)
  const [fileInputKey, setFileInputKey] = useState(0)
  const [colors, setColors] = useState(['', '', ''])
  const [revisionMessage, setRevisionMessage] = useState('')
  const [consentConfirmed, setConsentConfirmed] = useState(false)

  const reviewAvatarUrl = usePlayerAvatarUrl(request?.status === 'ready_for_review' ? request.review_image_path : null)
  const isActive = Boolean(request && ACTIVE_STATUSES.has(request.status))
  const statusCopy = request ? STATUS_COPY[request.status] : null

  const loadRequest = useCallback(async () => {
    if (!user?.id) {
      setRequest(null)
      setLoading(false)
      return
    }

    const { data, error: loadError } = await supabase
      .from('avatar_replacement_requests')
      .select('id, user_id, player_id, submission_type, original_file_name, reason, details, jersey_type, jersey_colors, appearance_instructions, status, review_image_path, admin_public_message, user_revision_message, revision_count, ready_for_review_at, completed_at, rejected_at, reference_delete_after, reference_deleted_at, created_at, updated_at')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (loadError) {
      setError(loadError.message)
      setRequest(null)
    } else {
      setRequest((data ?? null) as AvatarRequestRow | null)
    }
    setLoading(false)
  }, [user?.id])

  useEffect(() => {
    void loadRequest()
    if (!user?.id) return

    const timer = window.setInterval(() => {
      void loadRequest()
    }, 30000)

    return () => window.clearInterval(timer)
  }, [loadRequest, user?.id])


  useEffect(() => {
    if (!request || !['completed', 'rejected'].includes(request.status) || request.reference_deleted_at) return

    let cancelled = false

    async function cleanupPrivateSubmission() {
      const { data: cleanupPath, error: cleanupPathError } = await supabase.rpc('get_avatar_reference_cleanup_path_v1', {
        p_request_id: request.id,
      })
      if (cleanupPathError || !cleanupPath || cancelled) return

      const { error: removeError } = await supabase.storage.from(PRIVATE_BUCKET).remove([String(cleanupPath)])
      if (removeError || cancelled) return

      const { error: confirmError } = await supabase.rpc('confirm_avatar_reference_deleted_v1', {
        p_request_id: request.id,
      })
      if (!confirmError && !cancelled) await loadRequest()
    }

    void cleanupPrivateSubmission()
    return () => { cancelled = true }
  }, [loadRequest, request?.id, request?.reference_deleted_at, request?.status])

  const cleanedColors = useMemo(() => colors.map((value) => value.trim()).filter(Boolean).slice(0, 3), [colors])

  async function sendAdminEmailCopy(requestId: string, privatePhotoReference: string) {
    if (!player || !user) return
    const playerName = `${player.first_name} ${player.last_name}`.trim()
    const payload = new URLSearchParams()
    payload.set('form-name', 'tennis-legacy-contact')
    payload.set('request_id', requestId)
    payload.set('support_destination', SUPPORT_EMAIL)
    payload.set('account_email', user.email ?? '')
    payload.set('player_name', playerName)
    payload.set('world', player.world)
    payload.set('country_code', player.country_code)
    payload.set('category', 'Other')
    payload.set('subject', `Avatar replacement request — ${playerName}`)
    payload.set('message', [
      'Private Tennis Legacy avatar replacement request',
      '',
      `Request ID: ${requestId}`,
      `User ID: ${user.id}`,
      `Player: ${playerName}`,
      `Player ID: ${player.id}`,
      'Submission type: Reference photo for avatar creation',
      'Jersey type: Sport jersey',
      `Preferred colors: ${cleanedColors.length ? cleanedColors.join(', ') : 'None specified'}`,
      `Private photo reference: ${PRIVATE_BUCKET}/${privatePhotoReference}`,
      '',
      'Create a Tennis Legacy profile avatar from this private reference photo.',
      'The uploaded image is private and is not attached to this email or exposed through a public URL.',
    ].join('\n'))
    payload.set('page_url', window.location.href)

    try {
      await fetch('/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: payload.toString(),
      })
    } catch {
      // The database request and support queue record are authoritative; email forwarding is best-effort.
    }
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!user || !player || busy) return
    setError(null)
    setSuccess(null)

    if (!file) {
      setError('Please upload one clear photo of yourself.')
      return
    }
    if (!consentConfirmed) {
      setError('Please confirm that this is your own photo and that Tennis Legacy may process it privately for this avatar request.')
      return
    }

    setBusy(true)
    let storagePath: string | null = null

    try {
      const detected = await validateImage(file)
      const requestId = createSecureRequestId()
      storagePath = `${user.id}/${requestId}/submission.${detected.extension}`

      const { error: uploadError } = await supabase.storage
        .from(PRIVATE_BUCKET)
        .upload(storagePath, file, { contentType: detected.mime, upsert: false, cacheControl: '0' })

      if (uploadError) throw uploadError

      const { error: submitError } = await supabase.rpc('submit_avatar_replacement_request_v2', {
        p_request_id: requestId,
        p_submission_type: 'reference_photo',
        p_storage_path: storagePath,
        p_original_file_name: file.name,
        p_mime_type: detected.mime,
        p_size_bytes: file.size,
        p_reason: 'Profile avatar request',
        p_details: 'Create a Tennis Legacy profile avatar from my private reference photo.',
        p_jersey_type: 'sport_jersey',
        p_jersey_colors: cleanedColors,
        p_appearance_instructions: '',
        p_identity_attestation: consentConfirmed,
        p_privacy_consent: consentConfirmed,
        p_page_url: window.location.href,
      })

      if (submitError) {
        await supabase.storage.from(PRIVATE_BUCKET).remove([storagePath])
        throw submitError
      }

      await sendAdminEmailCopy(requestId, storagePath)
      setFile(null)
      setFileInputKey((value) => value + 1)
      setColors(['', '', ''])
      setConsentConfirmed(false)
      setSuccess(`Request ${requestId} was submitted privately to Tennis Legacy support.`)
      await loadRequest()
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : 'The avatar request could not be submitted.'
      setError(message)
    } finally {
      setBusy(false)
    }
  }

  async function approveReplacement() {
    if (!request || busy) return
    setBusy(true)
    setError(null)
    const { error: approveError } = await supabase.rpc('approve_avatar_replacement_v1', { p_request_id: request.id })
    if (approveError) {
      setError(approveError.message)
    } else {
      setSuccess('Replacement approved. Your new avatar is now active.')
      await refreshPlayer()
      await loadRequest()
    }
    setBusy(false)
  }

  async function requestRevision() {
    if (!request || busy) return
    if (revisionMessage.trim().length < 5) {
      setError('Please explain what should be corrected in at least 5 characters.')
      return
    }
    setBusy(true)
    setError(null)
    const { error: revisionError } = await supabase.rpc('request_avatar_replacement_revision_v1', {
      p_request_id: request.id,
      p_message: revisionMessage.trim(),
    })
    if (revisionError) {
      setError(revisionError.message)
    } else {
      setRevisionMessage('')
      setSuccess('Revision request sent. Your current avatar remains active.')
      await loadRequest()
    }
    setBusy(false)
  }

  return (
    <section className="tlg-account-section tlg-avatar-request-section">
      <header className="tlg-account-section-head">
        <div>
          <span>Player image</span>
          <h3>Private avatar replacement request</h3>
          <p>Upload one clear photo of yourself and, if you want, choose up to three jersey colors. We prepare the Tennis Legacy avatar, you review it, and nothing changes until you approve it.</p>
        </div>
      </header>

      {loading ? (
        <div className="tlg-avatar-request-loading">Loading avatar request status…</div>
      ) : (
        <>
          {request && statusCopy && (
            <div className={`tlg-avatar-request-status tone-${statusCopy.tone}`}>
              <div className="tlg-avatar-status-main">
                <span className="tlg-avatar-status-icon">{request.status === 'completed' ? <CheckCircle2 size={19} /> : <Clock3 size={19} />}</span>
                <div>
                  <span>Request status</span>
                  <strong>{statusCopy.label}</strong>
                  <p>{statusCopy.detail}</p>
                </div>
              </div>
              <div className="tlg-avatar-status-meta">
                <span>Request ID</span><code>{request.id}</code>
                <span>Submitted</span><strong>{formatDate(request.created_at)}</strong>
                <span>Type</span><strong>Reference photo</strong>
              </div>
              {request.admin_public_message && <p className="tlg-avatar-admin-message"><strong>Admin note:</strong> {request.admin_public_message}</p>}
            </div>
          )}

          {request?.status === 'ready_for_review' && (
            <div className="tlg-avatar-review-panel">
              <div className="tlg-avatar-review-copy">
                <span>Replacement ready</span>
                <h4>Review before applying</h4>
                <p>Your existing avatar remains active until you press <strong>Approve & apply</strong>. If something is wrong, you may request up to two revisions.</p>
                <div className="tlg-avatar-review-meta"><span>Revisions used</span><strong>{request.revision_count} / 2</strong></div>
              </div>
              <div className="tlg-avatar-review-image">
                {reviewAvatarUrl ? <img src={reviewAvatarUrl} alt="Prepared replacement avatar" /> : <div>Loading preview…</div>}
              </div>
              <div className="tlg-avatar-review-actions">
                <button type="button" className="tlg-account-primary-button" onClick={() => void approveReplacement()} disabled={busy || !reviewAvatarUrl}>Approve & apply</button>
                {request.revision_count < 2 && (
                  <div className="tlg-avatar-revision-box">
                    <label><span>Revision request</span><textarea rows={3} maxLength={1000} value={revisionMessage} onChange={(event) => setRevisionMessage(event.target.value)} placeholder="Describe exactly what should be corrected." /></label>
                    <button type="button" className="tlg-account-secondary-button" onClick={() => void requestRevision()} disabled={busy}>Request revision</button>
                  </div>
                )}
              </div>
            </div>
          )}

          {request && ['completed', 'rejected'].includes(request.status) && (
            <div className="tlg-avatar-retention-note">
              <ShieldCheck size={17} />
              <p>
                {request.reference_deleted_at
                  ? `The private original/reference image was deleted on ${formatDate(request.reference_deleted_at)}.`
                  : 'The private original/reference image is queued for immediate deletion now that the request is closed. If automatic cleanup needs a retry, the file remains private until it is removed.'}
              </p>
            </div>
          )}

          {!isActive && (
            <form className="tlg-avatar-request-form tlg-avatar-request-form-simple" onSubmit={handleSubmit}>
              <div className="tlg-avatar-simple-upload">
                <div className="tlg-avatar-simple-copy">
                  <Upload size={22} />
                  <div>
                    <strong>Upload your photo</strong>
                    <p>Use a clear, front-facing photo of yourself. JPG, PNG or WEBP, maximum 8 MB.</p>
                  </div>
                </div>
                <label className="tlg-account-field tlg-avatar-file-field">
                  <span>Your photo</span>
                  <input key={fileInputKey} type="file" accept="image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp" onChange={(event) => { setFile(event.target.files?.[0] ?? null); setError(null) }} required />
                </label>
              </div>

              <div className="tlg-avatar-simple-colors">
                <span>Jersey colors · optional · up to 3</span>
                <div>
                  {colors.map((color, index) => (
                    <input
                      key={index}
                      maxLength={30}
                      value={color}
                      onChange={(event) => setColors((items) => items.map((item, itemIndex) => itemIndex === index ? event.target.value : item))}
                      placeholder={`Color ${index + 1}`}
                    />
                  ))}
                </div>
              </div>

              <label className="tlg-avatar-simple-consent">
                <input type="checkbox" checked={consentConfirmed} onChange={(event) => setConsentConfirmed(event.target.checked)} required />
                <span>I confirm this is my own photo and allow Tennis Legacy to process it privately only for this avatar request.</span>
              </label>

              <div className="tlg-avatar-privacy-box">
                <ShieldCheck size={18} />
                <div><strong>Private upload</strong><p>Your source photo is stored privately, is not shown to other players, and is queued for deletion after the request is completed or rejected.</p></div>
              </div>

              {file && <div className="tlg-avatar-selected-file"><strong>Selected:</strong> {file.name} · {(file.size / 1024 / 1024).toFixed(2)} MB</div>}
              {error && <p className="tlg-avatar-request-error" role="alert">{error}</p>}
              {success && <p className="tlg-avatar-request-success" role="status">{success}</p>}

              <div className="tlg-account-form-actions">
                <button type="submit" className="tlg-account-primary-button" disabled={!player || !user || busy}>{busy ? 'Uploading privately…' : 'Submit photo for avatar creation'}</button>
                <small>Your current avatar stays unchanged until you review and approve the prepared replacement.</small>
              </div>
            </form>
          )}

          {isActive && request?.status !== 'ready_for_review' && (
            <div className="tlg-avatar-active-note"><RefreshCcw size={17} /><p>A new request cannot be opened while this one is active. You can follow the current state here; the page updates when the admin team changes it.</p></div>
          )}

          {isActive && error && <p className="tlg-avatar-request-error active" role="alert">{error}</p>}
          {isActive && success && <p className="tlg-avatar-request-success active" role="status">{success}</p>}
        </>
      )}
    </section>
  )
}
