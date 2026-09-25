import { RotateCcw } from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'

import CountryFlag from '../common/CountryFlag'
import { nationalCountryName } from '../../lib/nationalCountryName'
import { supabase } from '../../lib/supabase'

interface CompetitionOption {
  division_id: string
  region_code: string
  division_code: string
  label: string
  tier_level: number
  capacity: number
  format_kind: 'knockout' | 'group'
  tier_family: 'Qualifiers' | 'World Groups' | 'Regional'
  selector_region: string | null
  group_count: number
}

interface BrowserParticipant {
  association_id: string
  name: string
  country_code: string
  placement_state: 'official' | 'projected'
  seed_position: number
  group_code: string | null
  is_mine: boolean
}

interface BrowserFixture {
  fixture_id: string
  division_code?: string
  status: string
  fixture_kind: string
  home_association_id: string
  home_name: string
  home_country_code: string
  away_association_id: string
  away_name: string
  away_country_code: string
  home_match_wins: number
  away_match_wins: number
  winner_association_id: string | null
  tie_start_absolute_day: number
  tie_end_absolute_day: number
  window_tie_slot?: number | null
}

interface BrowserStanding {
  rank_position: number
  association_id: string
  association_name: string
  country_code: string
  ties_played: number
  ties_won: number
  ties_lost: number
  matches_won: number
  matches_lost: number
  standings_points: number
  is_mine: boolean
}

interface DivisionBrowser {
  available: boolean
  world: 'ATP' | 'WTA'
  season_number: number
  my_association_id: string
  my_division_id: string
  selected_division: {
    division_id: string
    division_code: string
    label: string
    region_code: string
    tier_level: number
    capacity: number
    promotion_slots: number
    relegation_slots: number
    format_kind: 'knockout' | 'group'
  }
  selected_group_code: string | null
  group_codes: string[]
  competition_options: CompetitionOption[]
  participants: BrowserParticipant[]
  fixtures: BrowserFixture[]
  standings: BrowserStanding[]
}

interface BracketRound {
  code: 'qualifier_r1' | 'qualifier_r2' | 'quarterfinal' | 'semifinal' | 'final'
  label: string
  matches: number
}

interface BracketTeam {
  association_id?: string
  name: string
  country_code?: string
  score?: number
  winner?: boolean
  is_mine?: boolean
}

interface BracketMatch {
  id: string
  team1: BracketTeam
  team2: BracketTeam
  status?: string
}

const MONTH_LENGTHS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const BRACKET_MATCH_WIDTH = 220
const BRACKET_MATCH_HEIGHT = 68
const BRACKET_COLUMN_GAP = 70
const BRACKET_FIRST_ROUND_GAP = 12
const BRACKET_STEP = BRACKET_MATCH_HEIGHT + BRACKET_FIRST_ROUND_GAP

const KNOCKOUT_ROUNDS: BracketRound[] = [
  { code: 'qualifier_r1', label: 'Qualifier Round 1', matches: 16 },
  { code: 'qualifier_r2', label: 'Qualifier Round 2', matches: 8 },
  { code: 'quarterfinal', label: 'Quarterfinal', matches: 4 },
  { code: 'semifinal', label: 'Semifinal', matches: 2 },
  { code: 'final', label: 'Final', matches: 1 },
]

function formatAbsoluteDay(absoluteDay?: number | null) {
  if (absoluteDay === null || absoluteDay === undefined || absoluteDay < 0) return '—'
  const season = Math.floor(absoluteDay / 366) + 1
  let remaining = absoluteDay % 366
  let month = 0
  while (month < MONTH_LENGTHS.length - 1 && remaining >= MONTH_LENGTHS[month]) {
    remaining -= MONTH_LENGTHS[month]
    month += 1
  }
  return `Season ${season} · ${remaining + 1} ${MONTH_NAMES[month]}`
}

function regionLabel(code: string) {
  if (code === 'EUROPE') return 'Europe'
  if (code === 'AMERICAS') return 'Americas'
  if (code === 'ASIA_OCEANIA') return 'Asia / Oceania'
  if (code === 'AFRICA') return 'Africa'
  return 'Global'
}

