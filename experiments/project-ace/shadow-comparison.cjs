'use strict';
// Offline-only, supplied legacy observations are not a live legacy engine invocation.
const {createHash}=require('node:crypto'),{importSnapshot}=require('./legacy-snapshot.cjs'),engine=require('./engine.cjs'),{calculate}=require('./official-statistics.cjs'),{duration}=require('./schedule-gate.cjs');
const check=(ok,msg)=>{if(!ok)throw Error(msg);};
const id=x=>typeof x==='string'&&x.length>0&&x.length<=120&&x.trim()===x;
const integer=(x,min,max)=>Number.isSafeInteger(x)&&x>=min&&x<=max;
function canonical(x){
 if(x===null||typeof x==='string'||typeof x==='boolean')return JSON.stringify(x);
 if(typeof x==='number'){check(Number.isFinite(x),'Non-finite input');return JSON.stringify(x);}
 if(Array.isArray(x))return '['+x.map(canonical).join(',')+']';
 check(x&&typeof x==='object'&&Object.getPrototypeOf(x)===Object.prototype,'JSON data required');
 return '{'+Object.keys(x).sort().map(k=>JSON.stringify(k)+':'+canonical(x[k])).join(',')+'}';
}
const digest=x=>createHash('sha256').update(canonical(x)).digest('hex');
const copy=x=>JSON.parse(canonical(x));
function freeze({match_id,competition_id,source_revision,snapshot,seed,ace_version='ace-context-0.5'}){
 check(id(match_id)&&id(competition_id)&&integer(source_revision,0,Number.MAX_SAFE_INTEGER)&&integer(seed,0,4294967295),'Invalid frozen identity or seed');
 const imported=importSnapshot(snapshot);
 check(['ace-poc-0.1','ace-tactical-0.4','ace-context-0.5'].includes(ace_version),'Unsupported Ace version');
 const player_ids=snapshot.players.map(p=>p.player.id);check(player_ids.every(id),'Invalid participant identity');
 const body={schema:'ace-shadow-input-v1',match_id,competition_id,source_revision,player_ids,seed,ace_version,snapshot:copy(snapshot),format:{surface:imported.surface,best_of:imported.bestOf,world:imported.detail.world,draw_type:imported.detail.draw_type}};
 return {...body,input_sha256:digest(body)};
}
function verify(frozen){
 const {input_sha256,...body}=frozen;
 check(body.schema==='ace-shadow-input-v1'&&input_sha256===digest(body),'Frozen input mismatch');
 const again=freeze(body);check(canonical(again)===canonical(frozen),'Invalid frozen input');
 return importSnapshot(body.snapshot);
}
function simulate(frozen){
 const input=verify(frozen);
 let s=engine.createMatch({players:input.players,surface:input.surface,bestOf:input.bestOf,weather:input.weather,seed:frozen.seed,version:frozen.ace_version});
 let steps=0;while(s.status!=='completed'){check(++steps<=100,'Match game safety limit');s=engine.stepGame(s);}
 const points=s.events.filter(x=>x.kind==='point');
 const stats=calculate(points);
 check(points.length===s.totalPoints&&stats.reduce((n,x)=>n+x.total_points_won,0)===s.totalPoints,'Engine statistics mismatch');
 return {schema:'ace-shadow-ace-result-v1',input_sha256:frozen.input_sha256,match_id:frozen.match_id,competition_id:frozen.competition_id,source_revision:frozen.source_revision,player_ids:[...frozen.player_ids],engine_version:s.version,status:'completed',winner_id:frozen.player_ids[s.winner],sets:s.completedSets.map(x=>({games:x.games,tiebreak:x.tiebreak})),stats,actual_duration_minutes:duration(s.gameNumber,s.totalPoints),point_trace_sha256:digest(points)};
}
function validateResult(result,frozen,legacy=false){
 check(result?.schema===(legacy?'ace-shadow-legacy-observation-v1':'ace-shadow-ace-result-v1')&&result.input_sha256===frozen.input_sha256&&result.match_id===frozen.match_id&&result.competition_id===frozen.competition_id&&result.source_revision===frozen.source_revision&&canonical(result.player_ids)===canonical(frozen.player_ids)&&id(result.engine_version)&&result.status==='completed','Result identity or provenance mismatch');
 const need=(frozen.format.best_of+1)/2;
 check(Array.isArray(result.sets)&&result.sets.length>=need&&result.sets.length<=frozen.format.best_of,'Invalid set count');
 const wins=[0,0];let games=0;
 for(const [i,s] of result.sets.entries()){
  check(Array.isArray(s.games)&&s.games.length===2&&s.games.every(x=>integer(x,0,7)),'Invalid set games');
  const hi=Math.max(...s.games),lo=Math.min(...s.games);
  check((hi===6&&lo<=4)||(hi===7&&(lo===5||lo===6)),'Invalid completed set');
  const w=s.games[0]>s.games[1]?0:1;wins[w]++;games+=hi+lo;
  check(wins[w]<need||i===result.sets.length-1,'Extra set after victory');
  if(lo===6){const target=frozen.format.best_of===5&&i===4?10:7;check(Array.isArray(s.tiebreak)&&s.tiebreak.length===2&&s.tiebreak.every(x=>integer(x,0,10000))&&s.tiebreak[w]>=target&&s.tiebreak[w]-s.tiebreak[1-w]>=2,'Invalid tiebreak');}
  else check(s.tiebreak===null,'Unexpected tiebreak');
 }
 const w=wins[0]===need?0:wins[1]===need?1:-1;check(w>=0&&result.winner_id===frozen.player_ids[w],'Winner disagrees with sets');
 const fields=['aces','double_faults','first_serves_in','first_serves_total','first_serve_points_won','first_serve_points_played','second_serve_points_won','second_serve_points_played','winners','unforced_errors','total_points_won','break_points_won','break_points_total'];
 check(Array.isArray(result.stats)&&result.stats.length===2&&result.stats.every(s=>fields.every(k=>integer(s[k],0,10000))),'Incomplete statistics');
 let points=0,served=0,classified=0;
 for(const s of result.stats){
  check(s.first_serves_in===s.first_serve_points_played&&s.first_serve_points_played+s.second_serve_points_played===s.first_serves_total&&s.first_serve_points_won<=s.first_serve_points_played&&s.second_serve_points_won<=s.second_serve_points_played&&s.aces<=s.first_serve_points_won&&s.double_faults<=s.second_serve_points_played-s.second_serve_points_won&&s.break_points_won<=s.break_points_total,'Inconsistent service statistics');
  points+=s.total_points_won;served+=s.first_serves_total;classified+=s.aces+s.double_faults+s.winners+s.unforced_errors;
 }
 for(let i=0;i<2;i++){const a=result.stats[i],b=result.stats[1-i];check(a.total_points_won===a.first_serve_points_won+a.second_serve_points_won+b.first_serves_total-b.first_serve_points_won-b.second_serve_points_won,'Inconsistent points won');}
 // Historical base-v1.1/v2.0 classification removes forced errors from winners
 // without recording a separate aggregate field. Preserve the residual explicitly.
 const forcedOmitted=legacy&&['base-v1.1','base-v2.0'].includes(result.engine_version);
 check(points===served&&(forcedOmitted?classified<=points:classified===points)&&points>=games*4,'Inconsistent match point totals');
 check(integer(result.actual_duration_minutes,1,1440),'Invalid observed duration');
 if(!legacy)check(result.actual_duration_minutes===duration(games,points),'Ace duration mismatch');
 return {games,points,minutes:result.actual_duration_minutes,first_serve_rate:result.stats.reduce((n,s)=>n+s.first_serves_in,0)/served,ace_rate:result.stats.reduce((n,s)=>n+s.aces,0)/points,double_fault_rate:result.stats.reduce((n,s)=>n+s.double_faults,0)/points,unclassified_point_rate:(points-classified)/points};
}
function compare(frozen,legacy){
 verify(frozen);
 const a=simulate(frozen),am=validateResult(a,frozen),lm=validateResult(legacy,frozen,true);
 const deltas=Object.fromEntries(Object.keys(am).map(k=>[k,am[k]-lm[k]]));
 return {schema:'ace-shadow-comparison-v1',review_only:true,production_ready:false,match_id:frozen.match_id,input_sha256:frozen.input_sha256,legacy_observation_sha256:digest(legacy),ace_result_sha256:digest(a),legacy_engine_version:legacy.engine_version,ace_engine_version:a.engine_version,winner_agreement:a.winner_id===legacy.winner_id,score_agreement:canonical(a.sets)===canonical(legacy.sets),metrics:{ace:am,legacy:lm,delta:deltas},status:'compared_review',legacy_provenance:'supplied_unverified_observation',ace_result:a};
}
module.exports={freeze,simulate,compare,digest};
