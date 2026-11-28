'use strict';
const assert=require('node:assert/strict'),engine=require('./engine.cjs'),{fixtureProfiles}=require('./profiles.cjs'),{modifiers}=require('./tactical-v3-review.cjs');
const version='ace-tactical-review-0.6',players=fixtureProfiles('power','defensive','hard',false,{hands:['left','right']});
const make=(v=version,p=players)=>engine.createMatch({players:p,version:v,seed:43});
const neutral=make(),legacy=make('ace-context-0.5');
for(const i of [0,1])for(const first of [true,false])assert.deepEqual(engine.probabilities(neutral,i,first),engine.probabilities(legacy,i,first));
function withTactic(side,patch){const s=make();const queued=engine.queueTactics(s,side,patch);assert.deepEqual(s.tactics,queued.tactics);queued.tactics[side]={...queued.tactics[side],...queued.pending[side]};return queued;}
for(const [side,key,value,server,first,metric] of [
 [0,'servePlacement','Wide',0,true,'ace'],[0,'servePlacement','T',0,true,'ace'],[0,'servePlacement','Body',0,true,'serverWin'],
 [1,'returnPosition','Closer',0,true,'serverWin'],[1,'returnPosition','Deeper',0,true,'serverWin'],[0,'serve','Serve + 1',0,true,'serverWin'],
 [1,'returnGame','Aggressive return',0,true,'serverWin'],[0,'courtPosition','Net attack',0,true,'serverWin'],[0,'courtPosition','Inside baseline',1,true,'serverWin'],[0,'courtPosition','Deep baseline',0,true,'serverWin'],
 [0,'risk','Aggressive',0,true,'serverWin'],[0,'risk','Safe',0,true,'serverWin'],[0,'target','Second serve',1,false,'serverWin']
]){
 const s=withTactic(side,{[key]:value});const a=engine.probabilities(s,server,first),b=engine.probabilities(neutral,server,first);
 assert.notEqual(a[metric],b[metric],key+' '+value);
 assert.ok(a.serverWin>=.32&&a.serverWin<=.90);
}
const second=withTactic(0,{target:'Second serve'});assert.deepEqual(engine.probabilities(second,1,true),engine.probabilities(neutral,1,true));
assert.throws(()=>engine.queueTactics(legacy,0,{risk:'Safe'}));assert.throws(()=>engine.queueTactics(neutral,0,{risk:'unknown'}));
const missing=make(version,[{...players[0],equipmentMultipliers:{serve:.65,return:.65,rally:.65}},players[1]]);
assert.ok(engine.probabilities(missing,0,true).serverWin<engine.probabilities(neutral,0,true).serverWin);
assert.throws(()=>make(version,[{...players[0],equipment:'performance'},players[1]]));
assert.throws(()=>make(version,[{...players[0],equipmentMultipliers:{serve:2,return:1,rally:1}},players[1]]));
const queued=engine.queueTactics(neutral,0,{risk:'Aggressive',courtPosition:'Net attack'});const stepped=engine.stepGame(queued);assert.equal(stepped.tactics[0].risk,'Aggressive');assert.deepEqual(engine.stepGame(queued),stepped);
assert.ok(modifiers(players[0],players[1],{risk:'Aggressive'}).ue>modifiers(players[0],players[1],{risk:'Safe'}).ue);
console.log('PASS extended tactical controls, old version isolation, neutral probabilities, equipment guard and next-game activation');
