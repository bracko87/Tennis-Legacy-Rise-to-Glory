'use strict';
const assert=require('node:assert/strict'),http=require('node:http');
const d=require('./tournament-draw.cjs'),{handler}=require('./tournament-http.cjs'),{makeOfflineAuth}=require('./start-offline.cjs'),{fixtureProfiles}=require('./profiles.cjs');
async function run(){
 let now=1000;
 const auth=makeOfflineAuth({email:'admin@example.invalid',password:'admin-pass',peerPassword:'peer-pass',now:()=>now});
 const admin={id:auth.policy.adminId,verified:true,isAdmin:true};
 const entrants=['p0','p1','p2','p3'].map((id,i)=>({id,profile:{...fixtureProfiles()[0],name:'Player '+i}}));
 let state=d.create({entrants,mainSlots:['p0','p1','p2','p3'],courts:['c1','c2'],startAt:2000,seed:42,pace:'fast',managedPlayer:'p0',managedMode:'manual',peerPlayer:'p1',peerMode:'manual'},admin,auth.policy,now);
 const store={read:()=>state,save:s=>{state=s;}};
 const server=http.createServer();await new Promise(r=>server.listen(0,'127.0.0.1',r));const port=server.address().port,base='http://127.0.0.1:'+port;
 server.on('request',handler({auth,port,now:()=>now,getStore:()=>store,createStore:()=>{throw Error('Unexpected create')}}));
 const req=async(path,method='GET',body,token)=>{const headers={Origin:base};if(body!==undefined)headers['Content-Type']='application/json';if(token)headers.Authorization='Bearer '+token;const r=await fetch(base+path,{method,headers,body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,body:await r.json()};};
 try{
  const A=(await req('/api/login','POST',{email:'admin@example.invalid',password:'admin-pass'})).body;
  const B=(await req('/api/login','POST',{email:'ace-peer@example.invalid',password:'peer-pass'})).body;
  assert.ok(A.admin);assert.equal(B.admin,false);assert.ok(B.token);
  assert.equal((await req('/api/draw','POST',{},B.token)).status,403);
  assert.equal((await req('/api/draw','GET',undefined,A.token)).body.managedPlayer,'p0');
  assert.equal((await req('/api/draw','GET',undefined,B.token)).body.managedPlayer,'p1');
  now=2000;
  const av=(await req('/api/match?id=draw-1','GET',undefined,A.token)).body,bv=(await req('/api/match?id=draw-1','GET',undefined,B.token)).body;
  assert.equal(av.side,0);assert.equal(bv.side,1);assert.equal(av.opponentType,'human');assert.deepEqual(av.games,bv.games);
  const [ac,bc]=await Promise.all([req('/api/coach?id=draw-1','POST',{targetGame:2,tactics:{serve:'Power serving'}},A.token),req('/api/coach?id=draw-1','POST',{targetGame:2,tactics:{rally:'Shorten points'}},B.token)]);
  assert.equal(ac.status,200);assert.equal(bc.status,200);assert.equal(ac.body.ownPending.serve,'Power serving');assert.equal(bc.body.ownPending.rally,'Shorten points');assert.equal(bc.body.ownPending.serve,undefined);
  const spectator=(await req('/api/match?id=draw-2','GET',undefined,B.token)).body;assert.equal(spectator.managed,false);assert.equal(spectator.side,null);assert.equal('ownHistory' in spectator,false);
  assert.equal((await req('/api/coach?id=draw-2','POST',{targetGame:2,tactics:{serve:'Power serving'}},B.token)).status,403);
  now=state.scheduler.jobs[0].fixture.active.endAt+5000;
  const a2=(await req('/api/match?id=draw-1','GET',undefined,A.token)).body,b2=(await req('/api/match?id=draw-1','GET',undefined,B.token)).body;
  assert.equal(a2.activeTactics.serve,'Power serving');assert.equal(b2.activeTactics.rally,'Shorten points');assert.equal(a2.activeTactics.rally,'Balanced rallies');
  now=5000000;const finA=(await req('/api/draw','GET',undefined,A.token)).body,finB=(await req('/api/draw','GET',undefined,B.token)).body;
  assert.equal(finA.phase,'completed');assert.equal(finA.champion,finB.champion);assert.equal(finA.results.length,3);assert.deepEqual(finA.results,finB.results);assert.ok(finB.conditions.every(x=>x.playerId==='p1'));assert.ok(finA.conditions.every(x=>x.playerId==='p0'));
  const opposite=d.create({entrants,mainSlots:['p0','p2','p1','p3'],courts:['c1','c2'],startAt:now+1000,seed:43,pace:'fast',managedPlayer:'p0',peerPlayer:'p1'},admin,auth.policy,now);
  const peer={id:auth.policy.syntheticId,verified:true,synthetic:true};
  const peerOnly=d.matchView(opposite,'draw-2',peer,auth.policy,now+1000);
  assert.equal(peerOnly.side,1);assert.equal(peerOnly.opponentType,'ai');assert.equal(peerOnly.opponentOnline,false);
  assert.equal(d.matchView(opposite,'draw-2',admin,auth.policy,now+1000).managed,false);
 }finally{await new Promise(r=>server.close(r));}
 console.log('PASS two authenticated tournament managers, own-match commands, simultaneous tactical activation, spectator isolation and shared champion');
}
run().catch(e=>{console.error(e);process.exitCode=1});
