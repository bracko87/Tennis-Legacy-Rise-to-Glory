'use strict';
// Offline adapter for actual Legacy-shaped tournament rows. No database I/O.
// Complete and consistent input is an external attestation, not verified source authority.
const {freeze}=require('./source-admission-review.cjs'),{digest}=require('./shadow-comparison.cjs');
const check=(v,m)=>{if(!v)throw Error(m)},uuid=x=>typeof x==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(x),time=x=>typeof x==='string'&&Number.isFinite(Date.parse(x));
const fields=['id','competition_id','draw_type','round_number','match_number','status','started_at','completed_at','winner_id','player1_id','player2_id','scheduled_season_week','scheduled_day','scheduled_start_minute','court_number'];
function adapt(s){
 check(s?.schema==='ace-legacy-tournament-export-v1'&&s.complete_export===true&&s.consistent_snapshot_attested===true,'Complete consistent export required');
 const {competition:c,edition:e,publication:d,entry_cycle:l}=s;
 check(c&&e&&d&&l&&uuid(c.id)&&uuid(e.id)&&c.tournament_edition_id===e.id&&d.competition_id===c.id&&l.competition_id===c.id,'Competition linkage mismatch');
 check(['ATP','WTA'].includes(c.world)&&c.status==='registration_closed'&&['registration_closed','in_progress'].includes(e.status),'Unsupported competition or edition phase');
 check(time(l.field_locked_at)&&Number.isSafeInteger(l.field_locked_game_second)&&l.field_locked_game_second>=0,'Missing field lock');
 check(Number.isSafeInteger(d.main_draw_size)&&[8,16,32,64,128].includes(d.main_draw_size)&&d.qualifying_draw_size===0&&d.qualifier_slots===0,'Qualification or unsupported draw');
 for(const k of ['entries','matches','results','simulations','cancellations'])check(Array.isArray(s[k]),'Missing complete '+k+' inventory');
 check(s.results.length===0&&s.simulations.length===0&&s.cancellations.length===0,'Existing results, simulations or cancellations');
 const size=d.main_draw_size;
 check(s.entries.length===size&&s.matches.length===size-1,'Incomplete full draw');
 const slots=new Map(),ids=new Set(),players=new Set();
 for(const a of s.entries){
  check(uuid(a.id)&&!ids.has(a.id)&&uuid(a.player_id)&&!players.has(a.player_id)&&a.competition_id===c.id&&a.world===c.world&&a.draw_type==='main_draw'&&a.entry_status==='active','Invalid active main draw entry');
  check(Number.isSafeInteger(a.bracket_slot)&&a.bracket_slot>=1&&a.bracket_slot<=size&&!slots.has(a.bracket_slot),'Invalid bracket slot');
  ids.add(a.id);players.add(a.player_id);slots.set(a.bracket_slot,a.player_id);
 }
 const matches=s.matches.map(m=>{
  check(uuid(m.id)&&m.competition_id===c.id&&m.bracket_size===size&&m.draw_type==='main_draw'&&m.status==='scheduled'&&m.completion_reason===null&&m.actual_duration_minutes===null&&m.schedule_reason==='standard','Unsupported existing match state');
  check(time(m.updated_at)&&typeof m.round_label==='string'&&m.round_label.length>0&&Number.isSafeInteger(m.estimated_duration_minutes)&&m.estimated_duration_minutes>=30&&m.estimated_duration_minutes<=360,'Missing source match metadata');
  for(const k of fields)check(Object.hasOwn(m,k),'Missing match field '+k);
  if(m.round_number===1)check(m.player1_id===slots.get(m.match_number*2-1)&&m.player2_id===slots.get(m.match_number*2),'Bracket participant mismatch');
  return Object.fromEntries(fields.map(k=>[k,m[k]]));
 });
 const frozen=freeze({schema:'ace-source-admission-v1',complete_export:true,competition:{id:c.id,scope:'singles',field_locked:true,qualification_required:false,status:'published',season_number:e.season_number,draw_size:size},players:[...players].sort().map(id=>({id})),matches,results:[],simulations:[]});
 const evidence={competition_id:c.id,edition_id:e.id,world:c.world,field_locked_at:l.field_locked_at,field_locked_game_second:l.field_locked_game_second,publication:{main_draw_size:size,qualifying_draw_size:d.qualifying_draw_size,qualifier_slots:d.qualifier_slots},matches:s.matches.map(m=>({id:m.id,updated_at:m.updated_at,round_label:m.round_label,estimated_duration_minutes:m.estimated_duration_minutes,schedule_reason:m.schedule_reason})).sort((a,b)=>a.id.localeCompare(b.id))};
 return {schema:'ace-legacy-tournament-adapter-review-v1',review_only:true,production_ready:false,activation_authorized:false,source_authenticated:false,source_sha256:digest(evidence),evidence,frozen};
}
module.exports={adapt};
