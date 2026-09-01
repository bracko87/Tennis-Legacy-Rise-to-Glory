import { ArrowLeft, Mail, Send, UserRound } from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router'

import GameLayout from '../../components/layout/GameLayout'
import usePlayerAvatarUrl from '../../hooks/usePlayerAvatarUrl'
import { supabase } from '../../lib/supabase'
import '../../styles/player-inbox.css'

interface InboxConversation {
  conversation_id: string
  other_player_id: string
  other_first_name: string
  other_last_name: string
  other_world: 'ATP' | 'WTA'
  other_country_code: string
  other_image_path: string | null
  last_message: string | null
  last_message_at: string | null
  unread_count: number
}

interface ConversationMessage {
  message_id: string
  sender_player_id: string
  body: string
  created_at: string
  is_mine: boolean
}

function ConversationAvatar({ path, name }: { path: string | null; name: string }) {
  const avatarUrl = usePlayerAvatarUrl(path)
  return <span className="tlg-inbox-avatar">{avatarUrl ? <img src={avatarUrl} alt={`${name} avatar`} /> : <UserRound size={22} />}</span>
}

export default function InboxPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const selectedId = searchParams.get('conversation')
  const [conversations, setConversations] = useState<InboxConversation[]>([])
  const [messages, setMessages] = useState<ConversationMessage[]>([])
  const [loadingInbox, setLoadingInbox] = useState(true)
  const [loadingMessages, setLoadingMessages] = useState(false)
  const [draft, setDraft] = useState('')
  const [sending, setSending] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const activeConversation = useMemo(
    () => conversations.find((conversation) => conversation.conversation_id === selectedId) ?? null,
    [conversations, selectedId],
  )

  const loadInbox = useCallback(async () => {
    const { data, error: inboxError } = await supabase.rpc('get_player_inbox_v1')
    if (inboxError) {
      setError(inboxError.message)
      setConversations([])
    } else {
      setConversations((data ?? []) as InboxConversation[])
    }
    setLoadingInbox(false)
  }, [])

  const loadMessages = useCallback(async (conversationId: string, quiet = false) => {
    if (!quiet) setLoadingMessages(true)
    const { data, error: messageError } = await supabase.rpc('get_player_conversation_messages_v1', {
      p_conversation_id: conversationId,
    })
    if (messageError) {
      setError(messageError.message)
      setMessages([])
    } else {
      setMessages((data ?? []) as ConversationMessage[])
      setError(null)
    }
    if (!quiet) setLoadingMessages(false)
  }, [])

  useEffect(() => { void loadInbox() }, [loadInbox])

  useEffect(() => {
    if (!selectedId) {
      setMessages([])
      return
    }
    void loadMessages(selectedId)
    void loadInbox()
    const timer = window.setInterval(() => {
      void loadMessages(selectedId, true)
      void loadInbox()
    }, 5000)
    return () => window.clearInterval(timer)
  }, [selectedId, loadInbox, loadMessages])

  async function sendMessage(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!selectedId || !draft.trim() || sending) return
    setSending(true)
    setError(null)
    const { error: sendError } = await supabase.rpc('send_player_message_v1', {
      p_conversation_id: selectedId,
      p_body: draft.trim(),
    })
    if (sendError) {
      setError(sendError.message)
    } else {
      setDraft('')
      await Promise.all([loadMessages(selectedId), loadInbox()])
    }
    setSending(false)
  }

  function selectConversation(id: string) {
    setSearchParams({ conversation: id })
  }

  return (
    <GameLayout title="Manager inbox" subtitle="Private player-to-player communication">
      <div className="tlg-inbox-page">
        <header className="tlg-inbox-heading">
          <div>
            <span>Player communication</span>
            <h2>Manager inbox</h2>
            <p>Private conversations started from another player's profile appear here.</p>
          </div>
          <Mail size={22} />
        </header>

        <div className="tlg-inbox-layout">
          <aside className={`tlg-inbox-sidebar ${selectedId ? 'tlg-inbox-sidebar-mobile-hidden' : ''}`}>
            <div className="tlg-inbox-sidebar-head"><strong>Conversations</strong><span>{conversations.length}</span></div>
            {loadingInbox ? (
              <div className="tlg-inbox-empty">Loading conversations…</div>
            ) : conversations.length === 0 ? (
              <div className="tlg-inbox-empty"><Mail size={24} /><strong>No conversations yet</strong><p>Open a player from the ATP/WTA ranking and use Send message to begin.</p><Link to="/game/rankings">Open Rankings</Link></div>
            ) : (
              <div className="tlg-inbox-conversation-list">
                {conversations.map((conversation) => {
                  const name = `${conversation.other_first_name} ${conversation.other_last_name}`
                  return (
                    <button key={conversation.conversation_id} type="button" className={`tlg-inbox-conversation ${selectedId === conversation.conversation_id ? 'tlg-inbox-conversation-active' : ''}`} onClick={() => selectConversation(conversation.conversation_id)}>
                      <ConversationAvatar path={conversation.other_image_path} name={name} />
                      <span className="tlg-inbox-conversation-copy"><strong>{name}</strong><small>{conversation.other_world} · {conversation.other_country_code}</small><p>{conversation.last_message || 'Conversation started. Send the first message.'}</p></span>
                      {Number(conversation.unread_count) > 0 && <span className="tlg-inbox-unread">{conversation.unread_count}</span>}
                    </button>
                  )
                })}
              </div>
            )}
          </aside>

          <section className={`tlg-inbox-thread ${!selectedId ? 'tlg-inbox-thread-mobile-hidden' : ''}`}>
            {!selectedId ? (
              <div className="tlg-inbox-thread-empty"><Mail size={30} /><strong>Select a conversation</strong><p>Your private message history will appear here.</p></div>
            ) : (
              <>
                <header className="tlg-inbox-thread-head">
                  <button type="button" className="tlg-inbox-mobile-back" onClick={() => setSearchParams({})}><ArrowLeft size={16} /></button>
                  {activeConversation && <ConversationAvatar path={activeConversation.other_image_path} name={`${activeConversation.other_first_name} ${activeConversation.other_last_name}`} />}
                  <div>
                    <strong>{activeConversation ? `${activeConversation.other_first_name} ${activeConversation.other_last_name}` : 'Conversation'}</strong>
                    {activeConversation && <span>{activeConversation.other_world} singles · {activeConversation.other_country_code}</span>}
                  </div>
                  {activeConversation && <Link to={`/game/players/${activeConversation.other_player_id}`}>View profile</Link>}
                </header>

                <div className="tlg-inbox-messages">
                  {loadingMessages ? <div className="tlg-inbox-thread-empty">Loading messages…</div> : messages.length === 0 ? (
                    <div className="tlg-inbox-thread-empty"><strong>Start the conversation</strong><p>Write a message below. Only you and this player can read this conversation.</p></div>
                  ) : messages.map((message) => (
                    <div key={message.message_id} className={`tlg-inbox-message ${message.is_mine ? 'tlg-inbox-message-mine' : ''}`}>
                      <p>{message.body}</p>
                      <span>{new Date(message.created_at).toLocaleString()}</span>
                    </div>
                  ))}
                </div>

                <form className="tlg-inbox-compose" onSubmit={sendMessage}>
                  <textarea value={draft} onChange={(event) => setDraft(event.target.value)} placeholder="Write a private message…" maxLength={2000} rows={3} />
                  <div><span>{draft.length}/2000</span><button type="submit" disabled={!draft.trim() || sending}><Send size={16} /> {sending ? 'Sending…' : 'Send'}</button></div>
                </form>
              </>
            )}
          </section>
        </div>
        {error && <p className="tlg-inbox-error">{error}</p>}
      </div>
    </GameLayout>
  )
}
