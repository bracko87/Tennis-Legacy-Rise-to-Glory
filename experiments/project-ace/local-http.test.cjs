'use strict';
const assert=require('node:assert/strict');
const http=require('node:http');
const os=require('node:os');
const path=require('node:path');
const fs=require('node:fs');
const {makeAuth}=require('./local-auth.cjs');
const {createStore,makeHandler}=require('./local-server.cjs');
async function run(){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'ace-test-'));
 let store=createStore(dir), server, now=1000, role=true;
 const auth=makeAuth({url:'http://127.0.0.1:54321',key:'sb_publishable_fake_local_test',adminId:'admin',syntheticId:'peer',multiplayerTest:true,fetcher:async(url,opt)=>{
  const id=opt.headers.Authorization?.slice(7);
  if(url.includes('/token?')){const b=JSON.parse(opt.body);return {ok:b.password==='fixture-password',json:async()=>({access_token:b.email.split('@')[0]})};}
  return {ok:true,json:async()=>url.endsWith('/user')?{id,is_anonymous:id==='anon'}:role};
 }});
 try{
  assert.throws(()=>createStore(dir),/EEXIST/);
  server=http.createServer();
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  const port=server.address().port,base='http://127.0.0.1:'+port;
  server.on('request',makeHandler({store,auth,port,now:()=>now}));
  async function req(p,{method='GET',token,body,origin=base}={}){
   const headers={Origin:origin};if(token)headers.Authorization='Bearer '+token;if(body!==undefined)headers['Content-Type']='application/json';
   const r=await fetch(base+p,{method,headers,body:body===undefined?undefined:JSON.stringify(body)});
   return {status:r.status,body:await r.json()};
  }
  const page=await fetch(base+'/');assert.equal(page.status,200);assert.match(await page.text(),/Project Ace/);
  assert.equal((await req('/api/fixture')).status,403);
  assert.equal((await req('/api/login',{method:'POST',body:{email:'other@test.invalid',password:'fixture-password'}})).status,403);
  assert.equal((await req('/api/login',{method:'POST',origin:'http://evil.invalid',body:{email:'admin@test.invalid',password:'fixture-password'}})).status,403);
  const sign=await req('/api/login',{method:'POST',body:{email:'admin@test.invalid',password:'fixture-password'}});assert.equal(sign.status,200);assert.equal(sign.body.admin,true);
  const token=sign.body.token;
  const peer=await req('/api/login',{method:'POST',body:{email:'peer@test.invalid',password:'fixture-password'}});assert.equal(peer.body.admin,false);
  assert.equal((await req('/api/fixture',{method:'POST',token:'peer',body:{}})).status,403);
  const created=await req('/api/fixture',{method:'POST',token,body:{pace:'fast',delaySeconds:5,humanOpponent:true,mode:'manual',peerMode:'manual'}});assert.equal(created.status,201);assert.equal(created.body.status,'scheduled');
  assert.equal((await req('/api/fixture',{method:'POST',token,body:{}})).status,409);
  const [a,b]=await Promise.all([req('/api/coach',{method:'POST',token,body:{targetGame:1,tactics:{rally:'Extend rallies'}}}),req('/api/coach',{method:'POST',token:'peer',body:{targetGame:1,tactics:{rally:'Shorten points'}}})]);
  assert.equal(a.status,200);assert.equal(b.status,200);
  now=6000;
  const av=await req('/api/fixture',{token}),bv=await req('/api/fixture',{token:'peer'});
  assert.equal(av.body.totalPoints,0);assert.equal(av.body.ownTactics.tactics.rally,'Extend rallies');assert.equal(bv.body.ownTactics.tactics.rally,'Shorten points');assert.equal(JSON.stringify(av.body).includes('Shorten points'),false);
  now=8000;const v=await req('/api/fixture',{token});assert.equal(v.body.totalPoints,1);assert.equal(v.body.events[0].probability,undefined);
  const checkpoint=store.read();store.close();store=createStore(dir);assert.deepEqual(store.read(),checkpoint);
  // Handler captures original store, which reads/writes the same path; replacement holds lock.
  now=2000000;const end=await req('/api/fixture',{token});assert.equal(end.body.status,'completed');assert.notEqual(end.body.winner,null);
  role=false;assert.equal((await req('/api/fixture',{token})).status,403);
  console.log('PASS native HTTP, login allowlist, simultaneous commands, elapsed-only events, persistence reopen, completion and revocation');
 }finally{if(server)await new Promise(r=>server.close(r));store.close();fs.rmSync(dir,{recursive:true,force:true});}
}
run().catch(e=>{console.error(e);process.exitCode=1;});
