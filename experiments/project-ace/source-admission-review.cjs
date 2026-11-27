'use strict';
// Offline source contract, deliberately limited to new, full, main-draw singles.
// No external connection, official mutation, claim or enablement.
const {isDeepStrictEqual}=require('node:util'),{createHash}=require('node:crypto');
const check=(x,m)=>{if(!x)throw Error(m);},id=x=>typeof x==='string'&&x.trim()===x&&x.length>0&&x.length<=120;
const natural=x=>Number.isSafeInteger(x)&&x>=1;
const unique=(xs,key)=>{check(Array.isArray(xs),'Complete inventory required');const out=new Map();for(const x of xs){const k=key(x);check(id(k)&&!out.has(k),'Missing or duplicate source identity');out.set(k,x);}return out;};
const position=m=>m.round_number+':'+m.match_number;
const copy=x=>JSON.parse(JSON.stringify(x));
const terminal=new Set(['completed','walkover','bye','cancelled']);
function freeze(source){
 check(source?.schema==='ace-source-admission-v1'&&source.complete_export===true,'Complete source export required');
 const c=source.competition;
 check(c&&id(c.id)&&c.scope==='singles'&&c.field_locked===true&&c.qualification_required===false&&c.status==='published','New locked main-draw singles only');
 check(natural(c.season_number)&&c.season_number<=10000,'Explicit source season required');
 check(natural(c.draw_size)&&[8,16,32,64,128].includes(c.draw_size),'Unsupported full draw size');
 check(Array.isArray(source.results)&&source.results.length===0&&Array.isArray(source.simulations)&&source.simulations.length===0,'Existing results or simulations require legacy');
 const players=unique(source.players,x=>x.id),matches=unique(source.matches,x=>x.id),pos=unique(source.matches,position);
 check(players.size===c.draw_size&&matches.size===c.draw_size-1,'Incomplete source draw');
 const entries=new Set();
 const rounds=Math.log2(c.draw_size),ordered=[];
 for(let round=1;round<=rounds;round++)for(let number=1;number<=c.draw_size/2**round;number++){
  const m=pos.get(round+':'+number);
  check(m&&m.competition_id===c.id&&m.draw_type==='main_draw'&&m.status==='scheduled'&&m.started_at===null&&m.completed_at===null&&m.winner_id===null,'Existing or foreign match state');
  check(natural(m.scheduled_season_week)&&m.scheduled_season_week<=52&&natural(m.scheduled_day)&&m.scheduled_day<=7&&Number.isSafeInteger(m.scheduled_start_minute)&&m.scheduled_start_minute>=0&&m.scheduled_start_minute<1440&&natural(m.court_number),'Invalid schedule');
  let feeder1=null,feeder2=null;
  if(round===1){
   for(const p of [m.player1_id,m.player2_id]){check(players.has(p)&&!entries.has(p),'Invalid first-round participant');entries.add(p);}
  }else{
   check(m.player1_id===null&&m.player2_id===null,'Future participant already assigned');
   feeder1=pos.get((round-1)+':'+(2*number-1)).id;
   feeder2=pos.get((round-1)+':'+(2*number)).id;
  }
  ordered.push({match_id:m.id,competition_id:c.id,round_number:round,match_number:number,draw_type:m.draw_type,scheduled_season_week:m.scheduled_season_week,scheduled_day:m.scheduled_day,scheduled_start_minute:m.scheduled_start_minute,court_number:m.court_number,player1_id:m.player1_id,player2_id:m.player2_id,feeder1,feeder2});
 }
 const body={schema:'ace-frozen-source-admission-v1',competition_id:c.id,season_number:c.season_number,draw_size:c.draw_size,matches:ordered};
 return {...body,sha256:createHash('sha256').update(JSON.stringify(body)).digest('hex')};
}
function assess(frozen,observation,policy){
 const {sha256,...body}=frozen;
 check(body.schema==='ace-frozen-source-admission-v1'&&sha256===createHash('sha256').update(JSON.stringify(body)).digest('hex'),'Frozen source contract changed');
 check(observation?.complete_export===true&&observation.competition_id===body.competition_id,'Complete same-competition observation required');
 const matches=unique(observation.matches,x=>x.id),sim=unique(observation.simulations,x=>x.match_id);
 check(matches.size===body.matches.length,'Match inventory changed');
 const contract=unique(body.matches,x=>x.match_id);
 check([...sim.keys()].every(k=>contract.has(k)),'Foreign simulation row');
 const enabled=policy?.enabled===true&&Array.isArray(policy.competitions)&&policy.competitions.includes(body.competition_id);
 const rows=[];
 for(const m of body.matches){
  const row=matches.get(m.match_id);check(row,'Source match missing');
  for(const k of ['competition_id','round_number','match_number','draw_type','scheduled_season_week','scheduled_day','scheduled_start_minute','court_number'])check(row[k]===m[k],'Source schedule or topology changed: '+m.match_id);
  let reason='review_candidate';
  if(!enabled)reason='routing_disabled';
  else if(row.status!=='scheduled'||row.started_at!==null||row.completed_at!==null||row.winner_id!==null||sim.has(m.match_id))reason='legacy_or_existing_state';
  else if(m.feeder1===null){
   check(row.player1_id===m.player1_id&&row.player2_id===m.player2_id,'First-round participants changed');
  }else{
   const a=matches.get(m.feeder1),b=matches.get(m.feeder2);
   if(!terminal.has(a.status)||!terminal.has(b.status))reason='feeders_pending';
   else if(a.winner_id===null||b.winner_id===null)reason='special_result_review';
   else if(a.winner_id===b.winner_id||row.player1_id!==a.winner_id||row.player2_id!==b.winner_id)reason='feeder_winner_mismatch';
   // Source statuses alone do not establish owner/effect authenticity.
   else reason='owner_receipt_verification_required';
  }
  rows.push({match_id:m.match_id,competition_id:m.competition_id,feeder1:m.feeder1,feeder2:m.feeder2,player1_id:row.player1_id,player2_id:row.player2_id,status:reason});
 }
 return {schema:'ace-source-admission-assessment-v1',review_only:true,production_ready:false,competition_id:body.competition_id,source_sha256:sha256,rows};
}
module.exports={freeze,assess};
