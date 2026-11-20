import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const schemaDir=path.join(root,'.helios-guest-schema')
const sandbox=path.join(root,'.helios-guest-sandbox')
const generator=path.join(root,'scripts','prepare-helios-guest-sandbox.mjs')
assert.equal(fs.existsSync(sandbox),false,'Do not run this test on a developer machine with an existing sandbox.')
assert.equal(fs.existsSync(schemaDir),false,'Do not run this test against an existing saved schema.')
const required=[
 'public.players','public.registration_control',
 'control_center_private.tennis_guest_trials_v1',
 'public.enroll_my_tennis_guest_trial_v1',
 'public.get_public_tennis_guest_test_status_v1',
 'public.get_my_tennis_guest_conversion_status_v1',
 'control_center_private.mark_tennis_guest_converted_v1',
 'control_center_private.prevent_retired_tennis_guest_conversion_v1',
 'public.tournament_matches','public.tournament_doubles_teams',
]
function run(file){return spawnSync(process.execPath,[generator,file],{cwd:root,encoding:'utf8',timeout:20000})}
try {
 fs.mkdirSync(schemaDir)
 const invalid=path.join(schemaDir,'has-data.sql')
 fs.writeFileSync(invalid,required.join('\n')+'\n'+('x'.repeat(11000))+'\n-- Data for Name: players; Type: TABLE DATA\n')
 let a=run(invalid)
 assert.notEqual(a.status,0,'A data-bearing schema dump must be rejected.')
 assert.equal(fs.existsSync(sandbox),false,'Invalid input must not write a sandbox.')

 const valid=path.join(schemaDir,'schema.sql')
 fs.writeFileSync(valid,'-- Synthetic SCHEMA-ONLY metadata markers for generator unit tests\n'+required.join('\n')+'\n'+('x'.repeat(11000)))
 a=run(valid)
 assert.equal(a.status,0,'Generator should accept minimal schema markers: '+a.stderr)
 const config=fs.readFileSync(path.join(sandbox,'supabase','config.toml'),'utf8')
 assert.match(config,/project_id = "tennis_helios_guest_sandbox"/)
 assert.match(config,/enable_anonymous_sign_ins = true/)
 assert.match(config,/port = 54341/)
 assert.match(config,/port = 54342/)
 assert.match(config,/8002/)
 assert.doesNotMatch(config,/cwfznmroiqcyhfkfcrow/)
 const triggers=fs.readFileSync(path.join(sandbox,'supabase','migrations','20261120000001_helios_local_auth_triggers.sql'),'utf8')
 assert.match(triggers,/mark_tennis_guest_converted_v1/)
 assert.match(triggers,/prevent_retired_tennis_guest_conversion_v1/)
 const seed=fs.readFileSync(path.join(sandbox,'supabase','migrations','20261120000002_helios_local_switch.sql'),'utf8')
 assert.match(seed,/guest_test_enabled/)
 assert.match(seed,/VALUES\(true,true,true,false\)/)
 const next=run(valid)
 assert.notEqual(next.status,0,'Existing test sandbox must not be overwritten.')
 assert.ok(fs.existsSync(path.join(sandbox,'supabase','migrations','20261120000000_helios_schema_snapshot.sql')))

 console.log('PASS: no player data permitted; local-only anonymous config; safe guest gate; no overwrite.')
} finally {
 fs.rmSync(sandbox,{recursive:true,force:true})
 fs.rmSync(schemaDir,{recursive:true,force:true})
}
