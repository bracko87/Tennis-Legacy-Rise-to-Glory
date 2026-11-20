import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

/** Server-controlled and fail-closed until H01/H02/H08 launch safeguards pass. */
export default function useTennisGuestAvailability() {
  const [available, setAvailable] = useState(false)

  useEffect(() => {
    let mounted = true
    void supabase.rpc('get_public_tennis_guest_test_status_v1')
      .then(({ data, error }) => {
        if (mounted) setAvailable(!error && data === true)
      }).catch(() => {
        if (mounted) setAvailable(false)
      })
    return () => { mounted = false }
  }, [])

  return available
}
