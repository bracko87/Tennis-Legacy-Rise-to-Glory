'use strict';
const assert=require('node:assert/strict'),{open}=require('./postgres-store.cjs'),{createService,startLoop}=require('./postgres-service.cjs'),demo=require('./world-demo.cjs'),{demo:drawArgs}=require('./tournament-http.cjs'),c=require('./world-clock.cjs');
const p={id:'a',verified:true,isAdmin:true},q={id:'b',verified:true,synthetic:true},policy={enabled:true,adminId:'a',multiplayerTest:true,syntheticId:'b'};
async function run(){
 let ms=0,game=c.slot(1,1,1,600)-300,speed=60;
 const clock=()=>({server_now:new Date(ms).toISOString(),game_total_seconds:game,speed_multiplier:speed});
 const args=drawArgs({pace:'fast',delaySeconds:5,mode:'manual',peerMode:'manual'},0,33,null,true);
 const store=open('service-ci');
 assert.equal(await store.save(-1,demo.create(args,p,policy,0)),0);
 const create=()=>createService({store:open('service-ci'),principal:p,policy,clock,now:()=>ms});
 let worker=create();const other=create();
 const advance=async(t,day,hour=10,rate=60)=>{ms=t;game=c.slot(1,1+Math.floor((day-1)/7),(day-1)%7+1,hour*60);speed=rate;await worker.tick();};
 ms=5000;game=c.slot(1,1,1,600);speed=0;
 await Promise.all([worker.tick(),other.tick()]);assert.equal((await store.read()).state.admissions.length,0);
 ms=5001;speed=60;await Promise.all([worker.tick(),other.tick()]);
 assert.equal((await store.read()).state.admissions.length,2);
 assert.equal((await worker.summary(p)).matches.filter(x=>x.status==='live').length,2);
 await advance(1000000,1,11,0);assert.equal((await worker.summary(p)).results.length,2);
 worker=create();await advance(1100000,2);await advance(2100000,2,11);await advance(2200000,3);
 const admin=await worker.summary(p),peer=await worker.summary(q),mine=admin.matches.find(m=>m.players.includes('p0')&&m.status==='live'),theirs=peer.matches.find(m=>m.players.includes('p2')&&m.status==='live');
 assert.ok(mine&&theirs);
 const before=await store.read();
 await assert.rejects(worker.command(mine.id,q,'coach',2,{serve:'Power serving'}),/Not your match/);
 assert.deepEqual(await store.read(),before);
 const target=(await worker.match(mine.id,p)).nextCoachingGame;
 const coach=await worker.command(mine.id,p,'coach',target,{serve:'Power serving'});
 assert.equal(coach.ownPending.serve,'Power serving');
 const privateView=await other.match(mine.id,q);assert.equal(privateView.managed,false);assert.equal('ownPending' in privateView,false);
 const stale=await store.read();
 await assert.rejects(worker.command(mine.id,p,'coach',target+1,{serve:'Balanced'}),/Stale coaching/);
 assert.deepEqual(await store.read(),stale);
 // A conflicting command must fail exactly once, without retrying.
 let attempts=0;
 const rejected=createService({principal:p,policy,clock,now:()=>ms,store:{read:()=>store.read(),save:async()=>{attempts++;throw Object.assign(Error('conflict'),{code:'ACE_REVISION_CONFLICT'});}}});
 await assert.rejects(rejected.command(mine.id,p,'coach',target,{serve:'Balanced'}),/conflict/);assert.equal(attempts,1);
 assert.equal((await worker.match(mine.id,p)).ownPending.serve,'Power serving');
 await advance(3200000,3,11);await advance(3300000,4);await advance(4300000,4,11);
 const final=await worker.summary(p);assert.equal(final.phase,'completed');assert.equal(final.results.length,6);assert.equal(final.career.transactions.length,1);
 await advance(4400000,8);assert.ok((await other.summary(p)).career.results.every(r=>r.status==='published'));
 assert.equal((await store.read()).state.ledger.transactions.length,2);
 const done=await store.read();await Promise.all([worker.tick(),other.tick()]);assert.deepEqual(await store.read(),done);
 // Test a running background loop without overlapping ticks or unhandled rejections.
 let calls=0,active=0,peak=0,errors=0;
 const loop=startLoop({tick:async()=>{calls++;peak=Math.max(peak,++active);await new Promise(r=>setTimeout(r,20));active--;if(calls===1)throw Error('transient');}},{intervalMs:100,maxBackoffMs:200,onError:()=>errors++});
 await new Promise(r=>setTimeout(r,370));await loop.stop();const count=calls;await new Promise(r=>setTimeout(r,150));
 assert.ok(count>=2);assert.equal(peak,1);assert.equal(errors,1);assert.equal(calls,count);
 console.log('PASS database-backed worker service, concurrent ticks, fresh-state restart, private coaching, non-retried conflicts, settlement and bounded background loop');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
