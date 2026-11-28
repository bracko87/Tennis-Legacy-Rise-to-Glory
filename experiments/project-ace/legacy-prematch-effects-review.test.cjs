'use strict';
const assert=require('node:assert/strict'),{fixture,id}=require('./legacy-tournament-fixture.cjs'),{equipmentProjection,tacticProjection,prepare,simulate}=require('./legacy-prematch-effects-review.cjs'),sample=require('./sample-legacy-snapshot.json');
const source=fixture(),m=source.matches[0];
const support={serve_pct:0,return_pct:0,rally_pct:0,net_pct:0,focus_pct:0,stamina_pct:0,heat_resistance_pct:0,cold_resistance_pct:0};
const equipment={human:true,support,missing:{racket:false,shoes:false,apparel:false}};
const tactic={source:'match_override',preset:'Balanced',approach:'Balanced',rally:'Balanced rallies',serve:'Balanced',servePlacement:'Automatic',returnGame:'Balanced',returnPosition:'Normal',courtPosition:'Normal baseline',target:'Automatic',risk:'Balanced'};
const context={schema:'ace-legacy-prematch-observation-v1',consistent_pre_match_attested:true,match_id:m.id,match_updated_at:m.updated_at,competition_id:m.competition_id,review_revision:0,ace_seed:127,edition:{id:source.edition.id,season_number:2,tournament_series_id:id(900)},series:{id:id(900),surface:'Hard',environment:'outdoor',category_code:'grand_slam_2000',name:'Synthetic tournament',city:'Test City',country_code:'XX'},weather:{status:'ready',environment:'outdoor',temperature_c:21,wind_kmh:5,precipitation:'none',can_delay_match:false,seed:'synthetic-weather'},players:[m.player1_id,m.player2_id].map((player_id,i)=>{const s=sample.players[i].skills;const fields=ks=>Object.fromEntries(ks.split(' ').map(k=>[k,s[k]]));return {playing_hand:i?'left':'right',equipment_class:'performance',equipment_evidence:'synthetic-gear-'+i,profile:{player_id,surface:'hard',preferred_surface:s.preferred_surface,playing_style:s.playing_style,technical:fields('serve forehand backhand return_skill volley slice drop_shot lob smash'),physical:fields('fitness stamina recovery movement'),condition:fields('fatigue sharpness morale confidence focus')}};})};
const obs=[m.player1_id,m.player2_id].map(player_id=>({player_id,match_id:m.id,match_updated_at:m.updated_at,evidence_revision:'synthetic-v1',equipment:structuredClone(equipment),tactic:{...tactic}}));
const p=equipmentProjection({...equipment,support:{...support,serve_pct:10,return_pct:1,focus_pct:5,stamina_pct:5,heat_resistance_pct:4},missing:{racket:true,shoes:true,apparel:true}},28);
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-12,String(a)+' != '+b);
near(p.climate,1.4);near(p.pct.serve,4);near(p.pct.return,3);near(p.pct.rally,2.5);
near(p.multipliers.serve,1.04*.65*.97);near(p.multipliers.return,1.03*.65*.93*.97);
near(equipmentProjection({...equipment,support:{...support,cold_resistance_pct:4}},12).climate,1.4);
near(equipmentProjection(equipment,21).multipliers.rally,1);
assert.throws(()=>equipmentProjection({...equipment,human:false,missing:{...equipment.missing,racket:true}},21));
assert.throws(()=>equipmentProjection({...equipment,support:{...support,focus_pct:null}},21));
assert.throws(()=>tacticProjection({...tactic,serve:'invalid'}));
const a=prepare(source,context,obs);assert.equal(a.blockers.length,0);assert.equal(a.base.frozen.snapshot.players[0].equipment,'standard');
const r=simulate(source,context,obs,a.review_sha256);assert.equal(r.production_ready,false);assert.ok(r.total_points>0);assert.deepEqual(simulate(source,context,obs,a.review_sha256),r);
const changed=structuredClone(obs);changed[0].equipment.missing.racket=true;changed[0].equipment.missing.shoes=true;changed[0].tactic.approach='Aggressive';
const b=prepare(source,context,changed);assert.notEqual(a.review_sha256,b.review_sha256);assert.throws(()=>simulate(source,context,changed,a.review_sha256));
const rb=simulate(source,context,changed,b.review_sha256);assert.equal(rb.tactics[0].approach,'Aggressive');assert.notEqual(rb.point_trace_sha256,r.point_trace_sha256);
for(const [k,v] of Object.entries({serve:'Serve + 1',servePlacement:'Wide',returnGame:'Aggressive return',returnPosition:'Closer',courtPosition:'Net attack',target:'Second serve',risk:'Aggressive'})){
 const x=structuredClone(obs);x[0].tactic[k]=v;const t=prepare(source,context,x);assert.equal(t.blockers.length,1);assert.throws(()=>simulate(source,context,x,t.review_sha256),/Unsupported tactical/);
}
assert.throws(()=>prepare(source,context,[...obs].reverse()));
const stale=structuredClone(obs);stale[0].match_updated_at='stale';assert.throws(()=>prepare(source,context,stale));
console.log('PASS source-shaped equipment modifiers, stacked penalties, identity and deterministic tactical simulation; seven unsupported tactic fields fail closed');

