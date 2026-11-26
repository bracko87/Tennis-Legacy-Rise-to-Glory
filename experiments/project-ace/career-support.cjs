'use strict';
// Pure, opt-in support snapshot. No mutation of official inventory/staff/health.
const clamp=(v,l,h)=>Math.max(l,Math.min(h,v));
const finite=(v,l,h,name)=>{if(typeof v!=='number'||!Number.isFinite(v)||v<l||v>h)throw Error('Invalid '+name);return v;};
const integer=(v,l,h,name)=>{finite(v,l,h,name);if(!Number.isInteger(v))throw Error('Invalid '+name);return v;};
const clone=x=>JSON.parse(JSON.stringify(x));
const categories=['racket','shoes','apparel'];
function resolveGear(inventory,loadout){
 if(!Array.isArray(inventory)||new Set(inventory.map(i=>i.id)).size!==inventory.length)throw Error('Invalid equipment inventory');
 for(const i of inventory){if(typeof i.id!=='string'||!i.id||!categories.includes(i.type))throw Error('Invalid item');finite(i.condition,0,100,'condition');}
 const selected={};for(const type of categories){
  const item=inventory.find(i=>i.id===loadout[type]&&i.type===type&&i.condition>0);
  selected[type]=item??null;
 }
 const missing=Object.fromEntries(categories.map(k=>[k,!selected[k]]));
 return {selected:clone(selected),missing,ratings:{serve:(missing.racket?.65:1)*(missing.apparel?.97:1),return:(missing.racket?.65:1)*(missing.shoes?.93:1)*(missing.apparel?.97:1),rally:(missing.racket?.65:1)*(missing.shoes?.93:1)*(missing.apparel?.97:1)}};
}
// Apply explicitly supplied wear units only. The real wear formula is not ported.
function wear(inventory,loadout,units){
 const before=resolveGear(inventory,loadout),items=clone(inventory),next={...loadout},events=[];
 for(const k of categories){
  const item=items.find(i=>i.id===before.selected[k]?.id);const n=finite(units[k]??0,0,100,'wear');if(!item||!n)continue;
  const old=item.condition;item.condition=Math.max(0,Math.round((old-n)*100)/100);
  if(item.condition===0){const replacement=items.filter(i=>i.type===k&&i.id!==item.id&&i.condition>0).sort((a,b)=>b.condition-a.condition||a.id.localeCompare(b.id))[0];next[k]=replacement?.id??null;events.push({type:'broken',id:item.id,replacement:next[k]});}
  else if(old>=20&&item.condition<20)events.push({type:'low',id:item.id});
 }
 return {inventory:items.filter(i=>i.condition>0),loadout:next,events};
}
function staff(input={}){
 return {matchFatigueReduction:finite(input.matchFatigueReduction??0,0,.10,'staff fatigue reduction'),injuryReduction:finite(input.injuryReduction??0,0,.12,'staff injury reduction'),recoveryMultiplier:finite(input.recoveryMultiplier??1,1,1.5,'recovery multiplier')};
}
function injuryRisk(p,{minutes=0,heat=0,activeInjuries=0,support={}}={}){
 finite(minutes,0,480,'minutes');finite(heat,0,2,'heat');integer(activeInjuries,0,100,'active injuries');
 const s=staff(support);let m=1;
 m*=p.fatigue>=80?2.4:p.fatigue>=65?1.75:p.fatigue>=50?1.30:1;
 m*=p.fitness<45?1.28:p.fitness>=70?.90:1;
 m*=p.recovery<45?1.20:p.recovery>=70?.92:1;
 if(p.movement<45)m*=1.12;if(minutes>120)m*=1+Math.min(.90,(minutes-120)/240);if(heat>0)m*=1+Math.min(.55,heat);if(activeInjuries>0)m*=1.35;
 return Math.round(clamp(.45*m*(1-s.injuryReduction),.03,7.5)*100)/100;
}
function eligibility(injuries,day){
 integer(day,0,Number.MAX_SAFE_INTEGER,'day');
 if(!Array.isArray(injuries))throw Error('Invalid injuries');
 for(const i of injuries){integer(i.tournamentReturnDay,0,Number.MAX_SAFE_INTEGER,'return day');integer(i.fullRecoveryDay,i.tournamentReturnDay,Number.MAX_SAFE_INTEGER,'recovery day');if(!['active','recovering','recovered'].includes(i.status))throw Error('Invalid injury status');}
 return {eligible:!injuries.some(i=>i.status!=='recovered'&&day<i.tournamentReturnDay),active:injuries.filter(i=>i.status!=='recovered'&&day<i.fullRecoveryDay).length};
}
function dayOff(p,support={}){
 const s=staff(support),base=Math.round(14+p.recovery*.10+p.fitness*.05+p.fatigue*.04);
 const reduction=Math.round(base*s.recoveryMultiplier);
 return {...p,fatigue:Math.max(0,p.fatigue-reduction),sharpness:Math.max(1,p.sharpness-1)};
}
function adjustedGain(gain,support={}){
 integer(gain,0,28,'career fatigue gain');return Math.max(0,gain-Math.round(gain*staff(support).matchFatigueReduction));
}
module.exports={resolveGear,wear,staff,injuryRisk,eligibility,dayOff,adjustedGain};
