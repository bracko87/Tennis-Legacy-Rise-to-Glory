from pathlib import Path

component = Path('src/components/player/AvatarReplacementRequestPanel.tsx')
text = component.read_text()

def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 occurrence, found {count}')
    text = text.replace(old, new, 1)

replace_once(
    "import { Camera, CheckCircle2, Clock3, ImagePlus, Palette, RefreshCcw, ShieldCheck, Upload } from 'lucide-react'",
    "import { BookOpen, CheckCircle2, Clock3, Copy, ImagePlus, Palette, RefreshCcw, ShieldCheck, Upload } from 'lucide-react'",
    'icon import',
)

replace_once(
    "const ACTIVE_STATUSES = new Set(['submitted', 'under_review', 'preparing', 'ready_for_review', 'revision_requested'])\n",
    "const ACTIVE_STATUSES = new Set(['submitted', 'under_review', 'preparing', 'ready_for_review', 'revision_requested'])\nconst CHATGPT_AVATAR_PROMPT = `Please create a realistic tennis player profile avatar based only on my attached photo and my own appearance. Use the attached Tennis Legacy example image only for framing and alignment. The background must be pure white. Use a passport-style, front-facing composition with the head centered and the eyes, ears, mouth and overall face position at approximately the same level as the example. Keep my real facial identity recognizable and do not make me resemble a celebrity, public figure or any other real person. Show the head and upper shoulders only. Dress me in a clean [sport jersey/polo shirt] in [preferred colors], with no logos, sponsors, text or brand marks. Use realistic lighting and a natural neutral expression, with no hat, sunglasses, props or background objects. Keep the result suitable for a square in-game profile image.`\n",
    'prompt constant',
)

replace_once(
    "  const [revisionMessage, setRevisionMessage] = useState('')\n",
    "  const [revisionMessage, setRevisionMessage] = useState('')\n  const [rulesOpen, setRulesOpen] = useState(false)\n  const [promptCopied, setPromptCopied] = useState(false)\n  const [identityConfirmed, setIdentityConfirmed] = useState(false)\n  const [privacyConsent, setPrivacyConsent] = useState(false)\n",
    'new state',
)

poll = """  useEffect(() => {
    void loadRequest()
    if (!user?.id) return

    const timer = window.setInterval(() => {
      void loadRequest()
    }, 30000)

    return () => window.clearInterval(timer)
  }, [loadRequest, user?.id])
"""
cleanup = poll + """

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
"""
replace_once(poll, cleanup, 'cleanup effect')

replace_once(
    """    if (details.trim().length < 5) {
      setError('Please add a short request description.')
      return
    }

    setBusy(true)
""",
    """    if (details.trim().length < 5) {
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
""",
    'submit validation',
)

replace_once("supabase.rpc('submit_avatar_replacement_request_v1'", "supabase.rpc('submit_avatar_replacement_request_v2'", 'submit rpc')

replace_once(
    """        p_appearance_instructions: appearanceInstructions.trim(),
        p_page_url: window.location.href,
""",
    """        p_appearance_instructions: appearanceInstructions.trim(),
        p_identity_attestation: identityConfirmed,
        p_privacy_consent: privacyConsent,
        p_page_url: window.location.href,
""",
    'submit rpc args',
)

replace_once(
    """      setAppearanceInstructions('')
      setColors(['', '', ''])
      setSuccess(`Request ${requestId} was submitted privately to Tennis Legacy support.`)
""",
    """      setAppearanceInstructions('')
      setColors(['', '', ''])
      setIdentityConfirmed(false)
      setPrivacyConsent(false)
      setSuccess(`Request ${requestId} was submitted privately to Tennis Legacy support.`)
""",
    'form reset',
)

replace_once(
    """        <Camera size={20} />
      </header>

      {loading ? (
""",
    """        <button
          type=\"button\"
          className=\"tlg-avatar-rules-button\"
          onClick={() => setRulesOpen((value) => !value)}
          aria-expanded={rulesOpen}
          aria-controls=\"tlg-avatar-rules-panel\"
        >
          <BookOpen size={16} />
          {rulesOpen ? 'Hide rules' : 'Avatar rules'}
        </button>
      </header>

      {rulesOpen && (
        <div id=\"tlg-avatar-rules-panel\" className=\"tlg-avatar-rules-panel\">
          <div className=\"tlg-avatar-rules-intro\">
            <BookOpen size={20} />
            <div>
              <strong>Official Tennis Legacy avatar rules</strong>
              <p>These rules apply both to reference photos and to finished avatars created by the player.</p>
            </div>
          </div>
          <div className=\"tlg-avatar-rules-grid\">
            <article><span>1</span><div><strong>Your own identity only</strong><p>The image must be you or an avatar based only on your own appearance. Do not submit another person, celebrity, public figure, friend or family member.</p></div></article>
            <article><span>2</span><div><strong>White background</strong><p>The final avatar must use a clean pure-white background with no scenery, objects or decorative background.</p></div></article>
            <article><span>3</span><div><strong>Passport-style framing</strong><p>Front-facing head and upper shoulders, centered and clearly visible. Eyes, ears, mouth and face position should follow the Tennis Legacy example alignment.</p></div></article>
            <article><span>4</span><div><strong>Clean game presentation</strong><p>Use a sport jersey or polo shirt in the requested colors. No logos, sponsors, brand marks, text, hats, sunglasses or distracting props.</p></div></article>
          </div>
          <div className=\"tlg-avatar-policy-warning\">Deliberately submitting or imitating another real person, including a celebrity or public figure, is prohibited. The request may be rejected and deliberate or repeated impersonation/abuse may result in account suspension or removal from the game.</div>
          <div className=\"tlg-avatar-chatgpt-box\">
            <div>
              <strong>Want to create the avatar yourself with ChatGPT?</strong>
              <p>Attach your own photo and the Tennis Legacy example image, then use this prompt. You can submit only the finished avatar for approval if you prefer not to send us your real photo.</p>
            </div>
            <textarea readOnly rows={6} value={CHATGPT_AVATAR_PROMPT} aria-label=\"Suggested ChatGPT avatar prompt\" />
            <button
              type=\"button\"
              className=\"tlg-account-secondary-button\"
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
""",
    'rules panel',
)

