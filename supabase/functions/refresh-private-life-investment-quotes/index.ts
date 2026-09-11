import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

type Instrument = {
  code: string
  asset_type: 'stock' | 'crypto'
  symbol: string
  provider: 'stooq' | 'yahoo' | 'coingecko'
  provider_key: string
}

type QuoteRow = {
  instrument_code: string
  price: number
  previous_price: number | null
  quote_as_of: string
  fetched_at: string
  source: string
  metadata: Record<string, unknown>
  updated_at: string
}

type YahooPoint = {
  ts: number
  close: number
  high: number | null
  low: number | null
  volume: number | null
}

const browserHeaders = {
  accept: 'application/json,text/plain,*/*',
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36',
}

function finite(value: unknown): number | null {
  const numeric = Number(value)
  return Number.isFinite(numeric) ? numeric : null
}

function percentChange(current: number, base: number | null) {
  if (base === null || base <= 0) return null
  return ((current - base) / base) * 100
}

function pointBack(points: YahooPoint[], sessions: number) {
  if (points.length <= sessions) return points[0]?.close ?? null
  return points[points.length - 1 - sessions]?.close ?? null
}

async function fetchYahooResponse(symbol: string) {
  const path = `/v8/finance/chart/${encodeURIComponent(symbol)}?range=1y&interval=1d&includePrePost=false&events=div%2Csplits`
  let response = await fetch(`https://query1.finance.yahoo.com${path}`, { headers: browserHeaders })
  if (!response.ok) {
    await new Promise((resolve) => setTimeout(resolve, 180))
    response = await fetch(`https://query2.finance.yahoo.com${path}`, { headers: browserHeaders })
  }
  return response
}

async function fetchYahooQuote(instrument: Instrument): Promise<QuoteRow> {
  const response = await fetchYahooResponse(instrument.provider_key)
  if (!response.ok) throw new Error(`${instrument.symbol}: Yahoo HTTP ${response.status}`)
  const payload = await response.json()
  const result = payload?.chart?.result?.[0]
  if (!result) throw new Error(`${instrument.symbol}: empty Yahoo response`)

  const meta = result.meta ?? {}
  const timestamps: unknown[] = Array.isArray(result.timestamp) ? result.timestamp : []
  const quote = result.indicators?.quote?.[0] ?? {}
  const closes: unknown[] = Array.isArray(quote.close) ? quote.close : []
  const highs: unknown[] = Array.isArray(quote.high) ? quote.high : []
  const lows: unknown[] = Array.isArray(quote.low) ? quote.low : []
  const volumes: unknown[] = Array.isArray(quote.volume) ? quote.volume : []

  const points: YahooPoint[] = []
  for (let index = 0; index < timestamps.length; index += 1) {
    const ts = finite(timestamps[index])
    const close = finite(closes[index])
    if (ts === null || close === null || close <= 0) continue
    points.push({
      ts,
      close,
      high: finite(highs[index]),
      low: finite(lows[index]),
      volume: finite(volumes[index]),
    })
  }

  const latestPoint = points[points.length - 1]
  const price = finite(meta.regularMarketPrice) ?? latestPoint?.close ?? null
  if (price === null || price <= 0) throw new Error(`${instrument.symbol}: invalid Yahoo price`)

  const previousClose = finite(meta.previousClose) ?? pointBack(points, 1)
  const highs52 = points.map((point) => point.high).filter((value): value is number => value !== null && value > 0)
  const lows52 = points.map((point) => point.low).filter((value): value is number => value !== null && value > 0)
  const marketTime = finite(meta.regularMarketTime)
  const now = new Date().toISOString()
  const quoteAsOf = marketTime ? new Date(marketTime * 1000).toISOString() : latestPoint ? new Date(latestPoint.ts * 1000).toISOString() : now
  const recentHistory = points.slice(-36).map((point) => ({ t: point.ts, p: Number(point.close.toFixed(4)) }))

  return {
    instrument_code: instrument.code,
    price,
    previous_price: previousClose,
    quote_as_of: quoteAsOf,
    fetched_at: now,
    source: 'yahoo',
    metadata: {
      provider_symbol: instrument.provider_key,
      currency: meta.currency ?? 'USD',
      exchange: meta.fullExchangeName ?? meta.exchangeName ?? null,
      market_state: meta.marketState ?? null,
      previous_close: previousClose,
      change_1d_pct: percentChange(price, previousClose),
      change_1w_pct: percentChange(price, pointBack(points, 5)),
      change_1m_pct: percentChange(price, pointBack(points, 22)),
      change_3m_pct: percentChange(price, pointBack(points, 66)),
      change_1y_pct: percentChange(price, points[0]?.close ?? null),
      high_52w: highs52.length ? Math.max(...highs52) : null,
      low_52w: lows52.length ? Math.min(...lows52) : null,
      volume: latestPoint?.volume ?? null,
      history: recentHistory,
      note: 'Yahoo Finance reference chart quote; exchange and provider delay may apply.',
    },
    updated_at: now,
  }
}

