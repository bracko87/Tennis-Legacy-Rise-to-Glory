'use strict';
const assert=require('node:assert/strict'),{createPoller,isolatedPoller}=require('./followup-poller.cjs');
const delay=n=>new Promise(r=>setTimeout(r,n));
(async()=>{
 assert.throws(()=>isolatedPoller({}),/opt-in/);
 assert.throws(()=>createPoller({drain:()=>{},batch:21}),/Invalid/);
 let calls=0,errors=0,active=0,peak=0,release;
 let first=new Promise(r=>release=r);
 const p=createPoller({intervalMs:50,batch:3,onError:()=>errors++,drain:async n=>{assert.equal(n,3);active++;peak=Math.max(peak,active);try{calls++;if(calls===1)await first;if(calls===2)throw Error('transient');}finally{active--;}}});
 assert.equal(p.start(),true);assert.equal(p.start(),false);await delay(120);assert.equal(calls,1);release();
 const deadline=Date.now()+2000;while(calls<3&&Date.now()<deadline)await delay(10);
 assert.ok(calls>=3);assert.equal(errors,1);assert.equal(peak,1);await p.stop();const count=calls;await delay(100);assert.equal(calls,count);assert.throws(()=>p.start(),/stopped/);
 let unblock;const q=createPoller({drain:()=>new Promise(r=>unblock=r),intervalMs:50});q.start();await Promise.resolve();let stopped=false;const done=q.stop().then(()=>stopped=true);await delay(20);assert.equal(stopped,false);unblock();await done;assert.equal(stopped,true);
 console.log('PASS isolated poller opt-in, bounded batches, no overlap, transient recovery and graceful shutdown');
})().catch(e=>{console.error(e);process.exitCode=1;});
