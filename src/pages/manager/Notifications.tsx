import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/notification-center.css'

type NotificationSeverity = 'info' | 'success' | 'warning' | 'error'
type NotificationFilter = 'all' | 'unread' | 'development'

interface NotificationRow {
  id: string
  user_id: string
  player_id: string | null
  notification_code: string
  title: string
  message: string
  severity: NotificationSeverity
  route: string | null
  payload: Record<string, unknown>
  created_at: string
  read_at: string | null
  archived_at: string | null
}

function relativeTime(value: string) {
  const created = new Date(value).getTime()
  const seconds = Math.max(0, Math.floor((Date.now() - created) / 1000))

  if (seconds < 60) return 'Just now'
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes} min ago`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours} h ago`
  const days = Math.floor(hours / 24)
  if (days < 7) return `${days} d ago`

  return new Intl.DateTimeFormat('en', {
    month: 'short',
    day: 'numeric',
    year: created < new Date().setFullYear(new Date().getFullYear() - 1) ? 'numeric' : undefined,
  }).format(new Date(value))
}

function payloadNumber(payload: Record<string, unknown>, key: string) {
  const value = payload[key]
  return typeof value === 'number' ? value : null
}

function payloadText(payload: Record<string, unknown>, key: string) {
  const value = payload[key]
  return typeof value === 'string' ? value : null
}

