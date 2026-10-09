import { useMemo, useState } from 'react'
import { createPortal } from 'react-dom'
import { useTranslation } from 'react-i18next'
import { X } from 'lucide-react'

import CountryFlag from '../common/CountryFlag'
import type {
  StaffContract,
  StaffDashboard,
  StaffMemberProfile,
  StaffRole,
} from '../../hooks/useStaff'
import { useLocalization } from '../../i18n/LocalizationProvider'
import {
  staffAttributeLabel,
  staffCadence,
  staffCourse,
  staffEducation,
  staffEffectLabel,
  staffQualityLabel,
  staffRoleCatalogText,
  staffRoleLabel,
  staffSpecialty,
  staffSystem,
} from '../../i18n/staffLocalization'
import '../../styles/staff-role-system.css'
import '../../styles/staff-role-overrides.css'

function formatGameDate(
  t: ReturnType<typeof useTranslation>['t'],
  date?: { season: number; month: number; day: number } | null,
) {
  if (!date) return '—'
  const months = t('staffPage.months', { returnObjects: true }) as string[]
  const month = months[date.month] ?? t('staffPage.profile.monthFallback', { month: date.month })
  return t('staffPage.profile.seasonDate', { month, day: date.day, season: date.season })
}

function AttributeRows({
  values,
  definitions,
}: {
  values: Record<string, number>
  definitions: Array<{ key: string; label: string; description: string }>
}) {
  const { t } = useTranslation()
  return (
    <div className="tlg-staff-profile-attributes">
      {definitions.map((attribute) => {
        const value = values[attribute.key] ?? 0
        const label = staffAttributeLabel(t, attribute.key, attribute.label)
        return (
          <div className="tlg-staff-profile-attribute" key={attribute.key} title={label}>
            <div className="tlg-staff-profile-attribute-top">
              <div>
                <strong>{label}</strong>
                <p>{attribute.description}</p>
              </div>
              <b>{value}</b>
            </div>
            <div className="tlg-staff-profile-attribute-track"><i style={{ width: `${Math.max(0, Math.min(100, value))}%` }} /></div>
          </div>
        )
      })}
    </div>
  )
}

function EffectRows({
  effects,
}: {
  effects: Array<{ label: string; current_display: string; maximum_display: string; cadence: string }>
}) {
  const { t } = useTranslation()
  return (
    <div className="tlg-staff-effect-table">
      {effects.map((effect) => (
        <div className="tlg-staff-effect-row" key={`${effect.label}-${effect.cadence}`}>
          <div><strong>{staffEffectLabel(t, effect.label)}</strong><span>{staffCadence(t, effect.cadence)}</span></div>
          <div><span>{t('staffPage.profile.current')}</span><strong>{effect.current_display}</strong></div>
          <div><span>{t('staffPage.profile.maximum')}</span><strong>{effect.maximum_display}</strong></div>
        </div>
      ))}
    </div>
  )
}

