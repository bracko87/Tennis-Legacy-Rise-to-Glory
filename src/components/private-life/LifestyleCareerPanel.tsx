import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import CountryFlag from '../common/CountryFlag'
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
  cruise_speed_kmh?: number
  overnight_transfer_limit_hours?: number
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

// The Overview preview displays readable nationalities and actual flag images,
// rather than the two-letter ISO codes used by the game database.
const ENGLISH_NATIONALITIES: Record<string, string> = {
  AL: 'Albanian', AR: 'Argentine', AT: 'Austrian', AU: 'Australian',
  BA: 'Bosnian', BE: 'Belgian', BG: 'Bulgarian', BR: 'Brazilian',
  BY: 'Belarusian', CA: 'Canadian', CH: 'Swiss', CL: 'Chilean',
  CN: 'Chinese', CO: 'Colombian', CR: 'Costa Rican', CY: 'Cypriot',
  CZ: 'Czech', DE: 'German', DK: 'Danish', DO: 'Dominican',
  DZ: 'Algerian', EC: 'Ecuadorian', EE: 'Estonian', EG: 'Egyptian',
  ES: 'Spanish', FI: 'Finnish', FR: 'French', GB: 'British',
  GE: 'Georgian', GR: 'Greek', HR: 'Croatian', HU: 'Hungarian',
  ID: 'Indonesian', IE: 'Irish', IL: 'Israeli', IN: 'Indian',
  IS: 'Icelandic', IT: 'Italian', JP: 'Japanese', KZ: 'Kazakh',
  KR: 'South Korean', LT: 'Lithuanian', LU: 'Luxembourgish',
  LV: 'Latvian', MA: 'Moroccan', MD: 'Moldovan', ME: 'Montenegrin',
  MK: 'Macedonian', MX: 'Mexican', MY: 'Malaysian', NL: 'Dutch',
  NO: 'Norwegian', NZ: 'New Zealand', PE: 'Peruvian', PH: 'Filipino',
  PK: 'Pakistani', PL: 'Polish', PT: 'Portuguese', RO: 'Romanian',
  RS: 'Serbian', RU: 'Russian', SE: 'Swedish', SG: 'Singaporean',
  SI: 'Slovenian', SK: 'Slovak', TH: 'Thai', TN: 'Tunisian',
  TR: 'Turkish', TW: 'Taiwanese', UA: 'Ukrainian', US: 'American',
  UY: 'Uruguayan', UZ: 'Uzbek', VE: 'Venezuelan', VN: 'Vietnamese',
  ZA: 'South African',
}

function regionName(code: string, locale: string): string {
  try {
    return new Intl.DisplayNames([locale], { type: 'region' }).of(code) ?? code
  } catch {
    return code
  }
}

function NationalityPreview({ nationality, locale }: { nationality?: string | null; locale: string }) {
  const raw = nationality?.trim() || ''
  const code = /^[a-z]{2}$/i.test(raw) ? raw.toUpperCase() : null
  const name = code
    ? (/^en(?:$|[-_])/i.test(locale) ? ENGLISH_NATIONALITIES[code] : undefined) ?? regionName(code, locale)
    : raw || '—'

  return (
    <span className="tlg-career-flag-row">
      <span>{name}</span>
      {code && <CountryFlag countryCode={code} countryName={regionName(code, locale)} width={22} height={15} />}
    </span>
  )
}

function LocationPreview({ city, country, locale }: { city?: string | null; country?: string | null; locale: string }) {
  const code = country && /^[a-z]{2}$/i.test(country) ? country.toUpperCase() : null
  return (
    <span className="tlg-career-flag-row">
      <span>{city ? `${city}${code ? ',' : ''}` : code ? regionName(code, locale) : '—'}</span>
      {code && <CountryFlag countryCode={code} countryName={regionName(code, locale)} width={22} height={15} />}
    </span>
  )
}

export function LifestyleFacts({ data, compact = false }: { data: LifestyleCareer; compact?: boolean }) {
  const { i18n } = useTranslation()
  const locale = i18n.resolvedLanguage ?? i18n.language
  const copy = useMemo(() => lifestyleCopy(locale), [locale])
  return (
    <div className={'tlg-career-facts' + (compact ? ' compact' : '')}>
      <div>
        <span>{copy.nationality}</span>
        <strong>{compact
          ? <NationalityPreview nationality={data.home_base?.nationality} locale={locale} />
          : data.home_base?.nationality || '—'}</strong>
      </div>
      <div>
        <span>{copy.homeBase}</span>
        <strong>{compact
          ? <LocationPreview city={data.home_base?.city} country={data.home_base?.country_code} locale={locale} />
          : <DestinationLabel city={data.home_base?.city} country={data.home_base?.country_code} />}</strong>
      </div>
      <div>
        <span>{copy.currentLocation}</span>
        <strong>{compact
          ? <LocationPreview city={data.current_location?.city} country={data.current_location?.country_code} locale={locale} />
          : <DestinationLabel city={data.current_location?.city} country={data.current_location?.country_code} />}</strong>
      </div>
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
