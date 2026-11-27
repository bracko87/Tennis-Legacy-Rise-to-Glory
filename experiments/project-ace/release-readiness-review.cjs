'use strict';
// Offline candidate evidence review only. No network, deployment or activation capability.
const fs=require('node:fs'),{digest}=require('./shadow-comparison.cjs');
const requiredWorkflows=['Ace local prototype verification','Ace isolated PostgreSQL review','Ace historical SQL shadow verification'];
const requiredEvidence=['approved_current_reference_catalog','authorized_isolated_restore','current_engine_shadow_comparison','official_input_provenance','official_reward_reconciliation','forced_error_and_statistic_contract','exception_reward_policy','operational_monitoring_and_rollback','explicit_release_authorization'];
const check=(v,m)=>{if(!v)throw Error(m);};
const sha=x=>typeof x==='string'&&/^[a-f0-9]{40}$/.test(x);
const sha256=x=>typeof x==='string'&&/^[a-f0-9]{64}$/.test(x);
function review(input){
 check(input?.schema==='ace-release-evidence-v1'&&sha(input.candidate_sha)&&input.branch==='project-ace','Invalid isolated candidate');
 check(Array.isArray(input.workflows)&&Array.isArray(input.evidence),'Missing evidence inventories');
 const workflowNames=new Set(),runIds=new Set(),blockers=[],checks=[];
 for(const run of input.workflows){
  check(requiredWorkflows.includes(run.name)&&!workflowNames.has(run.name),'Unexpected or duplicate workflow');
  check(Number.isSafeInteger(run.id)&&run.id>0&&!runIds.has(run.id),'Invalid or duplicate run ID');
  check(sha(run.head_sha)&&typeof run.head_branch==='string'&&['queued','in_progress','completed','requested','waiting','pending'].includes(run.status),'Invalid workflow receipt');
  check(run.status==='completed'?['success','failure','cancelled','skipped','timed_out','action_required','neutral','stale','startup_failure'].includes(run.conclusion):run.conclusion===null,'Invalid workflow conclusion');
  workflowNames.add(run.name);runIds.add(run.id);
 }
 for(const name of requiredWorkflows){
  const run=input.workflows.find(x=>x.name===name);
  const status=!run?'missing':run.head_sha!==input.candidate_sha||run.head_branch!==input.branch?'wrong_candidate':run.status!=='completed'?'pending':run.conclusion!=='success'?'failed':'reported_pass';
  checks.push({name,status,run_id:run?.id??null});
  if(status!=='reported_pass')blockers.push({kind:'technical_workflow',name,status});
 }
 const evidenceNames=new Set();
 for(const x of input.evidence){
  check(requiredEvidence.includes(x.kind)&&!evidenceNames.has(x.kind),'Unexpected or duplicate external evidence');
  check(['missing','supplied_for_manual_review'].includes(x.status),'External evidence cannot be self-approved');
  if(x.status==='supplied_for_manual_review')check(sha256(x.artifact_sha256)&&typeof x.reference==='string'&&x.reference.trim().length>0&&x.reference.length<=500&&x.candidate_sha===input.candidate_sha,'Invalid or stale external evidence');
  else check(x.artifact_sha256==null&&x.reference==null&&x.candidate_sha==null,'Missing evidence must not carry ambiguous artifacts');
  evidenceNames.add(x.kind);
 }
 const external=requiredEvidence.map(kind=>{
  const x=input.evidence.find(e=>e.kind===kind),status=x?.status??'missing';
  blockers.push({kind:'external_evidence',name:kind,status:status==='missing'?'missing':'manual_verification_required'});
  return {kind,status,artifact_sha256:x?.artifact_sha256??null,reference:x?.reference??null};
 });
 const technical=checks.every(x=>x.status==='reported_pass');
 return {schema:'ace-release-readiness-review-v1',candidate_sha:input.candidate_sha,branch:input.branch,technical_status:technical?'isolated_ci_reported_pass':'isolated_ci_incomplete',status:'production_blocked',review_only:true,production_ready:false,activation_authorized:false,workflow_provenance_verified:false,external_authority_verified:false,checks,external,blockers,evidence_sha256:digest(input),limitations:['Supplied workflow receipts are not independently authenticated by this offline utility','Passing isolated CI is not production compatibility','External evidence requires independent manual verification and explicit approval','This utility cannot activate routing, deploy or approve a production release']};
}
if(require.main===module){
 const file=process.argv[2];if(!file)throw Error('Usage: node release-readiness-review.cjs <candidate-evidence.json>');
 console.log(JSON.stringify(review(JSON.parse(fs.readFileSync(file,'utf8'))),null,2));
 // Never signal production clearance to automation, even if all evidence is supplied.
 process.exitCode=2;
}
module.exports={review,requiredWorkflows,requiredEvidence};
