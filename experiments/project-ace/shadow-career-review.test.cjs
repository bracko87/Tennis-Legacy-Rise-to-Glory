'use strict';
const assert=require('node:assert/strict'),{freeze,simulate,digest}=require('./shadow-comparison.cjs'),{freezeCareer,project,review}=require('./shadow-career-review.cjs'),raw=require('./sample-legacy-snapshot.json');
const clone=x=>JSON.parse(JSON.stringify(x));
const snapshot=clone(raw);snapshot.match.round_label='Final';snapshot.match.world='WTA';
const input=freeze({match_id:'career-final',competition_id:'career-c',source_revision:4,snapshot,seed:24321});
const catalog=[{code:'fixture_strain',severity:'moderate',relative_weight:1,treatment_code:'rest',base_performance_penalty:.05,training_out_min_days:1,training_out_max_days:1,tournament_out_min_days:2,tournament_out_max_days:2,recovery_min_days:4,recovery_max_days:4,aggravation_risk:.1,is_active:true,contexts:['match']}];
const context=freezeCareer(input,{absolute_day:30,through_day:31,ranking_publish_absolute_day:37,injury_catalog:catalog,rewards:{winner:{ranking_points:250,prize_money_usd:10001},runner_up:{ranking_points:165,prize_money_usd:5000},qualified_bonus:13},players:input.player_ids.map((player_id,i)=>({player_id,career_revision:7,human:true,qualified:i===0,profile:Object.fromEntries(['fatigue','sharpness','morale','confidence','focus','fitness','stamina','recovery','movement'].map(k=>[k,snapshot.players[i].skills[k]])),staff:{matchFatigueReduction:.1},injuries:[],inventory:[{id:player_id+'-r',type:'racket',condition:21,wear_per_match:2}],loadout:{racket:player_id+'-r',shoes:null,apparel:null},finance:{opening_day:0,balance:1000,tax_rate_basis_points:1800,settled_periods:[],transactions:[{player_id,idempotency_key:'opening',amount:1000,game_absolute_day:0,is_taxable:false,balance_before:0,balance_after:1000}]}}))});
const ace=simulate(input),legacy={...clone(ace),schema:'ace-shadow-legacy-observation-v1',engine_version:'synthetic-control'};delete legacy.point_trace_sha256;
legacy.winner_id=input.player_ids.find(x=>x!==ace.winner_id);legacy.sets=legacy.sets.map(s=>({games:[...s.games].reverse(),tiebreak:s.tiebreak?[...s.tiebreak].reverse():null}));legacy.stats.reverse();
const expected=project(input,legacy,context);
const observed={schema:'ace-shadow-career-observation-v1',input_sha256:input.input_sha256,context_sha256:context.context_sha256,legacy_observation_sha256:digest(legacy),players:clone(expected.players)};
const before=JSON.stringify([input,legacy,context,observed]),r=review(input,legacy,context,observed);
assert.equal(r.status,'matched_review');assert.equal(r.winner_agreement,false);assert.ok(r.outcome_differences.length>0);assert.deepEqual(r.processing_differences,[]);assert.equal(r.production_ready,false);
for(const p of expected.players){assert.equal(p.career_revision,8);assert.equal(p.equipment[0].condition,19);assert.ok(p.condition.fatigue>10);const prize=p.won?10001:5000;assert.equal(p.finance.closing_balance,1000+prize-Math.round(prize*.18));assert.equal(p.finance.tax_transactions.length,1);assert.equal(p.ranking.ranking_points,(p.won?250:165)+(p.player_id===input.player_ids[0]?13:0));}
assert.deepEqual(review(input,legacy,context,observed),r);assert.equal(JSON.stringify([input,legacy,context,observed]),before);
const bad=clone(observed);bad.players[0].finance.closing_balance++;const diff=review(input,legacy,context,bad);assert.equal(diff.status,'processing_difference_review');assert.deepEqual(diff.processing_differences.map(x=>x.path),['/0/finance/closing_balance']);
const wrong=clone(observed);wrong.players.reverse();assert.throws(()=>review(input,legacy,context,wrong),/identity/);
const altered=clone(context);altered.context.players[0].profile.fatigue++;assert.throws(()=>review(input,legacy,altered,observed),/profile/);
const balance=clone(context.context);balance.players[0].finance.balance++;assert.throws(()=>freezeCareer(input,balance),/balance/);
console.log('PASS same-outcome career replay, distinct engine outcomes, wear, source-ID injury roll, prize, monthly tax, qualified bonus and observation drift detection');

