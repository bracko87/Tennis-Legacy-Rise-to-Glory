'use strict';
// Provisional descriptive screening, not statistical equivalence or release approval.
const {digest}=require('./shadow-comparison.cjs');
const defaults=Object.freeze({schema:'ace-shadow-screening-policy-v1',minimum_per_cohort:100,margins:Object.freeze({games:3,points:25,minutes:25,first_serve_rate:0.05,ace_rate:0.025,double_fault_rate:0.02,focal_win_rate:0.10})});
const check=(v,m)=>{if(!v)throw Error(m)};
function assess(r,policy=defaults){
 check(r?.schema==='ace-shadow-cohort-v1'&&r.review_only===true&&r.production_ready===false&&Array.isArray(r.cohorts)&&r.cohorts.length>0,'Invalid review cohort');
 check(policy?.schema===defaults.schema&&Number.isSafeInteger(policy.minimum_per_cohort)&&policy.minimum_per_cohort>=30&&policy.minimum_per_cohort<=10000,'Invalid screening policy');
 const keys=Object.keys(defaults.margins);
 check(policy.margins&&Object.keys(policy.margins).length===keys.length&&keys.every(k=>Number.isFinite(policy.margins[k])&&policy.margins[k]>0&&policy.margins[k]<= (k.endsWith('_rate')?1:10000)),'Invalid screening margins');
 const cohorts=r.cohorts.map(c=>{
  check(Number.isSafeInteger(c.n)&&c.n>0,'Invalid cohort size');
  const metrics=keys.map(k=>{
   const m=k==='focal_win_rate'?c.focal_player_win_rate:c.metrics?.[k];
   if(!m)return {metric:k,status:'missing_metric',margin:policy.margins[k]};
   const d=m.paired_delta?.mean,interval=m.approximate_95pct_mean_delta_interval,margin=policy.margins[k];
   check(Number.isFinite(d),'Invalid paired delta');
   if(c.n<policy.minimum_per_cohort)return {metric:k,status:'insufficient_sample',delta:d,margin};
   check(Array.isArray(interval)&&interval.length===2&&interval.every(Number.isFinite)&&interval[0]<=d&&d<=interval[1],'Invalid paired interval');
   const status=interval[0]>=-margin&&interval[1]<=margin?'within_provisional_band':interval[0]>margin||interval[1]<-margin?'outside_provisional_band':'inconclusive';
   return {metric:k,status,delta:d,interval,margin};
  });
  const status=metrics.some(m=>m.status==='outside_provisional_band')?'investigate':metrics.every(m=>m.status==='within_provisional_band')?'within_provisional_bands':'inconclusive';
  return {reference_kind:c.reference_kind,reference_engine:c.reference_engine,ace_engine:c.ace_engine,cohort:c.cohort,surface:c.surface,best_of:c.best_of,world:c.world,draw_type:c.draw_type,n:c.n,case_manifest_sha256:c.case_manifest_sha256,status,metrics};
 });
 return {schema:'ace-shadow-screening-v1',review_only:true,production_ready:false,policy_approved:false,source_authenticated:false,policy_sha256:digest(policy),cohort_report_sha256:digest(r),status:cohorts.some(c=>c.status==='investigate')?'investigation_required':'descriptive_review_only',counts:{within:cohorts.filter(c=>c.status==='within_provisional_bands').length,investigate:cohorts.filter(c=>c.status==='investigate').length,inconclusive:cohorts.filter(c=>c.status==='inconclusive').length},cohorts,limitations:['Provisional engineering margins, not approved realism targets','Approximate intervals assume independent pairs and are not adjusted for multiplicity','Legacy agreement is not proof of tennis realism','Missing focal designation cannot be treated as competitive-balance clearance','No production authorization']};
}
module.exports={assess,defaults};
