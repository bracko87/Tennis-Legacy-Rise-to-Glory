import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'

import en from './locales/en'
import sr from './locales/sr'
import de from './locales/de'
import es from './locales/es'
import it from './locales/it'

export const SUPPORTED_LOCALES = ['en', 'sr', 'de', 'es', 'it', 'fr', 'ru', 'pt'] as const
export type AppLocale = typeof SUPPORTED_LOCALES[number]

export const ENABLED_LOCALES: readonly AppLocale[] = ['en', 'sr', 'de', 'es', 'it']

export const LOCALE_TAGS: Record<AppLocale, string> = {
  en: 'en-US',
  sr: 'sr-Latn-RS',
  de: 'de-DE',
  es: 'es-ES',
  it: 'it-IT',
  fr: 'fr-FR',
  ru: 'ru-RU',
  pt: 'pt-PT',
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
