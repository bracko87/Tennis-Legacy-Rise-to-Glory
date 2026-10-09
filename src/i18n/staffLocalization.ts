import type { TFunction } from 'i18next'

import type { StaffQuality, StaffRole } from '../hooks/useStaff'

const ROLE_KEYS: Record<StaffRole, string> = {
  head_coach: 'headCoach',
  fitness_coach: 'fitnessCoach',
  physiotherapist: 'physiotherapist',
  sports_psychologist: 'sportsPsychologist',
  performance_analyst: 'performanceAnalyst',
  agent_manager: 'careerManager',
}

const QUALITY_KEYS: Record<StaffQuality, string> = {
  developing: 'developing',
  professional: 'professional',
  advanced: 'advanced',
  elite: 'elite',
  world_class: 'worldClass',
}

const SPECIALTY_KEYS: Record<string, string> = {
  'Clay Development': 'clayDevelopment',
  'Hard Court Development': 'hardCourtDevelopment',
  'Grass Development': 'grassDevelopment',
  'Technical Development': 'technicalDevelopment',
  'Match Preparation': 'matchPreparation',
  'Serve & Volley': 'serveVolley',
  'Stamina Specialist': 'staminaSpecialist',
  'Movement Specialist': 'movementSpecialist',
  'Recovery Specialist': 'recoverySpecialist',
  Conditioning: 'conditioning',
  'Workload Management': 'workloadManagement',
  'Injury Prevention': 'injuryPrevention',
  'Fatigue Recovery': 'fatigueRecovery',
  Rehabilitation: 'rehabilitation',
  Treatment: 'treatment',
  Confidence: 'confidence',
  'Pressure Matches': 'pressureMatches',
  'Morale Recovery': 'moraleRecovery',
  Focus: 'focus',
  'Opponent Analysis': 'opponentAnalysis',
  'Tactical Analysis': 'tacticalAnalysis',
  Scouting: 'scouting',
  Negotiation: 'negotiation',
  'Sponsorship Network': 'sponsorshipNetwork',
  'Commercial Reputation': 'commercialReputation',
  'Career Management': 'careerManagement',
}

const SYSTEM_KEYS: Record<string, string> = {
  'Regular training': 'regularTraining',
  'Training camps': 'trainingCamps',
  'Match preparation': 'matchPreparation',
  Recovery: 'recovery',
  'Injury risk': 'injuryRisk',
  Rehabilitation: 'rehabilitation',
  'Return to play': 'returnToPlay',
  'Mental condition': 'mentalCondition',
  'Match pressure': 'matchPressure',
  'Opponent scouting': 'opponentScouting',
  'Player reports': 'playerReports',
  Sponsorship: 'sponsorship',
  'Commercial career management': 'commercialCareerManagement',
}

const EFFECT_LABEL_KEYS: Record<string, string> = {
  'Technical training effectiveness': 'technicalTrainingEffectiveness',
  'Tennis-skill camp effectiveness': 'tennisCampEffectiveness',
  'Match preparation': 'matchPreparation',
  'Tournament match execution': 'tournamentMatchExecution',
  'Physical training effectiveness': 'physicalTrainingEffectiveness',
  'Physical camp effectiveness': 'physicalCampEffectiveness',
  'Training fatigue gain': 'trainingFatigueGain',
  'Tournament match fatigue gain': 'tournamentMatchFatigueGain',
  'Fatigue recovery efficiency': 'fatigueRecoveryEfficiency',
  'Injury-risk reduction': 'injuryRiskReduction',
  'Full-recovery duration': 'fullRecoveryDuration',
  'Training/tournament return delay': 'returnDelay',
  'Tournament match injury-risk reduction': 'tournamentInjuryRiskReduction',
  'Morale recovery': 'moraleRecovery',
  'Confidence recovery': 'confidenceRecovery',
  'Focus recovery': 'focusRecovery',
  'Pressure-match support': 'pressureMatchSupport',
  'Tournament pressure-match execution': 'tournamentPressureExecution',
  'Opponent estimate accuracy': 'opponentEstimateAccuracy',
  'Opponent preparation intelligence': 'opponentPreparationIntelligence',
  'Tournament tactical preparation': 'tournamentTacticalPreparation',
  'Sponsor offer value': 'sponsorOfferValue',
  'Tournament sponsor objective payout': 'tournamentSponsorPayout',
}

const CADENCE_KEYS: Record<string, string> = {
  'Each planned training session': 'eachTrainingSession',
  'Each tennis-skills camp development day': 'eachTennisCampDay',
  'Each competitive match': 'eachCompetitiveMatch',
  'Each tournament match when travelling with the player': 'eachTravellingTournamentMatch',
  'Each physical-camp development day': 'eachPhysicalCampDay',
  'Player-selected Day Off': 'selectedDayOff',
  'Every injury-risk roll': 'everyInjuryRiskRoll',
  'When a new injury is created': 'newInjury',
  'Recovery/rest session': 'recoverySession',
  'Whenever an opponent report is opened': 'opponentReportOpened',
  'From the moment the next opponent is known': 'opponentKnown',
  'When sponsor offers are generated or repriced': 'sponsorOfferGenerated',
  'When a tournament-specific sponsor objective is completed while travelling': 'travellingSponsorObjective',
}