function bracketMatchCenter(roundIndex: number, matchIndex: number) {
  const firstRoundMatchSpan = 2 ** roundIndex
  const representedFirstMatchCenter = matchIndex * firstRoundMatchSpan + (firstRoundMatchSpan - 1) / 2
  return BRACKET_MATCH_HEIGHT / 2 + representedFirstMatchCenter * BRACKET_STEP
}

function placeholderTeam(): BracketTeam {
  return { name: 'TBD' }
}

function participantTeam(participant?: BrowserParticipant): BracketTeam {
  if (!participant) return placeholderTeam()
  return {
    association_id: participant.association_id,
    name: nationalCountryName(participant.country_code, participant.name),
    country_code: participant.country_code,
    is_mine: participant.is_mine,
  }
}

function fixtureTeam(
  fixture: BrowserFixture,
  side: 'home' | 'away',
  myAssociationId: string,
): BracketTeam {
  const associationId = side === 'home' ? fixture.home_association_id : fixture.away_association_id
  const score = side === 'home' ? fixture.home_match_wins : fixture.away_match_wins
  return {
    association_id: associationId,
    name: nationalCountryName(
      side === 'home' ? fixture.home_country_code : fixture.away_country_code,
      side === 'home' ? fixture.home_name : fixture.away_name,
    ),
    country_code: side === 'home' ? fixture.home_country_code : fixture.away_country_code,
    score,
    winner: fixture.winner_association_id === associationId,
    is_mine: associationId === myAssociationId,
  }
}

function roundFixtures(browser: DivisionBrowser, round: BracketRound) {
  const globalFixtures = [...browser.fixtures].sort((a, b) =>
    a.tie_start_absolute_day - b.tie_start_absolute_day || a.fixture_id.localeCompare(b.fixture_id),
  )

  if (round.code === 'qualifier_r1') {
    return globalFixtures.filter((fixture) => fixture.division_code === 'qualifier_r1')
  }

  if (round.code === 'qualifier_r2') {
    return globalFixtures.filter((fixture) => fixture.division_code === 'qualifier_r2')
  }

  const finalEight = globalFixtures.filter((fixture) => fixture.division_code === 'final_8')
  if (round.code === 'quarterfinal') return finalEight.slice(0, 4)
  if (round.code === 'semifinal') return finalEight.slice(4, 6)
  return finalEight.slice(6, 7)
}

function buildRoundMatches(browser: DivisionBrowser, round: BracketRound): BracketMatch[] {
  const fixtures = roundFixtures(browser, round)
  const selectedCode = browser.selected_division.division_code
  const selectedFeedsRound =
    (selectedCode === 'qualifier_r1' && round.code === 'qualifier_r1')
    || (selectedCode === 'qualifier_r2' && round.code === 'qualifier_r2')
    || (selectedCode === 'final_8' && round.code === 'quarterfinal')

  return Array.from({ length: round.matches }, (_, matchIndex) => {
    const fixture = fixtures[matchIndex]
    if (fixture) {
      return {
        id: fixture.fixture_id,
        team1: fixtureTeam(fixture, 'home', browser.my_association_id),
        team2: fixtureTeam(fixture, 'away', browser.my_association_id),
        status: fixture.status,
      }
    }

    if (selectedFeedsRound) {
      const first = browser.participants[matchIndex * 2]
      const second = browser.participants[matchIndex * 2 + 1]
      return {
        id: `${round.code}-${matchIndex}`,
        team1: participantTeam(first),
        team2: participantTeam(second),
      }
    }

    return {
      id: `${round.code}-${matchIndex}`,
      team1: placeholderTeam(),
      team2: placeholderTeam(),
    }
  })
}

function BracketTeamRow({ team }: { team: BracketTeam }) {
  return (
    <div className={`nt-division-bracket-team ${team.winner ? 'winner' : ''} ${team.is_mine ? 'mine' : ''}`}>
      <span className="flag">
        {team.country_code
          ? <CountryFlag countryCode={team.country_code} countryName={team.country_code} width={20} height={14} />
          : <span className="empty-flag" />}
      </span>
      <strong>{team.name}</strong>
      {team.score !== undefined && <b>{team.score}</b>}
    </div>
  )
}

