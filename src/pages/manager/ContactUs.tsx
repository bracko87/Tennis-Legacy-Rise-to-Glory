import { FormEvent, useState } from 'react'
import { CheckCircle2, LifeBuoy, Mail, MessageSquare, Send } from 'lucide-react'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/contact-us.css'

const DISCORD_INVITE = 'https://discord.gg/RBBtXgZey2'
const SUPPORT_EMAIL = 'contact@tennislegacygame.com'

const categories = [
  'Account',
  'Technical issue',
  'Bug report',
  'Billing / purchase',
  'Feedback',
  'Other',
] as const

type ContactCategory = (typeof categories)[number]

export default function ContactUsPage() {
  const { player, user } = useAuth()
  const [category, setCategory] = useState<ContactCategory>('Technical issue')
  const [subject, setSubject] = useState('')
  const [message, setMessage] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [referenceId, setReferenceId] = useState<string | null>(null)

  const playerName = player ? `${player.first_name} ${player.last_name}`.trim() : '—'

  async function submitNetlifyCopy(requestId: string) {
    const payload = new URLSearchParams()
    payload.set('form-name', 'tennis-legacy-contact')
    payload.set('request_id', requestId)
    payload.set('support_destination', SUPPORT_EMAIL)
    payload.set('account_email', user?.email ?? '')
    payload.set('player_name', playerName)
    payload.set('world', player?.world ?? '')
    payload.set('country_code', player?.country_code ?? '')
    payload.set('category', category)
    payload.set('subject', subject.trim())
    payload.set('message', message.trim())
    payload.set('page_url', window.location.href)

    try {
      await fetch('/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: payload.toString(),
      })
    } catch {
      // The Supabase support request is already safely stored. Netlify forwarding is best-effort.
    }
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (busy) return

    const cleanSubject = subject.trim()
    const cleanMessage = message.trim()

    if (cleanSubject.length < 3) {
      setError('Please enter a subject with at least 3 characters.')
      return
    }
    if (cleanMessage.length < 10) {
      setError('Please describe the issue in at least 10 characters.')
      return
    }

    setBusy(true)
    setError(null)
    setReferenceId(null)

    const { data, error: submitError } = await supabase.rpc('submit_contact_request_v1', {
      p_category: category,
      p_subject: cleanSubject,
      p_message: cleanMessage,
      p_page_url: window.location.href,
    })

    if (submitError || !data) {
      setError(submitError?.message ?? 'Your support request could not be submitted. Please try again.')
      setBusy(false)
      return
    }

    const requestId = String(data)
    await submitNetlifyCopy(requestId)
    setReferenceId(requestId)
    setSubject('')
    setMessage('')
    setBusy(false)
  }

  return (
    <GameLayout title="Contact Us" subtitle="Direct Tennis Legacy support">
      <div className="tlg-contact-page">
        <section className="tlg-contact-hero">
          <div>
            <span>SUPPORT</span>
            <h2>Contact Tennis Legacy</h2>
            <p>
              Send a support request directly from the game. Your account and player details are attached automatically so we can identify the correct career faster.
            </p>
          </div>
          <div className="tlg-contact-hero-actions">
            <a href={DISCORD_INVITE} target="_blank" rel="noreferrer"><MessageSquare size={16} /> Ask on Discord</a>
          </div>
        </section>

        <section className="tlg-contact-panel">
          <header className="tlg-contact-panel-head">
            <div>
              <span>CONTACT FORM</span>
              <h3>Send a support request</h3>
              <p>Messages are registered securely with Tennis Legacy support. Please include enough detail for us to reproduce or understand the issue.</p>
            </div>
            <Mail size={20} />
          </header>

          {referenceId ? (
            <div className="tlg-contact-success" role="status">
              <CheckCircle2 size={24} />
              <div>
                <strong>Your support request was submitted.</strong>
                <p>Reference: <code>{referenceId}</code></p>
                <p>Keep this reference if you need to follow up with us.</p>
                <button type="button" onClick={() => setReferenceId(null)}>Send another request</button>
              </div>
            </div>
          ) : (
            <form className="tlg-contact-form" onSubmit={handleSubmit}>
              <div className="tlg-contact-identity-grid">
                <label>
                  <span>Account email</span>
                  <input value={user?.email ?? ''} readOnly />
                </label>
                <label>
                  <span>Player</span>
                  <input value={playerName} readOnly />
                </label>
                <label>
                  <span>Competition world</span>
                  <input value={player?.world ?? '—'} readOnly />
                </label>
                <label>
                  <span>Country</span>
                  <input value={player?.country_code ?? '—'} readOnly />
                </label>
              </div>

              <div className="tlg-contact-fields">
                <label>
                  <span>Category</span>
                  <select value={category} onChange={(event) => setCategory(event.target.value as ContactCategory)}>
                    {categories.map((item) => <option key={item} value={item}>{item}</option>)}
                  </select>
                </label>

                <label>
                  <span>Subject</span>
                  <input
                    value={subject}
                    onChange={(event) => { setSubject(event.target.value); setError(null) }}
                    maxLength={160}
                    placeholder="Short summary of your question or problem"
                    required
                  />
                </label>

                <label className="tlg-contact-message-field">
                  <span>Message</span>
                  <textarea
                    value={message}
                    onChange={(event) => { setMessage(event.target.value); setError(null) }}
                    maxLength={5000}
                    rows={9}
                    placeholder="Describe what happened, what you expected, and any steps needed to reproduce the problem."
                    required
                  />
                  <small>{message.length.toLocaleString()} / 5,000</small>
                </label>
              </div>

              {error && <p className="tlg-contact-error" role="alert">{error}</p>}

              <div className="tlg-contact-submit-row">
                <button type="submit" disabled={busy}>
                  <Send size={16} /> {busy ? 'Sending…' : 'Send to Tennis Legacy Support'}
                </button>
                <p>Support address: <strong>{SUPPORT_EMAIL}</strong></p>
              </div>
            </form>
          )}
        </section>

        <section className="tlg-contact-alternative">
          <LifeBuoy size={20} />
          <div>
            <strong>Need community help instead?</strong>
            <p>For gameplay questions and community discussion, the Tennis Legacy Discord is usually the fastest place to ask other players.</p>
          </div>
          <a href={DISCORD_INVITE} target="_blank" rel="noreferrer">Join Discord</a>
        </section>
      </div>
    </GameLayout>
  )
}
