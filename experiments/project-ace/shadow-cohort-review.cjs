'use strict';
// Offline review of paired matches. No legacy invocation or official write authority.
const {compare,digest}=require('./shadow-comparison.cjs');
const check=(v,m)=>{if(!v)throw Error(m);};
const keys=['games','points','minutes','first_serve_rate','ace_rate','double_fault_rate','unclassified_point_rate'];
const mean=x=>x.reduce((s,v)=>s+v,0)/x.length;
const round=x=>Math.round(x*1e6)/1e6;
const quantile=(x,q)=>{const s=[...x].sort((a,b)=>a-b),p=(s.length-1)*q,i=Math.floor(p);return s[i]+(s[Math.min(i+1,s.length-1)]-s[i])*(p-i);};
function descriptive(x){
 const avg=mean(x);const sd=x.length>1?Math.sqrt(x.reduce((n,v)=>n+(v-avg)**2,0)/(x.length-1)):null;
 return {mean:round(avg),median:round(quantile(x,.5)),p10:round(quantile(x,.1)),p90:round(quantile(x,.9)),sample_sd:sd===null?null:round(sd)};
}
function paired(x,y){
 const d=x.map((v,i)=>v-y[i]);
 const summary=descriptive(d),avg=mean(d);
 // Approximate normal interval, descriptive only. Not an equivalence test.
 const sd=d.length>1?Math.sqrt(d.reduce((s,v)=>s+(v-avg)**2,0)/(d.length-1)):null;
 return {ace:descriptive(x),reference:descriptive(y),paired_delta:summary,approximate_95pct_mean_delta_interval:d.length>=30?[round(avg-1.96*sd/Math.sqrt(d.length)),round(avg+1.96*sd/Math.sqrt(d.length))]:null};
}
function report(pairs,{minimumPerCohort=30}={}){
 check(Array.isArray(pairs)&&pairs.length>0&&pairs.length<=10000,'Invalid paired inventory');
 check(Number.isSafeInteger(minimumPerCohort)&&minimumPerCohort>=30,'Minimum cohort must be at least 30');
 const identities=new Set(),hashes=new Set(),groups=new Map(),all=[];
 for(const {input,reference,cohort,reference_kind} of pairs){
  check(['synthetic_control','historical_sql_control','supplied_legacy_observation'].includes(reference_kind),'Explicit reference provenance required');
  check(typeof cohort==='string'&&cohort.trim()===cohort&&cohort.length>0&&cohort.length<=120,'Invalid cohort label');
  const k=JSON.stringify([input.competition_id,input.match_id,input.source_revision]);
  check(!identities.has(k)&&!hashes.has(input.input_sha256),'Duplicate source case');
  identities.add(k);hashes.add(input.input_sha256);
  check(reference_kind!=='supplied_legacy_observation'||!/^synthetic[-_]/i.test(reference.engine_version),'Synthetic reference mislabeled as legacy');
  check(reference_kind!=='historical_sql_control'||['base-v1.0','base-v1.1','base-v2.0'].includes(reference.engine_version),'Unknown historical engine label');
  const cmp=compare(input,reference);
  const groupKey=JSON.stringify([reference_kind,reference.engine_version,input.ace_version,input.format.surface,input.format.best_of,input.format.world,input.format.draw_type,cohort]);
  const row={identity:k,input_sha256:input.input_sha256,reference_sha256:cmp.legacy_observation_sha256,ace_sha256:cmp.ace_result_sha256,agreement:cmp.winner_agreement,score_agreement:cmp.score_agreement,ace_first_won:cmp.ace_result.winner_id===input.player_ids[0],reference_first_won:reference.winner_id===input.player_ids[0],metrics:cmp.metrics};
  if(!groups.has(groupKey))groups.set(groupKey,[]);groups.get(groupKey).push(row);all.push(row);
 }
 const summaries=[...groups].sort(([a],[b])=>a.localeCompare(b)).map(([k,rows])=>{
  rows.sort((a,b)=>a.identity.localeCompare(b.identity));
  const [reference_kind,reference_engine,ace_engine,surface,best_of,world,draw_type,cohort]=JSON.parse(k);
  const metric=Object.fromEntries(keys.map(key=>[key,paired(rows.map(x=>x.metrics.ace[key]),rows.map(x=>x.metrics.legacy[key]))]));
  const n=rows.length;
  return {reference_kind,reference_engine,ace_engine,surface,best_of,world,draw_type,cohort,n,adequate_sample:n>=minimumPerCohort,winner_agreement:round(mean(rows.map(x=>Number(x.agreement)))),score_agreement:round(mean(rows.map(x=>Number(x.score_agreement)))),first_slot_win_rate:{ace:round(mean(rows.map(x=>Number(x.ace_first_won)))),reference:round(mean(rows.map(x=>Number(x.reference_first_won)))),paired_delta:round(mean(rows.map(x=>Number(x.ace_first_won)-Number(x.reference_first_won))))},metrics:metric,case_manifest_sha256:digest(rows.map(({identity,input_sha256,reference_sha256,ace_sha256})=>({identity,input_sha256,reference_sha256,ace_sha256})))};
 });
 return {schema:'ace-shadow-cohort-v1',review_only:true,production_ready:false,status:'descriptive_review',paired_matches:all.length,minimum_per_cohort:minimumPerCohort,adequate_cohorts:summaries.filter(x=>x.adequate_sample).length,synthetic_pairs:pairs.filter(x=>x.reference_kind==='synthetic_control').length,historical_sql_pairs:pairs.filter(x=>x.reference_kind==='historical_sql_control').length,supplied_legacy_pairs:pairs.filter(x=>x.reference_kind==='supplied_legacy_observation').length,legacy_authority_verified:false,cohorts:summaries,limitations:['Reference provenance is a supplied label, not authentication','Within-cohort approximate intervals assume independent pairs','Winner agreement is descriptive, not a correctness or equivalence criterion','Cohorts below the minimum are insufficient for policy decisions','No multiplicity correction or preapproved equivalence margins']};
}
module.exports={report,paired};
