import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

type Instrument = {
  code: string
  asset_type: 'stock' | 'crypto'
  symbol: string
  provider: 'stooq' | 'coingecko'
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

function csvFields(line: string) {
  return line.split(',').map((value) => value.trim().replace(/^"|"$/g, ''))
}

async function fetchStooqQuote(instrument: Instrument, previousPrice: number | null): Promise<QuoteRow> {
  const url = `https://stooq.com/q/l/?s=${encodeURIComponent(instrument.provider_key)}&f=sd2t2c&h&e=csv`
  const response = await fetch(url, { headers: { 'User-Agent': 'TennisLegacy/1.0' } })
  if (!response.ok) throw new Error(`${instrument.symbol}: Stooq HTTP ${response.status}`)
  const text = await response.text()
  const lines = text.trim().split(/\r?\n/).filter(Boolean)
  if (lines.length < 2) throw new Error(`${instrument.symbol}: empty Stooq response`)
  const headers = csvFields(lines[0]).map((value) => value.toLowerCase())
  const values = csvFields(lines[1])
  const closeIndex = headers.indexOf('close')
  const dateIndex = headers.indexOf('date')
  const timeIndex = headers.indexOf('time')
  const rawPrice = closeIndex >= 0 ? values[closeIndex] : values[values.length - 1]
  const price = Number(rawPrice)
  if (!Number.isFinite(price) || price <= 0) throw new Error(`${instrument.symbol}: invalid Stooq price ${rawPrice}`)
  const now = new Date().toISOString()
  return {
    instrument_code: instrument.code,
    price,
    previous_price: previousPrice,
    quote_as_of: now,
    fetched_at: now,
    source: 'stooq',
    metadata: {
      provider_symbol: instrument.provider_key,
      provider_date: dateIndex >= 0 ? values[dateIndex] : null,
      provider_time: timeIndex >= 0 ? values[timeIndex] : null,
      note: 'Latest market quote supplied by Stooq; exchange delay may apply.',
    },
    updated_at: now,
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return Response.json({ error: 'POST required' }, { status: 405, headers: corsHeaders })

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } })

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
    if (crypto.length) {
      const ids = crypto.map((item) => item.provider_key).join(',')
      try {
        const url = `https://api.coingecko.com/api/v3/simple/price?ids=${encodeURIComponent(ids)}&vs_currencies=usd&include_last_updated_at=true`
        const response = await fetch(url, { headers: { accept: 'application/json', 'User-Agent': 'TennisLegacy/1.0' } })
        if (!response.ok) throw new Error(`CoinGecko HTTP ${response.status}`)
        const payload = await response.json()
        const now = new Date().toISOString()
        for (const instrument of crypto) {
          const row = payload?.[instrument.provider_key]
          const price = Number(row?.usd)
          if (!Number.isFinite(price) || price <= 0) {
            errors.push(`${instrument.symbol}: invalid CoinGecko quote`)
            continue
          }
          updates.push({
            instrument_code: instrument.code,
            price,
            previous_price: previous.get(instrument.code) ?? null,
            quote_as_of: row?.last_updated_at ? new Date(Number(row.last_updated_at) * 1000).toISOString() : now,
            fetched_at: now,
            source: 'coingecko',
            metadata: { provider_id: instrument.provider_key },
            updated_at: now,
          })
        }
      } catch (error) {
        errors.push(`Crypto refresh: ${error instanceof Error ? error.message : String(error)}`)
      }
    }

    const stocks = instruments.filter((item) => item.asset_type === 'stock')
    const stockResults = await Promise.allSettled(stocks.map((instrument) => fetchStooqQuote(instrument, previous.get(instrument.code) ?? null)))
    stockResults.forEach((result, index) => {
      if (result.status === 'fulfilled') updates.push(result.value)
      else errors.push(`${stocks[index]?.symbol ?? 'stock'}: ${result.reason instanceof Error ? result.reason.message : String(result.reason)}`)
    })

    if (updates.length) {
      const { error: upsertError } = await admin.from('private_life_investment_quotes').upsert(updates, { onConflict: 'instrument_code' })
      if (upsertError) throw upsertError
    }

    return Response.json({
      ok: updates.length > 0,
      updated: updates.length,
      expected: instruments.length,
      errors,
      refreshed_at: new Date().toISOString(),
    }, { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (error) {
    return Response.json({ error: error instanceof Error ? error.message : String(error) }, { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
