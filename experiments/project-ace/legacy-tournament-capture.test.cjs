'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),{adapt}=require('./legacy-tournament-adapter-review.cjs');
const [good,repeat,processed,unknown]=process.argv.slice(2).map(f=>JSON.parse(fs.readFileSync(f,'utf8')));
assert.equal(good.capture_scope,'synthetic_ci');assert.equal(good.restore_id,'synthetic-tournament-ci');
assert.deepEqual(good,repeat);
const a=adapt(good);assert.equal(a.frozen.matches.length,7);assert.equal(a.frozen.season_number,2);assert.equal(a.production_ready,false);assert.equal(a.source_authenticated,false);
assert.equal(processed.simulations.length,1);assert.throws(()=>adapt(processed),/Existing results/);
assert.equal(unknown.competition,null);assert.throws(()=>adapt(unknown),/Competition linkage/);
console.log('PASS read-only SQL snapshot to offline adapter, deterministic export, existing simulation exclusion and unknown competition rejection');
