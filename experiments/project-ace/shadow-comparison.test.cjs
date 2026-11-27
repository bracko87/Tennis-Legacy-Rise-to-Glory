'use strict';
const assert=require('node:assert/strict'),{freeze,simulate,compare,digest}=require('./shadow-comparison.cjs'),raw=require('./sample-legacy-snapshot.json');
const clone=x=>JSON.parse(JSON.stringify(x));
const cases=[['ATP','main_draw','Hard',5],['WTA','main_draw','Grass',3],['ATP','qualification','Clay',3]];
for(const [world,draw_type,surface,bestOf] of cases){
 const snapshot=clone(raw);Object.assign(snapshot.match,{world,draw_type,surface});
 const input=freeze({match_id:'shadow-'+world+'-'+draw_type,competition_id:'synthetic',source_revision:7,snapshot,seed:94321});
 assert.equal(input.format.best_of,bestOf);assert.deepEqual(simulate(input),simulate(input));
 const reversed=x=>Array.isArray(x)?x.map(reversed):x&&typeof x==='object'?Object.fromEntries(Object.keys(x).reverse().map(k=>[k,reversed(x[k])])):x;
 assert.deepEqual(input,freeze({match_id:input.match_id,competition_id:'synthetic',source_revision:7,snapshot:reversed(snapshot),seed:94321}));
 // Synthetic comparison control only; do not describe this as a real legacy run.
 const ace=simulate(input),legacy={...clone(ace),schema:'ace-shadow-legacy-observation-v1',engine_version:'synthetic-control'};
 delete legacy.point_trace_sha256;
 const report=compare(input,legacy);assert.equal(report.status,'compared_review');assert.equal(report.production_ready,false);assert.equal(report.winner_agreement,true);assert.equal(report.score_agreement,true);assert.ok(Object.values(report.metrics.delta).every(x=>x===0));
 const flipped=clone(legacy);flipped.winner_id=legacy.player_ids.find(x=>x!==legacy.winner_id);flipped.sets=legacy.sets.map(s=>({games:[...s.games].reverse(),tiebreak:s.tiebreak?[...s.tiebreak].reverse():null}));flipped.stats.reverse();
 const different=compare(input,flipped);assert.equal(different.winner_agreement,false);assert.equal(different.score_agreement,false);assert.equal(different.status,'compared_review');
 for(const change of [x=>x.input_sha256='0'.repeat(64),x=>x.source_revision++,x=>x.player_ids.reverse(),x=>x.winner_id='foreign',x=>x.stats[0].total_points_won++,x=>x.sets[0].games=[8,0],x=>x.actual_duration_minutes=0]){const bad=clone(legacy);change(bad);assert.throws(()=>compare(input,bad));}
 const tampered=clone(input);tampered.snapshot.players[0].skills.serve++;assert.throws(()=>simulate(tampered),/Frozen input mismatch/);
 const other=clone(input);other.format.best_of=bestOf===5?3:5;const {input_sha256,...body}=other;other.input_sha256=digest(body);assert.throws(()=>simulate(other),/Invalid frozen input/);

}
console.log('PASS frozen shadow input, format, deterministic Ace result, identity and statistics checks, outcome differences and tamper rejection');
