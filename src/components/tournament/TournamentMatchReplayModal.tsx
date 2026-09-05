import { useEffect, useMemo, useState } from 'react'

import CountryFlag from '../common/CountryFlag'
import usePlayerAvatarUrl from '../../hooks/usePlayerAvatarUrl'
import { supabase } from '../../lib/supabase'
import '../../styles/tournament-match-replay.css'

type ReplayStatus = 'unavailable' | 'prepared' | 'live' | 'completed' | 'void'

interface ReplayEvent {
  offset_seconds: number
  kind?: string
  description?: string
  p1_sets?: number
  p2_sets?: number
  p1_games?: number
  p2_games?: number
  p1_points?: string | number
  p2_points?: string | number
  set_number?: number
  game_number?: number
}

interface ReplayResponse {
  status: ReplayStatus
  match_status?: string
  controls_locked?: boolean
  historical_replay?: boolean
  speed?: number | null
  server_now?: string
  live_started_at?: string | null
  live_ends_at?: string | null
  replay_duration_seconds?: number
  elapsed_seconds?: number
  remaining_seconds?: number
  player1_id?: string
  player1_name?: string
  player2_id?: string
  player2_name?: string
  events?: ReplayEvent[]
  last_event?: ReplayEvent | null
  final_score?: { score?: string; sets?: unknown } | null
  winner_id?: string | null
  engine_version?: string | null
}

interface ReplayPlayerDetail {
  id: string
  first_name: string
  last_name: string
  country_code: string | null
  image_path: string | null
  ranking_position: number | null
  seed: number | null
}

interface ReplayMatchDetail {
  player1: ReplayPlayerDetail | null
  player2: ReplayPlayerDetail | null
}

function clockLabel(totalSeconds: number) {
  const value = Math.max(0, Math.floor(totalSeconds))
  const minutes = Math.floor(value / 60)
  const seconds = value % 60
  return `${minutes}:${String(seconds).padStart(2, '0')}`
}

function scoreValue(value: string | number | undefined) {
  return value == null ? '0' : String(value)
}

function lastAt(events: ReplayEvent[], playhead: number) {
  let latest: ReplayEvent | null = null
  for (const event of events) {
    if ((event.offset_seconds ?? 0) > playhead) break
    latest = event
  }
  return latest
}

function nextEventOffset(events: ReplayEvent[], playhead: number, kinds: string[]) {
  const next = events.find((event) => (event.offset_seconds ?? 0) > playhead && kinds.includes(event.kind ?? ''))
  return next?.offset_seconds ?? null
}

function initials(name: string) {
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase() ?? '').join('') || 'P'
}

