from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one match in {path}, found {count}")
    p.write_text(text.replace(old, new, 1))


exp = 'src/components/tournament/TournamentExperienceEnhancements.tsx'
replace_once(exp, "import { Link, useParams } from 'react-router'", "import { Link, useLocation, useParams } from 'react-router'")
replace_once(exp, "  world_rank: number\n  priority: number | null", "  world_rank: number\n  current_world_rank: number\n  priority: number | null")
replace_once(exp, "export default function TournamentExperienceEnhancements() {\n  const { competitionId } = useParams()\n  const [lifecycle, setLifecycle] = useState<LifecycleData | null>(null)", "export default function TournamentExperienceEnhancements() {\n  const { competitionId } = useParams()\n  const location = useLocation()\n  const [lifecycle, setLifecycle] = useState<LifecycleData | null>(null)")
replace_once(exp, "  const [drawBodyHost, setDrawBodyHost] = useState<HTMLElement | null>(null)\n", "  const [drawBodyHost, setDrawBodyHost] = useState<HTMLElement | null>(null)\n  const [fieldExpandedOverride, setFieldExpandedOverride] = useState<boolean | null>(null)\n\n  useEffect(() => {\n    setFieldExpandedOverride(null)\n  }, [competitionId])\n")
replace_once(exp, "  const groupedApplicants = useMemo(() => ({\n    main_draw: field?.applicants.filter((row) => row.projected_group === 'main_draw') ?? [],\n    qualification: field?.applicants.filter((row) => row.projected_group === 'qualification') ?? [],\n    outside: field?.applicants.filter((row) => row.projected_group === 'outside') ?? [],\n  }), [field])\n\n  return (", "  const groupedApplicants = useMemo(() => ({\n    main_draw: field?.applicants.filter((row) => row.projected_group === 'main_draw') ?? [],\n    qualification: field?.applicants.filter((row) => row.projected_group === 'qualification') ?? [],\n    outside: field?.applicants.filter((row) => row.projected_group === 'outside') ?? [],\n  }), [field])\n\n  const fieldExpanded = fieldExpandedOverride ?? !['draw_published', 'in_progress', 'completed'].includes(lifecycle?.phase ?? '')\n  const returnPath = `${location.pathname}${location.search}${location.hash}`\n\n  return (")

replace_once(exp, '''      {fieldHost && field && createPortal(
        <div className="tlg-applicant-field">
          <div className="tlg-applicant-field-head">
            <div><span>Live application field</span><strong>{field.applicant_count} applicants</strong></div>
            <p>Main Draw {field.main_draw_total_capacity}: {field.direct_main_draw_slots} direct places + {field.qualifier_slots} qualifier places · Qualification capacity {field.qualification_capacity}.</p>
          </div>
          <div className="tlg-applicant-scroll">''', '''      {fieldHost && field && createPortal(
        <div className={`tlg-applicant-field${fieldExpanded ? '' : ' collapsed'}`}>
          <div className="tlg-applicant-field-head">
            <div><span>Live application field</span><strong>{field.applicant_count} current applicant{field.applicant_count === 1 ? '' : 's'}</strong></div>
            <div className="tlg-applicant-field-head-actions">
              {fieldExpanded && <p>Main Draw {field.main_draw_total_capacity}: {field.direct_main_draw_slots} direct places + {field.qualifier_slots} qualifier places · Qualification capacity {field.qualification_capacity}.</p>}
              <button type="button" className="tlg-applicant-field-toggle" aria-expanded={fieldExpanded} onClick={() => setFieldExpandedOverride(!fieldExpanded)}>
                {fieldExpanded ? 'Hide field' : 'Show field'}
              </button>
            </div>
          </div>
          {fieldExpanded && <div className="tlg-applicant-scroll">''')

replace_once(exp, '''                      <b>#{row.world_rank}</b>
                      <CountryFlag countryCode={row.country_code ?? ''} countryName={row.country_code ?? ''} width={19} height={13} />
                      <strong>{row.first_name} {row.last_name}{row.is_user ? ' · You' : ''}</strong>''', '''                      <b title={row.current_world_rank !== row.world_rank ? `Current ranking: #${row.current_world_rank}` : undefined}>#{row.world_rank}</b>
                      <CountryFlag countryCode={row.country_code ?? ''} countryName={row.country_code ?? ''} width={19} height={13} />
                      <Link
                        className="tlg-applicant-player-link"
                        to={`/game/players/${row.player_id}`}
                        state={{ playerProfileReturn: returnPath, playerProfileReturnLabel: 'Back to Tournament' }}
                      >
                        {row.first_name} {row.last_name}{row.is_user ? ' · You' : ''}
                      </Link>''')

