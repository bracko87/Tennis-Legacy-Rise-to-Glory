import { useTranslation } from 'react-i18next'
import { lifestyleCopy } from '../../lib/lifestyleCareerI18n'
import '../../styles/private-life-marketplace.css'

type JetSpecification = {
  seats: number
  rangeKm: number
  fatigueReduction: number
  baseCost: number
  costPerKm: number
}

/**
 * Display-only preview of the nine screenshot-approved aircraft.
 * Keep aligned with migration 20261026094500_private_life_jet_travel_integration_v1.sql.
 * NEVER use browser values for flight authorization, billing or fatigue.
 * The server RPC remains authoritative once the database migration is live.
 */
export const APPROVED_TOURNAMENT_JETS: Readonly<Record<string, JetSpecification>> = {
  air_cessaro_citation_m3:         { seats: 7,  rangeKm: 3000,  fatigueReduction: 24, baseCost: 2800,  costPerKm: 4 },
  air_emborgier_phenom_350e:       { seats: 8,  rangeKm: 3600,  fatigueReduction: 27, baseCost: 3300,  costPerKm: 5 },
  air_bombara_challenger_420:      { seats: 9,  rangeKm: 4500,  fatigueReduction: 30, baseCost: 4500,  costPerKm: 7 },
  air_cessaro_citation_latitude_x: { seats: 9,  rangeKm: 5000,  fatigueReduction: 34, baseCost: 5800,  costPerKm: 8 },
  air_emborgier_praetor_680:       { seats: 10, rangeKm: 6200,  fatigueReduction: 38, baseCost: 6800,  costPerKm: 10 },
  air_dassier_falcon_9x:          { seats: 14, rangeKm: 7600,  fatigueReduction: 42, baseCost: 8900,  costPerKm: 13 },
  air_gulfstar_g650_lx:           { seats: 16, rangeKm: 9500,  fatigueReduction: 45, baseCost: 11000, costPerKm: 16 },
  air_bombara_global_8000x:       { seats: 17, rangeKm: 11500, fatigueReduction: 48, baseCost: 14000, costPerKm: 19 },
  air_gulfstar_g900_sovereign:    { seats: 19, rangeKm: 13500, fatigueReduction: 50, baseCost: 17000, costPerKm: 23 },
}

