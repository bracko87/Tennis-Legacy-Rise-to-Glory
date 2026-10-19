// Real-world tennis headlines are fetched server-side; the client receives
// only source, article title, publication timestamp, and the publisher URL.
// No full third-party article content is republished.
type NewsItem = {
  title: string
  source: string
  published_at: string
  url: string
}

const SOURCES = [
  { name: 'ESPN Tennis', feed: 'https://www.espn.com/espn/rss/tennis/news', domain: 'espn.com' },
  { name: 'ATP Tour', feed: 'https://www.atptour.com/en/media/rss-feed/xml-feed', domain: 'atptour.com' },
  { name: 'The Guardian', feed: 'https://www.theguardian.com/sport/tennis/rss', domain: 'theguardian.com' },
] as const

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'public, max-age=900, s-maxage=900',
}

function xmlText(value: string): string {
  const raw = value.replace(/^<!\[CDATA\[([\s\S]*?)\]\]>$/, '$1').replace(/<[^>]*>/g, '')
  return raw.replace(/&#(x[0-9a-f]+|\d+);|&(amp|lt|gt|quot|apos|nbsp);/gi, (match, number, entity) => {
    if (number) {
      const codepoint = number[0]?.toLowerCase() === 'x'
        ? parseInt(number.slice(1), 16) : parseInt(number, 10)
      return Number.isFinite(codepoint) && codepoint > 0 && codepoint <= 0x10ffff
        ? String.fromCodePoint(codepoint) : ''
    }
    return ({ amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' } as Record<string, string>)[entity?.toLowerCase()] ?? match
  }).trim()
}

function tag(block: string, name: string): string {
  const match = block.match(new RegExp('<' + name + '(?:\\s[^>]*)?>([\\s\\S]*?)<\\/' + name + '>', 'i'))
  return match ? xmlText(match[1]) : ''
}

function parseFeed(xml: string, source: typeof SOURCES[number]): NewsItem[] {
  if (!/<rss\b|<feed\b/i.test(xml)) return []
  const items = xml.match(/<item\b[^>]*>[\s\S]*?<\/item>/gi) ?? []
  const found: NewsItem[] = []
  for (const block of items.slice(0, 25)) {
    const title = tag(block, 'title').slice(0, 240)
    const published = tag(block, 'pubDate') || tag(block, 'dc:date')
    const url = tag(block, 'link')
    const parsedDate = Date.parse(published)
    if (!title || !Number.isFinite(parsedDate) || !url) continue
    try {
      const parsed = new URL(url)
      if (parsed.protocol !== 'https:' || !(parsed.hostname === source.domain || parsed.hostname.endsWith('.' + source.domain))) continue
      found.push({ title, source: source.name, published_at: new Date(parsedDate).toISOString(), url: parsed.toString() })
    } catch {
      // Never return malformed or non-HTTPS links.
    }
  }
  return found
}

async function loadSource(source: typeof SOURCES[number]): Promise<NewsItem[]> {
  try {
    const response = await fetch(source.feed, {
      signal: AbortSignal.timeout(8000),
      headers: { 'Accept': 'application/rss+xml, application/xml, text/xml', 'User-Agent': 'TennisLegacyNews/1.0' },
    })
    if (!response.ok) return []
    const xml = (await response.text()).slice(0, 600_000)
    return parseFeed(xml, source)
  } catch {
    return []
  }
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers })
  if (request.method !== 'GET') return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers })

  const grouped = await Promise.all(SOURCES.map(loadSource))
  const unique = new Map<string, NewsItem>()
  for (const item of grouped.flat()) unique.set(item.url, item)
  const articles = [...unique.values()]
    .sort((a, b) => b.published_at.localeCompare(a.published_at))
    .slice(0, 5)

  return new Response(JSON.stringify({ articles, available: articles.length > 0 }), {
    status: 200,
    headers,
  })
})
