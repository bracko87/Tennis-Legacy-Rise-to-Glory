'use strict';
const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const a=require('./match-service.cjs');
const {makeAuth}=require('./local-auth.cjs');
const p={name:'Ace Admin',serve:62,return:58,rally:60,forehand:65,backhand:55,fitness:65,stamina:68,movement:62,fatigue:10,focus:75,confidence:70};
const q={...p,name:'Ace Test Opponent',backhand:42,stamina:55};
function createStore(dir){
 fs.mkdirSync(dir,{recursive:true,mode:0o700});
 const lock=path.join(dir,'writer.lock'),file=path.join(dir,'fixture.json');
 const fd=fs.openSync(lock,'wx',0o600);
 function close(){fs.closeSync(fd);fs.unlinkSync(lock);}
 function read(){return fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):null;}
 function save(record){const tmp=file+'.'+crypto.randomUUID()+'.tmp';try{fs.writeFileSync(tmp,JSON.stringify(record),{mode:0o600,flag:'wx'});fs.renameSync(tmp,file);}finally{if(fs.existsSync(tmp))fs.unlinkSync(tmp);}}
 return {read,save,close};
}
function makeHandler({store,auth,now=Date.now,host='127.0.0.1',port=8765}){
 const origin='http://'+host+':'+port;
 const send=(res,status,obj)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(obj));};
 const readBody=async req=>{let body='';for await(const chunk of req){body+=chunk;if(Buffer.byteLength(body)>8192){const e=Error('Body too large');e.status=413;throw e;}}try{return JSON.parse(body||'{}')}catch{const e=Error('Invalid JSON');e.status=400;throw e;}};
 return async(req,res)=>{
  try{
   if(req.headers.host!==host+':'+port||(req.headers.origin&&req.headers.origin!==origin))return send(res,403,{error:'Forbidden origin'});
   const url=new URL(req.url,origin);
   if(!['/api/fixture','/api/coach','/api/heartbeat'].includes(url.pathname))return send(res,404,{error:'Not found'});
   const principal=await auth.authenticate(req.headers.authorization);
   if(!principal)return send(res,403,{error:'Forbidden'});
   let body={};if(req.method==='POST'){if(!/^application\/json(?:;|$)/i.test(req.headers['content-type']||''))return send(res,415,{error:'JSON required'});body=await readBody(req);}
   // All state operations after await are synchronous: one process, one writer.
   const t=now();let r=store.read();
   if(url.pathname==='/api/fixture'&&req.method==='POST'){
    if(!a.canUse(principal,auth.policy))return send(res,403,{error:'Forbidden'});
    if(r&&a.advance(r,t).checkpoint.status!=='completed')return send(res,409,{error:'Existing fixture not complete'});
    const delay=body.delaySeconds??10;
    if(!Number.isInteger(delay)||delay<5||delay>86400)return send(res,400,{error:'Delay must be 5–86400 seconds'});
    const human=body.humanOpponent===true;
    r=a.createFixture({id:crypto.randomUUID(),players:[p,{...q,name:human?'Ace Human Peer':'Ace Test AI'}],seed:crypto.randomInt(0,4294967296),startAt:t+delay*1000,opponentId:human?auth.policy.syntheticId:null,coachingModes:[body.mode??'hybrid',human?(body.peerMode??'hybrid'):'auto']},principal,auth.policy,t);
    store.save(r);return send(res,201,a.view(r,principal,auth.policy,t));
   }
   if(!r)return send(res,404,{error:'No fixture'});
   // Check authorization before persisting any advancement.
   a.view(r,principal,auth.policy,t);
   if(url.pathname==='/api/fixture'&&req.method==='GET')r=a.advance(r,t);
   else if(url.pathname==='/api/heartbeat'&&req.method==='POST')r=a.heartbeat(r,principal,auth.policy,t);
   else if(url.pathname==='/api/coach'&&req.method==='POST')r=a.coach(r,principal,auth.policy,t,body.targetGame,body.tactics);
   else return send(res,405,{error:'Method not allowed'});
   store.save(r);return send(res,200,a.view(r,principal,auth.policy,t));
  }catch(e){return send(res,e.status||500,{error:e.status?e.message:'Local Ace request failed'});}
 };
}
function start(){
 if(process.env.ACE_LOCAL_ENABLED!=='1')throw Error('Explicit local Ace enablement required');
 const port=Number(process.env.ACE_PORT||8765);
 if(!Number.isInteger(port)||port<1024||port>65535)throw Error('Invalid port');
 const auth=makeAuth({url:process.env.ACE_SUPABASE_URL,key:process.env.ACE_SUPABASE_ANON_KEY,adminId:process.env.ACE_ADMIN_USER_ID,syntheticId:process.env.ACE_SYNTHETIC_USER_ID||null,multiplayerTest:process.env.ACE_MULTIPLAYER_TEST==='1'});
 const dir=process.env.ACE_STATE_DIR;
 if(!dir||!path.isAbsolute(dir))throw Error('Set absolute private ACE_STATE_DIR outside repository');
 const store=createStore(dir),server=http.createServer(makeHandler({store,auth,port}));
 const tick=setInterval(()=>{try{const r=store.read();if(r&&r.checkpoint.status!=='completed'){const n=a.advance(r,Date.now());if(n.revision!==r.revision)store.save(n);}}catch(e){console.error('Ace local tick failed:',e.message);}},500);
 let closing=false;function close(){if(closing)return;closing=true;clearInterval(tick);server.close(()=>{store.close();});}
 process.on('SIGINT',close);process.on('SIGTERM',close);server.on('error',e=>{console.error(e.message);clearInterval(tick);store.close();process.exitCode=1;});
 server.listen(port,'127.0.0.1',()=>console.log('Local Ace API at http://127.0.0.1:'+port));
}
if(require.main===module)start();
module.exports={createStore,makeHandler};