const statusTranslations: Record<string, {
  preview: string
  available: string
  onlyDirect: string
  inactive: string
  commercial: string
  groupFare: string
  operationsAllowance: string
}> = {
  en: {
    preview: 'Planned tournament transport',
    available: 'Tournament transport',
    onlyDirect: 'Direct flights only',
    inactive: 'Preview only — travel feature is not activated on this database.',
    commercial: 'If out of range, player and staff fly commercially.',
    groupFare: 'One operating fare covers player + staff',
    operationsAllowance: 'Plus $1,000 flight allowance and any aircraft repositioning',
  },
  de: {
    preview: 'Geplanter Turniertransport',
    available: 'Turniertransport',
    onlyDirect: 'Nur Direktflüge',
    inactive: 'Vorschau — Reisefunktion in dieser Datenbank noch nicht aktiviert.',
    commercial: 'Außer Reichweite: Linienflüge für Spieler und Team.',
    groupFare: 'Ein Flugpreis für Spieler und Team',
    operationsAllowance: 'Zuzüglich 1.000 $ Flugpauschale und möglicher Jet-Überführung',
  },
  sr: {
    preview: 'Planirani prevoz na turnire',
    available: 'Prevoz na turnire',
    onlyDirect: 'Samo direktni letovi',
    inactive: 'Pregled — funkcija putovanja još nije aktivirana u bazi.',
    commercial: 'Van dometa: igrač i stručni štab lete redovnim letom.',
    groupFare: 'Jedna cena leta za igrača i stručni štab',
    operationsAllowance: 'Plus 1.000 $ po letu i eventualno pozicioniranje aviona',
  },
  es: {
    preview: 'Transporte a torneos previsto',
    available: 'Transporte a torneos',
    onlyDirect: 'Solo vuelos directos',
    inactive: 'Vista previa: la función de viaje aún no está activada en esta base de datos.',
    commercial: 'Fuera de alcance: jugador y equipo vuelan en línea comercial.',
    groupFare: 'Una tarifa para el jugador y el equipo',
    operationsAllowance: 'Más 1.000 $ por vuelo y posicionamiento del avión si procede',
  },
  fr: {
    preview: 'Transport prévu pour les tournois',
    available: 'Transport pour les tournois',
    onlyDirect: 'Vols directs uniquement',
    inactive: 'Aperçu — la fonction voyage n’est pas active sur cette base de données.',
    commercial: 'Hors de portée : joueur et équipe prennent un vol commercial.',
    groupFare: 'Un seul tarif pour le joueur et son équipe',
    operationsAllowance: 'Plus 1 000 $ par vol et repositionnement éventuel',
  },
  it: {
    preview: 'Trasporto ai tornei previsto',
    available: 'Trasporto ai tornei',
    onlyDirect: 'Solo voli diretti',
    inactive: 'Anteprima: la funzione viaggi non è ancora attiva su questo database.',
    commercial: 'Fuori autonomia: giocatore e staff volano con voli commerciali.',
    groupFare: 'Un costo di volo per giocatore e staff',
    operationsAllowance: 'Più 1.000 $ a volo e l’eventuale riposizionamento',
  },
  pt: {
    preview: 'Transporte previsto para torneios',
    available: 'Transporte para torneios',
    onlyDirect: 'Apenas voos diretos',
    inactive: 'Pré-visualização: função de viagem ainda não ativada nesta base de dados.',
    commercial: 'Fora do alcance: jogador e equipa usam voos comerciais.',
    groupFare: 'Um único custo de voo para jogador e equipa',
    operationsAllowance: 'Mais 1.000 $ por voo e eventual reposicionamento',
  },
  ru: {
    preview: 'Планируемые перелёты на турниры',
    available: 'Перелёты на турниры',
    onlyDirect: 'Только прямые рейсы',
    inactive: 'Предпросмотр: функция ещё не активирована в этой базе данных.',
    commercial: 'Вне дальности: игрок и команда летят регулярным рейсом.',
    groupFare: 'Одна стоимость полёта для игрока и команды',
    operationsAllowance: 'Плюс 1 000 $ за рейс и возможный перегон самолёта',
  },
}

type Props = {
  catalogCode: string
  connectedBackendActive: boolean
  formatMoney: (amount: number) => string
  compact?: boolean
}

export default function PrivateJetTravelPreview({ catalogCode, connectedBackendActive, formatMoney, compact = false }: Props) {
  const { i18n } = useTranslation()
  const language = (i18n.resolvedLanguage || i18n.language || 'en').toLowerCase().split('-')[0]
  const labels = statusTranslations[language] ?? statusTranslations.en
  const copy = lifestyleCopy(language)
  const jet = APPROVED_TOURNAMENT_JETS[catalogCode]

  if (!jet) {
    return <div className="tlg-aircraft-preview tlg-aircraft-lifestyle"><strong>{copy.jetIneligible}</strong></div>
  }

  return (
    <section className={'tlg-aircraft-preview' + (compact ? ' is-compact' : '')} aria-label={labels.available}>
      <strong className="tlg-aircraft-preview-title">{connectedBackendActive ? labels.available : labels.preview} · {labels.onlyDirect}</strong>
      <div className="tlg-aircraft-preview-facts">
        <span>{copy.range}: <b>{jet.rangeKm.toLocaleString(language)} km</b></span>
        <span>{copy.capacity}: <b>{jet.seats}</b></span>
        <span>{copy.fatigueBenefit}: <b>{jet.fatigueReduction}%</b></span>
        {!compact && <span>{copy.operating}: <b>{formatMoney(jet.baseCost)} + {formatMoney(jet.costPerKm)}/km</b></span>}
      </div>
      {!compact && <small>{labels.groupFare}. {labels.operationsAllowance}.</small>}
      <small>{labels.commercial}</small>
      {!connectedBackendActive && <small className="tlg-aircraft-preview-pending">{labels.inactive}</small>}
    </section>
  )
}
