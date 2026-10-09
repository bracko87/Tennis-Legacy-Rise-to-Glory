import { useEffect, useMemo, useState } from 'react'
import { useTranslation, type TFunction } from 'react-i18next'
import { Link } from 'react-router'

import GameLayout from '../../components/layout/GameLayout'
import { useLocalization } from '../../i18n/LocalizationProvider'
import { supabase } from '../../lib/supabase'
import '../../styles/tennis-club.css'

type ClubTab = 'members' | 'world' | 'chat'

type ClubRanking = {
  id: string
  name: string
  world_rank: number
  points: number
  member_count: number
  atp_members: number
  wta_members: number
  owner_player_id: string
  created_absolute_day: number
}

type ClubSummary = ClubRanking & { role: 'owner' | 'member' }

type ClubMember = {
  player_id: string
  first_name: string
  last_name: string
  world: string
  role: 'owner' | 'member'
  ranking_points: number
  joined_absolute_day: number
}

type ClubRequest = {
  request_id: string
  club_id?: string
  club_name?: string
  player_id?: string
  first_name?: string
  last_name?: string
  world?: string
  ranking_points?: number
  owner_name?: string
  created_absolute_day: number
}

type ClubChatMessage = {
  id: string
  player_id: string
  first_name: string
  last_name: string
  world: string
  game_absolute_day: number
  season: number
  month: number
  day: number
  message: string
  created_at?: string
}

type ClubCandidate = {
  player_id: string
  first_name: string
  last_name: string
  world: string
  ranking_points: number
}

type ClubDashboard = {
  player: {
    id: string
    first_name: string
    last_name: string
    world: string
    ranking_points: number
  }
  coins_balance: number
  settings: {
    creation_cost_coins: number
    chat_history_game_days: number
  }
  club: ClubSummary | null
  members: ClubMember[]
  invitations: ClubRequest[]
  applications: ClubRequest[]
  incoming_applications: ClubRequest[]
  world_clubs: ClubRanking[]
  chat: {
    club_id: string | null
    history_game_days?: number
    messages: ClubChatMessage[]
  }
  current_absolute_day: number
}

function gameDate(message: ClubChatMessage, t: TFunction) {
  const months = t('staffPage.months', { returnObjects: true }) as string[]
  const month = months[message.month] ?? `M${message.month}`
  return t('tennisClubPage.chat.gameDate', { month, day: message.day, season: message.season })
}

function WorldBadge({ world }: { world?: string }) {
  const normalized = String(world ?? '').toUpperCase()
  return <span className={`tlg-club-world-badge ${normalized === 'WTA' ? 'wta' : 'atp'}`}>{normalized || 'ATP'}</span>
}

