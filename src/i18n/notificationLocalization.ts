import type { TFunction } from 'i18next'

export interface LocalizableNotification {
  notification_code: string
  title: string
  message: string
  payload?: Record<string, unknown> | null
}

export function notificationTemplateKey(code: string) {
  return code.replaceAll('.', '_')
}

export function localizeNotification<T extends LocalizableNotification>(notification: T, t: TFunction) {
  const key = notificationTemplateKey(notification.notification_code)
  const values = { ...(notification.payload ?? {}) }

  return {
    title: t(`notifications.templates.${key}.title`, {
      ...values,
      defaultValue: notification.title,
    }),
    message: t(`notifications.templates.${key}.message`, {
      ...values,
      defaultValue: notification.message,
    }),
  }
}