async function fetchCryptoQuotes(instruments: Instrument[], previous: Map<string, number>) {
  const updates: QuoteRow[] = []
  const errors: string[] = []
  if (!instruments.length) return { updates, errors }

  try {
    const ids = instruments.map((item) => item.provider_key).join(',')
    const url = `https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=${encodeURIComponent(ids)}&order=market_cap_desc&per_page=250&page=1&sparkline=true&price_change_percentage=24h%2C7d%2C30d%2C1y`
    const response = await fetch(url, { headers: { accept: 'application/json', 'User-Agent': 'TennisLegacy/1.0' } })
    if (!response.ok) throw new Error(`CoinGecko HTTP ${response.status}`)
    const payload = await response.json()
    const rows = new Map((Array.isArray(payload) ? payload : []).map((row: Record<string, unknown>) => [String(row.id), row]))
    const now = new Date().toISOString()

    for (const instrument of instruments) {
      const row = rows.get(instrument.provider_key) as Record<string, any> | undefined
      const price = finite(row?.current_price)
      if (price === null || price <= 0) {
        errors.push(`${instrument.symbol}: invalid CoinGecko quote`)
        continue
      }
      const change24 = finite(row?.price_change_percentage_24h_in_currency ?? row?.price_change_percentage_24h)
      const derivedPrevious = change24 !== null && change24 > -99.99 ? price / (1 + change24 / 100) : previous.get(instrument.code) ?? null
      const sparkline = Array.isArray(row?.sparkline_in_7d?.price) ? row.sparkline_in_7d.price.filter((value: unknown) => finite(value) !== null).slice(-48).map((value: unknown) => Number(Number(value).toFixed(6))) : []
      updates.push({
        instrument_code: instrument.code,
        price,
        previous_price: derivedPrevious,
        quote_as_of: row?.last_updated ? new Date(String(row.last_updated)).toISOString() : now,
        fetched_at: now,
        source: 'coingecko',
        metadata: {
          provider_id: instrument.provider_key,
          market_cap: finite(row?.market_cap),
          market_cap_rank: finite(row?.market_cap_rank),
          total_volume: finite(row?.total_volume),
          high_24h: finite(row?.high_24h),
          low_24h: finite(row?.low_24h),
          change_1d_pct: change24,
          change_1w_pct: finite(row?.price_change_percentage_7d_in_currency),
          change_1m_pct: finite(row?.price_change_percentage_30d_in_currency),
          change_1y_pct: finite(row?.price_change_percentage_1y_in_currency),
          history: sparkline,
          note: 'CoinGecko external market reference price.',
        },
        updated_at: now,
      })
    }
  } catch (error) {
    errors.push(`Crypto refresh: ${error instanceof Error ? error.message : String(error)}`)
  }

  return { updates, errors }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return Response.json({ error: 'POST required' }, { status: 405, headers: corsHeaders })

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } })
    const authorization = req.headers.get('Authorization') ?? ''
    const token = authorization.replace(/^Bearer\s+/i, '').trim()
    if (!token) return Response.json({ error: 'Authentication required' }, { status: 401, headers: corsHeaders })

    const { data: userData, error: userError } = await admin.auth.getUser(token)
    const userId = userData?.user?.id
    if (userError || !userId) return Response.json({ error: 'Authentication required' }, { status: 401, headers: corsHeaders })

    const { data: membership, error: membershipError } = await admin
      .from('premium_memberships')
      .select('plan_code,status,current_period_end')
      .eq('user_id', userId)
      .maybeSingle()
    if (membershipError) throw membershipError
    const periodActive = !membership?.current_period_end || new Date(membership.current_period_end).getTime() > Date.now()
    if (membership?.plan_code !== 'premium' || membership?.status !== 'active' || !periodActive) {
      return Response.json({ error: 'Premium membership required' }, { status: 403, headers: corsHeaders })
    }

    const { data: instrumentsData, error: instrumentsError } = await admin
      .from('private_life_investment_instruments')
      .select('code,asset_type,symbol,provider,provider_key')
      .eq('active', true)
      .order('sort_order')
    if (instrumentsError) throw instrumentsError

    const instruments = (instrumentsData ?? []) as Instrument[]
    const { data: existingQuotes, error: quoteReadError } = await admin
      .from('private_life_investment_quotes')
      .select('instrument_code,price')
    if (quoteReadError) throw quoteReadError
    const previous = new Map((existingQuotes ?? []).map((row) => [row.instrument_code, Number(row.price)]))

    const updates: QuoteRow[] = []
    const errors: string[] = []

    const crypto = instruments.filter((item) => item.asset_type === 'crypto')
    const cryptoResult = await fetchCryptoQuotes(crypto, previous)
    updates.push(...cryptoResult.updates)
    errors.push(...cryptoResult.errors)

    const stocks = instruments.filter((item) => item.asset_type === 'stock')
    const batchSize = 8
    for (let offset = 0; offset < stocks.length; offset += batchSize) {
      const batch = stocks.slice(offset, offset + batchSize)
      const results = await Promise.allSettled(batch.map((instrument) => fetchYahooQuote(instrument)))
      results.forEach((result, index) => {
        if (result.status === 'fulfilled') updates.push(result.value)
        else errors.push(`${batch[index]?.symbol ?? 'stock'}: ${result.reason instanceof Error ? result.reason.message : String(result.reason)}`)
      })
      if (offset + batchSize < stocks.length) await new Promise((resolve) => setTimeout(resolve, 120))
    }

    if (updates.length) {
      const { error: upsertError } = await admin.from('private_life_investment_quotes').upsert(updates, { onConflict: 'instrument_code' })
      if (upsertError) throw upsertError
    }

    return Response.json({
      ok: updates.length > 0,
      updated: updates.length,
      expected: instruments.length,
      stock_updated: updates.filter((row) => row.source === 'yahoo').length,
      crypto_updated: updates.filter((row) => row.source === 'coingecko').length,
      errors,
      refreshed_at: new Date().toISOString(),
    }, { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (error) {
    return Response.json({ error: error instanceof Error ? error.message : String(error) }, { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
