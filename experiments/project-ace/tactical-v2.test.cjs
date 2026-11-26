'use strict';
const assert=require('node:assert/strict');
const e=require('./engine.cjs'),{fixtureProfiles}=require('./profiles.cjs'),a=require('./match-service.cjs');
const create=(players=fixtureProfiles(),surface='hard',version='ace-tactical-0.4',seed=123)=>e.createMatch({players,surface,version,seed});
const patch=(s,p,i=0)=>({...s,tactics:s.tactics.map((t,j)=>j===i?{...t,...p}:t)});
const prob=(s,server)=>{const x=e.probabilities(s,server,true),y=e.probabilities(s,server,false);return x.firstIn*(x.ace+(1-x.ace)*x.serverWin)+(1-x.firstIn)*(1-y.doubleFault)*y.serverWin;};
const delta=(s,p,server=0)=> (prob(patch(s,p),server)-prob(s,server))*(server===0?1:-1);
const base=create();
assert.ok(delta(base,{target:'Backhand'})>.02);assert.ok(delta(base,{target:'Forehand'})<-.02);
assert.ok(delta(base,{approach:'Aggressive'})>.01);
const tired=create(fixtureProfiles().map((p,i)=>({...p,fatigue:i?55:15})),'clay');
assert.ok(delta(tired,{rally:'Extend rallies'})>.03);assert.ok(delta(tired,{rally:'Shorten points'})<-.02);
const power=create(fixtureProfiles('power','defensive','grass'),'grass');
assert.ok(delta(power,{serve:'Power serving'})>.02);assert.ok(delta(power,{rally:'Shorten points'})>.015);
const exhausted=create(fixtureProfiles().map((p,i)=>({...p,fatigue:i?10:80})));
assert.ok(delta(exhausted,{approach:'Aggressive'})<0);assert.ok(delta(exhausted,{rally:'Shorten points'})>0);assert.ok(delta(exhausted,{serve:'Safe first serve'})>0);
const aggressive={approach:'Aggressive',rally:'Extend rallies',serve:'Power serving',returnGame:'Attack second serve',target:'Backhand'};
for(const surface of ['hard','grass','clay'])for(const preset of ['balanced','defensive','power']){
 const s=patch(create(fixtureProfiles(preset,'balanced',surface),surface),aggressive);
 for(const first of [true,false])for(const server of [0,1]){
  const q=e.probabilities(s,server,first);assert.ok(Math.abs(q.tacticalDelta)<=.065);
  for(const k of ['firstIn','doubleFault','ace','serverWin'])assert.ok(q[k]>=0&&q[k]<=1);
  const swapped={...s,players:[...s.players].reverse(),tactics:[...s.tactics].reverse()};
  assert.deepEqual(q,e.probabilities(swapped,1-server,first));
 }
}
const finish=s=>{while(s.status!=='completed')s=e.stepGame(s);return s;};
const initial=create(),before=e.stepGame(initial),queued=e.queueTactics(before,0,aggressive),after=e.stepGame(queued);
assert.deepEqual(after.events.slice(0,before.events.length),before.events);
assert.deepEqual(finish(queued),finish(JSON.parse(JSON.stringify(queued))));
assert.notEqual(after.players[0].fatigue,after.players[1].fatigue);
const legacy=create(fixtureProfiles(),'hard','ace-poc-0.1');
assert.equal(e.stepGame(legacy).version,'ace-poc-0.1');
assert.equal('tacticalDelta' in e.probabilities(legacy,0,true),false);
const admin={id:'a',verified:true,isAdmin:true},policy={enabled:true,adminId:'a'};
const fixture=a.createFixture({id:'v4',players:fixtureProfiles(),seed:6,startAt:1000},admin,policy,0);
assert.equal(fixture.checkpoint.version,'ace-tactical-0.4');
assert.equal(a.view(fixture,admin,policy,1000).engineVersion,'ace-tactical-0.4');
const oldFixture={...fixture,checkpoint:legacy};assert.equal(a.advance(oldFixture,1000).active.after.version,'ace-poc-0.1');
console.log('PASS contextual tactical benefit and penalty, cap, side symmetry, individualized fatigue, immutable history, restart and legacy version preservation');
