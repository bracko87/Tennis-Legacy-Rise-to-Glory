import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'

import en from './locales/en'
import sr from './locales/sr'
import de from './locales/de'
import es from './locales/es'
import it from './locales/it'
import fr from './locales/fr'
import ru from './locales/ru'
import pt from './locales/pt'

export const SUPPORTED_LOCALES = ['en', 'sr', 'de', 'es', 'it', 'fr', 'ru', 'pt'] as const
export type AppLocale = typeof SUPPORTED_LOCALES[number]

export const ENABLED_LOCALES: readonly AppLocale[] = ['en', 'sr', 'de', 'es', 'it', 'pt']

export const LOCALE_TAGS: Record<AppLocale, string> = {
  en: 'en-US',
  sr: 'sr-Latn-RS',
  de: 'de-DE',
  es: 'es-ES',
  it: 'it-IT',
  fr: 'fr-FR',
  ru: 'ru-RU',
  pt: 'pt-BR',
}

export function normalizeAppLocale(value?: string | null): AppLocale {
  const normalized = (value || 'en').trim().toLowerCase().split('-')[0]
  return (SUPPORTED_LOCALES as readonly string[]).includes(normalized)
    ? normalized as AppLocale
    : 'en'
}

void i18n
  .use(initReactI18next)
  .init({
    resources: {
      en: { translation: en },
      sr: { translation: sr },
      de: { translation: de },
      es: { translation: es },
      it: { translation: it },
      fr: { translation: fr },
      ru: { translation: ru },
      pt: { translation: pt },
    },
    lng: normalizeAppLocale(
      typeof window !== 'undefined'
        ? window.localStorage.getItem('tlg:locale') || 'en'
        : 'en',
    ),
    fallbackLng: 'en',
    supportedLngs: [...SUPPORTED_LOCALES],
    nonExplicitSupportedLngs: true,
    load: 'languageOnly',
    returnNull: false,
    interpolation: { escapeValue: false },
  })

export default i18n
