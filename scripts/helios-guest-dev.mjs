#!/usr/bin/env node
/**
 * Helios guest tester: only launches if the isolated local Supabase API is up.
 * Refuses linked/remote/production URLs; never logs privileged CLI credentials.
 */
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..')
const sandbox=path.join(root,'.helios-guest-sandbox')
const config=path.join(sandbox,'supabase','config.toml')
function fail(reason){console.error('HELIOS local Guest Mode: '+reason);process.exit(1)}
if(!fs.existsSync(config) || !fs.readFileSync(config,'utf8').includes('project_id = "tennis_helios_guest_sandbox"'))
  fail('Isolated Helios stack missing. See docs/HELIOS_LOCAL_GUEST_TEST_SETUP.md')
if(!fs.readFileSync(config,'utf8').includes('enable_anonymous_sign_ins = true'))
  fail('Local anonymous Auth must be explicitly enabled in sandbox config.')
let output=''
try {
  const args=['supabase','status','-o','env']
  if(process.platform==='win32'){
    output=execFileSync('cmd.exe',['/d','/s','/c','npx supabase status -o env'],
      {cwd:sandbox,encoding:'utf8',stdio:['ignore','pipe','pipe'],timeout:30000,windowsHide:true})
  } else {
    output=execFileSync('npx',args,{cwd:sandbox,encoding:'utf8',
      stdio:['ignore','pipe','pipe'],timeout:30000})
  }
} catch {
  fail('Local Docker Supabase is not running. Start it inside .helios-guest-sandbox using npx supabase start.')
}
const vars=new Map()
for(const line of output.split(/\r?\n/)){
  const m=line.trim().match(/^(?:export\s+)?([A-Z][A-Z0-9_]*)=(.*)$/)
  if(!m)continue
  let value=m[2].trim()
  if((value.startsWith('"')&&value.endsWith('"'))||(value.startsWith("'")&&value.endsWith("'")))
    value=value.slice(1,-1)
  vars.set(m[1],value)
}
const raw=vars.get('API_URL') || vars.get('SUPABASE_URL') || ''
let url
try{url=new URL(raw)}catch{fail('Missing local Supabase API_URL')}
if(url.protocol!=='http:' || !['localhost','127.0.0.1'].includes(url.hostname)
   || url.port!=='54341' || url.username || url.password || url.search || url.hash)
  fail('Refusing to connect to any backend other than localhost port 54341.')
const key=vars.get('PUBLISHABLE_KEY') || vars.get('SUPABASE_PUBLISHABLE_KEY') || vars.get('ANON_KEY') || ''
if(!((key.startsWith('sb_publishable_')||key.startsWith('eyJ'))&&key.length>=25&&!/\s/.test(key)))
  fail('Local status is missing a browser-safe publishable / anon key.')
process.env.TL_SUPABASE_URL=url.origin
process.env.TL_SUPABASE_PUBLISHABLE_KEY=key
process.env.TL_DEV_PORT='8002'
console.log('Helios Guest Mode testing: LOCAL isolated backend '+url.origin)
console.log('This cannot connect to the production Supabase project.')
await import('./build.mjs')
