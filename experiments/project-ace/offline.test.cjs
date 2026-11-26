'use strict';
const assert=require('node:assert/strict');
const http=require('node:http'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {makeOfflineAuth}=require('./start-offline.cjs');
const {makeHandler,createStore}=require('./local-server.cjs');
async function run(){
 let now=1000;const email='local@example.invalid',password='local-test-password',peerPassword='peer-test-password';
 const auth=makeOfflineAuth({email,password,now:()=>now});
 assert.equal(await auth.login(email,'wrong'),null);
 assert.equal(await auth.login('other@example.invalid',password),null);
 assert.equal(await auth.login('ace-peer@example.invalid',peerPassword),null);
 const admin=await auth.login(email,password);
 assert.equal(admin.admin,true);
 assert.equal((await auth.authenticate('Bearer '+admin.token)).isAdmin,true);
 assert.equal(await auth.authenticate('Bearer fake'),null);
 now+=8*60*60*1000;assert.equal(await auth.authenticate('Bearer '+admin.token),null);
 now=1000;
 const multi=makeOfflineAuth({email,password,peerPassword,now:()=>now});
 const peer=await multi.login('ace-peer@example.invalid',peerPassword);
 assert.equal(peer.admin,false);assert.equal((await multi.authenticate('Bearer '+peer.token)).synthetic,true);
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'ace-offline-')),store=createStore(dir),server=http.createServer();
 try{
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  const port=server.address().port,base='http://127.0.0.1:'+port;
  server.on('request',makeHandler({store,auth,port,now:()=>now}));
  async function req(p,method='GET',body,token){
   const headers={Origin:base};if(body!==undefined)headers['Content-Type']='application/json';if(token)headers.Authorization='Bearer '+token;
   const r=await fetch(base+p,{method,headers,body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,body:await r.json()};
  }
  assert.equal((await req('/api/fixture')).status,403);
  const login=await req('/api/login','POST',{email,password});assert.equal(login.status,200);
  const t=login.body.token;
  assert.equal((await req('/api/fixture','POST',{humanOpponent:true},t)).status,400);
  assert.equal((await req('/api/fixture','POST',{pace:'fast',delaySeconds:5,mode:'manual'},t)).status,201);
  assert.equal((await req('/api/coach','POST',{targetGame:1,tactics:{approach:'Aggressive'}},t)).status,200);
  now=8000;const v=await req('/api/fixture','GET',undefined,t);assert.equal(v.body.totalPoints,1);
  assert.equal(v.body.ownTactics.tactics.approach,'Aggressive');
  now=2000000;assert.equal((await req('/api/fixture','GET',undefined,t)).body.status,'completed');
 }finally{await new Promise(r=>server.close(r));store.close();fs.rmSync(dir,{recursive:true,force:true});}
 console.log('PASS Docker-free login, expiring sessions, admin-only gate, optional peer, native HTTP match and coaching');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
