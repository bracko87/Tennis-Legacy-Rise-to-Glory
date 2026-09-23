import { useCallback, useEffect, useMemo, useState } from 'react'
import { ChevronDown, ChevronRight } from 'lucide-react'
import { useNavigate } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'
import '../../styles/notification-center.css'

type NotificationSeverity = 'info' | 'success' | 'warning' | 'error'
type NotificationFilter = 'all' | 'unread' | 'important' | 'tournament' | 'health' | 'equipment' | 'account'

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
  event_key: string | null
  created_at: string
  read_at: string | null
  archived_at: string | null
}

interface NotificationAction {
  label: string
  to: string
  primary?: boolean
}

interface ContextRow {
  label: string
  value: string
}

const CATEGORY_LABELS: Record<string, string> = {
  account: 'Account',
  equipment: 'Equipment',
  finance: 'Finance',
  player_condition: 'Player condition',
  player_development: 'Player development',
  player_health: 'Health & injuries',
  private_life: 'Private life',
  staff: 'Staff',
  tournament: 'Tournament',
  training: 'Training',
  travel: 'Travel',
}

const FILTERS: Array<{ key: NotificationFilter; label: string }> = [
  { key: 'all', label: 'All' },
  { key: 'unread', label: 'Unread' },
  { key: 'important', label: 'Important' },
  { key: 'tournament', label: 'Tournaments & travel' },
  { key: 'health', label: 'Player & training' },
  { key: 'equipment', label: 'Equipment' },
  { key: 'account', label: 'Account & finance' },
]

