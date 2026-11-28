'use strict';
const assert=require('node:assert/strict'),{adapt}=require('./legacy-tournament-adapter-review.cjs');
const {fixture,id}=require('./legacy-tournament-fixture.cjs');
const t='2026-11-28T00:00:00Z';
const f=fixture(),a=adapt(f);assert.equal(a.frozen.matches.length,7);assert.equal(a.frozen.season_number,2);assert.equal(a.production_ready,false);assert.equal(a.source_authenticated,false);assert.deepEqual(adapt(f),a);
const ordered=fixture();ordered.entries.reverse();ordered.matches.reverse();assert.deepEqual(adapt(ordered),a);
for(const mutate of [x=>x.complete_export=false,x=>x.consistent_snapshot_attested=false,x=>x.competition.status='registration_open',x=>x.entry_cycle.field_locked_at=null,x=>x.publication.qualifier_slots=1,x=>x.publication.qualifying_draw_size=16,x=>x.entries[0].bracket_slot=2,x=>x.entries[0].entry_status='withdrawn',x=>x.entries[0].world='WTA',x=>x.matches.pop(),x=>x.matches[0].player1_id=id(999),x=>x.matches[0].court_number=null,x=>x.matches[0].scheduled_start_minute=null,x=>x.matches[0].status='in_progress',x=>x.matches[0].completion_reason='health_walkover',x=>x.matches[0].schedule_reason='travel_risk',x=>x.results.push({}),x=>x.simulations.push({}),x=>x.cancellations.push({}),x=>x.edition.id=id(999)]){
 const x=fixture();mutate(x);assert.throws(()=>adapt(x));
}
const changed=fixture();changed.matches[0].estimated_duration_minutes=160;assert.notEqual(adapt(changed).source_sha256,a.source_sha256);
const changedSlot=fixture();changedSlot.matches[0].scheduled_start_minute=630;assert.notEqual(adapt(changedSlot).source_sha256,a.source_sha256);
const changedPublication=fixture();changedPublication.publication.published_at='2026-11-28T01:00:00Z';assert.notEqual(adapt(changedPublication).source_sha256,a.source_sha256);
console.log('PASS Legacy-shaped full locked singles adapter, deterministic order, source metadata binding and 20 fail-closed boundaries');
