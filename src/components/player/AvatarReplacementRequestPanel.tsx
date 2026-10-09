import { CheckCircle2, Clock3, RefreshCcw, ShieldCheck, Upload } from 'lucide-react'
import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'

import { useAuth } from '../../auth/AuthContext'
import { useLocalization } from '../../i18n/LocalizationProvider'
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

const STATUS_TONE: Record<AvatarRequestRow['status'], string> = {
  submitted: 'info',
  under_review: 'info',
  preparing: 'info',
  ready_for_review: 'success',
  completed: 'success',
  revision_requested: 'warning',
  rejected: 'warning',
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

function createSecureRequestId(t: TFunction) {
  const cryptoApi = globalThis.crypto
  if (!cryptoApi) throw new Error(t('playerAccountPage.avatar.errors.crypto'))

  if (typeof cryptoApi.randomUUID === 'function') return cryptoApi.randomUUID()
  if (typeof cryptoApi.getRandomValues !== 'function') {
    throw new Error(t('playerAccountPage.avatar.errors.crypto'))
  }

  const bytes = cryptoApi.getRandomValues(new Uint8Array(16))
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0'))
  return `${hex.slice(0, 4).join('')}-${hex.slice(4, 6).join('')}-${hex.slice(6, 8).join('')}-${hex.slice(8, 10).join('')}-${hex.slice(10, 16).join('')}`
}

async function validateImage(file: File, t: TFunction) {
  if (file.size <= 0) throw new Error(t('playerAccountPage.avatar.errors.file'))
  if (file.size > MAX_FILE_BYTES) throw new Error(t('playerAccountPage.avatar.errors.size'))

  const bytes = new Uint8Array(await file.slice(0, 16).arrayBuffer())
  const detected = detectImageType(bytes)
  if (!detected) throw new Error(t('playerAccountPage.avatar.errors.type'))

  if (file.type && file.type !== detected.mime && !(file.type === 'image/jpg' && detected.mime === 'image/jpeg')) {
    throw new Error(t('playerAccountPage.avatar.errors.mismatch'))
  }

  return detected
}

function formatDate(value: string | null, localeTag: string) {
  if (!value) return '—'
  return new Intl.DateTimeFormat(localeTag, { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value))
}

export default function AvatarReplacementRequestPanel() {
  const { t } = useTranslation()
  const { localeTag } = useLocalization()
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
  const statusTone = request ? STATUS_TONE[request.status] : null

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
      setError(t('playerAccountPage.avatar.errors.photoRequired'))
      return
    }
    if (!consentConfirmed) {
      setError(t('playerAccountPage.avatar.errors.consentRequired'))
      return
    }

    setBusy(true)
    let storagePath: string | null = null

    try {
      const detected = await validateImage(file, t)
      const requestId = createSecureRequestId(t)
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
      setSuccess(t('playerAccountPage.avatar.success.submitted', { id: requestId }))
      await loadRequest()
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : t('playerAccountPage.avatar.errors.submit')
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
      setSuccess(t('playerAccountPage.avatar.success.approved'))
      await refreshPlayer()
      await loadRequest()
    }
    setBusy(false)
  }

  async function requestRevision() {
    if (!request || busy) return
    if (revisionMessage.trim().length < 5) {
      setError(t('playerAccountPage.avatar.errors.revision'))
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
      setSuccess(t('playerAccountPage.avatar.success.revision'))
      await loadRequest()
    }
    setBusy(false)
  }

  return (
    <section className="tlg-account-section tlg-avatar-request-section">
      <header className="tlg-account-section-head">
        <div>
          <span>{t('playerAccountPage.avatar.requestKicker')}</span>
          <h3>{t('playerAccountPage.avatar.requestTitle')}</h3>
          <p>{t('playerAccountPage.avatar.requestIntro')}</p>
        </div>
      </header>

      {loading ? (
        <div className="tlg-avatar-request-loading">{t('playerAccountPage.avatar.loading')}</div>
      ) : (
        <>
          {request && statusTone && (
            <div className={`tlg-avatar-request-status tone-${statusTone}`}>
              <div className="tlg-avatar-status-main">
                <span className="tlg-avatar-status-icon">{request.status === 'completed' ? <CheckCircle2 size={19} /> : <Clock3 size={19} />}</span>
                <div>
                  <span>{t('playerAccountPage.avatar.status')}</span>
                  <strong>{t(`playerAccountPage.avatar.statuses.${request.status}.label`)}</strong>
                  <p>{t(`playerAccountPage.avatar.statuses.${request.status}.detail`)}</p>
                </div>
              </div>
              <div className="tlg-avatar-status-meta">
                <span>{t('playerAccountPage.avatar.requestId')}</span><code>{request.id}</code>
                <span>{t('playerAccountPage.avatar.submittedAt')}</span><strong>{formatDate(request.created_at, localeTag)}</strong>
                <span>{t('playerAccountPage.avatar.type')}</span><strong>{t('playerAccountPage.avatar.referencePhoto')}</strong>
              </div>
              {request.admin_public_message && <p className="tlg-avatar-admin-message"><strong>{t('playerAccountPage.avatar.adminNote')}</strong> {request.admin_public_message}</p>}
            </div>
          )}

          {request?.status === 'ready_for_review' && (
            <div className="tlg-avatar-review-panel">
              <div className="tlg-avatar-review-copy">
                <span>{t('playerAccountPage.avatar.readyKicker')}</span>
                <h4>{t('playerAccountPage.avatar.readyTitle')}</h4>
                <p>{t('playerAccountPage.avatar.readyBody')}</p>
                <div className="tlg-avatar-review-meta"><span>{t('playerAccountPage.avatar.revisionsUsed')}</span><strong>{request.revision_count} / 2</strong></div>
              </div>
              <div className="tlg-avatar-review-image">
                {reviewAvatarUrl ? <img src={reviewAvatarUrl} alt={t('playerAccountPage.avatar.preparedAlt')} /> : <div>{t('playerAccountPage.avatar.loadingPreview')}</div>}
              </div>
              <div className="tlg-avatar-review-actions">
                <button type="button" className="tlg-account-primary-button" onClick={() => void approveReplacement()} disabled={busy || !reviewAvatarUrl}>{t('playerAccountPage.avatar.approve')}</button>
                {request.revision_count < 2 && (
                  <div className="tlg-avatar-revision-box">
                    <label><span>{t('playerAccountPage.avatar.revision')}</span><textarea rows={3} maxLength={1000} value={revisionMessage} onChange={(event) => setRevisionMessage(event.target.value)} placeholder={t('playerAccountPage.avatar.revisionPlaceholder')} /></label>
                    <button type="button" className="tlg-account-secondary-button" onClick={() => void requestRevision()} disabled={busy}>{t('playerAccountPage.avatar.requestRevision')}</button>
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
                  ? t('playerAccountPage.avatar.deletedOn', { date: formatDate(request.reference_deleted_at, localeTag) })
                  : t('playerAccountPage.avatar.deletionQueued')}
              </p>
            </div>
          )}

          {!isActive && (
            <form className="tlg-avatar-request-form tlg-avatar-request-form-simple" onSubmit={handleSubmit}>
              <div className="tlg-avatar-simple-upload">
                <div className="tlg-avatar-simple-copy">
                  <Upload size={22} />
                  <div>
                    <strong>{t('playerAccountPage.avatar.uploadTitle')}</strong>
                    <p>{t('playerAccountPage.avatar.uploadBody')}</p>
                  </div>
                </div>
                <label className="tlg-account-field tlg-avatar-file-field">
                  <span>{t('playerAccountPage.avatar.yourPhoto')}</span>
                  <input key={fileInputKey} type="file" accept="image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp" onChange={(event) => { setFile(event.target.files?.[0] ?? null); setError(null) }} required />
                </label>
              </div>

              <div className="tlg-avatar-simple-colors">
                <span>{t('playerAccountPage.avatar.jerseyColors')}</span>
                <div>
                  {colors.map((color, index) => (
                    <input
                      key={index}
                      maxLength={30}
                      value={color}
                      onChange={(event) => setColors((items) => items.map((item, itemIndex) => itemIndex === index ? event.target.value : item))}
                      placeholder={t('playerAccountPage.avatar.colorPlaceholder', { index: index + 1 })}
                    />
                  ))}
                </div>
              </div>

              <label className="tlg-avatar-simple-consent">
                <input type="checkbox" checked={consentConfirmed} onChange={(event) => setConsentConfirmed(event.target.checked)} required />
                <span>{t('playerAccountPage.avatar.consent')}</span>
              </label>

              <div className="tlg-avatar-privacy-box">
                <ShieldCheck size={18} />
                <div><strong>{t('playerAccountPage.avatar.privacyTitle')}</strong><p>{t('playerAccountPage.avatar.privacyBody')}</p></div>
              </div>

              {file && <div className="tlg-avatar-selected-file"><strong>{t('playerAccountPage.avatar.selected')}</strong> {file.name} · {(file.size / 1024 / 1024).toFixed(2)} MB</div>}
              {error && <p className="tlg-avatar-request-error" role="alert">{error}</p>}
              {success && <p className="tlg-avatar-request-success" role="status">{success}</p>}

              <div className="tlg-account-form-actions">
                <button type="submit" className="tlg-account-primary-button" disabled={!player || !user || busy}>{busy ? t('playerAccountPage.avatar.uploading') : t('playerAccountPage.avatar.submit')}</button>
                <small>{t('playerAccountPage.avatar.submitNote')}</small>
              </div>
            </form>
          )}

          {isActive && request?.status !== 'ready_for_review' && (
            <div className="tlg-avatar-active-note"><RefreshCcw size={17} /><p>{t('playerAccountPage.avatar.activeNote')}</p></div>
          )}

          {isActive && error && <p className="tlg-avatar-request-error active" role="alert">{error}</p>}
          {isActive && success && <p className="tlg-avatar-request-success active" role="status">{success}</p>}
        </>
      )}
    </section>
  )
}
