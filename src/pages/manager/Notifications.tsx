import { useCallback, useEffect, useMemo, useState } from 'react'
import { ChevronDown, ChevronRight } from 'lucide-react'
import { useTranslation, type TFunction } from 'react-i18next'
import { useNavigate } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import GameLayout from '../../components/layout/GameLayout'
import { useLocalization } from '../../i18n/LocalizationProvider'
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

const FILTERS: NotificationFilter[] = ['all', 'unread', 'important', 'tournament', 'health', 'equipment', 'account']

function notificationTemplateKey(code: string) {
  return code.replaceAll('.', '_')
}

function localizedNotification(notification: NotificationRow, t: TFunction) {
  const key = notificationTemplateKey(notification.notification_code)
  const values = { ...notification.payload }
  return {
    title: t(`notifications.templates.${key}.title`, { ...values, defaultValue: notification.title }),
    message: t(`notifications.templates.${key}.message`, { ...values, defaultValue: notification.message }),
  }
}

const SEVERITY_ORDER: Record<NotificationSeverity, number> = {
  info: 1,
  success: 2,
  warning: 3,
  error: 4,
}

function relativeTime(value: string, t: TFunction, localeTag: string) {
  const created = new Date(value).getTime()
  const seconds = Math.max(0, Math.floor((Date.now() - created) / 1000))

  if (seconds < 60) return t('notifications.time.justNow')
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return t('notifications.time.minutesAgo', { count: minutes })
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return t('notifications.time.hoursAgo', { count: hours })
  const days = Math.floor(hours / 24)
  if (days < 7) return t('notifications.time.daysAgo', { count: days })

  return new Intl.DateTimeFormat(localeTag, {
    month: 'short',
    day: 'numeric',
    year: created < new Date().setFullYear(new Date().getFullYear() - 1) ? 'numeric' : undefined,
  }).format(new Date(value))
}

