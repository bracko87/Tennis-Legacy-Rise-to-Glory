#!/usr/bin/env node
/**
 * Build an isolated LOCAL Supabase migration stack from a SCHEMA-ONLY
 * SQL snapshot of the existing game. Never connects to a database.
 * Run: node scripts/prepare-private-life-sandbox.mjs <schema.sql> [folder]
 *
 * Export using the read-only Supabase CLI db dump --linked option.
 * NEVER use db reset --linked or db push for this process.
 * Do not commit a snapshot: SQL function bodies may contain private settings.
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const input = process.argv[2] ? path.resolve(process.argv[2]) : ''
const output = process.argv[3]
  ? path.resolve(process.argv[3])
  : path.join(root, '.private-life-sandbox')

function stop(reason) {
  process.stderr.write('Private Life sandbox: '+reason+'\n')
  process.exit(1)
}
if (!input || !fs.existsSync(input) || !fs.statSync(input).isFile()) {
  stop('Pass an existing schema-only SQL dump as the first argument.')
}
const schema = fs.readFileSync(input, 'utf8')
if (schema.length < 500 || !schema.includes('public.players') ||
    !schema.includes('public.private_life_asset_catalog') ||
    !schema.includes('public.player_travel_legs')) {
  stop('Not a complete Tennis Legacy public-schema baseline. No files changed.')
}
// A schema dump contains functions with INSERT statements in their bodies.
// Reject pg_dump DATA sections, not legitimate stored-function source code.
if (/^-- Data for Name:|^COPY\s+\S+[^\n]*\sFROM stdin;|^INSERT INTO public\.[^\s]+ \([^\n]+\) VALUES \(/im.test(schema)) {
  stop('pg_dump DATA section detected. Export SCHEMA ONLY, never player records.')
}
if (/(?:CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public\.)?player_lifestyle_state\b|CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public\.)?player_tournament_travel_selection\b)/i.test(schema)) {
  stop('Snapshot already includes the new Private Life schema. Do not reapply.')
}
if (path.resolve(input).startsWith(path.resolve(output) + path.sep)) {
  stop('Snapshot must be OUTSIDE the generated sandbox folder.')
}
if (path.resolve(output) === root || path.resolve(output) === path.parse(output).root) {
  stop('Refusing to overwrite the repository or filesystem root.')
}
const migrationNames = [
  '20261026093000_private_life_career_foundation_v1.sql',
  '20261026094500_private_life_jet_travel_integration_v1.sql',
  '20261026095500_private_life_profile_residence_v1.sql',
]
for(const n of migrationNames) {
  if(!fs.existsSync(path.join(root,'supabase','migrations',n))) stop('Missing migration '+n)
}
const sub=path.join(output,'supabase')
const migrations=path.join(sub,'migrations')
if(fs.existsSync(output)) {
  stop('Output already exists: '+output+'. Choose a new empty folder.')
}
fs.mkdirSync(migrations,{recursive:true})
try {
  const config=fs.readFileSync(path.join(root,'supabase','config.toml'),'utf8')
    .replace(/project_id\s*=\s*"[^"]+"/,'project_id = "tennis_private_life_sandbox"')
    .replace(/\b54321\b/g,'54331')
    .replace(/\b54322\b/g,'54332')
    .replace(/\b54320\b/g,'54330')
    .replace(/\b54323\b/g,'54333')
    .replace(/\b54324\b/g,'54334')
    .replace(/\b8000\b/g,'8001')
  fs.writeFileSync(path.join(sub,'config.toml'),config)
  fs.writeFileSync(path.join(migrations,'20260827000000_existing_schema_baseline.sql'),schema)
  // Supabase schema-only dump omits managed auth tables and their triggers.
  // Five custom trigger definitions were inspected READ-ONLY on Oct 26 2026.
  const triggers = [
    ['aa_block_public_registration_v1','BEFORE','enforce_public_registration_gate_v1'],
    ['on_auth_user_created','AFTER','handle_new_user'],
    ['on_auth_user_created_commerce','AFTER','handle_user_commerce'],
    ['on_auth_user_created_referral','AFTER','handle_referral_signup_v1'],
    ['zz_on_auth_user_created_registration_invite','AFTER','handle_registration_invite_bonus_v1'],
  ]
  fs.writeFileSync(path.join(migrations,'20260827001000_restore_local_auth_triggers.sql'),
    '-- LOCAL SANDBOX ONLY: never run this against live Supabase.\n'+
    triggers.map(([name,timing,fn])=>
      'DROP TRIGGER IF EXISTS '+name+' ON auth.users;\n'+
      'CREATE TRIGGER '+name+' '+timing+' INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.'+fn+'();\n'
    ).join('\n'))
  for(const n of migrationNames) {
    fs.copyFileSync(path.join(root,'supabase','migrations',n),path.join(migrations,n))
  }
  const instructions = [
    'ISOLATED TENNIS LEGACY PRIVATE LIFE SANDBOX',
    'No production records included. Never commit this folder.',
    '',
    'From this sandbox folder (Docker Desktop and Supabase CLI required):',
    '  npx supabase start',
    '  npx supabase status -o env',
    '',
    'In a SECOND Windows CMD window, from the original game repository:',
    '  set TL_SUPABASE_URL=http://127.0.0.1:54331',
    '  set TL_SUPABASE_PUBLISHABLE_KEY=<LOCAL_ANON_KEY_FROM_STATUS>',
    '  set TL_DEV_PORT=8001',
    '  npm run dev',
    '',
    'Only proceed if Supabase start and all three Private Life migrations pass.',
    'The local schema has NO REAL ACCOUNTS. Create a local test account',
    'with valid game registration eligibility; local tournaments may need',
    'synthetic seeds. Do not use production or --linked migration commands.',
    'Never run supabase db push, db reset --linked or deploy Netlify.',
    'If baseline restore fails, STOP and report the error.',
  ]
  fs.writeFileSync(path.join(output,'README-START-HERE.txt'),instructions.join('\n')+'\n')
  process.stdout.write('Created schema-only local sandbox: '+output+'\n')
  process.stdout.write('Next: cd "'+output+'" && npx supabase start\n')
} catch(e) {
  fs.rmSync(output,{recursive:true,force:true})
  throw e
}
