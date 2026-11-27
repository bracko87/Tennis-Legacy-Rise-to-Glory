'use strict';
const assert=require('node:assert/strict'),a=require('./engine.cjs'),{calculate}=require('./official-statistics.cjs'),{fromCheckpoint}=require('./official-replay-adapter.cjs'),{duration}=require('./schedule-gate.cjs'),{project}=require('./official-simulation-payload-review.cjs');
const p={name:'Ace Admin',serve:62,return:58,rally:60,forehand:65,backhand:55,fitness:65,stamina:68,movement:62,fatigue:10,focus:75,confidence:70},q={...p,name:'Ace Test AI',backhand:42,stamina:55};
let count=0,tiebreaks=0,deciding=0;
for(const bestOf of [3,5])for(let seed=1;seed<=100;seed++){
 let s=a.createMatch({players:[p,q],seed,bestOf});while(s.status!=='completed')s=a.stepGame(s);
 const ids=['p1','p2'],stats=calculate(s.events.filter(e=>e.kind==='point'));
 tiebreaks+=s.completedSets.filter(x=>x.tiebreak).length;if(bestOf===5&&s.completedSets[4]?.tiebreak)deciding++;
 for(const order of [[0,1],[1,0]]){
  const sets=s.completedSets.map((x,i)=>({match_id:'m',set_number:i+1,player1_games:x.games[order[0]],player2_games:x.games[order[1]],player1_tiebreak_points:x.tiebreak?.[order[0]]??null,player2_tiebreak_points:x.tiebreak?.[order[1]]??null,status:'completed'}));
  const m={match_id:'m',status:'completed',player1_id:ids[order[0]],player2_id:ids[order[1]],winner_id:ids[s.winner],score:sets.map(x=>x.player1_games+'-'+x.player2_games).join(' '),sets,stats:order.map(i=>({match_id:'m',player_id:ids[i],...stats[i]})),actual_duration_minutes:duration(s.gameNumber,s.totalPoints),engine_version:'ace-review'};
  const seconds=bestOf===3?480:1800,r=fromCheckpoint(m,s,ids,seconds);
  assert.equal(r.events.at(-1).offset_seconds,seconds);assert.equal(r.events.filter(e=>e.kind==='point').length,s.totalPoints);
  const payload=project(m,{match_id:'m',player1_id:m.player1_id,player2_id:m.player2_id,engine_seed:String(seed),estimated_match_minutes:150,weather:{heat_index:24},weather_source:'synthetic',replay:r});
  assert.equal(payload.simulation.final_score.score,m.score);assert.equal(payload.simulation.total_points,s.totalPoints);assert.equal(payload.production_ready,false);
  assert.throws(()=>fromCheckpoint({...m,winner_id:'foreign'},s,ids,seconds),/identity/);
  count++;
 }
}
assert.equal(count,400);assert.ok(tiebreaks>0);assert.ok(deciding>0);
console.log(JSON.stringify({passed:count,tiebreaks,deciding,production_ready:false}));
