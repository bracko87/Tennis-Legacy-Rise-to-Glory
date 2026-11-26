'use strict';
const assert=require('node:assert/strict'),http=require('node:http'),{createAuth}=require('./local-supabase-review-auth.cjs'),{handler}=require('./app-review-http.cjs'),{open}=require('./postgres-store.cjs'),{createService}=require('./postgres-service.cjs'),world=require('./world-demo.cjs'),{demo}=require('./tournament-http.cjs'),c=require('./world-clock.cjs');
async function run(){
 const uid='11111111-1111-4111-8111-111111111111',token='Bearer a.b.c',appOrigin='http://127.0.0.1:8000';let admin=true,ms=0,game=c.slot(1,1,1,600)-300;
 const auth=createAuth({url:'http://127.0.0.1:54321',key:'test-publishable',userId:uid,fetcher:async(u)=>({ok:true,json:async()=>u.endsWith('/user')?{id:uid,is_anonymous:false}:admin})});
 const store=open('app-coach-ci'),p={id:uid,verified:true,isAdmin:true},clock=()=>({server_now:new Date(ms).toISOString(),game_total_seconds:game,speed_multiplier:60});
 await store.save(-1,world.create(demo({delaySeconds:5,pace:'fast',mode:'manual'},0,33),p,auth.policy,0));
 const worker=createService({store,principal:p,policy:auth.policy,now:()=>ms,clock});
 const server=http.createServer();await new Promise(r=>server.listen(0,'127.0.0.1',r));const port=server.address().port;
 server.on('request',handler({auth,store,port,appOrigin,coaching:true,now:()=>ms,clock}));
 const req=async(route,method='GET',body,origin=appOrigin,authorization=token)=>{const r=await fetch('http://127.0.0.1:'+port+route,{method,headers:{Origin:origin,Authorization:authorization,...(body===undefined?{}:{'Content-Type':'application/json'})},body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,body:await r.json()};};
 const tick=async(t,day,hour=10)=>{ms=t;game=c.slot(1,1,day,hour*60);await worker.tick();};
 try{
  await tick(5000,1);
  const before=await store.read();
  assert.equal((await req('/api/coach?id=draw-1','POST',{targetGame:2,tactics:{serve:'Power serving'}})).status,403);
  assert.deepEqual(await store.read(),before);
  await tick(1000000,1,11);await tick(1100000,2);await tick(2100000,2,11);await tick(2200000,3);
  const d=(await req('/api/draw')).body,mine=d.matches.find(m=>m.players.includes(d.managedPlayer)&&m.status==='live');assert.ok(mine);assert.equal(d.coachingEnabled,true);
  const id=mine.id,route='/api/coach?id='+id,view=(await req('/api/match?id='+id)).body,target=view.nextCoachingGame,patch={targetGame:target,tactics:{serve:'Power serving'}};
  const prior=await store.read();
  assert.equal((await req(route,'POST',patch,'https://untrusted.invalid')).status,403);
  assert.equal((await req(route,'POST',{...patch,playerId:'other'})).status,400);
  assert.equal((await req(route,'POST',{targetGame:target,tactics:{constructor:'x'}})).status,400);
  admin=false;assert.equal((await req(route,'POST',patch)).status,403);admin=true;
  assert.deepEqual(await store.read(),prior);
  const cmd=await req(route,'POST',patch);assert.equal(cmd.status,200);assert.equal(cmd.body.ownPending.serve,'Power serving');
  const saved=await store.read();assert.equal(saved.revision,cmd.body.revision);assert.ok(Number.isInteger(cmd.body.matchRevision));assert.equal((await req('/api/match?id='+id)).body.revision,saved.revision);
  const stale=await req(route,'POST',{targetGame:target+1,tactics:{serve:'Balanced'}});assert.equal(stale.status,409);assert.deepEqual(await store.read(),saved);
  const job=saved.state.draw.scheduler.jobs.find(j=>j.id===id);ms=job.fixture.active.endAt+5000;await worker.tick();
  const applied=(await req('/api/match?id='+id)).body;assert.equal(applied.activeTactics.serve,'Power serving');
  await tick(3200000,3,11);await tick(3300000,4);await tick(4300000,4,11);
  assert.equal((await req('/api/draw')).body.phase,'completed');assert.equal((await store.read()).state.ledger.transactions.length,1);
 }finally{await new Promise(r=>server.close(r));}
 console.log('PASS actual app coaching gateway, admin and ownership checks, next-game activation, stale rejection and committed results');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
