import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

export type RegistrationAvailability = 'loading' | 'open' | 'closed'

/** Read-only server-controlled registration gate. Defaults to closed on errors. */
export default function usePublicRegistrationStatus(): RegistrationAvailability {
  const [availability, setAvailability] = useState<RegistrationAvailability>('loading')

  useEffect(() => {
    let active = true
    void supabase.rpc('get_public_registration_status_v1').then(({ data, error }) => {
      if (active) setAvailability(!error && data === true ? 'open' : 'closed')
    })
    return () => { active = false }
  }, [])

  return availability
}
