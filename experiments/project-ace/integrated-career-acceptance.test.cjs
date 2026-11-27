'use strict';
// Sequential synthetic career acceptance across qualification, main draw, tax and ranking.
const assert=require('node:assert/strict'),{freeze,simulate}=require('./shadow-comparison.cjs'),{freezeCareer,project}=require('./shadow-career-review.cjs'),{reconcile}=require('./ranking-defence-review.cjs'),raw=require('./sample-legacy-snapshot.json');
const clone=x=>JSON.parse(JSON.stringify(x));
const catalog=[{code:'fixture_strain',severity:'moderate',relative_weight:1,treatment_code:'rest',base_performance_penalty:.05,training_out_min_days:1,training_out_max_days:1,tournament_out_min_days:1,tournament_out_max_days:1,recovery_min_days:1,recovery_max_days:1,aggravation_risk:.1,is_active:true,contexts:['match']}];
const fields=['fatigue','sharpness','morale','confidence','focus','fitness','stamina','recovery','movement'];
const rewards={qualifying_final_loss:{ranking_points:8,prize_money_usd:400},semifinal:{ranking_points:90,prize_money_usd:2000},winner:{ranking_points:250,prize_money_usd:10000},runner_up:{ranking_points:165,prize_money_usd:5000},qualified_bonus:13};
const players=new Map();
function add(rawPlayer,id){
 const x=clone(rawPlayer);x.player.id=id;x.skills.player_id=id;
 players.set(id,{raw:x,player_id:id,career_revision:0,human:true,qualified:false,profile:Object.fromEntries(fields.map(k=>[k,x.skills[k]])),staff:{matchFatigueReduction:.1},injuries:[],inventory:[{id:id+'-r',type:'racket',condition:30,wear_per_match:2}],loadout:{racket:id+'-r',shoes:null,apparel:null},finance:{opening_day:0,balance:1000,tax_rate_basis_points:1800,settled_periods:[],transactions:[{player_id:id,idempotency_key:'opening',amount:1000,game_absolute_day:0,is_taxable:false,balance_before:0,balance_after:1000}]}});
}
['p','q','r','s'].forEach((id,i)=>add(raw.players[i%2],id));
let competition='integrated-cup',publish=37;const results=[],seen=new Set();
function play(id,ids,label,day,through,qualification=null){
 assert.ok(!seen.has(id));seen.add(id);
 const snapshot=clone(raw);snapshot.match.world='WTA';snapshot.match.draw_type=qualification?'qualification':'main_draw';snapshot.match.round_label=label;
 snapshot.players=ids.map(id=>{const p=players.get(id),x=clone(p.raw);Object.assign(x.skills,p.profile);return x;});
 const input=freeze({match_id:id,competition_id:competition,source_revision:0,snapshot,seed:24321+seen.size});
 const cx=freezeCareer(input,{absolute_day:day,through_day:through,ranking_publish_absolute_day:publish,injury_catalog:catalog,rewards,players:ids.map(id=>{const {raw,...p}=players.get(id);return p;}),...(qualification?{qualification}:{})});
 const res=simulate(input),out=project(input,res,cx);
 assert.deepEqual(project(input,res,cx),out);
 for(const x of out.players){
  const p=players.get(x.player_id);assert.equal(x.career_revision,p.career_revision+1);assert.ok(x.equipment[0].condition<p.inventory[0].condition);
  p.career_revision=x.career_revision;p.profile={...p.profile,...x.condition};p.inventory=x.equipment;p.loadout=x.loadout;
  if(x.injury_recovery)p.injuries.push({status:x.injury_recovery.status,tournamentReturnDay:x.injury_recovery.tournament_return_absolute_day,fullRecoveryDay:x.injury_recovery.expected_full_recovery_absolute_day});
  if(x.qualified_for_main_draw)p.qualified=true;
  const f=p.finance;f.transactions.push(...x.finance.prize_transactions,...x.finance.tax_transactions);f.settled_periods.push(...x.finance.tax_periods);f.balance=x.finance.closing_balance;
  if(x.ranking){assert.ok(!results.some(r=>r.player===x.player_id&&r.competition===competition));results.push({id:'result-'+competition+'-'+x.player_id,competition,player:x.player_id,points:x.ranking.ranking_points,publish_day:publish,status:'pending'});}
 }
 return out.players.find(p=>p.won).player_id;
}
const qualifier=play('qual',['p','q'],'Qualifying Final',20,21,{round:1,total_rounds:1});
const finalist=play('semi',[qualifier,'r'],'Semifinal',24,25);
const champion=play('final',[finalist,'s'],'Final',30,31);
assert.equal(results.length,4);
for(const p of players.values()){
 const prizes=p.finance.transactions.filter(t=>t.idempotency_key.startsWith('tournament-prize:'));assert.equal(prizes.length,1);
 assert.equal(p.finance.balance,p.finance.transactions.reduce((n,t)=>n+t.amount,0));
 const result=results.find(r=>r.player===p.player_id);
 assert.ok(result);assert.equal(p.finance.transactions.filter(t=>t.idempotency_key==='monthly-tax:1:1').length,p.player_id===finalist||p.player_id==='s'?1:0);
 assert.equal(p.qualified,p.player_id===qualifier);
}
const state={editions:[{competition,series:'integrated-series',world:'WTA',season:1,publish_day:publish,status:'completed'}],results,contributions:[],cycles:[],last_day:null};
const pre=reconcile(state,36);assert.equal(pre.state.contributions.length,0);
const ranked=reconcile(pre.state,37);assert.equal(ranked.state.contributions.length,4);assert.equal(ranked.totals[JSON.stringify(['WTA',champion])],250+(champion===qualifier?13:0));
assert.deepEqual(reconcile(ranked.state,37).state,ranked.state);
console.log('PASS sequential qualification, semifinal and final career state carryover, unique gross prizes, monthly tax and ranking publication');