function StaffProfileDialog({
  profile,
  loading,
  error,
  onClose,
}: {
  profile: StaffMemberProfile | null
  loading: boolean
  error: string | null
  onClose: () => void
}) {
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()
  return createPortal(
    <div className="tlg-staff-profile-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}>
      <section className="tlg-staff-profile-dialog" role="dialog" aria-modal="true" aria-label={t('staffPage.profile.aria')}>
        <header className="tlg-staff-profile-dialog-head">
          <div><span>{t('staffPage.profile.eyebrow')}</span><h2>{profile ? `${profile.staff.first_name} ${profile.staff.last_name}` : t('staffPage.profile.title')}</h2></div>
          <button type="button" onClick={onClose} aria-label={t('staffPage.profile.close')}><X size={19} /></button>
        </header>

        {loading ? <div className="tlg-staff-profile-loading">{t('staffPage.profile.loading')}</div> : error ? <div className="tlg-staff-profile-error">{error}</div> : profile && (
          <div className="tlg-staff-profile-content">
            <section className="tlg-staff-profile-hero tlg-staff-profile-hero-clean">
              <div className="tlg-staff-profile-identity-copy">
                <span>{staffRoleLabel(t, profile.staff.role, profile.staff.role_label).toUpperCase()}</span>
                <div className="tlg-staff-profile-name-line">
                  <h3>{profile.staff.first_name} {profile.staff.last_name}</h3>
                  <CountryFlag countryCode={profile.staff.country_code} countryName={profile.staff.country_code} width={25} height={16} />
                </div>
                <p>{staffRoleCatalogText(t, profile.staff.role, 'responsibility', profile.role.main_responsibility)}</p>
              </div>
            </section>

            <section className="tlg-staff-profile-facts">
              <div><span>{t('staffPage.profile.age')}</span><strong>{profile.staff.age}</strong></div>
              <div><span>{t('staffPage.profile.experience')}</span><strong>{t('staffPage.profile.years', { count: profile.staff.experience_years })}</strong></div>
              <div><span>{t('staffPage.profile.specialty')}</span><strong>{staffSpecialty(t, profile.staff.specialty)}</strong></div>
              <div><span>{t('staffPage.profile.status')}</span><strong>{profile.contract.status === 'active' ? t('staffPage.profile.employedActive') : profile.contract.status}</strong></div>
              <div><span>{t('staffPage.profile.assignment')}</span><strong>{profile.current_assignment}</strong></div>
              <div><span>{t('staffPage.profile.weeklyWage')}</span><strong>{formatCurrency(profile.contract.weekly_salary, 'USD')}</strong></div>
            </section>

            <section className="tlg-staff-profile-section">
              <header><div><span>{t('staffPage.profile.playerBonuses')}</span><h3>{t('staffPage.profile.bonusesTitle')}</h3></div></header>
              <EffectRows effects={profile.current_effects} />
              <div className="tlg-staff-profile-rule-note"><span>{staffRoleCatalogText(t, profile.staff.role, 'stacking', profile.role.stacking_rule)}</span></div>
              <div className="tlg-staff-profile-engine-note">{t('staffPage.profile.engineNote')}</div>
            </section>

            <section className="tlg-staff-profile-section">
              <header><div><span>{t('staffPage.profile.attributes')}</span><h3>{t('staffPage.profile.attributesTitle')}</h3></div></header>
              <AttributeRows values={profile.staff.attributes} definitions={profile.role.attributes} />
            </section>

            <section className="tlg-staff-profile-two-column">
              <article>
                <header><div><span>{t('staffPage.profile.contract')}</span><h3>{t('staffPage.profile.currentEmployment')}</h3></div></header>
                <dl>
                  <div><dt>{t('staffPage.profile.start')}</dt><dd>{formatGameDate(t, profile.contract.start_game_day)}</dd></div>
                  <div><dt>{t('staffPage.profile.expiry')}</dt><dd>{formatGameDate(t, profile.contract.end_game_day)}</dd></div>
                  <div><dt>{t('staffPage.profile.remaining')}</dt><dd className={profile.contract.weeks_remaining <= 4 ? 'warning' : ''}>{t('staffPage.candidate.weeks', { count: profile.contract.weeks_remaining })}</dd></div>
                  <div><dt>{t('staffPage.profile.assignmentLabel')}</dt><dd>{profile.contract.assignment}</dd></div>
                </dl>
              </article>
              <article>
                <header><div><span>{t('staffPage.profile.facility')}</span><h3>{t('staffPage.profile.facilityTitle')}</h3></div></header>
                <p>{profile.facility.message}</p>
                <strong>{profile.facility.limited ? t('staffPage.profile.capActive') : t('staffPage.profile.noCap')}</strong>
              </article>
            </section>

            <section className="tlg-staff-profile-two-column">
              <article>
                <header><div><span>{t('staffPage.profile.education')}</span><h3>{t('staffPage.profile.qualifications')}</h3></div></header>
                <p>{staffEducation(t, profile.staff.education)}</p>
                <div className="tlg-staff-profile-courses">{profile.staff.courses.map((course) => <span key={course}>{staffCourse(t, course)}</span>)}</div>
              </article>
              <article>
                <header><div><span>{t('staffPage.profile.advisory')}</span><h3>{t('staffPage.profile.advisoryTitle')}</h3></div></header>
                <p>{profile.advisory.message}</p>
              </article>
            </section>

            <section className="tlg-staff-profile-role-review">
              <span>{t('staffPage.profile.roleDesign')}</span>
              <strong>{t('staffPage.profile.systemsInfluenced', { systems: profile.role.systems.map((system) => staffSystem(t, system)).join(' · ') })}</strong>
              <p>{staffRoleCatalogText(t, profile.staff.role, 'review', profile.role.review_note)}</p>
              <p><b>{t('staffPage.profile.vacantPosition')}</b> {staffRoleCatalogText(t, profile.staff.role, 'vacancy', profile.role.vacancy_behavior)}</p>
            </section>
          </div>
        )}
      </section>
    </div>,
    document.body,
  )
}

