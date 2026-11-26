'use strict';
// Manual review service. Database installer is intentionally not invoked here.
const {open}=require('./postgres-store.cjs'),{createService,startLoop}=require('./postgres-service.cjs');
async function main(){
 const id=process.env.ACE_REVIEW_WORLD_ID;
 if(!id)throw Error('Set ACE_REVIEW_WORLD_ID to an existing disposable review world');
 const store=open(id),row=await store.read();if(!row)throw Error('Review world not found; run a seed or integration test first');
 const owner=row.state.draw.owner,peer=row.state.draw.peerOwner??null;
 const principal={id:owner,verified:true,isAdmin:true},policy={enabled:true,adminId:owner,multiplayerTest:!!peer,syntheticId:peer};
 const service=createService({store,principal,policy});
 const loop=startLoop(service,{onError:e=>console.error('Review worker tick:',e.code||e.message)});
 console.log('Isolated PostgreSQL worker started for '+id+'; no HTTP listener or production access');
 let closing=false;
 const stop=async()=>{if(closing)return;closing=true;await loop.stop();console.log('Review worker stopped');};
 process.once('SIGINT',stop);process.once('SIGTERM',stop);
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