replace_once(exp, '''            })}
          </div>
        </div>, fieldHost)}''', '''            })}
          </div>}
        </div>, fieldHost)}''')


defence = 'src/components/tournament/TournamentDefendingPoints.tsx'
replace_once(defence, "  const [error, setError] = useState<string | null>(null)\n", "  const [error, setError] = useState<string | null>(null)\n  const [expanded, setExpanded] = useState(false)\n\n  useEffect(() => {\n    setExpanded(false)\n  }, [competitionId])\n")
replace_once(defence, '''    <section className="tlg-detail-panel tlg-defence-panel">
      <header className="tlg-detail-panel-head tlg-defence-head">
        <div>
          <span>Ranking protection</span>
          <h2>Defending Points</h2>
          <p>Last season's points from this same tournament series stay in the ranking until this edition's ranking cycle replaces them.</p>
        </div>
        <ShieldCheck size={20} />
      </header>''', '''    <section className={`tlg-detail-panel tlg-defence-panel${expanded ? '' : ' collapsed'}`}>
      <header className="tlg-detail-panel-head tlg-defence-head">
        <div>
          <span>Ranking protection</span>
          <h2>Defending Points</h2>
          {expanded && <p>Last season's points from this same tournament series stay in the ranking until this edition's ranking cycle replaces them.</p>}
        </div>
        <div className="tlg-defence-head-actions">
          {data && <span>{data.own.points_defending.toLocaleString()} pts defending</span>}
          <button type="button" aria-expanded={expanded} onClick={() => setExpanded((value) => !value)}>
            {expanded ? 'Collapse' : 'Expand'}
          </button>
          <ShieldCheck size={20} />
        </div>
      </header>''')

exp_css = Path('src/styles/tournament-experience-enhancements.css')
exp_css.write_text(exp_css.read_text() + '''

/* Collapsible application field and clean profile links. */
.tlg-applicant-field.collapsed .tlg-applicant-field-head{border-bottom:0}
.tlg-applicant-field-head-actions{display:flex;align-items:center;justify-content:flex-end;gap:10px;min-width:0}
.tlg-applicant-field-head-actions p{min-width:0}
.tlg-applicant-field-toggle{flex:0 0 auto;padding:6px 10px;border:1px solid #cbdce7;border-radius:7px;background:#fff;color:#315a75;font-size:.56rem;font-weight:800;cursor:pointer}
.tlg-applicant-field-toggle:hover{border-color:#9bc6e3;color:#0b6fc8;background:#f4faff}
.tlg-applicant-player-link{min-width:0;overflow:hidden;color:#294b62;font-size:.6rem;font-weight:760;text-decoration:none;text-overflow:ellipsis;white-space:nowrap}
.tlg-applicant-player-link:hover{color:#0b6fc8;text-decoration:none}
.tlg-applicant-row.is-user>.tlg-applicant-player-link{color:#0b609a;font-weight:850}
@media(max-width:980px){.tlg-applicant-field-head-actions{width:100%;justify-content:space-between}.tlg-applicant-field-head-actions p{text-align:left}}
''')

def_css = Path('src/styles/tournament-defending-points.css')
def_css.write_text(def_css.read_text() + '''

/* Defending Points is intentionally compact by default. */
.tlg-defence-panel.collapsed>.tlg-defence-head{border-bottom:0}
.tlg-defence-panel.collapsed>:not(.tlg-defence-head){display:none}
.tlg-defence-head-actions{display:flex;align-items:center;justify-content:flex-end;gap:10px;flex:0 0 auto}
.tlg-defence-head-actions>span{color:#6f8396;font-size:.62rem;font-weight:800;white-space:nowrap}
.tlg-defence-head-actions>button{padding:6px 10px;border:1px solid #cbdce7;border-radius:7px;background:#fff;color:#315a75;font-size:.58rem;font-weight:800;cursor:pointer}
.tlg-defence-head-actions>button:hover{border-color:#9bc6e3;color:#0b6fc8;background:#f4faff}
.tlg-defence-head-actions>svg{color:#0b6fc8}
@media(max-width:680px){.tlg-defence-head-actions>span{display:none}}
''')