const {taxReview,monthStart,recoveryReview}=require('./career-processing-review.cjs'),{verifySettled}=require('./historical-tax-review.cjs'),{dayOff,eligibility}=require('./career-support.cjs');
function settleAll(day){
 for(const p of players.values()){
  const f=p.finance,plan=taxReview({...f,player_id:p.player_id,human:true,through_day:day});
  f.transactions.push(...plan.transactions);f.settled_periods.push(...plan.periods);f.balance=plan.balance;
  verifySettled(p.player_id,f,day);
  assert.equal(f.balance,f.transactions.reduce((n,t)=>n+t.amount,0));
  assert.equal(taxReview({...f,player_id:p.player_id,human:true,through_day:day}).transactions.length,0);
 }
}
settleAll(31);
for(const p of players.values())assert.equal(p.finance.transactions.filter(t=>t.idempotency_key==='monthly-tax:1:1').length,1);
settleAll(366);
for(const p of players.values()){
 assert.equal(p.finance.settled_periods.length,12);
 assert.equal(p.finance.settled_periods.at(-1).due_absolute_day,366);
 p.qualified=false;
 const before=p.profile;
 p.profile=dayOff(before,p.staff);
 assert.ok(p.profile.fatigue<=before.fatigue);
 for(const k of ['fitness','stamina','recovery','movement'])assert.equal(p.profile[k],before[k]);
 p.injuries=p.injuries.map(i=>i.fullRecoveryDay<=366?{...i,status:'recovered'}:i);
 assert.equal(eligibility(p.injuries,366).eligible,true);
}
const injury={status:'active',onset_absolute_day:365,expected_full_recovery_absolute_day:368};
assert.equal(recoveryReview(injury,366).status,'recovering');
assert.equal(recoveryReview(injury,368).status,'recovered');
assert.equal(eligibility([{status:'active',tournamentReturnDay:368,fullRecoveryDay:369}],366).eligible,false);
assert.equal(eligibility([{status:'recovering',tournamentReturnDay:368,fullRecoveryDay:369}],368).eligible,true);
competition='integrated-cup-season2';publish=375;
const nextChampion=play('final-season2',[champion,players.get(champion).player_id==='s'?'r':'s'],'Final',370,371);
const next=clone(ranked.state);next.editions.push({competition,series:'integrated-series',world:'WTA',season:2,publish_day:publish,status:'completed'});next.results.push(...results.filter(r=>r.competition===competition));
const defended=reconcile(next,375);
assert.equal(defended.state.contributions.filter(c=>c.active).length,2);
assert.equal(defended.totals[JSON.stringify(['WTA',nextChampion])],250);
assert.equal(defended.state.contributions.filter(c=>c.season===1&&c.active).length,0);
for(const p of players.values())assert.equal(p.finance.transactions.filter(t=>t.idempotency_key==='monthly-tax:1:1').length,1);
settleAll(monthStart(2,2));
console.log('PASS all-player month settlement, twelve historical periods, recovery eligibility, season rollover and next-edition ranking defence');
