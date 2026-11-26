'use strict';
// Pure rehearsal: default legacy, opt-in new competitions, immutable active ownership.
const check=(x,m)=>{if(!x)throw Error(m);};
function choose(row,policy){
 check(row&&typeof row.id==='string'&&typeof row.competition==='string','Invalid match');
 check(['scheduled','in_progress','completed','bye','walkover','cancelled'].includes(row.status),'Unknown match state');
 check(['none','prepared','live','completed'].includes(row.legacySimulation),'Unknown simulation state');
 check(row.owner===null||['legacy','ace'].includes(row.owner),'Unknown owner');
 check(policy&&typeof policy.enabled==='boolean'&&Array.isArray(policy.competitions),'Invalid routing policy');
 if(row.owner!==null)return row.owner;
 if(row.status!=='scheduled'||row.legacySimulation!=='none'||row.started===true)return 'legacy';
 if(policy.enabled&&policy.competitions.includes(row.competition)&&row.scope==='singles'&&row.eligible===true)return 'ace';
 return 'legacy';
}
function action(row,policy,actor){
 check(['ace','legacy','watchdog','guest_retirement','travel_no_show','health_surrender','admin_repair'].includes(actor),'Unknown actor');
 const owner=choose(row,policy);
 if(actor===owner)return {owner,status:'owner_allowed'};
 if(['ace','legacy'].includes(actor))return {owner,status:'wrong_engine'};
 // External terminal mutations require an explicit owner-aware handoff;
 // do not silently drop legitimate retirement/no-show events.
 return {owner,status:'owner_aware_handoff_required'};
}
function rollback(rows){
 check(Array.isArray(rows),'Explicit owned match list required');
 const drain=[],retain=[];
 for(const row of rows){
  if(row.owner!=='ace')continue;
  if(row.status==='scheduled'||row.status==='in_progress')drain.push(row.id);
  else retain.push(row.id);
 }
 return {newAdmissions:'legacy',drain,retain,canRemoveAce:drain.length===0};
}
module.exports={choose,action,rollback};
