import { Clock3, Send, Users } from 'lucide-react'
import { useCallback, useEffect, useRef, useState } from 'react'

import { supabase } from '../../lib/supabase'

interface ChatRow {
  message_id: string
  player_id: string
  player_name: string
  game_absolute_day: number
  message: string
  created_at: string
  is_mine: boolean
}

interface PresenceParticipant {
  user_id: string
  player_id: string
  player_name: string
  joined_at: string
  last_active_at: string
  is_me: boolean
}

interface PresenceState {
  is_member: boolean
  joined: boolean
  joined_at?: string | null
  last_active_at?: string | null
  expires_at?: string | null
  timeout_minutes?: number
  participants: PresenceParticipant[]
}

interface NationalTeamChatProps {
  isMember: boolean
  associationName: string
}

const EMPTY_PRESENCE: PresenceState = {
  is_member: false,
  joined: false,
  participants: [],
  timeout_minutes: 10,
}

function formatChatTime(value?: string | null) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}

export default function NationalTeamChat({ isMember, associationName }: NationalTeamChatProps) {
  const [rows, setRows] = useState<ChatRow[]>([])
  const [presence, setPresence] = useState<PresenceState>(EMPTY_PRESENCE)
  const [draft, setDraft] = useState('')
  const [loading, setLoading] = useState(isMember)
  const [working, setWorking] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const lastInteractionRef = useRef<number>(Date.now())

  const markActivity = useCallback(() => {
    lastInteractionRef.current = Date.now()
  }, [])

  const load = useCallback(async () => {
    if (!isMember) {
      setRows([])
      setPresence(EMPTY_PRESENCE)
      setLoading(false)
      return
    }

    setLoading(true)
    const [chatResult, presenceResult] = await Promise.all([
      supabase.rpc('get_my_national_team_chat_v1', { p_limit: 150 }),
      supabase.rpc('get_my_national_team_chat_presence_v1'),
    ])

    if (chatResult.error) {
      setRows([])
      setError(chatResult.error.message)
    } else {
      setRows((chatResult.data ?? []) as ChatRow[])
    }

    if (presenceResult.error) {
      setPresence(EMPTY_PRESENCE)
      setError(presenceResult.error.message)
    } else {
      setPresence((presenceResult.data ?? EMPTY_PRESENCE) as PresenceState)
      if (!chatResult.error) setError(null)
    }

    setLoading(false)
  }, [isMember])

  const refreshPresence = useCallback(async () => {
    if (!isMember) return

    const { data, error: rpcError } = await supabase.rpc('get_my_national_team_chat_presence_v1')
    if (rpcError) {
      setError(rpcError.message)
      return
    }

    setPresence((data ?? EMPTY_PRESENCE) as PresenceState)
  }, [isMember])

  useEffect(() => {
    void load()
  }, [load])

  useEffect(() => {
    if (!isMember) return

    const poll = window.setInterval(() => {
      void refreshPresence()
    }, 30_000)

    return () => window.clearInterval(poll)
  }, [isMember, refreshPresence])

  useEffect(() => {
    if (!isMember || !presence.joined) return

    const heartbeat = window.setInterval(async () => {
      const wasRecentlyActive = Date.now() - lastInteractionRef.current < 90_000
      if (!wasRecentlyActive) {
        await refreshPresence()
        return
      }

      const { data, error: rpcError } = await supabase.rpc('touch_my_national_team_chat_v1')
      if (rpcError) {
        setError(rpcError.message)
        return
      }

      const result = data as { joined?: boolean } | null
      if (!result?.joined) {
        await refreshPresence()
        return
      }

      await refreshPresence()
    }, 60_000)

    return () => window.clearInterval(heartbeat)
  }, [isMember, presence.joined, refreshPresence])

  async function joinChat() {
    if (!isMember || working) return

    setWorking(true)
    setError(null)
    markActivity()

    const { error: rpcError } = await supabase.rpc('join_my_national_team_chat_v1')

    if (rpcError) setError(rpcError.message)
    else await refreshPresence()

    setWorking(false)
  }

  async function sendMessage() {
    const value = draft.trim()
    if (!value || working || !isMember || !presence.joined) return

    setWorking(true)
    setError(null)
    markActivity()

    const { error: rpcError } = await supabase.rpc('send_national_team_chat_message_v1', {
      p_message: value,
    })

    if (rpcError) {
      setError(rpcError.message)
      await refreshPresence()
    } else {
      setDraft('')
      await load()
    }

    setWorking(false)
  }

  const activeParticipants = presence.participants ?? []
  const recentHistory = rows.slice(0, 5)
  const joinLabel = activeParticipants.length > 0 ? 'Join Chat' : 'Start Chat'

  return (
    <div className="nt-chat-layout" onPointerDown={markActivity} onKeyDown={markActivity}>
      <section className="tlg-v2-panel nt-team-chat nt-team-chat-page">
        <header className="nt-section-header">
          <div>
            <span>PRIVATE TEAM CHAT</span>
            <h3>{associationName} member room</h3>
          </div>
        </header>

        {!isMember ? (
          <div className="nt-placeholder">
            Join the association first to access its private national-team chat.
          </div>
        ) : loading ? (
          <div className="nt-chat-empty">Loading association messages…</div>
        ) : (
          <>
            <p>
              All active association members can read the conversation. Join the live room to post messages and appear in the active-participant list.
            </p>

            {error && <div className="nt-alert nt-alert-error">{error}</div>}

            <div className="nt-chat-stream">
              {rows.length === 0 ? (
                <div className="nt-chat-empty">No messages yet.</div>
              ) : [...rows].reverse().map((row) => (
                <article key={row.message_id} className={row.is_mine ? 'mine' : ''}>
                  <header>
                    <strong>{row.player_name}</strong>
                    <span>{formatChatTime(row.created_at)} · Game day {row.game_absolute_day}</span>
                  </header>
                  <p>{row.message}</p>
                </article>
              ))}
            </div>

            <div className={\`nt-chat-compose \${presence.joined ? '' : 'locked'}\`}>
              <textarea
                value={draft}
                maxLength={1000}
                disabled={!presence.joined}
                placeholder={presence.joined ? 'Message your national association…' : 'Join the live chat to send a message…'}
                onChange={(event) => {
                  markActivity()
                  setDraft(event.target.value)
                }}
              />
              <button
                type="button"
                disabled={working || !presence.joined || !draft.trim()}
                onClick={() => void sendMessage()}
              >
                <Send size={15} /> {working ? 'Sending…' : 'Send'}
              </button>
            </div>

            {!presence.joined && (
              <div className="nt-chat-readonly-note">
                You are currently reading in view-only mode. Join the live room to send messages.
              </div>
            )}
          </>
        )}
      </section>

      <aside className="tlg-v2-panel nt-chat-room-panel">
        <header className="nt-section-header">
          <div>
            <span>LIVE CHAT ROOM</span>
            <h3>{presence.joined ? 'You are in the room' : 'Join the conversation'}</h3>
          </div>
        </header>

        {!isMember ? (
          <div className="nt-placeholder">Association membership is required.</div>
        ) : (
          <>
            {!presence.joined ? (
              <div className="nt-chat-join-card">
                <Users size={22} />
                <strong>{joinLabel}</strong>
                <span>
                  {activeParticipants.length > 0
                    ? \`\${activeParticipants.length} member\${activeParticipants.length === 1 ? '' : 's'} currently active. You can read the conversation before joining.\`
                    : 'Nobody is active in the live room right now. You can start the session.'}
                </span>
                <button type="button" disabled={working} onClick={() => void joinChat()}>
                  {working ? 'Joining…' : joinLabel}
                </button>
                <small>Live presence expires after 10 minutes without chat activity.</small>
              </div>
            ) : (
              <div className="nt-chat-session-status">
                <div>
                  <span>SESSION ACTIVE</span>
                  <strong>Joined at {formatChatTime(presence.joined_at)}</strong>
                </div>
                <small>
                  <Clock3 size={13} />
                  Expires after 10 minutes of inactivity
                </small>
              </div>
            )}

            {presence.joined && (
              <div className="nt-chat-side-section">
                <div className="nt-chat-side-heading">
                  <span>ACTIVE PARTICIPANTS</span>
                  <strong>{activeParticipants.length}</strong>
                </div>

                <div className="nt-chat-participants">
                  {activeParticipants.length === 0 ? (
                    <p>No active participants.</p>
                  ) : activeParticipants.map((participant) => (
                    <div key={participant.user_id}>
                      <span className="nt-chat-presence-dot" />
                      <div>
                        <strong>{participant.player_name}{participant.is_me ? ' · You' : ''}</strong>
                        <small>Active {formatChatTime(participant.last_active_at)}</small>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            <div className="nt-chat-side-section">
              <div className="nt-chat-side-heading">
                <span>RECENT CHAT HISTORY</span>
                <strong>{rows.length}</strong>
              </div>

              <div className="nt-chat-recent-history">
                {recentHistory.length === 0 ? (
                  <p>No chat history yet.</p>
                ) : recentHistory.map((row) => (
                  <article key={row.message_id}>
                    <header>
                      <strong>{row.player_name}</strong>
                      <span>{formatChatTime(row.created_at)}</span>
                    </header>
                    <p>{row.message}</p>
                  </article>
                ))}
              </div>
            </div>
          </>
        )}
      </aside>
    </div>
  )
}
