'use strict';
// psql transport for disposable local PostgreSQL only. No browser credentials.
const {spawn,spawnSync}=require('node:child_process');
function connection(env=process.env){
 if(env.ACE_REVIEW_DB!=='1'||!env.ACE_REVIEW_DB_PASSWORD)throw Error('Explicit isolated review database opt-in required');
 const port=Number(env.ACE_REVIEW_DB_PORT||55432);
 if(!Number.isInteger(port)||port<1024||port>65535)throw Error('Invalid review port');
 const args=['-X','-qAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',String(port),'-U','ace_review_worker','-d','ace_review','-w'];
 const childEnv={...Object.fromEntries(['PATH','Path','SYSTEMROOT','SystemRoot','WINDIR','TEMP','TMP','HOME','USERPROFILE'].filter(k=>env[k]!==undefined).map(k=>[k,env[k]])),PGPASSWORD:env.ACE_REVIEW_DB_PASSWORD,PGCONNECT_TIMEOUT:'5',PGSSLMODE:'disable'};
 function sql(query){
  return new Promise((resolve,reject)=>{
   const child=spawn('psql',args,{env:childEnv,stdio:['pipe','pipe','pipe']});
   let out='',err='',finished=false;
   const timer=setTimeout(()=>{child.kill();reject(Error('Review database timeout'));},30000);
   child.stdout.on('data',c=>{out+=c;if(out.length>64*1024*1024)child.kill();});
   child.stderr.on('data',c=>{if(err.length<8192)err+=c;});
   child.stdin.on('error',()=>{});
   child.on('error',e=>{clearTimeout(timer);reject(e);});
   child.on('close',code=>{clearTimeout(timer);if(code!==0){const e=Error(err.includes('ACE_REVISION_CONFLICT')?'Revision conflict':'Review database rejected operation');e.code=err.includes('ACE_REVISION_CONFLICT')?'ACE_REVISION_CONFLICT':'ACE_DATABASE_ERROR';reject(e);}else resolve(out.trim());});
   child.stdin.end(query+'\n');
  });
 }
 return {sql};
}
const literal=x=>"convert_from(decode('"+Buffer.from(x,'utf8').toString('base64')+"','base64'),'UTF8')";
function open(id,db=connection()){
 if(typeof id!=='string'||!/^[a-zA-Z0-9_-]{1,80}$/.test(id))throw Error('Invalid world ID');
 const key=literal(id);
 return {
  async read(){const raw=await db.sql('SELECT ace_review.load_world('+key+');');return raw?JSON.parse(raw):null;},
  async save(expected,state){
   if(!Number.isSafeInteger(expected)||expected< -1||state?.kind!=='world'||state.version!==1)throw Error('Invalid revision or world');
   const value=literal(JSON.stringify(state));
   return Number(await db.sql('SELECT ace_review.commit_world('+key+','+expected+','+value+'::jsonb);'));
  }
 };
}
async function mutate(store,fn){
 // A revision conflict is returned to the caller. Never silently replay a stale coaching command.
 const current=await store.read();if(!current)throw Error('World missing');
 const next=await fn(current.state);const revision=await store.save(current.revision,next);
 return {revision,state:next};
}
module.exports={connection,open,mutate};
