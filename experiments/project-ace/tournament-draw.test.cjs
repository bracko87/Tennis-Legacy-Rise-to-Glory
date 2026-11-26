'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const d=require('./tournament-draw.cjs'),{open}=require('./tournament-store.cjs'),{fixtureProfiles}=require('./profiles.cjs'),{apply}=require('./career-condition.cjs');
const admin={id:'admin',verified:true,isAdmin:true},policy={enabled:true,adminId:'admin'},other={id:'other',verified:true,isAdmin:true};
const entrants=Array.from({length:8},(_,i)=>({id:'p'+i,profile:{...fixtureProfiles(i%2?'power':'balanced','balanced','clay',false,{})[0],name:'Synthetic '+i}}));
const args={entrants,mainSlots:['p0',{qualifier:'Q1'},'p1','p2'],qualification:[{id:'Q1',players:['p3','p4','p5','p6']}],courts:['c1','c2'],startAt:1000,surface:'clay',pace:'fast',mainBestOf:5,seed:33,roundGapMs:60000};
// Seven entrants: three direct + four qualifying.
args.entrants=entrants.slice(0,7);
const start=d.create(args,admin,policy,0);
assert.throws(()=>d.create({...args,mainSlots:['p0','p1','p1',{qualifier:'Q1'}]},admin,policy,0),/slots/);
assert.throws(()=>d.summary(start,other,policy,0),/Forbidden/);
assert.equal(start.matches.length,2);assert.equal(start.champion,null);
const at=d.advance(start,admin,policy,1000);assert.equal(at.scheduler.jobs.filter(j=>j.status==='live').length,2);
assert.equal(d.summary(at,admin,policy,1000).results.length,0);
const end=d.advance(at,admin,policy,10000000),split=d.advance(d.advance(at,admin,policy,80000),admin,policy,10000000);
assert.deepEqual(end,split);
assert.equal(end.phase,'completed');assert.equal(end.matches.length,6);assert.equal(end.scheduler.receipts.length,6);
assert.equal(end.conditionEvents.length,12);assert.equal(new Set(end.conditionEvents.map(x=>x.matchId+':'+x.playerId)).size,12);
assert.ok(end.champion);const qualifier=end.groups[0].winner;
assert.ok(end.matches.filter(m=>m.phase==='main_draw'&&m.round===1).some(m=>m.players.includes(qualifier)));
const final=end.matches.at(-1);assert.equal(final.winner,end.champion);assert.equal(end.scheduler.jobs.at(-1).fixture.checkpoint.bestOf,5);
assert.ok(end.scheduler.jobs.filter(j=>end.matches.find(m=>m.id===j.id).phase==='qualification').every(j=>j.fixture.checkpoint.bestOf===3));
for(const p of end.roster){
 const log=end.conditionEvents.filter(x=>x.playerId===p.id);let prior=args.entrants.find(x=>x.id===p.id).profile;
 for(const entry of log){assert.equal(entry.before.fatigue,prior.fatigue);assert.ok(entry.gain>=4&&entry.gain<=28);prior={...prior,...entry.after};}
 assert.equal(p.profile.fatigue,prior.fatigue);
}
assert.deepEqual(d.advance(end,admin,policy,10000001).conditionEvents,end.conditionEvents);
const r={totalGames:12,totalPoints:48,sets:[{},{}]};
assert.equal(apply({...entrants[0].profile,fitness:50,stamina:50,recovery:50},r,true,'hard').gain,6);
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'ace-draw-'));let disk;
const opts={kind:'draw',advance:(s,n)=>d.advance(s,admin,policy,n)};
try{disk=open(dir,start,opts);disk.tick(80000);disk.close();assert.throws(()=>open(dir),/kind/);disk=open(dir,null,opts);assert.deepEqual(disk.tick(10000000),end);disk.close();}
finally{disk?.close();fs.rmSync(dir,{recursive:true,force:true});}
console.log('PASS qualification sections, main-draw progression, best-of-five final, exactly-once condition events, private access and deterministic persistent restart');
