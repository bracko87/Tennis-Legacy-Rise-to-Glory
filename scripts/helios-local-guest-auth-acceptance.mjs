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
    result=process.env.GITHUB_ACTIONS==='true'&&process.env.HELIOS_CI_LOCAL_CLI==='1'
      ?execFileSync('supabase',['status','-o','env'],{cwd:sandbox,encoding:'utf8',timeout:30000,stdio:['ignore','pipe','pipe']})
      :process.platform==='win32'
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
  const email='helios-qa-'+randomUUID()+'@example.com'
  const update=await client.auth.updateUser({email},{emailRedirectTo:'http://127.0.0.1:8002/guest/register'})
  if(update.error)throw Error('Local email-link request failed: '+(update.error.code||'unknown'))
  assert.equal(update.data.user.id,id,'Email link request replaced Auth identity')
  // Retrieve only the message addressed to the unique synthetic email from
  // the LOCAL Mailpit API. Never follow an arbitrary URL or log the token.
  const mailBase='http://127.0.0.1:54344'
  async function mailJson(path){
    const u=requireLocalUrl(mailBase+path,54344)
    const response=await fetch(u,{redirect:'error',signal:AbortSignal.timeout(5000)})
    if(!response.ok)throw Error('Local Mailpit API returned '+response.status)
    return response.json()
  }
  let verification
  for(let attempt=0;attempt<20&&!verification;attempt++){
    const list=await mailJson('/api/v1/search?query='+encodeURIComponent('to:'+email))
    for(const msg of list.messages||[]){
      if(!msg.To?.some(x=>x.Address?.toLowerCase()===email))continue
      const full=await mailJson('/api/v1/message/'+encodeURIComponent(msg.ID))
      const body=String(full.Text||'')+'\n'+String(full.HTML||'').replace(/&amp;/g,'&')
      for(const match of body.matchAll(/https?:\/\/[^\s<>"']+/g)){
        let url
        try{url=requireLocalUrl(match[0],54341)}catch{continue}
        if(url.pathname==='/auth/v1/verify'&&url.searchParams.get('type')==='email_change'){
          verification=url.searchParams.get('token')
          if(verification)break
        }
      }
      if(verification)break
    }
    if(!verification)await new Promise(r=>setTimeout(r,1000))
  }
  if(!verification)throw Error('No local email-change confirmation link received in Mailpit')
  const verified=await client.auth.verifyOtp({token_hash:verification,type:'email_change'})
  if(verified.error)throw Error('Local email verification failed: '+(verified.error.code||'unknown'))
  const linked=await client.auth.getUser()
  if(linked.error)throw Error('Local verified identity unavailable')
  assert.equal(linked.data.user.id,id,'Email verification must retain original Auth ID')
  assert.equal(linked.data.user.is_anonymous,false)
  const converted=await rpc(client,'get_my_tennis_guest_conversion_status_v1')
  assert.equal(converted.eligible,true)
  assert.equal(converted.email_verified,true)
  assert.equal(converted.is_anonymous,false)
  assert.ok(converted.converted_at,'Conversion timestamp required')
  assert.equal(Date.parse(converted.started_at),Date.parse(first.started_at))
  assert.equal(Date.parse(converted.expires_at),Date.parse(first.expires_at))
  const password='HeliosQA-'+randomUUID()+'-9'
  const pass=await client.auth.updateUser({password})
  if(pass.error)throw Error('Local password setup failed: '+(pass.error.code||'unknown'))
  assert.equal(pass.data.user.id,id)
  const finalStatus=await rpc(client,'get_my_tennis_guest_conversion_status_v1')
  assert.equal(finalStatus.password_set,true)
  assert.equal(finalStatus.converted_at,converted.converted_at)
  const afterConversion=await client.rpc('enroll_my_tennis_guest_trial_v1')
  assert.ok(afterConversion.error,'Permanent identity cannot re-enroll as guest')
  await client.auth.signOut({scope:'local'})
  const login=await client.auth.signInWithPassword({email,password})
  if(login.error)throw Error('Local permanent account sign-in failed: '+(login.error.code||'unknown'))
  assert.equal(login.data.user.id,id,'Permanent sign-in must retain original Auth ID')
  assert.equal(login.data.user.is_anonymous,false)
  await client.auth.signOut({scope:'local'})
  console.log('PASS confirmed local email conversion, password setup, permanent sign-in and no second trial.')
  console.log('LIMIT: This is a real Auth/RPC integration test, not browser UI, full gameplay, expiry retirement or physical data erasure verification.')
  console.log('The synthetic account stays in the disposable local stack; no deletion is attempted.')
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))
 main().catch(e=>{console.error('FAIL Helios real local Auth: '+e.message);process.exitCode=1})