function fullDateTime(value: string, localeTag: string) {
  return new Intl.DateTimeFormat(localeTag, {
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
  if (code.startsWith('national.') || code.startsWith('national_team.')) return 'national_team'
  return 'account'
}

function categoryLabel(notification: NotificationRow, t: TFunction) {
  const key = categoryKey(notification)
  return t(`notifications.categories.${key}`, {
    defaultValue: key.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase()),
  })
}

function notificationTypeLabel(notification: NotificationRow, t: TFunction) {
  const templateKey = notificationTemplateKey(notification.notification_code)
  const translated = t(`notifications.templates.${templateKey}.title`, {
    ...notification.payload,
    defaultValue: '',
  })
  if (translated) return translated

  return payloadText(notification.payload, 'notification_label')
    ?? notification.notification_code
      .split('.')
      .slice(1)
      .join(' ')
      .replaceAll('_', ' ')
      .replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function severityLabel(severity: NotificationSeverity, t: TFunction) {
  return t(`notifications.severity.${severity}`)
}

function tournamentRoute(competitionId: string | null) {
  return competitionId ? `/game/tournaments/${competitionId}` : null
}

function preparationRoute(competitionId: string | null) {
  return competitionId ? `/game/schedule?competition=${encodeURIComponent(competitionId)}&prepare=1` : '/game/schedule'
}

function primaryActionLabel(code: string, t: TFunction) {
  if (code === 'doubles.partner.invitation') return t('notifications.actions.reviewInvitation')
  if (code === 'doubles.draw.published') return t('notifications.actions.viewDoublesDraw')
  if (code === 'doubles.match.scheduled') return t('notifications.actions.prepareDoublesMatch')
  if (code === 'doubles.match.result') return t('notifications.actions.viewDoublesResult')
  if (code.startsWith('doubles.')) return t('notifications.actions.openDoubles')
  if (code === 'tournament.draw.published') return t('notifications.actions.viewDraw')
  if (code === 'tournament.preparation.available') return t('notifications.actions.openPreparation')
  if (code.startsWith('tournament.application.')) return t('notifications.actions.viewTournament')
  if (code.startsWith('tournament.entry.')) return t('notifications.actions.viewTournament')
  if (code === 'tournament.canceled') return t('notifications.actions.viewTournament')
  if (code === 'account.birthday_gift') return t('notifications.actions.viewCoins')
  if (code.startsWith('equipment.technical_sponsor.offer')) return t('notifications.actions.openSponsorOffers')
  if (code.startsWith('equipment.technical_sponsor.')) return t('notifications.actions.openSponsorship')
  if (code.startsWith('equipment.')) return t('notifications.actions.viewEquipment')
  if (code.startsWith('travel.')) return t('notifications.actions.openSchedule')
  if (code.startsWith('player.fatigue.') || code.startsWith('training.')) return t('notifications.actions.openTraining')
  if (code.startsWith('player.health.') || code.startsWith('player.injury.') || code.startsWith('player.illness.')) return t('notifications.actions.openHealth')
  if (code.startsWith('player.skill.')) return t('notifications.actions.viewSkills')
  if (code.startsWith('player.private_life.')) return t('notifications.actions.openPrivateLife')
  if (code.startsWith('avatar.')) return t('notifications.actions.openAccount')
  if (code.startsWith('finance.')) return t('notifications.actions.openFinance')
  if (code.startsWith('staff.')) return t('notifications.actions.openStaff')
  if (code === 'national_team.callup') return t('notifications.actions.reviewCallup')
  if (code === 'national.captain.election' || code === 'national.captain.runoff') return t('notifications.actions.voteNow')
  if (code === 'national.captain.elected') return t('notifications.actions.openElection')
  if (code.startsWith('national.')) return t('notifications.actions.openNationalTeam')
  return t('notifications.actions.open')
}

function notificationActions(notification: NotificationRow, t: TFunction) {
  const payload = notification.payload
  const code = notification.notification_code
  const competitionId = payloadText(payload, 'competition_id')
  let primaryRoute = safeGameRoute(payloadText(payload, 'action_url')) ?? safeGameRoute(notification.route)

  if (code.startsWith('tournament.') && competitionId) {
    primaryRoute = code === 'tournament.preparation.available'
      ? preparationRoute(competitionId)
      : tournamentRoute(competitionId)
  } else if (code.startsWith('doubles.') && competitionId) {
    primaryRoute = `/game/tournaments/${competitionId}/doubles`
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
      national_team: '/game/national-team',
      account: '/game/player-account',
    }[category] ?? null
  }

  const actions: NotificationAction[] = []
  if (primaryRoute) actions.push({ label: primaryActionLabel(code, t), to: primaryRoute, primary: true })

  if (code === 'tournament.preparation.available' && competitionId) {
    actions.push({ label: t('notifications.actions.viewTournament'), to: tournamentRoute(competitionId)! })
  }

  const finance = payloadObject(payload, 'finance')
  if ((finance || code.startsWith('player.private_life.')) && primaryRoute !== '/game/finance') {
    actions.push({ label: t('notifications.actions.openFinance'), to: '/game/finance' })
  }

  const relatedPlayerId = payloadText(payload, 'related_player_id') ?? payloadText(payload, 'rider_id')
  if (relatedPlayerId) actions.push({ label: t('notifications.actions.viewPlayer'), to: `/game/players/${relatedPlayerId}` })

  const unique = new Map<string, NotificationAction>()
  actions.forEach((action) => {
    if (!unique.has(action.to)) unique.set(action.to, action)
  })
  return Array.from(unique.values())
}

function gameMomentLabel(value: Record<string, unknown> | null, t: TFunction) {
  if (!value) return null
  const season = typeof value.season === 'number' ? value.season : null
  const month = typeof value.month === 'number' ? value.month : null
  const day = typeof value.day === 'number' ? value.day : null
  if (season === null || month === null || day === null) return null
  const hour = typeof value.hour === 'number' ? value.hour : 0
  const minute = typeof value.minute === 'number' ? value.minute : 0
  return t('notifications.context.seasonMoment', { season, day: String(day).padStart(2, '0'), month: String(month).padStart(2, '0'), time: `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}` })
}

function money(value: number, localeTag: string) {
  const formatted = new Intl.NumberFormat(localeTag, {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 0,
  }).format(Math.abs(Math.round(value)))
  return `${value < 0 ? '−' : ''}${formatted}`
}

function contextRows(notification: NotificationRow, t: TFunction, localeTag: string) {
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
    add(t('notifications.context.tournament'), titleTournament)
    add(t('notifications.context.entryWave'), payloadText(payload, 'entry_wave'))
    add(t('notifications.context.draw'), payloadText(payload, 'draw_type')?.replaceAll('_', ' '))
    add(t('notifications.context.priority'), payloadNumber(payload, 'priority'))
    add(t('notifications.context.nextEntryWave'), payloadText(payload, 'next_entry_wave'))
    add(t('notifications.context.tournamentStart'), gameMomentLabel(payloadObject(payload, 'tournament_start'), t))
    add(t('notifications.context.acceptedPlayers'), payloadNumber(payload, 'accepted_players'))
    add(t('notifications.context.minimumPlayers'), payloadNumber(payload, 'minimum_players'))
    const refunded = payloadNumber(payload, 'refunded_amount')
    if (refunded !== null) add(t('notifications.context.refunded'), money(refunded, localeTag))
  }

  if (notification.notification_code.startsWith('doubles.')) {
    add(t('notifications.context.tournament'), payloadText(payload, 'tournament_name') ?? titleTournament)
    add(t('notifications.context.city'), payloadText(payload, 'city'))
    add(t('notifications.context.partner'), payloadText(payload, 'partner_name') ?? payloadText(payload, 'proposed_partner_name'))
    add(t('notifications.context.opponents'), payloadText(payload, 'opponents'))
    add(t('notifications.context.round'), payloadText(payload, 'round_label'))
    add(t('notifications.context.entryStatus'), payloadText(payload, 'entry_status')?.replaceAll('_', ' '))
    add(t('notifications.context.result'), payloadText(payload, 'result')?.replace(/w/g, (letter) => letter.toUpperCase()))
    add(t('notifications.context.partnershipDeadline'), gameMomentLabel(payloadObject(payload, 'partnership_deadline'), t))
    add(t('notifications.context.tournamentStart'), gameMomentLabel(payloadObject(payload, 'tournament_start'), t))
    add(t('notifications.context.tournamentEnd'), gameMomentLabel(payloadObject(payload, 'tournament_end'), t))

    const seasonWeek = payloadNumber(payload, 'season_week')
    const matchDay = payloadNumber(payload, 'day')
    const startMinute = payloadNumber(payload, 'start_minute')
    if (seasonWeek !== null && matchDay !== null) add(t('notifications.context.matchDay'), t('notifications.context.seasonWeekDay', { week: seasonWeek, day: matchDay }))
    if (startMinute !== null) {
      const hour = Math.floor(startMinute / 60)
      const minute = startMinute % 60
      add(t('notifications.context.matchTime'), `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`)
    }
    const court = payloadNumber(payload, 'court_number')
    if (court !== null) add(t('notifications.context.court'), t('notifications.context.courtNumber', { court }))
    const sets = payloadNumber(payload, 'sets_played')
    const games = payloadNumber(payload, 'games_played')
    if (sets !== null) add(t('notifications.context.setsPlayed'), sets)
    if (games !== null) add(t('notifications.context.gamesPlayed'), games)

    const bracketSize = payloadNumber(payload, 'bracket_size')
    if (bracketSize !== null) add(t('notifications.context.drawSize'), t('notifications.context.teamsCount', { count: bracketSize }))
  }

  if (notification.notification_code.startsWith('national.') || notification.notification_code.startsWith('national_team.')) {
    add(t('notifications.context.association'), payloadText(payload, 'association_name'))
    add(t('notifications.context.captain'), payloadText(payload, 'captain_name'))
    add(t('notifications.context.opponent'), payloadText(payload, 'opponent_name'))
    add(t('notifications.context.hostCity'), payloadText(payload, 'host_city'))
    add(t('notifications.context.votingDeadline'), payloadText(payload, 'voting_deadline_label'))
    const round = payloadNumber(payload, 'round')
    if (round !== null) add(t('notifications.context.electionRound'), round)
    const responseDeadline = payloadNumber(payload, 'response_deadline_absolute_day')
    if (responseDeadline !== null) add(t('notifications.context.responseDeadline'), t('notifications.context.gameDay', { day: responseDeadline }))
    const compensation = payloadNumber(payload, 'expected_compensation_usd')
    if (compensation !== null) add(t('notifications.context.appearancePayment'), money(compensation, localeTag))
  }

  if (notification.notification_code.startsWith('travel.')) {
    const city = payloadText(payload, 'destination_city')
    const country = payloadText(payload, 'destination_country_code')
    add(t('notifications.context.destination'), [city, country].filter(Boolean).join(' · '))
    const km = payloadNumber(payload, 'distance_km')
    if (km !== null) add(t('notifications.context.distance'), `${new Intl.NumberFormat(localeTag).format(Math.round(km))} km`)
    const gross = payloadNumber(payload, 'gross_travel_fatigue')
    if (gross !== null) add(t('notifications.context.grossFatigue'), `+${gross}`)
    const recovery = payloadNumber(payload, 'travel_day_recovery')
    if (recovery !== null) add(t('notifications.context.travelDayRecovery'), `−${recovery}`)
    const net = payloadNumber(payload, 'fatigue_change')
    if (net !== null) add(t('notifications.context.netFatigue'), `${net >= 0 ? '+' : ''}${net}`)
    const finance = payloadObject(payload, 'finance')
    const amount = finance && typeof finance.amount === 'number' ? finance.amount : null
    if (amount !== null) add(t('notifications.context.travelCost'), money(amount, localeTag))
  }

  const before = payloadNumber(payload, 'fatigue_before')
  const after = payloadNumber(payload, 'fatigue_after')
  if (before !== null && after !== null) add(t('notifications.context.fatigue'), `${before}/100 → ${after}/100`)

  const skill = payloadText(payload, 'skill')
  const oldValue = payloadNumber(payload, 'old_value')
  const newValue = payloadNumber(payload, 'new_value')
  if (skill) add(t('notifications.context.skill'), skill)
  if (oldValue !== null && newValue !== null) add(t('notifications.context.skillChange'), `${oldValue} → ${newValue}`)

  const risk = payloadObject(payload, 'risk')
  if (risk) {
    if (typeof risk.risk_level === 'string') add(t('notifications.context.riskLevel'), risk.risk_level)
    if (typeof risk.risk_percent === 'number') add(t('notifications.context.risk'), `${risk.risk_percent.toFixed(2)}%`)
    if (Array.isArray(risk.reasons)) add(t('notifications.context.riskFactors'), risk.reasons.filter((item) => typeof item === 'string').join(' · '))
  }

  const sponsorCategory = payloadText(payload, 'category')
  if (notification.notification_code.startsWith('equipment.') && sponsorCategory) {
    add(t('notifications.context.equipmentCategory'), sponsorCategory === 'apparel' ? t('notifications.context.apparel') : sponsorCategory === 'racket' ? t('notifications.context.racket') : sponsorCategory === 'shoes' ? t('notifications.context.shoes') : sponsorCategory)
  }
  add(t('notifications.context.daysRemaining'), payloadNumber(payload, 'days_remaining'))

  if (notification.notification_code === 'account.birthday_gift') {
    const reward = payloadNumber(payload, 'reward_amount')
    if (reward !== null) add(t('notifications.context.birthdayReward'), t('common.coinsCount', { count: reward }))
    add(t('notifications.context.rewardYear'), payloadNumber(payload, 'reward_year'))
  }

  if (notification.notification_code.startsWith('avatar.')) {
    add(t('notifications.context.requestStatus'), payloadText(payload, 'status')?.replaceAll('_', ' '))
  }

  if (notification.notification_code.startsWith('player.private_life.')) {
    add(t('notifications.context.billingMonth'), payloadText(payload, 'month_name'))
    const total = payloadNumber(payload, 'total_cost')
    if (total !== null) add(t('notifications.context.totalCost'), money(-Math.abs(total), localeTag))
  }

  const progress = payloadNumber(payload, 'progress_percent')
  if (progress !== null) add(t('notifications.context.recoveryProgress'), `${progress}%`)

  const conditionCode = payloadText(payload, 'condition_code') ?? payloadText(payload, 'injury_code') ?? payloadText(payload, 'illness_code')
  if (conditionCode) add(t('notifications.context.condition'), conditionCode.replaceAll('_', ' '))

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
