'use strict';
// Opt-in private career support, applied only in the unified world pilot.
const h=require('./career-support.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
function prepare(s,job,day){
 for(let i=0;i<2;i++){
  const id=job.playerKeys[i],p=s.roster.find(x=>x.id===id),support=s.worldSupport.players[id];
  if(support&&!h.eligibility(support.injuries,day).eligible)return {status:'blocked_injury',player:id};
 }
 // Checkpoint has not played any points. Apply the frozen rating snapshot once.
 for(let i=0;i<2;i++){
  const id=job.playerKeys[i],support=s.worldSupport.players[id];if(!support)continue;
  const p=job.fixture.checkpoint.players[i];
  if(support.inventory){
   const {ratings}=h.resolveGear(support.inventory,support.loadout);
   p.equipment='standard';
   for(const k of ['serve','return','rally'])p[k]*=ratings[k];
   if(p.rawServe!==undefined)p.rawServe*=ratings.serve;
  }
 }
 return {status:'ready'};
}
function complete(s,p,receipt,delta){
 const support=s.worldSupport.players[p.id];if(!support)return delta;
 const gain=h.adjustedGain(delta.gain,support.staff),after={...delta.after,fatigue:Math.min(100,delta.before.fatigue+gain)};
 const active=h.eligibility(support.injuries,s.worldSupport.day).active;
 const risk=h.injuryRisk({...p.profile,...after},{minutes:delta.minutes,heat:0,activeInjuries:active,support:support.staff});
 const event={matchId:receipt.matchId,playerId:p.id,day:s.worldSupport.day,injuryRiskPercent:risk,wear:[]};
 if(support.inventory){const r=h.wear(support.inventory,support.loadout,support.wearPerMatch);support.inventory=r.inventory;support.loadout=r.loadout;event.wear=r.events;}
 s.worldSupport.events.push(event);
 return {...delta,gain,after};
}
function validate(config,ids,day){
 const players=Object.create(null);
 for(const [id,input] of Object.entries(config??{})){
  if(!ids.includes(id)||!input||typeof input!=='object')throw Error('Invalid career support player');
  const staff=h.staff(input.staff),injuries=clone(input.injuries??[]);h.eligibility(injuries,day);
  const entry={staff,injuries};
  if(input.inventory!==undefined){h.resolveGear(input.inventory,input.loadout);h.wear(input.inventory,input.loadout,input.wearPerMatch??{});Object.assign(entry,{inventory:clone(input.inventory),loadout:clone(input.loadout),wearPerMatch:clone(input.wearPerMatch??{})});}
  players[id]=entry;
 }
 return {day,players,events:[]};
}
module.exports={prepare,complete,validate};
