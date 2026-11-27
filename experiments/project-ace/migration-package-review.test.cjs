'use strict';
const assert=require('node:assert/strict'),{manifest,list,verifyJournal}=require('./migration-package-review.cjs');
const m=manifest(),clone=x=>JSON.parse(JSON.stringify(x));
assert.equal(m.entries.length,22);assert.equal(m.production_ready,false);assert.equal(m.activation_authorized,false);assert.deepEqual(manifest(),m);
assert.equal(verifyJournal(m,clone(m.entries)).status,'disposable_journal_matched');
for(const mutate of [x=>x.pop(),x=>x.reverse(),x=>x[0].sha256='0'.repeat(64),x=>x.push(x[0]),x=>x[0].filename='other.sql',x=>x[1].ordinal=1]){
 const bad=clone(m.entries);mutate(bad);assert.throws(()=>verifyJournal(m,bad),/differs from candidate/);
}
assert.throws(()=>list('files=(\n ../unsafe.sql\n)\n'),/Invalid migration order/);
console.log('PASS exact revision migration bytes, ordered manifest, journal reconciliation and missing/reordered/altered/duplicate entry rejection');
