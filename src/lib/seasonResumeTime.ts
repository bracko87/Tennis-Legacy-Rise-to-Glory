/** Format a server-owned UTC resume timestamp in the player's device time zone. */
export function formatSeasonResumeTime(
  resumeAt: string | null | undefined,
  localeTag: string,
  timeZone?: string,
): string | null {
  if (!resumeAt) return null

  const date = new Date(resumeAt)
  if (Number.isNaN(date.getTime())) return null

  const localTimeZone = timeZone || Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'
  const formatted = new Intl.DateTimeFormat(localeTag, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
    timeZone: localTimeZone,
    timeZoneName: 'short',
  }).format(date)

  // The IANA identifier removes ambiguity across daylight-saving changes.
  return `${formatted} (${localTimeZone})`
}
