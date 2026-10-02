import { useEffect, useMemo, useRef, useState } from 'react'
import { ChevronLeft, ChevronRight, Download, Search, X } from 'lucide-react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router'

import GameLayout from '../../components/layout/GameLayout'
import { getGameManual, type ManualChapter, type ManualSection } from '../../content/manual'
import { downloadGameManualPdf } from '../../lib/manualPdf'
import '../../styles/game-manual.css'


function sectionText(section: ManualSection) {
  const tableText = section.table
    ? [
        ...section.table.headers,
        ...section.table.rows.flat(),
      ].join(' ')
    : ''

  return [
    section.title,
    ...(section.paragraphs ?? []),
    ...(section.bullets ?? []),
    ...(section.steps ?? []),
    section.example ?? '',
    section.note ?? '',
    tableText,
  ].join(' ')
}

function chapterText(chapter: ManualChapter) {
  return [
    chapter.title,
    chapter.summary,
    ...chapter.sections.map(sectionText),
  ].join(' ').toLowerCase()
}

function snippetFor(chapter: ManualChapter, query: string) {
  const lower = query.toLowerCase()
  const matchingSection = chapter.sections.find((section) => sectionText(section).toLowerCase().includes(lower))
  const source = matchingSection
    ? [
        ...(matchingSection.paragraphs ?? []),
        ...(matchingSection.bullets ?? []),
        ...(matchingSection.steps ?? []),
      ].join(' ')
    : chapter.summary

  if (!source) return chapter.summary
  const index = source.toLowerCase().indexOf(lower)
  if (index < 0) return source.slice(0, 210)
  const start = Math.max(0, index - 70)
  const end = Math.min(source.length, index + query.length + 130)
  return `${start > 0 ? '…' : ''}${source.slice(start, end)}${end < source.length ? '…' : ''}`
}

