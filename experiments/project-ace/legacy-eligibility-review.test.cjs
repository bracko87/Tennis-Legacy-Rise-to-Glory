'use strict';
const assert=require('node:assert/strict'),{fixture}=require('./legacy-tournament-fixture.cjs'),{prepare,execute,health,travel}=require('./legacy-eligibility-review.cjs');
const source=fixture(),m=source.matches[0],day=368,minute=day*1440+600;
const t={status:'normal',basis:'planned_travel_leg',departure_absolute_minute:(day-1)*1440+540,arrival_absolute_minute:(day-1)*1440+840,ready_absolute_minute:(day-1)*1440+930,pre_match_arrival_buffer_minutes:90,target_absolute_minute:minute,actual_presence_confirmed:true};
const e={schema:'ace-legacy-match-eligibility-observation-v1',complete_health_attested:true,consistent_snapshot_attested:true,match_id:m.id,competition_id:m.competition_id,match_updated_at:m.updated_at,match_absolute_day:day,target_absolute_minute:minute,observed_absolute_minute:minute,players:[m.player1_id,m.player2_id].map(player_id=>({player_id,human:true,evidence_revision:'synthetic-v1',career_status:'active',health_records:[],travel:{...t}}))};
const record=(id,returnDay,kind='injury')=>({id,kind,status:'active',onset_absolute_day:day-5,tournament_return_absolute_day:returnDay,expected_full_recovery_absolute_day:returnDay+3,performance_penalty:.1});
const ready=prepare(source,e);assert.equal(ready.decision,'ready_for_review');assert.deepEqual(prepare(source,e),ready);
assert.throws(()=>execute(source,e,ready.eligibility_sha256),/context/);
const one=structuredClone(e);one.players[0].health_records=[record('injury1',day+2)];
const a=prepare(source,one);assert.equal(a.decision,'medical_walkover_review');assert.equal(a.winner_id,m.player2_id);
const receipt=execute(source,one,a.eligibility_sha256);assert.equal(receipt.total_points,0);assert.equal(receipt.engine_started,false);assert.deepEqual(receipt.stats,[]);
assert.throws(()=>execute(source,one,ready.eligibility_sha256),/changed/);
const dual=structuredClone(one);dual.players[1].health_records=[record('ill1',day+1,'illness')];assert.equal(prepare(source,dual).winner_id,m.player2_id);
dual.players[1].health_records=[record('ill1',day+2,'illness')];assert.equal(prepare(source,dual).winner_id,m.player1_id);
dual.players[0].health_records.push(record('injury2',day+10));assert.equal(prepare(source,dual).winner_id,m.player1_id);
const returning=structuredClone(e);returning.players[0].health_records=[record('injury1',day)];assert.equal(prepare(source,returning).players[0].health.blocked,false);assert.equal(prepare(source,returning).decision,'hold');
returning.players[0].health_records[0].status='recovered';assert.equal(prepare(source,returning).decision,'ready_for_review');
const high=structuredClone(e);high.players[0].travel={...t,status:'tight',departure_absolute_minute:minute-400,arrival_absolute_minute:minute-90,ready_absolute_minute:minute};assert.equal(prepare(source,high).decision,'ready_for_review');
high.players[0].travel.arrival_absolute_minute++;high.players[0].travel.ready_absolute_minute++;high.players[0].travel.status='impossible';assert.equal(prepare(source,high).decision,'hold');
const absent=structuredClone(one);absent.players[1].travel.actual_presence_confirmed=false;assert.equal(prepare(source,absent).decision,'hold');assert.equal(prepare(source,absent).winner_id,null);
const ai=structuredClone(e);ai.players[1].human=false;ai.players[1].travel=null;assert.equal(prepare(source,ai).decision,'ready_for_review');
const retired=structuredClone(e);retired.players[0].career_status='retired';assert.equal(prepare(source,retired).decision,'hold');
for(const change of [x=>x.players.reverse(),x=>x.complete_health_attested=false,x=>x.match_updated_at='old',x=>x.observed_absolute_minute--,x=>x.players[0].travel.status='impossible',x=>delete x.players[0].health_records,x=>x.players[0].health_records=[record('bad',day+1),record('bad',day+2)],x=>x.players[0].health_records=[{...record('bad',day+2),onset_absolute_day:day+1}],x=>x.players[0].travel.ready_absolute_minute++,x=>x.target_absolute_minute++]){
 const x=structuredClone(e);change(x);assert.throws(()=>prepare(source,x));
}
console.log('PASS eligibility: injury and illness, inclusive return, dual blocked tie, zero-point walkover, travel boundaries, career hold, stale evidence and malformed inputs');
