import { Check, Crown, ShieldCheck, Sparkles, Star } from 'lucide-react'
import { Link } from 'react-router'
import { useTranslation } from 'react-i18next'

import { PREMIUM_INTELLIGENCE_IDS, premiumGuideCopy, type PremiumIntelligenceId } from '../../lib/premiumFeatureGuideI18n'
import { trainingEffectivenessLabels } from '../../lib/trainingEffectivenessI18n'
import { tournamentPlanningLabels } from '../../lib/tournamentPlanningI18n'
import { seasonPlanningLabels } from '../../lib/seasonPlanningI18n'
import { staffAdvisoryLabels } from '../../lib/staffAdvisoryI18n'
import { sponsorIntelligenceLabels } from '../../lib/sponsorIntelligenceI18n'
import { financialIntelligenceLabels } from '../../lib/financialIntelligenceI18n'
import { equipmentIntelligenceLabels } from '../../lib/equipmentIntelligenceI18n'
import { careerIntelligenceLabels } from '../../lib/careerIntelligenceI18n'
import { tournamentWatchLabels } from '../../lib/tournamentWatchI18n'
import '../../styles/premium-benefits-guide.css'

type Placement = 'homepage' | 'dialog' | 'packages'

export default function PremiumBenefitsGuide({ placement }: { placement: Placement }) {
  const { t, i18n } = useTranslation()
  const language = i18n.resolvedLanguage ?? i18n.language
  const l = premiumGuideCopy(language)
  const watchCopy = tournamentWatchLabels(language)
  const titleId = `tlg-premium-benefits-title-${placement}`

  // The same feature labels used inside the actual game, in the active language.
  const titles: Record<PremiumIntelligenceId, string> = {
    statistics: t('statisticsPage.premiumInsights.title'),
    deepMatch: t('deepMatchAnalysis.title'),
    development: t('developmentPremium.title'),
    training: trainingEffectivenessLabels(language).title,
    tournaments: tournamentPlanningLabels(language).title,
    season: seasonPlanningLabels(language).title,
    staff: staffAdvisoryLabels(language).title,
    sponsors: sponsorIntelligenceLabels(language).title,
    finance: financialIntelligenceLabels(language).title,
    equipment: equipmentIntelligenceLabels(language).title,
    career: careerIntelligenceLabels(language).title,
  }

  return (
    <section className={`tlg-premium-guide tlg-premium-guide--${placement}`} id={placement === 'homepage' ? 'premium-features' : undefined} aria-labelledby={titleId}>
      <header className="tlg-premium-guide-head">
        <span className="tlg-premium-guide-kicker"><Crown size={16} aria-hidden="true" /> {t('home.premium.eyebrow')}</span>
        <h2 id={titleId}>{l.heading}</h2>
        <p>{l.intro}</p>
      </header>

      <div className="tlg-premium-guide-free">
        <div>
          <h3><ShieldCheck size={19} aria-hidden="true" /> {l.freeTitle}</h3>
          <p>{l.freeIntro}</p>
        </div>
        <ul>{l.freeItems.map((item, index) => (
          <li key={index}><Check size={16} aria-hidden="true" /><span>{item}</span></li>
        ))}</ul>
      </div>

      <div className="tlg-premium-guide-premium-heading">
        <h3><Sparkles size={20} aria-hidden="true" /> {l.premiumTitle}</h3>
        <p>{l.premiumIntro}</p>
      </div>

      <div className="tlg-premium-guide-grid">
        {PREMIUM_INTELLIGENCE_IDS.map(id => (
          <article className="tlg-premium-guide-feature" key={id}>
            <h4>{titles[id]}</h4>
            <p>{l.modules[id]}</p>
          </article>
        ))}
      </div>

      <div className="tlg-premium-guide-extra">
        <h3>{l.extrasTitle}</h3>
        <ul>
          <li><Star size={16} aria-hidden="true" /><span><strong>{watchCopy.title}</strong> — {watchCopy.intro}</span></li>
          <li><Check size={16} aria-hidden="true" /><span>{l.ranking}</span></li>
          <li><Check size={16} aria-hidden="true" /><span>{l.privateLife}</span></li>
        </ul>
      </div>

      <div className="tlg-premium-guide-notes">
        <p>{l.trustNote}</p>
        <p>{l.coinsNote}</p>
        <p>{l.trialNote}</p>
      </div>
      {placement === 'homepage' && (
        <div className="tlg-premium-guide-action">
          <Link to="/register">{t('home.cta.create')}</Link>
        </div>
      )}
    </section>
  )
}
