import {
  CalendarDays,
  ChevronRight,
  Hotel,
  MapPin,
  Plane,
  ShieldCheck,
  SlidersHorizontal,
  Users,
  X,
} from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { Link, useSearchParams } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import { useCommerce } from '../../hooks/useCommerce'
import CountryFlag from '../../components/common/CountryFlag'
import GameLayout from '../../components/layout/GameLayout'
import TournamentJetPicker from '../../components/private-life/TournamentJetPicker'
import { lifestyleCopy } from '../../lib/lifestyleCareerI18n'
import { useStaff, type StaffRole } from '../../hooks/useStaff'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { staffEffectLabel, staffRoleLabel } from '../../i18n/staffLocalization'
import { supabase } from '../../lib/supabase'
import {
  BALANCED_TACTIC,
  TACTIC_OPTIONS,
  TACTIC_PRESETS,
  tacticFromPreset,
  type TournamentTactic,
} from '../../lib/tournamentTactics'
import '../../styles/schedule-operations.css'
import '../../styles/schedule-operations-v2.css'

interface TournamentSummaryItem {
  competition_id: string
  season: number
  start_week: number
  end_week: number
  tournament_name: string
  city: string
  country_code: string
  category_code: string
  category_label: string
  surface: string
  logo_url: string | null
}

interface PlayerTournamentSummary {
  next_tournaments: TournamentSummaryItem[]
}

interface TournamentApplicationItem {
  competition_id: string
  season: number
  start_week: number
  end_week: number
  tournament_name: string
  city: string
  country_code: string
  category_code: string
  category_label: string
  surface: string
  status_code: string
  status_label: string
  draw_type?: string | null
  partner_name?: string | null
  partner_country_code?: string | null
}

interface TournamentApplicationHistory {
  singles: TournamentApplicationItem[]
  doubles: TournamentApplicationItem[]
}

type PreparationTab = 'travel' | 'staff' | 'tactics' | 'summary'
type TravelClass = 'Economy' | 'Premium Economy' | 'Business' | 'First Class'
type HotelTier = 'Budget' | 'Standard' | 'Premium' | 'Luxury'

interface TravelEngineLeg {
  band: string
  basis: string
  distance_km: number | null
  round_trip_km: number | null
  cost: number
  cost_one_way: number
  base_cost_one_way: number
  travel_class: TravelClass
  price_multiplier: number
  base_arrival_fatigue: number
  arrival_fatigue: number
  fatigue_multiplier: number
  estimated_hours_one_way: number
  formula: string
  source?: { city?: string; country_code?: string }
  destination?: { city?: string; country_code?: string }
}

interface AccommodationEngineQuote {
  adjusted_unit_cost: number
  base_unit_cost: number
  destination_cost_index: number
  cost_tier: string
  units: number
  party_size: number
  total: number
}

interface TournamentStaffEffectItem {
  contract_id: string
  role: string
  name: string
  overall_rating: number
  benefit_label: string
  benefit_value: string
  active_tournament_effect: boolean
}

interface TournamentStaffEffects {
  selected_count: number
  match_staff_multiplier: number
  match_execution_bonus_pct: number
  match_fatigue_reduction: number
  match_fatigue_reduction_pct: number
  injury_prevention_reduction: number
  injury_risk_reduction_pct: number
  commercial_bonus_multiplier: number
  commercial_bonus_pct: number
  staff: TournamentStaffEffectItem[]
}

interface TournamentPreparationQuote {
  engine: string
  origin: { city?: string; country_code?: string; continuity?: string }
  destination: { city: string; country_code: string }
  draw_type: string
  minimum_nights: number
  maximum_nights: number
  party_size: number
  staff_count: number
  player_travel: TravelEngineLeg
  staff_travel: TravelEngineLeg
  player_travel_cost: number
  staff_travel_cost: number
  private_jet?: { active?: boolean; name?: string; staff_on_jet?: number; staff_commercial?: number }
  staff_effects?: TournamentStaffEffects
  minimum_total: number
  maximum_total: number
  hotel: {
    tier: HotelTier
    label: string
    base_nightly_cost: number
    recovery_support_pct: number
    minimum: AccommodationEngineQuote
    maximum: AccommodationEngineQuote
  }
}

interface PreparationPlanResponse {
  saved: boolean
  player_travel_class: TravelClass
  staff_travel_class: TravelClass
  hotel_tier: HotelTier
  selected_staff_contract_ids: string[]
  tactic: TournamentTactic
  quote?: TournamentPreparationQuote
  updated_at?: string
}

const TRAVEL_CLASSES: TravelClass[] = ['Economy', 'Premium Economy', 'Business', 'First Class']
const HOTEL_TIERS: Array<{ value: HotelTier; nightly: number }> = [
  { value: 'Budget', nightly: 90 },
  { value: 'Standard', nightly: 150 },
  { value: 'Premium', nightly: 240 },
  { value: 'Luxury', nightly: 420 },
]

function tournamentWeekLabel(item: Pick<TournamentSummaryItem, 'season' | 'start_week' | 'end_week'>, t: TFunction) {
  if (item.start_week === item.end_week) return t('schedulePage.weekSingle', { season: item.season, week: item.start_week })
  return t('schedulePage.weekRange', { season: item.season, start: item.start_week, end: item.end_week })
}

function surfaceLabel(value: string, t: TFunction) {
  return t(`schedulePage.surface.${value.toLowerCase()}`, { defaultValue: value.charAt(0).toUpperCase() + value.slice(1) })
}

function tacticLabel(value: string, t: TFunction) {
  return t(`schedulePage.tacticValues.${value}`, { defaultValue: value })
}

function travelClassEffect(value: TravelClass, t: TFunction) {
  return t(`schedulePage.preparation.travelInfo.${value}`)
}

