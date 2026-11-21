#!/usr/bin/env node
/**
 * HELIOS guest E2E sandbox generator. No database or network connections.
 *
 * Input: a SCHEMA-ONLY pg_dump snapshot of public,control_center_private.
 * Output: a NEW, disposable local Supabase stack (never existing projects).
 *
 * Never point the output at a production or existing folder. Never commit the
 * schema snapshot: even schema-only function bodies can contain configuration.
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const schemaPath = process.argv[2] ? path.resolve(process.argv[2]) : ''
const target = path.join(root, '.helios-guest-sandbox')
const migrations = path.join(target, 'supabase', 'migrations')
function fail(message) {
  console.error('HELIOS local sandbox: ' + message)
  process.exit(1)
}
if (!schemaPath || !fs.existsSync(schemaPath) || !fs.statSync(schemaPath).isFile())
  fail('Expected a SCHEMA-ONLY dump file as first argument.')
if (fs.existsSync(target))
  fail('Sandbox already exists. Refusing to overwrite it or any local test accounts.')
if (schemaPath.startsWith(target + path.sep))
  fail('Source schema dump must not be inside sandbox output.')
if (!schemaPath.startsWith(path.join(root, '.helios-guest-schema') + path.sep))
  fail('Keep the schema-only source inside .helios-guest-schema/ (gitignored).')

const dump = fs.readFileSync(schemaPath, 'utf8')
if (dump.length < 10000) fail('Schema-only dump is unexpectedly small.')
const required = [
  'public.players',
  'public.registration_control',
  'control_center_private.tennis_guest_trials_v1',
  'public.enroll_my_tennis_guest_trial_v1',
  'public.get_public_tennis_guest_test_status_v1',
  'public.get_my_tennis_guest_conversion_status_v1',
  'control_center_private.mark_tennis_guest_converted_v1',
  'control_center_private.prevent_retired_tennis_guest_conversion_v1',
  'public.tournament_matches',
  'public.tournament_doubles_teams',
]
for (const marker of required) {
  if (!dump.includes(marker)) fail('Missing schema dependency ' + marker + '. Dump both public and control_center_private; no user data.')
}
// Do not reject INSERT statements inside CREATE FUNCTION; only top-level
// pg_dump data sections should be excluded from a schema-only export.
if (/^-- Data for Name:|^COPY\s+[^\n]+FROM stdin;|^INSERT INTO [^\n]+VALUES\s*\(/im.test(dump))
  fail('Snapshot appears to contain data. Export SCHEMA ONLY (never user records).')
if (/CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?auth\.users\b/i.test(dump))
  fail('Do not dump Auth-managed user tables. Local Supabase creates its own auth.users.')
if (/CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?storage\.objects\b/i.test(dump))
  fail('Do not import remote Storage objects.')

const baseConfig = fs.readFileSync(path.join(root, 'supabase', 'config.toml'), 'utf8')
let config = baseConfig
  .replace(/project_id\s*=\s*"[^"]+"/, 'project_id = "tennis_helios_guest_sandbox"')
  .replace(/\b54321\b/g, '54341')
  .replace(/\b54322\b/g, '54342')
  .replace(/\b54320\b/g, '54340')
  .replace(/\b54323\b/g, '54343')
  .replace(/\b54324\b/g, '54344')
  .replace(/\b8000\b/g, '8002')
// Use actual local email confirmation and manual identity linking, matching the
// production linking flow. The local SMTP service captures all messages.
config = config.replace('[auth]\n', '[auth]\nenable_anonymous_sign_ins = true\nenable_manual_linking = true\n')
config = config.replace('additional_redirect_urls = ["http://localhost:8002", "http://127.0.0.1:8002"]',
  'additional_redirect_urls = ["http://localhost:8002", "http://127.0.0.1:8002", "http://127.0.0.1:8002/guest/register", "http://localhost:8002/guest/register"]')
if (!config.includes('[auth.email]')) {
  config += '\n[auth.email]\nenable_confirmations = true\n'
} else if (!/enable_confirmations\s*=\s*true/.test(config)) {
  fail('Local acceptance requires email confirmations enabled in config.')
}
if (!config.includes('enable_manual_linking = true'))
  fail('Could not enable LOCAL manual identity linking.')
if (!config.includes('enable_anonymous_sign_ins = true'))
  fail('Could not enable LOCAL anonymous Auth.')
const triggerSql = `-- HELIOS LOCAL SANDBOX ONLY; never apply to a remote project.
-- Auth system tables are provided by LOCAL Supabase. The public/private
-- functions referenced below must exist in the schema-only snapshot.
CREATE TRIGGER aa_block_public_registration_v1 BEFORE INSERT
  ON auth.users FOR EACH ROW
  EXECUTE FUNCTION public.enforce_public_registration_gate_v1();
CREATE TRIGGER on_auth_user_created AFTER INSERT
  ON auth.users FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
CREATE TRIGGER on_auth_user_created_commerce AFTER INSERT
  ON auth.users FOR EACH ROW
  EXECUTE FUNCTION public.handle_user_commerce();
CREATE TRIGGER on_auth_user_created_referral AFTER INSERT
  ON auth.users FOR EACH ROW
  EXECUTE FUNCTION public.handle_referral_signup_v1();
CREATE TRIGGER zz_on_auth_user_created_registration_invite AFTER INSERT
  ON auth.users FOR EACH ROW
  EXECUTE FUNCTION public.handle_registration_invite_bonus_v1();
CREATE TRIGGER prevent_retired_tennis_guest_conversion_v1
  BEFORE UPDATE OF is_anonymous ON auth.users FOR EACH ROW
  WHEN (OLD.is_anonymous IS TRUE AND NEW.is_anonymous IS FALSE)
  EXECUTE FUNCTION control_center_private.prevent_retired_tennis_guest_conversion_v1();
CREATE TRIGGER mark_tennis_guest_converted_v1
  AFTER UPDATE OF is_anonymous ON auth.users FOR EACH ROW
  WHEN (OLD.is_anonymous IS TRUE AND NEW.is_anonymous IS FALSE)
  EXECUTE FUNCTION control_center_private.mark_tennis_guest_converted_v1();
`
const localSeed = `-- LOCAL HELIOS ONLY: NO production account data.
-- Creates only the singleton switch; all real users stay exclusively remote.
INSERT INTO public.registration_control(
  singleton_id,public_signup_enabled,guest_test_enabled,google_oauth_enabled)
VALUES(true,true,true,false)
ON CONFLICT (singleton_id) DO UPDATE
SET public_signup_enabled=excluded.public_signup_enabled,
    guest_test_enabled=excluded.guest_test_enabled,
    google_oauth_enabled=excluded.google_oauth_enabled;
DO $check$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.registration_control
                WHERE singleton_id=true AND guest_test_enabled=true)
 THEN RAISE EXCEPTION 'Local guest trial gate not enabled'; END IF;
 IF (SELECT count(*) FROM auth.users) <> 0
 THEN RAISE EXCEPTION 'Local fixture must begin with no Auth users'; END IF;
END;
$check$;
`
try {
  fs.mkdirSync(migrations, { recursive: true })
  fs.writeFileSync(path.join(target, 'supabase','config.toml'), config)
  fs.writeFileSync(path.join(migrations, '20261120000000_helios_schema_snapshot.sql'), dump)
  fs.writeFileSync(path.join(migrations, '20261120000001_helios_local_auth_triggers.sql'), triggerSql)
  fs.writeFileSync(path.join(migrations, '20261120000002_helios_local_switch.sql'), localSeed)
  fs.writeFileSync(path.join(target, 'README-START-HERE.txt'), [
    'HELIOS ISOLATED LOCAL GUEST SANDBOX — NOT PRODUCTION',
    'Local API: http://127.0.0.1:54341; local UI: http://127.0.0.1:8002',
    'Before starting: Docker Desktop must be running.',
    'In this folder: npx supabase start',
    'If initial migration restore fails, STOP. Do not retry against production.',
    'Then in the repo root: npm run dev:helios-guest',
    'Never export real users, never use db push or db reset --linked.',
    'Anonymous provider and public guest switch are enabled ONLY in this sandbox.',
    'No real tournament seed/players exist until separately created as synthetic fixtures.',
    'Account erasure is NOT enabled by this environment.',
  ].join('\n') + '\n')
  console.log('Created new disposable Helios sandbox (no database was contacted).')
  console.log('From .helios-guest-sandbox: npx supabase start')
  console.log('From original repository: npm run dev:helios-guest')
} catch(e) {
  fs.rmSync(target,{recursive:true,force:true})
  throw e
}
