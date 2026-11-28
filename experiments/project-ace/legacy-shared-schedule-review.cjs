'use strict';
// Offline shared inventory gate; no locks, writes or source authority.
const {adapt}=require('./legacy-tournament-adapter-review.cjs'),eligibility=require('./legacy-eligibility-review.cjs');
const {slot}=require('./world-clock.cjs'),{duration}=require('./schedule-gate.cjs'),{digest}=require('./shadow-comparison.cjs');
const check=(x,m)=>{if(!x)throw Error(m)};
const int=(x,l=0,h=Number.MAX_SAFE_INTEGER)=>Number.isSafeInteger(x)&&x>=l&&x<=h;
const id=x=>typeof x==='string'&&x.trim()===x&&x.length>0&&x.length<=120;
const overlap=(a,b)=>a.some(x=>b.includes(x));
const day=x=>Math.floor(x/1440);
function normalize(r){
 check(r&&id(r.id)&&id(r.competition_id)&&id(r.venue_id)&&['singles','doubles'].includes(r.kind)&&['scheduled','live','completed','walkover'].includes(r.status)&&id(r.revision),'Invalid inventory identity');
 check(Array.isArray(r.players)&&r.players.every(id)&&new Set(r.players).size===r.players.length,'Invalid inventory participants');
 const count=r.kind==='singles'?2:4;
 check(r.players.length===count||(r.status==='scheduled'&&r.players.length===0),'Incomplete participant assignment');
 check(int(r.start_minute)&&int(r.court,1,100)&&int(r.estimated_duration_minutes,1,420)&&int(r.recovery_minutes,60,1440),'Invalid inventory timing');
 if(r.status==='completed')check(int(r.actual_end_minute,r.start_minute+1)&&[null,...r.players].includes(r.winner_id)&& (r.kind!=='singles'||r.players.includes(r.winner_id)),'Invalid completed inventory');
 else if(r.status==='walkover')check(int(r.actual_end_minute,r.start_minute)&&r.kind==='singles'&&r.players.includes(r.winner_id),'Invalid walkover inventory');
 else check(r.actual_end_minute===null&&r.winner_id===null,'Unexpected terminal evidence');
 return {id:r.id,competition_id:r.competition_id,venue_id:r.venue_id,kind:r.kind,status:r.status,revision:r.revision,players:[...r.players],start_minute:r.start_minute,court:r.court,estimated_duration_minutes:r.estimated_duration_minutes,recovery_minutes:r.recovery_minutes,actual_end_minute:r.actual_end_minute,winner_id:r.winner_id};
}
function prepare(source,e){
 const admission=adapt(source);
 check(e?.schema==='ace-legacy-shared-schedule-observation-v1'&&e.complete_inventory_attested===true&&e.consistent_snapshot_attested===true,'Complete shared scheduling evidence required');
 check(e.competition_id===admission.frozen.competition_id&&id(e.inventory_revision)&&int(e.game_second)&&typeof e.speed==='number'&&Number.isFinite(e.speed)&&e.speed>=0&&e.speed<=1000,'Invalid schedule identity or clock');
 const policy=e.policy;
 check(policy&&id(policy.venue_id)&&int(policy.first_week,1,52)&&int(policy.last_week,policy.first_week,52)&&int(policy.court_count,1,100),'Invalid main draw phase or venue');
 const season=admission.frozen.season_number,first=slot(season,policy.first_week,1,0)/60,last=slot(season,policy.last_week,7,0)/60+1439;
 check(Array.isArray(e.inventory),'Complete match inventory required');
 const rows=e.inventory.map(normalize).sort((a,b)=>a.id.localeCompare(b.id));
 check(new Set(rows.map(r=>r.id)).size===rows.length,'Duplicate inventory match');
 const by=new Map(rows.map(r=>[r.id,r]));
 const sourceIds=new Set(source.matches.map(m=>m.id));
 for(const m of source.matches){
  const r=by.get(m.id),start=slot(season,m.scheduled_season_week,m.scheduled_day,m.scheduled_start_minute)/60;
  check(r&&r.kind==='singles'&&r.competition_id===m.competition_id&&r.venue_id===policy.venue_id&&r.court<=policy.court_count&&r.start_minute>=first&&r.start_minute<=last,'Missing or invalid source schedule row');
  // Original first-round participants never change. Later matches require
  // ordered feeder winners, not predicted or manually assigned identities.
  if(m.round_number===1)check(digest(r.players)===digest([m.player1_id,m.player2_id]),'First-round participants changed');
  if(r.status==='scheduled'&&m.id===e.match_id)check(r.revision===m.updated_at&&r.start_minute===start&&r.court===m.court_number&&r.estimated_duration_minutes===m.estimated_duration_minutes,'Target slot or revision changed; re-extract');
 }
 check(rows.every(r=>r.competition_id!==e.competition_id||r.kind!=='singles'||sourceIds.has(r.id)),'Unexpected same-competition singles match');
 const m=admission.frozen.matches.find(x=>x.match_id===e.match_id),target=by.get(e.match_id);
 check(m&&target&&target.status==='scheduled','Scheduled target required');
 const now=Math.floor(e.game_second/60),original=target.start_minute;
 let feederStatus='ready',feederEarliest=0;
 if(m.feeder1!==null){
  const feeders=[by.get(m.feeder1),by.get(m.feeder2)];
  if(!feeders.every(x=>['completed','walkover'].includes(x.status)))feederStatus='feeders_pending';
  else if(feeders[0].winner_id===feeders[1].winner_id||digest(target.players)!==digest(feeders.map(x=>x.winner_id)))feederStatus='feeder_winner_mismatch';
  else {feederEarliest=Math.max(...feeders.map(x=>x.actual_end_minute+(x.status==='walkover'?0:60)));feederStatus='owner_receipt_verification_required';}
 }
 function conflicts(start,court){
  const out=[];
  for(const r of rows){
   if(r.id===target.id||r.status==='walkover')continue;
   const samePlayer=overlap(r.players,target.players),sameCourt=r.venue_id===target.venue_id&&r.court===court;
   if(!samePlayer&&!sameCourt)continue;
   if(r.status==='live'){out.push({id:r.id,reason:'live_resource'});continue;}
   const end=r.status==='completed'?r.actual_end_minute:r.start_minute+r.estimated_duration_minutes;
   const rest=Math.max(r.recovery_minutes,target.recovery_minutes);
   if(samePlayer&&r.competition_id!==target.competition_id&&day(r.start_minute)===day(start)){out.push({id:r.id,reason:'cross_competition_day'});continue;}
   const buffer=Math.max(samePlayer?rest:0,sameCourt?15:0);
   if(start<end+buffer&&r.start_minute<start+target.estimated_duration_minutes+buffer)out.push({id:r.id,reason:samePlayer?'player_rest_or_overlap':'court_overlap'});
  }
  return out;
 }
 let status='ready_for_review',proposed=null,blockers=[];
 if(e.speed===0)status='paused';
 else if(e.game_second<original*60)status='not_due';
 else if(feederStatus!=='ready')status=feederStatus;
 else if(now!==original)status='fresh_slot_required';
 else if(original%1440<600||original%1440>1290){status='blocked';blockers=[{id:target.id,reason:'outside_start_window'}];}
 else {
  blockers=conflicts(original,target.court);
  if(blockers.length){
   status='blocked';
   // Proposed future slots are non-authoritative. Never reserve resources here.
   for(let d=Math.max(day(original),day(now));d<=day(last)&&!proposed;d++){
    for(let minute=600;minute<=1290&&!proposed;minute+=30){
     const start=d*1440+minute;if(start<=now+10||start<original||start<first||start>last)continue;
     for(let i=0;i<policy.court_count;i++){
      const court=(target.court-1+i)%policy.court_count+1;
      if(!conflicts(start,court).length){proposed={start_minute:start,court};break;}
     }
    }
   }
   if(proposed)status='reschedule_review';
  }
 }
 const body={schema:'ace-legacy-shared-schedule-review-v1',review_only:true,production_ready:false,activation_authorized:false,source_authenticated:false,admission_sha256:admission.source_sha256,inventory_revision:e.inventory_revision,game_second:e.game_second,speed:e.speed,policy:{venue_id:policy.venue_id,first_week:policy.first_week,last_week:policy.last_week,court_count:policy.court_count},inventory:rows,target_id:target.id,target_revision:target.revision,feeder_status:feederStatus,feeder_earliest_minute:feederEarliest,status,blockers,proposed};
 return {...body,schedule_sha256:digest(body)};
}
function execute(source,e,expectedScheduleSha,health,expectedHealthSha,context=null,observations=null,expectedEffectsSha=null){
 const g=prepare(source,e);
 check(g.schedule_sha256===expectedScheduleSha,'Schedule evidence changed');
 if(g.status!=='ready_for_review')return {review_only:true,production_ready:false,status:'held',schedule_status:g.status,schedule_sha256:expectedScheduleSha,proposed:g.proposed};
 check(health?.match_id===g.target_id&&health.match_updated_at===g.target_revision&&health.observed_absolute_minute===Math.floor(g.game_second/60),'Health and scheduling evidence mismatch');
 const result=eligibility.execute(source,health,expectedHealthSha,context,observations,expectedEffectsSha);
 const target=g.inventory.find(x=>x.id===g.target_id);
 let followups=[],playedMinutes=null;
 if(result.status==='simulated_review'){
  const r=result.result,games=r.sets.reduce((n,s)=>n+s.games[0]+s.games[1],0);
  playedMinutes=duration(games,r.total_points);
  const end=target.start_minute+playedMinutes;
  followups=g.inventory.filter(x=>x.id!==target.id&&x.status==='scheduled'&&x.start_minute>=target.start_minute).flatMap(x=>{
   const samePlayer=overlap(x.players,target.players),sameCourt=x.venue_id===target.venue_id&&x.court===target.court;
   const earliest=Math.max(samePlayer?end+Math.max(x.recovery_minutes,target.recovery_minutes):0,sameCourt?end+15:0);
   return earliest>x.start_minute?[{match_id:x.id,revision:x.revision,earliest_minute:earliest}]:[];
  });
  const bracket=adapt(source).frozen.matches;
  const next=bracket.find(x=>x.feeder1===target.id||x.feeder2===target.id);
  if(next){const row=g.inventory.find(x=>x.id===next.match_id);if(row.start_minute<end+60){const existing=followups.find(x=>x.match_id===row.id);if(existing)existing.earliest_minute=Math.max(existing.earliest_minute,end+60);else followups.push({match_id:row.id,revision:row.revision,earliest_minute:end+60});}}
 }
 return {review_only:true,production_ready:false,activation_authorized:false,status:result.status,schedule_sha256:expectedScheduleSha,eligibility_result:result,played_minutes:playedMinutes,followup_review_obligations:followups};
}
module.exports={prepare,execute};