const SEVERITY_ORDER: Record<NotificationSeverity, number> = {
  info: 1,
  success: 2,
  warning: 3,
  error: 4,
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

function fullDateTime(value: string) {
  return new Intl.DateTimeFormat('en', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
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

function payloadObject(payload: Record<string, unknown>, key: string) {
  const value = payload[key]
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null
}

function safeGameRoute(value: string | null | undefined) {
  if (!value || !value.startsWith('/game/')) return null
  return value
}

function categoryKey(notification: NotificationRow) {
  const payloadCategory = payloadText(notification.payload, 'notification_category')
  if (payloadCategory) return payloadCategory

  const code = notification.notification_code
  if (code.startsWith('tournament.') || code.startsWith('doubles.')) return 'tournament'
  if (code.startsWith('travel.')) return 'travel'
  if (code.startsWith('equipment.')) return 'equipment'
  if (code.startsWith('training.')) return 'training'
  if (code.startsWith('player.skill.')) return 'player_development'
  if (code.startsWith('player.fatigue.')) return 'player_condition'
  if (code.startsWith('player.health.') || code.startsWith('player.injury.') || code.startsWith('player.illness.')) return 'player_health'
  if (code.startsWith('player.private_life.')) return 'private_life'
  if (code.startsWith('avatar.') || code.startsWith('account.')) return 'account'
  if (code.startsWith('finance.')) return 'finance'
  if (code.startsWith('staff.')) return 'staff'
  return 'account'
}

function categoryLabel(notification: NotificationRow) {
  const key = categoryKey(notification)
  return CATEGORY_LABELS[key] ?? key.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function notificationTypeLabel(notification: NotificationRow) {
  return payloadText(notification.payload, 'notification_label')
    ?? notification.notification_code
      .split('.')
      .slice(1)
      .join(' ')
      .replaceAll('_', ' ')
      .replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function severityLabel(severity: NotificationSeverity) {
  if (severity === 'error') return 'Critical'
  if (severity === 'warning') return 'Important'
  if (severity === 'success') return 'Success'
  return 'Information'
}

function tournamentRoute(competitionId: string | null) {
  return competitionId ? `/game/tournaments/${competitionId}` : null
}

function preparationRoute(competitionId: string | null) {
  return competitionId ? `/game/schedule?competition=${encodeURIComponent(competitionId)}&prepare=1` : '/game/schedule'
}

function primaryActionLabel(code: string) {
  if (code === 'doubles.partner.invitation') return 'Review invitation'
  if (code === 'doubles.draw.published') return 'View doubles draw'
  if (code.startsWith('doubles.')) return 'Open doubles'
  if (code === 'tournament.draw.published') return 'View draw'
  if (code === 'tournament.preparation.available') return 'Open preparation'
  if (code.startsWith('tournament.application.')) return 'View tournament'
  if (code.startsWith('tournament.entry.')) return 'View tournament'
  if (code === 'tournament.canceled') return 'View tournament'
  if (code === 'account.birthday_gift') return 'View coins'
  if (code.startsWith('equipment.technical_sponsor.offer')) return 'Open sponsor offers'
  if (code.startsWith('equipment.technical_sponsor.')) return 'Open sponsorship'
  if (code.startsWith('equipment.')) return 'View equipment'
  if (code.startsWith('travel.')) return 'Open schedule'
  if (code.startsWith('player.fatigue.') || code.startsWith('training.')) return 'Open training'
  if (code.startsWith('player.health.') || code.startsWith('player.injury.') || code.startsWith('player.illness.')) return 'Open health'
  if (code.startsWith('player.skill.')) return 'View skills'
  if (code.startsWith('player.private_life.')) return 'Open private life'
  if (code.startsWith('avatar.')) return 'Open account'
  if (code.startsWith('finance.')) return 'Open finance'
  if (code.startsWith('staff.')) return 'Open staff'
  return 'Open'
}

function notificationActions(notification: NotificationRow) {
  const payload = notification.payload
  const code = notification.notification_code
  const competitionId = payloadText(payload, 'competition_id')
  let primaryRoute = safeGameRoute(payloadText(payload, 'action_url')) ?? safeGameRoute(notification.route)

  if (code.startsWith('tournament.') && competitionId) {
    primaryRoute = code === 'tournament.preparation.available'
      ? preparationRoute(competitionId)
      : tournamentRoute(competitionId)
  } else if (code === 'account.birthday_gift') {
    primaryRoute = '/game/pro-packages'
  } else if (code.startsWith('equipment.technical_sponsor.')) {
    primaryRoute = '/game/equipment?tab=sponsors'
  }

  if (!primaryRoute) {
    const category = categoryKey(notification)
    primaryRoute = {
      tournament: '/game/calendar?tab=tournament-calendar',
      travel: '/game/schedule',
      equipment: '/game/equipment',
      training: '/game/training',
      player_condition: '/game/training',
      player_development: '/game/skills',
      player_health: '/game/injuries',
      private_life: '/game/private-life',
      finance: '/game/finance',
      staff: '/game/staff',
      account: '/game/player-account',
    }[category] ?? null
  }

  const actions: NotificationAction[] = []
  if (primaryRoute) actions.push({ label: primaryActionLabel(code), to: primaryRoute, primary: true })

  if (code === 'tournament.preparation.available' && competitionId) {
    actions.push({ label: 'View tournament', to: tournamentRoute(competitionId)! })
  }

  const finance = payloadObject(payload, 'finance')
  if ((finance || code.startsWith('player.private_life.')) && primaryRoute !== '/game/finance') {
    actions.push({ label: 'Open finance', to: '/game/finance' })
  }

  const relatedPlayerId = payloadText(payload, 'related_player_id') ?? payloadText(payload, 'rider_id')
  if (relatedPlayerId) actions.push({ label: 'View player', to: `/game/players/${relatedPlayerId}` })

  const unique = new Map<string, NotificationAction>()
  actions.forEach((action) => {
    if (!unique.has(action.to)) unique.set(action.to, action)
  })
  return Array.from(unique.values())
}

function gameMomentLabel(value: Record<string, unknown> | null) {
  if (!value) return null
  const season = typeof value.season === 'number' ? value.season : null
  const month = typeof value.month === 'number' ? value.month : null
  const day = typeof value.day === 'number' ? value.day : null
  if (season === null || month === null || day === null) return null
  const hour = typeof value.hour === 'number' ? value.hour : 0
  const minute = typeof value.minute === 'number' ? value.minute : 0
  return `Season ${season} · ${String(day).padStart(2, '0')}/${String(month).padStart(2, '0')} · ${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`
}

function money(value: number) {
  return `${value < 0 ? '−' : ''}$${Math.abs(Math.round(value)).toLocaleString()}`
}

function contextRows(notification: NotificationRow) {
  const payload = notification.payload
  const rows: ContextRow[] = []
  const add = (label: string, value: string | number | null | undefined) => {
    if (value === null || value === undefined || value === '') return
    const text = String(value)
    if (!rows.some((row) => row.label === label && row.value === text)) rows.push({ label, value: text })
  }

  const titleTournament = notification.title.includes(' · ')
    ? notification.title.split(' · ').slice(-1)[0]
    : null

  if (notification.notification_code.startsWith('tournament.')) {
    add('Tournament', titleTournament)
    add('Entry wave', payloadText(payload, 'entry_wave'))
    add('Draw', payloadText(payload, 'draw_type')?.replaceAll('_', ' '))
    add('Priority', payloadNumber(payload, 'priority'))
    add('Next entry wave', payloadText(payload, 'next_entry_wave'))
    add('Tournament start', gameMomentLabel(payloadObject(payload, 'tournament_start')))
    add('Accepted players', payloadNumber(payload, 'accepted_players'))
    add('Minimum players', payloadNumber(payload, 'minimum_players'))
    const refunded = payloadNumber(payload, 'refunded_amount')
    if (refunded !== null) add('Refunded', money(refunded))
  }

  if (notification.notification_code.startsWith('doubles.')) {
    add('Tournament', payloadText(payload, 'tournament_name') ?? titleTournament)
    add('City', payloadText(payload, 'city'))
    add('Partner', payloadText(payload, 'partner_name') ?? payloadText(payload, 'proposed_partner_name'))
    add('Entry status', payloadText(payload, 'entry_status')?.replaceAll('_', ' '))
    add('Partnership deadline', gameMomentLabel(payloadObject(payload, 'partnership_deadline')))
    add('Tournament start', gameMomentLabel(payloadObject(payload, 'tournament_start')))
    add('Tournament end', gameMomentLabel(payloadObject(payload, 'tournament_end')))
    const bracketSize = payloadNumber(payload, 'bracket_size')
    if (bracketSize !== null) add('Draw size', `${bracketSize} teams`)
  }

  if (notification.notification_code.startsWith('travel.')) {
    const city = payloadText(payload, 'destination_city')
    const country = payloadText(payload, 'destination_country_code')
    add('Destination', [city, country].filter(Boolean).join(' · '))
    const km = payloadNumber(payload, 'distance_km')
    if (km !== null) add('Distance', `${Math.round(km).toLocaleString()} km`)
    const gross = payloadNumber(payload, 'gross_travel_fatigue')
    if (gross !== null) add('Gross fatigue', `+${gross}`)
    const recovery = payloadNumber(payload, 'travel_day_recovery')
    if (recovery !== null) add('Travel-day recovery', `−${recovery}`)
    const net = payloadNumber(payload, 'fatigue_change')
    if (net !== null) add('Net fatigue', `${net >= 0 ? '+' : ''}${net}`)
    const finance = payloadObject(payload, 'finance')
    const amount = finance && typeof finance.amount === 'number' ? finance.amount : null
    if (amount !== null) add('Travel cost', money(amount))
  }

  const before = payloadNumber(payload, 'fatigue_before')
  const after = payloadNumber(payload, 'fatigue_after')
  if (before !== null && after !== null) add('Fatigue', `${before}/100 → ${after}/100`)

  const skill = payloadText(payload, 'skill')
  const oldValue = payloadNumber(payload, 'old_value')
  const newValue = payloadNumber(payload, 'new_value')
  if (skill) add('Skill', skill)
  if (oldValue !== null && newValue !== null) add('Skill change', `${oldValue} → ${newValue}`)

  const risk = payloadObject(payload, 'risk')
  if (risk) {
    if (typeof risk.risk_level === 'string') add('Risk level', risk.risk_level)
    if (typeof risk.risk_percent === 'number') add('Risk', `${risk.risk_percent.toFixed(2)}%`)
    if (Array.isArray(risk.reasons)) add('Risk factors', risk.reasons.filter((item) => typeof item === 'string').join(' · '))
  }

  const sponsorCategory = payloadText(payload, 'category')
  if (notification.notification_code.startsWith('equipment.') && sponsorCategory) {
    add('Equipment category', sponsorCategory === 'apparel' ? 'Clothing' : sponsorCategory === 'racket' ? 'Racquet' : sponsorCategory === 'shoes' ? 'Shoes' : sponsorCategory)
  }
  add('Days remaining', payloadNumber(payload, 'days_remaining'))

  if (notification.notification_code === 'account.birthday_gift') {
    const reward = payloadNumber(payload, 'reward_amount')
    if (reward !== null) add('Birthday reward', `${reward} Coins`)
    add('Reward year', payloadNumber(payload, 'reward_year'))
  }

  if (notification.notification_code.startsWith('avatar.')) {
    add('Request status', payloadText(payload, 'status')?.replaceAll('_', ' '))
  }

  if (notification.notification_code.startsWith('player.private_life.')) {
    add('Billing month', payloadText(payload, 'month_name'))
    const total = payloadNumber(payload, 'total_cost')
    if (total !== null) add('Total cost', money(-Math.abs(total)))
  }

  const progress = payloadNumber(payload, 'progress_percent')
  if (progress !== null) add('Recovery progress', `${progress}%`)

  const conditionCode = payloadText(payload, 'condition_code') ?? payloadText(payload, 'injury_code') ?? payloadText(payload, 'illness_code')
  if (conditionCode) add('Condition', conditionCode.replaceAll('_', ' '))

  return rows
}

function dedupeNotifications(items: NotificationRow[]) {
  const normal: NotificationRow[] = []
  const fatigue = new Map<string, NotificationRow>()

  for (const item of items) {
    if (!item.notification_code.startsWith('player.fatigue.')) {
      normal.push(item)
      continue
    }
    const fatigueAfter = payloadNumber(item.payload, 'fatigue_after')
    const key = `${item.player_id ?? 'none'}:${item.created_at}:${fatigueAfter ?? 'none'}`
    const current = fatigue.get(key)
    if (!current || SEVERITY_ORDER[item.severity] > SEVERITY_ORDER[current.severity]) fatigue.set(key, item)
  }

  return [...normal, ...fatigue.values()].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
}

function matchesFilter(notification: NotificationRow, filter: NotificationFilter) {
  if (filter === 'all') return true
  if (filter === 'unread') return !notification.read_at
  if (filter === 'important') return notification.severity === 'warning' || notification.severity === 'error'

  const category = categoryKey(notification)
  if (filter === 'tournament') return category === 'tournament' || category === 'travel'
  if (filter === 'health') return ['player_health', 'player_condition', 'player_development', 'training'].includes(category)
  if (filter === 'equipment') return category === 'equipment'
  if (filter === 'account') return ['account', 'finance', 'private_life', 'staff'].includes(category)
  return true
}

export default function NotificationsPage() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [notifications, setNotifications] = useState<NotificationRow[]>([])
  const [filter, setFilter] = useState<NotificationFilter>('all')
  const [expandedId, setExpandedId] = useState<string | null>(null)
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
      .select('id, user_id, player_id, notification_code, title, message, severity, route, payload, event_key, created_at, read_at, archived_at')
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
        () => void loadNotifications(),
      )
      .subscribe()

    return () => {
      void supabase.removeChannel(channel)
    }
  }, [loadNotifications, user?.id])

  const normalizedNotifications = useMemo(() => dedupeNotifications(notifications), [notifications])
  const unreadCount = useMemo(() => normalizedNotifications.filter((item) => !item.read_at).length, [normalizedNotifications])
  const importantCount = useMemo(
    () => normalizedNotifications.filter((item) => item.severity === 'warning' || item.severity === 'error').length,
    [normalizedNotifications],
  )
  const visibleNotifications = useMemo(
    () => normalizedNotifications.filter((item) => matchesFilter(item, filter)),
    [filter, normalizedNotifications],
  )

  async function markRead(notification: NotificationRow) {
    if (notification.read_at) return true

    const readAt = new Date().toISOString()
    const { error: updateError } = await supabase
      .from('user_notifications')
      .update({ read_at: readAt })
      .eq('id', notification.id)
      .eq('user_id', user?.id ?? '')

    if (updateError) {
      setError(updateError.message)
      return false
    }

    setNotifications((items) => items.map((item) => (
      item.id === notification.id ? { ...item, read_at: readAt } : item
    )))
    return true
  }

  async function toggleNotification(notification: NotificationRow) {
    if (expandedId === notification.id) {
      await markRead(notification)
      setExpandedId(null)
      return
    }

    const previous = expandedId
      ? notifications.find((item) => item.id === expandedId) ?? null
      : null

    if (previous) await markRead(previous)
    setExpandedId(notification.id)
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
      .eq('user_id', user?.id ?? '')

    if (updateError) {
      setError(updateError.message)
      return
    }

    setNotifications((items) => items.filter((item) => item.id !== notification.id))
    setExpandedId((current) => current === notification.id ? null : current)
  }

  async function openAction(notification: NotificationRow, action: NotificationAction) {
    await markRead(notification)
    navigate(action.to)
  }

  return (
    <GameLayout title="Notifications" subtitle="Career alerts, decisions and game updates">
      <section className="tlg-v2-command tlg-notification-command">
        <div className="tlg-v2-command-inner tlg-notification-command-inner">
          <div>
            <span className="tlg-v2-command-kicker">Notification center</span>
            <h2>Career notifications</h2>
            <p>
              Tournament decisions, travel, player condition, training, equipment, account events and other career updates are collected here. Open a notification to see its full context and continue directly to the affected game area.
            </p>
          </div>
          <div className="tlg-notification-summary" aria-label="Notification summary">
            <div><span>Unread</span><strong>{unreadCount}</strong></div>
            <div><span>Important</span><strong>{importantCount}</strong></div>
            <div><span>Total</span><strong>{normalizedNotifications.length}</strong></div>
          </div>
        </div>
      </section>

      <section className="tlg-notification-panel">
        <header className="tlg-notification-toolbar">
          <div className="tlg-notification-filters" role="tablist" aria-label="Notification filters">
            {FILTERS.map((item) => (
              <button
                type="button"
                key={item.key}
                className={filter === item.key ? 'active' : ''}
                onClick={() => setFilter(item.key)}
              >
                {item.label}
                {item.key === 'unread' && unreadCount > 0 ? ` (${unreadCount})` : ''}
                {item.key === 'important' && importantCount > 0 ? ` (${importantCount})` : ''}
              </button>
            ))}
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
            <strong>{filter === 'unread' ? 'No unread notifications' : 'No notifications in this category'}</strong>
            <p>
              {filter === 'unread'
                ? 'Everything in your notification center has been read.'
                : 'Tournament entries and draws, travel, player health, training, equipment, account rewards and other career events will appear here when they occur.'}
            </p>
          </div>
        ) : (
          <div className="tlg-notification-list">
            {visibleNotifications.map((notification) => {
              const expanded = expandedId === notification.id
              const rows = contextRows(notification)
              const actions = notificationActions(notification)

              return (
                <article
                  key={notification.id}
                  className={`tlg-notification-item severity-${notification.severity} ${notification.read_at ? 'read' : 'unread'} ${expanded ? 'expanded' : ''}`}
                  onClick={() => void toggleNotification(notification)}
                  onKeyDown={(event) => {
                    if (event.target !== event.currentTarget) return
                    if (event.key === 'Enter' || event.key === ' ') {
                      event.preventDefault()
                      void toggleNotification(notification)
                    }
                  }}
                  role="button"
                  tabIndex={0}
                  aria-expanded={expanded}
                >
                  <div className="tlg-notification-status" aria-hidden="true" />
                  <div className="tlg-notification-copy">
                    <div className="tlg-notification-meta">
                      <span>{categoryLabel(notification)}</span>
                      <time dateTime={notification.created_at}>{relativeTime(notification.created_at)}</time>
                      {!notification.read_at && <b>Unread</b>}
                    </div>
                    <h3>{notification.title}</h3>
                    <p className="tlg-notification-summary-message">{notification.message}</p>
                    <div className="tlg-notification-card-badges">
                      <span className={`severity-chip severity-${notification.severity}`}>{severityLabel(notification.severity)}</span>
                      <span>{notificationTypeLabel(notification)}</span>
                    </div>
                  </div>
                  <button
                    type="button"
                    className="tlg-notification-expand"
                    aria-label={expanded ? 'Collapse notification' : 'Open notification details'}
                    onClick={(event) => {
                      event.stopPropagation()
                      void toggleNotification(notification)
                    }}
                  >
                    <span>{expanded ? 'Hide' : 'Details'}</span>
                    {expanded ? <ChevronDown size={15} /> : <ChevronRight size={15} />}
                  </button>

                  {expanded && (
                    <div className="tlg-notification-detail" onClick={(event) => event.stopPropagation()}>
                      <div className="tlg-notification-detail-copy">
                        <span>Full description</span>
                        <p>{notification.message}</p>
                      </div>

                      <dl className="tlg-notification-detail-grid">
                        <div><dt>Created</dt><dd>{fullDateTime(notification.created_at)}</dd></div>
                        <div><dt>Category</dt><dd>{categoryLabel(notification)}</dd></div>
                        <div><dt>Type</dt><dd>{notificationTypeLabel(notification)}</dd></div>
                        <div><dt>Priority</dt><dd>{severityLabel(notification.severity)}</dd></div>
                        <div><dt>Status</dt><dd>{notification.read_at ? 'Read' : 'Unread'}</dd></div>
                        {rows.map((row) => <div key={`${row.label}:${row.value}`}><dt>{row.label}</dt><dd>{row.value}</dd></div>)}
                      </dl>

                      <div className="tlg-notification-detail-actions">
                        {actions.length > 0 ? actions.map((action) => (
                          <button
                            type="button"
                            key={`${notification.id}:${action.to}`}
                            className={action.primary ? 'primary' : ''}
                            onClick={() => void openAction(notification, action)}
                          >
                            {action.label}
                          </button>
                        )) : (
                          <span className="tlg-notification-no-action">This update no longer has an active game destination.</span>
                        )}
                        <button type="button" className="subtle" onClick={() => void dismiss(notification)}>Dismiss</button>
                      </div>
                    </div>
                  )}
                </article>
              )
            })}
          </div>
        )}
      </section>
    </GameLayout>
  )
}
