'use strict';
// Experimental mapping to Ace match checkpoint, not a verified official simulator formula.
const keys=['serve','return','rally','forehand','backhand','movement','stamina','fitness','smash','slice','volley'];
const finite=(x,min,max)=>typeof x==='number'&&Number.isFinite(x)&&x>=min&&x<=max;
function validate(penalty,skills){
 if(!finite(penalty,0,.5)||!skills||typeof skills!=='object'||Array.isArray(skills)||Object.entries(skills).some(([k,v])=>!keys.includes(k)||!finite(v,-.4,0)))throw Error('Invalid health performance effects');
}
function effects(records,day){
 if(!Number.isSafeInteger(day)||day<0||!Array.isArray(records))throw Error('Invalid health effects date');
 let penalty=0;const skills={};
 for(const r of records){
  validate(r.performancePenalty,r.skillEffects);
  if(r.status==='recovered'||day>=r.fullRecoveryDay||day<r.onsetDay)continue;
  const remaining=Math.max(0,Math.min(1,(r.fullRecoveryDay-day)/Math.max(1,r.fullRecoveryDay-r.onsetDay)));
  penalty=Math.min(.35,penalty+r.performancePenalty*remaining);
  for(const [k,v] of Object.entries(r.skillEffects))skills[k]=Math.max(-.4,(skills[k]??0)+v*remaining);
 }
 return {penalty,skills};
}
function apply(player,records,day){
 const e=effects(records,day);
 for(const k of keys){
  if(!Number.isFinite(player[k]))continue;
  // Generic reduction only for aggregate shot ratings. Specific supported skills are separate.
  const general=['serve','return','rally'].includes(k)?1-e.penalty:1;
  player[k]=Math.max(0,Math.min(100,player[k]*general*(1+(e.skills[k]??0))));
 }
 if(Number.isFinite(player.rawServe))player.rawServe=Math.max(0,Math.min(100,player.rawServe*(1-e.penalty)*(1+(e.skills.serve??0))));
 return e;
}
module.exports={validate,effects,apply};
