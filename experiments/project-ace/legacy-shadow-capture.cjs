'use strict';
// Offline validation, not proof of historical pre-match input provenance.
const {digest,compare}=require('./shadow-comparison.cjs');
const check=(v,m)=>{if(!v)throw Error(m)},int=(x,min=0)=>Number.isSafeInteger(x)&&x>=min;
const fields=['aces','double_faults','first_serves_in','first_serves_total','first_serve_points_won','first_serve_points_played','second_serve_points_won','second_serve_points_played','break_points_won','break_points_total','winners','unforced_errors','total_points_won'];
const setFields=['set_number','player1_games','player2_games','player1_tiebreak_points','player2_tiebreak_points'];
function normalized(input,capture,link){
 check(capture?.schema==='ace-legacy-shadow-capture-v1'&&typeof capture.restore_id==='string'&&capture.restore_id.length>0,'Invalid restored capture');
 const m=capture.match,s=capture.simulation;
 check(m&&s&&m.id===input.match_id&&m.competition_id===input.competition_id&&s.match_id===m.id&&m.player1_id===input.player_ids[0]&&m.player2_id===input.player_ids[1],'Match identity mismatch');
 check(m.status==='completed'&&s.simulation_status==='completed'&&m.completion_reason==null&&m.winner_id===s.final_winner_id&&input.player_ids.includes(m.winner_id)&&int(m.actual_duration_minutes,1),'Completed played match required');
 check(typeof m.started_at==='string'&&typeof m.completed_at==='string'&&Number.isFinite(Date.parse(m.started_at))&&Date.parse(m.completed_at)>=Date.parse(m.started_at),'Invalid completion timestamps');
 for(const k of ['draw_type','round_label','scheduled_season_week','scheduled_day','scheduled_start_minute','court_number'])check(m[k]===input.snapshot.match[k],'Source schedule or phase changed: '+k);
 check(typeof s.engine_version==='string'&&s.engine_version.length>0&&typeof s.engine_seed==='string'&&s.engine_seed.length>0&&int(s.total_games,1)&&int(s.total_points,1),'Missing simulation evidence');
 check(Array.isArray(capture.routines)&&new Set(capture.routines.map(x=>x.signature)).size===capture.routines.length&&capture.routines.every(x=>typeof x.signature==='string'&&/^[a-f0-9]{32}$/.test(x.definition_md5)),'Invalid routine inventory');
 for(const name of ['simulate_tournament_match_v1','prepare_tournament_match_simulation_v1','finalize_match_replay_v1','get_match_engine_profile_v1','simulated_tennis_duration_minutes_v1'])check(capture.routines.some(x=>x.signature.startsWith('public.'+name+'(')||x.signature.startsWith(name+'(')),'Missing routine fingerprint: '+name);
 check(Array.isArray(capture.sets)&&Array.isArray(s.sets_payload)&&capture.sets.length===s.sets_payload.length&&capture.sets.length>=2,'Incomplete set evidence');
 const sets=capture.sets.map((x,i)=>{
  const y=s.sets_payload[i];check(y&&x.status==='completed'&&x.set_number===i+1&&setFields.every(k=>(x[k]??null)===(y[k]??null)),'Simulation/set disagreement');
  return {games:[x.player1_games,x.player2_games],tiebreak:x.player1_tiebreak_points==null&&x.player2_tiebreak_points==null?null:[x.player1_tiebreak_points,x.player2_tiebreak_points]};
 });
 check(Array.isArray(capture.stats)&&capture.stats.length===2,'Incomplete official statistics');
 const stats=capture.stats.map((x,i)=>{
  const y=i===0?s.player1_stats:s.player2_stats;check(x.player_id===input.player_ids[i]&&y&&fields.every(k=>int(x[k])&&x[k]===y[k]),'Simulation/statistics disagreement');
  return Object.fromEntries(fields.map(k=>[k,x[k]]));
 });
 check(sets.reduce((n,x)=>n+x.games[0]+x.games[1],0)===s.total_games&&stats.reduce((n,x)=>n+x.total_points_won,0)===s.total_points,'Simulation totals disagree');
 // Link is external attestation, not self-verifying proof that the snapshot was captured before legacy preparation.
 check(link?.schema==='ace-legacy-shadow-link-v1'&&link.input_sha256===input.input_sha256&&link.capture_sha256===digest(capture)&&link.restore_id===capture.restore_id&&link.legacy_engine_seed===s.engine_seed&&link.routine_inventory_sha256===digest(capture.routines)&&link.pre_match_capture_attested===true,'Missing or conflicting pre-match linkage');
 const observation={schema:'ace-shadow-legacy-observation-v1',input_sha256:input.input_sha256,match_id:m.id,competition_id:m.competition_id,source_revision:input.source_revision,player_ids:[m.player1_id,m.player2_id],engine_version:s.engine_version,status:m.status,winner_id:m.winner_id,sets,stats,actual_duration_minutes:m.actual_duration_minutes};
 const report=compare(input,observation);
 return {schema:'ace-legacy-shadow-capture-review-v1',review_only:true,production_ready:false,legacy_authority_verified:false,restore_id:capture.restore_id,capture_sha256:digest(capture),link_sha256:digest(link),observation,comparison:report,status:'linked_capture_review',limitations:['Restore marker and external attestation do not authenticate historical inputs','Routine hashes identify restored definitions, not necessarily the historical executing version','Schedule changes and special outcomes require separate review','No production database or legacy invocation']};
}
module.exports={normalized};