export default function TennisClubPage() {
  const { t } = useTranslation()
  const { formatNumber } = useLocalization()
  const number = (value: number) => formatNumber(Math.round(Number(value) || 0))
  const [tab, setTab] = useState<ClubTab>('members')
  const [dashboard, setDashboard] = useState<ClubDashboard | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [clubName, setClubName] = useState('')
  const [inviteQuery, setInviteQuery] = useState('')
  const [inviteCandidates, setInviteCandidates] = useState<ClubCandidate[]>([])
  const [chatText, setChatText] = useState('')

  async function loadDashboard(background = false) {
    if (!background) setLoading(true)
    setError(null)
    const { data, error: dashboardError } = await supabase.rpc('get_tennis_club_dashboard_v1')
    if (dashboardError || !data) setError(dashboardError?.message ?? t('tennisClubPage.loadError'))
    else setDashboard(data as ClubDashboard)
    if (!background) setLoading(false)
  }

  async function loadChat() {
    const { data, error: chatError } = await supabase.rpc('get_tennis_club_chat_v1')
    if (chatError || !data) return
    setDashboard((current) => current ? { ...current, chat: data as ClubDashboard['chat'] } : current)
  }

  useEffect(() => {
    void loadDashboard()
  }, [])

  useEffect(() => {
    const clubId = dashboard?.club?.id
    if (!clubId) return
    const channel = supabase
      .channel(`tennis-club-chat-${clubId}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'tennis_club_chat_messages', filter: `club_id=eq.${clubId}` }, () => {
        void loadChat()
      })
      .subscribe()
    return () => {
      void supabase.removeChannel(channel)
    }
  }, [dashboard?.club?.id])

  async function runAction(key: string, action: () => Promise<{ error: { message?: string } | null }>, success: string) {
    setBusy(key)
    setError(null)
    setMessage(null)
    const result = await action()
    if (result.error) setError(result.error.message ?? t('tennisClubPage.actionError'))
    else {
      setMessage(success)
      await loadDashboard(true)
    }
    setBusy(null)
  }

  async function createClub() {
    const trimmed = clubName.trim()
    if (trimmed.length < 3) {
      setError(t('tennisClubPage.create.nameError'))
      return
    }
    await runAction(
      'create',
      async () => {
        const { error: createError } = await supabase.rpc('create_tennis_club_v1', { p_name: trimmed })
        return { error: createError }
      },
      t('tennisClubPage.create.success', { name: trimmed }),
    )
    setClubName('')
  }

  async function applyToClub(club: ClubRanking) {
    await runAction(
      `apply:${club.id}`,
      async () => {
        const { error: applyError } = await supabase.rpc('apply_to_tennis_club_v1', { p_club_id: club.id })
        return { error: applyError }
      },
      t('tennisClubPage.join.applicationSent', { name: club.name }),
    )
  }

  async function respondRequest(requestId: string, accept: boolean, success: string) {
    await runAction(
      `request:${requestId}:${accept ? 'accept' : 'decline'}`,
      async () => {
        const { error: requestError } = await supabase.rpc('respond_tennis_club_request_v1', { p_request_id: requestId, p_accept: accept })
        return { error: requestError }
      },
      success,
    )
  }

  async function searchInviteCandidates() {
    setBusy('search')
    setError(null)
    const { data, error: searchError } = await supabase.rpc('search_tennis_club_invite_candidates_v1', { p_query: inviteQuery.trim() })
    if (searchError) setError(searchError.message)
    else setInviteCandidates((data ?? []) as ClubCandidate[])
    setBusy(null)
  }

  async function invitePlayer(candidate: ClubCandidate) {
    await runAction(
      `invite:${candidate.player_id}`,
      async () => {
        const { error: inviteError } = await supabase.rpc('invite_to_tennis_club_v1', { p_player_id: candidate.player_id })
        return { error: inviteError }
      },
      t('tennisClubPage.ownerTools.invitationSent', { name: `${candidate.first_name} ${candidate.last_name}` }),
    )
    setInviteCandidates((current) => current.filter((item) => item.player_id !== candidate.player_id))
  }

  async function sendChatMessage() {
    const trimmed = chatText.trim()
    if (!trimmed) return
    setBusy('chat')
    setError(null)
    const { error: chatError } = await supabase.rpc('send_tennis_club_chat_message_v1', { p_message: trimmed })
    if (chatError) setError(chatError.message)
    else {
      setChatText('')
      await loadChat()
    }
    setBusy(null)
  }

  const pendingApplications = useMemo(() => new Set((dashboard?.applications ?? []).map((item) => item.club_id)), [dashboard?.applications])
  const pendingInvitations = useMemo(() => new Set((dashboard?.invitations ?? []).map((item) => item.club_id)), [dashboard?.invitations])

  if (loading && !dashboard) {
    return (
      <GameLayout title={t('tennisClubPage.title')} subtitle={t('tennisClubPage.subtitle')}>
        <div className="tlg-club-state">{t('tennisClubPage.loading')}</div>
      </GameLayout>
    )
  }

  return (
    <GameLayout title={t('tennisClubPage.title')} subtitle={t('tennisClubPage.subtitle')}>
      <div className="tlg-club-page">
        <section className="tlg-club-hero">
          <div>
            <span>{t('tennisClubPage.kicker')}</span>
            <h1>{t('tennisClubPage.title')}</h1>
            <p>{t('tennisClubPage.intro')}</p>
          </div>
        </section>

        <div className="tlg-club-tabs" role="tablist" aria-label={t('tennisClubPage.tabsAria')}>
          <button type="button" className={tab === 'members' ? 'active' : ''} onClick={() => setTab('members')}>{t('tennisClubPage.tabs.members')}</button>
          <button type="button" className={tab === 'world' ? 'active' : ''} onClick={() => setTab('world')}>{t('tennisClubPage.tabs.world')}</button>
          <button type="button" className={tab === 'chat' ? 'active' : ''} onClick={() => setTab('chat')}>{t('tennisClubPage.tabs.chat')}</button>
        </div>

        {error && <div className="tlg-club-alert error">{error}</div>}
        {message && <div className="tlg-club-alert">{message}</div>}

        {dashboard && tab === 'members' && !dashboard.club && (
          <div className="tlg-club-members-empty-view">
            <section className="tlg-club-create-grid">
              <article className="tlg-club-create-card">
                <span>{t('tennisClubPage.create.kicker')}</span>
                <h2>{t('tennisClubPage.create.title')}</h2>
                <p>{t('tennisClubPage.create.body', { count: dashboard.settings.creation_cost_coins })}</p>
                <div className="tlg-club-coin-row">
                  <div><span>{t('tennisClubPage.create.yourCoins')}</span><strong>{number(dashboard.coins_balance)}</strong></div>
                  <div><span>{t('tennisClubPage.create.cost')}</span><strong>{number(dashboard.settings.creation_cost_coins)}</strong></div>
                </div>
                <label>
                  <span>{t('tennisClubPage.create.name')}</span>
                  <input value={clubName} maxLength={40} placeholder={t('tennisClubPage.create.placeholder')} onChange={(event) => setClubName(event.target.value)} />
                </label>
                <button type="button" className="primary" disabled={busy === 'create' || dashboard.coins_balance < dashboard.settings.creation_cost_coins} onClick={() => void createClub()}>
                  {busy === 'create' ? t('tennisClubPage.create.creating') : dashboard.coins_balance < dashboard.settings.creation_cost_coins ? t('tennisClubPage.create.needCoins', { count: dashboard.settings.creation_cost_coins }) : t('tennisClubPage.create.button', { count: dashboard.settings.creation_cost_coins })}
                </button>
              </article>

              <article className="tlg-club-join-card">
                <span>{t('tennisClubPage.join.kicker')}</span>
                <h2>{t('tennisClubPage.join.title')}</h2>
                <p>{t('tennisClubPage.join.body')}</p>
                <div className="tlg-club-request-stack">
                  {dashboard.invitations.length === 0 && dashboard.applications.length === 0 && <div className="tlg-club-empty">{t('tennisClubPage.join.none')}</div>}
                  {dashboard.invitations.map((invite) => (
                    <div className="tlg-club-request-row" key={invite.request_id}>
                      <div><span>{t('tennisClubPage.join.invitation')}</span><strong>{invite.club_name}</strong><small>{t('tennisClubPage.join.from', { name: invite.owner_name })}</small></div>
                      <div className="actions">
                        <button type="button" className="accept" disabled={busy?.startsWith(`request:${invite.request_id}`)} onClick={() => void respondRequest(invite.request_id, true, t('tennisClubPage.join.joined', { name: invite.club_name }))}>{t('tennisClubPage.join.accept')}</button>
                        <button type="button" disabled={busy?.startsWith(`request:${invite.request_id}`)} onClick={() => void respondRequest(invite.request_id, false, t('tennisClubPage.join.declined'))}>{t('tennisClubPage.join.decline')}</button>
                      </div>
                    </div>
                  ))}
                  {dashboard.applications.map((application) => (
                    <div className="tlg-club-request-row pending" key={application.request_id}>
                      <div><span>{t('tennisClubPage.join.pending')}</span><strong>{application.club_name}</strong><small>{t('tennisClubPage.join.waiting')}</small></div>
                      <b>{t('tennisClubPage.join.pendingLabel')}</b>
                    </div>
                  ))}
                </div>
              </article>
            </section>

            <section className="tlg-club-panel">
              <header className="tlg-club-panel-head">
                <div><span>{t('tennisClubPage.find.kicker')}</span><h2>{t('tennisClubPage.find.title')}</h2><p>{t('tennisClubPage.find.body')}</p></div>
                <button type="button" className="text-action" onClick={() => setTab('world')}>{t('tennisClubPage.find.top50')}</button>
              </header>
              <WorldClubTable t={t} number={number} clubs={dashboard.world_clubs.slice(0, 12)} ownClubId={null} canApply pendingApplications={pendingApplications} pendingInvitations={pendingInvitations} busy={busy} onApply={applyToClub} />
            </section>
          </div>
        )}

        {dashboard && tab === 'members' && dashboard.club && (
          <div className="tlg-club-members-view">
            <section className="tlg-club-summary">
              <div className="identity"><span>{t('tennisClubPage.own.kicker')}</span><h2>{dashboard.club.name}</h2><small>{dashboard.club.role === 'owner' ? t('tennisClubPage.own.owner') : t('tennisClubPage.own.member')} · {t('tennisClubPage.own.shared')}</small></div>
              <Metric label={t('tennisClubPage.own.worldRank')} value={`#${dashboard.club.world_rank ?? '—'}`} />
              <Metric label={t('tennisClubPage.own.clubPoints')} value={number(dashboard.club.points)} />
              <Metric label={t('tennisClubPage.own.members')} value={number(dashboard.club.member_count)} detail={`${dashboard.club.atp_members} ATP · ${dashboard.club.wta_members} WTA`} />
            </section>

            <section className="tlg-club-panel">
              <header className="tlg-club-panel-head"><div><span>{t('tennisClubPage.own.roster')}</span><h2>{t('tennisClubPage.own.members')}</h2><p>{t('tennisClubPage.own.rosterBody')}</p></div></header>
              <div className="tlg-club-member-table-wrap">
                <table className="tlg-club-table">
                  <thead><tr><th>{t('tennisClubPage.own.columns.member')}</th><th>{t('tennisClubPage.own.columns.tour')}</th><th>{t('tennisClubPage.own.columns.role')}</th><th>{t('tennisClubPage.own.columns.points')}</th><th>{t('tennisClubPage.own.columns.contribution')}</th></tr></thead>
                  <tbody>
                    {dashboard.members.map((member) => (
                      <tr key={member.player_id}>
                        <td><Link to={`/game/players/${member.player_id}`}>{member.first_name} {member.last_name}</Link></td>
                        <td><WorldBadge world={member.world} /></td>
                        <td>{member.role === 'owner' ? t('tennisClubPage.own.roleOwner') : t('tennisClubPage.own.roleMember')}</td>
                        <td>{number(member.ranking_points)}</td>
                        <td><strong>{t('tennisClubPage.own.pointsShort', { count: number(member.ranking_points) })}</strong></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>

            {dashboard.club.role === 'owner' && (
              <section className="tlg-club-owner-grid">
                <article className="tlg-club-panel">
                  <header className="tlg-club-panel-head compact"><div><span>{t('tennisClubPage.ownerTools.applications')}</span><h2>{t('tennisClubPage.ownerTools.pendingRequests')}</h2></div></header>
                  <div className="tlg-club-owner-list">
                    {dashboard.incoming_applications.length === 0 && <div className="tlg-club-empty">{t('tennisClubPage.ownerTools.noRequests')}</div>}
                    {dashboard.incoming_applications.map((application) => (
                      <div className="tlg-club-owner-row" key={application.request_id}>
                        <div><strong>{application.first_name} {application.last_name}</strong><span><WorldBadge world={application.world} /> {t('tennisClubPage.own.pointsShort', { count: number(application.ranking_points ?? 0) })}</span></div>
                        <div className="actions">
                          <button type="button" className="accept" disabled={busy?.startsWith(`request:${application.request_id}`)} onClick={() => void respondRequest(application.request_id, true, t('tennisClubPage.ownerTools.joinedClub', { name: `${application.first_name} ${application.last_name}` }))}>{t('tennisClubPage.join.accept')}</button>
                          <button type="button" disabled={busy?.startsWith(`request:${application.request_id}`)} onClick={() => void respondRequest(application.request_id, false, t('tennisClubPage.ownerTools.applicationDeclined'))}>{t('tennisClubPage.join.decline')}</button>
                        </div>
                      </div>
                    ))}
                  </div>
                </article>

                <article className="tlg-club-panel">
                  <header className="tlg-club-panel-head compact"><div><span>{t('tennisClubPage.ownerTools.invite')}</span><h2>{t('tennisClubPage.ownerTools.searchTitle')}</h2><p>{t('tennisClubPage.ownerTools.searchBody')}</p></div></header>
                  <div className="tlg-club-invite-search">
                    <div><input value={inviteQuery} placeholder={t('tennisClubPage.ownerTools.playerPlaceholder')} onChange={(event) => setInviteQuery(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter') void searchInviteCandidates() }} /><button type="button" onClick={() => void searchInviteCandidates()} disabled={busy === 'search'}>{busy === 'search' ? t('tennisClubPage.ownerTools.searching') : t('tennisClubPage.ownerTools.search')}</button></div>
                    <div className="tlg-club-candidate-list">
                      {inviteCandidates.map((candidate) => (
                        <div key={candidate.player_id}>
                          <div><strong>{candidate.first_name} {candidate.last_name}</strong><span><WorldBadge world={candidate.world} /> {t('tennisClubPage.own.pointsShort', { count: number(candidate.ranking_points) })}</span></div>
                          <button type="button" disabled={busy === `invite:${candidate.player_id}`} onClick={() => void invitePlayer(candidate)}>{busy === `invite:${candidate.player_id}` ? t('tennisClubPage.ownerTools.sending') : t('tennisClubPage.ownerTools.inviteButton')}</button>
                        </div>
                      ))}
                    </div>
                  </div>
                </article>
              </section>
            )}
          </div>
        )}

        {dashboard && tab === 'world' && (
          <section className="tlg-club-panel tlg-club-world-panel">
            <header className="tlg-club-panel-head">
              <div><span>{t('tennisClubPage.world.kicker')}</span><h2>{t('tennisClubPage.world.title')}</h2><p>{t('tennisClubPage.world.body')}</p></div>
              <div className="tlg-club-ranking-note"><strong>{dashboard.world_clubs.length}</strong><span>{t('tennisClubPage.world.ranked', { count: dashboard.world_clubs.length })}</span></div>
            </header>
            <WorldClubTable t={t} number={number} clubs={dashboard.world_clubs} ownClubId={dashboard.club?.id ?? null} canApply={!dashboard.club} pendingApplications={pendingApplications} pendingInvitations={pendingInvitations} busy={busy} onApply={applyToClub} />
          </section>
        )}

        {dashboard && tab === 'chat' && !dashboard.club && (
          <section className="tlg-club-chat-locked">
            <span>{t('tennisClubPage.chat.membersOnly')}</span>
            <h2>{t('tennisClubPage.chat.locked')}</h2>
            <p>{t('tennisClubPage.chat.lockedBody')}</p>
            <button type="button" onClick={() => setTab('members')}>{t('tennisClubPage.chat.goMembers')}</button>
          </section>
        )}

        {dashboard && tab === 'chat' && dashboard.club && (
          <section className="tlg-club-panel tlg-club-chat-panel">
            <header className="tlg-club-panel-head">
              <div><span>{t('tennisClubPage.chat.kicker')}</span><h2>{dashboard.club.name}</h2><p>{t('tennisClubPage.chat.body', { count: dashboard.settings.chat_history_game_days })}</p></div>
              <div className="tlg-club-chat-status"><strong>{dashboard.members.length}</strong><span>{t('tennisClubPage.chat.members', { count: dashboard.members.length })}</span></div>
            </header>
            <div className="tlg-club-chat-messages">
              {(dashboard.chat?.messages ?? []).length === 0 && <div className="tlg-club-empty chat">{t('tennisClubPage.chat.empty')}</div>}
              {(dashboard.chat?.messages ?? []).map((chatMessage) => {
                const mine = chatMessage.player_id === dashboard.player.id
                return (
                  <div className={`tlg-club-chat-message${mine ? ' mine' : ''}`} key={chatMessage.id}>
                    <div className="meta"><strong>{chatMessage.first_name} {chatMessage.last_name}</strong><WorldBadge world={chatMessage.world} /><span>{gameDate(chatMessage, t)}</span></div>
                    <p>{chatMessage.message}</p>
                  </div>
                )
              })}
            </div>
            <div className="tlg-club-chat-compose">
              <textarea maxLength={500} rows={3} value={chatText} placeholder={t('tennisClubPage.chat.placeholder')} onChange={(event) => setChatText(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); void sendChatMessage() } }} />
              <div><span>{t('tennisClubPage.chat.composeHint', { count: chatText.length })}</span><button type="button" disabled={!chatText.trim() || busy === 'chat'} onClick={() => void sendChatMessage()}>{busy === 'chat' ? t('tennisClubPage.chat.sending') : t('tennisClubPage.chat.send')}</button></div>
            </div>
          </section>
        )}
      </div>
    </GameLayout>
  )
}

function Metric({ label, value, detail }: { label: string; value: string; detail?: string }) {
  return <div className="tlg-club-metric"><span>{label}</span><strong>{value}</strong>{detail && <small>{detail}</small>}</div>
}

function WorldClubTable({ t, number, clubs, ownClubId, canApply, pendingApplications, pendingInvitations, busy, onApply }: {
  t: TFunction
  number: (value: number) => string
  clubs: ClubRanking[]
  ownClubId: string | null
  canApply: boolean
  pendingApplications: Set<string | undefined>
  pendingInvitations: Set<string | undefined>
  busy: string | null
  onApply: (club: ClubRanking) => Promise<void>
}) {
  if (clubs.length === 0) return <div className="tlg-club-empty table-empty">{t('tennisClubPage.world.empty')}</div>
  return (
    <div className="tlg-club-table-wrap">
      <table className="tlg-club-table world">
        <thead><tr><th>#</th><th>{t('tennisClubPage.world.columns.club')}</th><th>{t('tennisClubPage.world.columns.members')}</th><th>{t('tennisClubPage.world.columns.split')}</th><th>{t('tennisClubPage.world.columns.points')}</th><th>{t('tennisClubPage.world.columns.status')}</th></tr></thead>
        <tbody>
          {clubs.map((club) => {
            const isOwn = ownClubId === club.id
            const applied = pendingApplications.has(club.id)
            const invited = pendingInvitations.has(club.id)
            return (
              <tr key={club.id} className={isOwn ? 'own' : ''}>
                <td><strong>#{club.world_rank}</strong></td>
                <td><strong className="club-name">{club.name}</strong></td>
                <td>{number(club.member_count)}</td>
                <td><span className="tour-split"><b>{club.atp_members} ATP</b><b>{club.wta_members} WTA</b></span></td>
                <td><strong>{t('tennisClubPage.own.pointsShort', { count: number(club.points) })}</strong></td>
                <td>
                  {isOwn ? <span className="tlg-club-status-text">{t('tennisClubPage.world.yourClub')}</span> : applied ? <span className="tlg-club-status-text">{t('tennisClubPage.world.applicationPending')}</span> : invited ? <span className="tlg-club-status-text">{t('tennisClubPage.world.invitationReceived')}</span> : canApply ? <button type="button" className="apply" disabled={busy === `apply:${club.id}`} onClick={() => void onApply(club)}>{busy === `apply:${club.id}` ? t('tennisClubPage.world.applying') : t('tennisClubPage.world.apply')}</button> : <span className="tlg-club-status-text muted">—</span>}
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
