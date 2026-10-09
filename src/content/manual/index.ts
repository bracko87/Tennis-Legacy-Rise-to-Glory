import type { GameManualDocument, ManualChapter } from './types'
import { manualCoreChapters } from './manual.en.core'
import { manualCompetitionChapters } from './manual.en.competition'
import { manualCareerChapters } from './manual.en.career'
import { manualCoreChaptersSr } from './manual.sr.core'
import { manualCompetitionChaptersSr } from './manual.sr.competition'
import { manualCareerChaptersSr } from './manual.sr.career'

const englishManual: GameManualDocument = {
  meta: {
    title: 'Tennis Legacy: Rise to Glory - Full Game Manual',
    shortTitle: 'Full Game Manual',
    language: 'English',
    locale: 'en',
    version: '1.0',
    updated: '2026-10-09',
    sourceNotice: 'English is the source edition. Future locale files can reuse the same chapter and section identifiers.',
  },
  chapters: [
    ...manualCoreChapters,
    ...manualCompetitionChapters,
    ...manualCareerChapters,
  ],
}

const serbianManual: GameManualDocument = {
  meta: {
    title: 'Tennis Legacy: Rise to Glory - Kompletan priručnik igre',
    shortTitle: 'Kompletan priručnik',
    language: 'Srpski (latinica)',
    locale: 'sr',
    version: '1.0',
    updated: '2026-10-09',
    sourceNotice: 'Srpsko izdanje prati iste identifikatore poglavlja i odeljaka kao engleski izvor i koristi srpsku latinicu.',
  },
  chapters: [
    ...manualCoreChaptersSr,
    ...manualCompetitionChaptersSr,
    ...manualCareerChaptersSr,
  ],
}

const MANUALS: Record<string, GameManualDocument> = {
  en: englishManual,
  sr: serbianManual,
}

export function getGameManual(locale = 'en'): GameManualDocument {
  return MANUALS[locale] ?? MANUALS.en
}

export function getGameManualChapter(locale: string, chapterId: string): ManualChapter | undefined {
  return getGameManual(locale).chapters.find((chapter) => chapter.id === chapterId)
}

export type { GameManualDocument, ManualChapter, ManualSection, ManualLink, ManualTable } from './types'