function KnockoutTree({ browser }: { browser: DivisionBrowser }) {
  const width = KNOCKOUT_ROUNDS.length * BRACKET_MATCH_WIDTH + (KNOCKOUT_ROUNDS.length - 1) * BRACKET_COLUMN_GAP
  const height = (KNOCKOUT_ROUNDS[0].matches - 1) * BRACKET_STEP + BRACKET_MATCH_HEIGHT

  return (
    <div className="nt-division-bracket-scroll">
      <div className="nt-division-bracket-headings" style={{ width }}>
        {KNOCKOUT_ROUNDS.map((round, roundIndex) => (
          <header
            key={round.code}
            style={{ left: roundIndex * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP) }}
          >
            <strong>{round.label}</strong>
            <span>{round.matches} {round.matches === 1 ? 'tie' : 'ties'}</span>
          </header>
        ))}
      </div>

      <div className="nt-division-bracket-tree" style={{ width, height }}>
        <svg
          className="nt-division-bracket-connectors"
          width={width}
          height={height}
          viewBox={`0 0 ${width} ${height}`}
          aria-hidden="true"
        >
          {KNOCKOUT_ROUNDS.slice(0, -1).flatMap((_, roundIndex) => {
            const parentRound = KNOCKOUT_ROUNDS[roundIndex + 1]
            const startX = roundIndex * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP) + BRACKET_MATCH_WIDTH
            const middleX = startX + BRACKET_COLUMN_GAP / 2
            const endX = (roundIndex + 1) * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP)

            return Array.from({ length: parentRound.matches }, (_, parentIndex) => {
              const firstY = bracketMatchCenter(roundIndex, parentIndex * 2)
              const secondY = bracketMatchCenter(roundIndex, parentIndex * 2 + 1)
              const parentY = bracketMatchCenter(roundIndex + 1, parentIndex)

              return (
                <path
                  key={`connector-${roundIndex}-${parentIndex}`}
                  d={`M ${startX} ${firstY} H ${middleX} M ${startX} ${secondY} H ${middleX} M ${middleX} ${firstY} V ${secondY} M ${middleX} ${parentY} H ${endX}`}
                />
              )
            })
          })}
        </svg>

        {KNOCKOUT_ROUNDS.map((round, roundIndex) => {
          const matches = buildRoundMatches(browser, round)
          return (
            <section
              key={round.code}
              className="nt-division-bracket-round"
              style={{ left: roundIndex * (BRACKET_MATCH_WIDTH + BRACKET_COLUMN_GAP) }}
            >
              {matches.map((match, matchIndex) => {
                const top = bracketMatchCenter(roundIndex, matchIndex) - BRACKET_MATCH_HEIGHT / 2
                return (
                  <article
                    key={match.id}
                    className="nt-division-bracket-match"
                    style={{ top }}
                  >
                    <BracketTeamRow team={match.team1} />
                    <BracketTeamRow team={match.team2} />
                  </article>
                )
              })}
            </section>
          )
        })}
      </div>
    </div>
  )
}