function hotelInfo(value: HotelTier, t: TFunction) {
  return {
    label: t(`schedulePage.preparation.hotelInfo.${value}.label`),
    detail: t(`schedulePage.preparation.hotelInfo.${value}.detail`),
    effect: t(`schedulePage.preparation.hotelInfo.${value}.effect`),
  }
}

function formatPlanSummary(playerClass: TravelClass, selectedHotelTier: HotelTier, staffCount: number, tacticPreset: string, t: TFunction) {
  const selectedHotel = hotelInfo(selectedHotelTier, t)
  return `${playerClass} · ${selectedHotel.label} · ${staffCount === 0 ? t('schedulePage.preparation.playerOnly') : t('schedulePage.preparation.staffCount', { count: staffCount })} · ${tacticLabel(tacticPreset, t)}`
}

function distance(value: number | null | undefined, t: TFunction, formatNumber: (value: number) => string) {
  return value == null ? t('schedulePage.preparation.distanceUnavailable') : `${formatNumber(Math.round(value))} km`
}

function tournamentStaffEffectsSummary(effects: TournamentStaffEffects, t: TFunction) {
  const values: string[] = []
  if (effects.match_execution_bonus_pct > 0) values.push(t('schedulePage.preparation.staffEffect.match', { value: effects.match_execution_bonus_pct }))
  if (effects.match_fatigue_reduction_pct > 0) values.push(t('schedulePage.preparation.staffEffect.fatigue', { value: effects.match_fatigue_reduction_pct }))
  if (effects.injury_risk_reduction_pct > 0) values.push(t('schedulePage.preparation.staffEffect.injury', { value: effects.injury_risk_reduction_pct }))
  if (effects.commercial_bonus_pct > 0) values.push(t('schedulePage.preparation.staffEffect.sponsor', { value: effects.commercial_bonus_pct }))
  return values.length > 0 ? values.join(' · ') : t('schedulePage.preparation.staffEffect.none')
}

function applicationStatusTone(status: string) {
  if (['accepted_main_draw', 'accepted_qualification', 'active', 'confirmed', 'champion'].includes(status)) return 'positive'
  if (['applied', 'looking_for_partner', 'alternate', 'waitlisted'].includes(status)) return 'pending'
  if (['rejected', 'withdrawn', 'canceled', 'cancelled', 'listing_cancelled', 'listing_expired'].includes(status)) return 'negative'
  return 'neutral'
}

function TournamentApplicationList({
  title,
  subtitle,
  items,
  doubles = false,
}: {
  title: string
  subtitle: string
  items: TournamentApplicationItem[]
  doubles?: boolean
}) {
  const { t } = useTranslation()
  return (
    <section className="tlg-schedule-application-group">
      <header>
        <div><span>{doubles ? t('schedulePage.doubles') : t('schedulePage.singles')}</span><h3>{title}</h3><p>{subtitle}</p></div>
        <strong>{t('schedulePage.tournamentCount', { count: items.length })}</strong>
      </header>

      {items.length === 0 ? (
        <div className="tlg-schedule-application-empty">{t('schedulePage.noApplications', { discipline: doubles ? t('schedulePage.doubles').toLowerCase() : t('schedulePage.singles').toLowerCase() })}</div>
      ) : (
        <div className="tlg-schedule-application-table">
          <div className="tlg-schedule-application-row head" aria-hidden="true">
            <span>{t('schedulePage.columns.tournament')}</span><span>{t('schedulePage.columns.schedule')}</span><span>{t('schedulePage.columns.categorySurface')}</span><span>{doubles ? t('schedulePage.columns.partner') : t('schedulePage.columns.entry')}</span><span>{t('schedulePage.columns.status')}</span>
          </div>
          {items.map((item) => {
            const entryDetail = doubles
              ? (item.partner_name ? t('schedulePage.withPartner', { name: item.partner_name }) : t('schedulePage.partnerNotConfirmed'))
              : item.draw_type === 'main_draw'
                ? t('schedulePage.mainDraw')
                : item.draw_type === 'qualification'
                  ? t('schedulePage.qualification')
                  : t('schedulePage.application')
            const href = doubles
              ? `/game/tournaments/${item.competition_id}/doubles`
              : `/game/tournaments/${item.competition_id}`

            return (
              <Link key={`${doubles ? 'd' : 's'}-${item.competition_id}`} to={href} className="tlg-schedule-application-row">
                <div className="tlg-schedule-application-name">
                  <CountryFlag countryCode={item.country_code} countryName={item.country_code} width={24} height={16} />
                  <div><strong>{item.tournament_name}</strong><small>{item.city}, {item.country_code}</small></div>
                </div>
                <span>{tournamentWeekLabel(item, t)}</span>
                <span>{item.category_label} · {surfaceLabel(item.surface, t)}</span>
                <span>{entryDetail}</span>
                <strong className={`tlg-schedule-application-status ${applicationStatusTone(item.status_code)}`}>{t(`calendarPage.tournament.userStatus.${item.status_code}`, { defaultValue: item.status_label })}</strong>
              </Link>
            )
          })}
        </div>
      )}
    </section>
  )
}

