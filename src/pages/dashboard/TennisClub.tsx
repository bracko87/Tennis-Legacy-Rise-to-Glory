import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router'

import GameLayout from '../../components/layout/GameLayout'
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

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function number(value: number) {
  return Math.round(Number(value) || 0).toLocaleString()
}

function gameDate(message: ClubChatMessage) {
  return `${MONTHS[Math.max(0, message.month - 1)] ?? `M${message.month}`} ${message.day} · S${message.season}`
}

function WorldBadge({ world }: { world?: string }) {
  const normalized = String(world ?? '').toUpperCase()
  return <span className={`tlg-club-world-badge ${normalized === 'WTA' ? 'wta' : 'atp'}`}>{normalized || 'ATP'}</span>
}

export default function TennisClubPage() {
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
    if (dashboardError || !data) setError(dashboardError?.message ?? 'Unable to load Tennis Club.')
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
    if (result.error) setError(result.error.message ?? 'Unable to complete this club action.')
    else {
      setMessage(success)
      await loadDashboard(true)
    }
    setBusy(null)
  }

  async function createClub() {
    const trimmed = clubName.trim()
    if (trimmed.length < 3) {
      setError('Club name must contain at least 3 characters.')
      return
    }
    await runAction(
      'create',
      async () => {
        const { error: createError } = await supabase.rpc('create_tennis_club_v1', { p_name: trimmed })
        return { error: createError }
      },
      `${trimmed} created successfully.`,
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
      `Application sent to ${club.name}.`,
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
      `Invitation sent to ${candidate.first_name} ${candidate.last_name}.`,
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
      <GameLayout title="Tennis Club" subtitle="Shared ATP and WTA social clubs">
        <div className="tlg-club-state">Loading Tennis Club…</div>
      </GameLayout>
    )
  }

  return (
    <GameLayout title="Tennis Club" subtitle="Shared ATP and WTA social clubs">
      <div className="tlg-club-page">
        <section className="tlg-club-hero">
          <div>
            <span>SHARED TENNIS COMMUNITY</span>
            <h1>Tennis Club</h1>
            <p>ATP and WTA professionals meet in one shared club structure. Tour competition remains separate; club membership, club points and club chat are shared.</p>
          </div>
        </section>

        <div className="tlg-club-tabs" role="tablist" aria-label="Tennis Club sections">
          <button type="button" className={tab === 'members' ? 'active' : ''} onClick={() => setTab('members')}>Members</button>
          <button type="button" className={tab === 'world' ? 'active' : ''} onClick={() => setTab('world')}>World Clubs</button>
          <button type="button" className={tab === 'chat' ? 'active' : ''} onClick={() => setTab('chat')}>Club Chat</button>
        </div>

        {error && <div className="tlg-club-alert error">{error}</div>}
        {message && <div className="tlg-club-alert">{message}</div>}

        {dashboard && tab === 'members' && !dashboard.club && (
          <div className="tlg-club-members-empty-view">
            <section className="tlg-club-create-grid">
              <article className="tlg-club-create-card">
                <span>START YOUR OWN CLUB</span>
                <h2>Create a Tennis Club</h2>
                <p>Become the owner of a new shared ATP/WTA club. Creating a club is a Premium Coin action and costs exactly {dashboard.settings.creation_cost_coins} coins.</p>
                <div className="tlg-club-coin-row">
                  <div><span>YOUR COINS</span><strong>{number(dashboard.coins_balance)}</strong></div>
                  <div><span>CREATION COST</span><strong>{number(dashboard.settings.creation_cost_coins)}</strong></div>
                </div>
                <label>
                  <span>Club name</span>
                  <input value={clubName} maxLength={40} placeholder="Enter a unique club name" onChange={(event) => setClubName(event.target.value)} />
                </label>
                <button type="button" className="primary" disabled={busy === 'create' || dashboard.coins_balance < dashboard.settings.creation_cost_coins} onClick={() => void createClub()}>
                  {busy === 'create' ? 'Creating…' : dashboard.coins_balance < dashboard.settings.creation_cost_coins ? `Need ${dashboard.settings.creation_cost_coins} coins` : `Create Club · ${dashboard.settings.creation_cost_coins} coins`}
                </button>
              </article>

              <article className="tlg-club-join-card">
                <span>JOIN AN EXISTING CLUB</span>
                <h2>Applications & invitations</h2>
                <p>Apply to a club from the World Clubs list, or accept an invitation sent by a club owner.</p>
                <div className="tlg-club-request-stack">
                  {dashboard.invitations.length === 0 && dashboard.applications.length === 0 && <div className="tlg-club-empty">No pending invitations or applications.</div>}
                  {dashboard.invitations.map((invite) => (
                    <div className="tlg-club-request-row" key={invite.request_id}>
                      <div><span>INVITATION</span><strong>{invite.club_name}</strong><small>From {invite.owner_name}</small></div>
                      <div className="actions">
                        <button type="button" className="accept" disabled={busy?.startsWith(`request:${invite.request_id}`)} onClick={() => void respondRequest(invite.request_id, true, `You joined ${invite.club_name}.`)}>Accept</button>
                        <button type="button" disabled={busy?.startsWith(`request:${invite.request_id}`)} onClick={() => void respondRequest(invite.request_id, false, 'Invitation declined.')}>Decline</button>
                      </div>
                    </div>
                  ))}
                  {dashboard.applications.map((application) => (
                    <div className="tlg-club-request-row pending" key={application.request_id}>
                      <div><span>APPLICATION PENDING</span><strong>{application.club_name}</strong><small>Waiting for the club owner</small></div>
                      <b>Pending</b>
                    </div>
                  ))}
                </div>
              </article>
            </section>

            <section className="tlg-club-panel">
              <header className="tlg-club-panel-head">
                <div><span>FIND A CLUB</span><h2>Leading world clubs</h2><p>Apply to any club directly. The full ranking contains the top 50 clubs worldwide.</p></div>
                <button type="button" className="text-action" onClick={() => setTab('world')}>View Top 50</button>
              </header>
              <WorldClubTable clubs={dashboard.world_clubs.slice(0, 12)} ownClubId={null} canApply pendingApplications={pendingApplications} pendingInvitations={pendingInvitations} busy={busy} onApply={applyToClub} />
            </section>
          </div>
        )}

        {dashboard && tab === 'members' && dashboard.club && (
          <div className="tlg-club-members-view">
            <section className="tlg-club-summary">
              <div className="identity"><span>YOUR TENNIS CLUB</span><h2>{dashboard.club.name}</h2><small>{dashboard.club.role === 'owner' ? 'Club Owner' : 'Club Member'} · Shared ATP/WTA club</small></div>
              <Metric label="World Rank" value={`#${dashboard.club.world_rank ?? '—'}`} />
              <Metric label="Club Points" value={number(dashboard.club.points)} />
              <Metric label="Members" value={number(dashboard.club.member_count)} detail={`${dashboard.club.atp_members} ATP · ${dashboard.club.wta_members} WTA`} />
            </section>

            <section className="tlg-club-panel">
              <header className="tlg-club-panel-head"><div><span>CLUB ROSTER</span><h2>Members</h2><p>Club points are the live sum of every member's official ranking points, regardless of ATP or WTA tour.</p></div></header>
              <div className="tlg-club-member-table-wrap">
                <table className="tlg-club-table">
                  <thead><tr><th>Member</th><th>Tour</th><th>Role</th><th>Ranking Points</th><th>Contribution</th></tr></thead>
                  <tbody>
                    {dashboard.members.map((member) => (
                      <tr key={member.player_id}>
                        <td><Link to={`/game/players/${member.player_id}`}>{member.first_name} {member.last_name}</Link></td>
                        <td><WorldBadge world={member.world} /></td>
                        <td>{member.role === 'owner' ? 'Owner' : 'Member'}</td>
                        <td>{number(member.ranking_points)}</td>
                        <td><strong>{number(member.ranking_points)} pts</strong></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>

            {dashboard.club.role === 'owner' && (
              <section className="tlg-club-owner-grid">
                <article className="tlg-club-panel">
                  <header className="tlg-club-panel-head compact"><div><span>MEMBERSHIP APPLICATIONS</span><h2>Pending requests</h2></div></header>
                  <div className="tlg-club-owner-list">
                    {dashboard.incoming_applications.length === 0 && <div className="tlg-club-empty">No players are waiting for approval.</div>}
                    {dashboard.incoming_applications.map((application) => (
                      <div className="tlg-club-owner-row" key={application.request_id}>
                        <div><strong>{application.first_name} {application.last_name}</strong><span><WorldBadge world={application.world} /> {number(application.ranking_points ?? 0)} ranking pts</span></div>
                        <div className="actions">
                          <button type="button" className="accept" disabled={busy?.startsWith(`request:${application.request_id}`)} onClick={() => void respondRequest(application.request_id, true, `${application.first_name} ${application.last_name} joined the club.`)}>Accept</button>
                          <button type="button" disabled={busy?.startsWith(`request:${application.request_id}`)} onClick={() => void respondRequest(application.request_id, false, 'Application declined.')}>Decline</button>
                        </div>
                      </div>
                    ))}
                  </div>
                </article>

                <article className="tlg-club-panel">
                  <header className="tlg-club-panel-head compact"><div><span>INVITE A PLAYER</span><h2>ATP + WTA search</h2><p>Search human players from either tour who do not currently belong to a club.</p></div></header>
                  <div className="tlg-club-invite-search">
                    <div><input value={inviteQuery} placeholder="Player name" onChange={(event) => setInviteQuery(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter') void searchInviteCandidates() }} /><button type="button" onClick={() => void searchInviteCandidates()} disabled={busy === 'search'}>{busy === 'search' ? 'Searching…' : 'Search'}</button></div>
                    <div className="tlg-club-candidate-list">
                      {inviteCandidates.map((candidate) => (
                        <div key={candidate.player_id}>
                          <div><strong>{candidate.first_name} {candidate.last_name}</strong><span><WorldBadge world={candidate.world} /> {number(candidate.ranking_points)} pts</span></div>
                          <button type="button" disabled={busy === `invite:${candidate.player_id}`} onClick={() => void invitePlayer(candidate)}>{busy === `invite:${candidate.player_id}` ? 'Sending…' : 'Invite'}</button>
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
              <div><span>WORLD CLUB RANKING</span><h2>Top 50 Tennis Clubs</h2><p>Ranking points are recalculated live from every ATP and WTA member's current official ranking points.</p></div>
              <div className="tlg-club-ranking-note"><strong>{dashboard.world_clubs.length}</strong><span>clubs ranked</span></div>
            </header>
            <WorldClubTable clubs={dashboard.world_clubs} ownClubId={dashboard.club?.id ?? null} canApply={!dashboard.club} pendingApplications={pendingApplications} pendingInvitations={pendingInvitations} busy={busy} onApply={applyToClub} />
          </section>
        )}

        {dashboard && tab === 'chat' && !dashboard.club && (
          <section className="tlg-club-chat-locked">
            <span>MEMBERS ONLY</span>
            <h2>Club Chat is locked</h2>
            <p>Create a Tennis Club, join one through an application, or accept a club invitation to unlock the private member chat.</p>
            <button type="button" onClick={() => setTab('members')}>Go to Members</button>
          </section>
        )}

        {dashboard && tab === 'chat' && dashboard.club && (
          <section className="tlg-club-panel tlg-club-chat-panel">
            <header className="tlg-club-panel-head">
              <div><span>PRIVATE CLUB CHAT</span><h2>{dashboard.club.name}</h2><p>Only current club members can read or post here. Chat history is retained for the last {dashboard.settings.chat_history_game_days} in-game days.</p></div>
              <div className="tlg-club-chat-status"><strong>{dashboard.members.length}</strong><span>members</span></div>
            </header>
            <div className="tlg-club-chat-messages">
              {(dashboard.chat?.messages ?? []).length === 0 && <div className="tlg-club-empty chat">No club messages yet. Start the conversation.</div>}
              {(dashboard.chat?.messages ?? []).map((chatMessage) => {
                const mine = chatMessage.player_id === dashboard.player.id
                return (
                  <div className={`tlg-club-chat-message${mine ? ' mine' : ''}`} key={chatMessage.id}>
                    <div className="meta"><strong>{chatMessage.first_name} {chatMessage.last_name}</strong><WorldBadge world={chatMessage.world} /><span>{gameDate(chatMessage)}</span></div>
                    <p>{chatMessage.message}</p>
                  </div>
                )
              })}
            </div>
            <div className="tlg-club-chat-compose">
              <textarea maxLength={500} rows={3} value={chatText} placeholder="Write to your club…" onChange={(event) => setChatText(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); void sendChatMessage() } }} />
              <div><span>{chatText.length}/500 · Enter to send · Shift+Enter for new line</span><button type="button" disabled={!chatText.trim() || busy === 'chat'} onClick={() => void sendChatMessage()}>{busy === 'chat' ? 'Sending…' : 'Send message'}</button></div>
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

function WorldClubTable({ clubs, ownClubId, canApply, pendingApplications, pendingInvitations, busy, onApply }: {
  clubs: ClubRanking[]
  ownClubId: string | null
  canApply: boolean
  pendingApplications: Set<string | undefined>
  pendingInvitations: Set<string | undefined>
  busy: string | null
  onApply: (club: ClubRanking) => Promise<void>
}) {
  if (clubs.length === 0) return <div className="tlg-club-empty table-empty">No Tennis Clubs have been created yet.</div>
  return (
    <div className="tlg-club-table-wrap">
      <table className="tlg-club-table world">
        <thead><tr><th>#</th><th>Club</th><th>Members</th><th>ATP / WTA</th><th>Club Points</th><th>Status</th></tr></thead>
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
                <td><strong>{number(club.points)} pts</strong></td>
                <td>
                  {isOwn ? <span className="tlg-club-status-text">Your club</span> : applied ? <span className="tlg-club-status-text">Application pending</span> : invited ? <span className="tlg-club-status-text">Invitation received</span> : canApply ? <button type="button" className="apply" disabled={busy === `apply:${club.id}`} onClick={() => void onApply(club)}>{busy === `apply:${club.id}` ? 'Applying…' : 'Apply'}</button> : <span className="tlg-club-status-text muted">—</span>}
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
