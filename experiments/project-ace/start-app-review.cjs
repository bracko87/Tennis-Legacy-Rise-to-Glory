'use strict';
const {open}=require('./postgres-store.cjs'),{createAuth}=require('./local-supabase-review-auth.cjs'),{serve}=require('./app-review-http.cjs'),{createService,startLoop}=require('./postgres-service.cjs'),{demo}=require('./tournament-http.cjs'),world=require('./world-demo.cjs');
async function main(){
 if(process.env.TL_ACE_REVIEW!=='1')throw Error('Explicit review flag required');
 const auth=createAuth({url:process.env.TL_SUPABASE_URL,key:process.env.TL_SUPABASE_PUBLISHABLE_KEY,userId:process.env.ACE_REVIEW_ADMIN_UUID});
 const store=open(process.env.ACE_REVIEW_WORLD_ID),principal={id:auth.policy.adminId,verified:true,isAdmin:true};
 const old=await store.read();
 if(old){if(old.state.draw.owner!==principal.id||old.state.draw.peerOwner)throw Error('Review world owner mismatch');}
 else{const now=Date.now();await store.save(-1,world.create(demo({pace:'fast',delaySeconds:60},now,33),principal,auth.policy,now));}
 const worker=createService({store,principal,policy:auth.policy}),loop=startLoop(worker,{onError:e=>console.error('Review worker:',e.code||e.message)});
 const server=serve({auth,store,appOrigin:process.env.ACE_REVIEW_APP_ORIGIN||'http://127.0.0.1:8000'});
 server.on('error',e=>{console.error(e.message);void loop.stop();process.exitCode=1;});
 const stop=async()=>{await loop.stop();server.close();};process.once('SIGINT',stop);process.once('SIGTERM',stop);
 console.log('Read-only Project Ace app review gateway: 127.0.0.1:8769');
}
main().catch(e=>{console.error(e.message);process.exitCode=1});
