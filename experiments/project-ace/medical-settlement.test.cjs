'use strict';
const assert=require('node:assert/strict'),bridge=require('./official-review.cjs'),w=require('./world-worker.cjs'),c=require('./world-clock.cjs'),{project}=require('./official-settlement-review.cjs'),{snapshot,options}=require('./official-review.test.cjs'),{connection}=require('./postgres-store.cjs');
const clone=x=>JSON.parse(JSON.stringify(x)),p={id:'a',verified:true,isAdmin:true},policy={enabled:true,adminId:'a'};
const raw=(ms,day,hour)=>({server_now:new Date(ms).toISOString(),game_total_seconds:c.slot(1,1,day,hour*60),speed_multiplier:60});
const lit=x=>x===null?'NULL':"convert_from(decode('"+Buffer.from(String(x)).toString('base64')+"','base64'),'UTF8')";
function fixture(id){
 const x=clone(snapshot);x.competition.id=id;x.match_slots.forEach((m,i)=>{m.id=id+'-m'+i;m.competition_id=id;});
 let s=bridge.create(x,p,policy,raw(0,1,9),options);s.config.medicalWalkovers=true;
 s.draw.worldSupport.players.p0.injuries=[{status:'active',tournamentReturnDay:4,fullRecoveryDay:6}];
 s=w.tick(s,raw(5000,1,10),p,policy);s=w.tick(s,raw(1000000,1,11),p,policy);
 s=w.tick(s,raw(1100000,2,10),p,policy);s=w.tick(s,raw(2100000,2,11),p,policy);
 assert.equal(s.draw.phase,'completed');assert.equal(s.draw.medicalEvidence.length,1);
 const map=(rows,key)=>rows.find(x=>x.local===key).source;
 const officialMatches=s.draw.matches.map(m=>({match_id:map(s.source.matches,m.id),competition_id:id,player1_id:map(s.source.players,m.players[0]),player2_id:map(s.source.players,m.players[1]),status:'scheduled'}));
 return {s,officialMatches};
}
async function run(){
 const {s,officialMatches}=fixture('medical-final-ok');
 assert.throws(()=>project(s),/participant rows required/);
 const x=project(s,{officialMatches}),m=x.matches.find(m=>m.completion_reason==='health_walkover');
 assert.ok(m);assert.equal(m.actual_duration_minutes,null);assert.equal(m.winner_id,'source-p1');assert.deepEqual(m.sets,[]);assert.deepEqual(m.stats,[]);
 assert.equal(x.conditions.length,4);assert.ok(x.conditions.every(e=>e.match_id!==m.match_id));assert.equal(x.results.length,4);assert.equal(x.transactions.length,1);
 assert.equal(x.results.find(r=>r.player_id==='source-p0').prize_money_earned,2000);
 assert.equal(x.production_ready,false);
 const bad=clone(s);bad.draw.medicalEvidence[0].health[0].records=[];assert.throws(()=>project(bad,{officialMatches}),/Medical result disagrees/);
 const wrong=officialMatches.map(row=>row.match_id===m.match_id?{...row,status:'in_progress'}:row);assert.throws(()=>project(s,{officialMatches:wrong}),/unstarted/);
 const db=connection(),stage=x=>db.sql('SELECT ace_review.stage_settlement('+lit(JSON.stringify(x))+'::jsonb);'),finish=id=>db.sql('SELECT ace_review.finalize_staged_competition('+lit(id)+');');
 async function claimAll(x){for(const m of x.matches){const earlier=x.matches.filter(z=>z!==m&&z.match_id!==x.matches.at(-1).match_id);const f=id=>m===x.matches.at(-1)?earlier.find(z=>z.winner_id===id)?.match_id??null:null;await db.sql('SELECT ace_review.claim_finalization('+[m.match_id,m.competition_id,'ace',m.player1_id,m.player2_id,f(m.player1_id),f(m.player2_id)].map(lit).join(',')+');');}}
 await stage(x);await claimAll(x);assert.deepEqual((await Promise.all([finish(x.competition_id),finish(x.competition_id)])).sort(),['already_finalized','finalized_review']);
 const stored=JSON.parse(await db.sql('SELECT payload FROM ace_review.finalized_matches WHERE match_id='+lit(m.match_id)+';'));assert.deepEqual(stored,m);
 const b=fixture('medical-final-bad'),y=project(b.s,{officialMatches:b.officialMatches});y.matches.find(m=>m.completion_reason==='health_walkover').actual_duration_minutes=60;
 await stage(y);await claimAll(y);await assert.rejects(finish(y.competition_id),/rejected/);
 assert.equal(await db.sql('SELECT count(*) FROM ace_review.finalized_matches WHERE competition_id='+lit(y.competition_id)+';'),'0');
 console.log('PASS official-shaped medical projection, frozen evidence, zero-play effects, stage rewards, atomic finalization and rejection of fabricated duration');
}
module.exports={fixture};
if(require.main===module)run().catch(e=>{console.error(e);process.exitCode=1});
