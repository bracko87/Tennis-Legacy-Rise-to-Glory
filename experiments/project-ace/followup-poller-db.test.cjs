'use strict';
const assert=require('node:assert/strict'),{isolatedPoller}=require('./followup-poller.cjs'),{connection}=require('./postgres-store.cjs');
(async()=>{
 const db=connection();let errors=[];
 const p=isolatedPoller(process.env,e=>errors.push(e));
 // All preceding scheduling fixtures are already processed. Exercise real transport.
 p.start();await new Promise(r=>setTimeout(r,1250));await p.stop();
 assert.deepEqual(errors,[]);
 const r=JSON.parse(await db.sql('SELECT ace_cutover_review.drain_followup_outbox(1);'));assert.equal(r.processed,0);
 console.log('PASS isolated periodic worker real PostgreSQL transport and shutdown');
})().catch(e=>{console.error(e);process.exitCode=1;});
