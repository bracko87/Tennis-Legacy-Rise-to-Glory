import { Bell, Languages, SlidersHorizontal } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import GameLayout from '../../components/layout/GameLayout'
import { ENABLED_LOCALES, SUPPORTED_LOCALES, type AppLocale } from '../../i18n'
import { useLocalization } from '../../i18n/LocalizationProvider'
import '../../styles/game-preferences.css'

const LANGUAGE_LABEL_KEYS: Record<AppLocale, string> = {
  en: 'common.english',
  sr: 'settings.serbianLatin',
  de: 'common.german',
  es: 'common.spanish',
  it: 'common.italian',
  fr: 'common.french',
  ru: 'common.russian',
  pt: 'common.portuguese',
}

export default function GamePreferencesPage() {
  const { t } = useTranslation()
  const { locale, setLocale, saving } = useLocalization()
  const [message, setMessage] = useState<{ tone: 'success' | 'error'; text: string } | null>(null)

  async function changeLanguage(next: AppLocale) {
    if (!ENABLED_LOCALES.includes(next) || next === locale || saving) return
    setMessage(null)
    const saved = await setLocale(next)
    setMessage({
      tone: saved ? 'success' : 'error',
      text: saved ? t('settings.languageSaved') : t('settings.languageSaveError'),
    })
  }

  return (
    <GameLayout title={t('settings.title')} subtitle={t('settings.subtitle')}>
      <div className="tlg-preferences-page">
        <header className="tlg-preferences-intro">
          <span>{t('settings.managerSettings')}</span>
          <h2>{t('settings.preferences')}</h2>
          <p>{t('settings.intro')}</p>
        </header>

        <section className="tlg-preferences-section">
          <header className="tlg-preferences-section-head">
            <div>
              <span>{t('settings.languageSection')}</span>
              <h3>{t('settings.languageTitle')}</h3>
              <p>{t('settings.languageDescription')}</p>
            </div>
            <Languages size={21} aria-hidden="true" />
          </header>

          <div className="tlg-language-grid" role="radiogroup" aria-label={t('settings.languageTitle')}>
            {SUPPORTED_LOCALES.map((code) => {
              const enabled = ENABLED_LOCALES.includes(code)
              const active = locale === code
              return (
                <button
                  key={code}
                  type="button"
                  role="radio"
                  aria-checked={active}
                  className={`tlg-language-option ${active ? 'active' : ''} ${enabled ? '' : 'disabled'}`}
                  disabled={!enabled || saving}
                  onClick={() => void changeLanguage(code)}
                >
                  <span>
                    <strong>{t(LANGUAGE_LABEL_KEYS[code])}</strong>
                    <small>{enabled ? t('settings.qaReady') : t('settings.qaPending')}</small>
                  </span>
                  <em>{code.toUpperCase()}</em>
                </button>
              )
            })}
          </div>

          <p className="tlg-language-note">{t('settings.sourceNote')}</p>
          {message && <div className={`tlg-language-message ${message.tone}`}>{message.text}</div>}
        </section>

        <section className="tlg-preferences-section">
          <header className="tlg-preferences-section-head">
            <div>
              <span>{t('settings.notifications')}</span>
              <h3>{t('settings.inGameNotifications')}</h3>
              <p>{t('settings.notificationDescription')}</p>
            </div>
            <Bell size={21} aria-hidden="true" />
          </header>

          <div className="tlg-preferences-empty">
            <span className="tlg-preferences-empty-icon"><SlidersHorizontal size={24} /></span>
            <div>
              <strong>{t('settings.notificationNotConfigured')}</strong>
              <p>{t('settings.notificationPlaceholder')}</p>
            </div>
          </div>
        </section>
      </div>
    </GameLayout>
  )
}
