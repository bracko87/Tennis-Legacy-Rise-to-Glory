import { useEffect, useState } from 'react'
import { ExternalLink } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { supabase } from '../../lib/supabase'

type Article = {
  title: string
  source: string
  published_at: string
  url: string
}

export default function RealWorldTennisNews() {
  const { t } = useTranslation()
  const { localeTag } = useLocalization()
  const [articles, setArticles] = useState<Article[]>([])
  const [loading, setLoading] = useState(true)
  const [unavailable, setUnavailable] = useState(false)

  useEffect(() => {
    let active = true
    async function load() {
      try {
        const { data, error } = await supabase.functions.invoke('tennis-world-news', { method: 'GET' })
        if (!active) return
        if (error || !data?.available || !Array.isArray(data.articles)) {
          setUnavailable(true)
          return
        }
        const valid = (data.articles as Article[]).filter((item) => {
          if (!item?.title || !item?.published_at || !item?.source) return false
          try { return new URL(item.url).protocol === 'https:' && Number.isFinite(Date.parse(item.published_at)) }
          catch { return false }
        }).slice(0, 5)
        setArticles(valid)
        setUnavailable(valid.length === 0)
      } catch {
        if (active) setUnavailable(true)
      } finally {
        if (active) setLoading(false)
      }
    }
    void load()
    return () => { active = false }
  }, [])

  return <section className="tlg-overview-world-news">
    <div className="tlg-overview-panel-head">
      <div>
        <span>{t('overviewPage.extra.newsEyebrow')}</span>
        <h3>{t('overviewPage.extra.newsTitle')}</h3>
        <p>{t('overviewPage.extra.newsIntro')}</p>
      </div>
    </div>
    {loading ? <p className="tlg-overview-world-news-state">{t('overviewPage.extra.newsLoading')}</p> :
      unavailable ? <p className="tlg-overview-world-news-state">{t('overviewPage.extra.newsUnavailable')}</p> :
        <div className="tlg-overview-world-news-list">
          {articles.map((item) => <article key={item.url} className="tlg-overview-world-news-item">
            <a href={item.url} target="_blank" rel="noopener noreferrer">
              <strong>{item.title}</strong><ExternalLink size={14} aria-hidden="true" />
            </a>
            <div className="tlg-overview-world-news-meta">
              <span>{item.source}</span>
              <time dateTime={item.published_at}>
                {new Intl.DateTimeFormat(localeTag, { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(item.published_at))}
              </time>
              <span>{t('overviewPage.extra.fullArticle')}</span>
            </div>
          </article>)}
        </div>}
  </section>
}
