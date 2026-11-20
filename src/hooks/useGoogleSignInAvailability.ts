import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

/**
 * Google sign-in remains fail-closed until an administrator verifies Google
 * OAuth credentials, exact redirect URLs and existing-account preservation.
 * Configuration is read-only to anonymous users.
 */
export default function useGoogleSignInAvailability() {
  const [enabled, setEnabled] = useState(false)

  useEffect(() => {
    let active = true
    void supabase.rpc('get_public_google_oauth_status_v1').then(({ data, error }) => {
      if (active) setEnabled(!error && data === true)
    }).catch(() => {
      if (active) setEnabled(false)
    })
    return () => { active = false }
  }, [])

  return enabled
}

export async function startTennisGoogleSignIn() {
  // The existing protected route checks for an already owned player and
  // forwards returning players to their original career/overview.
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: new URL('/create-player', window.location.origin).toString(),
    },
  })
  if (error) throw error
}
