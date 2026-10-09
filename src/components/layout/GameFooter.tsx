import { Clock3, Coins } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { Link } from 'react-router'

import { useCommerce } from '../../hooks/useCommerce'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { useGameClock } from '../../hooks/useGameClock'
import { weekdayForDate } from '../../lib/competitionCalendar'
import { supabase } from '../../lib/supabase'

const PROPELOTON_URL = 'https://propelotonmanager.com/?source=tennis_legacy'
export default function GameFooter() {
  const { t } = useTranslation()
  const { localeTag, formatNumber } = useLocalization()
  const clock = useGameClock()
  const commerce = useCommerce()
  const weekday = weekdayForDate(clock.monthIndex, clock.day)

  function recordCrossGameClick() {
    void supabase.rpc('record_cross_game_referral_event_v1', {
      p_event_type: 'outgoing_click',
      p_source_game: 'tennis_legacy',
      p_destination_game: 'propeloton_manager',
      p_surface: 'game_footer',
    })
  }

  return (
    <footer className="tlg-v2-footer tlg-v4-footer tlg-v6-footer tlg-commerce-footer">
      <div className="tlg-v4-game-clock" aria-live="polite">
        <Clock3 size={15} />
        {clock.loading ? (
          <span>{t('footer.synchronizingClock')}</span>
        ) : clock.error ? (
          <span>{t('footer.clockUnavailable')}</span>
        ) : (
          <>
            <strong>{t('footer.season', { season: clock.season })}</strong>
            <span>·</span>
            <span>{weekday}, {clock.month} {clock.day}</span>
            <span>·</span>
            <span>{clock.formattedTime}</span>
          </>
        )}
      </div>

      <a
        href={PROPELOTON_URL}
        target="_blank"
        rel="noreferrer"
        onClick={recordCrossGameClick}
        aria-label={t('footer.proPelotonAria')}
        style={{
          marginLeft: 'auto',
          color: '#1377ad',
          fontSize: 11,
          fontWeight: 800,
          textDecoration: 'none',
          whiteSpace: 'nowrap',
        }}
      >
        {t('footer.alsoFromStudio')}
      </a>

      <Link
        to="/game/pro-packages"
        className="tlg-commerce-coin-balance"
        aria-label={t('footer.coinBalanceAria', { count: commerce.coins })}
        title={t('footer.coinStoreTitle')}
      >
        <Coins size={16} />
        <strong>{commerce.loading ? '—' : formatNumber(commerce.coins)}</strong>
        <span>{t('common.coins')}</span>
      </Link>
    </footer>
  )
}
