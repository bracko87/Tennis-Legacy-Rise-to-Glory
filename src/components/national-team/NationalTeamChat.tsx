import { Send } from 'lucide-react'
import { useCallback, useEffect, useState } from 'react'

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

interface NationalTeamChatProps {
  isMember: boolean
  associationName: string
}

export default function NationalTeamChat({ isMember, associationName }: NationalTeamChatProps) {
  const [rows, setRows] = useState<ChatRow[]>([])
  const [draft, setDraft] = useState('')
  const [loading, setLoading] = useState(isMember)
  const [working, setWorking] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    if (!isMember) {
      setRows([])
      setLoading(false)
      return
    }

    setLoading(true)
    const { data, error: rpcError } = await supabase.rpc('get_my_national_team_chat_v1', { p_limit: 150 })
    if (rpcError) {
      setRows([])
      setError(rpcError.message)
    } else {
      setRows((data ?? []) as ChatRow[])
      setError(null)
    }
    setLoading(false)
  }, [isMember])

  useEffect(() => {
    void load()
  }, [load])

  async function sendMessage() {
    const value = draft.trim()
    if (!value || working || !isMember) return

    setWorking(true)
    setError(null)
    const { error: rpcError } = await supabase.rpc('send_national_team_chat_message_v1', {
      p_message: value,
    })

    if (rpcError) setError(rpcError.message)
    else {
      setDraft('')
      await load()
    }
    setWorking(false)
  }

  return (
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
          <p>Only active association members can read or post here. Use this room for call-ups, doubles pairings, opponent discussion and national-team planning.</p>

          {error && <div className="nt-alert nt-alert-error">{error}</div>}

          <div className="nt-chat-stream">
            {rows.length === 0 ? (
              <div className="nt-chat-empty">No messages yet.</div>
            ) : [...rows].reverse().map((row) => (
              <article key={row.message_id} className={row.is_mine ? 'mine' : ''}>
                <header><strong>{row.player_name}</strong><span>Game day {row.game_absolute_day}</span></header>
                <p>{row.message}</p>
              </article>
            ))}
          </div>

          <div className="nt-chat-compose">
            <textarea
              value={draft}
              maxLength={1000}
              placeholder="Message your national association…"
              onChange={(event) => setDraft(event.target.value)}
            />
            <button type="button" disabled={working || !draft.trim()} onClick={() => void sendMessage()}>
              <Send size={15} /> {working ? 'Sending…' : 'Send'}
            </button>
          </div>
        </>
      )}
    </section>
  )
}
