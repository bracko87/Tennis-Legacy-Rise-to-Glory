'use strict';
const assert=require('node:assert/strict'),http=require('node:http');
const {handler}=require('./tournament-http.cjs'),driver=require('./world-demo.cjs'),{makeOfflineAuth}=require('./start-offline.cjs');
async function run(){
 let now=1000,state=null;
 const auth=makeOfflineAuth({email:'admin@example.invalid',password:'admin-pass',peerPassword:'peer-pass',now:()=>now});
 const server=http.createServer();await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const port=server.address().port,base='http://127.0.0.1:'+port,store={read:()=>state,save:s=>{state=s;}};
 server.on('request',handler({auth,driver,port,now:()=>now,getStore:()=>state?store:null,createStore:s=>{state=s;}}));
 const req=async(path,method='GET',body,token,origin=base)=>{const headers={Origin:origin};if(body!==undefined)headers['Content-Type']='application/json';if(token)headers.Authorization='Bearer '+token;const r=await fetch(base+path,{method,headers,body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,body:await r.json()};};
 try{
  assert.equal((await req('/api/login','POST',null)).status,400);
  assert.equal((await req('/api/login','POST',[])).status,400);
  assert.equal((await req('/api/login','POST',{email:'admin@example.invalid',password:'wrong'})).status,403);
  assert.equal((await req('/api/login','POST',{email:'admin@example.invalid',password:'admin-pass'},undefined,'https://untrusted.invalid')).status,403);
  assert.equal((await req('/api/login','POST',{email:'x'.repeat(9000)})).status,413);
  const admin=(await req('/api/login','POST',{email:'admin@example.invalid',password:'admin-pass'})).body.token;
  const peer=(await req('/api/login','POST',{email:'ace-peer@example.invalid',password:'peer-pass'})).body.token;
  assert.equal((await req('/api/draw','POST',{delaySeconds:5,pace:'fast'},admin)).status,201);
  const original=JSON.stringify(state);
  assert.equal((await req('/api/draw','POST',{},peer)).status,403);
  assert.equal((await req('/api/draw','GET',undefined,'A'.repeat(43))).status,403);
  assert.equal((await req('/api/coach?id=draw-1','POST',{targetGame:2,tactics:{constructor:'x'}},admin)).status,400);
  assert.equal((await req('/api/coach?id=draw-1','POST',{targetGame:2,tactics:{serve:'bad'}},admin)).status,400);
  assert.equal((await req('/api/coach?id=draw-1','POST',{targetGame:0,tactics:{serve:'Balanced'}},admin)).status,400);
  assert.equal(JSON.stringify(state),original);
  now=6000;
  const v=(await req('/api/match?id=draw-1','GET',undefined,peer)).body;
  assert.equal(v.managed,false);assert.equal(v.side,null);assert.equal(v.events.length,0);
  for(const key of ['checkpoint','active','revealAt','rng','timingSeed','ownHistory','ownTactics','ownPending','activeTactics','recommendations'])assert.equal(Object.hasOwn(v,key),false,key);
  const previous=JSON.stringify(state);
  assert.equal((await req('/api/coach?id=draw-1','POST',{targetGame:2,tactics:{serve:'Balanced'}},peer)).status,403);
  assert.equal(JSON.stringify(state),previous);
  now=8*3600000+1001;
  assert.equal((await req('/api/draw','GET',undefined,admin)).status,403);
  assert.equal((await req('/api/draw','GET',undefined,peer)).status,403);
 }finally{await new Promise(r=>server.close(r));}
 console.log('PASS malformed input, body size, origin, forged/expired tokens, spectator privacy, forbidden commands and unchanged state');
}
run().catch(e=>{console.error(e);process.exitCode=1});
