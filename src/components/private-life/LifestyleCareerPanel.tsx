import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { lifestyleCopy, type LifestyleCopy } from '../../lib/lifestyleCareerI18n'
import '../../styles/private-life-career.css'

export type OwnedTravelJet = {
  owned_asset_id: string
  name: string
  max_range_km: number
  passenger_capacity: number
  cost_per_km: number
  base_trip_cost: number
  reduction_percent: number
}

export type LifestyleCareer = {
  home_base?: { city?: string | null; country_code?: string | null; nationality?: string | null; asset_id?: string | null }
  current_location?: { city?: string | null; country_code?: string | null; type?: string | null }
  active_residence_asset_id?: string | null
  pending_residence_asset_id?: string | null
  pending_effective_absolute_day?: number | null
  last_relocation_absolute_day?: number | null
  morale_bonus?: number
  maximum_morale_bonus?: number
  preferred_travel_mode?: 'cheapest' | 'commercial' | 'best_owned_jet' | 'ask_every_time'
  eligible_jets?: OwnedTravelJet[]
}

export function DestinationLabel({ city, country }: { city?: string | null; country?: string | null }) {
  return <>{[city, country].filter(Boolean).join(', ') || '—'}</>
}

export function LifestyleFacts({ data, compact = false }: { data: LifestyleCareer; compact?: boolean }) {
  const { i18n } = useTranslation()
  const copy = useMemo(() => lifestyleCopy(i18n.resolvedLanguage ?? i18n.language), [i18n.resolvedLanguage, i18n.language])
  return (
    <div className={'tlg-career-facts' + (compact ? ' compact' : '')}>
      <div><span>{copy.nationality}</span><strong>{data.home_base?.nationality || '—'}</strong></div>
      <div><span>{copy.homeBase}</span><strong><DestinationLabel city={data.home_base?.city} country={data.home_base?.country_code} /></strong></div>
      <div><span>{copy.currentLocation}</span><strong><DestinationLabel city={data.current_location?.city} country={data.current_location?.country_code} /></strong></div>
      {!compact && <div><span>{copy.morale}</span><strong>+{Number(data.morale_bonus ?? 0)}/3</strong><small>{copy.moraleNote}</small></div>}
    </div>
  )
}

type Props = {
  data: LifestyleCareer
  saving: boolean
  onTravelPreference: (value: NonNullable<LifestyleCareer['preferred_travel_mode']>) => void
  formatCurrency: (amount: number) => string
}

export function LifestyleCareerPanel({data, saving, onTravelPreference, formatCurrency}: Props) {
  const { i18n } = useTranslation()
  const copy: LifestyleCopy = lifestyleCopy(i18n.resolvedLanguage ?? i18n.language)
  return (
    <section className="tlg-career-panel" aria-label={copy.title}>
      <div className="tlg-career-panel-heading">
        <div><h3>{copy.title}</h3><p>{copy.subtitle}</p></div>
        <strong className="tlg-career-morale">{copy.morale}: +{Number(data.morale_bonus ?? 0)}/3</strong>
      </div>
      <LifestyleFacts data={data} />
      {data.pending_residence_asset_id && <p className="tlg-career-pending">{copy.movePending} · {copy.relocateNote} (day {data.pending_effective_absolute_day})</p>}
      <label className="tlg-career-preference">
        <span>{copy.preferredTravel}</span>
        <select disabled={saving} value={data.preferred_travel_mode ?? 'ask_every_time'}
          onChange={event => onTravelPreference(event.target.value as NonNullable<LifestyleCareer['preferred_travel_mode']>)}>
          <option value="ask_every_time">{copy.askEveryTime}</option>
          <option value="cheapest">{copy.cheapest}</option>
          <option value="commercial">{copy.commercial}</option>
          <option value="best_owned_jet">{copy.bestOwnedJet}</option>
        </select>
      </label>
      <div className="tlg-career-jet-list">
        <h4>{copy.ownedJets}</h4>
        {(data.eligible_jets ?? []).length === 0 ? <p>{copy.none}</p> : (data.eligible_jets ?? []).map(jet => (
          <div key={jet.owned_asset_id} className="tlg-career-jet">
            <strong>{jet.name}</strong>
            <span>{copy.range}: {jet.max_range_km.toLocaleString()} km</span>
            <span>{copy.capacity}: {jet.passenger_capacity}</span>
            <span>{copy.operating}: {formatCurrency(jet.base_trip_cost)} + {formatCurrency(jet.cost_per_km)}/km</span>
            <span>{copy.fatigueBenefit}: {jet.reduction_percent}%</span>
          </div>
        ))}
      </div>
    </section>
  )
}
