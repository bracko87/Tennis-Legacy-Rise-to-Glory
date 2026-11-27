'use strict';
// Disposable review only; never installs a production scheduler.
const {createPoller}=require('./followup-poller.cjs');
const {connection}=require('./postgres-store.cjs');
function isolatedSchedulePoller(env=process.env,onError){
 if(env.ACE_SCHEDULE_REVIEW!=='disposable-ci-only')throw Error('Explicit isolated scheduling opt-in required');
 const db=connection(env);
 return createPoller({drain:async n=>JSON.parse(await db.sql('SELECT ace_shared_schedule_fixture.drain_schedule_queue('+n+');')),intervalMs:1000,batch:10,onError});
}
if(require.main===module){
 try{
  const p=isolatedSchedulePoller(process.env,e=>console.error('Scheduling review tick:',e.code||e.message));
  process.once('SIGINT',()=>p.stop());process.once('SIGTERM',()=>p.stop());p.start();
 }catch(e){console.error(e.message);process.exitCode=1;}
}
module.exports={isolatedSchedulePoller};
