'use strict';
const assert=require('node:assert/strict');
const a=require('./engine.cjs');
const p={name:'Ace Admin',serve:62,return:58,rally:60,forehand:65,backhand:55,fitness:65,stamina:68,movement:62,fatigue:10,focus:75,confidence:70};
const q={...p,name:'Ace Test AI',backhand:42,stamina:55};
const setup=(seed,bestOf=3)=>a.createMatch({players:[p,q],seed,bestOf});
const finish=s=>{while(s.status!=='completed')s=a.stepGame(s);return s};
const patch={approach:'Aggressive',rally:'Extend rallies',serve:'Power serving',returnGame:'Attack second serve',target:'Backhand'};
const firstSet=seed=>{let s=setup(seed);while(!s.completedSets.length)s=a.stepGame(s);return s};
let passed=0;const test=(name,fn)=>{fn();passed++;console.log('PASS '+name)};
test('No predetermined winner or future events',()=>{const s=setup(6);assert.equal(s.winner,null);assert.equal(s.events.length,0);assert.equal(a.observable(s).winner,null);assert.equal('rng' in a.observable(s),false);const n=a.stepGame(s);assert.equal(n.gameNumber,1);assert.equal(n.winner,null);assert.equal(s.gameNumber,0);});
test('Deterministic restart and immutable checkpoint',()=>{const s=firstSet(6),before=JSON.stringify(s);assert.deepEqual(finish(s),finish(JSON.parse(before)));assert.equal(JSON.stringify(s),before);assert.throws(()=>a.stepGame(s,s.gameNumber-1),/Stale/);});
test('Coaching only activates next game',()=>{const s=firstSet(6),queued=a.queueTactics(s,0,patch);assert.deepEqual(queued.events,s.events);assert.deepEqual(queued.tactics,s.tactics);const n=a.stepGame(queued);assert.deepEqual(n.events.slice(0,s.events.length),s.events);assert.equal(n.events[s.events.length].kind,'tactics');assert.equal(n.events[s.events.length].game,s.gameNumber+1);assert.deepEqual(n.tactics[0],patch);assert.equal(n.pending[0],null);});
test('Same seed example flips final winner',()=>{const s=firstSet(6),c=finish(s),d=finish(a.queueTactics(s,0,patch));assert.equal(c.winner,1);assert.equal(d.winner,0);assert.deepEqual(c.completedSets[0],d.completedSets[0]);assert.deepEqual(c.completedSets.map(x=>x.games),[[2,6],[6,2],[6,7]]);assert.deepEqual(d.completedSets.map(x=>x.games),[[2,6],[6,2],[6,2]]);});
test('Invalid commands and completion lock',()=>{const s=setup(1);assert.throws(()=>a.queueTactics(s,0,{serve:'Cheat'}));assert.throws(()=>a.queueTactics(s,3,patch));assert.throws(()=>a.queueTactics(s,0,{unknown:'yes'}));const done=finish(s);assert.throws(()=>a.queueTactics(done,0,patch));assert.deepEqual(a.stepGame(done),done);});
let tbCount=0,deciding=0;
test('Scoring, service order, stats and condition bounds over 200 matches',()=>{for(const bestOf of [3,5])for(let seed=1;seed<=100;seed++){
 const s=finish(setup(seed,bestOf));assert.equal(s.sets[s.winner],Math.floor(bestOf/2)+1);
 assert.equal(s.stats[0].points+s.stats[1].points,s.totalPoints);assert.equal(s.stats[0].servicePoints+s.stats[1].servicePoints,s.totalPoints);
 assert.equal(s.gameNumber,s.completedSets.reduce((n,x)=>n+x.games[0]+x.games[1],0));
 for(const stat of s.stats){assert.ok(stat.firstIn<=stat.servicePoints);assert.ok(stat.aces<=stat.firstIn);assert.ok(stat.doubleFaults<=stat.servicePoints-stat.firstIn);}
 for(const pl of s.players)for(const k of ['fatigue','focus','confidence'])assert.ok(pl[k]>=0&&pl[k]<=100);
 let next=setup(seed,bestOf).nextServer;let prior=0;let points=[];
 for(const e of s.events){if(e.kind==='point'){assert.equal(e.number,++prior);const n=points.length;const expected=e.tiebreak&&n>0?(Math.floor((n-1)/2)%2===0?1-next:next):next;assert.equal(e.server,expected);points.push(e);}
 if(e.kind==='game_end'){const target=e.tiebreak?(bestOf===5&&e.set===5?10:7):4;assert.ok(Math.max(...e.points)>=target&&Math.abs(e.points[0]-e.points[1])>=2);assert.equal(points.length,e.points[0]+e.points[1]);for(const pt of points.slice(0,-1))assert.ok(!(Math.max(...pt.points)>=target&&Math.abs(pt.points[0]-pt.points[1])>=2));if(e.tiebreak){tbCount++;if(target===10)deciding++;}next=1-next;points=[];}
 if(e.kind==='set_end'){const hi=Math.max(...e.games),lo=Math.min(...e.games);assert.ok((hi===6&&lo<=4)||(hi===7&&(lo===5||lo===6)));assert.equal(!!e.tiebreak,hi===7&&lo===6);}
 }assert.equal(prior,s.totalPoints);assert.equal(points.length,0);
}assert.ok(tbCount>0);assert.ok(deciding>0);});
test('100 paired interventions preserve history and change subsequent probability',()=>{let changes=0,probs=0;for(let seed=1;seed<=100;seed++){const s=firstSet(seed),c=finish(s),d=finish(a.queueTactics(s,0,patch));assert.deepEqual(c.events.slice(0,s.events.length),s.events);assert.deepEqual(d.events.slice(0,s.events.length),s.events);if(JSON.stringify(c.completedSets.map(x=>x.games))!==JSON.stringify(d.completedSets.map(x=>x.games)))changes++;if(c.events.filter(e=>e.kind==='point')[s.totalPoints].probability!==d.events.filter(e=>e.kind==='point')[s.totalPoints].probability)probs++;}assert.equal(changes,44);assert.equal(probs,100);});
console.log(JSON.stringify({passed,tiebreaks:tbCount,decidingTiebreaks:deciding,pairedMatches:100,scorelineChanges:44}));
