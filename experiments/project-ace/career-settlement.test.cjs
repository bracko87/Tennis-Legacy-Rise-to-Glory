'use strict';
const assert=require('node:assert/strict'),bridge=require('./official-review.cjs'),w=require('./world-worker.cjs'),c=require('./world-clock.cjs'),{career}=require('./career-settlement-review.cjs'),{project}=require('./official-settlement-review.cjs'),{snapshot,options}=require('./official-review.test.cjs'),{connection}=require('./postgres-store.cjs'),health=require('./health-lifecycle.cjs');
const p={id:'a',verified:true,isAdmin:true},policy={enabled:true,adminId:'a'},id='career-review-ci';
const clone=x=>JSON.parse(JSON.stringify(x)),raw=(ms,day,hour=10)=>({server_now:new Date(ms).toISOString(),game_total_seconds:day*c.DAY+hour*3600,speed_multiplier:60});
const lit=x=>x===null?'NULL':"convert_from(decode('"+Buffer.from(String(x)).toString('base64')+"','base64'),'UTF8')";
async function run(){
 const x=clone(snapshot);x.competition.id=id;x.match_slots.forEach((m,i)=>{m.id=id+'-m'+i;m.competition_id=id;});
 const catalog=[{code:'fixture_strain',severity:'moderate',relative_weight:1,treatment_code:'rest',base_performance_penalty:.05,training_out_min_days:1,training_out_max_days:1,tournament_out_min_days:2,tournament_out_max_days:2,recovery_min_days:4,recovery_max_days:4,aggravation_risk:.1,is_active:true,contexts:['match']}];
 let s=bridge.create(x,p,policy,raw(0,2,9),options);s.config.medicalWalkovers=true;s.config.autoHealth={catalog};
 for(const row of s.draw.roster)if(!s.draw.worldSupport.players[row.id])s.draw.worldSupport.players[row.id]={staff:{},injuries:[]};
 health.init(s.draw,s.config,2);
 s=w.tick(s,raw(5000,2),p,policy);s=w.tick(s,raw(1000000,2,11),p,policy);s=w.tick(s,raw(1100000,3),p,policy);s=w.tick(s,raw(2100000,3,11),p,policy);s=w.tick(s,raw(2200000,31),p,policy);
 assert.equal(s.draw.phase,'completed');
 const map=(rows,key)=>rows.find(x=>x.local===key).source;
 const officialMatches=s.draw.matches.map(m=>({match_id:map(s.source.matches,m.id),competition_id:id,player1_id:map(s.source.players,m.players[0]),player2_id:map(s.source.players,m.players[1]),status:'scheduled'}));
 const settlement=project(s,{officialMatches}),prize=settlement.transactions[0];
 const finance=[{player_id:prize.player_id,balance:1500,opening_day:0,tax_rate_basis_points:1800,transactions:[{player_id:prize.player_id,idempotency_key:'opening',amount:1500,is_taxable:false,game_absolute_day:0}],settled_periods:[]}];
 const args={officialMatches,finance,catalog,throughDay:31,prizeDays:{[prize.idempotency_key]:3}};
 const review=career(s,args),tax=Math.round(prize.amount*.18);
 assert.equal(review.accounts[0].balance_after_tax,1500+prize.amount-tax);assert.equal(review.taxes[0].transactions[0].amount,-tax);assert.equal(review.injury_rolls.length,settlement.matches.filter(m=>m.completion_reason!=='health_walkover').length*2);
 assert.deepEqual(career(s,args),review);assert.throws(()=>career(s,{...args,finance:[]}),/Complete human/);
 const bad=clone(s);bad.draw.worldSupport.health.rolls[0].roll=999;assert.throws(()=>career(bad,args),/Injury roll mismatch/);
 const db=connection(),stage=x=>db.sql('SELECT ace_review.stage_career('+lit(JSON.stringify(x))+'::jsonb);');
 await assert.rejects(stage(review),/rejected/);
 await db.sql('SELECT ace_review.stage_settlement('+lit(JSON.stringify(settlement))+'::jsonb);');
 for(const m of settlement.matches){const final=m===settlement.matches.at(-1),f=id=>final?settlement.matches.slice(0,-1).find(x=>x.winner_id===id)?.match_id??null:null;await db.sql('SELECT ace_review.claim_finalization('+[m.match_id,id,'ace',m.player1_id,m.player2_id,f(m.player1_id),f(m.player2_id)].map(lit).join(',')+');');}
 await db.sql('SELECT ace_review.finalize_staged_competition('+lit(id)+');');
 assert.deepEqual((await Promise.all([stage(review),stage(review)])).sort(),['already_staged','staged']);
 const tampered=clone(review);tampered.accounts[0].gross_prize++;await assert.rejects(stage(tampered),/rejected/);
 assert.deepEqual(JSON.parse(await db.sql('SELECT payload FROM ace_review.career_exports WHERE competition_id='+lit(id)+';')),review);
 await assert.rejects(db.sql('DELETE FROM ace_review.career_exports'),/rejected/);
 console.log('PASS gross prize, monthly tax, source-ID injury replay, ranking contribution and immutable career proposal staging');
}
run().catch(e=>{console.error(e);process.exitCode=1});
