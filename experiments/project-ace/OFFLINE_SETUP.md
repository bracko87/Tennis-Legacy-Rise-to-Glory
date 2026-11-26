# Docker-free first pilot
Windows CMD from the project-ace checkout:
```cmd
git pull --ff-only origin project-ace
set "ACE_ADMIN_EMAIL=your-admin-email"
node experiments/project-ace/start-offline.cjs
```
Node 18+ only; no npm install, Docker, Supabase, or production login. Open http://127.0.0.1:8765 with the email and temporary password shown in CMD. Password rotates on each server launch; match state is persisted in a separate home-directory sandbox. Ctrl+C stops the local server. The existing local Supabase launcher is unchanged and remains available for later real authentication testing. Optional synthetic peer: set ACE_MULTIPLAYER_TEST=1 before launch. By default only the designated local test identity has access. This is not verification of the real production admin session: it is a local persona with server-side password/session/allowlist protection. No production data is read or written. Do not publish or expose the local server.
