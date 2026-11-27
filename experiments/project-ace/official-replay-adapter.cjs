'use strict';
// Adapt already-completed, scoreboard-bearing review events to historical Legacy v1.
// No live registration or hidden result disclosure.
const check=(v,m)=>{if(!v)throw Error(m);};
function adapt(match,source,durationSeconds){
 check(match.status==='completed'&&match.completion_reason!=='health_walkover','Played completion required');
 check(Number.isInteger(durationSeconds)&&durationSeconds>=480&&durationSeconds<=1800,'Legacy duration bounds');
 check(source?.status==='completed'&&source.player1_id===match.player1_id&&source.player2_id===match.player2_id&&source.winner_id===match.winner_id&&source.final_score?.score===match.score,'Replay identity mismatch');
 const es=source.events;
 check(Array.isArray(es)&&es.length>=2&&es[0].kind==='match_start'&&es.at(-1).kind==='match_end','Incomplete replay');
 const last=es.at(-1).offset_seconds;
 check(Number.isFinite(last)&&last>0&&es[0].offset_seconds===0,'Invalid replay span');
 const counts={point:0,game_end:0,set_end:0,match_start:0,match_end:0,changeover:0};
 const events=es.map((e,i)=>{
  check(Object.hasOwn(counts,e.kind)&&Number.isFinite(e.offset_seconds)&&e.offset_seconds>=0&&(i===0||e.offset_seconds>=es[i-1].offset_seconds),'Invalid replay sequence');
  counts[e.kind]++;
  check(['p1_sets','p2_sets','p1_games','p2_games','set_number','game_number'].every(k=>Number.isInteger(e[k])&&e[k]>=0)&&e.set_number>=1,'Missing scoreboard');
  check(['p1_points','p2_points'].every(k=>typeof e[k]==='string'&&/^(?:[0-9]+|AD)$/.test(e[k]))&&typeof e.description==='string'&&e.description.length>0,'Invalid scoreboard points');
  return {...e,offset_seconds:Math.round(e.offset_seconds*durationSeconds/last)};
 });
 const games=match.sets.reduce((n,s)=>n+s.player1_games+s.player2_games,0),points=match.stats.reduce((n,s)=>n+s.total_points_won,0);
 check(counts.match_start===1&&counts.match_end===1&&counts.point===points&&counts.game_end===games&&counts.set_end===match.sets.length,'Replay totals mismatch');
 const ends=events.filter(e=>e.kind==='set_end');let a=0,b=0;
 for(const [i,e] of ends.entries()){const s=match.sets[i];if(s.player1_games>s.player2_games)a++;else b++;check(e.set_number===i+1&&e.p1_games===s.player1_games&&e.p2_games===s.player2_games&&e.p1_sets===a&&e.p2_sets===b,'Replay set score mismatch');}
 check(events.at(-1).p1_sets===a&&events.at(-1).p2_sets===b&&(a>b?match.player1_id:match.player2_id)===match.winner_id,'Replay winner mismatch');
 return {player1_id:match.player1_id,player2_id:match.player2_id,winner_id:match.winner_id,final_score:match.score,schema_version:1,duration_seconds:durationSeconds,events};
}
module.exports={adapt};
