// Real Auth + PostgREST acceptance test. Requires the restored LOCAL Helios stack.
// No live database connection, no service-role token, no hard deletion.
// The test creates one synthetic account in the local sandbox.
import assert from 'node:assert/strict'
import {readFileSync,existsSync} from 'node:fs'
import {resolve,dirname} from 'node:path'
import {fileURLToPath} from 'node:url'
import {execFileSync} from 'node:child_process'
import {randomUUID} from 'node:crypto'
import {createClient} from '@supabase/supabase-js'

export function requireLocalUrl(input, port) {
  const u=new URL(input)
  if(u.protocol!=='http:'|| !['127.0.0.1','localhost'].includes(u.hostname)
    ||u.port!==String(port)||u.username||u.password||u.hash)
    throw Error('Refusing a non-Helios localhost endpoint')
  return u
}
export function parseStatus(output) {
  const vars=new Map()
  for(const line of output.split(/\r?\n/)){
    const m=line.trim().match(/^(?:export\s+)?([A-Z][A-Z0-9_]*)=(.*)$/)
    if(!m)continue
    vars.set(m[1],m[2].trim().replace(/^["']|["']$/g,''))
  }
  const api=requireLocalUrl(vars.get('API_URL')||vars.get('SUPABASE_URL')||'',54341)
  if(api.pathname!=='/'||api.search)throw Error('Not a local API origin')
  const key=vars.get('PUBLISHABLE_KEY')||vars.get('SUPABASE_PUBLISHABLE_KEY')||vars.get('ANON_KEY')||''
  if(!((key.startsWith('sb_publishable_')||key.startsWith('eyJ'))&&key.length>=25&&!/\s/.test(key)))
    throw Error('Missing local publishable or anonymous key')
  if(key.startsWith('eyJ')){
    let claims
    try{ claims=JSON.parse(Buffer.from(key.split('.')[1],'base64url').toString('utf8')) }
    catch{ throw Error('Invalid local anonymous JWT') }
    if(claims.role!=='anon')throw Error('Expected anon role, never use a privileged key')
  }
  return {origin:api.origin,key}
}
export function assertTrial(a,b) {
  assert.equal(a.state,'active','Trial must be active')
  assert.equal(a.is_guest,true)
  assert.equal(a.can_play,true)
  assert.equal(a.premium_trial_active,true)
  assert.equal(Date.parse(a.expires_at)-Date.parse(a.started_at),14*86400000,'Guest duration must be 14 real days')
  assert.equal(Date.parse(a.premium_expires_at)-Date.parse(a.started_at),7*86400000,'Premium duration must be seven real days')
  for(const field of ['started_at','expires_at','premium_expires_at'])
    assert.equal(Date.parse(a[field]),Date.parse(b[field]),'Repeated enrollment changed '+field)
}
export async function restrictedFetch(input,init) {
  const url=input instanceof Request?input.url:String(input)
  requireLocalUrl(url,54341)
  // Prevent a local HTTP redirect from sending an Authorization header elsewhere.
  return fetch(input,{...init,redirect:'error',signal:init?.signal||AbortSignal.timeout(20000)})
}
async function rpc(client,name,args) {
  const {data,error}=await client.rpc(name,args)
  if(error)throw Error(name+' failed: '+(error.code||'unknown'))
  return data
}
async function main(){
  const root=resolve(dirname(fileURLToPath(import.meta.url)),'..')
  const sandbox=resolve(root,'.helios-guest-sandbox')
  const configPath=resolve(sandbox,'supabase','config.toml')
  const config=existsSync(configPath)?readFileSync(configPath,'utf8'):''
  if(!/project_id\s*=\s*"tennis_helios_guest_sandbox"/.test(config)
    ||!/enable_anonymous_sign_ins\s*=\s*true/.test(config))
    throw Error('Prepare the isolated local Helios schema sandbox first')
  if(/cwfznmroiqcyhfkfcrow/.test(config))throw Error('Production project reference in sandbox configuration')
  let result
  try{
    result=process.platform==='win32'
      ?execFileSync('cmd.exe',['/d','/s','/c','npx supabase status -o env'],{cwd:sandbox,encoding:'utf8',timeout:30000,stdio:['ignore','pipe','pipe'],windowsHide:true})
      :execFileSync('npx',['supabase','status','-o','env'],{cwd:sandbox,encoding:'utf8',timeout:30000,stdio:['ignore','pipe','pipe']})
  }catch{throw Error('Local Supabase stack is not running; start the isolated sandbox first')}
  const {origin,key}=parseStatus(result)
  const client=createClient(origin,key,{
    auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},
    global:{fetch:restrictedFetch}
  })
  assert.equal(await rpc(client,'get_public_tennis_guest_test_status_v1'),true,'Local guest switch must be enabled')
  const unauthEnrol=await client.rpc('enroll_my_tennis_guest_trial_v1')
  assert.ok(unauthEnrol.error,'Signed-out enrollment must fail')
  console.log('PASS local gate and signed-out enrollment rejection')
  const signIn=await client.auth.signInAnonymously()
  if(signIn.error)throw Error('Local anonymous Auth failed: '+(signIn.error.code||'unknown'))
  const id=signIn.data.user?.id
  assert.ok(id,'Auth user ID missing')
  assert.equal(signIn.data.user.is_anonymous,true)
  const before=await rpc(client,'get_my_tennis_guest_trial_v1')
  assert.equal(before.state,'not_enrolled')
  const preAccess=await client.rpc('assert_my_tennis_guest_access_v1')
  assert.ok(preAccess.error,'Unenrolled guest gameplay must be forbidden')
  console.log('PASS real anonymous Auth and blocked unenrolled gameplay')
  const first=await rpc(client,'enroll_my_tennis_guest_trial_v1')
  const repeat=await rpc(client,'enroll_my_tennis_guest_trial_v1')
  assertTrial(first,repeat)
  const read=await rpc(client,'get_my_tennis_guest_trial_v1')
  assert.equal(read.state,'active')
  assert.equal(Date.parse(read.expires_at),Date.parse(first.expires_at))
  await rpc(client,'assert_my_tennis_guest_access_v1')
  const status=await rpc(client,'get_my_tennis_guest_conversion_status_v1')
  assert.equal(status.eligible,true)
  assert.equal(status.is_anonymous,true)
  assert.equal(status.can_convert,true)
  const user=await client.auth.getUser()
  if(user.error)throw Error('Local session retrieval failed')
  assert.equal(user.data.user.id,id)
  console.log('PASS real 14-day guest, 7-day Premium, unchanged repeated enrollment and same Auth identity')
  const email='helios-qa-'+randomUUID()+'@example.invalid'
  const update=await client.auth.updateUser({email},{emailRedirectTo:'http://127.0.0.1:8002/guest/register'})
  if(update.error)throw Error('Local email-link request failed: '+(update.error.code||'unknown'))
  assert.equal(update.data.user.id,id,'Email link request replaced Auth identity')
  // Confirmation depends on local SMTP. Do not silently bypass it or use a
  // service role to force conversion; actual browser linking remains an E2E gate.
  const pending=await rpc(client,'get_my_tennis_guest_conversion_status_v1')
  assert.equal(pending.eligible,true)
  console.log('PASS local email-link request retains identity.')
  console.log('LIMIT: Complete the confirmation in LOCAL Mailpit and browser. This does not certify confirmed conversion, gameplay, expiration, hard deletion or full-schema restoration.')
  console.log('The synthetic account stays in the disposable local stack; no deletion is attempted.')
  await client.auth.signOut({scope:'local'})
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))
 main().catch(e=>{console.error('FAIL Helios real local Auth: '+e.message);process.exitCode=1})
