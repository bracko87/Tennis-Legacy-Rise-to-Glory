# Ace multiplayer and local API review — 2026-11-26

## Verified
- Seven match-service test groups passed against fetched committed sources in an isolated JavaScript runtime with assertions: default deny; scheduled start and elapsed-only projection; simultaneous opposing tactics; stale window rejection; offline completion and deterministic reconnect; hybrid/AI decisions; clock rollback and immutable reads.
- Local auth adapter tests passed in Node 22 with mocked HTTP auth responses and a copied source/test pair. URL restriction, publishable-only config, expired/anonymous/ordinary user rejection, exact identity allowlist, admin RPC verification, revocation and optional synthetic peer tested.
- Original engine seven groups remain the previous verified baseline; engine file unchanged.
- local-server.cjs syntax parsed; actual HTTP server, real Supabase authentication, file persistence and UI not yet run end-to-end.

## Local operation (development only)
Run from repo root:
```
node experiments/project-ace/engine.test.cjs
node experiments/project-ace/match-service.test.cjs
node experiments/project-ace/local-auth.test.cjs
```
The local API requires ACE_LOCAL_ENABLED=1, ACE_SUPABASE_URL (loopback HTTP only), ACE_SUPABASE_ANON_KEY (local anon/publishable key), ACE_ADMIN_USER_ID (local test user ID, with app_admins role), ACE_STATE_DIR (absolute private directory outside repository). ACE_PORT defaults to 8765. Optional synthetic peer only with ACE_MULTIPLAYER_TEST=1 and ACE_SYNTHETIC_USER_ID. Use separate local test credentials; never reuse production password or production URL. No production UUID/email/secret committed. Start with `node experiments/project-ace/local-server.cjs`.
The server listens on 127.0.0.1 and checks Host/Origin. It keeps one fixture in a private file, uses atomic replacement and a single writer lock; no production tables or external scheduler. After an unclean shutdown, verify no process is running before removing the stale writer.lock. A new fixture replaces a completed fixture (historical archive not implemented).
API: authenticated GET/POST /api/fixture, POST /api/heartbeat, POST /api/coach (targetGame/tactics). POST fixture accepts delaySeconds (5–86400), mode and optional humanOpponent/peerMode. Do not expose the private state file or raw engine events.
The simulated clock uses 2 seconds per point and 5 seconds between games as provisional test pacing; conditions update at game boundaries. An offline hybrid player uses AI after 30 seconds since last presence. Real tournament pacing, scout-based information visibility, AI balance and event semantics require further validation.

## Mandatory next gates
1. Set up local Supabase admin fixture and optional synthetic peer, verify actual token/RPC integration. No production auth passwords or live data.
2. Run actual HTTP server integration tests, persistence/restart and parallel requests; check no production connectivity.
3. Build protected local Test Center and browser login/scheduling/coaching/replay. Only then schedule first admin fixture. Test two browser sessions separately.
4. Verify today's production database recovery point before production changes. No production merge or migration.
