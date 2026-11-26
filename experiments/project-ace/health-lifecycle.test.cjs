'use strict';
const assert=require('node:assert/strict'),w=require('./world-worker.cjs'),c=require('./world-clock.cjs'),{demo}=require('./tournament-http.cjs'),{random}=require('./career-processing-review.cjs'),h=require('./health-lifecycle.cjs'),{decide}=require('./health-walkover.cjs');
const p={id:'a',verified:true,isAdmin:true},q={id:'b',verified:true,synthetic:true},policy={enabled:true,adminId:'a',syntheticId:'b',multiplayerTest:true};
const catalog=[{code:'fixture_strain',severity:'moderate',relative_weight:1,treatment_code:'rest',base_performance_penalty:.05,training_out_min_days:1,training_out_max_days:1,tournament_out_min_days:2,tournament_out_max_days:2,recovery_min_days:4,recovery_max_days:4,aggravation_risk:.1,is_active:true,contexts:['match']}];
const day=Math.floor(c.slot(1,1,1,600)/c.DAY);
let competition;for(let i=0;i<100000;i++){const k='health-'+i,m=JSON.stringify([k,'draw-1']);if(random('p0:match:'+m+':injury',1)*100<.03&&random('p2:match:'+m+':injury',1)*100>7.5){competition=k;break;}}
assert.ok(competition);
const raw=(ms,d,hour=10)=>({server_now:new Date(ms).toISOString(),game_total_seconds:d*c.DAY+hour*3600,speed_multiplier:60});
function make(support={p0:{injuries:[]},p2:{injuries:[]}}){
 const b=demo({pace:'fast',delaySeconds:5},0,33,null,true);
 return w.create({draw:{...b,entrants:b.entrants.filter(x=>['p0','p2'].includes(x.id)),mainSlots:['p0','p2'],qualification:[],courts:['court-1']},config:{competition,series:'health-cup',season:1,lastWeek:1,medicalWalkovers:true,autoHealth:{catalog},slots:[{id:'draw-1',phase:'main_draw',week:1,day:1,minute:600,firstWeek:1,lastWeek:1,court:1}],rewards:[{stage_code:'winner',ranking_points:100,prize_money_usd:1000},{stage_code:'runner_up',ranking_points:60,prize_money_usd:500}]},support},p,policy,{...raw(0,day),game_total_seconds:c.slot(1,1,1,600)-300});
}
async function run(){
 assert.throws(()=>make({p0:{injuries:[]}}),/every entrant/);
 const initial=make(),live=w.tick(initial,raw(5000,day),p,policy),done=w.tick(live,raw(1000000,day,11),p,policy);
 assert.equal(done.draw.phase,'completed');
 const lifecycle=done.draw.worldSupport.health;assert.equal(lifecycle.rolls.length,2);
 assert.equal(lifecycle.rolls.find(x=>x.player_id==='p0').status,'injured');
 assert.equal(lifecycle.rolls.find(x=>x.player_id==='p2').status,'clear');
 const injury=done.draw.worldSupport.players.p0.injuries[0];assert.equal(injury.tournamentReturnDay,day+2);
 assert.equal(decide(['p0','p2'],done.draw.worldSupport.players,day+1).winnerKey,'p2');
 assert.equal(decide(['p0','p2'],done.draw.worldSupport.players,day+2),null);
 const again=w.tick(done,raw(1000001,day,11),p,policy);assert.deepEqual(again.draw.worldSupport.health,lifecycle);
 const later=w.tick(again,raw(1100000,day+4),p,policy);
 assert.equal(later.draw.worldSupport.players.p0.injuries[0].status,'recovered');
 assert.equal(later.draw.worldSupport.players.p0.injuries[0].progressPercent,100);
 assert.deepEqual(w.summary(later,p,policy,1100000).career.healthNotices.map(n=>n.code),['injury_detected','training_clear','competition_clear','fully_recovered']);
 assert.deepEqual(w.summary(later,q,policy,1100000).career.healthNotices,[]);
 assert.deepEqual(w.summary(later,q,policy,1100000).career.healthRecords,[]);
 const replay=w.tick(JSON.parse(JSON.stringify(later)),raw(1100001,day+4),p,policy);assert.deepEqual(replay.draw.healthNotices,later.draw.healthNotices);
 const illness={key:'flu1',kind:'illness',status:'active',onsetDay:day-1,trainingReturnDay:day+1,tournamentReturnDay:day+2,fullRecoveryDay:day+3};
 const blocked=w.tick(make({p0:{injuries:[illness]},p2:{injuries:[]}}),raw(5000,day),p,policy);
 assert.equal(blocked.draw.scheduler.receipts[0].completionReason,'health_walkover');assert.equal(blocked.draw.worldSupport.health.rolls.length,0);
 const recovered=w.tick(blocked,raw(1000000,day+3),p,policy);assert.equal(recovered.draw.worldSupport.players.p0.injuries[0].status,'recovered');
 if(process.env.ACE_REVIEW_DB==='1'){
  const {open}=require('./postgres-store.cjs'),store=open('health-lifecycle-ci');
  assert.equal(await store.save(-1,done),0);assert.deepEqual((await store.read()).state,done);
  assert.equal(await store.save(0,later),1);assert.deepEqual((await store.read()).state,later);
  assert.equal(await store.save(1,replay),2);
 }
 console.log('PASS automatic match injury and clear rolls, imported illness, medical walkover, clearance boundaries, skipped-day recovery, private notices and replay');
}
run().catch(e=>{console.error(e);process.exitCode=1});
