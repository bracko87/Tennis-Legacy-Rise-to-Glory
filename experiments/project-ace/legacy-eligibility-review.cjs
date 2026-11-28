'use strict';
// Isolated review gate. Supplied observations are not authoritative RPC results.
const {adapt}=require('./legacy-tournament-adapter-review.cjs');
const effects=require('./legacy-prematch-effects-review.cjs');
const {digest}=require('./shadow-comparison.cjs');
const check=(v,m)=>{if(!v)throw Error(m)};
const int=x=>Number.isSafeInteger(x)&&x>=0;
function scheduled(source,matchId){
 const admission=adapt(source),m=source.matches.find(x=>x.id===matchId);
 check(m&&m.round_number===1&&m.started_at===null&&m.completed_at===null&&m.winner_id===null,'Unstarted first-round match required');
 const day=(source.edition.season_number-1)*366+2+(m.scheduled_season_week-1)*7+(m.scheduled_day-1);
 const minute=day*1440+m.scheduled_start_minute;
 check(int(day)&&int(minute),'Invalid absolute match slot');
 return {admission,m,day,minute};
}
function health(records,day){
 check(Array.isArray(records),'Complete injury and illness list required');
 const ids=new Set();
 const normalized=records.map(r=>{
  check(r&&typeof r.id==='string'&&r.id.trim()===r.id&&r.id.length>0&&!ids.has(r.kind+':'+r.id)&&['injury','illness'].includes(r.kind)&&['active','recovering','recovered'].includes(r.status),'Invalid or duplicate health row');
  ids.add(r.kind+':'+r.id);
  const a=r.onset_absolute_day,b=r.tournament_return_absolute_day,c=r.expected_full_recovery_absolute_day;
  check([a,b,c].every(int)&&a<=b&&b<=c&&a<=day,'Invalid health dates');
  check(typeof r.performance_penalty==='number'&&Number.isFinite(r.performance_penalty)&&r.performance_penalty>=0&&r.performance_penalty<=.5,'Invalid health penalty');
  return {id:r.id,kind:r.kind,status:r.status,onset_absolute_day:a,tournament_return_absolute_day:b,expected_full_recovery_absolute_day:c,performance_penalty:r.performance_penalty};
 }).sort((a,b)=>a.kind.localeCompare(b.kind)||a.id.localeCompare(b.id));
 const active=normalized.filter(r=>r.status!=='recovered');
 const blocked=active.filter(r=>day<r.tournament_return_absolute_day);
 // Inclusive return date; retain conservative hold through full-recovery day
 // until exact current Legacy performance modifiers are reconciled.
 return {records:normalized,blocked:blocked.length>0,earliest_return_day:blocked.length?Math.min(...blocked.map(r=>r.tournament_return_absolute_day)):null,performance_review_required:active.some(r=>day<=r.expected_full_recovery_absolute_day)};
}
function travel(t,target,day){
 check(t&&['normal','tight','impossible'].includes(t.status)&&t.target_absolute_minute===target,'Invalid or stale travel readiness');
 check(['planned_travel_leg','fallback_schedule'].includes(t.basis),'Unrecognized travel evidence basis');
 const {departure_absolute_minute:d,arrival_absolute_minute:a,ready_absolute_minute:r,pre_match_arrival_buffer_minutes:b}=t;
 check([d,a,r,b].every(int)&&a>=d&&r===a+b,'Invalid travel timeline or arrival buffer');
 const derived=r>target?'impossible':Math.floor(a/1440)>=day||d>(day-1)*1440+540?'tight':'normal';
 check(t.status===derived,'Travel readiness contradicts timeline');
 check(typeof t.actual_presence_confirmed==='boolean','Explicit presence evidence required');
 // A predicted arrival is not proof of presence. No travel no-show adjudication.
 return {status:derived,basis:t.basis,departure_absolute_minute:d,arrival_absolute_minute:a,ready_absolute_minute:r,pre_match_arrival_buffer_minutes:b,target_absolute_minute:target,actual_presence_confirmed:t.actual_presence_confirmed};
}
function prepare(source,e){
 check(e?.schema==='ace-legacy-match-eligibility-observation-v1'&&e.complete_health_attested===true&&e.consistent_snapshot_attested===true,'Complete consistent eligibility evidence required');
 const {admission,m,day,minute}=scheduled(source,e.match_id);
 check(e.competition_id===m.competition_id&&e.match_updated_at===m.updated_at&&e.match_absolute_day===day&&e.target_absolute_minute===minute,'Eligibility identity or schedule mismatch');
 check(int(e.observed_absolute_minute)&&e.observed_absolute_minute===minute,'Review requires evidence at exact scheduled game minute');
 check(Array.isArray(e.players)&&e.players.length===2,'Two ordered eligibility observations required');
 const players=e.players.map((p,i)=>{
  check(p&&p.player_id===[m.player1_id,m.player2_id][i]&&typeof p.evidence_revision==='string'&&p.evidence_revision.trim().length>0&&typeof p.human==='boolean','Eligibility participant evidence mismatch');
  check(['active','retired','unknown'].includes(p.career_status),'Explicit career status required');
  check(p.career_status==='active'||p.human,'Invalid AI career retirement evidence');
  const h=health(p.health_records,day);
  const t=p.human?travel(p.travel,minute,day):null;
  check(p.human||p.travel===null,'AI travel must be explicitly not applicable');
  return {player_id:p.player_id,human:p.human,evidence_revision:p.evidence_revision,career_status:p.career_status,health:h,travel:t};
 });
 let decision='ready_for_review',winner=null,blockers=[];
 for(const p of players){
  if(p.career_status!=='active')blockers.push(p.player_id+': career status requires official resolution');
  if(p.travel&&(p.travel.status==='impossible'||!p.travel.actual_presence_confirmed))blockers.push(p.player_id+': travel not ready or presence unconfirmed');
 }
 const blocked=players.filter(p=>p.health.blocked);
 // Mixed medical, travel, and guest cases are not assigned invented precedence.
 if(blockers.length)decision='hold';
 else if(blocked.length){
  decision='medical_walkover_review';
  winner=blocked.length===1?players.find(p=>!p.health.blocked).player_id:players[0].health.earliest_return_day<=players[1].health.earliest_return_day?players[0].player_id:players[1].player_id;
 }else{
  for(const p of players)if(p.health.performance_review_required)blockers.push(p.player_id+': current health performance modifiers require reconciliation');
  if(blockers.length)decision='hold';
 }
 const body={schema:'ace-legacy-match-eligibility-review-v1',review_only:true,production_ready:false,activation_authorized:false,source_authenticated:false,admission_sha256:admission.source_sha256,match_id:m.id,match_updated_at:m.updated_at,competition_id:m.competition_id,absolute_day:day,target_absolute_minute:minute,players,decision,winner_id:winner,blockers};
 return {...body,eligibility_sha256:digest(body)};
}
function execute(source,e,expectedSha,context=null,observations=null,expectedEffectsSha=null){
 const gate=prepare(source,e);
 check(gate.eligibility_sha256===expectedSha,'Eligibility evidence changed');
 if(gate.decision==='hold')return {review_only:true,production_ready:false,status:'held',eligibility_sha256:expectedSha,blockers:gate.blockers};
 if(gate.decision==='medical_walkover_review')return {review_only:true,production_ready:false,status:'walkover_review',completion_reason:'health_walkover',winner_id:gate.winner_id,match_id:gate.match_id,score:'W/O',total_points:0,total_games:0,sets:[],stats:[],engine_started:false,eligibility_sha256:expectedSha};
 check(context?.match_id===gate.match_id&&context.match_updated_at===gate.match_updated_at&&context.competition_id===gate.competition_id,'Simulation context does not match eligibility');
 check(Array.isArray(observations)&&observations.length===2&&observations.every((o,i)=>o.player_id===gate.players[i].player_id&&o.evidence_revision===gate.players[i].evidence_revision&&o.equipment?.human===gate.players[i].human),'Simulation evidence revision or participant mismatch');
 const result=effects.simulate(source,context,observations,expectedEffectsSha,'ace-tactical-review-0.6');
 return {review_only:true,production_ready:false,status:'simulated_review',eligibility_sha256:expectedSha,result};
}
module.exports={prepare,execute,health,travel};
