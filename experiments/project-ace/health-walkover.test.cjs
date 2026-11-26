'use strict';
const assert=require('node:assert/strict'),{decide}=require('./health-walkover.cjs'),w=require('./world-worker.cjs'),c=require('./world-clock.cjs'),{demo}=require('./tournament-http.cjs');
const injury=(day,status='active')=>({status,tournamentReturnDay:day,fullRecoveryDay:day+2});
const support=(a=[],b=[])=>({p0:{injuries:a},p2:{injuries:b}});
assert.equal(decide(['p0','p2'],support(),0),null);
assert.equal(decide(['p0','p2'],support([injury(2)]),2),null);
assert.equal(decide(['p0','p2'],support([injury(2,'recovered')]),0),null);
assert.equal(decide(['p0','p2'],support([injury(2,'recovering')]),1).winnerKey,'p2');
assert.equal(decide(['p0','p2'],support([], [injury(2)]),1).winnerKey,'p0');
assert.equal(decide(['p0','p2'],support([injury(3),injury(7)],[injury(4)]),1).winnerKey,'p0');
assert.equal(decide(['p0','p2'],support([injury(3)],[injury(3)]),1).winnerKey,'p0');
const p={id:'a',verified:true,isAdmin:true},q={id:'b',verified:true,synthetic:true},policy={enabled:true,adminId:'a',syntheticId:'b',multiplayerTest:true};
const raw=(ms,day,speed=60)=>({server_now:new Date(ms).toISOString(),game_total_seconds:c.slot(1,1,day,600),speed_multiplier:speed});
const config={competition:'medical-cup',series:'medical-cup',season:1,lastWeek:1,medicalWalkovers:true,slots:[{id:'draw-1',phase:'main_draw',week:1,day:1,minute:600,firstWeek:1,lastWeek:1,court:1}],rewards:[{stage_code:'winner',ranking_points:100,prize_money_usd:1000},{stage_code:'runner_up',ranking_points:60,prize_money_usd:500}]};
function create(injuries){
 const base=demo({pace:'fast',delaySeconds:5},0,33,null,true);
 const draw={...base,entrants:base.entrants.filter(x=>['p0','p2'].includes(x.id)),mainSlots:['p0','p2'],qualification:[],courts:['court-1']};
 return w.create({draw,config,support:injuries},p,policy,{...raw(0,1),game_total_seconds:c.slot(1,1,1,600)-300});
}
async function run(){
 const matchDay=Math.floor(c.slot(1,1,1,600)/c.DAY);
 const initial=create(support([injury(matchDay+1)]));
 const paused=w.tick(initial,raw(5000,1,0),p,policy);
 assert.equal(paused.draw.scheduler.receipts.length,0);
 const s=w.tick(paused,raw(5001,1),p,policy);
 assert.equal(s.draw.phase,'completed');assert.equal(s.draw.champion,'p2');assert.equal(s.admissions.length,0);
 const receipt=s.draw.scheduler.receipts[0];assert.equal(receipt.completionReason,'health_walkover');assert.equal(receipt.totalPoints,0);assert.equal(receipt.totalGames,0);assert.equal(receipt.startedAt,null);
 assert.deepEqual(s.draw.conditionEvents,[]);assert.deepEqual(s.draw.worldSupport.events,[]);assert.deepEqual(s.draw.roster,initial.draw.roster);
 assert.equal(s.completed[0].durationMinutes,0);assert.equal(s.ledger.results.length,2);assert.equal(s.ledger.transactions.length,2);
 assert.equal(s.ledger.results.find(x=>x.player==='p2').points,100);assert.equal(s.ledger.results.find(x=>x.player==='p0').prize,500);
 assert.equal(w.matchView(s,'draw-1',p,policy,5001).score,'W/O');assert.equal(w.matchView(s,'draw-1',q,policy,5001).winner,1);
 assert.equal(w.summary(s,p,policy,5001).career.healthNotices.length,1);assert.deepEqual(w.summary(s,q,policy,5001).career.healthNotices,[]);
 assert.throws(()=>w.command(s,'draw-1',p,policy,5001,'coach',2,{}),/Match not live/);
 const replay=w.tick(JSON.parse(JSON.stringify(s)),raw(5002,1),p,policy);assert.deepEqual(replay.draw.scheduler.receipts,s.draw.scheduler.receipts);assert.deepEqual(replay.ledger,s.ledger);assert.deepEqual(replay.draw.healthNotices,s.draw.healthNotices);
 const both=w.tick(create(support([injury(matchDay+2)],[injury(matchDay+1)])),raw(5000,1),p,policy);assert.equal(both.draw.champion,'p2');assert.equal(both.draw.healthNotices.length,2);assert.equal(both.draw.healthNotices.find(n=>n.playerId==='p2').advanced,true);
 const cleared=w.tick(create(support([injury(matchDay)])),raw(5000,1),p,policy);assert.equal(cleared.admissions.length,1);assert.equal(cleared.draw.scheduler.receipts.length,0);
 if(process.env.ACE_REVIEW_DB==='1'){
  const {open}=require('./postgres-store.cjs'),store=open('medical-walkover-ci');
  assert.equal(await store.save(-1,initial),0);assert.equal(await store.save(0,s),1);
  assert.deepEqual((await open('medical-walkover-ci').read()).state,s);
  const bad=JSON.parse(JSON.stringify(s));bad.draw.scheduler.receipts[0].winnerKey='p0';
  await assert.rejects(store.save(1,bad),/rejected/);
  assert.deepEqual((await store.read()).state,s);
  assert.equal(await store.save(1,replay),2);
  assert.equal((await store.read()).state.ledger.transactions.length,2);
 }
 console.log('PASS medical eligibility, return boundary, tie-break, zero-play walkover, advancement, prizes, private notices, replay and optional PostgreSQL restart');
}
run().catch(e=>{console.error(e);process.exitCode=1});