function GroupView({
  browser,
  groupCodes,
  onGroupChange,
}: {
  browser: DivisionBrowser
  groupCodes: string[]
  onGroupChange: (groupCode: string) => void
}) {
  const selectedGroup = browser.selected_group_code ?? groupCodes[0] ?? 'A'
  const participants = browser.participants.filter((participant) => participant.group_code === selectedGroup)

  return (
    <div className="nt-division-group-view">
      <div className="nt-division-group-head">
        <div>
          <span>GROUP COMPETITION</span>
          <h3>{browser.selected_division.label} · Group {selectedGroup}</h3>
          <p>Each association plays the other countries in its group. Results feed this table and determine promotion/relegation at season end.</p>
        </div>

        {groupCodes.length > 1 && (
          <label>
            <span>Group</span>
            <select value={selectedGroup} onChange={(event) => onGroupChange(event.target.value)}>
              {groupCodes.map((groupCode) => (
                <option key={groupCode} value={groupCode}>Group {groupCode}</option>
              ))}
            </select>
          </label>
        )}
      </div>

      <section className="nt-division-group-table">
        <header>
          <span>#</span>
          <span>National team</span>
          <span>P</span>
          <span>W</span>
          <span>L</span>
          <span>Matches</span>
          <span>Pts</span>
        </header>

        {browser.standings.length > 0 ? browser.standings.map((row) => (
          <div key={row.association_id} className={row.is_mine ? 'mine' : ''}>
            <strong>{row.rank_position}</strong>
            <span className="team">
              <CountryFlag countryCode={row.country_code} countryName={row.country_code} width={22} height={15} />
              <b>{nationalCountryName(row.country_code, row.association_name)}</b>
            </span>
            <span>{row.ties_played}</span>
            <span>{row.ties_won}</span>
            <span>{row.ties_lost}</span>
            <span>{row.matches_won}–{row.matches_lost}</span>
            <strong>{row.standings_points}</strong>
          </div>
        )) : participants.length > 0 ? participants.map((participant, index) => (
          <div key={participant.association_id} className={participant.is_mine ? 'mine' : ''}>
            <strong>{index + 1}</strong>
            <span className="team">
              <CountryFlag countryCode={participant.country_code} countryName={participant.country_code} width={22} height={15} />
              <b>{nationalCountryName(participant.country_code, participant.name)}</b>
            </span>
            <span>0</span><span>0</span><span>0</span><span>0–0</span><strong>0</strong>
          </div>
        )) : (
          <div className="empty">No active associations are assigned to this group yet.</div>
        )}
      </section>

      <section className="nt-division-group-fixtures">
        <div className="nt-division-group-section-head">
          <span>NATIONAL TIES</span>
          <h4>Group fixtures</h4>
        </div>

        {browser.fixtures.length === 0 ? (
          <div className="empty">No group ties have been scheduled yet.</div>
        ) : browser.fixtures.map((fixture) => (
          <article key={fixture.fixture_id}>
            <span className="date">{formatAbsoluteDay(fixture.tie_start_absolute_day)}</span>
            <div className="side">
              <CountryFlag countryCode={fixture.home_country_code} countryName={fixture.home_country_code} width={22} height={15} />
              <strong>{nationalCountryName(fixture.home_country_code, fixture.home_name)}</strong>
            </div>
            <b className="score">{fixture.home_match_wins} – {fixture.away_match_wins}</b>
            <div className="side away">
              <strong>{nationalCountryName(fixture.away_country_code, fixture.away_name)}</strong>
              <CountryFlag countryCode={fixture.away_country_code} countryName={fixture.away_country_code} width={22} height={15} />
            </div>
            <span className="status">{fixture.status.replaceAll('_', ' ')}</span>
          </article>
        ))}
      </section>
    </div>
  )
}

