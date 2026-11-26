'use strict';
const assert=require('node:assert/strict'),{open,connection,mutate}=require('./postgres-store.cjs');
const w=require('./world-worker.cjs'),demo=require('./world-demo.cjs'),{demo:drawArgs}=require('./tournament-http.cjs'),c=require('./world-clock.cjs');
const p={id:'a',verified:true,isAdmin:true},policy={enabled:true,adminId:'a'};
const raw=(ms,day,hour=10)=>({server_now:new Date(ms).toISOString(),game_total_seconds:c.slot(1,1,day,hour*60),speed_multiplier:60});
const clone=x=>JSON.parse(JSON.stringify(x));
async function run(){
 const db=connection(),store=open('world-ci',db),args=drawArgs({pace:'fast',delaySeconds:5},0,33);
 let expected=demo.create(args,p,policy,0);
 assert.equal(await store.read(),null);assert.equal(await store.save(-1,expected),0);
 assert.deepEqual((await store.read()).state,expected);
 const a=await store.read(),b=await open('world-ci').read();
 const one=w.tick(a.state,raw(5000,1),p,policy),two=w.tick(b.state,raw(5001,1),p,policy);
 const writes=await Promise.allSettled([store.save(a.revision,one),open('world-ci').save(b.revision,two)]);
 assert.equal(writes.filter(x=>x.status==='fulfilled').length,1);
 assert.equal(writes.find(x=>x.status==='rejected').reason.code,'ACE_REVISION_CONFLICT');
 const winner=(await store.read()).state;assert.deepEqual(winner,writes[0].status==='fulfilled'?one:two);
 for(const [ms,day,hour] of [[1000000,1,11],[1100000,2,10],[2100000,2,11],[2200000,3,10],[3200000,3,11],[3300000,4,10],[4300000,4,11],[4400000,8,10]]){
  // A fresh client on each iteration simulates process-independent restart.
  const current=open('world-ci');// reconstruct from persisted state
  const prior=await current.read();expected=w.tick(prior.state,raw(ms,day,hour),p,policy);
  const updated=await mutate(current,s=>w.tick(s,raw(ms,day,hour),p,policy));
  assert.deepEqual(updated.state,expected);assert.deepEqual((await current.read()).state,expected);
 }
 const done=await store.read();assert.equal(done.state.draw.phase,'completed');assert.equal(done.state.draw.scheduler.receipts.length,6);assert.equal(done.state.ledger.transactions.length,1);
 const invalid=clone(done.state);invalid.ledger.transactions[0].amount++;
 await assert.rejects(store.save(done.revision,invalid),/rejected/);
 assert.deepEqual(await store.read(),done);
 const invalidReceipt=clone(done.state);invalidReceipt.draw.scheduler.receipts[0].score='fake';
 await assert.rejects(store.save(done.revision,invalidReceipt),/rejected/);assert.deepEqual(await store.read(),done);
 const duplicate=clone(done.state);duplicate.ledger.transactions.push(duplicate.ledger.transactions[0]);
 await assert.rejects(store.save(done.revision,duplicate),/rejected/);assert.deepEqual(await store.read(),done);
 await assert.rejects(db.sql("DELETE FROM ace_review.receipts"),/rejected/);
 assert.deepEqual(await store.read(),done);
 assert.equal(await store.save(done.revision,done.state),done.revision+1);
 assert.equal((await store.read()).state.ledger.transactions.length,1);
 console.log('PASS real PostgreSQL world persistence, competing revisions, restart, rollback, append-only receipts and finance');
}
run().catch(e=>{console.error(e);process.exitCode=1});