replace_once(
    """                  <small>Private upload · JPG, PNG or WEBP only · maximum 8 MB · SVG is intentionally not accepted.</small>
                </label>
""",
    """                  <small>Private upload · JPG, PNG or WEBP only · maximum 8 MB · SVG is intentionally not accepted.</small>
                  <small className=\"tlg-avatar-photo-privacy-note\">The private submission is used only to process this avatar request, is not shown to other players or posted to public/community channels, and is not reused for unrelated purposes. The private source copy is queued for deletion as soon as the request is completed or rejected.</small>
                </label>
""",
    'upload disclaimer',
)

replace_once(
    """              <div className=\"tlg-avatar-privacy-box\">
                <ShieldCheck size={18} />
                <div><strong>Private submission</strong><p>The source image is stored in a private Supabase bucket. The admin email contains only a request ID and private storage reference, never a public image URL. Closed-request source images are targeted for deletion after 30 days and can be removed earlier by an administrator.</p></div>
              </div>
""",
    """              <div className=\"tlg-avatar-attestations\">
                <label>
                  <input type=\"checkbox\" checked={identityConfirmed} onChange={(event) => setIdentityConfirmed(event.target.checked)} required />
                  <span><strong>Identity confirmation.</strong> I confirm that I am the person shown, or that the submitted avatar is based only on my own appearance. It is not another real person, celebrity or public figure, and I own or have the right to submit the image.</span>
                </label>
                <label>
                  <input type=\"checkbox\" checked={privacyConsent} onChange={(event) => setPrivacyConsent(event.target.checked)} required />
                  <span><strong>Limited processing consent.</strong> I allow Tennis Legacy to access and process this private file only to review, create or approve my requested avatar. I understand that the private source copy is queued for deletion when the request is completed or rejected, while minimal request/moderation records may be retained where necessary for security, legal or abuse-prevention purposes.</span>
                </label>
              </div>

              <div className=\"tlg-avatar-privacy-box\">
                <ShieldCheck size={18} />
                <div><strong>Private submission</strong><p>The source file is stored in a private Supabase bucket and is never exposed through a public source-image URL. It is not shown to other players, posted to Discord/community channels, or reused for unrelated purposes. When the request closes, the private source copy is queued for immediate deletion; if automatic cleanup needs a retry, it remains private until an administrator removes it.</p></div>
              </div>
""",
    'privacy and attestation',
)

replace_once(
    """                {request.reference_deleted_at
                  ? `The private original/reference image was deleted on ${formatDate(request.reference_deleted_at)}.`
                  : request.reference_delete_after
                    ? `The private original/reference image is scheduled for deletion after ${formatDate(request.reference_delete_after)} and may be deleted earlier by an administrator.`
                    : 'The closed request no longer changes your avatar. The admin team can delete the private original/reference image when it is no longer needed.'}
""",
    """                {request.reference_deleted_at
                  ? `The private original/reference image was deleted on ${formatDate(request.reference_deleted_at)}.`
                  : 'The private original/reference image is queued for immediate deletion now that the request is closed. If automatic cleanup needs a retry, the file remains private until it is removed.'}
""",
    'retention copy',
)

component.write_text(text)

css = Path('src/styles/avatar-replacement-request.css')
css_text = css.read_text()
if '.tlg-avatar-rules-button{' in css_text:
    raise SystemExit('rules styles already present')
