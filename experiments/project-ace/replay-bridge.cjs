'use strict';
// Map elapsed Ace events to the existing ReplayEvent shape, without registering a sealed simulation.
function score(a,b,tb){if(tb)return String(a);if(a>=3&&b>=3)return a>b?'AD':'40';return ['0','15','30','40'][Math.min(a,3)];}
function project(v,pointDelay){
 const events=[];let offset=0,games=[0,0],sets=[0,0],set=1,game=0,points=['0','0'],lastKind='';
 const emit=(kind,description)=>events.push({offset_seconds:offset/1000,kind,description,p1_sets:sets[0],p2_sets:sets[1],p1_games:games[0],p2_games:games[1],p1_points:points[0],p2_points:points[1],set_number:set,game_number:game});
 if(v.status!=='scheduled')emit('match_start','Match started');
 for(const e of v.events){
  if(e.kind==='point'){
   if(e.game!==game){if(game){offset+=v.breakMs;if(lastKind==='set_end'){games=[0,0];set=e.set;}points=['0','0'];}game=e.game;set=e.set;}
   offset+=pointDelay(e.number);points=[score(e.points[0],e.points[1],e.tiebreak),score(e.points[1],e.points[0],e.tiebreak)];
   emit('point',v.players[e.winner].name+(e.ace?' serves an ace':e.df?' wins after a double fault':e.ue?' wins after an unforced error':' wins the point'));
  }else if(e.kind==='game_end'){games=[...e.games];points=['0','0'];emit('game_end','Game complete');}
  else if(e.kind==='set_end'){sets=[...e.sets];games=[...e.games];emit('set_end','Set complete');}
  else if(e.kind==='match_end')emit('match_end','Match complete');
  lastKind=e.kind;
 }
 const done=v.status==='completed',elapsed=Math.max(0,Math.floor((v.serverNow-v.startAt)/1000));
 return {status:done?'completed':v.status==='scheduled'?'prepared':'live',match_status:done?'completed':v.status==='scheduled'?'scheduled':'in_progress',controls_locked:!done,historical_replay:done,server_now:new Date(v.serverNow).toISOString(),live_started_at:new Date(v.startAt).toISOString(),elapsed_seconds:done?offset/1000:elapsed,replay_duration_seconds:done?offset/1000:null,player1_id:v.id+':p1',player2_id:v.id+':p2',player1_name:v.players[0].name,player2_name:v.players[1].name,events,last_event:events.at(-1)??null,final_score:done?{score:v.completedSets.map(s=>s.games.join('-')).join(' '),sets:v.completedSets}:null,winner_id:done?v.id+':p'+(v.winner+1):null,engine_version:v.engineVersion};
}
module.exports={project};
