import { BookOpen, CheckCircle2, Clock3, Copy, ImagePlus, Palette, RefreshCcw, ShieldCheck, Upload } from 'lucide-react'
import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react'

import { useAuth } from '../../auth/AuthContext'
import usePlayerAvatarUrl from '../../hooks/usePlayerAvatarUrl'
import { supabase } from '../../lib/supabase'
import '../../styles/avatar-replacement-request.css'

const SUPPORT_EMAIL = 'contact@tennislegacygame.com'
const PRIVATE_BUCKET = 'avatar-replacement-submissions'
const MAX_FILE_BYTES = 8 * 1024 * 1024
const ACTIVE_STATUSES = new Set(['submitted', 'under_review', 'preparing', 'ready_for_review', 'revision_requested'])
const CHATGPT_AVATAR_PROMPT = `Please create a realistic tennis player profile avatar based only on my attached photo and my own appearance. Use the attached Tennis Legacy example image only for framing and alignment. The background must be pure white. Use a passport-style, front-facing composition with the head centered and the eyes, ears, mouth and overall face position at approximately the same level as the example. Keep my real facial identity recognizable and do not make me resemble a celebrity, public figure or any other real person. Show the head and upper shoulders only. Dress me in a clean [sport jersey/polo shirt] in [preferred colors], with no logos, sponsors, text or brand marks. Use realistic lighting and a natural neutral expression, with no hat, sunglasses, props or background objects. Keep the result suitable for a square in-game profile image.`

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
  under_review: { label: 'Under review', detail: 'The Tennis Legacy team is reviewing your photo and instructions.', tone: 'info' },
  preparing: { label: 'Replacement being prepared', detail: 'A replacement avatar is currently being prepared.', tone: 'info' },
  ready_for_review: { label: 'Ready for review', detail: 'A replacement is ready. Your current avatar is still active until you approve it.', tone: 'success' },
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
  const [submissionType, setSubmissionType] = useState<'reference_photo' | 'candidate_avatar'>('reference_photo')
  const [file, setFile] = useState<File | null>(null)
  const [fileInputKey, setFileInputKey] = useState(0)
  const [reason, setReason] = useState('I want an avatar based on my real appearance')
  const [details, setDetails] = useState('')
  const [jerseyType, setJerseyType] = useState<'sport_jersey' | 'polo_shirt'>('sport_jersey')
  const [colors, setColors] = useState(['', '', ''])
  const [appearanceInstructions, setAppearanceInstructions] = useState('')
  const [revisionMessage, setRevisionMessage] = useState('')
  const [rulesOpen, setRulesOpen] = useState(false)
  const [promptCopied, setPromptCopied] = useState(false)
  const [identityConfirmed, setIdentityConfirmed] = useState(false)
  const [privacyConsent, setPrivacyConsent] = useState(false)

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
      `Submission type: ${submissionType === 'candidate_avatar' ? 'User-created replacement for approval' : 'Reference photo for admin-created replacement'}`,
      `Reason: ${reason}`,
      `Jersey type: ${jerseyType === 'sport_jersey' ? 'Sport jersey' : 'Polo shirt'}`,
      `Preferred colors: ${cleanedColors.length ? cleanedColors.join(', ') : 'None specified'}`,
      `Private photo reference: ${PRIVATE_BUCKET}/${privatePhotoReference}`,
      '',
      'Request details:',
      details.trim(),
      '',
      'Appearance instructions:',
      appearanceInstructions.trim() || 'None',
      '',
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
      setError('Please select one reference image or one finished avatar image for approval.')
      return
    }
    if (details.trim().length < 5) {
      setError('Please add a short request description.')
      return
    }
    if (!identityConfirmed) {
      setError('Please confirm that the submitted image is you or is based only on your own appearance.')
      return
    }
    if (!privacyConsent) {
      setError('Please accept the limited image-processing and privacy notice before submitting.')
      return
    }

    setBusy(true)
    let storagePath: string | null = null

    try {
      const detected = await validateImage(file)
      const requestId = crypto.randomUUID()
      storagePath = `${user.id}/${requestId}/submission.${detected.extension}`

      const { error: uploadError } = await supabase.storage
        .from(PRIVATE_BUCKET)
        .upload(storagePath, file, { contentType: detected.mime, upsert: false, cacheControl: '0' })

      if (uploadError) throw uploadError

      const { error: submitError } = await supabase.rpc('submit_avatar_replacement_request_v2', {
        p_request_id: requestId,
        p_submission_type: submissionType,
        p_storage_path: storagePath,
        p_original_file_name: file.name,
        p_mime_type: detected.mime,
        p_size_bytes: file.size,
        p_reason: reason,
        p_details: details.trim(),
        p_jersey_type: jerseyType,
        p_jersey_colors: cleanedColors,
        p_appearance_instructions: appearanceInstructions.trim(),
        p_identity_attestation: identityConfirmed,
        p_privacy_consent: privacyConsent,
        p_page_url: window.location.href,
      })

      if (submitError) {
        await supabase.storage.from(PRIVATE_BUCKET).remove([storagePath])
        throw submitError
      }

      await sendAdminEmailCopy(requestId, storagePath)
      setFile(null)
      setFileInputKey((value) => value + 1)
      setDetails('')
      setAppearanceInstructions('')
      setColors(['', '', ''])
      setIdentityConfirmed(false)
      setPrivacyConsent(false)
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
      <header className="tlg-account-section-head tlg-account-section-head-icon">
        <div>
          <span>Player image</span>
          <h3>Private avatar replacement request</h3>
          <p>Use one private photo as a reference, or upload an avatar you created yourself for approval. Nothing changes automatically and the original photo is never posted to Discord or exposed through a public URL.</p>
        </div>
        <button
          type="button"
          className="tlg-avatar-rules-button"
          onClick={() => setRulesOpen((value) => !value)}
          aria-expanded={rulesOpen}
          aria-controls="tlg-avatar-rules-panel"
        >
          <BookOpen size={16} />
          {rulesOpen ? 'Hide rules' : 'Avatar rules'}
        </button>
      </header>

      {rulesOpen && (
        <div id="tlg-avatar-rules-panel" className="tlg-avatar-rules-panel">
          <div className="tlg-avatar-rules-intro">
            <BookOpen size={20} />
            <div>
              <strong>Official Tennis Legacy avatar rules</strong>
              <p>These rules apply both to reference photos and to finished avatars created by the player.</p>
            </div>
          </div>
          <div className="tlg-avatar-rules-grid">
            <article><span>1</span><div><strong>Your own identity only</strong><p>The image must be you or an avatar based only on your own appearance. Do not submit another person, celebrity, public figure, friend or family member.</p></div></article>
            <article><span>2</span><div><strong>White background</strong><p>The final avatar must use a clean pure-white background with no scenery, objects or decorative background.</p></div></article>
            <article><span>3</span><div><strong>Passport-style framing</strong><p>Front-facing head and upper shoulders, centered and clearly visible. Eyes, ears, mouth and face position should follow the Tennis Legacy example alignment.</p></div></article>
            <article><span>4</span><div><strong>Clean game presentation</strong><p>Use a sport jersey or polo shirt in the requested colors. No logos, sponsors, brand marks, text, hats, sunglasses or distracting props.</p></div></article>
          </div>
          <div className="tlg-avatar-policy-warning">Deliberately submitting or imitating another real person, including a celebrity or public figure, is prohibited. The request may be rejected and deliberate or repeated impersonation/abuse may result in account suspension or removal from the game.</div>
          <div className="tlg-avatar-chatgpt-box">
            <div>
              <strong>Want to create the avatar yourself with ChatGPT?</strong>
              <p>Attach your own photo and the Tennis Legacy example image, then use this prompt. You can submit only the finished avatar for approval if you prefer not to send us your real photo.</p>
            </div>
            <textarea readOnly rows={6} value={CHATGPT_AVATAR_PROMPT} aria-label="Suggested ChatGPT avatar prompt" />
            <button
              type="button"
              className="tlg-account-secondary-button"
              onClick={() => {
                void navigator.clipboard.writeText(CHATGPT_AVATAR_PROMPT).then(() => {
                  setPromptCopied(true)
                  window.setTimeout(() => setPromptCopied(false), 1800)
                })
              }}
            >
              <Copy size={14} /> {promptCopied ? 'Prompt copied' : 'Copy ChatGPT prompt'}
            </button>
          </div>
        </div>
      )}

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
                <span>Type</span><strong>{request.submission_type === 'candidate_avatar' ? 'Own image · approval only' : 'Reference photo'}</strong>
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
            <form className="tlg-avatar-request-form" onSubmit={handleSubmit}>
              <div className="tlg-avatar-mode-grid">
                <label className={submissionType === 'reference_photo' ? 'selected' : ''}>
                  <input type="radio" name="avatar-mode" value="reference_photo" checked={submissionType === 'reference_photo'} onChange={() => setSubmissionType('reference_photo')} />
                  <ImagePlus size={20} />
                  <strong>Use my photo as reference</strong>
                  <span>Admin creates/prepares a game-style avatar based on your appearance and preferences.</span>
                </label>
                <label className={submissionType === 'candidate_avatar' ? 'selected' : ''}>
                  <input type="radio" name="avatar-mode" value="candidate_avatar" checked={submissionType === 'candidate_avatar'} onChange={() => setSubmissionType('candidate_avatar')} />
                  <Upload size={20} />
                  <strong>I created my own avatar</strong>
                  <span>Upload your finished image privately. It is reviewed first and never applied automatically.</span>
                </label>
              </div>

              <div className="tlg-avatar-request-grid">
                <label className="tlg-account-field tlg-avatar-file-field">
                  <span>{submissionType === 'candidate_avatar' ? 'Finished avatar image for approval' : 'One reference photo of yourself'}</span>
                  <input key={fileInputKey} type="file" accept="image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp" onChange={(event) => { setFile(event.target.files?.[0] ?? null); setError(null) }} required />
                  <small>Private upload · JPG, PNG or WEBP only · maximum 8 MB · SVG is intentionally not accepted.</small>
                  <small className="tlg-avatar-photo-privacy-note">The private submission is used only to process this avatar request, is not shown to other players or posted to public/community channels, and is not reused for unrelated purposes. The private source copy is queued for deletion as soon as the request is completed or rejected.</small>
                </label>

                <label className="tlg-account-field">
                  <span>Reason for replacement</span>
                  <select value={reason} onChange={(event) => setReason(event.target.value)} required>
                    <option>I want an avatar based on my real appearance</option>
                    <option>Avatar does not resemble me</option>
                    <option>Generated avatar quality issue</option>
                    <option>I created my own replacement image</option>
                    <option>Other</option>
                  </select>
                </label>

                <label className="tlg-account-field tlg-avatar-details-field">
                  <span>Additional request details</span>
                  <textarea rows={4} maxLength={4000} value={details} onChange={(event) => setDetails(event.target.value)} placeholder="Explain what you would like changed and anything the admin team should know." required />
                </label>

                <label className="tlg-account-field">
                  <span>Preferred jersey type</span>
                  <select value={jerseyType} onChange={(event) => setJerseyType(event.target.value as 'sport_jersey' | 'polo_shirt')}>
                    <option value="sport_jersey">Sport jersey</option>
                    <option value="polo_shirt">Polo shirt</option>
                  </select>
                </label>

                <div className="tlg-account-field tlg-avatar-colors-field">
                  <span><Palette size={14} /> Preferred jersey colors · up to 3</span>
                  <div>{colors.map((color, index) => <input key={index} maxLength={30} value={color} onChange={(event) => setColors((items) => items.map((item, itemIndex) => itemIndex === index ? event.target.value : item))} placeholder={`Color ${index + 1}${index === 0 ? ' (optional)' : ''}`} />)}</div>
                </div>

                <label className="tlg-account-field tlg-avatar-details-field">
                  <span>Optional appearance instructions</span>
                  <textarea rows={3} maxLength={2000} value={appearanceInstructions} onChange={(event) => setAppearanceInstructions(event.target.value)} placeholder="Examples: hairstyle, facial hair, expression, shirt details, or other appearance guidance." />
                </label>
              </div>

              <div className="tlg-avatar-attestations">
                <label>
                  <input type="checkbox" checked={identityConfirmed} onChange={(event) => setIdentityConfirmed(event.target.checked)} required />
                  <span><strong>Identity confirmation.</strong> I confirm that I am the person shown, or that the submitted avatar is based only on my own appearance. It is not another real person, celebrity or public figure, and I own or have the right to submit the image.</span>
                </label>
                <label>
                  <input type="checkbox" checked={privacyConsent} onChange={(event) => setPrivacyConsent(event.target.checked)} required />
                  <span><strong>Limited processing consent.</strong> I allow Tennis Legacy to access and process this private file only to review, create or approve my requested avatar. I understand that the private source copy is queued for deletion when the request is completed or rejected, while minimal request/moderation records may be retained where necessary for security, legal or abuse-prevention purposes.</span>
                </label>
              </div>

              <div className="tlg-avatar-privacy-box">
                <ShieldCheck size={18} />
                <div><strong>Private submission</strong><p>The source file is stored in a private Supabase bucket and is never exposed through a public source-image URL. It is not shown to other players, posted to Discord/community channels, or reused for unrelated purposes. When the request closes, the private source copy is queued for immediate deletion; if automatic cleanup needs a retry, it remains private until an administrator removes it.</p></div>
              </div>

              {file && <div className="tlg-avatar-selected-file"><strong>Selected:</strong> {file.name} · {(file.size / 1024 / 1024).toFixed(2)} MB</div>}
              {error && <p className="tlg-avatar-request-error" role="alert">{error}</p>}
              {success && <p className="tlg-avatar-request-success" role="status">{success}</p>}

              <div className="tlg-account-form-actions">
                <button type="submit" className="tlg-account-primary-button" disabled={!player || !user || busy}>{busy ? 'Submitting privately…' : 'Submit private avatar request'}</button>
                <small>Admin/support destination: {SUPPORT_EMAIL}. Your current avatar stays unchanged until a prepared replacement is explicitly approved by you.</small>
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
