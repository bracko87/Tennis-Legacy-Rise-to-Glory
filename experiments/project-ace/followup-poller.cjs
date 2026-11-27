'use strict';
// Isolated review only. No scheduler installation, no production connection.
const {connection}=require('./postgres-store.cjs');
function createPoller({drain,intervalMs=1000,batch=10,onError=()=>{}}={}){
 if(typeof drain!=='function'||!Number.isInteger(intervalMs)||intervalMs<50||intervalMs>60000||!Number.isInteger(batch)||batch<1||batch>20)throw Error('Invalid review poller configuration');
 let running=false,timer=null,inflight=null,stopping=false;
 function schedule(){if(running)timer=setTimeout(tick,intervalMs);}
 function tick(){
  timer=null;if(!running)return;
  inflight=Promise.resolve().then(()=>drain(batch)).catch(e=>{try{onError(e);}catch{}}).finally(()=>{inflight=null;schedule();});
 }
 return {
  start(){if(stopping)throw Error('Poller stopped');if(running)return false;running=true;tick();return true;},
  async stop(){running=false;stopping=true;if(timer!==null){clearTimeout(timer);timer=null;}if(inflight)await inflight;},
  get running(){return running;}
 };
}
function isolatedPoller(env=process.env,onError){
 if(env.ACE_FOLLOWUP_REVIEW!=='disposable-ci-only')throw Error('Explicit isolated follow-up opt-in required');
 const db=connection(env);
 return createPoller({drain:async n=>JSON.parse(await db.sql('SELECT ace_cutover_review.drain_followup_outbox('+n+');')),intervalMs:1000,batch:10,onError});
}
if(require.main===module){
 try{
  const poller=isolatedPoller(process.env,e=>console.error('Follow-up review tick:',e.code||e.message));
  let stopping=false;const stop=async()=>{if(stopping)return;stopping=true;await poller.stop();};
  process.once('SIGINT',stop);process.once('SIGTERM',stop);poller.start();
 }catch(e){console.error(e.message);process.exitCode=1;}
}
module.exports={createPoller,isolatedPoller};
