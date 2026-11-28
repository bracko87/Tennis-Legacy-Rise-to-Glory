'use strict';
const assert=require('node:assert/strict'),{fixture,id}=require('./legacy-tournament-fixture.cjs'),{prepare,execute}=require('./legacy-shared-schedule-review.cjs'),{slot}=require('./world-clock.cjs');
const s=fixture(),m=s.matches[0],minute=slot(2,1,1,600)/60,venue=id(800);
function obs(){return {schema:'ace-legacy-shared-schedule-observation-v1',complete_inventory_attested:true,consistent_snapshot_attested:true,competition_id:m.competition_id,match_id:m.id,inventory_revision:'synthetic-v1',game_second:minute*60,speed:6,policy:{venue_id:venue,first_week:1,last_week:1,court_count:4},inventory:s.matches.map(x=>({id:x.id,competition_id:x.competition_id,venue_id:venue,kind:'singles',status:'scheduled',revision:x.updated_at,players:x.player1_id?[x.player1_id,x.player2_id]:[],start_minute:slot(2,x.scheduled_season_week,x.scheduled_day,x.scheduled_start_minute)/60,court:x.court_number,estimated_duration_minutes:x.estimated_duration_minutes,recovery_minutes:60,actual_end_minute:null,winner_id:null}))};}
const external={id:id(999),competition_id:id(998),venue_id:id(997),kind:'doubles',status:'completed',revision:'external-1',players:[m.player1_id,id(901),id(902),id(903)],start_minute:minute-150,court:1,estimated_duration_minutes:90,recovery_minutes:60,actual_end_minute:minute-60,winner_id:null};
const a=obs(),ready=prepare(s,a);assert.equal(ready.status,'ready_for_review');assert.deepEqual(prepare(s,a),ready);
const paused=obs();paused.speed=0;assert.equal(prepare(s,paused).status,'paused');
const early=obs();early.game_second--;assert.equal(prepare(s,early).status,'not_due');
const late=obs();late.game_second+=60;assert.equal(prepare(s,late).status,'fresh_slot_required');
const rest=obs();rest.inventory.push({...external,competition_id:m.competition_id,venue_id:venue,court:4});assert.equal(prepare(s,rest).status,'ready_for_review');
rest.inventory.at(-1).actual_end_minute++;assert.notEqual(prepare(s,rest).status,'ready_for_review');
const otherDay=obs();otherDay.inventory.push(external);assert.equal(prepare(s,otherDay).status,'reschedule_review');assert.ok(prepare(s,otherDay).proposed.start_minute>=minute+1440-600);
const live=obs();live.inventory.push({...external,status:'live',actual_end_minute:null});assert.equal(prepare(s,live).status,'blocked');
const future=obs();future.inventory.push({...external,competition_id:m.competition_id,venue_id:venue,court:1,players:[id(910),id(911),id(912),id(913)],status:'scheduled',start_minute:minute+100,actual_end_minute:null});assert.equal(prepare(s,future).status,'reschedule_review');
const court=obs();court.inventory.push({...external,competition_id:m.competition_id,venue_id:venue,court:1,players:[id(910),id(911),id(912),id(913)],actual_end_minute:minute-15});assert.equal(prepare(s,court).status,'ready_for_review');court.inventory.at(-1).actual_end_minute++;assert.notEqual(prepare(s,court).status,'ready_for_review');
const later=obs();later.match_id=s.matches[4].id;later.game_second=later.inventory[4].start_minute*60;assert.equal(prepare(s,later).status,'feeders_pending');
for(let i=0;i<2;i++){const x=later.inventory[i];x.status='completed';x.actual_end_minute=x.start_minute+120;x.winner_id=x.players[0];}
later.inventory[4].players=[later.inventory[0].winner_id,later.inventory[1].winner_id];assert.equal(prepare(s,later).status,'owner_receipt_verification_required');
later.inventory[4].players.reverse();assert.equal(prepare(s,later).status,'feeder_winner_mismatch');
assert.throws(()=>execute(s,paused,ready.schedule_sha256),/changed/);
assert.equal(execute(s,paused,prepare(s,paused).schedule_sha256).status,'held');
for(const change of [x=>x.complete_inventory_attested=false,x=>x.inventory.pop(),x=>x.inventory.push(x.inventory[0]),x=>x.inventory[0].revision='stale',x=>x.inventory[0].court=2,x=>x.inventory[0].players.reverse(),x=>x.policy.court_count=1]){
 const x=obs();change(x);assert.throws(()=>prepare(s,x));
}
console.log('PASS shared inventory schedule: due clock, rest and court boundaries, doubles, unknown live finish, future reservation, feeder evidence and stale revision');
