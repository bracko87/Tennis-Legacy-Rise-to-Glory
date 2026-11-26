# Ace Test Center — local pilot setup (2026-11-26)
This is a standalone localhost prototype, not an integrated Tennis Legacy route. It never connects to production and does not modify official tournaments or player careers. The designated administrator is created as a separate local account using the specified email and a random local password. Initial mode allows only this admin to access matches; the optional synthetic peer is disabled unless explicitly enabled.

## Windows CMD
Prerequisites: Node 22, Git, Docker Desktop running, and permission to install/run Supabase CLI locally. From a directory where a separate checkout can be created:
```cmd
git clone --branch project-ace --single-branch https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory.git Tennis-Ace
cd Tennis-Ace
set "ACE_ADMIN_EMAIL=your-admin-email"
node experiments/project-ace/start-local.cjs
```
The launcher provisions a dedicated local Supabase project on ports 54361–54364 under your home directory, prints the local password and runs the loopback-only Test Center at http://127.0.0.1:8765. Do not use your production password. The generated credentials and state stay outside Git. It never runs supabase link, db push or a remote migration. If provisioning fails, do not delete or reset other Supabase stacks; report the error.
Open the local URL, sign in with the printed local credentials, schedule an AI match, and send tactics. Commands activate at the next game boundary. For an optional two-manager test, stop the server, set ACE_MULTIPLAYER_TEST=1, restart it and sign into the synthetic peer in another browser. The peer cannot schedule matches and can only see its assigned fixture. To stop the server use Ctrl+C; the Docker stack can separately be stopped by running npx supabase stop from the dedicated home-directory sandbox only.
For subsequent code updates in the separate checkout, use git pull --ff-only origin project-ace. No production merge.

## Verification status
Committed interface, local login proxy, fixture setup script and native HTTP tests. JavaScript syntax checked in isolated runtime. The prior engine and match-service test groups were executed in an isolated JS runtime; local auth/native HTTP and real Docker provisioning are not yet verified. CI workflow project-ace-local.yml added for native tests; actual run result not yet available. No match has been scheduled on the user's machine. Browser acceptance and real two-session authentication remain required. Current UI conditions update per game, not per point. The server supports one fixture; completed fixtures are replaced by new ones. No integration with the official game's router, schedule or financial systems yet.
