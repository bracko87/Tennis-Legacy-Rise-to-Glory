'use strict';
// Creates a disposable isolated Supabase stack and local identities. Never links a remote project.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto');
const {execFileSync,spawn}=require('node:child_process');
const root=path.join(os.homedir(),'.tennis-ace-local-v1');
const config=path.join(root,'supabase','config.toml');
const sql="create table public.app_admins(user_id uuid primary key references auth.users(id), role text not null check(role='admin'));\nalter table public.app_admins enable row level security;\nrevoke all on public.app_admins from public,anon,authenticated;\ngrant all on public.app_admins to service_role;\ncreate function public.is_app_admin_v1() returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.app_admins where user_id=auth.uid() and role='admin') $$;\nrevoke all on function public.is_app_admin_v1() from public,anon;\ngrant execute on function public.is_app_admin_v1() to authenticated;\n";
const toml='project_id = "tennis_ace_local_v1"\n[api]\nenabled = true\nport = 54361\n[db]\nport = 54362\nshadow_port = 54360\nmajor_version = 17\n[studio]\nenabled = false\n[local_smtp]\nenabled = true\nport = 54364\n[auth]\nenabled = true\nsite_url = "http://127.0.0.1:8765"\n[auth.email]\nenable_confirmations = false\n[db.seed]\nenabled = false\n';
function cli(args,output=false){
 const cmd=process.platform==='win32'?'cmd.exe':'npx';
 const a=process.platform==='win32'?['/d','/s','/c','npx supabase '+args.join(' ')]:['supabase',...args];
 return execFileSync(cmd,a,{cwd:root,encoding:'utf8',stdio:output?['ignore','pipe','pipe']:'inherit',timeout:600000,windowsHide:true});
}
function parse(s){const vars={};for(const line of s.split(/\r?\n/)){const m=line.trim().match(/^([A-Z][A-Z0-9_]*)=(.*)$/);if(m)vars[m[1]]=m[2].replace(/^["']|["']$/g,'');}return vars;}
async function main(){
 const email=process.env.ACE_ADMIN_EMAIL;if(!email||!email.includes('@'))throw Error('Set ACE_ADMIN_EMAIL to the intended local admin email.');
 if(!fs.existsSync(config)){if(fs.existsSync(root))throw Error('Refusing unknown existing sandbox');fs.mkdirSync(path.join(root,'supabase','migrations'),{recursive:true,mode:0o700});fs.writeFileSync(config,toml);fs.writeFileSync(path.join(root,'supabase','migrations','20261126000000_ace_fixture.sql'),sql);}
 if(fs.readFileSync(config,'utf8')!==toml)throw Error('Unexpected local sandbox config');
 try{cli(['status','-o','env'],true);}catch{cli(['start']);}
 const v=parse(cli(['status','-o','env'],true)),u=new URL(v.API_URL||v.SUPABASE_URL||'');
 if(u.protocol!=='http:'||!['localhost','127.0.0.1'].includes(u.hostname)||u.port!=='54361'||u.pathname!=='/'||u.username||u.password||u.search||u.hash)throw Error('Refusing non-Ace local endpoint');
 const anon=v.PUBLISHABLE_KEY||v.ANON_KEY,service=v.SERVICE_ROLE_KEY||v.SECRET_KEY;
 if(!anon||!service)throw Error('Local credentials unavailable');
 const credFile=path.join(root,'local-accounts.json');
 async function request(endpoint,method,body){const headers={apikey:service,Authorization:'Bearer '+service,'Content-Type':'application/json'};const res=await fetch(u.origin+endpoint,{method,headers,body:JSON.stringify(body),redirect:'error'});if(!res.ok)throw Error('Local provisioning failed: '+endpoint+' HTTP '+res.status);return res.json().catch(()=>null);}
 async function ensure(name){const password=crypto.randomBytes(18).toString('base64url');const data=await request('/auth/v1/admin/users','POST',{email:name,password,email_confirm:true});return {id:data.id||data.user?.id,email:name,password};}
 let credentials;
 if(fs.existsSync(credFile)){credentials=JSON.parse(fs.readFileSync(credFile,'utf8'));if(credentials.admin.email!==email)throw Error('Local admin email differs from saved fixture');}
 else{const admin=await ensure(email),peer=await ensure('ace-peer@example.invalid');await request('/rest/v1/app_admins','POST',{user_id:admin.id,role:'admin'});credentials={admin,peer};fs.writeFileSync(credFile,JSON.stringify(credentials),{mode:0o600,flag:'wx'});}
 console.log('LOCAL ONLY: http://127.0.0.1:8765');
 console.log('Admin email: '+credentials.admin.email+'\nLocal password: '+credentials.admin.password);
 const multiplayer=process.env.ACE_MULTIPLAYER_TEST==='1';
 if(multiplayer)console.log('Optional synthetic peer: '+credentials.peer.email+'\nLocal peer password: '+credentials.peer.password);
 const child=spawn(process.execPath,[path.join(__dirname,'local-server.cjs')],{stdio:'inherit',env:{...process.env,ACE_LOCAL_ENABLED:'1',ACE_PORT:'8765',ACE_SUPABASE_URL:u.origin,ACE_SUPABASE_ANON_KEY:anon,ACE_ADMIN_USER_ID:credentials.admin.id,ACE_MULTIPLAYER_TEST:multiplayer?'1':'0',ACE_SYNTHETIC_USER_ID:multiplayer?credentials.peer.id:'',ACE_STATE_DIR:path.join(root,'state')}});
 child.on('exit',code=>{process.exitCode=code??1;});for(const sig of ['SIGINT','SIGTERM'])process.on(sig,()=>child.kill(sig));
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
