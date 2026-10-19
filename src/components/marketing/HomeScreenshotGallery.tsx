import { useCallback, useEffect, useState } from 'react'
import { ChevronLeft, ChevronRight, Images, X } from 'lucide-react'
import { supabase } from '../../lib/supabase'
import { useLocalization } from '../../i18n/LocalizationProvider'
import '../../styles/home-screenshot-gallery.css'

// These twenty files were verified in the existing Admin/Branding storage folder.
// They are signed on request; never embed storage bearer tokens into public source.
const SCREENSHOTS = Array.from({ length: 20 }, (_, index) => ({
  number: index + 1,
  path: `Branding/tennis ${String(index + 1).padStart(3, '0')}.png`,
}))
const PAGE_SIZE = 6
const I18N: Record<string, { prev: string; next: string; close: string; view: string; unavailable: string; retry: string; loading: string; image: string }> = {
  en: { prev: 'Previous', next: 'Next', close: 'Close', view: 'View screenshot', unavailable: 'Screenshots cannot be loaded right now.', retry: 'Try again', loading: 'Loading screenshots…', image: 'Screenshot' },
  sr: { prev: 'Prethodno', next: 'Sledeće', close: 'Zatvori', view: 'Otvori sliku', unavailable: 'Slike trenutno nisu dostupne.', retry: 'Pokušaj ponovo', loading: 'Učitavanje slika…', image: 'Slika' },
  de: { prev: 'Zurück', next: 'Weiter', close: 'Schließen', view: 'Screenshot ansehen', unavailable: 'Screenshots können derzeit nicht geladen werden.', retry: 'Erneut versuchen', loading: 'Screenshots werden geladen…', image: 'Screenshot' },
  es: { prev: 'Anterior', next: 'Siguiente', close: 'Cerrar', view: 'Ver captura', unavailable: 'No se pueden cargar las capturas ahora.', retry: 'Reintentar', loading: 'Cargando capturas…', image: 'Captura' },
  it: { prev: 'Precedente', next: 'Successiva', close: 'Chiudi', view: 'Apri schermata', unavailable: 'Le schermate non sono disponibili al momento.', retry: 'Riprova', loading: 'Caricamento schermate…', image: 'Schermata' },
  fr: { prev: 'Précédent', next: 'Suivant', close: 'Fermer', view: 'Voir la capture', unavailable: 'Les captures ne sont pas disponibles pour le moment.', retry: 'Réessayer', loading: 'Chargement des captures…', image: 'Capture' },
  ru: { prev: 'Назад', next: 'Вперёд', close: 'Закрыть', view: 'Посмотреть скриншот', unavailable: 'Скриншоты сейчас недоступны.', retry: 'Повторить', loading: 'Загрузка скриншотов…', image: 'Скриншот' },
  pt: { prev: 'Anterior', next: 'Seguinte', close: 'Fechar', view: 'Ver imagem', unavailable: 'As imagens não estão disponíveis neste momento.', retry: 'Tentar novamente', loading: 'A carregar imagens…', image: 'Imagem' },
}
type Props = { eyebrow: string; title: string; description: string }

