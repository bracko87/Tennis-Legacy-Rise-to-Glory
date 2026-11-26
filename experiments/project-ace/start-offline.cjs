'use strict';
// Standalone localhost pilot only. No remote database, network auth, or production credentials.
const crypto=require('node:crypto');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {serveLocal}=require('./local-server.cjs');
const hash=x=>crypto.createHash('sha256').update(x).digest();
const makePassword=()=>crypto.randomBytes(18).toString('base64url');
function makeOfflineAuth({email,password,peerPassword=null,now=Date.now}){
 const accounts=[{email:email.toLowerCase(),hash:hash(password),principal:{id:'ace-local-admin-v1',verified:true,isAdmin:true}}];
 if(peerPassword)accounts.push({email:'ace-peer@example.invalid',hash:hash(peerPassword),principal:{id:'ace-local-peer-v1',verified:true,synthetic:true}});
 const policy={enabled:true,adminId:'ace-local-admin-v1',syntheticId:peerPassword?'ace-local-peer-v1':null,multiplayerTest:!!peerPassword};
 const sessions=new Map();
 const lifetime=8*60*60*1000;
 async function login(email,password){
  if(typeof email!=='string'||typeof password!=='string'||email.length>320||password.length>1024)return null;
  const entry=accounts.find(x=>x.email===email.trim().toLowerCase());
  if(!entry||!crypto.timingSafeEqual(entry.hash,hash(password)))return null;
  for(const [k,v] of sessions)if(v.expires<=now())sessions.delete(k);
  if(sessions.size>=100)sessions.delete(sessions.keys().next().value);
  const token=crypto.randomBytes(32).toString('base64url');
  sessions.set(token,{principal:entry.principal,expires:now()+lifetime});
  return {token,admin:entry.principal.isAdmin===true};
 }
 async function authenticate(header){
  if(typeof header!=='string'||!/^Bearer [A-Za-z0-9_-]{43}$/.test(header))return null;
  const token=header.slice(7),s=sessions.get(token);
  if(!s||s.expires<=now()){sessions.delete(token);return null;}
  return {...s.principal};
 }
 async function logout(header){if(typeof header==='string'&&/^Bearer [A-Za-z0-9_-]{43}$/.test(header))sessions.delete(header.slice(7));}
 return {policy,login,authenticate,logout};
}
function start(){
 const email=(process.env.ACE_ADMIN_EMAIL||'').trim().toLowerCase();
 if(!email||!email.includes('@')||email==='ace-peer@example.invalid')throw Error('Set ACE_ADMIN_EMAIL to your local test email.');
 const dir=path.join(os.homedir(),'.tennis-ace-offline-v1');
 // Separate from the optional real local Supabase sandbox.
 fs.mkdirSync(dir,{recursive:true,mode:0o700});
 const identity=path.join(dir,'identity.json');
 if(fs.existsSync(identity)){
  if(JSON.parse(fs.readFileSync(identity,'utf8')).email!==email)throw Error('This pilot belongs to a different local test identity.');
 }else fs.writeFileSync(identity,JSON.stringify({email}),{flag:'wx',mode:0o600});
 const password=makePassword(),peerPassword=process.env.ACE_MULTIPLAYER_TEST==='1'?makePassword():null;
 const auth=makeOfflineAuth({email,password,peerPassword});
 console.log('PROJECT ACE — NODE ONLY — NO DOCKER OR SUPABASE');
 console.log('Local test email: '+email+'\nTemporary local password: '+password);
 if(peerPassword)console.log('Synthetic peer: ace-peer@example.invalid\nTemporary local peer password: '+peerPassword);
 console.log('Passwords change on each launch. Your match state persists locally.');
 serveLocal({auth,dir:path.join(dir,'state'),port:8765});
}
if(require.main===module){try{start()}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={makeOfflineAuth};