const EDUCATION_KEYS: Record<string, string> = {
  'Performance Analysis & Data Qualification': 'performanceAnalysis',
  'Professional Tennis Coaching Diploma': 'tennisCoaching',
  'Sport Psychology Qualification': 'sportPsychology',
  'Sports Conditioning & Performance Diploma': 'conditioningPerformance',
  'Sports Management & Representation Diploma': 'managementRepresentation',
  'Sports Physiotherapy Qualification': 'physiotherapy',
}

const COURSE_KEYS: Record<string, string> = {
  'Advanced Player Development': 'advancedPlayerDevelopment',
  'Advanced Professional Development': 'advancedProfessionalDevelopment',
  'Athlete Career & Sponsorship Management': 'careerSponsorshipManagement',
  'Competitive Performance Psychology': 'performancePsychology',
  'Developing Professional Practice': 'developingPractice',
  'Elite Professional Development': 'eliteProfessionalDevelopment',
  'Professional Practice': 'professionalPractice',
  'Tennis Injury Management': 'injuryManagement',
  'Tennis Match Analysis': 'matchAnalysis',
  'Tennis Workload Management': 'workloadManagement',
  'World-Class Professional Development': 'worldClassProfessionalDevelopment',
}

const CHANCE_KEYS: Record<string, string> = {
  Accepted: 'accepted',
  'No chance': 'noChance',
  'Very unlikely': 'veryUnlikely',
  Unlikely: 'unlikely',
  Possible: 'possible',
  'Good chance': 'goodChance',
  'Strong chance': 'strongChance',
}

const BACKEND_TEXT_KEYS: Record<string, string> = {
  'Your professional team': 'professionalTeam',
  'No facility cap currently applies in Tennis Legacy. The calculated staff bonus is applied in full.': 'noFacilityCapMessage',
  'No separate Staff Advisory service is enabled for Tennis Legacy staff yet. Role effects shown here are the live gameplay effects.': 'advisoryUnavailable',
  'Your offer was accepted. Review and confirm the contract.': 'offerAcceptedReview',
  'The staff member accepted these terms. The contract starts only after you confirm.': 'acceptedTerms',
  'Negotiations ended after three rejected offers.': 'threeRejected',
  'World Class staff will not negotiate with players ranked outside the Top 500, regardless of salary.': 'worldClassRankRefusal',
  'Elite staff will not negotiate with players ranked outside the Top 1500.': 'eliteRankRefusal',
  'Ranking reflects sporting reputation; salary and contract length can improve the offer.': 'rankingReputation',
}

export function staffRoleLabel(t: TFunction, role: StaffRole, fallback?: string) {
  return t(`staffPage.roles.${ROLE_KEYS[role]}`, { defaultValue: fallback ?? role })
}

export function staffQualityLabel(t: TFunction, quality: StaffQuality, fallback?: string) {
  return t(`staffPage.qualities.${QUALITY_KEYS[quality]}`, { defaultValue: fallback ?? quality })
}

export function staffSpecialty(t: TFunction, source: string) {
  const key = SPECIALTY_KEYS[source]
  return key ? t(`staffPage.dynamic.specialties.${key}`) : source
}

export function staffSystem(t: TFunction, source: string) {
  const key = SYSTEM_KEYS[source]
  return key ? t(`staffPage.dynamic.systems.${key}`) : source
}

export function staffEffectLabel(t: TFunction, source: string) {
  const key = EFFECT_LABEL_KEYS[source]
  return key ? t(`staffPage.dynamic.effects.${key}`) : source
}

export function staffCadence(t: TFunction, source: string) {
  const key = CADENCE_KEYS[source]
  return key ? t(`staffPage.dynamic.cadences.${key}`) : source
}

export function staffEducation(t: TFunction, source: string) {
  const key = EDUCATION_KEYS[source]
  return key ? t(`staffPage.dynamic.education.${key}`) : source
}

export function staffCourse(t: TFunction, source: string) {
  const key = COURSE_KEYS[source]
  return key ? t(`staffPage.dynamic.courses.${key}`) : source
}

export function staffChanceLabel(t: TFunction, source?: string | null) {
  if (!source) return t('staffPage.unavailable')
  const key = CHANCE_KEYS[source]
  return key ? t(`staffPage.dynamic.chances.${key}`) : source
}

export function staffBackendText(t: TFunction, source?: string | null) {
  if (!source) return ''
  const key = BACKEND_TEXT_KEYS[source]
  return key ? t(`staffPage.dynamic.backend.${key}`) : source
}

export function staffAttributeLabel(t: TFunction, key: string, fallback?: string) {
  return t(`staffPage.attributes.${key}`, { defaultValue: fallback ?? key })
}

export function staffRoleCatalogText(
  t: TFunction,
  role: StaffRole,
  field: 'responsibility' | 'vacancy' | 'stacking' | 'review',
  fallback?: string | null,
) {
  return t(`staffPage.roleCatalog.${ROLE_KEYS[role]}.${field}`, { defaultValue: fallback ?? '' })
}


export function staffAttributeDescription(t: TFunction, key: string, fallback?: string) {
  return t(`staffPage.attributeDescriptions.${key}`, { defaultValue: fallback ?? '' })
}
