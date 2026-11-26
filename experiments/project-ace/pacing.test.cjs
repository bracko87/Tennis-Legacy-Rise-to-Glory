'use strict';
const assert=require('node:assert/strict');
const a=require('./match-service.cjs');
const {fixtureProfiles}=require('./profiles.cjs');
const policy={enabled:true,adminId:'a',syntheticId:'b',multiplayerTest:true};
const admin={id:'a',verified:true,isAdmin:true},peer={id:'b',verified:true,synthetic:true};
const make=pace=>a.createFixture({id:'pacing',players:fixtureProfiles(),seed:6,startAt:60000,opponentId:'b',coachingModes:['manual','manual'],pace},admin,policy,0);
assert.throws(()=>make('bogus'),/Invalid match pace/);
for(const name of ['fast','balanced','coaching','extended']){
 const timing=a.PACES[name],r=make(name),start=r.startAt;
 let s=a.advance(r,start),v=a.view(s,admin,policy,start);
 assert.equal(v.nextPointAt,start+timing.pointMs);assert.equal(v.nextGameAt,null);assert.equal(v.totalPoints,0);assert.equal('endAt' in v,false);
 assert.equal(a.view(s,admin,policy,start+timing.pointMs-1).totalPoints,0);
 assert.equal(a.view(s,admin,policy,start+timing.pointMs).totalPoints,1);
 const end=s.active.endAt;
 assert.equal(end-start,s.active.points.length*timing.pointMs);
 s=a.advance(s,end);assert.equal(s.nextAt,end+timing.breakMs);
 v=a.view(s,admin,policy,end);assert.equal(v.nextGameAt,end+timing.breakMs);assert.equal(v.phase,'between-games');
 s=a.coach(s,admin,policy,end+timing.breakMs-1,2,{rally:'Extend rallies'});
 s=a.coach(s,peer,policy,end+timing.breakMs-1,2,{rally:'Shorten points'});
 s=a.advance(JSON.parse(JSON.stringify(s)),end+timing.breakMs);
 assert.equal(s.applied[0].game,2);assert.equal(s.applied[1].game,2);
 assert.equal(s.active.after.tactics[0].rally,'Extend rallies');assert.equal(s.active.after.tactics[1].rally,'Shorten points');
}
assert.deepEqual(a.PACES.balanced,{pointMs:4000,breakMs:12000});
const fast=a.advance(make('fast'),10000000),slow=a.advance(make('coaching'),10000000),middle=a.advance(make('balanced'),10000000);
assert.deepEqual(fast.checkpoint,middle.checkpoint);
assert.deepEqual(fast.checkpoint,slow.checkpoint);
// Variable pacing is shared, persisted, independent of match outcomes and backward compatible.
const variable=make('standard');
assert.deepEqual(a.PACES.standard,{pointMinMs:4000,pointMaxMs:7000,breakMs:5000});
let vrec=a.advance(variable,variable.startAt);
const intervals=new Set();
while(vrec.checkpoint.status!=='completed'){
 if(!vrec.active){vrec=a.advance(vrec,vrec.nextAt);continue;}
 const {startAt,revealAt,endAt}=vrec.active;
 for(let i=0;i<revealAt.length;i++){
  const dt=revealAt[i]-(i?revealAt[i-1]:startAt);
  assert.ok([4000,5000,6000,7000].includes(dt));intervals.add(dt);
  const pre=a.view(vrec,admin,policy,revealAt[i]-1),other=a.view(vrec,peer,policy,revealAt[i]-1);
  assert.equal(pre.nextPointAt,revealAt[i]);assert.equal(pre.nextPointAt,other.nextPointAt);
  assert.equal(pre.totalPoints,vrec.checkpoint.totalPoints+i);
  assert.equal('revealAt' in pre,false);assert.equal('endAt' in pre,false);
 }
 assert.deepEqual(a.view(vrec,admin,policy,startAt),a.view(JSON.parse(JSON.stringify(vrec)),admin,policy,startAt));
 vrec=a.advance(vrec,endAt);
 if(vrec.nextAt!==null)assert.equal(vrec.nextAt,endAt+5000);
}
assert.equal(intervals.size,4);
assert.deepEqual(vrec.checkpoint,fast.checkpoint);
const legacyActive=a.advance(make('fast'),60000);delete legacyActive.active.revealAt;delete legacyActive.pace;delete legacyActive.timingSeed;
assert.equal(a.view(legacyActive,admin,policy,62000).totalPoints,1);
const legacy=make('fast');delete legacy.pace;assert.equal(a.view(legacy,admin,policy,60000).pointMs,2000);
console.log('PASS configurable pacing, point visibility, full coaching window, simultaneous commands, persisted timing, legacy records and same-seed score invariance');
