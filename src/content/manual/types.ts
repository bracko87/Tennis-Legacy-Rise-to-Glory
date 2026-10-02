export type ManualLink = { label: string; href: string }

export type ManualTable = {
  headers: string[]
  rows: string[][]
}

export type ManualSection = {
  title: string
  paragraphs?: string[]
  bullets?: string[]
  steps?: string[]
  table?: ManualTable
  example?: string
  note?: string
  links?: ManualLink[]
}

export type ManualChapter = {
  id: string
  title: string
  summary: string
  sections: ManualSection[]
  links?: ManualLink[]
}

export type GameManualDocument = {
  meta: {
    title: string
    shortTitle: string
    language: string
    locale: string
    version: string
    updated: string
    sourceNotice: string
  }
  chapters: ManualChapter[]
}