const later=clone(context.context);later.absolute_day=365;later.through_day=366;later.ranking_publish_absolute_day=370;
for(const p of later.players){
 const f=p.finance,player_id=p.player_id;
 f.transactions.push({player_id,idempotency_key:'prior-prize',amount:1000,game_absolute_day:5,is_taxable:true,balance_before:1000,balance_after:2000});
 f.transactions.push({player_id,idempotency_key:'monthly-tax:1:1',amount:-100,game_absolute_day:31,is_taxable:false,balance_before:2000,balance_after:1900});
 f.balance=1900;
 const {monthStart}=require('./career-processing-review.cjs');
 f.settled_periods=Array.from({length:11},(_,i)=>({player_id,season:1,month:i+1,taxable_income:i===0?1000:0,tax_amount:i===0?100:0,tax_rate:.10,due_absolute_day:monthStart(1,i+2),settled_absolute_day:monthStart(1,i+2),transaction_key:i===0?'monthly-tax:1:1':null}));
}
const laterContext=freezeCareer(input,later),laterResult=project(input,legacy,laterContext);
for(const p of laterResult.players){assert.equal(p.finance.tax_periods.length,1);assert.equal(p.finance.tax_periods[0].month,12);assert.equal(p.finance.tax_transactions[0].game_absolute_day,366);assert.equal(p.finance.closing_balance,1900+p.finance.prize_transactions[0].amount+p.finance.tax_transactions[0].amount);}
const badTax=clone(later);badTax.players[0].finance.settled_periods[0].tax_amount++;assert.throws(()=>freezeCareer(input,badTax),/amount mismatch/);
const hole=clone(later);hole.players[0].finance.settled_periods.splice(1,1);assert.throws(()=>freezeCareer(input,hole),/Missing earlier/);
const unlinked=clone(later);unlinked.players[0].finance.settled_periods=[];assert.throws(()=>freezeCareer(input,unlinked),/Unlinked/);
console.log('PASS historical tax reconciliation, changed rates, prior zero periods, missing receipts and season rollover without duplicate charges');

for(const [label,stage] of [['Round of 128','round_128'],['Round of 64','round_64'],['Round of 32','round_32'],['Round of 16','round_16'],['Quarterfinal','quarterfinal'],['Semifinal','semifinal']]){
 const snap=clone(snapshot);snap.match.round_label=label;
 const i=freeze({match_id:'career-'+stage,competition_id:'career-c',source_revision:4,snapshot:snap,seed:24321});
 const cx=clone(context.context);cx.rewards[stage]={ranking_points:42,prize_money_usd:2000};
 const frozen=freezeCareer(i,cx),res=simulate(i),out=project(i,res,frozen);
 const winner=out.players.find(p=>p.won),loser=out.players.find(p=>!p.won);
 assert.equal(winner.ranking,null);assert.equal(winner.finance.prize_transactions.length,0);
 assert.equal(loser.ranking.stage,stage);assert.equal(loser.ranking.ranking_points,42+(loser.player_id===i.player_ids[0]?13:0));
 assert.equal(loser.finance.prize_transactions[0].amount,2000);
 assert.equal(loser.finance.prize_transactions[0].idempotency_key,'tournament-prize:career-c:'+loser.player_id);
 assert.equal(loser.finance.closing_balance,2640);
 assert.ok(winner.condition.fatigue>10);
 const missing=clone(cx);delete missing.rewards[stage];assert.throws(()=>freezeCareer(i,missing),/reward rules/);
}
console.log('PASS six main draw elimination stages, advancing winner no prize or ranking, qualified bonus, tax and missing rules rejection');

for(const [round,total,label,stage] of [[1,3,'Qualifying Round 1','qualifying_round_1_loss'],[2,3,'Qualification Round 2','qualifying_round_2_loss'],[3,3,'Qualifying Final','qualifying_final_loss']]){
 const snap=clone(snapshot);snap.match.draw_type='qualification';snap.match.round_label=label;
 const i=freeze({match_id:'qual-'+round,competition_id:'career-c',source_revision:4,snapshot:snap,seed:24321});
 const cx=clone(context.context);cx.qualification={round,total_rounds:total};cx.rewards[stage]={ranking_points:8,prize_money_usd:400};cx.players.forEach(p=>p.qualified=false);
 const frozen=freezeCareer(i,cx),res=simulate(i),out=project(i,res,frozen);
 const winner=out.players.find(p=>p.won),loser=out.players.find(p=>!p.won);
 assert.equal(winner.ranking,null);assert.equal(winner.finance.prize_transactions.length,0);
 assert.equal(winner.qualified_for_main_draw,round===total);assert.equal(loser.qualified_for_main_draw,false);
 assert.equal(loser.ranking.stage,stage);assert.equal(loser.ranking.qualifying_bonus_points,0);assert.equal(loser.ranking.ranking_points,8);
 assert.equal(loser.finance.prize_transactions[0].amount,400);
 const bad=clone(cx);bad.players[0].qualified=true;assert.throws(()=>freezeCareer(i,bad),/already be qualified/);
 const absent=clone(cx);delete absent.qualification;assert.throws(()=>freezeCareer(i,absent),/bracket evidence/);
}
console.log('PASS qualification elimination rewards, final advancement, no premature prize or bonus, explicit bracket evidence and invalid qualification rejection');
