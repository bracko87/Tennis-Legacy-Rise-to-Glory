'use strict';
const assert=require('node:assert/strict'),{taxReview,injuryReview,recoveryReview,random,monthStart,periodOf}=require('./career-processing-review.cjs'),{connection}=require('./postgres-store.cjs'),{reordered}=require('./official-review.test.cjs');
async function run(){
 const db=connection(),player_id='source-p0',prize=reordered.transactions[0];
 const tx=(id,amount,day,taxable)=>({player_id,idempotency_key:id,amount,game_absolute_day:day,is_taxable:taxable});
 const input={player_id,human:true,opening_day:0,through_day:60,balance:100,tax_rate_basis_points:1800,transactions:[tx('opening',1500,0,false),tx(prize.idempotency_key,prize.amount,5,true),tx('sponsor',503,10,true),tx('travel',-200,11,false),tx('non-taxable',700,12,false)],settled_periods:[]};
 const plan=taxReview(input),expected=Number(await db.sql('SELECT round(('+prize.amount+'+503)::numeric*0.18)::bigint;'));
 assert.equal(plan.periods.length,2);assert.equal(plan.periods[0].tax_amount,expected);assert.equal(plan.periods[1].tax_amount,0);assert.equal(plan.transactions.length,1);assert.equal(plan.transactions[0].idempotency_key,'monthly-tax:1:1');assert.equal(plan.balance,100-expected);assert.ok(plan.balance<0);
 const replay=taxReview({...input,balance:plan.balance,transactions:[...input.transactions,...plan.transactions],settled_periods:plan.periods});assert.equal(replay.transactions.length,0);assert.equal(replay.periods.length,0);
 assert.throws(()=>taxReview({...input,transactions:[...input.transactions,...plan.transactions]}),/without settled period/);
 assert.equal(monthStart(1,3),60);assert.equal(monthStart(2,1),366);assert.deepEqual(periodOf(365),{season:1,month:12});
 const december=taxReview({...input,opening_day:335,through_day:366,transactions:[tx('open-dec',100,335,false),tx('dec-prize',1001,365,true)]});assert.equal(december.periods[0].due_absolute_day,366);assert.equal(december.transactions[0].amount,-180);
 // Two exact catalogue rows from checked-in injury migration, not the complete live catalogue.
 const row=(code,severity,weight,treatment,penalty,train,tour,rec,aggravation)=>({code,severity,relative_weight:weight,treatment_code:treatment,base_performance_penalty:penalty,training_out_min_days:train[0],training_out_max_days:train[1],tournament_out_min_days:tour[0],tournament_out_max_days:tour[1],recovery_min_days:rec[0],recovery_max_days:rec[1],aggravation_risk:aggravation,is_active:true,contexts:['match']});
 const catalog=[row('shoulder_tightness','minor',1.25,'rest_ice',.025,[0,1],[0,0],[2,4],.08),row('shoulder_strain','moderate',.75,'upper_body_rehab',.065,[2,5],[1,4],[6,11],.16)];
 let match_id;for(let i=0;i<10000;i++){if(random(player_id+':match:m'+i+':injury',1)*100<7.5){match_id='m'+i;break;}}assert.ok(match_id);
 const seed=player_id+':match:'+match_id+':injury';
 const sqlRandom=Number(await db.sql("SELECT (('x'||substr(md5('"+seed+":1'),1,8))::bit(32)::bigint)::double precision/4294967296.0;"));assert.equal(random(seed,1),sqlRandom);
 const args={player_id,match_id,absolute_day:5,risk_percent:7.5,catalog};
 const injury=injuryReview(args);assert.equal(injury.status,'injured');assert.equal(injuryReview({...args,prior_rolls:[injury.result]}).status,'already_processed');
 assert.throws(()=>injuryReview({...args,risk_percent:0,prior_rolls:[injury.result]}),/Conflicting/);
 const recovered=recoveryReview(injury.result.injury,injury.result.injury.expected_full_recovery_absolute_day);assert.equal(recovered.status,'recovered');assert.equal(recovered.progress_percent,100);
 const clear=injuryReview({...args,risk_percent:0});assert.equal(clear.status,'clear');assert.equal(injuryReview({...args,risk_percent:0,prior_rolls:[clear.result]}).status,'already_processed');
 assert.throws(()=>injuryReview({...args,catalog:[]}),/catalogue/);
 console.log('PASS monthly taxable income, exact rounding, December rollover, debt, tax replay, SQL-compatible injury random, injury replay and recovery review');
}
run().catch(e=>{console.error(e);process.exitCode=1});
