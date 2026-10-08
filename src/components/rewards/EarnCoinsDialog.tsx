import { useCallback, useEffect, useState } from 'react'
import { createPortal } from 'react-dom'
import { Coins, ExternalLink, Loader2, RefreshCw, X } from 'lucide-react'
import { supabase } from '../../lib/supabase'

interface CpxRewardSummary {
  total_coins: number
  active_usd: number
  pending_coin_fraction: number
  recent: Array<{
    trans_id: string
    reward_type: string
    amount_usd: number
    status: number
    created_at: string
  }>
}

interface Props {
  open: boolean
  onClose: () => void
}

/** Tennis Legacy CPX surveys. Provider content is loaded only after player consent. */
export default function EarnCoinsDialog({ open, onClose }: Props) {
  const [surveyUrl, setSurveyUrl] = useState<string | null>(null)
  const [starting, setStarting] = useState(false)
  const [refreshing, setRefreshing] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [summary, setSummary] = useState<CpxRewardSummary | null>(null)

  const refresh = useCallback(async () => {
    setRefreshing(true)
    try {
      const { data, error: rpcError } = await supabase.rpc('get_my_cpx_tennis_reward_summary_v1')
      if (rpcError) throw rpcError
      setSummary((data ?? null) as CpxRewardSummary | null)
      window.dispatchEvent(new Event('tlg-coin-balance-changed'))
    } catch {
      // Survey availability/history errors must not disrupt gameplay.
    } finally {
      setRefreshing(false)
    }
  }, [])

  useEffect(() => {
    if (!open) {
      setSurveyUrl(null)
      setError(null)
      return
    }
    void refresh()
  }, [open, refresh])

  useEffect(() => {
    if (!open) return
    const onEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', onEscape)
    return () => document.removeEventListener('keydown', onEscape)
  }, [open, onClose])

  useEffect(() => {
    if (!open || !surveyUrl) return
    const interval = window.setInterval(() => { void refresh() }, 30000)
    return () => window.clearInterval(interval)
  }, [open, surveyUrl, refresh])

  async function startSurveys() {
    setStarting(true)
    setError(null)
    try {
      const { data: session, error: authError } = await supabase.auth.getSession()
      if (authError || !session.session?.access_token) throw new Error('Sign in required')

      const { data, error: callError } = await supabase.functions.invoke(
        'cpx-tennis-offerwall-link', { body: {} },
      )
      if (callError || typeof data?.url !== 'string') throw new Error('Offerwall unavailable')

      const url = new URL(data.url)
      if (url.protocol !== 'https:' || url.hostname !== 'offers.cpx-research.com' ||
          url.searchParams.get('app_id') !== '37031') {
        throw new Error('Unexpected survey destination')
      }
      setSurveyUrl(url.toString())
    } catch {
      setError('Surveys are temporarily unavailable. Please try again later.')
    } finally {
      setStarting(false)
    }
  }

  if (!open) return null

  return createPortal(
    <div className="tlg-cpx-overlay" role="presentation" onMouseDown={event => {
      if (event.target === event.currentTarget) onClose()
    }}>
      <section className="tlg-cpx-dialog" role="dialog" aria-modal="true"
        aria-labelledby="tlg-cpx-dialog-title">
        <header className="tlg-cpx-dialog-header">
          <div>
            <h2 id="tlg-cpx-dialog-title"><Coins size={22} /> Earn Free Coins</h2>
            <p>Complete optional surveys from CPX Research to support your tennis career.</p>
          </div>
          <button type="button" className="tlg-cpx-close" aria-label="Close surveys" onClick={onClose}>
            <X size={20} />
          </button>
        </header>

        <div className="tlg-cpx-dialog-body">
          <div className="tlg-cpx-stats">
            <div className="tlg-cpx-stat tlg-cpx-stat-rate">
              <strong>$1 publisher reward = 15 Coins</strong>
              <small>100 Reward Points = 15 Coins</small>
            </div>
            <div className="tlg-cpx-stat">
              <small>Net survey Coins</small>
              <strong>{summary?.total_coins ?? '—'}</strong>
            </div>
            <div className="tlg-cpx-stat">
              <small>Fractional Coins saved</small>
              <strong>{summary ? Number(summary.pending_coin_fraction).toFixed(2) : '—'}</strong>
            </div>
          </div>
          <p className="tlg-cpx-footnote">
            Coins are awarded after CPX confirms a survey. Canceled rewards may be reversed.
            Surveys depend on availability and may not always be offered.
          </p>

          {!surveyUrl ? (
            <div className="tlg-cpx-consent">
              <p>Opening surveys shares your game account identifier and connection data with
                CPX Research. Participation is completely optional.</p>
              {error && <p role="alert" className="tlg-cpx-error">{error}</p>}
              <button type="button" className="tlg-cpx-primary" disabled={starting}
                onClick={() => void startSurveys()}>
                {starting ? <Loader2 size={17} className="tlg-cpx-spin" /> : <Coins size={17} />}
                {starting ? 'Connecting…' : error ? 'Try again' : 'Browse Surveys'}
              </button>
            </div>
          ) : (
            <div className="tlg-cpx-surveys">
              <div className="tlg-cpx-survey-actions">
                <a href={surveyUrl} target="_blank" rel="noreferrer noopener">
                  <ExternalLink size={15} /> Open surveys in new tab
                </a>
                <button type="button" disabled={refreshing} onClick={() => void refresh()}>
                  <RefreshCw size={15} className={refreshing ? 'tlg-cpx-spin' : ''} />
                  Refresh rewards
                </button>
              </div>
              <iframe title="CPX Research surveys" src={surveyUrl} loading="lazy"
                referrerPolicy="no-referrer" allow="clipboard-read; clipboard-write"
                className="tlg-cpx-frame" />
            </div>
          )}

          <div className="tlg-cpx-history">
            <h3>Recent survey activity</h3>
            {summary?.recent?.length ? summary.recent.map(item => (
              <div key={item.trans_id} className="tlg-cpx-history-row">
                <span>{new Date(item.created_at).toLocaleDateString()} · Survey</span>
                <span className={item.status === 2 ? 'tlg-cpx-reversed' : 'tlg-cpx-completed'}>
                  {item.status === 2 ? 'Reversed' : 'Completed'} ·
                  {' $'}{Number(item.amount_usd).toFixed(2)}
                </span>
              </div>
            )) : <p className="tlg-cpx-footnote">No survey activity yet.</p>}
          </div>
        </div>
      </section>
    </div>, document.body,
  )
}
