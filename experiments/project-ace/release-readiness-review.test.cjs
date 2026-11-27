'use strict';
const assert=require('node:assert/strict'),{review,requiredWorkflows,requiredEvidence}=require('./release-readiness-review.cjs');
const sha='a'.repeat(40),clone=x=>JSON.parse(JSON.stringify(x));
const empty={schema:'ace-release-evidence-v1',candidate_sha:sha,branch:'project-ace',workflows:[],evidence:[]};
const missing=review(empty);assert.equal(missing.technical_status,'isolated_ci_incomplete');assert.equal(missing.blockers.length,requiredWorkflows.length+requiredEvidence.length);
const full={...empty,workflows:requiredWorkflows.map((name,i)=>({name,id:i+1,head_sha:sha,head_branch:'project-ace',status:'completed',conclusion:'success'}))};
const clean=review(full);assert.equal(clean.technical_status,'isolated_ci_reported_pass');assert.equal(clean.production_ready,false);assert.equal(clean.activation_authorized,false);assert.equal(clean.status,'production_blocked');assert.equal(clean.workflow_provenance_verified,false);
for(const [patch,expected] of [[{head_sha:'b'.repeat(40)},'wrong_candidate'],[{head_branch:'main'},'wrong_candidate'],[{status:'in_progress',conclusion:null},'pending'],[{conclusion:'failure'},'failed']]){
 const x=clone(full);Object.assign(x.workflows[0],patch);assert.equal(review(x).checks[0].status,expected);assert.equal(review(x).technical_status,'isolated_ci_incomplete');
}
const supplied={...full,evidence:requiredEvidence.map(kind=>({kind,status:'supplied_for_manual_review',artifact_sha256:'c'.repeat(64),reference:'synthetic evidence reference '+kind,candidate_sha:sha}))};
const r=review(supplied);assert.equal(r.production_ready,false);assert.equal(r.external_authority_verified,false);assert.ok(r.blockers.every(b=>b.status==='manual_verification_required'));assert.deepEqual(review(supplied),r);
for(const mutate of [x=>x.branch='main',x=>x.workflows.push(x.workflows[0]),x=>x.workflows[1].id=x.workflows[0].id,x=>x.evidence[0].status='approved',x=>x.evidence[0].candidate_sha='b'.repeat(40),x=>x.evidence[0].artifact_sha256='invalid',x=>x.workflows[0].conclusion=null]){
 const x=clone(supplied);mutate(x);assert.throws(()=>review(x));
}
console.log('PASS candidate-bound CI evidence, missing/pending/failed/wrong-commit checks, duplicate and stale receipt rejection, external evidence never self-approves release');

for(const kind of ['shared_production_schedule_authority','official_career_and_ranking_authority','statistical_uncertainty_disposition','match_permission_reconciliation']){
 assert.ok(requiredEvidence.includes(kind));
 assert.ok(review(full).blockers.some(b=>b.name===kind&&b.status==='missing'));
 const suppliedOnly={...full,evidence:[{kind,status:'supplied_for_manual_review',artifact_sha256:'d'.repeat(64),reference:'fixture only',candidate_sha:sha}]};
 assert.ok(review(suppliedOnly).blockers.some(b=>b.name===kind&&b.status==='manual_verification_required'));
}
console.log('PASS explicit scheduling, career authority, statistical uncertainty and permission evidence gates');
