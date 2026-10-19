import { useEffect, useState } from 'react'
import { Trophy } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { supabase } from '../../lib/supabase'

type TournamentSummary = {
  competition_id: string
  tournament_name: string
  city: string
  category_code: string
  entry_status: string
  draw_type: string
}

type Detail = {
  logo_url: string | null
  winner_points: number | null
  main_draw_capacity: number | null
  competition_status: string | null
  environment: string | null
  schedule_slots: Array<{ calendar_month: number }> | null
}
type Rewards = { announced_prize_pool_usd?: number | null }

const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]

function storedAdminPath(url: string | null | undefined) {
  if (!url) return null
  const marker = '/storage/v1/object/sign/Admin/'
  const start = url.indexOf(marker)
  if (start < 0) return null
  try {
    return decodeURIComponent(url.slice(start + marker.length).split('?')[0])
  } catch {
    return null
  }
}

function readableStatus(text: string | null | undefined) {
  if (!text) return '—'
  return text.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

/** Uses existing tournament RPCs and stored Admin artwork, never invented prize/points. */
export default function NextTournamentExtras({ tournament }: { tournament: TournamentSummary }) {
  const { t } = useTranslation()
  const { formatCurrency, formatNumber } = useLocalization()
  const [detail, setDetail] = useState<Detail | null>(null)
  const [rewards, setRewards] = useState<Rewards | null>(null)
  const [logo, setLogo] = useState<string | null>(null)
  const [logoFailed, setLogoFailed] = useState(false)

  useEffect(() => {
    let active = true
    setDetail(null)
    setRewards(null)
    setLogo(null)
    setLogoFailed(false)

    async function load() {
      const [detailResult, rewardsResult] = await Promise.allSettled([
        supabase.rpc('get_tournament_detail_v1', { p_competition_id: tournament.competition_id }),
        supabase.rpc('get_tournament_rewards_v1', { p_competition_id: tournament.competition_id }),
      ])
      if (!active) return

      const detailResponse = detailResult.status === 'fulfilled' ? detailResult.value : null
      const rewardResponse = rewardsResult.status === 'fulfilled' ? rewardsResult.value : null
      const row = detailResponse && !detailResponse.error
        ? ((Array.isArray(detailResponse.data) ? detailResponse.data[0] : detailResponse.data) as Detail | null)
        : null

      setDetail(row)
      if (rewardResponse && !rewardResponse.error) setRewards(rewardResponse.data as Rewards | null)

      const storedPath = storedAdminPath(row?.logo_url)
      if (storedPath) {
        const { data, error } = await supabase.storage.from('Admin').createSignedUrl(storedPath, 3600)
        if (active && !error && data?.signedUrl) {
          setLogo(data.signedUrl)
          return
        }
      }

      // Recover an uploaded tournament logo when its database reference is absent.
      const month = row?.schedule_slots?.[0]?.calendar_month
      if (!month || month < 1 || month > 12) return
      const folder = `Tournament Logos/${MONTHS[month - 1]}`
      const { data: files, error } = await supabase.storage.from('Admin').list(folder, {
        search: tournament.tournament_name,
        limit: 30,
      })
      if (!active || error || !files?.length) return
      const exact = files.find((file) =>
        file.name.replace(/\.[^.]+$/, '').toLocaleLowerCase() === tournament.tournament_name.toLocaleLowerCase())
      if (!exact) return
      const signed = await supabase.storage.from('Admin').createSignedUrl(`${folder}/${exact.name}`, 3600)
      if (active && !signed.error) setLogo(signed.data?.signedUrl ?? null)
    }

    void load()
    return () => { active = false }
  }, [tournament.competition_id, tournament.tournament_name])

  const values = [
    { label: t('overviewPage.extra.prizePool'), value: rewards?.announced_prize_pool_usd != null ? formatCurrency(rewards.announced_prize_pool_usd, 'USD') : null },
    { label: t('overviewPage.extra.winnerPoints'), value: detail?.winner_points != null ? formatNumber(detail.winner_points) : null },
    { label: t('overviewPage.extra.mainDraw'), value: detail?.main_draw_capacity != null ? formatNumber(detail.main_draw_capacity) : null },
    { label: t('overviewPage.extra.environment'), value: detail?.environment ? readableStatus(detail.environment) : null },
    { label: t('overviewPage.extra.status'), value: detail?.competition_status ? readableStatus(detail.competition_status) : null },
    { label: t('overviewPage.extra.yourEntry'), value: readableStatus(tournament.entry_status) },
  ]

  return (
    <div className="tlg-overview-tournament-extras">
      <div className="tlg-overview-tournament-facts">
        <strong className="tlg-overview-extras-heading">{t('overviewPage.extra.atAGlance')}</strong>
        <div className="tlg-overview-tournament-facts-grid">
          {values.filter((item) => item.value !== null).map((item) =>
            <div key={item.label}><span>{item.label}</span><strong>{item.value}</strong></div>)}
        </div>
      </div>
      <div className="tlg-overview-tournament-art">
        {logo && !logoFailed
          ? <img src={logo} alt={t('overviewPage.extra.logoAlt', { name: tournament.tournament_name })} onError={() => setLogoFailed(true)} />
          : <div className="tlg-overview-tournament-art-fallback"><Trophy size={42} aria-hidden="true" /><strong>{tournament.tournament_name}</strong></div>}
      </div>
    </div>
  )
}
