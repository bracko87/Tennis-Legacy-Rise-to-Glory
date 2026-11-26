'use strict';
const assert=require('node:assert/strict'),http=require('node:http');
const {handler}=require('./tournament-http.cjs'),driver=require('./world-demo.cjs'),{makeOfflineAuth}=require('./start-offline.cjs');
async function run(){
 let now=1000,state=null;
 const auth=makeOfflineAuth({email:'admin@example.invalid',password:'admin-pass',peerPassword:'peer-pass',now:()=>now});
 const server=http.createServer();await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const port=server.address().port,base='http://127.0.0.1:'+port,store={read:()=>state,save:s=>{state=s;}};
 server.on('request',handler({auth,driver,port,now:()=>now,getStore:()=>state?store:null,createStore:s=>{state=s;}}));
 const req=async(path,method='GET',body,token)=>{const headers={Origin:base};if(body!==undefined)headers['Content-Type']='application/json';if(token)headers.Authorization='Bearer '+token;const r=await fetch(base+path,{method,headers,body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,body:await r.json()};};
 try{
  const a=(await req('/api/login','POST',{email:'admin@example.invalid',password:'admin-pass'})).body;
  const b=(await req('/api/login','POST',{email:'ace-peer@example.invalid',password:'peer-pass'})).body;
  assert.equal((await req('/api/draw','POST',{},b.token)).status,403);
  const first=await req('/api/draw','POST',{delaySeconds:5,pace:'fast'},a.token);
  assert.equal(first.status,201);assert.equal(first.body.world.synthetic,true);assert.equal(first.body.career.balance,1000);
  assert.equal(first.body.matches.length,2);assert.ok(first.body.matches.every(m=>m.status==='scheduled'&&m.gameSlot));
  const early=await req('/api/match?id=draw-1','GET',undefined,b.token);assert.equal(early.body.status,'scheduled');
  now=6000;const next=await req('/api/draw','GET',undefined,a.token);assert.equal(next.status,200);assert.equal(next.body.matches.filter(m=>m.status==='live').length,2);
  assert.equal((await req('/api/coach?id=draw-1','POST',{targetGame:2,tactics:{serve:'Power serving'}},b.token)).status,403);
  const peer=await req('/api/draw','GET',undefined,b.token);assert.equal(peer.body.managedPlayer,'p2');assert.equal(peer.body.career.support,null);
  assert.equal('config' in peer.body,false);assert.equal('anchor' in peer.body,false);
  assert.equal(state.admissions.length,2);
 }finally{await new Promise(r=>server.close(r));}
 console.log('PASS native world HTTP creation, calendar activation, peer isolation and sanitized views');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