css_text += """
.tlg-avatar-rules-button{min-height:36px;display:inline-flex;align-items:center;gap:7px;padding:0 12px;border:1px solid #bad8ed;border-radius:8px;color:#0967b8;background:#f5fbff;font:inherit;font-size:.64rem;font-weight:800;cursor:pointer;white-space:nowrap}
.tlg-avatar-rules-button:hover{border-color:#83bee5;background:#edf8ff}
.tlg-avatar-rules-panel{display:grid;gap:14px;margin:18px 22px 0;padding:17px 18px;border:1px solid #cbdfea;border-radius:11px;background:#f8fcff}
.tlg-avatar-rules-intro{display:flex;align-items:flex-start;gap:11px}.tlg-avatar-rules-intro>svg{flex:0 0 auto;color:#0b6fc8}.tlg-avatar-rules-intro strong{display:block;color:#173c57;font-size:.78rem}.tlg-avatar-rules-intro p{margin:4px 0 0;color:#6c8293;font-size:.63rem;line-height:1.5}
.tlg-avatar-rules-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.tlg-avatar-rules-grid article{display:flex;gap:10px;padding:12px;border:1px solid #d8e6ee;border-radius:9px;background:#fff}.tlg-avatar-rules-grid article>span{width:24px;height:24px;display:inline-flex;align-items:center;justify-content:center;flex:0 0 auto;border-radius:50%;color:#fff;background:#0b6fc8;font-size:.6rem;font-weight:800}.tlg-avatar-rules-grid strong{display:block;color:#27485f;font-size:.67rem}.tlg-avatar-rules-grid p{margin:4px 0 0;color:#718696;font-size:.61rem;line-height:1.48}
.tlg-avatar-policy-warning{padding:11px 13px;border:1px solid #ecc5c5;border-radius:8px;color:#8c3030;background:#fff7f7;font-size:.62rem;font-weight:700;line-height:1.55}
.tlg-avatar-chatgpt-box{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:10px;padding-top:13px;border-top:1px solid #d8e5ed}.tlg-avatar-chatgpt-box>div{grid-column:1/-1}.tlg-avatar-chatgpt-box strong{display:block;color:#23465e;font-size:.7rem}.tlg-avatar-chatgpt-box p{margin:4px 0 0;color:#6e8495;font-size:.62rem;line-height:1.5}.tlg-avatar-chatgpt-box textarea{width:100%;min-height:120px;padding:10px 11px;border:1px solid #cadbe6;border-radius:8px;resize:vertical;color:#34546b;background:#fff;font:inherit;font-size:.62rem;line-height:1.5}.tlg-avatar-chatgpt-box .tlg-account-secondary-button{align-self:start;gap:6px}
.tlg-avatar-photo-privacy-note{display:block;margin-top:5px;padding:8px 9px;border-left:3px solid #77b79a;color:#587767!important;background:#f5fbf8;font-size:.59rem!important;line-height:1.5!important}
.tlg-avatar-attestations{display:grid;gap:9px}.tlg-avatar-attestations label{display:flex;align-items:flex-start;gap:9px;padding:11px 12px;border:1px solid #d7e3ea;border-radius:9px;background:#fff;cursor:pointer}.tlg-avatar-attestations input{width:16px;height:16px;flex:0 0 auto;margin-top:1px;accent-color:#0b6fc8}.tlg-avatar-attestations span{color:#617a8d;font-size:.62rem;line-height:1.55}.tlg-avatar-attestations strong{color:#294c65}
@media(max-width:900px){.tlg-avatar-rules-grid{grid-template-columns:1fr}.tlg-avatar-chatgpt-box{grid-template-columns:1fr}.tlg-avatar-chatgpt-box .tlg-account-secondary-button{width:fit-content}}
@media(max-width:640px){.tlg-avatar-rules-panel{margin-left:16px;margin-right:16px}.tlg-avatar-rules-button{width:auto}.tlg-avatar-chatgpt-box .tlg-account-secondary-button{width:100%}}
"""
css.write_text(css_text)

doc = Path('docs/avatar-replacement-admin-workflow.md')
doc_text = doc.read_text()
doc_text = doc_text.replace('The user is notified and the private source image receives a 30-day deletion target.', 'The user is notified and the private source image receives an immediate deletion target. Delete the private source object as part of closing the request.')
doc_text = doc_text.replace('Completed or rejected requests set `reference_delete_after` to 30 days after closure. Admins may delete the private source image earlier when it is no longer needed.', 'Completed or rejected requests set `reference_delete_after` immediately. The client attempts to remove the user-owned private source copy as soon as it sees the closed status; admins should delete it immediately as part of closing a request if it still exists.')
doc_text = doc_text.replace('and schedules the private reference image for deletion after 30 days.', 'and queues the private reference image for immediate deletion.')
if '## Identity and avatar rules' not in doc_text:
    doc_text += """

## Identity and avatar rules

The submitted image must show the account holder or be a generated avatar based only on the account holder's own appearance. Another real person, celebrity or public figure is not permitted. Deliberate or repeated impersonation/abuse may lead to account suspension or removal.

Final avatars should use a pure white background, front-facing passport-style head/upper-shoulder framing, and the standard Tennis Legacy face alignment. Sport jerseys or polo shirts may use the player's requested colors, but final images should not contain logos, sponsors, brand marks, text, hats, sunglasses or distracting props.

New submissions must record both an identity attestation and a limited-processing consent. The consent is limited to processing the private file for the avatar request; do not reuse the source image for unrelated purposes or publish it to community channels. Minimal request/moderation metadata may be retained for security, legal or abuse-prevention needs after the image itself is removed.
"""
doc.write_text(doc_text)