export default function SchedulePage() {
  const { t, i18n } = useTranslation()
  const lifestyleLabels = lifestyleCopy(i18n.resolvedLanguage ?? i18n.language)
  const { formatCurrency, formatNumber } = useLocalization()
  const money = (value: number) => formatCurrency(Math.round(value), 'USD')
  const { player, playerLoading } = useAuth()
  const { isPremium, loading: membershipLoading } = useCommerce()
  const { dashboard: staffDashboard, loading: staffLoading } = useStaff()
  const [searchParams, setSearchParams] = useSearchParams()
  const requestedCompetitionId = searchParams.get('competition')
  const shouldOpenPreparation = searchParams.get('prepare') === '1'
  const [upcoming, setUpcoming] = useState<TournamentSummaryItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [prepareOpen, setPrepareOpen] = useState(false)
  const [activeTab, setActiveTab] = useState<PreparationTab>('travel')
  const [playerTravelClass, setPlayerTravelClass] = useState<TravelClass>('Economy')
  const [staffTravelClass, setStaffTravelClass] = useState<TravelClass>('Economy')
  const [hotelTier, setHotelTier] = useState<HotelTier>('Standard')
  const [selectedStaff, setSelectedStaff] = useState<string[]>([])
  const [tactics, setTactics] = useState<TournamentTactic>({ ...BALANCED_TACTIC })
  const [planSaved, setPlanSaved] = useState(false)
  const [hasUnsavedChanges, setHasUnsavedChanges] = useState(false)
  const [savedPlanSummary, setSavedPlanSummary] = useState<string | null>(null)
  const [planLoading, setPlanLoading] = useState(false)
  const [planSaving, setPlanSaving] = useState(false)
  const [planMessage, setPlanMessage] = useState<string | null>(null)
  const [engineQuote, setEngineQuote] = useState<TournamentPreparationQuote | null>(null)
  const [quoteLoading, setQuoteLoading] = useState(false)
  const [travelModeRevision, setTravelModeRevision] = useState(0)
  const [applicationHistory, setApplicationHistory] = useState<TournamentApplicationHistory>({ singles: [], doubles: [] })
  const [applicationsLoading, setApplicationsLoading] = useState(true)
  const [applicationsError, setApplicationsError] = useState<string | null>(null)

  useEffect(() => {
    if (!player?.id) {
      setUpcoming([])
      setLoading(false)
      return
    }
    let cancelled = false
    async function loadSchedule() {
      setLoading(true)
      setError(null)
      const { data, error: rpcError } = await supabase.rpc('get_player_tournament_summary_v1', { p_player_id: player!.id })
      if (cancelled) return
      if (rpcError) {
        setUpcoming([])
        setError(rpcError.message)
      } else {
        const summary = (data ?? { next_tournaments: [] }) as PlayerTournamentSummary
        setUpcoming(summary.next_tournaments ?? [])
      }
      setLoading(false)
    }
    void loadSchedule()
    return () => { cancelled = true }
  }, [player?.id])

  useEffect(() => {
    if (!player?.id) {
      setApplicationHistory({ singles: [], doubles: [] })
      setApplicationsLoading(false)
      setApplicationsError(null)
      return
    }

    let cancelled = false
    async function loadApplications() {
      setApplicationsLoading(true)
      setApplicationsError(null)
      const { data, error: applicationError } = await supabase.rpc('get_player_tournament_application_history_v1', {
        p_player_id: player!.id,
      })
      if (cancelled) return
      if (applicationError) {
        setApplicationHistory({ singles: [], doubles: [] })
        setApplicationsError(applicationError.message)
      } else {
        const history = (data ?? { singles: [], doubles: [] }) as TournamentApplicationHistory
        setApplicationHistory({
          singles: history.singles ?? [],
          doubles: history.doubles ?? [],
        })
      }
      setApplicationsLoading(false)
    }

    void loadApplications()
    return () => { cancelled = true }
  }, [player?.id])

  const nextTournament = useMemo(
    () => upcoming.find((item) => item.competition_id === requestedCompetitionId) ?? upcoming[0] ?? null,
    [requestedCompetitionId, upcoming],
  )
  const laterTournaments = useMemo(
    () => upcoming.filter((item) => item.competition_id !== nextTournament?.competition_id),
    [nextTournament?.competition_id, upcoming],
  )
  const activeStaff = staffDashboard?.contracts ?? []

  useEffect(() => {
    if (!player?.id || !nextTournament?.competition_id) {
      setPlanSaved(false)
      setHasUnsavedChanges(false)
      setSavedPlanSummary(null)
      setEngineQuote(null)
      return
    }
    let cancelled = false
    async function loadPreparation() {
      setPlanLoading(true)
      setPlanMessage(null)
      const { data, error: planError } = await supabase.rpc('get_tournament_preparation_v1', {
        p_player_id: player!.id,
        p_competition_id: nextTournament!.competition_id,
      })
      if (cancelled) return
      setPlanLoading(false)
      if (planError || !data) {
        setPlanMessage(planError?.message ?? t('schedulePage.preparation.loadError'))
        return
      }
      const plan = data as PreparationPlanResponse
      const loadedPlayerTravelClass = plan.player_travel_class ?? 'Economy'
      const loadedStaffTravelClass = plan.staff_travel_class ?? 'Economy'
      const loadedHotelTier = plan.hotel_tier ?? 'Standard'
      const loadedStaff = plan.selected_staff_contract_ids ?? []
      const loadedTactic = plan.tactic ?? { ...BALANCED_TACTIC }
      setPlayerTravelClass(loadedPlayerTravelClass)
      setStaffTravelClass(loadedStaffTravelClass)
      setHotelTier(loadedHotelTier)
      setSelectedStaff(loadedStaff)
      setTactics(loadedTactic)
      setPlanSaved(Boolean(plan.saved))
      setHasUnsavedChanges(false)
      setSavedPlanSummary(plan.saved ? formatPlanSummary(loadedPlayerTravelClass, loadedHotelTier, loadedStaff.length, loadedTactic.preset, t) : null)
      setEngineQuote(plan.quote ?? null)
    }
    void loadPreparation()
    return () => { cancelled = true }
  }, [nextTournament?.competition_id, player?.id])

  useEffect(() => {
    if (
      loading
      || !shouldOpenPreparation
      || !requestedCompetitionId
      || nextTournament?.competition_id !== requestedCompetitionId
    ) return

    setActiveTab('travel')
    setPlanMessage(null)
    setPrepareOpen(true)

    const nextParams = new URLSearchParams(searchParams)
    nextParams.delete('prepare')
    setSearchParams(nextParams, { replace: true })
  }, [
    loading,
    nextTournament?.competition_id,
    requestedCompetitionId,
    searchParams,
    setSearchParams,
    shouldOpenPreparation,
  ])

  useEffect(() => {
    if (!prepareOpen || planLoading || !player?.id || !nextTournament?.competition_id) return
    let cancelled = false
    const timer = window.setTimeout(async () => {
      setQuoteLoading(true)
      const { data, error: quoteError } = await supabase.rpc('quote_tournament_preparation_v1', {
        p_player_id: player.id,
        p_competition_id: nextTournament.competition_id,
        p_player_travel_class: playerTravelClass,
        p_staff_travel_class: staffTravelClass,
        p_hotel_tier: hotelTier,
        p_selected_staff_contract_ids: selectedStaff,
      })
      if (cancelled) return
      setQuoteLoading(false)
      if (quoteError || !data) {
        setPlanMessage(quoteError?.message ?? t('schedulePage.preparation.quoteError'))
        return
      }
      setEngineQuote(data as TournamentPreparationQuote)
    }, 80)
    return () => {
      cancelled = true
      window.clearTimeout(timer)
    }
  }, [prepareOpen, planLoading, player?.id, nextTournament?.competition_id, playerTravelClass, staffTravelClass, hotelTier, selectedStaff, travelModeRevision])

  const selectedStaffNames = useMemo(
    () => activeStaff.filter((contract) => selectedStaff.includes(contract.contract_id)).map((contract) => `${contract.staff.first_name} ${contract.staff.last_name}`),
    [activeStaff, selectedStaff],
  )

  const hotel = HOTEL_TIERS.find((tier) => tier.value === hotelTier) ?? HOTEL_TIERS[1]
  const hotelCopy = hotelInfo(hotelTier, t)
  const estimate = engineQuote

  function openPreparation() {
    setActiveTab('travel')
    setPlanMessage(null)
    setPrepareOpen(true)
  }

  function markPlanDirty() {
    setHasUnsavedChanges(true)
    setPlanMessage(null)
  }

  function toggleStaff(contractId: string) {
    markPlanDirty()
    setSelectedStaff((current) => current.includes(contractId) ? current.filter((id) => id !== contractId) : [...current, contractId])
  }

  function applyPreset(preset: string) {
    markPlanDirty()
    setTactics(tacticFromPreset(preset))
  }

  async function savePreparation() {
    if (!player?.id || !nextTournament) return
    setPlanSaving(true)
    setPlanMessage(null)
    const { data, error: saveError } = await supabase.rpc('save_tournament_preparation_v1', {
      p_player_id: player.id,
      p_competition_id: nextTournament.competition_id,
      p_player_travel_class: playerTravelClass,
      p_staff_travel_class: staffTravelClass,
      p_hotel_tier: hotelTier,
      p_selected_staff_contract_ids: selectedStaff,
      p_tactic_preset: tactics.preset,
      p_tactic_approach: tactics.approach,
      p_tactic_rally: tactics.rally,
      p_tactic_serve: tactics.serve,
      p_tactic_serve_placement: tactics.servePlacement,
      p_tactic_return: tactics.returnGame,
      p_tactic_return_position: tactics.returnPosition,
      p_tactic_court_position: tactics.courtPosition,
      p_tactic_target: tactics.target,
      p_tactic_risk: tactics.risk,
    })
    setPlanSaving(false)
    if (saveError || !data) {
      setPlanMessage(saveError?.message ?? t('schedulePage.preparation.saveError'))
      return
    }
    const saved = data as PreparationPlanResponse
    const savedStaff = saved.selected_staff_contract_ids ?? []
    const savedTactic = saved.tactic ?? tactics
    setPlanSaved(true)
    setHasUnsavedChanges(false)
    setPlanMessage(t('schedulePage.preparation.savedMessage'))
    setPlayerTravelClass(saved.player_travel_class)
    setStaffTravelClass(saved.staff_travel_class)
    setHotelTier(saved.hotel_tier)
    setSelectedStaff(savedStaff)
    setTactics(savedTactic)
    setSavedPlanSummary(formatPlanSummary(saved.player_travel_class, saved.hotel_tier, savedStaff.length, savedTactic.preset, t))
    setEngineQuote(saved.quote ?? engineQuote)
  }

  const planSummary = savedPlanSummary ?? t('schedulePage.defaultPlan')

  return (
    <GameLayout title={t('schedulePage.title')} subtitle={t('schedulePage.subtitle')}>
      <div className="tlg-schedule-page">
        <section className="tlg-schedule-hero">
          <div className="tlg-schedule-section-head">
            <div>
              <span>{t('schedulePage.nextTournament')}</span>
              <h2>{t('schedulePage.nextHeading')}</h2>
              <p>{t('schedulePage.nextIntro')}</p>
            </div>
          </div>

          {loading || playerLoading ? <div className="tlg-schedule-empty">{t('schedulePage.loadingSchedule')}</div> : error ? <div className="tlg-schedule-error">{t('schedulePage.loadError', { error })}</div> : !nextTournament ? (
            <div className="tlg-schedule-empty tlg-schedule-empty-large">
              <CalendarDays size={28} />
              <strong>{t('schedulePage.noTournament')}</strong>
              <p>{t('schedulePage.noTournamentBody')}</p>
              <Link to="/game/calendar?tab=tournament-calendar">{t('schedulePage.openCalendar')}</Link>
            </div>
          ) : (
            <div className="tlg-next-tournament-card">
              <div className="tlg-next-tournament-main">
                <div className="tlg-next-tournament-location">
                  <CountryFlag countryCode={nextTournament.country_code} countryName={nextTournament.country_code} width={34} height={23} />
                  <div>
                    <span>{nextTournament.category_label}</span>
                    <h3>{nextTournament.tournament_name}</h3>
                    <p><MapPin size={14} /> {nextTournament.city}, {nextTournament.country_code}</p>
                  </div>
                </div>

                <div className="tlg-next-tournament-actions">
                  <button type="button" className="primary" onClick={openPreparation}>{t('schedulePage.prepareTournament')}</button>
                  <Link to={`/game/tournaments/${nextTournament.competition_id}`}>{t('schedulePage.openTournament')} <ChevronRight size={15} /></Link>
                </div>

                <div className={`tlg-default-plan-strip${planSaved ? ' saved' : ''}`}>
                  <div><span>{planSaved ? t('schedulePage.savedPreparation') : t('schedulePage.automaticDefault')}</span><strong>{planSaved ? planSummary : t('schedulePage.defaultPlan')}</strong></div>
                  <p>{planSaved ? t('schedulePage.savedPlanBody', { name: nextTournament.tournament_name }) : t('schedulePage.defaultPlanBody')}</p>
                </div>

                <div className="tlg-next-tournament-meta">
                  <div><span>{t('schedulePage.meta.schedule')}</span><strong>{tournamentWeekLabel(nextTournament, t)}</strong></div>
                  <div><span>{t('schedulePage.meta.surface')}</span><strong>{surfaceLabel(nextTournament.surface, t)}</strong></div>
                  <div><span>{t('schedulePage.meta.entry')}</span><strong>{t('schedulePage.meta.registered')}</strong></div>
                  <div><span>{t('schedulePage.meta.preparation')}</span><strong>{planLoading ? t('schedulePage.meta.loading') : planSaved ? t('schedulePage.meta.savedPlan') : t('schedulePage.meta.defaultsActive')}</strong></div>
                </div>
              </div>
            </div>
          )}
        </section>

        <section className="tlg-schedule-list-card">
          <div className="tlg-schedule-section-head compact"><div><span>{t('schedulePage.otherKicker')}</span><h2>{t('schedulePage.otherHeading')}</h2><p>{t('schedulePage.otherIntro')}</p></div></div>
          {!loading && upcoming.length === 0 ? <div className="tlg-schedule-empty">{t('schedulePage.noAdditional')}</div> : laterTournaments.length === 0 ? <div className="tlg-schedule-empty">{t('schedulePage.noLater')}</div> : (
            <div className="tlg-schedule-tournament-list">
              {laterTournaments.map((item) => (
                <Link key={item.competition_id} to={`/game/tournaments/${item.competition_id}`} className="tlg-schedule-tournament-row">
                  <div className="tlg-schedule-row-name"><CountryFlag countryCode={item.country_code} countryName={item.country_code} width={24} height={16} /><div><strong>{item.tournament_name}</strong><span>{item.city}, {item.country_code}</span></div></div>
                  <span>{item.category_code}</span><span>{surfaceLabel(item.surface, t)}</span><span>{tournamentWeekLabel(item, t)}</span><ChevronRight size={16} />
                </Link>
              ))}
            </div>
          )}
        </section>

        <section className="tlg-schedule-applications-card">
          <div className="tlg-schedule-section-head compact">
            <div>
              <span>{t('schedulePage.applicationsKicker')}</span>
              <h2>{t('schedulePage.applicationsHeading')}</h2>
              <p>{t('schedulePage.applicationsIntro')}</p>
            </div>
          </div>

          {applicationsLoading ? (
            <div className="tlg-schedule-empty">{t('schedulePage.loadingApplications')}</div>
          ) : applicationsError ? (
            <div className="tlg-schedule-error">{t('schedulePage.applicationsError', { error: applicationsError })}</div>
          ) : (
            <div className="tlg-schedule-application-groups">
              <TournamentApplicationList
                title={t('schedulePage.singlesApplications')}
                subtitle={t('schedulePage.singlesApplicationsBody')}
                items={applicationHistory.singles}
              />
              <TournamentApplicationList
                title={t('schedulePage.doublesApplications')}
                subtitle={t('schedulePage.doublesApplicationsBody')}
                items={applicationHistory.doubles}
                doubles
              />
            </div>
          )}
        </section>
      </div>

      {prepareOpen && nextTournament && (
        <div className="tlg-tournament-prep-backdrop" role="presentation" onMouseDown={(event) => { if (event.currentTarget === event.target) setPrepareOpen(false) }}>
          <section className="tlg-tournament-prep-dialog" role="dialog" aria-modal="true" aria-label={t('schedulePage.preparation.aria', { name: nextTournament.tournament_name })}>
            <header className="tlg-tournament-prep-header">
              <div><span>{t('schedulePage.preparation.kicker')}</span><h2>{nextTournament.tournament_name}</h2><p>{nextTournament.city}, {nextTournament.country_code} · {surfaceLabel(nextTournament.surface, t)} · {tournamentWeekLabel(nextTournament, t)}</p></div>
              <button type="button" className="icon" onClick={() => setPrepareOpen(false)} aria-label={t('schedulePage.preparation.close')}><X size={19} /></button>
            </header>

            <nav className="tlg-tournament-prep-tabs" aria-label={t('schedulePage.preparation.sectionsAria')}>
              <PrepTab active={activeTab === 'travel'} icon={<Plane size={15} />} label={t('schedulePage.preparation.tabs.travel')} onClick={() => setActiveTab('travel')} />
              <PrepTab active={activeTab === 'staff'} icon={<Users size={15} />} label={t('schedulePage.preparation.tabs.staff')} onClick={() => setActiveTab('staff')} />
              <PrepTab active={activeTab === 'tactics'} icon={<SlidersHorizontal size={15} />} label={t('schedulePage.preparation.tabs.tactics')} onClick={() => setActiveTab('tactics')} />
              <PrepTab active={activeTab === 'summary'} icon={<ShieldCheck size={15} />} label={t('schedulePage.preparation.tabs.summary')} onClick={() => setActiveTab('summary')} />
            </nav>

            <div className="tlg-tournament-prep-body">
              {activeTab === 'travel' && (
                <div className="tlg-prep-stack">
                  <div className="tlg-prep-rule"><Plane size={18} /><div><strong>{t('schedulePage.preparation.automaticTiming')}</strong><p>{t('schedulePage.preparation.automaticTimingBody')}</p></div></div>
                  {estimate && <div className="tlg-prep-copy"><h3>{estimate.origin.city ?? t('schedulePage.preparation.currentLocation')} → {estimate.destination.city}</h3><p>{t('schedulePage.preparation.oneWay', { distance: distance(estimate.player_travel.distance_km, t, formatNumber), hours: estimate.player_travel.estimated_hours_one_way })}</p></div>}
                  {nextTournament && !membershipLoading && isPremium && <TournamentJetPicker
                     competitionId={nextTournament.competition_id}
                     staffCount={selectedStaff.length}
                     distanceKm={Number(estimate?.player_travel.distance_km ?? 0)}
                     money={money}
                     onChanged={() => setTravelModeRevision((revision) => revision + 1)}
                   />}
                   <ChoiceSection title={t('schedulePage.preparation.playerClass')} subtitle={t('schedulePage.preparation.playerClassBody')}><ChoiceGrid values={TRAVEL_CLASSES} selected={playerTravelClass} onSelect={(value) => { markPlanDirty(); setPlayerTravelClass(value as TravelClass) }} /></ChoiceSection>
                  <PlanImpact label={t('schedulePage.preparation.playerTravelEffect')} value={estimate ? `${estimate.private_jet?.active ? `${lifestyleLabels.jetMode} · ${estimate.private_jet.name ?? lifestyleLabels.selectedJet}` : travelClassEffect(playerTravelClass, t)} · ${t('schedulePage.preparation.fatigueArrival', { fatigue: estimate.player_travel.arrival_fatigue })}` : travelClassEffect(playerTravelClass, t)} cost={estimate ? t('schedulePage.preparation.roundTrip', { amount: money(estimate.player_travel_cost) }) : '—'} />
                  <ChoiceSection title={t('schedulePage.preparation.staffClass')} subtitle={t('schedulePage.preparation.staffClassBody')}><ChoiceGrid values={TRAVEL_CLASSES} selected={staffTravelClass} onSelect={(value) => { markPlanDirty(); setStaffTravelClass(value as TravelClass) }} /></ChoiceSection>
                  <PlanImpact label={t('schedulePage.preparation.staffTravelEffect')} value={selectedStaff.length > 0 && estimate ? `${travelClassEffect(staffTravelClass, t)} · ${t('schedulePage.preparation.fatigueTraveller', { fatigue: estimate.staff_travel.arrival_fatigue, count: selectedStaff.length })}` : t('schedulePage.preparation.noStaffSelected')} cost={estimate ? money(estimate.staff_travel_cost) : '—'} />
                  <ChoiceSection title={t('schedulePage.preparation.hotel')} subtitle={t('schedulePage.preparation.hotelBody')}>
                    <div className="tlg-prep-hotel-grid">{HOTEL_TIERS.map((tier) => { const info = hotelInfo(tier.value, t); return <button key={tier.value} type="button" className={hotelTier === tier.value ? 'selected' : ''} onClick={() => { markPlanDirty(); setHotelTier(tier.value) }}><Hotel size={17} /><strong>{info.label}</strong><span>{info.detail} · {info.effect}</span><small>{t('schedulePage.preparation.basePerNight', { amount: money(tier.nightly) })}</small></button> })}</div>
                  </ChoiceSection>
                  <PlanImpact label={t('schedulePage.preparation.selectedHotelEffect')} value={hotelCopy.effect} cost={t('schedulePage.preparation.perPersonNight', { amount: estimate ? money(estimate.hotel.minimum.adjusted_unit_cost) : money(hotel.nightly) })} />
                </div>
              )}

              {activeTab === 'staff' && (
                <div className="tlg-prep-stack">
                  <div className="tlg-prep-copy"><h3>{t('schedulePage.preparation.chooseStaff')}</h3><p>{t('schedulePage.preparation.chooseStaffBody')}</p></div>
                  {staffLoading ? <div className="tlg-schedule-empty">{t('schedulePage.preparation.loadingStaff')}</div> : activeStaff.length === 0 ? <div className="tlg-schedule-empty">{t('schedulePage.preparation.noStaff')}</div> : (
                    <div className="tlg-prep-staff-list">{activeStaff.map((contract) => { const checked = selectedStaff.includes(contract.contract_id); const effect = estimate?.staff_effects?.staff.find((item) => item.contract_id === contract.contract_id); return <button key={contract.contract_id} type="button" className={checked ? 'selected' : ''} onClick={() => toggleStaff(contract.contract_id)}><span className="checkbox">{checked ? '✓' : ''}</span><div><strong>{contract.staff.first_name} {contract.staff.last_name}</strong><span>{staffRoleLabel(t, contract.role as StaffRole, contract.role_label)} · {t('schedulePage.preparation.rating', { rating: contract.staff.overall_rating })}</span>{checked && effect && <span>{t('schedulePage.preparation.tournamentEffect', { label: staffEffectLabel(t, effect.benefit_label), value: effect.benefit_value })}</span>}</div><small>{checked ? t('schedulePage.preparation.travelling') : t('schedulePage.preparation.staysHome')}</small></button> })}</div>
                  )}
                  {estimate && <PlanImpact label={t('schedulePage.preparation.currentParty')} value={t('schedulePage.preparation.travellers', { count: estimate.party_size })} cost={t('schedulePage.preparation.staffTravelCost', { amount: money(estimate.staff_travel_cost) })} />}
                  {estimate?.staff_effects && selectedStaff.length > 0 && <PlanImpact label={t('schedulePage.preparation.staffEffects')} value={tournamentStaffEffectsSummary(estimate.staff_effects, t)} cost={t('schedulePage.preparation.activeWhileTravelling')} />}
                </div>
              )}

              {activeTab === 'tactics' && (
                <div className="tlg-prep-stack">
                  <div className="tlg-prep-copy"><h3>{t('schedulePage.preparation.defaultTactic')}</h3><p>{t('schedulePage.preparation.defaultTacticBody')}</p></div>
                  <div className="tlg-tactic-presets">{TACTIC_PRESETS.map((preset) => <button key={preset} type="button" className={tactics.preset === preset ? 'selected' : ''} onClick={() => applyPreset(preset)}>{tacticLabel(preset, t)}</button>)}</div>
                  <div className="tlg-tactic-grid">
                    <SelectField t={t} label={t('schedulePage.preparation.fields.approach')} value={tactics.approach} values={TACTIC_OPTIONS.approach} onChange={(value) => { markPlanDirty(); setTactics((current) => ({ ...current, preset: 'Custom', approach: value })) }} />
                    <SelectField t={t} label={t('schedulePage.preparation.fields.rally')} value={tactics.rally} values={TACTIC_OPTIONS.rally} onChange={(value) => { markPlanDirty(); setTactics((current) => ({ ...current, preset: 'Custom', rally: value })) }} />
                    <SelectField t={t} label={t('schedulePage.preparation.fields.serve')} value={tactics.serve} values={TACTIC_OPTIONS.serve} onChange={(value) => { markPlanDirty(); setTactics((current) => ({ ...current, preset: 'Custom', serve: value })) }} />
                    <SelectField t={t} label={t('schedulePage.preparation.fields.servePlacement')} value={tactics.servePlacement} values={TACTIC_OPTIONS.servePlacement} onChange={(value) => { markPlanDirty(); setTactics((current) => ({ ...current, preset: 'Custom', servePlacement: value })) }} />
                    <SelectField t={t} label={t('schedulePage.preparation.fields.returnGame')} value={tactics.returnGame} values={TACTIC_OPTIONS.returnGame} onChange={(value) => { markPlanDirty(); setTactics((current) => ({ ...current, preset: 'Custom', returnGame: value })) }} />
                    <SelectField t={t} label={t('schedulePage.preparation.fields.returnPosition')} value={tactics.returnPosition} values={TACTIC_OPTIONS.returnPosition} onChange={(value) => { markPlanDirty(); setTactics((current) => ({ ...current, preset: 'Custom', returnPosition: value })) }} />
                    <SelectField t={t} label={t('schedulePage.preparation.fields.courtPosition')} value={tactics.courtPosition} values={TACTIC_OPTIONS.courtPosition} onChange={(value) => { markPlanDirty(); setTactics((current) => ({ ...current, preset: 'Custom', courtPosition: value })) }} />
                    <SelectField t={t} label={t('schedulePage.preparation.fields.target')} value={tactics.target} values={TACTIC_OPTIONS.target} onChange={(value) => { markPlanDirty(); setTactics((current) => ({ ...current, preset: 'Custom', target: value })) }} />
                    <SelectField t={t} label={t('schedulePage.preparation.fields.risk')} value={tactics.risk} values={TACTIC_OPTIONS.risk} onChange={(value) => { markPlanDirty(); setTactics((current) => ({ ...current, preset: 'Custom', risk: value })) }} />
                  </div>
                  <div className="tlg-prep-rule soft"><SlidersHorizontal size={18} /><div><strong>{t('schedulePage.preparation.specificOverride')}</strong><p>{t('schedulePage.preparation.specificOverrideBody')}</p></div></div>
                </div>
              )}

              {activeTab === 'summary' && estimate && (
                <div className="tlg-prep-stack">
                  <div className="tlg-prep-summary-grid">
                    <SummaryItem label={t('schedulePage.preparation.route')} value={`${estimate.origin.city ?? t('schedulePage.preparation.currentLocation')} → ${estimate.destination.city} · ${distance(estimate.player_travel.distance_km, t, formatNumber)}`} />
                    <SummaryItem label={t('schedulePage.preparation.playerFlight')} value={`${estimate.private_jet?.active ? `${lifestyleLabels.selectedJet}: ${estimate.private_jet.name ?? '—'}` : travelClassLabel(playerTravelClass, t)} · ${money(estimate.player_travel_cost)} · ${t('schedulePage.preparation.summaryFatigue', { value: estimate.player_travel.arrival_fatigue })}`} />
                    <SummaryItem label={t('schedulePage.preparation.staffFlight')} value={selectedStaff.length === 0 ? t('schedulePage.preparation.noStaffTravel') : `${estimate.private_jet?.active ? `${lifestyleLabels.staffOnBoard}: ${estimate.private_jet.staff_on_jet ?? 0} · ${lifestyleLabels.staffCommercial}: ${estimate.private_jet.staff_commercial ?? 0}` : travelClassLabel(staffTravelClass, t)} · ${money(estimate.staff_travel_cost)}`} />
                    <SummaryItem label={t('schedulePage.preparation.hotelLabel')} value={`${hotelCopy.label} · ${t('schedulePage.preparation.perPersonNight', { amount: money(estimate.hotel.minimum.adjusted_unit_cost) })} · ${hotelCopy.effect}`} />
                    <SummaryItem label={t('schedulePage.preparation.travellingStaff')} value={selectedStaff.length === 0 ? t('schedulePage.preparation.playerOnly') : t('schedulePage.preparation.staffCount', { count: selectedStaff.length })} />
                    {estimate.staff_effects && estimate.staff_effects.match_execution_bonus_pct > 0 && <SummaryItem label={t('schedulePage.preparation.matchExecution')} value={`+${estimate.staff_effects.match_execution_bonus_pct}%`} />}
                    {estimate.staff_effects && estimate.staff_effects.match_fatigue_reduction_pct > 0 && <SummaryItem label={t('schedulePage.preparation.fatigueSupport')} value={t('schedulePage.preparation.summaryMatchFatigue', { value: estimate.staff_effects.match_fatigue_reduction_pct })} />}
                    {estimate.staff_effects && estimate.staff_effects.injury_risk_reduction_pct > 0 && <SummaryItem label={t('schedulePage.preparation.injuryPrevention')} value={t('schedulePage.preparation.summaryInjury', { value: estimate.staff_effects.injury_risk_reduction_pct })} />}
                    {estimate.staff_effects && estimate.staff_effects.commercial_bonus_pct > 0 && <SummaryItem label={t('schedulePage.preparation.commercialSupport')} value={t('schedulePage.preparation.summaryCommercial', { value: estimate.staff_effects.commercial_bonus_pct })} />}
                    <SummaryItem label={t('schedulePage.preparation.defaultTacticLabel')} value={tacticLabel(tactics.preset, t)} />
                    <SummaryItem label={t('schedulePage.preparation.returnTravel')} value={t('schedulePage.preparation.dayAfterElimination')} />
                  </div>
                  {selectedStaffNames.length > 0 && <div className="tlg-prep-selected-staff"><span>{t('schedulePage.preparation.party')}</span><strong>{selectedStaffNames.join(', ')}</strong></div>}
                  <div className="tlg-prep-cost-placeholder tlg-prep-cost-live"><span>{t('schedulePage.preparation.estimatedCost')} {quoteLoading ? t('schedulePage.preparation.recalculatingShort') : ''}</span><strong>{money(estimate.minimum_total)} – {money(estimate.maximum_total)}</strong><div className="tlg-prep-cost-breakdown"><small>{t('schedulePage.preparation.travelCost', { amount: money(estimate.player_travel_cost + estimate.staff_travel_cost) })}</small><small>{t('schedulePage.preparation.hotelCost', { amount: money(estimate.hotel.minimum.adjusted_unit_cost * estimate.party_size) })}</small><small>{t('schedulePage.preparation.stayRange', { min: estimate.minimum_nights, max: estimate.maximum_nights })}</small><small>{t('schedulePage.preparation.arrivalFatigue', { value: estimate.player_travel.arrival_fatigue })}</small></div><p>{t('schedulePage.preparation.stayBody')}</p></div>
                </div>
              )}
            </div>

            <footer className="tlg-tournament-prep-footer">
              <span>{planMessage ?? (quoteLoading ? t('schedulePage.preparation.recalculating') : hasUnsavedChanges ? t('schedulePage.preparation.unsaved') : planSaved ? t('schedulePage.preparation.active') : t('schedulePage.preparation.defaults'))}</span>
              <button type="button" onClick={savePreparation} disabled={planSaving || planLoading || quoteLoading}>{planSaving ? t('schedulePage.preparation.saving') : hasUnsavedChanges && planSaved ? t('schedulePage.preparation.saveChanges') : t('schedulePage.preparation.savePlan')}</button>
            </footer>
          </section>
        </div>
      )}
    </GameLayout>
  )
}

