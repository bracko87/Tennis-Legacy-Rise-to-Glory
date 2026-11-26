'use strict';
const assert=require('node:assert/strict'),http=require('node:http'),{open}=require('./postgres-store.cjs'),{gateway}=require('./postgres-http.cjs'),{makeOfflineAuth}=require('./start-offline.cjs'),c=require('./world-clock.cjs');
async function run(){
 let now=1000,game=c.slot(1,1,1,600)-300;
 const auth=makeOfflineAuth({email:'admin@example.invalid',password:'admin-pass',peerPassword:'peer-pass',now:()=>now});
 const store=open('http-ci'),server=http.createServer();
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const port=server.address().port,base='http://127.0.0.1:'+port;
 const g=gateway({auth,store,port,now:()=>now,clock:()=>({server_now:new Date(now).toISOString(),game_total_seconds:game,speed_multiplier:60})});
 server.on('request',g.handler);
 const req=async(route,method='GET',body,token,origin=base)=>{const headers={Origin:origin};if(token)headers.Authorization='Bearer '+token;if(body!==undefined)headers['Content-Type']='application/json';const r=await fetch(base+route,{method,headers,body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,body:await r.json()};};
 try{
  assert.equal((await req('/api/draw')).status,403);
  const a=(await req('/api/login','POST',{email:'admin@example.invalid',password:'admin-pass'})).body;
  const b=(await req('/api/login','POST',{email:'ace-peer@example.invalid',password:'peer-pass'})).body;
  assert.equal(a.backend,'postgres-review');assert.equal(b.admin,false);
  assert.equal((await req('/api/draw','POST',{},b.token)).status,403);
  assert.equal((await req('/api/draw','POST',{delaySeconds:5,pace:'fast',mode:'manual',peerMode:'manual'},a.token)).status,201);
  assert.equal((await req('/api/draw','POST',{},a.token)).status,409);
  const before=await store.read();assert.equal((await req('/api/draw','GET',undefined,a.token)).body.revision,before.revision);assert.deepEqual(await store.read(),before);
  async function tick(ms,day,hour=10){now=ms;game=c.slot(1,1,day,hour*60);await g.tick();}
  await tick(6000,1);assert.equal((await req('/api/draw','GET',undefined,a.token)).body.matches.filter(x=>x.status==='live').length,2);
  const spec=(await req('/api/match?id=draw-1','GET',undefined,b.token)).body;
  assert.equal(spec.managed,false);assert.equal('ownPending' in spec,false);assert.equal(spec.events.length,0);
  assert.equal((await req('/api/coach?id=draw-1','POST',{targetGame:2,tactics:{serve:'Balanced'}},b.token)).status,403);
  // Advance without any browser requests.
  await tick(1000000,1,11);await tick(1100000,2);await tick(2100000,2,11);await tick(2200000,3);
  const draw=(await req('/api/draw','GET',undefined,a.token)).body;
  const mine=draw.matches.find(m=>m.players.includes(draw.managedPlayer)&&m.status==='live');
  assert.ok(mine);
  const view=(await req('/api/match?id='+mine.id,'GET',undefined,a.token)).body;
  const patch={targetGame:view.nextCoachingGame,tactics:{serve:'Power serving'}};
  assert.equal((await req('/api/coach?id='+mine.id,'POST',patch,a.token,'https://untrusted.invalid')).status,403);
  const cmd=await req('/api/coach?id='+mine.id,'POST',patch,a.token);assert.equal(cmd.status,200);assert.equal(cmd.body.ownPending.serve,'Power serving');
  assert.equal((await req('/api/logout','POST',{},a.token)).status,200);assert.equal((await req('/api/draw','GET',undefined,a.token)).status,403);
  await tick(3200000,3,11);await tick(3300000,4);await tick(4300000,4,11);
  const again=(await req('/api/login','POST',{email:'admin@example.invalid',password:'admin-pass'})).body;
  const final=(await req('/api/draw','GET',undefined,again.token)).body;assert.equal(final.phase,'completed');assert.equal(final.results.length,6);assert.equal(final.career.transactions.length,1);
  assert.equal((await open('http-ci').read()).state.ledger.transactions.length,2);
  assert.equal('source' in final,false);assert.equal('anchor' in final,false);
 }finally{await new Promise(r=>server.close(r));}
 console.log('PASS PostgreSQL browser gateway, read-only polling, authenticated coaching, session revocation and offline completion');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
