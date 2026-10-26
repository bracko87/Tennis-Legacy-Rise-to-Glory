import { test } from 'node:test'
import assert from 'node:assert/strict'
import os from 'node:os'
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..')
const script=path.join(root,'scripts/prepare-private-life-sandbox.mjs')

function inFixture(testFn) {
 const rootTmp=fs.mkdtempSync(path.join(os.tmpdir(),'tl-private-life-schema-'))
 try { testFn(rootTmp) }
 finally { fs.rmSync(rootTmp,{recursive:true,force:true}) }
}
function writeSample(p, extra='') {
 fs.writeFileSync(p,[
  'CREATE TABLE public.players (id uuid primary key);',
  'CREATE TABLE public.private_life_asset_catalog (code text primary key);',
  'CREATE TABLE public.player_travel_legs (id uuid primary key);',
  '-- Other required schema objects are present only in the REAL dump.',
  '/* '+('schema only '.repeat(70))+' */',
  extra,
 ].join('\n'))
}
test('sandbox copies only existing-schema baseline and three pending migrations',()=>{
 inFixture(temp=>{
  const src=path.join(temp,'snapshot.sql'),out=path.join(temp,'test-stack')
  writeSample(src)
  execFileSync(process.execPath,[script,src,out],{cwd:root,stdio:'pipe'})
  const dir=path.join(out,'supabase','migrations')
  const migrations=fs.readdirSync(dir).sort()
  assert.deepEqual(migrations,[
   '20260827000000_existing_schema_baseline.sql',
   '20260827001000_restore_local_auth_triggers.sql',
   '20261026090000_sandbox_reference_seed.sql',
   '20261026093000_private_life_career_foundation_v1.sql',
   '20261026094500_private_life_jet_travel_integration_v1.sql',
   '20261026095500_private_life_profile_residence_v1.sql',
  ])
  assert.equal(fs.readFileSync(path.join(dir,migrations[0]),'utf8'),fs.readFileSync(src,'utf8'))
  const seed=fs.readFileSync(path.join(dir,'20261026090000_sandbox_reference_seed.sql'),'utf8')
  assert.match(seed,/air_cessaro_citation_m3/)
  assert.match(seed,/air_gulfstar_g900_sovereign/)
  assert.match(seed,/sandbox_hobby_propeller/)
  assert.match(seed,/rs_belgrade/)
  assert.doesNotMatch(seed,/insert\\s+into\\s+(?:auth\\.|public\\.players\\b)/i)
  const config=fs.readFileSync(path.join(out,'supabase','config.toml'),'utf8')
  assert.match(config,/54331/)
  assert.match(config,/54332/)
  assert.match(config,/tennis_private_life_sandbox/)
  assert.doesNotMatch(config,/54321/)
  assert.match(fs.readFileSync(path.join(out,'README-START-HERE.txt'),'utf8'),/LOCAL_ANON_KEY/)
  assert.throws(()=>execFileSync(process.execPath,[script,src,out],{cwd:root,stdio:'pipe'}))
 })
})
test('schema-only PostgreSQL function bodies may legitimately contain INSERT statements',()=>{
 inFixture(temp=>{
  const src=path.join(temp,'schema.sql'),out=path.join(temp,'good-stack')
  writeSample(src,[
   'CREATE FUNCTION public.test_procedure() RETURNS void LANGUAGE plpgsql AS $',
   'BEGIN',
   '  INSERT INTO public.players (id) VALUES (gen_random_uuid());',
   'END $;',
  ].join('\n'))
  execFileSync(process.execPath,[script,src,out],{cwd:root,stdio:'pipe'})
  assert.ok(fs.existsSync(path.join(out,'supabase','migrations','20261026093000_private_life_career_foundation_v1.sql')))
 })
})
test('sandbox builder rejects data dumps or missing game schema',()=>{
 inFixture(temp=>{
  const src=path.join(temp,'schema.sql'),out=path.join(temp,'bad-stack')
  writeSample(src,'COPY public.players FROM stdin;')
  assert.throws(()=>execFileSync(process.execPath,[script,src,out],{cwd:root,stdio:'pipe'}))
  assert.equal(fs.existsSync(out),false)
  writeSample(src,'CREATE TABLE public.player_lifestyle_state (player_id uuid);')
  assert.throws(()=>execFileSync(process.execPath,[script,src,out],{cwd:root,stdio:'pipe'}))
  assert.equal(fs.existsSync(out),false)
 })
})


test('Windows setup uses only read-only remote schema export and local migration commands',()=>{
 const cmd=fs.readFileSync(path.join(root,'scripts/setup-private-life-sandbox.cmd'),'utf8')
 assert.match(cmd,/supabase link --project-ref cwfznmroiqcyhfkfcrow/)
 assert.match(cmd,/supabase db dump --linked --schema public -f/)
 assert.match(cmd,/prepare-private-life-sandbox\.mjs/)
 assert.match(cmd,/pushd "\.private-life-sandbox"/)
 assert.match(cmd,/call npx supabase start/)
 assert.match(cmd,/supabase status -o env/)
 assert.ok(cmd.includes('private_life_career_db_smoke.sql'))
 assert.match(cmd,/if not defined LOCAL_DB_CONTAINER/)
 assert.match(cmd,/docker ps --filter/)
 assert.match(cmd,/docker exec -i "%LOCAL_DB_CONTAINER%" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -f -/)
 assert.ok(cmd.includes('echo ERROR: Private Life LOCAL schema smoke test FAILED.'))
 assert.match(cmd,/TL_SUPABASE_URL=http:\/\/127\.0\.0\.1:54331/)
 assert.match(cmd,/TL_DEV_PORT=8001/)
 // Ignore comments, warning strings and the explicit no-dangerous-commands guard.
 const executable=cmd.split(/\r?\n/).map(x=>x.trim()).filter(x=>x &&
   !/^(rem\b|echo\b|::|if\b.*echo\b)/i.test(x)).join('\n')
 assert.doesNotMatch(executable,/^\s*(?:call\s+)?(?:npx\s+)?supabase\s+db\s+(?:push|reset)\b/im)
 assert.doesNotMatch(executable,/^\s*(?:call\s+)?(?:npx\s+)?supabase\s+db\s+dump\b[^\n]*--data-only/im)
 assert.doesNotMatch(executable,/^\s*(?:call\s+)?(?:npx\s+)?supabase\s+functions\s+deploy\b/im)
 assert.doesNotMatch(executable,/^\s*(?:call\s+)?(?:npx\s+)?supabase\s+start\b[^\n]*--linked/im)
})
