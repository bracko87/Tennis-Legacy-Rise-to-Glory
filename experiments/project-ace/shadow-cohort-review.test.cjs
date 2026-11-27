'use strict';
const assert=require('node:assert/strict'),{report,paired}=require('./shadow-cohort-review.cjs'),{cases}=require('./shadow-cohort-synthetic.cjs');
assert.deepEqual(paired([1,3],[2,2]).paired_delta,{mean:0,median:0,p10:-.8,p90:.8,sample_sd:1.414214});
const sample=cases(10),r=report(sample);
assert.equal(r.paired_matches,360);assert.equal(r.cohorts.length,36);assert.equal(r.synthetic_pairs,360);assert.equal(r.supplied_legacy_pairs,0);assert.equal(r.adequate_cohorts,0);assert.equal(r.production_ready,false);
for(const c of r.cohorts){assert.equal(c.n,10);assert.equal(c.adequate_sample,false);assert.ok(c.winner_agreement>=0&&c.winner_agreement<=1);assert.equal(c.metrics.minutes.approximate_95pct_mean_delta_interval,null);}
const small=sample.slice(0,2);
assert.deepEqual(report(small),report([...small].reverse()));
assert.throws(()=>report([small[0],small[0]]),/Duplicate source case/);
assert.throws(()=>report([{...small[0],reference_kind:'supplied_legacy_observation'}]),/mislabeled/);
assert.throws(()=>report(small,{minimumPerCohort:1}),/at least 30/);
assert.deepEqual(paired(Array(30).fill(2),Array(30).fill(1)).approximate_95pct_mean_delta_interval,[1,1]);
console.log('PASS 360 synthetic paired cases / 720 engine simulations, 36 cohorts, sample-size and provenance separation, deterministic aggregation and duplicate rejection');
