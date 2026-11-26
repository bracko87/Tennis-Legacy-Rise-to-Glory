'use strict';
const assert=require('node:assert/strict'),http=require('node:http');
const {handler,demo}=require('./tournament-http.cjs'),{makeOfflineAuth}=require('./start-offline.cjs'),d=require('./tournament-draw.cjs');
async function run(){
 let now=1000,state=null;
 const auth=makeOfflineAuth({email:'test@example.invalid',password:'test-pass',peerPassword:'peer-pass',now:()=>now});
 const server=http.createServer();await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const port=server.address().port,base='http://127.0.0.1:'+port;
 const store={read:()=>state,save:s=>{state=s;}};
 server.on('request',handler({auth,port,now:()=>now,getStore:()=>state?store:null,createStore:s=>{state=s;}}));
 const req=async(p,method='GET',body,token)=>{const headers={Origin:base};if(body!==undefined)headers['Content-Type']='application/json';if(token)headers.Authorization='Bearer '+token;const r=await fetch(base+p,{method,headers,body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,body:await r.json()};};
 try{
  assert.equal((await fetch(base)).status,200);
  assert.equal((await req('/api/draw')).status,403);
  assert.equal((await req('/api/login','POST',{email:'ace-peer@example.invalid',password:'peer-pass'})).status,403);
  const token=(await req('/api/login','POST',{email:'test@example.invalid',password:'test-pass'})).body.token;
  assert.equal((await req('/api/draw','POST',{delaySeconds:5,pace:'fast',mode:'manual'},token)).status,201);
  assert.equal((await req('/api/draw','POST',{},token)).status,409);
  now=6000;const x=await req('/api/match?id=draw-1','GET',undefined,token);assert.equal(x.body.managed,false);assert.equal(x.body.side,null);assert.equal('ownHistory' in x.body,false);
  assert.equal((await req('/api/coach?id=draw-1','POST',{targetGame:2,tactics:{serve:'Power serving'}},token)).status,403);
  // Advance boundary by boundary until the first managed main-draw match starts.
  const p={id:auth.policy.adminId,verified:true,isAdmin:true};
  const next=require('./tournament-lifecycle.cjs').nextEventAt;
  for(let i=0;i<1000;i++){state=d.advance(state,p,auth.policy,now);if(state.scheduler.jobs.some(j=>j.playerKeys.includes('p0')&&j.status==='live'))break;now=next(state.scheduler);assert.ok(Number.isFinite(now));}
  const job=state.scheduler.jobs.find(j=>j.playerKeys.includes('p0')&&j.status==='live');assert.ok(job);
  const live=(await req('/api/match?id='+job.id,'GET',undefined,token)).body;assert.equal(live.managed,true);assert.equal(live.side,0);assert.equal(live.coachingMode,'manual');
  const c=await req('/api/coach?id='+job.id,'POST',{targetGame:live.nextCoachingGame,tactics:{serve:'Power serving'}},token);assert.equal(c.status,200);assert.equal(c.body.ownPending.serve,'Power serving');
  assert.equal((await req('/api/heartbeat?id='+job.id,'POST',{},token)).status,200);
  // Session expires after 8h; simulated completion is much shorter.
  now+=5000000;const final=await req('/api/draw','GET',undefined,token);assert.equal(final.body.phase,'completed');assert.equal(final.body.results.length,6);
 }finally{await new Promise(r=>server.close(r));}
 console.log('PASS native private tournament HTTP, admin-only access, spectator privacy, managed match commands and complete bracket');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
