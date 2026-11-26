'use strict';
// Opt-in isolated medical resolution. No official RPC or simulated points.
const {eligibility}=require('./career-support.cjs');
function decide(players,support,day){
 if(!Array.isArray(players)||players.length!==2||players[0]===players[1])throw Error('Two distinct players required');
 const blocked=players.map(id=>{
  const injuries=support[id]?.injuries??[];
  return eligibility(injuries,day).eligible?null:Math.min(...injuries.filter(i=>i.status!=='recovered'&&day<i.tournamentReturnDay).map(i=>i.tournamentReturnDay));
 });
 if(blocked.every(x=>x===null))return null;
 // Legacy v14 uses minimum outstanding return date, then official player1 on tie.
 const i=blocked[0]===null?0:blocked[1]===null?1:blocked[0]<=blocked[1]?0:1;
 return {winnerKey:players[i],loserKey:players[1-i],blockedPlayers:players.filter((_,i)=>blocked[i]!==null)};
}
function resolve(draw,job,day,now){
 const meta=draw.matches.find(x=>x.id===job.id);
 if(!meta||job.status!=='scheduled'||!job.held||job.actualStartAt!==null||job.fixture.checkpoint.totalPoints!==0||draw.scheduler.receipts.some(r=>r.matchId===job.id))throw Error('Invalid medical resolution state');
 const outcome=decide(meta.players,draw.worldSupport.players,day);
 if(!outcome)return null;
 const receipt={matchId:job.id,...outcome,completionReason:'health_walkover',score:'W/O',sets:[],stats:[],totalPoints:0,totalGames:0,engineVersion:null,startedAt:null,completedAt:now,absoluteDay:day};
 draw.scheduler.receipts.push(receipt);
 Object.assign(job,{status:'completed',held:false,completedAt:now});
 draw.healthNotices??=[];
 for(const id of outcome.blockedPlayers){
  if(![draw.managedPlayer,draw.peerPlayer].includes(id))continue;
  draw.healthNotices.push({key:'health-walkover:'+job.id+':'+id,playerId:id,matchId:job.id,day,code:'player.health.medical_walkover',advanced:id===outcome.winnerKey});
 }
 return receipt;
}
module.exports={decide,resolve};
