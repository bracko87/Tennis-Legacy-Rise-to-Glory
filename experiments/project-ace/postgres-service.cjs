'use strict';
// Trusted server-side service for a disposable PostgreSQL review world.
// No production URL, user-supplied clock, or public HTTP endpoints.
const w=require('./world-worker.cjs'),a=require('./match-service.cjs'),c=require('./world-clock.cjs');
const {isDeepStrictEqual}=require('node:util');
const conflict=e=>e?.code==='ACE_REVISION_CONFLICT';
const fail=(message,status,code)=>Object.assign(Error(message),{status,code});
function createService({store,principal,policy,now=Date.now,clock=(s,ms)=>({server_now:new Date(ms).toISOString(),game_total_seconds:c.at(s.anchor,ms),speed_multiplier:s.anchor.speed})}){
 if(!a.canUse(principal,policy))throw fail('Invalid worker identity',403);
 async function read(){const row=await store.read();if(!row)throw fail('Review world missing',404);w.access(row.state,principal,policy);return row;}
 function next(row){
  const raw=clock(row.state,now()),sample=c.sample(raw);
  if(sample.realMs<row.state.clock.realMs||sample.gameSeconds<row.state.clock.gameSeconds)throw fail('Worker clock behind committed sample',409,'ACE_STALE_CLOCK');
  return w.tick(row.state,raw,principal,policy);
 }
 async function tick(){
  // Only background advancement is safe to retry, and each retry reloads state
  // and takes a fresh server-side clock sample. No stale commands are replayed.
  for(let n=0;n<3;n++){
   const row=await read();const state=next(row);
   if(isDeepStrictEqual(state,row.state))return {revision:row.revision,changed:false};
   try{return {revision:await store.save(row.revision,state),changed:true};}
   catch(e){if(!conflict(e)||n===2)throw e;}
  }
 }
 async function summary(p){const row=await read();return {revision:row.revision,...w.summary(row.state,p,policy,row.state.clock.realMs)};}
 function committedMatch(state,id,p,revision){const v=w.matchView(state,id,p,policy,state.clock.realMs);return {...v,matchRevision:v.revision,revision};}
 async function match(id,p){const row=await read();return committedMatch(row.state,id,p,row.revision);}
 async function command(id,p,action,targetGame,patch){
  const row=await read();w.access(row.state,p,policy);
  const state=next(row);
  const out=w.command(state,id,p,policy,state.clock.realMs,action,targetGame,patch);
  const revision=await store.save(row.revision,out); // Never retry a user command.
  return committedMatch(out,id,p,revision);
 }
 return {tick,summary,match,command};
}
function startLoop(service,{intervalMs=1000,maxBackoffMs=30000,onError=()=>{}}={}){
 if(!Number.isInteger(intervalMs)||intervalMs<100||!Number.isInteger(maxBackoffMs)||maxBackoffMs<intervalMs)throw Error('Invalid worker cadence');
 let stopped=false,timer=null,inflight=null,failures=0;
 function schedule(delay){if(!stopped)timer=setTimeout(run,delay);}
 function run(){
  if(stopped)return;
  inflight=(async()=>{try{await service.tick();failures=0;}catch(e){failures++;onError(e);}finally{inflight=null;schedule(Math.min(maxBackoffMs,intervalMs*2**Math.min(failures,10)));}})();
 }
 run();
 return {async stop(){stopped=true;clearTimeout(timer);if(inflight)await inflight;}};
}
module.exports={createService,startLoop};
