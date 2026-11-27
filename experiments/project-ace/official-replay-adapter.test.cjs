'use strict';
const assert=require('node:assert/strict'),{adapt}=require('./official-replay-adapter.cjs');
const match={status:'completed',player1_id:'p1',player2_id:'p2',winner_id:'p1',score:'6-0 6-0',sets:[{player1_games:6,player2_games:0},{player1_games:6,player2_games:0}],stats:[{total_points_won:48},{total_points_won:0}]};
const events=[];let time=0;
const add=(kind,set,game,games,sets,points='0')=>events.push({kind,offset_seconds:time++,description:kind,set_number:set,game_number:game,p1_games:games,p2_games:0,p1_sets:sets,p2_sets:0,p1_points:points,p2_points:'0'});
add('match_start',1,0,0,0);
for(let s=1;s<=2;s++){for(let g=1;g<=6;g++){for(const p of ['15','30','40','40'])add('point',s,(s-1)*6+g,g-1,s-1,p);add('game_end',s,(s-1)*6+g,g,s-1);}add('set_end',s,s*6,6,s);}
add('match_end',2,12,6,2);
const source={status:'completed',player1_id:'p1',player2_id:'p2',winner_id:'p1',final_score:{score:match.score},events};
const r=adapt(match,source,480);assert.equal(r.events.at(-1).offset_seconds,480);assert.ok(r.events.every(e=>Number.isInteger(e.offset_seconds)));assert.equal(r.schema_version,1);
assert.throws(()=>adapt(match,source,479),/bounds/);
assert.throws(()=>adapt(match,{...source,status:'live'},480),/identity/);
const bad=structuredClone(source);bad.events.find(e=>e.kind==='set_end').p1_games=5;assert.throws(()=>adapt(match,bad,480),/set score/);
assert.throws(()=>adapt(match,{...source,events:events.filter((e,i)=>i!==1)},480),/totals/);
console.log('PASS historical replay adapter, integer timeline, scoreboard and final-set checks');
