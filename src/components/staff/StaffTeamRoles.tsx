import { useMemo, useState } from 'react'
import { createPortal } from 'react-dom'
import {
  BookOpen,
  BriefcaseBusiness,
  Building2,
  CalendarDays,
  CircleHelp,
  GraduationCap,
  Info,
  X,
} from 'lucide-react'

import CountryFlag from '../common/CountryFlag'
import type {
  StaffContract,
  StaffDashboard,
  StaffMemberProfile,
  StaffRole,
} from '../../hooks/useStaff'
import '../../styles/staff-role-system.css'

const MONTHS = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]

function formatGameDate(date?: { season: number; month: number; day: number } | null) {
  if (!date) return '—'
  return `${MONTHS[date.month] ?? `Month ${date.month}`} ${date.day} · Season ${date.season}`
}

function initials(first: string, last: string) {
  return `${first.charAt(0)}${last.charAt(0)}`.toUpperCase()
}

function AttributeRows({
  values,
  definitions,
}: {
  values: Record<string, number>
  definitions: Array<{ key: string; label: string; description: string }>
}) {
  return (
    <div className="tlg-staff-profile-attributes">
      {definitions.map((attribute) => {
        const value = values[attribute.key] ?? 0
        return (
          <div className="tlg-staff-profile-attribute" key={attribute.key} title={attribute.description}>
            <div className="tlg-staff-profile-attribute-top">
              <div>
                <strong>{attribute.label}</strong>
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
  return (
    <div className="tlg-staff-effect-table">
      {effects.map((effect) => (
        <div className="tlg-staff-effect-row" key={`${effect.label}-${effect.cadence}`}>
          <div><strong>{effect.label}</strong><span>{effect.cadence}</span></div>
          <div><span>Current</span><strong>{effect.current_display}</strong></div>
          <div><span>Maximum</span><strong>{effect.maximum_display}</strong></div>
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
  return createPortal(
    <div className="tlg-staff-profile-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}>
      <section className="tlg-staff-profile-dialog" role="dialog" aria-modal="true" aria-label="Staff member profile">
        <header className="tlg-staff-profile-dialog-head">
          <div><span>STAFF PROFILE</span><h2>{profile ? `${profile.staff.first_name} ${profile.staff.last_name}` : 'Staff profile'}</h2></div>
          <button type="button" onClick={onClose} aria-label="Close staff profile"><X size={19} /></button>
        </header>

        {loading ? <div className="tlg-staff-profile-loading">Loading full staff profile…</div> : error ? <div className="tlg-staff-profile-error">{error}</div> : profile && (
          <div className="tlg-staff-profile-content">
            <section className="tlg-staff-profile-hero">
              <div className="tlg-staff-profile-avatar" aria-label="Staff avatar">
                {profile.staff.image_path ? <img src={profile.staff.image_path} alt="" /> : <span>{initials(profile.staff.first_name, profile.staff.last_name)}</span>}
              </div>
              <div className="tlg-staff-profile-identity-copy">
                <span>{profile.staff.role_label.toUpperCase()}</span>
                <h3>{profile.staff.first_name} {profile.staff.last_name}</h3>
                <div className="tlg-staff-profile-country"><CountryFlag countryCode={profile.staff.country_code} countryName={profile.staff.country_code} width={25} height={16} /> {profile.staff.country_code}</div>
                <p>{profile.role.main_responsibility}</p>
              </div>
              <div className="tlg-staff-profile-rating"><strong>{profile.staff.overall_rating}</strong><span>{profile.staff.quality_label}</span></div>
            </section>

            <section className="tlg-staff-profile-facts">
              <div><span>AGE</span><strong>{profile.staff.age}</strong></div>
              <div><span>EXPERIENCE</span><strong>{profile.staff.experience_years} years</strong></div>
              <div><span>SPECIALTY</span><strong>{profile.staff.specialty}</strong></div>
              <div><span>STATUS</span><strong>{profile.contract.status === 'active' ? 'Employed · Active' : profile.contract.status}</strong></div>
              <div><span>ASSIGNMENT</span><strong>{profile.current_assignment}</strong></div>
              <div><span>WEEKLY WAGE</span><strong>${profile.contract.weekly_salary.toLocaleString()}</strong></div>
            </section>

            <section className="tlg-staff-profile-section">
              <header><BriefcaseBusiness size={17} /><div><span>PLAYER BONUSES</span><h3>Bonuses this staff member provides to your player</h3></div></header>
              <EffectRows effects={profile.current_effects} />
              <div className="tlg-staff-profile-rule-note"><Info size={15} /><span>{profile.role.stacking_rule}</span></div>
            </section>

            <section className="tlg-staff-profile-section">
              <header><CircleHelp size={17} /><div><span>ATTRIBUTES</span><h3>How the rating affects gameplay</h3></div></header>
              <AttributeRows values={profile.staff.attributes} definitions={profile.role.attributes} />
            </section>

            <section className="tlg-staff-profile-two-column">
              <article>
                <header><CalendarDays size={16} /><div><span>CONTRACT</span><h3>Current employment</h3></div></header>
                <dl>
                  <div><dt>Start</dt><dd>{formatGameDate(profile.contract.start_game_day)}</dd></div>
                  <div><dt>Expiry</dt><dd>{formatGameDate(profile.contract.end_game_day)}</dd></div>
                  <div><dt>Remaining</dt><dd className={profile.contract.weeks_remaining <= 4 ? 'warning' : ''}>{profile.contract.weeks_remaining} weeks</dd></div>
                  <div><dt>Assignment</dt><dd>{profile.contract.assignment}</dd></div>
                </dl>
              </article>
              <article>
                <header><Building2 size={16} /><div><span>FACILITY LIMIT</span><h3>Applied vs potential</h3></div></header>
                <p>{profile.facility.message}</p>
                <strong>{profile.facility.limited ? 'Facility cap active' : 'No facility cap · full calculated bonus applied'}</strong>
              </article>
            </section>

            <section className="tlg-staff-profile-two-column">
              <article>
                <header><GraduationCap size={16} /><div><span>EDUCATION</span><h3>Qualifications & experience</h3></div></header>
                <p>{profile.staff.education}</p>
                <div className="tlg-staff-profile-courses">{profile.staff.courses.map((course) => <span key={course}>{course}</span>)}</div>
              </article>
              <article>
                <header><BookOpen size={16} /><div><span>STAFF ADVISORY</span><h3>Advisory availability</h3></div></header>
                <p>{profile.advisory.message}</p>
              </article>
            </section>

            <section className="tlg-staff-profile-role-review">
              <span>ROLE DESIGN</span>
              <strong>Systems influenced: {profile.role.systems.join(' · ')}</strong>
              <p>{profile.role.review_note}</p>
              <p><b>Vacant position:</b> {profile.role.vacancy_behavior}</p>
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
        <header><div><span>ACTIVE TEAM BENEFITS</span><h2>Combined career effects</h2></div><small>Bonuses are calculated centrally and update with your active contracts.</small></header>
        <div className="tlg-staff-career-effects-grid">
          <div><span>Technical training</span><strong>{combined.technical_training_display}</strong></div>
          <div><span>Physical training</span><strong>{combined.physical_training_display}</strong></div>
          <div><span>Day Off recovery</span><strong>{combined.active_recovery_display}</strong><small>Medical-staff bonus applied to player-selected Day Off</small></div>
          <div><span>Injury risk</span><strong>{combined.injury_risk_display}</strong><small>Relative reduction</small></div>
          <div><span>Match staff support</span><strong>{combined.match_support_display}</strong><small>Global cap +2.00%</small></div>
          <div><span>Sponsor offer value</span><strong>{combined.sponsor_value_display}</strong></div>
        </div>
      </section>

      <section className="tlg-staff-role-guide">
        <header>
          <div><span>ROLE STRUCTURE</span><h2>Your six career-support positions</h2></div>
          <p>One staff member per role. Core game functions continue when a position is vacant; only that role's staff bonus is missing.</p>
        </header>
      </section>

      <section className="tlg-staff-team-grid tlg-staff-team-grid-v2">
        {dashboard.roles.map((role) => {
          const contract = contractsByRole.get(role.role)
          return (
            <article className={`tlg-staff-role-card tlg-staff-role-card-v2 ${contract ? 'filled' : 'empty'}`} key={role.role}>
              <header>
                <div><span>{role.label.toUpperCase()}</span><p>{role.main_responsibility}</p></div>
                <b>{contract ? contract.staff.overall_rating : `${role.max_positions} SLOT`}</b>
              </header>

              <div className="tlg-staff-role-systems">{role.systems.map((system) => <span key={system}>{system}</span>)}</div>

              {contract ? (
                <>
                  <div className="tlg-staff-identity">
                    <CountryFlag countryCode={contract.staff.country_code} countryName={contract.staff.country_code} width={24} height={16} />
                    <div><strong>{contract.staff.first_name} {contract.staff.last_name}</strong><span>{contract.staff.country_code} · {contract.staff.specialty}</span></div>
                  </div>
                  <div className="tlg-staff-role-meta"><span>{contract.staff.quality_label}</span><span>{contract.staff.specialty}</span></div>
                  <div className={`tlg-staff-contract-line ${contract.weeks_remaining <= 4 ? 'warning' : ''}`}><span>${contract.weekly_salary.toLocaleString()} / week</span><strong>{contract.weeks_remaining} weeks remaining</strong></div>
                  <div className="tlg-staff-role-actions">
                    <button type="button" className="secondary" onClick={() => void openProfile(contract.staff.id)}>View full profile</button>
                    <button type="button" className="secondary danger" disabled={saving} onClick={() => onTerminate(contract)}>End Contract</button>
                  </div>
                </>
              ) : (
                <div className="tlg-staff-empty-role tlg-staff-empty-role-v2">
                  <strong>No {role.label.toLowerCase()} assigned</strong>
                  <p>{role.vacancy_behavior}</p>
                  <button type="button" onClick={() => onHire(role.role)}>Hire {role.label}</button>
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