function ReplayPlayerCard({ player, fallbackName, winner }: { player: ReplayPlayerDetail | null; fallbackName: string; winner: boolean }) {
  const avatarUrl = usePlayerAvatarUrl(player?.image_path)
  const name = player ? `${player.first_name} ${player.last_name}` : fallbackName

  return (
    <article className={`tlg-replay-player-card${winner ? ' winner' : ''}`}>
      {winner && <span className="tlg-replay-winner-badge">Winner</span>}
      <div className="tlg-replay-player-avatar">
        {avatarUrl ? <img src={avatarUrl} alt={`${name} profile`} /> : <span>{initials(name)}</span>}
      </div>
      <h3>{name}</h3>
      <div className="tlg-replay-player-country">
        <CountryFlag countryCode={player?.country_code ?? null} countryName={player?.country_code ?? undefined} width={24} height={16} />
        <span>{player?.country_code ?? '—'}</span>
      </div>
      <div className="tlg-replay-player-meta">
        <div><span>World rank</span><strong>{player?.ranking_position ? `#${player.ranking_position}` : '—'}</strong></div>
        {player?.seed ? <div><span>Seed</span><strong>#{player.seed}</strong></div> : null}
      </div>
    </article>
  )
}

export default function TournamentMatchReplayModal({ matchId, onClose }: { matchId: string; onClose: () => void }) {
  const [data, setData] = useState<ReplayResponse | null>(null)
  const [matchDetail, setMatchDetail] = useState<ReplayMatchDetail | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [watchingReplay, setWatchingReplay] = useState(false)
  const [playhead, setPlayhead] = useState(0)
  const [playing, setPlaying] = useState(false)
  const [speed, setSpeed] = useState<1 | 2 | 4>(1)

  useEffect(() => {
    let cancelled = false
    const loadDetail = async () => {
      const { data: detailData, error: detailError } = await supabase.rpc('get_tournament_match_detail_v1', { p_match_id: matchId })
      if (cancelled || detailError || !detailData) return
      setMatchDetail(detailData as ReplayMatchDetail)
    }
    void loadDetail()
    return () => { cancelled = true }
  }, [matchId])

  useEffect(() => {
    let cancelled = false
    let timer = 0

    const load = async () => {
      const { data: replayData, error: replayError } = await supabase.rpc('get_tournament_match_replay_v1', { p_match_id: matchId })
      if (cancelled) return
      setLoading(false)
      if (replayError) {
        setError(replayError.message)
        return
      }
      setError(null)
      const next = (replayData ?? { status: 'unavailable' }) as ReplayResponse
      setData(next)
      if (next.status === 'live' || next.status === 'prepared') {
        timer = window.setTimeout(() => void load(), 1500)
      }
    }

    void load()
    return () => {
      cancelled = true
      window.clearTimeout(timer)
    }
  }, [matchId])

  const duration = data?.replay_duration_seconds ?? 0
  const fullEvents = useMemo(() => (data?.events ?? []).slice().sort((a, b) => a.offset_seconds - b.offset_seconds), [data?.events])

  useEffect(() => {
    if (!watchingReplay || !playing || data?.status !== 'completed') return
    const started = performance.now()
    const base = playhead
    const timer = window.setInterval(() => {
      const elapsed = ((performance.now() - started) / 1000) * speed
      const next = Math.min(duration, base + elapsed)
      setPlayhead(next)
      if (next >= duration) setPlaying(false)
    }, 150)
    return () => window.clearInterval(timer)
  }, [data?.status, duration, playhead, playing, speed, watchingReplay])

  const isLive = data?.status === 'live'
  const isCompleted = data?.status === 'completed'
  const effectivePlayhead = isLive ? (data?.elapsed_seconds ?? 0) : playhead
  const visibleEvents = isLive ? fullEvents : fullEvents.filter((event) => event.offset_seconds <= effectivePlayhead)
  const latest = isLive ? (data?.last_event ?? visibleEvents[visibleEvents.length - 1] ?? null) : lastAt(fullEvents, effectivePlayhead)
  const feed = visibleEvents.slice(-8).reverse()
  const winnerName = data?.winner_id === data?.player1_id ? data?.player1_name : data?.winner_id === data?.player2_id ? data?.player2_name : null

  function startHistoricalReplay() {
    setWatchingReplay(true)
    setPlayhead(0)
    setSpeed(1)
    setPlaying(true)
  }

  function seekTo(value: number) {
    setPlayhead(Math.max(0, Math.min(duration, value)))
  }

  const nextGame = nextEventOffset(fullEvents, playhead, ['game_end'])
  const nextSet = nextEventOffset(fullEvents, playhead, ['set_end'])

  return (
    <div className="tlg-replay-backdrop" role="presentation" onMouseDown={(event) => { if (event.currentTarget === event.target) onClose() }}>
      <section className="tlg-replay-modal" role="dialog" aria-modal="true" aria-label="Match replay">
        <button type="button" className="tlg-replay-close" onClick={onClose} aria-label="Close replay">×</button>

        {loading ? <div className="tlg-replay-state">Loading match replay…</div> : error ? <div className="tlg-replay-state error">{error}</div> : !data || data.status === 'unavailable' ? (
          <div className="tlg-replay-state"><strong>Replay not available yet</strong><span>This match does not yet have a generated point-by-point simulation.</span></div>
        ) : data.status === 'prepared' ? (
          <div className="tlg-replay-state"><strong>Match simulation prepared</strong><span>The result is sealed. Live playback will begin automatically when the scheduled match time is reached.</span></div>
        ) : (
          <>
            <header className="tlg-replay-head">
              <div>
                <span>{isLive ? 'Live match' : 'Match replay'}</span>
                <p>{isLive ? 'First occurrence · synchronized with the official live timeline' : 'Completed match · historical replay controls unlocked'}</p>
              </div>
              <strong className={isLive ? 'live' : 'final'}>{isLive ? 'LIVE · 1× LOCKED' : 'FINAL'}</strong>
            </header>

            {isCompleted && !watchingReplay ? (
              <div className="tlg-replay-finished tlg-replay-result-layout">
                <ReplayPlayerCard player={matchDetail?.player1 ?? null} fallbackName={data.player1_name ?? 'Player 1'} winner={data.winner_id === data.player1_id} />
                <div className="tlg-replay-result-center">
                  <span>Official result</span>
                  <h3>{data.final_score?.score ?? 'Match completed'}</h3>
                  {winnerName && <p><strong>{winnerName}</strong> won the match.</p>}
                  <button type="button" className="tlg-replay-watch-button" onClick={startHistoricalReplay}><span aria-hidden="true">▶</span> Watch Replay</button>
                  <small>Historical replay controls unlocked</small>
                </div>
                <ReplayPlayerCard player={matchDetail?.player2 ?? null} fallbackName={data.player2_name ?? 'Player 2'} winner={data.winner_id === data.player2_id} />
              </div>
            ) : (
              <>
                <div className="tlg-replay-scoreboard">
                  <div className="player"><span>{data.player1_name ?? 'Player 1'}</span><strong>{latest?.p1_sets ?? 0}</strong><b>{latest?.p1_games ?? 0}</b><em>{scoreValue(latest?.p1_points)}</em></div>
                  <div className="labels"><span>SETS</span><span>GAMES</span><span>POINTS</span></div>
                  <div className="player"><span>{data.player2_name ?? 'Player 2'}</span><strong>{latest?.p2_sets ?? 0}</strong><b>{latest?.p2_games ?? 0}</b><em>{scoreValue(latest?.p2_points)}</em></div>
                </div>

                <div className="tlg-replay-progress-wrap">
                  <div className="tlg-replay-progress"><span style={{ width: `${duration ? Math.min(100, (effectivePlayhead / duration) * 100) : 0}%` }} /></div>
                  <div><strong>{clockLabel(effectivePlayhead)}</strong><span>{clockLabel(duration)}</span></div>
                </div>

                {isLive ? (
                  <div className="tlg-replay-lock-note"><strong>Live playback controls are locked.</strong><span>You cannot pause, rewind, accelerate, skip games/sets, or reveal the result during the first occurrence. Leaving this screen does not stop the match.</span></div>
                ) : (
                  <div className="tlg-replay-controls">
                    <button type="button" onClick={() => setPlaying((value) => !value)}>{playing ? 'Pause' : 'Play'}</button>
                    {[1, 2, 4].map((value) => <button key={value} type="button" className={speed === value ? 'active' : ''} onClick={() => setSpeed(value as 1 | 2 | 4)}>{value}×</button>)}
                    <button type="button" onClick={() => { seekTo(0); setPlaying(true) }}>Restart</button>
                    <button type="button" disabled={nextGame == null} onClick={() => nextGame != null && seekTo(nextGame)}>Next Game</button>
                    <button type="button" disabled={nextSet == null} onClick={() => nextSet != null && seekTo(nextSet)}>Next Set</button>
                    <button type="button" onClick={() => { seekTo(duration); setPlaying(false) }}>Final Result</button>
                  </div>
                )}

                <div className="tlg-replay-feed">
                  <header><span>Point-by-point</span><strong>{latest?.description ?? (latest?.kind === 'match_start' ? 'Match started' : 'Live play')}</strong></header>
                  {feed.length === 0 ? <div className="empty">Waiting for the first point…</div> : feed.map((event, index) => (
                    <div key={`${event.offset_seconds}-${index}`} className={event.kind ?? 'event'}>
                      <span>{clockLabel(event.offset_seconds)}</span>
                      <strong>{event.description ?? (event.kind === 'game_end' ? 'Game completed' : event.kind === 'set_end' ? 'Set completed' : event.kind === 'match_end' ? 'Match completed' : 'Point')}</strong>
                      <small>{event.p1_games ?? 0}–{event.p2_games ?? 0} · {scoreValue(event.p1_points)}–{scoreValue(event.p2_points)}</small>
                    </div>
                  ))}
                </div>
              </>
            )}
          </>
        )}
      </section>
    </div>
  )
}
