'use strict';
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const d=require('./tournament-draw.cjs'),{open}=require('./tournament-store.cjs'),{fixtureProfiles}=require('./profiles.cjs'),{canUse}=require('./match-service.cjs');
function demo({surface='hard',pace='standard',delaySeconds=60,mode='hybrid'}={},now,seed){
 if(!['hard','clay','grass'].includes(surface)||!['standard','fast'].includes(pace)||!['hybrid','manual','auto'].includes(mode)||!Number.isInteger(delaySeconds)||delaySeconds<5||delaySeconds>86400)throw Object.assign(Error('Invalid tournament settings'),{status:400});
 const names=['Your Ace Player','Rally Specialist','Power Server','All-court Challenger','Clay Specialist','Baseline Attacker','Qualifier Hopeful'];
 const presets=['balanced','defensive','power','balanced','defensive','aggressive','balanced'];
 const entrants=names.map((name,i)=>({id:'p'+i,profile:{...fixtureProfiles(presets[i],'balanced',surface,false,{})[0],name}}));
 return {entrants,mainSlots:['p0',{qualifier:'Q1'},'p1','p2'],qualification:[{id:'Q1',players:['p3','p4','p5','p6']}],courts:['court-1','court-2'],startAt:now+delaySeconds*1000,seed,surface,pace,mainBestOf:3,roundGapMs:60000,managedPlayer:'p0',managedMode:mode};
}
function handler({auth,getStore,createStore,now=Date.now,port=8766}){
 const host='127.0.0.1:'+port,origin='http://'+host;
 const send=(res,status,x)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(x));};
 async function body(req){let b='';for await(const c of req){b+=c;if(Buffer.byteLength(b)>8192)throw Object.assign(Error('Body too large'),{status:413});}try{return JSON.parse(b||'{}')}catch{throw Object.assign(Error('Invalid JSON'),{status:400});}}
 return async(req,res)=>{try{
  if(req.headers.host!==host||(req.headers.origin&&req.headers.origin!==origin))return send(res,403,{error:'Forbidden origin'});
  const url=new URL(req.url,origin),file={'/':'tournament.html','/tournament.js':'tournament.js','/ace.css':'ace.css'}[url.pathname];
  if(req.method==='GET'&&file){res.writeHead(200,{'Content-Type':file.endsWith('.html')?'text/html; charset=utf-8':file.endsWith('.js')?'text/javascript; charset=utf-8':'text/css; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"});return res.end(fs.readFileSync(path.join(__dirname,file)));}
  if(req.method==='POST'&&(req.headers.origin!==origin||!/^application\/json(?:;|$)/i.test(req.headers['content-type']||'')))return send(res,403,{error:'Forbidden POST'});
  if(url.pathname==='/api/login'&&req.method==='POST'){const x=await body(req),session=await auth.login(x.email,x.password);return session?.admin?send(res,200,session):send(res,403,{error:'Local administrator required'});}
  const p=await auth.authenticate(req.headers.authorization);if(!canUse(p,auth.policy))return send(res,403,{error:'Forbidden'});
  const x=req.method==='POST'?await body(req):{},t=now(),store=getStore();
  if(url.pathname==='/api/draw'&&req.method==='POST'){
   if(store)return send(res,409,{error:'Existing tournament retained; use a separate state directory for another tournament'});
   const state=d.create(demo(x,t,crypto.randomInt(0,4294967296)),p,auth.policy,t);
   createStore(state);return send(res,201,d.summary(state,p,auth.policy,t));
  }
  if(!store)return send(res,404,{error:'No private tournament'});
  let s=d.advance(store.read(),p,auth.policy,t);
  if(url.pathname==='/api/draw'&&req.method==='GET'){store.save(s);return send(res,200,d.summary(s,p,auth.policy,t));}
  const id=url.searchParams.get('id');
  if(url.pathname==='/api/match'&&req.method==='GET'){const v=d.matchView(s,id,p,auth.policy,t);store.save(s);return send(res,200,v);}
  if(['/api/heartbeat','/api/coach'].includes(url.pathname)&&req.method==='POST'){
   s=d.command(s,id,p,auth.policy,t,url.pathname==='/api/coach'?'coach':'heartbeat',x.targetGame,x.tactics);
   store.save(s);return send(res,200,d.matchView(s,id,p,auth.policy,t));
  }
  return send(res,404,{error:'Unknown endpoint'});
 }catch(e){return send(res,e.status||500,{error:e.status?e.message:'Local tournament request failed'});}};
}
function serve({auth,dir,port=8766}){
 const principal={id:auth.policy.adminId,verified:true,isAdmin:true};
 const opts={kind:'draw',advance:(s,n)=>d.advance(s,principal,auth.policy,n)};
 let store=fs.existsSync(path.join(dir,'tournament.json'))?open(dir,null,opts):null;
 const server=http.createServer(handler({auth,port,getStore:()=>store,createStore:s=>{store=open(dir,s,opts);}}));
 const timer=setInterval(()=>{try{if(store){const old=store.read();if(old.phase!=='completed'){const s=d.advance(old,principal,auth.policy,Date.now());if(s.scheduler.receipts.length!==old.scheduler.receipts.length||s.scheduler.jobs.some((j,i)=>j.fixture.revision!==old.scheduler.jobs[i]?.fixture.revision))store.save(s);}}}catch(e){console.error('Private draw tick:',e.message);}},500);
 let closing=false;const close=()=>{if(closing)return;closing=true;clearInterval(timer);server.close(()=>store?.close());};
 process.on('SIGINT',close);process.on('SIGTERM',close);
 server.on('error',e=>{console.error(e.message);clearInterval(timer);store?.close();process.exitCode=1;});
 server.listen(port,'127.0.0.1',()=>console.log('Private tournament: http://127.0.0.1:'+port));
 return server;
}
module.exports={demo,handler,serve};
