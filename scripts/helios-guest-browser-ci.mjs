// Actual guest React pages and AuthProvider, real Chromium, real disposable Auth.
// No network requests to the public game or external sites; synthetic accounts only.
import assert from 'node:assert/strict'
import {createServer} from 'node:http'
import {mkdtemp,readFile,rm} from 'node:fs/promises'
import {tmpdir} from 'node:os'
import {join,resolve} from 'node:path'
import {execFileSync} from 'node:child_process'
import {randomUUID} from 'node:crypto'
import {createRequire} from 'node:module'
import * as esbuild from 'esbuild'
import {parseStatus,requireLocalUrl} from './helios-local-guest-auth-acceptance.mjs'
if(process.env.GITHUB_ACTIONS!=='true')throw Error('CI-only browser test')
const sandbox=resolve('.helios-guest-sandbox')
const config=await readFile(join(sandbox,'supabase/config.toml'),'utf8')
if(!config.includes('project_id = "tennis_helios_guest_sandbox"'))throw Error('Missing isolated sandbox')
const {origin,key}=parseStatus(execFileSync('supabase',['status','-o','env'],{cwd:sandbox,encoding:'utf8',stdio:['ignore','pipe','pipe']}))
const require=createRequire(import.meta.url)
const {chromium}=require('/tmp/helios-browser-tools/node_modules/playwright')
const dir=await mkdtemp(join(tmpdir(),'helios-ui-'))
let server,browser
const base='http://127.0.0.1:8002'
function gate(enabled){
 const sql="DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM control_center_private.helios_real_auth_ci_marker WHERE id) THEN RAISE EXCEPTION 'CI marker missing'; END IF; UPDATE public.registration_control SET guest_test_enabled="+(enabled?'true':'false')+" WHERE singleton_id=true; END $$;"
 execFileSync('docker',['exec','-i','supabase_db_tennis_helios_guest_sandbox','psql','-X','-w','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{input:sql,stdio:['pipe','pipe','pipe'],timeout:20000})
}
async function mailLink(email){
 for(let i=0;i<30;i++){
  const list=await fetch('http://127.0.0.1:54344/api/v1/search?query='+encodeURIComponent('to:'+email),{redirect:'error',signal:AbortSignal.timeout(5000)}).then(r=>r.json())
  for(const msg of list.messages||[]){
   if(!msg.To?.some(x=>x.Address?.toLowerCase()===email))continue
   const full=await fetch('http://127.0.0.1:54344/api/v1/message/'+encodeURIComponent(msg.ID),{redirect:'error',signal:AbortSignal.timeout(5000)}).then(r=>r.json())
   const body=String(full.Text||'')+'\n'+String(full.HTML||'').replace(/&amp;/g,'&')
   for(const match of body.matchAll(/https?:\/\/[^\s<>"']+/g)){
    let u
    try{u=requireLocalUrl(match[0],54341)}catch{continue}
    if(u.pathname==='/auth/v1/verify'&&u.searchParams.get('type')==='email_change'&&u.searchParams.get('token')){
     const redirect=new URL(u.searchParams.get('redirect_to')||base+'/guest/register')
     if(redirect.origin!==base||redirect.pathname!=='/guest/register')throw Error('Nonlocal or unexpected verification redirect')
     return u.toString()
    }
   }
  }
  await new Promise(r=>setTimeout(r,1000))
 }
 throw Error('Local verification email not found')
}
try{
 await esbuild.build({entryPoints:['tests/browser/helios-guest-harness.tsx'],outfile:join(dir,'app.js'),bundle:true,format:'iife',jsx:'automatic',define:{__TL_SUPABASE_URL__:JSON.stringify(origin),__TL_SUPABASE_PUBLISHABLE_KEY__:JSON.stringify(key)},loader:{'.css':'css'},external:['/mock/*','/marketing/*'],logLevel:'warning'})
 server=createServer(async(req,res)=>{
   try{
    const path=new URL(req.url,base).pathname
    if(path==='/app.js'||path==='/app.css'){
     res.setHeader('Content-Type',path.endsWith('.js')?'text/javascript':'text/css')
     res.end(await readFile(join(dir,path.slice(1))))
    }else{
     res.setHeader('Content-Type','text/html; charset=utf-8')
     res.end('<!doctype html><html><head><link rel="stylesheet" href="/app.css"></head><body><div id="root"></div><script src="/app.js"></script></body></html>')
    }
   }catch{res.statusCode=404;res.end()}
 })
 await new Promise((ok,fail)=>{server.once('error',fail);server.listen(8002,'127.0.0.1',ok)})
 browser=await chromium.launch({headless:true})
 const context=await browser.newContext({serviceWorkers:'block'})
 await context.route('**/*',route=>{
  let u
  try{u=new URL(route.request().url())}catch{return route.abort()}
  if(u.origin===base||u.origin===origin||u.origin==='http://localhost:54341'||u.origin==='http://127.0.0.1:54341')return route.continue()
  return route.abort()
 })
 const page=await context.newPage()
 page.setDefaultTimeout(30000)
 gate(false)
 await page.goto(base+'/try-as-guest')
 await page.getByText('Test Player access is not available yet.',{exact:false}).waitFor()
 assert.equal(await page.getByRole('button',{name:'Create Test Player'}).isDisabled(),true)
 console.log('PASS real browser disabled guest entry')
 gate(true)
 await page.reload()
 const create=page.getByRole('button',{name:'Create Test Player'})
 await create.click()
 await page.getByRole('heading',{name:'Guest onboarding route reached'}).waitFor()
 const id=(await page.getByTestId('identity').innerText()).trim()
 assert.match(id,/^[0-9a-f-]{36}$/i)
 assert.equal(await page.getByTestId('identity-type').innerText(),'guest')
 await page.getByRole('link',{name:'Continue to registration'}).click()
 await page.getByLabel('Your email address').waitFor()
 // Simulate an old activity record and returning to the window.
 await page.evaluate(()=>{localStorage.setItem('tlg:last-authenticated-activity',String(Date.now()-11*60*1000));window.dispatchEvent(new Event('focus'))})
 await page.reload()
 await page.getByLabel('Your email address').waitFor()
 assert.equal(await page.getByTestId('identity').innerText(),id)
 assert.equal(await page.getByTestId('identity-type').innerText(),'guest')
 console.log('PASS real browser guest session survives inactivity and reload')
 const email='helios-ui-'+randomUUID()+'@example.com'
 await page.getByLabel('Your email address').fill(email)
 await page.getByRole('button',{name:'Verify Email & Save My Progress'}).click()
 await page.getByText('Verification email requested.',{exact:false}).waitFor()
 const verify=await mailLink(email)
 // Browser follows actual Auth verification redirect; never print link/token.
 try{await page.goto(verify,{waitUntil:'domcontentloaded'})}catch{throw Error('Local browser email confirmation navigation failed')}
 await page.getByLabel('New password',{exact:true}).waitFor()
 const password='HeliosUI-'+randomUUID()+'-9'
 await page.getByLabel('New password',{exact:true}).fill(password)
 await page.getByLabel('Confirm password',{exact:true}).fill(password)
 await page.getByRole('button',{name:'Save Password & Complete Registration'}).click()
 await page.getByRole('heading',{name:'Progress saved to your permanent account'}).waitFor()
 assert.equal(await page.getByTestId('identity').innerText(),id)
 assert.equal(await page.getByTestId('identity-type').innerText(),'registered')
 console.log('PASS real browser email confirmation and password setup retain original Auth identity')
 await page.evaluate(()=>{localStorage.setItem('tlg:last-authenticated-activity',String(Date.now()-11*60*1000));window.dispatchEvent(new Event('focus'))})
 await page.getByRole('heading',{name:'Signed out'}).waitFor()
 console.log('PASS registered account retains normal inactivity security logout')
 console.log('LIMIT: actual guest entry/conversion screens and route guards; player-creation destination is a fixture, not full-game browser coverage.')
}catch(e){
 // Avoid printing navigation errors that might contain verification fragments.
 console.error('FAIL isolated Helios browser test:',String(e.message).replace(/https?:\/\/\S+/g,'[url redacted]').replace(/eyJ[A-Za-z0-9._-]+/g,'[jwt redacted]'))
 process.exitCode=1
}finally{
 if(browser)await browser.close()
 if(server)await new Promise(r=>server.close(r))
 gate(true)
 await rm(dir,{recursive:true,force:true})
}
