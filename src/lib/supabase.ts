import { createClient } from '@supabase/supabase-js'

/**
 * Public browser credentials for the locked Tennis Legacy Supabase project.
 * The publishable key is intentionally safe for browser use; database access
 * remains protected by Row Level Security.
 */
// These values are supplied by esbuild's compile-time define. Test builds can
// point to an isolated local Supabase stack without affecting production.
declare const __TL_SUPABASE_URL__: string
declare const __TL_SUPABASE_PUBLISHABLE_KEY__: string
const SUPABASE_URL = __TL_SUPABASE_URL__
const SUPABASE_PUBLISHABLE_KEY = __TL_SUPABASE_PUBLISHABLE_KEY__
const SUPABASE_REQUEST_TIMEOUT_MS = 15_000

/**
 * Browser fetch has no built-in request timeout. A stalled network request can
 * therefore leave a React loading state active forever. Supabase/PostgREST
 * converts an aborted fetch into its normal error response, allowing callers
 * to leave their loading state and show a useful retryable error instead.
 */
const fetchWithTimeout: typeof fetch = async (input, init) => {
  const controller = new AbortController()
  const upstreamSignal = init?.signal
  const abortFromUpstream = () => controller.abort(upstreamSignal?.reason)

  if (upstreamSignal?.aborted) controller.abort(upstreamSignal.reason)
  else upstreamSignal?.addEventListener('abort', abortFromUpstream, { once: true })

  const timeoutId = globalThis.setTimeout(() => controller.abort('Supabase request timed out'), SUPABASE_REQUEST_TIMEOUT_MS)

  try {
    return await globalThis.fetch(input, { ...init, signal: controller.signal })
  } finally {
    globalThis.clearTimeout(timeoutId)
    upstreamSignal?.removeEventListener('abort', abortFromUpstream)
  }
}

export const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_PUBLISHABLE_KEY,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
    global: {
      fetch: fetchWithTimeout,
    },
  },
)