export default function NotificationsPage() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [notifications, setNotifications] = useState<NotificationRow[]>([])
  const [filter, setFilter] = useState<NotificationFilter>('all')
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const loadNotifications = useCallback(async () => {
    if (!user?.id) {
      setNotifications([])
      setLoading(false)
      return
    }

    const { data, error: loadError } = await supabase
      .from('user_notifications')
      .select('id, user_id, player_id, notification_code, title, message, severity, route, payload, created_at, read_at, archived_at')
      .eq('user_id', user.id)
      .is('archived_at', null)
      .order('created_at', { ascending: false })
      .limit(150)

    if (loadError) {
      setError(loadError.message)
      setNotifications([])
    } else {
      setError(null)
      setNotifications((data ?? []) as NotificationRow[])
    }

    setLoading(false)
  }, [user?.id])

  useEffect(() => {
    void loadNotifications()

    if (!user?.id) return

    const channel = supabase
      .channel(`notification-center-${user.id}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_notifications',
          filter: `user_id=eq.${user.id}`,
        },
        () => {
          void loadNotifications()
        },
      )
      .subscribe()

    return () => {
      void supabase.removeChannel(channel)
    }
  }, [loadNotifications, user?.id])

  const unreadCount = useMemo(
    () => notifications.filter((item) => !item.read_at).length,
    [notifications],
  )

  const developmentCount = useMemo(
    () => notifications.filter((item) => item.notification_code.startsWith('player.skill.')).length,
    [notifications],
  )

  const visibleNotifications = useMemo(() => {
    if (filter === 'unread') return notifications.filter((item) => !item.read_at)
    if (filter === 'development') return notifications.filter((item) => item.notification_code.startsWith('player.skill.'))
    return notifications
  }, [filter, notifications])

  async function markRead(notification: NotificationRow) {
    if (notification.read_at) return

    const readAt = new Date().toISOString()
    const { error: updateError } = await supabase
      .from('user_notifications')
      .update({ read_at: readAt })
      .eq('id', notification.id)

    if (updateError) {
      setError(updateError.message)
      return
    }

    setNotifications((items) => items.map((item) => (
      item.id === notification.id ? { ...item, read_at: readAt } : item
    )))
  }

  async function markAllRead() {
    if (!user?.id || unreadCount === 0 || busy) return

    setBusy(true)
    const readAt = new Date().toISOString()
    const { error: updateError } = await supabase
      .from('user_notifications')
      .update({ read_at: readAt })
      .eq('user_id', user.id)
      .is('read_at', null)
      .is('archived_at', null)

    if (updateError) {
      setError(updateError.message)
    } else {
      setNotifications((items) => items.map((item) => ({ ...item, read_at: item.read_at ?? readAt })))
    }
    setBusy(false)
  }

  async function dismiss(notification: NotificationRow) {
    const archivedAt = new Date().toISOString()
    const { error: updateError } = await supabase
      .from('user_notifications')
      .update({ archived_at: archivedAt })
      .eq('id', notification.id)

    if (updateError) {
      setError(updateError.message)
      return
    }

    setNotifications((items) => items.filter((item) => item.id !== notification.id))
  }

  async function openNotification(notification: NotificationRow) {
    await markRead(notification)
    if (notification.route) navigate(notification.route)
  }

  return (
    <GameLayout title="Notifications" subtitle="Manager alerts and game updates">
      <section className="tlg-v2-command tlg-notification-command">
        <div className="tlg-v2-command-inner tlg-notification-command-inner">
          <div>
            <span className="tlg-v2-command-kicker">Notification center</span>
            <h2>Career notifications</h2>
            <p>
              Automatic career, development, tournament and account events are collected here. Notification types are centrally defined so future delivery rules can be shared across in-game, email and push channels.
            </p>
          </div>
          <div className="tlg-notification-summary" aria-label="Notification summary">
            <div><span>Unread</span><strong>{unreadCount}</strong></div>
            <div><span>Total</span><strong>{notifications.length}</strong></div>
            <div><span>Development</span><strong>{developmentCount}</strong></div>
          </div>
        </div>
      </section>

      <section className="tlg-notification-panel">
        <header className="tlg-notification-toolbar">
          <div className="tlg-notification-filters" role="tablist" aria-label="Notification filters">
            <button type="button" className={filter === 'all' ? 'active' : ''} onClick={() => setFilter('all')}>All</button>
            <button type="button" className={filter === 'unread' ? 'active' : ''} onClick={() => setFilter('unread')}>Unread {unreadCount > 0 ? `(${unreadCount})` : ''}</button>
            <button type="button" className={filter === 'development' ? 'active' : ''} onClick={() => setFilter('development')}>Player development</button>
          </div>
          <button type="button" className="tlg-notification-mark-all" disabled={unreadCount === 0 || busy} onClick={markAllRead}>
            {busy ? 'Updating…' : 'Mark all as read'}
          </button>
        </header>

        {error && <div className="tlg-notification-error">Unable to update notifications: {error}</div>}

        {loading ? (
          <div className="tlg-notification-empty">Loading notifications…</div>
        ) : visibleNotifications.length === 0 ? (
          <div className="tlg-notification-empty">
            <strong>{filter === 'unread' ? 'No unread notifications' : 'No notifications yet'}</strong>
            <p>
              {filter === 'unread'
                ? 'Everything has been read.'
                : 'The first live notification is connected to tennis-skill changes. When a real skill increases or decreases, the event will appear here automatically.'}
            </p>
          </div>
        ) : (
          <div className="tlg-notification-list">
            {visibleNotifications.map((notification) => {
              const skill = payloadText(notification.payload, 'skill')
              const oldValue = payloadNumber(notification.payload, 'old_value')
              const newValue = payloadNumber(notification.payload, 'new_value')
              const delta = payloadNumber(notification.payload, 'delta')

              return (
                <article
                  key={notification.id}
                  className={`tlg-notification-item severity-${notification.severity} ${notification.read_at ? 'read' : 'unread'}`}
                >
                  <div className="tlg-notification-status" aria-hidden="true" />
                  <div className="tlg-notification-copy">
                    <div className="tlg-notification-meta">
                      <span>{notification.notification_code.startsWith('player.skill.') ? 'Player development' : 'Game update'}</span>
                      <time dateTime={notification.created_at}>{relativeTime(notification.created_at)}</time>
                    </div>
                    <h3>{notification.title}</h3>
                    <p>{notification.message}</p>

                    {skill && oldValue !== null && newValue !== null && delta !== null && (
                      <div className="tlg-notification-skill-change">
                        <span>{skill}</span>
                        <strong>{oldValue} → {newValue}</strong>
                        <em className={delta > 0 ? 'positive' : 'negative'}>{delta > 0 ? '+' : ''}{delta}</em>
                      </div>
                    )}
                  </div>
                  <div className="tlg-notification-actions">
                    {notification.route && (
                      <button type="button" onClick={() => void openNotification(notification)}>Open</button>
                    )}
                    {!notification.read_at && (
                      <button type="button" onClick={() => void markRead(notification)}>Mark read</button>
                    )}
                    <button type="button" className="subtle" onClick={() => void dismiss(notification)}>Dismiss</button>
                  </div>
                </article>
              )
            })}
          </div>
        )}
      </section>
    </GameLayout>
  )
}