function PrepTab({ active, icon, label, onClick }: { active: boolean; icon: JSX.Element; label: string; onClick: () => void }) {
  return <button type="button" className={active ? 'active' : ''} onClick={onClick}>{icon}<span>{label}</span></button>
}

function ChoiceSection({ title, subtitle, children }: { title: string; subtitle: string; children: JSX.Element }) {
  return <section className="tlg-prep-choice-section"><div><h3>{title}</h3><p>{subtitle}</p></div>{children}</section>
}

function travelClassLabel(value: string, t: TFunction) {
  return t(`schedulePage.preparation.travelClasses.${value}`, { defaultValue: value })
}

function ChoiceGrid({ values, selected, onSelect }: { values: readonly string[]; selected: string; onSelect: (value: string) => void }) {
  const { t } = useTranslation()
  return <div className="tlg-prep-choice-grid">{values.map((value) => <button key={value} type="button" className={selected === value ? 'selected' : ''} onClick={() => onSelect(value)}>{travelClassLabel(value, t)}</button>)}</div>
}

function SelectField({ t, label, value, values, onChange }: { t: TFunction; label: string; value: string; values: readonly string[]; onChange: (value: string) => void }) {
  return <label className="tlg-tactic-field"><span>{label}</span><select value={value} onChange={(event) => onChange(event.target.value)}>{values.map((option) => <option key={option} value={option}>{tacticLabel(option, t)}</option>)}</select></label>
}

function SummaryItem({ label, value }: { label: string; value: string }) {
  return <div className="tlg-prep-summary-item"><span>{label}</span><strong>{value}</strong></div>
}

function PlanImpact({ label, value, cost }: { label: string; value: string; cost: string }) {
  return <div className="tlg-prep-impact"><div><span>{label}</span><strong>{value}</strong></div><b>{cost}</b></div>
}
