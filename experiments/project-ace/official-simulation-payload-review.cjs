'use strict';
// Review-only projection. No official writes; weather and duration metadata must be independently sourced.
const {isDeepStrictEqual}=require('node:util'),{duration}=require('./schedule-gate.cjs');
const check=(v,m)=>{if(!v)throw Error(m);};
function project(match,evidence){
 check(match?.status==='completed'&&match.completion_reason!=='health_walkover','Played completion required');
 check(match.player1_id&&match.player2_id&&match.player1_id!==match.player2_id&&[match.player1_id,match.player2_id].includes(match.winner_id),'Invalid participants');
 check(Array.isArray(match.sets)&&match.sets.length>=2&&Array.isArray(match.stats)&&match.stats.length===2,'Missing played statistics');
 check(evidence?.match_id===match.match_id&&evidence.player1_id===match.player1_id&&evidence.player2_id===match.player2_id,'Evidence participant order mismatch');
 check(typeof evidence.engine_seed==='string'&&evidence.engine_seed.length>0&&typeof match.engine_version==='string'&&match.engine_version.length>0,'Missing engine evidence');
 check(Number.isInteger(evidence.estimated_match_minutes)&&evidence.estimated_match_minutes>=20&&evidence.estimated_match_minutes<=480,'Missing duration metadata');
 check(evidence.weather&&typeof evidence.weather.heat_index==='number'&&Number.isFinite(evidence.weather.heat_index)&&typeof evidence.weather_source==='string'&&evidence.weather_source.length>0,'Missing weather evidence');
 const games=match.sets.reduce((n,s)=>n+s.player1_games+s.player2_games,0),points=match.stats.reduce((n,s)=>n+s.total_points_won,0);
 check(Number.isSafeInteger(games)&&Number.isSafeInteger(points)&&games>0&&points>0&&duration(games,points)===match.actual_duration_minutes,'Duration mismatch');
 check(match.stats.every((s,i)=>s.player_id===[match.player1_id,match.player2_id][i]&&s.match_id===match.match_id),'Statistics participant mismatch');
 check(match.sets.every((s,i)=>s.match_id===match.match_id&&s.set_number===i+1&&s.status==='completed'),'Set order mismatch');
 const replay=evidence.replay;
 check(replay?.player1_id===match.player1_id&&replay.player2_id===match.player2_id&&replay.winner_id===match.winner_id&&replay.final_score===match.score,'Replay identity mismatch');
 check(Array.isArray(replay.events)&&replay.events.length>1&&replay.events[0].kind==='match_start'&&replay.events.at(-1).kind==='match_end','Incomplete replay');
 check(replay.events.filter(e=>e.kind==='point').length===points&&replay.events.every((e,i)=>Number.isFinite(e.offset_seconds)&&e.offset_seconds>=0&&(i===0||e.offset_seconds>=replay.events[i-1].offset_seconds)),'Invalid replay sequence');
 check(Number.isInteger(replay.schema_version)&&replay.schema_version>0&&Number.isInteger(replay.duration_seconds)&&replay.duration_seconds>=replay.events.at(-1).offset_seconds,'Invalid replay duration');
 const stats=match.stats.map(({match_id,player_id,...s})=>s);
 return JSON.parse(JSON.stringify({review_only:true,production_ready:false,simulation:{match_id:match.match_id,simulation_status:'completed',engine_version:match.engine_version,engine_seed:evidence.engine_seed,replay_schema_version:replay.schema_version,replay_duration_seconds:replay.duration_seconds,total_points:points,total_games:games,final_winner_id:match.winner_id,final_score:match.score,sets_payload:match.sets.map(({match_id,...s})=>s),player1_stats:stats[0],player2_stats:stats[1],events_payload:replay.events,metadata:{estimated_match_minutes:evidence.estimated_match_minutes,weather:evidence.weather}},weather_source:evidence.weather_source,actual_duration_minutes:match.actual_duration_minutes,required_order:['stage_official_simulation','stage_sets_and_statistics','transition_match_completed_once','reconcile_existing_trigger_effects'],blockers:['authentic replay schema and event semantics verification','authoritative weather and estimated duration provenance','shared transactional authority','special completion reason handling']}));
}
module.exports={project};
