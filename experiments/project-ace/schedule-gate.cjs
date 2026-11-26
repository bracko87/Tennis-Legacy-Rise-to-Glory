'use strict';
// Pure admission planner based on ensure_safe_singles_start_v1, with a stronger
// rule: a live participant/court remains occupied until actual completion.
const c=require('./world-clock.cjs');
const duration=(games,points)=>Math.min(420,Math.max(60,Math.round(games*5+points*.13)));
function plan(target,others,gameSeconds,speed){
 if(!target||target.status!=='scheduled'||target.feederReady!==true||!Array.isArray(target.players)||target.players.length!==2||target.players[0]===target.players[1])return {status:'not_eligible'};
 if(!Number.isSafeInteger(gameSeconds)||gameSeconds<0||!Number.isFinite(speed)||speed<0)throw Error('Invalid clock');
 if(speed===0)return {status:'paused'};
 const original=c.slot(target.season,target.week,target.day,target.minute)/60;
 if(original*60>gameSeconds)return {status:'not_due'};
 const first=c.slot(target.season,target.firstWeek,1,0)/60/1440,last=c.slot(target.season,target.lastWeek,7,0)/60/1440;
 const max=target.courtCount,preferred=target.court;
 if(!Number.isInteger(max)||max<1||max>100||!Number.isInteger(preferred)||preferred<1||preferred>max||first>last||Math.floor(original/1440)<first||Math.floor(original/1440)>last)throw Error('Invalid phase or court');
 const current=Math.floor(gameSeconds/60);
 const relevant=others.filter(x=>x.id!==target.id&&['scheduled','live','completed'].includes(x.status));
 function available(abs,court){
  for(const x of relevant){
   const samePlayer=x.players.some(p=>target.players.includes(p)),sameCourt=x.competition===target.competition&&x.court===court;
   if(!samePlayer&&!sameCourt)continue;
   // Scheduled future slots do not reserve a live resource; earlier due slots take precedence.
   if(x.status==='scheduled'&&(x.startMinute>abs||(x.startMinute===abs&&String(x.id)>String(target.id))))continue;
   if(x.status==='live')return false;
   const end=Math.max(x.startMinute+(x.durationMinutes??150),x.completedGameMinute??0);
   if(samePlayer&&x.competition!==target.competition&&Math.floor(x.startMinute/1440)===Math.floor(abs/1440))return false;
   if(x.startMinute<=abs&&abs<end+Math.max(samePlayer?60:0,sameCourt?15:0))return false;
  }
  return true;
 }
 // Keep due original slot only on the original day and within the phase.
 if(current<=(last+1)*1440-1&&Math.floor(current/1440)===Math.floor(original/1440)&&available(current,preferred))return {status:'ready',court:preferred,gameMinute:current};
 // Unknown live finish is a reason to hold, not to fabricate an end time.
 if(relevant.some(x=>x.status==='live'&&(x.players.some(p=>target.players.includes(p))||x.competition===target.competition&&max===1)))return {status:'waiting_live_conflict'};
 for(let day=Math.max(Math.floor(original/1440),Math.floor(current/1440),first);day<=last;day++){
  for(let minute=600;minute<=1290;minute+=30){
   const abs=day*1440+minute;if(abs<=current+10||abs<original)continue;
   for(let i=0;i<max;i++){const court=(preferred-1+i)%max+1;if(available(abs,court))return {status:'rescheduled',court,gameMinute:abs,week:target.firstWeek+Math.floor((day-first)/7),day:(day-first)%7+1,minute};}
  }
 }
 return {status:'blocked',reason:'no_safe_slot_in_phase'};
}
module.exports={plan,duration};