export default function StaffTeamRoles({
  dashboard,
  saving,
  onHire,
  onTerminate,
  loadProfile,
}: {
  dashboard: StaffDashboard
  saving: boolean
  onHire: (role: StaffRole) => void
  onTerminate: (contract: StaffContract) => void
  loadProfile: (staffId: string) => Promise<{ profile: StaffMemberProfile | null; error: string | null }>
}) {
  const { t } = useTranslation()
  const { formatCurrency } = useLocalization()
  const contractsByRole = useMemo(() => new Map(dashboard.contracts.map((contract) => [contract.role, contract])), [dashboard.contracts])
  const [profile, setProfile] = useState<StaffMemberProfile | null>(null)
  const [profileLoading, setProfileLoading] = useState(false)
  const [profileError, setProfileError] = useState<string | null>(null)
  const [profileOpen, setProfileOpen] = useState(false)

  async function openProfile(staffId: string) {
    setProfile(null)
    setProfileError(null)
    setProfileLoading(true)
    setProfileOpen(true)
    const result = await loadProfile(staffId)
    setProfile(result.profile)
    setProfileError(result.error)
    setProfileLoading(false)
  }

  const combined = dashboard.combined_effects

  return (
    <>
      <section className="tlg-staff-career-effects">
        <header><div><span>{t('staffPage.team.activeBenefits')}</span><h2>{t('staffPage.team.combinedEffects')}</h2></div><small>{t('staffPage.team.combinedNote')}</small></header>
        <div className="tlg-staff-career-effects-grid">
          <div><span>{t('staffPage.team.technicalTraining')}</span><strong>{combined.technical_training_display}</strong></div>
          <div><span>{t('staffPage.team.physicalTraining')}</span><strong>{combined.physical_training_display}</strong></div>
          <div><span>{t('staffPage.team.dayOffRecovery')}</span><strong>{combined.active_recovery_display}</strong><small>{t('staffPage.team.dayOffNote')}</small></div>
          <div><span>{t('staffPage.team.injuryRisk')}</span><strong>{combined.injury_risk_display}</strong><small>{t('staffPage.team.relativeReduction')}</small></div>
          <div><span>{t('staffPage.team.matchSupport')}</span><strong>{combined.match_support_display}</strong><small>{t('staffPage.team.globalCap')}</small></div>
          <div><span>{t('staffPage.team.sponsorValue')}</span><strong>{combined.sponsor_value_display}</strong></div>
        </div>
      </section>

      <section className="tlg-staff-role-guide">
        <header>
          <div><span>{t('staffPage.team.roleStructure')}</span><h2>{t('staffPage.team.positions')}</h2></div>
          <p>{t('staffPage.team.positionsBody')}</p>
        </header>
      </section>

      <section className="tlg-staff-team-grid tlg-staff-team-grid-v2">
        {dashboard.roles.map((role) => {
          const contract = contractsByRole.get(role.role)
          return (
            <article className={`tlg-staff-role-card tlg-staff-role-card-v2 ${contract ? 'filled' : 'empty'}`} key={role.role}>
              <header>
                <div><span>{staffRoleLabel(t, role.role, role.label).toUpperCase()}</span><p>{staffRoleCatalogText(t, role.role, 'responsibility', role.main_responsibility)}</p></div>
                <b>{contract ? contract.staff.overall_rating : t('staffPage.team.slot', { count: role.max_positions })}</b>
              </header>

              <div className="tlg-staff-role-systems">{role.systems.map((system) => <span key={system}>{staffSystem(t, system)}</span>)}</div>

              {contract ? (
                <>
                  <div className="tlg-staff-identity tlg-staff-identity-inline-flag">
                    <div>
                      <div className="tlg-staff-card-name-line">
                        <strong>{contract.staff.first_name} {contract.staff.last_name}</strong>
                        <CountryFlag countryCode={contract.staff.country_code} countryName={contract.staff.country_code} width={24} height={16} />
                      </div>
                      <span>{staffSpecialty(t, contract.staff.specialty)}</span>
                    </div>
                  </div>
                  <div className="tlg-staff-role-meta"><span>{staffQualityLabel(t, contract.staff.quality_tier, contract.staff.quality_label)}</span><span>{staffSpecialty(t, contract.staff.specialty)}</span></div>
                  <div className={`tlg-staff-contract-line ${contract.weeks_remaining <= 4 ? 'warning' : ''}`}><span>{t('staffPage.team.perWeek', { amount: formatCurrency(contract.weekly_salary, 'USD') })}</span><strong>{t('staffPage.team.weeksRemaining', { count: contract.weeks_remaining })}</strong></div>
                  <div className="tlg-staff-role-actions">
                    <button type="button" className="secondary" onClick={() => void openProfile(contract.staff.id)}>{t('staffPage.team.viewProfile')}</button>
                    <button type="button" className="secondary danger" disabled={saving} onClick={() => onTerminate(contract)}>{t('staffPage.team.endContract')}</button>
                  </div>
                </>
              ) : (
                <div className="tlg-staff-empty-role tlg-staff-empty-role-v2">
                  <strong>{t('staffPage.team.noAssigned', { role: staffRoleLabel(t, role.role, role.label).toLowerCase() })}</strong>
                  <p>{staffRoleCatalogText(t, role.role, 'vacancy', role.vacancy_behavior)}</p>
                  <button type="button" onClick={() => onHire(role.role)}>{t('staffPage.team.hire', { role: staffRoleLabel(t, role.role, role.label) })}</button>
                </div>
              )}
            </article>
          )
        })}
      </section>

      {profileOpen && <StaffProfileDialog profile={profile} loading={profileLoading} error={profileError} onClose={() => setProfileOpen(false)} />}
    </>
  )
}
