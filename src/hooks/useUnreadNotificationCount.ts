import { useCallback, useEffect, useState } from 'react'

import { useAuth } from '../auth/AuthContext'
import { supabase } from '../lib/supabase'

export default function useUnreadNotificationCount() {
  const { user } = useAuth()
  const [count, setCount] = useState(0)

  const refresh = useCallback(async () => {
    if (!user?.id) {
      setCount(0)
      return
    }

    const { count: unreadCount, error } = await supabase
      .from('user_notifications')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .is('read_at', null)
      .is('archived_at', null)

    if (error) {
      console.error('Unable to load unread notification count:', error.message)
      return
    }

    setCount(unreadCount ?? 0)
  }, [user?.id])

  useEffect(() => {
    void refresh()

    if (!user?.id) return

    const channel = supabase
      .channel(`notification-count-${user.id}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_notifications',
          filter: `user_id=eq.${user.id}`,
        },
        () => {
          void refresh()
        },
      )
      .subscribe()

    function refreshWhenVisible() {
      if (document.visibilityState === 'visible') void refresh()
    }

    document.addEventListener('visibilitychange', refreshWhenVisible)

    return () => {
      document.removeEventListener('visibilitychange', refreshWhenVisible)
      void supabase.removeChannel(channel)
    }
  }, [refresh, user?.id])

  return { unreadCount: count, refreshUnreadCount: refresh }
}