export default function NationalCompetitionDivisions() {
  const [browser, setBrowser] = useState<DivisionBrowser | null>(null)
  const [loading, setLoading] = useState(true)
  const [switching, setSwitching] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const loadBrowser = useCallback(async (divisionId?: string | null, groupCode?: string | null, initial = false) => {
    if (initial) setLoading(true)
    else setSwitching(true)
    setError(null)

    const { data, error: rpcError } = await supabase.rpc('get_national_team_division_browser_v1', {
      p_division_id: divisionId ?? null,
      p_group_code: groupCode ?? null,
    })

    if (rpcError) {
      setError(rpcError.message)
    } else {
      setBrowser(data as DivisionBrowser)
    }

    setLoading(false)
    setSwitching(false)
  }, [])

  useEffect(() => {
    void loadBrowser(null, null, true)
  }, [loadBrowser])

  const selectedOption = useMemo(
    () => browser?.competition_options.find((option) => option.division_id === browser.selected_division.division_id) ?? null,
    [browser],
  )

  const tierFamily = selectedOption?.tier_family ?? 'Qualifiers'
  const selectedRegion = selectedOption?.selector_region ?? 'GLOBAL'

  const regions = useMemo(() => {
    if (!browser) return []
    return Array.from(new Set(
      browser.competition_options
        .filter((option) => option.tier_family === 'Regional' && option.selector_region)
        .map((option) => option.selector_region as string),
    ))
  }, [browser])

  const competitionChoices = useMemo(() => {
    if (!browser) return []
    return browser.competition_options.filter((option) => {
      if (option.tier_family !== tierFamily) return false
      if (tierFamily === 'Regional') return option.selector_region === selectedRegion
      return true
    })
  }, [browser, tierFamily, selectedRegion])

  const groupCodes = useMemo(() => {
    const count = selectedOption?.group_count ?? 0
    return Array.from({ length: count }, (_, index) => String.fromCharCode(65 + index))
  }, [selectedOption])

  async function changeTier(nextTier: string) {
    if (!browser) return
    const nextRegion = nextTier === 'Regional' ? (regions[0] ?? 'EUROPE') : null
    const option = browser.competition_options.find((item) =>
      item.tier_family === nextTier
      && (nextTier !== 'Regional' || item.selector_region === nextRegion),
    )
    if (option) await loadBrowser(option.division_id, option.format_kind === 'group' ? 'A' : null)
  }

  async function changeRegion(nextRegion: string) {
    if (!browser) return
    const option = browser.competition_options.find((item) =>
      item.tier_family === 'Regional' && item.selector_region === nextRegion,
    )
    if (option) await loadBrowser(option.division_id, 'A')
  }

  if (loading) {
    return <section className="tlg-v2-panel nt-division-browser-state">Loading national competition…</section>
  }

  if (error || !browser?.available || !selectedOption) {
    return <section className="tlg-v2-panel nt-division-browser-state">{error ?? 'National competition is unavailable.'}</section>
  }

  const viewingMine = browser.selected_division.division_id === browser.my_division_id

  return (
    <section className="tlg-v2-panel nt-division-browser-shell">
      <div className="nt-division-browser-head">
        <div>
          <span>DIVISIONS</span>
          <h2>{browser.selected_division.label}{browser.selected_group_code ? ` · Group ${browser.selected_group_code}` : ''}</h2>
          <p>
            Season {browser.season_number} · {viewingMine ? 'Your national team competition' : 'Competition browser'}
          </p>
        </div>

        {!viewingMine && (
          <button type="button" className="nt-division-my-competition" disabled={switching} onClick={() => void loadBrowser(null, null)}>
            <RotateCcw size={14} /> My competition
          </button>
        )}
      </div>

      <div className="nt-division-filters">
        <label>
          <span>Tier</span>
          <select value={tierFamily} disabled={switching} onChange={(event) => void changeTier(event.target.value)}>
            <option value="Qualifiers">Qualifiers / Final 8</option>
            <option value="World Groups">World Groups</option>
            <option value="Regional">Regional</option>
          </select>
        </label>

        <label>
          <span>Region</span>
          <select
            value={tierFamily === 'Regional' ? selectedRegion : 'GLOBAL'}
            disabled={switching || tierFamily !== 'Regional'}
            onChange={(event) => void changeRegion(event.target.value)}
          >
            {tierFamily !== 'Regional'
              ? <option value="GLOBAL">Global</option>
              : regions.map((region) => <option key={region} value={region}>{regionLabel(region)}</option>)}
          </select>
        </label>

        <label>
          <span>Competition</span>
          <select
            value={browser.selected_division.division_id}
            disabled={switching}
            onChange={(event) => {
              const option = browser.competition_options.find((item) => item.division_id === event.target.value)
              void loadBrowser(event.target.value, option?.format_kind === 'group' ? 'A' : null)
            }}
          >
            {competitionChoices.map((option) => (
              <option key={option.division_id} value={option.division_id}>{option.label}</option>
            ))}
          </select>
        </label>
      </div>

      {switching && <div className="nt-division-switching">Loading selected competition…</div>}

      {!switching && browser.selected_division.format_kind === 'knockout' && (
        <div className="nt-division-knockout">
          <div className="nt-division-view-intro">
            <span>KNOCKOUT PATH</span>
            <h3>Qualifier Round 1 → Qualifier Round 2 → Final 8</h3>
            <p>
              This is the championship path for this season. Winners advance to the next knockout stage; the Final 8 continues through quarterfinal, semifinal and final.
            </p>
          </div>
          <KnockoutTree browser={browser} />
        </div>
      )}

      {!switching && browser.selected_division.format_kind === 'group' && (
        <GroupView
          browser={browser}
          groupCodes={groupCodes}
          onGroupChange={(groupCode) => void loadBrowser(browser.selected_division.division_id, groupCode)}
        />
      )}
    </section>
  )
}
