import { createPortal } from 'react-dom'
import { useEffect, useMemo, useState } from 'react'
import { useParams } from 'react-router'

import { supabase } from '../../lib/supabase'

interface TournamentLogoDetail {
  tournament_name: string
  logo_url: string | null
  schedule_slots: Array<{ calendar_month: number }>
}

const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]

function signedStoragePath(value: string | null) {
  if (!value) return null
  const marker = '/storage/v1/object/sign/Admin/'
  const start = value.indexOf(marker)
  if (start < 0) return null
  const encodedPath = value.slice(start + marker.length).split('?')[0]
  try {
    return decodeURIComponent(encodedPath)
  } catch {
    return encodedPath.replaceAll('%20', ' ')
  }
}

export default function TournamentLogoRecovery() {
  const { competitionId } = useParams()
  const [detail, setDetail] = useState<TournamentLogoDetail | null>(null)
  const [resolvedUrl, setResolvedUrl] = useState<string | null>(null)
  const [target, setTarget] = useState<HTMLElement | null>(null)

  useEffect(() => {
    if (!competitionId) return
    let cancelled = false

    async function loadDetail() {
      const { data, error } = await supabase.rpc('get_tournament_detail_v1', {
        p_competition_id: competitionId,
      })
      if (cancelled || error) return
      const row = (Array.isArray(data) ? data[0] : data) as TournamentLogoDetail | null
      setDetail(row)
    }

    void loadDetail()
    return () => { cancelled = true }
  }, [competitionId])

  const monthName = useMemo(() => {
    const month = detail?.schedule_slots?.[0]?.calendar_month
    return month && month >= 1 && month <= 12 ? MONTHS[month - 1] : null
  }, [detail?.schedule_slots])

  useEffect(() => {
    if (!detail) return
    let cancelled = false

    async function resolveLogo() {
      setResolvedUrl(null)

      // First refresh any stored signed URL instead of depending on an old token.
      const existingPath = signedStoragePath(detail!.logo_url)
      if (existingPath) {
        const { data, error } = await supabase.storage.from('Admin').createSignedUrl(existingPath, 60 * 60 * 24 * 7)
        if (!cancelled && !error && data?.signedUrl) {
          setResolvedUrl(data.signedUrl)
          return
        }
      }

      // Some older tournament rows lost logo_url during naming/data migrations.
      // Recover the already-uploaded image by looking in that tournament month's folder.
      if (!monthName) return
      const folder = `Tournament Logos/${monthName}`
      const { data: files, error: listError } = await supabase.storage.from('Admin').list(folder, {
        limit: 100,
        search: detail!.tournament_name,
      })
      if (cancelled || listError || !files?.length) return

      const wanted = detail!.tournament_name.toLocaleLowerCase()
      const exact = files.find((file) => file.name.replace(/\.[^.]+$/, '').toLocaleLowerCase() === wanted)
        ?? files.find((file) => file.name.toLocaleLowerCase().startsWith(wanted))
      if (!exact) return

      const { data: signed, error: signError } = await supabase.storage
        .from('Admin')
        .createSignedUrl(`${folder}/${exact.name}`, 60 * 60 * 24 * 7)
      if (!cancelled && !signError && signed?.signedUrl) setResolvedUrl(signed.signedUrl)
    }

    void resolveLogo()
    return () => { cancelled = true }
  }, [detail, monthName])

  useEffect(() => {
    if (!resolvedUrl) return
    let frame = 0
    let cancelled = false

    function findTarget() {
      if (cancelled) return
      const logoTarget = document.querySelector<HTMLElement>('.tlg-detail-logo-slot')
      if (!logoTarget) {
        frame = window.requestAnimationFrame(findTarget)
        return
      }
      logoTarget.classList.add('tlg-detail-logo-slot-recovered')
      logoTarget.querySelectorAll<HTMLElement>('.tlg-tournament-logo-image:not(.tlg-tournament-logo-image-recovered)')
        .forEach((image) => { image.style.display = 'none' })
      setTarget(logoTarget)
    }

    frame = window.requestAnimationFrame(findTarget)
    return () => {
      cancelled = true
      window.cancelAnimationFrame(frame)
      const logoTarget = document.querySelector<HTMLElement>('.tlg-detail-logo-slot')
      logoTarget?.classList.remove('tlg-detail-logo-slot-recovered')
      logoTarget?.querySelectorAll<HTMLElement>('.tlg-tournament-logo-image:not(.tlg-tournament-logo-image-recovered)')
        .forEach((image) => { image.style.display = '' })
      setTarget(null)
    }
  }, [resolvedUrl])

  if (!target || !resolvedUrl || !detail) return null

  return createPortal(
    <img
      className="tlg-tournament-logo-image tlg-tournament-logo-image-ready tlg-tournament-logo-image-recovered"
      src={resolvedUrl}
      alt={`${detail.tournament_name} tournament logo`}
      decoding="async"
    />,
    target,
  )
}