const v3='ace-tactical-review-0.6';
const neutralV3=prepare(source,context,obs,v3);
assert.notEqual(neutralV3.review_sha256,a.review_sha256);
assert.equal(simulate(source,context,obs,neutralV3.review_sha256,v3).point_trace_sha256,r.point_trace_sha256);
assert.throws(()=>simulate(source,context,obs,neutralV3.review_sha256));
const full=structuredClone(obs);
Object.assign(full[0].tactic,{preset:'Attack',serve:'Serve + 1',servePlacement:'Wide',returnGame:'Aggressive return',returnPosition:'Closer',courtPosition:'Net attack',target:'Second serve',risk:'Aggressive'});
full[0].equipment.missing.shoes=true;
const c=prepare(source,context,full,v3);assert.equal(c.blockers.length,0);
const rc=simulate(source,context,full,c.review_sha256,v3);assert.equal(rc.tactics[0].servePlacement,'Wide');assert.equal(rc.tactics[0].risk,'Aggressive');assert.notEqual(rc.point_trace_sha256,r.point_trace_sha256);assert.deepEqual(simulate(source,context,full,c.review_sha256,v3),rc);
console.log('PASS opt-in review v0.6: neutral trace parity, full tactical observation, digest version binding and deterministic execution');

const eligibility=require('./legacy-eligibility-review.cjs');
const day=368,minute=day*1440+m.scheduled_start_minute;
const eligibilityEvidence={schema:'ace-legacy-match-eligibility-observation-v1',complete_health_attested:true,consistent_snapshot_attested:true,match_id:m.id,competition_id:m.competition_id,match_updated_at:m.updated_at,match_absolute_day:day,target_absolute_minute:minute,observed_absolute_minute:minute,players:obs.map(o=>({player_id:o.player_id,human:true,evidence_revision:o.evidence_revision,career_status:'active',health_records:[],travel:{status:'normal',basis:'planned_travel_leg',departure_absolute_minute:(day-1)*1440+540,arrival_absolute_minute:(day-1)*1440+840,ready_absolute_minute:(day-1)*1440+930,pre_match_arrival_buffer_minutes:90,target_absolute_minute:minute,actual_presence_confirmed:true}}))};
const g=eligibility.prepare(source,eligibilityEvidence);
assert.deepEqual(eligibility.execute(source,eligibilityEvidence,g.eligibility_sha256,context,obs,neutralV3.review_sha256).result,simulate(source,context,obs,neutralV3.review_sha256,v3));
const rev=structuredClone(obs);rev[0].evidence_revision='other';assert.throws(()=>eligibility.execute(source,eligibilityEvidence,g.eligibility_sha256,context,rev,neutralV3.review_sha256),/revision/);
const unavailable=structuredClone(eligibilityEvidence);unavailable.players[0].travel.actual_presence_confirmed=false;const held=eligibility.prepare(source,unavailable);assert.equal(eligibility.execute(source,unavailable,held.eligibility_sha256,context,obs,neutralV3.review_sha256).status,'held');
console.log('PASS eligibility-gated v0.6 simulation, same evidence revision and travel hold');

const shared=require('./legacy-shared-schedule-review.cjs'),{slot}=require('./world-clock.cjs');
const scheduleEvidence={schema:'ace-legacy-shared-schedule-observation-v1',complete_inventory_attested:true,consistent_snapshot_attested:true,competition_id:m.competition_id,match_id:m.id,inventory_revision:'synthetic-v1',game_second:minute*60,speed:6,policy:{venue_id:id(800),first_week:1,last_week:1,court_count:4},inventory:source.matches.map(x=>({id:x.id,competition_id:x.competition_id,venue_id:id(800),kind:'singles',status:'scheduled',revision:x.updated_at,players:x.player1_id?[x.player1_id,x.player2_id]:[],start_minute:slot(2,x.scheduled_season_week,x.scheduled_day,x.scheduled_start_minute)/60,court:x.court_number,estimated_duration_minutes:x.estimated_duration_minutes,recovery_minutes:60,actual_end_minute:null,winner_id:null}))};
const sched=shared.prepare(source,scheduleEvidence);
const combined=shared.execute(source,scheduleEvidence,sched.schedule_sha256,eligibilityEvidence,g.eligibility_sha256,context,obs,neutralV3.review_sha256);
assert.equal(combined.status,'simulated_review');assert.ok(combined.played_minutes>=60);assert.equal(combined.activation_authorized,false);
assert.deepEqual(combined.eligibility_result.result,simulate(source,context,obs,neutralV3.review_sha256,v3));
assert.throws(()=>shared.execute(source,scheduleEvidence,sched.schedule_sha256,{...eligibilityEvidence,observed_absolute_minute:minute+1},g.eligibility_sha256),/mismatch/);
console.log('PASS shared scheduling and eligibility composed with deterministic match engine');