export default function GameManualPage() {
  const activeLocale = (document.documentElement.lang || navigator.language || 'en').split('-')[0].toLowerCase()
  const manual = getGameManual(activeLocale)
  const navigate = useNavigate()
  const { chapterId } = useParams()
  const [searchParams, setSearchParams] = useSearchParams()
  const pdfAutoDownloadHandled = useRef(false)
  const [query, setQuery] = useState('')

  const currentIndex = Math.max(
    0,
    manual.chapters.findIndex((chapter) => chapter.id === chapterId),
  )
  const current = manual.chapters[currentIndex]
  const previous = currentIndex > 0 ? manual.chapters[currentIndex - 1] : null
  const next = currentIndex < manual.chapters.length - 1 ? manual.chapters[currentIndex + 1] : null

  const searchResults = useMemo(() => {
    const normalized = query.trim().toLowerCase()
    if (!normalized) return []

    return manual.chapters
      .filter((chapter) => chapterText(chapter).includes(normalized))
      .map((chapter) => ({
        chapter,
        snippet: snippetFor(chapter, normalized),
      }))
  }, [manual.chapters, query])

  useEffect(() => {
    if (searchParams.get('download') !== 'pdf' || pdfAutoDownloadHandled.current) return

    pdfAutoDownloadHandled.current = true
    downloadGameManualPdf(manual)

    const next = new URLSearchParams(searchParams)
    next.delete('download')
    setSearchParams(next, { replace: true })
  }, [manual, searchParams, setSearchParams])

  const openChapter = (id: string) => {
    setQuery('')
    navigate(`/game/manual/${id}`)
    window.scrollTo({ top: 0, behavior: 'auto' })
  }

  return (
    <GameLayout title="Full Game Manual" subtitle="Complete Tennis Legacy gameplay reference">
      <div className="tlg-manual-page">
        <section className="tlg-manual-hero">
          <div>
            <span>OFFICIAL IN-GAME REFERENCE</span>
            <h2>{manual.meta.title}</h2>
            <p>
              {manual.chapters.length} chapters covering the implemented career from player creation through
              training, tournaments, rankings, equipment, finance, health, community and long-term progression.
            </p>
            <small>
              English source edition · Version {manual.meta.version} · Updated {manual.meta.updated}
            </small>
          </div>
          <div className="tlg-manual-hero-actions">
            <Link to="/game/help">Back to Help Center</Link>
            <button className="primary" type="button" onClick={() => downloadGameManualPdf(manual)}>
              <Download size={15} aria-hidden="true" />
              Download PDF
            </button>
          </div>
        </section>

        <section className="tlg-manual-search-panel">
          <div className="tlg-manual-search">
            <Search size={17} aria-hidden="true" />
            <input
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search the full manual…"
              aria-label="Search the full game manual"
            />
            {query && (
              <button type="button" onClick={() => setQuery('')} aria-label="Clear manual search">
                <X size={15} />
              </button>
            )}
          </div>
          <span>{query.trim() ? `${searchResults.length} matching chapter${searchResults.length === 1 ? '' : 's'}` : 'Search rules, pages, systems and gameplay processes'}</span>
        </section>

        {query.trim() ? (
          <section className="tlg-manual-search-results">
            <header>
              <span>SEARCH RESULTS</span>
              <h3>Matches for “{query.trim()}”</h3>
            </header>
            {searchResults.length === 0 ? (
              <div className="tlg-manual-empty">
                <strong>No manual chapter matched this search.</strong>
                <p>Try a page name such as Training, Rankings, Finance, Equipment, Staff, Health or Tournament.</p>
              </div>
            ) : (
              <div className="tlg-manual-result-grid">
                {searchResults.map(({ chapter, snippet }) => (
                  <button type="button" key={chapter.id} onClick={() => openChapter(chapter.id)}>
                    <span>Chapter {manual.chapters.findIndex((item) => item.id === chapter.id) + 1}</span>
                    <strong>{chapter.title}</strong>
                    <p>{snippet}</p>
                  </button>
                ))}
              </div>
            )}
          </section>
        ) : (
          <div className="tlg-manual-layout">
            <aside className="tlg-manual-toc" aria-label="Manual table of contents">
              <div className="tlg-manual-toc-head">
                <span>TABLE OF CONTENTS</span>
                <strong>{manual.chapters.length} chapters</strong>
              </div>
              <nav>
                {manual.chapters.map((chapter, index) => (
                  <button
                    type="button"
                    key={chapter.id}
                    className={chapter.id === current.id ? 'active' : ''}
                    onClick={() => openChapter(chapter.id)}
                  >
                    <span>{String(index + 1).padStart(2, '0')}</span>
                    <strong>{chapter.title}</strong>
                  </button>
                ))}
              </nav>
            </aside>

            <article className="tlg-manual-reader">
              <header className="tlg-manual-chapter-head">
                <span>CHAPTER {currentIndex + 1} OF {manual.chapters.length}</span>
                <h1>{current.title}</h1>
                <p>{current.summary}</p>
              </header>

              <div className="tlg-manual-chapter-body">
                {current.sections.map((section, sectionIndex) => (
                  <section className="tlg-manual-section" key={`${current.id}-${sectionIndex}`}>
                    <h2>{section.title}</h2>

                    {section.paragraphs?.map((paragraph, index) => (
                      <p key={index}>{paragraph}</p>
                    ))}

                    {section.bullets && (
                      <ul>
                        {section.bullets.map((item, index) => <li key={index}>{item}</li>)}
                      </ul>
                    )}

                    {section.steps && (
                      <ol>
                        {section.steps.map((item, index) => <li key={index}>{item}</li>)}
                      </ol>
                    )}

                    {section.table && (
                      <div className="tlg-manual-table-wrap">
                        <table>
                          <thead>
                            <tr>{section.table.headers.map((header) => <th key={header}>{header}</th>)}</tr>
                          </thead>
                          <tbody>
                            {section.table.rows.map((row, rowIndex) => (
                              <tr key={rowIndex}>
                                {row.map((cell, cellIndex) => <td key={cellIndex}>{cell}</td>)}
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}

                    {section.example && (
                      <div className="tlg-manual-callout example">
                        <strong>Example</strong>
                        <p>{section.example}</p>
                      </div>
                    )}

                    {section.note && (
                      <div className="tlg-manual-callout note">
                        <strong>Important</strong>
                        <p>{section.note}</p>
                      </div>
                    )}

                    {section.links && section.links.length > 0 && (
                      <div className="tlg-manual-links">
                        {section.links.map((link) => (
                          <Link key={link.href + link.label} to={link.href}>{link.label}</Link>
                        ))}
                      </div>
                    )}
                  </section>
                ))}
              </div>

              <footer className="tlg-manual-chapter-nav">
                <div>
                  {previous ? (
                    <button type="button" onClick={() => openChapter(previous.id)}>
                      <ChevronLeft size={15} />
                      <span><small>Previous chapter</small>{previous.title}</span>
                    </button>
                  ) : <span />}
                </div>
                <div>
                  {next ? (
                    <button type="button" onClick={() => openChapter(next.id)}>
                      <span><small>Next chapter</small>{next.title}</span>
                      <ChevronRight size={15} />
                    </button>
                  ) : (
                    <Link to="/game/help">Return to Help Center</Link>
                  )}
                </div>
              </footer>
            </article>
          </div>
        )}

        <section className="tlg-manual-source-note">
          <strong>Localization-ready manual architecture</strong>
          <p>{manual.meta.sourceNotice} English is the current source edition.</p>
        </section>
      </div>
    </GameLayout>
  )
}
