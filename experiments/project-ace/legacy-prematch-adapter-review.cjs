'use strict';
// Offline mapping of reviewed, pre-match Legacy profile observations. No live calls.
const {adapt}=require('./legacy-tournament-adapter-review.cjs'),{freeze,digest}=require('./shadow-comparison.cjs'),{importSnapshot}=require('./legacy-snapshot.cjs');
const check=(v,m)=>{if(!v)throw Error(m)};
const groups={technical:['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash'],physical:['fitness','stamina','recovery','movement'],condition:['fatigue','sharpness','morale','confidence','focus']};
const gear=['standard','performance','missing-racket','missing-shoes','missing-apparel'];
function adaptMatch(source,context){
 const admission=adapt(source);
 check(context?.schema==='ace-legacy-prematch-observation-v1'&&context.consistent_pre_match_attested===true,'Consistent pre-match observation required');
 const {edition:e,series:s,weather:w,players}=context;
 const m=source.matches.find(x=>x.id===context.match_id);
 check(m&&m.round_number===1&&m.updated_at===context.match_updated_at&&context.competition_id===admission.frozen.competition_id,'Unmatched or stale first-round match');
 check(e&&s&&e.id===source.edition.id&&e.season_number===source.edition.season_number&&e.tournament_series_id===s.id&&typeof s.id==='string'&&s.id.length>0,'Tournament series linkage required');
 check(typeof s.surface==='string'&&['hard','clay','grass'].includes(s.surface.toLowerCase())&&['indoor','outdoor'].includes(s.environment),'Unsupported surface or environment');
 const surface=s.surface.toLowerCase();
 check(w&&w.status==='ready'&&w.environment===s.environment&&w.can_delay_match===false&&typeof w.seed==='string'&&w.seed.length>0,'Explicit non-delayed weather required');
 check(Array.isArray(players)&&players.length===2,'Two ordered player observations required');
 const converted=players.map((x,i)=>{
  const p=x?.profile,id=i===0?m.player1_id:m.player2_id;
  check(p&&p.player_id===id&&typeof p.surface==='string'&&p.surface.toLowerCase()===surface,'Player order, identity or surface mismatch');
  check(['left','right'].includes(x.playing_hand)&&gear.includes(x.equipment_class)&&typeof x.equipment_evidence==='string'&&x.equipment_evidence.trim().length>0,'Explicit hand and reviewed equipment classification required');
  check(typeof p.preferred_surface==='string'&&['hard','clay','grass'].includes(p.preferred_surface.toLowerCase())&&typeof p.playing_style==='string','Explicit preference and style required');
  const skills={player_id:id,preferred_surface:p.preferred_surface,playing_style:p.playing_style};
  for(const [group,keys] of Object.entries(groups))for(const k of keys){const v=p[group]?.[k];check(Number.isSafeInteger(v)&&v>=(k==='fatigue'?0:1)&&v<=100,'Missing or invalid raw '+k);skills[k]=v;}
  return {player:{id,first_name:'Review',last_name:'Player '+(i+1),playing_hand:x.playing_hand},skills,equipment:x.equipment_class};
 });
 const snapshot={schema:'ace-legacy-snapshot-v1',match:{status:m.status,surface,world:source.competition.world,category_code:s.category_code,draw_type:m.draw_type,tournament_name:s.name,city:s.city,country_code:s.country_code,round_label:m.round_label,scheduled_season_week:m.scheduled_season_week,scheduled_day:m.scheduled_day,scheduled_start_minute:m.scheduled_start_minute,court_number:m.court_number},players:converted,weather:{environment:w.environment,temperatureC:w.temperature_c,windKmh:w.wind_kmh,precipitation:w.precipitation}};
 const normalized=importSnapshot(snapshot);
 const frozen=freeze({match_id:m.id,competition_id:m.competition_id,source_revision:context.review_revision,snapshot,seed:context.ace_seed});
 const evidence={admission_sha256:admission.source_sha256,match_updated_at:m.updated_at,series_id:s.id,edition_id:e.id,weather_seed:w.seed,equipment_evidence:players.map(x=>x.equipment_evidence),input_sha256:frozen.input_sha256};
 return {schema:'ace-legacy-prematch-adapter-review-v1',review_only:true,production_ready:false,source_authenticated:false,equipment_authority_verified:false,activation_authorized:false,evidence,evidence_sha256:digest(evidence),best_of:normalized.bestOf,frozen};
}
module.exports={adaptMatch};