export default function HomeScreenshotGallery({ eyebrow, title, description }: Props) {
  const { locale } = useLocalization()
  const labels = I18N[locale] ?? I18N.en
  const [sources, setSources] = useState<Record<string, string>>({})
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(0)
  const [selected, setSelected] = useState<number | null>(null)
  const [retryKey, setRetryKey] = useState(0)
  const totalPages = Math.ceil(SCREENSHOTS.length / PAGE_SIZE)

  const load = useCallback(async (isActive: () => boolean) => {
    setLoading(true)
    const { data, error } = await supabase.storage.from('Admin')
      .createSignedUrls(SCREENSHOTS.map(({ path }) => path), 3600)
    if (!isActive()) return
    const next: Record<string, string> = {}
    if (!error && data) {
      for (let i = 0; i < data.length; i += 1) {
        if (data[i]?.signedUrl && !data[i]?.error) next[SCREENSHOTS[i].path] = data[i].signedUrl
      }
    }
    setSources(next)
    setLoading(false)
  }, [])

  useEffect(() => {
    let active = true
    const reload = () => { void load(() => active) }
    reload()
    // Storage signed links are short-lived. Refresh without recreating the gallery.
    const interval = window.setInterval(reload, 45 * 60 * 1000)
    return () => { active = false; window.clearInterval(interval) }
  }, [load, retryKey])

  useEffect(() => {
    if (selected === null) return
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setSelected(null)
      if (event.key === 'ArrowLeft') setSelected((current) => current === null ? null : (current + 19) % 20)
      if (event.key === 'ArrowRight') setSelected((current) => current === null ? null : (current + 1) % 20)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [selected])

  const available = SCREENSHOTS.filter(({ path }) => Boolean(sources[path]))
  const shown = SCREENSHOTS.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE)

  return (
    <section className="tlg-home-screenshots-section" id="game-screenshots" aria-labelledby="tlg-home-screenshots-title">
      <div className="tlg-section">
        <div className="tlg-home-screenshots-top">
          <div className="tlg-home-screenshots-heading">
            <span className="tlg-section-eyebrow">{eyebrow}</span>
            <h2 id="tlg-home-screenshots-title">{title}</h2>
            <p>{description}</p>
          </div>
          <div className="tlg-home-screenshots-nav">
            <span className="tlg-home-screenshots-count">{SCREENSHOTS.length} {labels.image.toLowerCase()}s</span>
            <button type="button" onClick={() => setPage((current) => (current + totalPages - 1) % totalPages)} aria-label={labels.prev}><ChevronLeft size={19} /></button>
            <button type="button" onClick={() => setPage((current) => (current + 1) % totalPages)} aria-label={labels.next}><ChevronRight size={19} /></button>
          </div>
        </div>

        {loading && available.length === 0 ? <p className="tlg-home-gallery-state">{labels.loading}</p> :
          available.length === 0 ? (
            <div className="tlg-home-gallery-state"><Images size={28} /><span>{labels.unavailable}</span><button type="button" onClick={() => setRetryKey((x) => x + 1)}>{labels.retry}</button></div>
          ) : (
            <>
              <div className="tlg-home-screenshots-grid">
                {shown.map(({ number, path }) => (
                  <button key={path} type="button" className="tlg-home-screenshot-card"
                    onClick={() => setSelected(number - 1)} disabled={!sources[path]} aria-label={`${labels.view} ${number}`}>
                    <span className="tlg-home-screenshot-frame">
                      {sources[path] ? <img src={sources[path]} alt={`${title} — ${labels.image} ${number}`} loading="lazy" /> : <Images aria-hidden="true" size={26} />}
                    </span>
                    <span className="tlg-home-screenshot-caption"><span>{String(number).padStart(2, '0')}</span><strong>{labels.image} {number}</strong></span>
                  </button>
                ))}
              </div>
              <div className="tlg-home-screenshots-pages" aria-label={title}>
                {Array.from({ length: totalPages }, (_, index) =>
                  <button key={index} type="button" className={page === index ? 'active' : ''}
                    onClick={() => setPage(index)} aria-label={`${labels.image} ${index * PAGE_SIZE + 1}–${Math.min((index + 1) * PAGE_SIZE, SCREENSHOTS.length)}`} aria-current={page === index ? 'page' : undefined} />)}
              </div>
            </>
          )}
      </div>

      {selected !== null && sources[SCREENSHOTS[selected].path] && (
        <div className="tlg-home-gallery-lightbox" role="dialog" aria-modal="true" aria-label={`${labels.image} ${selected + 1}`}
          onClick={(event) => { if (event.currentTarget === event.target) setSelected(null) }}>
          <button className="tlg-home-gallery-close" type="button" onClick={() => setSelected(null)} aria-label={labels.close}><X size={24} /></button>
          <div className="tlg-home-gallery-lightbox-content">
            <img src={sources[SCREENSHOTS[selected].path]} alt={`${title} — ${labels.image} ${selected + 1}`} />
            <div className="tlg-home-gallery-lightbox-controls">
              <button type="button" onClick={() => setSelected((selected + 19) % 20)} aria-label={labels.prev}><ChevronLeft size={21} /></button>
              <span>{selected + 1} / {SCREENSHOTS.length}</span>
              <button type="button" onClick={() => setSelected((selected + 1) % 20)} aria-label={labels.next}><ChevronRight size={21} /></button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
