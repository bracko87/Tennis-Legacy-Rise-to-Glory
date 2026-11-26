'use strict';
// Review of the legacy pre-draw field-lock contract; no official application writes.
const {eligibility}=require('./career-support.cjs');
const copy=x=>JSON.parse(JSON.stringify(x));
const check=(v,m)=>{if(!v)throw Error(m);};
const second=x=>Number.isSafeInteger(x)&&x>=0;
const id=x=>typeof x==='string'&&x.length>0&&x.length<=120;
function plan(input){
 const {competition,nowSecond,lateCloseSecond,startSecond,drawExists=false,locked=false,entries,reserves,health}=input;
 check(id(competition)&&[nowSecond,lateCloseSecond,startSecond].every(second)&&lateCloseSecond<startSecond,'Invalid field timeline');
 check(typeof drawExists==='boolean'&&typeof locked==='boolean','Invalid field state');
 if(drawExists)return {status:'draw_already_exists'};
 if(nowSecond>=startSecond)return {status:'tournament_started'};
 if(locked)return {status:'already_locked'};
 if(nowSecond<lateCloseSecond)return {status:'not_due'};
 check(Array.isArray(entries)&&Array.isArray(reserves)&&health&&typeof health==='object','Explicit field and health snapshot required');
 const ids=new Set(),entryIds=new Set();
 for(const row of entries){
  check(id(row.entryId)&&id(row.playerId)&&!entryIds.has(row.entryId)&&!ids.has(row.playerId)&&['human','ai'].includes(row.playerType)&&['active','withdrawn'].includes(row.status)&&['main_draw','qualification'].includes(row.phase),'Invalid entry');
  ids.add(row.playerId);entryIds.add(row.entryId);
 }
 for(const row of reserves){
  check(id(row.playerId)&&!ids.has(row.playerId)&&row.playerType==='ai'&&Array.isArray(row.phases)&&row.phases.length&&new Set(row.phases).size===row.phases.length&&row.phases.every(p=>['main_draw','qualification'].includes(p)),'Invalid or duplicate AI reserve');
  ids.add(row.playerId);
 }
 const day=Math.floor(startSecond/86400),available=new Map();
 for(const playerId of ids){
  check(Object.hasOwn(health,playerId)&&Array.isArray(health[playerId]),'Missing health snapshot for '+playerId);
  available.set(playerId,eligibility(health[playerId],day).eligible);
 }
 const withdrawals=[],notices=[],replacements=[],vacancies=[],used=new Set();
 const active=entries.filter(e=>e.status==='active');
 for(const e of active){
  if(available.get(e.playerId))continue;
  withdrawals.push({entryId:e.entryId,playerId:e.playerId,status:'withdrawn',reason:'medical_unavailable_at_tournament_start',phase:e.phase});
  if(e.playerType==='human')notices.push({key:'health-tournament-withdrawn:'+competition+':'+e.playerId,playerId:e.playerId,code:'player.health.tournament_withdrawn'});
  // Explicit ranked reserve order from caller; cannot invent or infer official ranking.
  const candidate=reserves.find(x=>!used.has(x.playerId)&&available.get(x.playerId)&&x.phases.includes(e.phase));
  if(candidate){used.add(candidate.playerId);replacements.push({withdrawnEntryId:e.entryId,playerId:candidate.playerId,phase:e.phase});}
  else vacancies.push({withdrawnEntryId:e.entryId,phase:e.phase});
 }
 return copy({status:vacancies.length?'replacement_required':'ready_to_lock',reviewOnly:true,competition,startDay:day,withdrawals,replacements,vacancies,notices,retained:active.filter(e=>available.get(e.playerId)).map(e=>e.playerId)});
}
module.exports={plan};
