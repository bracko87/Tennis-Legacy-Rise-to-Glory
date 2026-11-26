'use strict';
// Isolated admission of scheduled singles fixtures from authoritative clock samples.
// Tick only when a fresh server clock sample is supplied. Real-time simulation
// continues even if the game clock pauses. No prediction of future points.
const t=require('./tournament-lifecycle.cjs'),c=require('./world-clock.cjs'),g=require('./schedule-gate.cjs'),a=require('./match-service.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
function create(now,fixtures){if(!Array.isArray(fixtures)||new Set(fixtures.map(x=>x.id)).size!==fixtures.length)throw Error('Duplicate fixture');return {clock:null,pending:clone(fixtures),scheduler:t.create(now,{courtRestMs:0,playerRestMs:0}),admissions:[],completed:[]};}
function tick(state,raw,p,policy){
 if(!a.canUse(p,policy))throw Error('Forbidden');
 const clock=c.sample(raw),now=clock.realMs,s=clone(state);
 if(s.clock&&(now<s.clock.realMs||clock.gameSeconds<s.clock.gameSeconds))throw Error('Clock rollback; explicit new-world reset required');
 s.scheduler=t.advance(s.scheduler,now);
 for(const r of s.scheduler.receipts)if(!s.completed.some(x=>x.id===r.matchId)){
  const admission=s.admissions.find(x=>x.id===r.matchId);
  // If completion occurred between samples, conservatively use the observed game minute.
  s.completed.push({...admission,status:'completed',completedGameMinute:Math.floor(clock.gameSeconds/60),durationMinutes:g.duration(r.totalGames,r.totalPoints)});
 }
 s.clock=clock;
 for(const target of s.pending.sort((x,y)=>c.slot(x.season,x.week,x.day,x.minute)-c.slot(y.season,y.week,y.day,y.minute)||x.id.localeCompare(y.id))){
  if(target.status!=='scheduled')continue;
  const live=s.admissions.filter(x=>!s.completed.some(y=>y.id===x.id)).map(x=>({...x,status:'live'}));
  const earlier=s.pending.filter(x=>x.id!==target.id&&x.status==='scheduled').map(x=>({...x,startMinute:c.slot(x.season,x.week,x.day,x.minute)/60}));
  const result=g.plan(target,[...live,...s.completed,...earlier],clock.gameSeconds,clock.speed);
  target.lastGate=result.status;
  if(result.status==='rescheduled'){Object.assign(target,{week:result.week,day:result.day,minute:result.minute,court:result.court});continue;}
  if(result.status!=='ready')continue;
  s.scheduler=t.schedule(s.scheduler,{...target.fixture,id:target.id,courtKey:target.competition+':'+result.court,playerKeys:target.players,startAt:now},p,policy,now);
  s.scheduler=t.advance(s.scheduler,now);
  target.status='admitted';s.admissions.push({id:target.id,competition:target.competition,court:result.court,players:[...target.players],startMinute:result.gameMinute,durationMinutes:target.estimatedDuration??150});
 }
 return s;
}
module.exports={create,tick};
