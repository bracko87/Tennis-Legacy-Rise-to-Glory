import { createClient } from '@supabase/supabase-js'

/**
 * Public browser credentials for the locked Tennis Legacy Supabase project.
 * The publishable key is intentionally safe for browser use; database access
 * remains protected by Row Level Security.
 */
const SUPABASE_URL = 'https://cwfznmroiqcyhfkfcrow.supabase.co'
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_FpDi8rEB6r1Ai49UMS_R2Q__UAGburi'

export const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_PUBLISHABLE_KEY,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  },
)
