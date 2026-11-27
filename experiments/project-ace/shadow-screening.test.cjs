'use strict';
const assert=require('node:assert/strict'),{assess,defaults}=require('./shadow-screening.cjs'),{paired}=require('./shadow-cohort-review.cjs');
const metric=(d,n=100)=>paired(Array(n).fill(d),Array(n).fill(0));
const keys=Object.keys(defaults.margins).filter(k=>k!=='focal_win_rate');
function cohort(n=100){return {reference_kind:'historical_sql_control',reference_engine:'base-v2.0',ace_engine:'ace-context-0.5',cohort:'fixture',surface:'Hard',best_of:3,world:'ATP',draw_type:'main_draw',n,case_manifest_sha256:'a'.repeat(64),metrics:Object.fromEntries(keys.map(k=>[k,metric(0,n)])),focal_player_win_rate:metric(0,n)};}
const report=c=>({schema:'ace-shadow-cohort-v1',review_only:true,production_ready:false,cohorts:[c]});
let r=assess(report(cohort()));assert.equal(r.counts.within,1);assert.equal(r.production_ready,false);assert.equal(r.policy_approved,false);
r=assess(report(cohort(30)));assert.equal(r.counts.inconclusive,1);assert.ok(r.cohorts[0].metrics.every(m=>m.status==='insufficient_sample'));
let c=cohort();c.metrics.minutes=metric(30);assert.equal(assess(report(c)).counts.investigate,1);
c=cohort();c.metrics.minutes.approximate_95pct_mean_delta_interval=[-26,26];assert.equal(assess(report(c)).counts.inconclusive,1);
c=cohort();c.focal_player_win_rate=null;assert.equal(assess(report(c)).counts.inconclusive,1);
assert.throws(()=>assess(report(cohort()),{...defaults,minimum_per_cohort:1}),/policy/);
assert.throws(()=>assess(report(cohort()),{...defaults,margins:{...defaults.margins,ace_rate:0}}),/margins/);
console.log('PASS provisional statistical bands, insufficient samples, differences, uncertainty, missing metrics and nonauthorization');
