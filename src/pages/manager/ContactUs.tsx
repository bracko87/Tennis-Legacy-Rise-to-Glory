import { FormEvent, useState } from 'react'
import { CheckCircle2, LifeBuoy, Mail, MessageSquare, Send } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'
import { useLocalization } from '../../i18n/LocalizationProvider'
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
  const { t } = useTranslation()
  const { formatNumber } = useLocalization()
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
      setError(t('supportPages.contact.subjectError'))
      return
    }
    if (cleanMessage.length < 10) {
      setError(t('supportPages.contact.messageError'))
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
      setError(submitError?.message ?? t('supportPages.contact.submitError'))
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
    <GameLayout title={t('supportPages.contact.title')} subtitle={t('supportPages.contact.subtitle')}>
      <div className="tlg-contact-page">
        <section className="tlg-contact-hero">
          <div>
            <span>{t('supportPages.contact.support')}</span>
            <h2>{t('supportPages.contact.heading')}</h2>
            <p>
              {t('supportPages.contact.intro')}
            </p>
          </div>
          <div className="tlg-contact-hero-actions">
            <a href={DISCORD_INVITE} target="_blank" rel="noreferrer"><MessageSquare size={16} /> {t('supportPages.contact.askDiscord')}</a>
          </div>
        </section>

        <section className="tlg-contact-panel">
          <header className="tlg-contact-panel-head">
            <div>
              <span>{t('supportPages.contact.form')}</span>
              <h3>{t('supportPages.contact.sendRequest')}</h3>
              <p>{t('supportPages.contact.formIntro')}</p>
            </div>
            <Mail size={20} />
          </header>

          {referenceId ? (
            <div className="tlg-contact-success" role="status">
              <CheckCircle2 size={24} />
              <div>
                <strong>{t('supportPages.contact.submitted')}</strong>
                <p>{t('supportPages.contact.reference')}: <code>{referenceId}</code></p>
                <p>{t('supportPages.contact.keepReference')}</p>
                <button type="button" onClick={() => setReferenceId(null)}>{t('supportPages.contact.another')}</button>
              </div>
            </div>
          ) : (
            <form className="tlg-contact-form" onSubmit={handleSubmit}>
              <div className="tlg-contact-identity-grid">
                <label>
                  <span>{t('supportPages.contact.email')}</span>
                  <input value={user?.email ?? ''} readOnly />
                </label>
                <label>
                  <span>{t('supportPages.contact.player')}</span>
                  <input value={playerName} readOnly />
                </label>
                <label>
                  <span>{t('supportPages.contact.world')}</span>
                  <input value={player?.world ?? '—'} readOnly />
                </label>
                <label>
                  <span>{t('supportPages.contact.country')}</span>
                  <input value={player?.country_code ?? '—'} readOnly />
                </label>
              </div>

              <div className="tlg-contact-fields">
                <label>
                  <span>{t('supportPages.contact.category')}</span>
                  <select value={category} onChange={(event) => setCategory(event.target.value as ContactCategory)}>
                    {categories.map((item) => <option key={item} value={item}>{t(`supportPages.contact.categories.${item}`)}</option>)}
                  </select>
                </label>

                <label>
                  <span>{t('supportPages.contact.subject')}</span>
                  <input
                    value={subject}
                    onChange={(event) => { setSubject(event.target.value); setError(null) }}
                    maxLength={160}
                    placeholder={t('supportPages.contact.subjectPlaceholder')}
                    required
                  />
                </label>

                <label className="tlg-contact-message-field">
                  <span>{t('supportPages.contact.message')}</span>
                  <textarea
                    value={message}
                    onChange={(event) => { setMessage(event.target.value); setError(null) }}
                    maxLength={5000}
                    rows={9}
                    placeholder={t('supportPages.contact.messagePlaceholder')}
                    required
                  />
                  <small>{formatNumber(message.length)} / {formatNumber(5000)}</small>
                </label>
              </div>

              {error && <p className="tlg-contact-error" role="alert">{error}</p>}

              <div className="tlg-contact-submit-row">
                <button type="submit" disabled={busy}>
                  <Send size={16} /> {busy ? t('supportPages.contact.sending') : t('supportPages.contact.send')}
                </button>
                <p>{t('supportPages.contact.supportAddress')}: <strong>{SUPPORT_EMAIL}</strong></p>
              </div>
            </form>
          )}
        </section>

        <section className="tlg-contact-alternative">
          <LifeBuoy size={20} />
          <div>
            <strong>{t('supportPages.contact.communityTitle')}</strong>
            <p>{t('supportPages.contact.communityBody')}</p>
          </div>
          <a href={DISCORD_INVITE} target="_blank" rel="noreferrer">{t('supportPages.contact.joinDiscord')}</a>
        </section>
      </div>
    </GameLayout>
  )
}
