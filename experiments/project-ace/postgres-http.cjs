'use strict';
// Loopback-only HTTP gateway for the disposable PostgreSQL worker.
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {createService,startLoop}=require('./postgres-service.cjs'),world=require('./world-demo.cjs'),{demo}=require('./tournament-http.cjs'),{canUse}=require('./match-service.cjs');
const fail=(message,status)=>Object.assign(Error(message),{status});
const fields={approach:['Defensive','Balanced','Aggressive'],rally:['Shorten points','Balanced rallies','Extend rallies'],serve:['Safe first serve','Balanced','Power serving'],returnGame:['Safe return','Balanced','Attack second serve'],target:['Automatic','Backhand','Forehand','Movement','Stamina']};
function gateway({auth,store,port=8768,reactDir=null,privatePlayer=null,now=Date.now,clock,createWorld=null}){
 const policy=auth.policy,principal={id:policy.adminId,verified:true,isAdmin:true};
 const service=createService({store,principal,policy,now,clock});
 const host='127.0.0.1:'+port,origin='http://'+host;
 let queue=Promise.resolve();
 function serial(fn){const result=queue.then(fn);queue=result.catch(()=>{});return result;}
 const tick=()=>serial(async()=>{if(!await store.read())return {changed:false};return service.tick();});
 const send=(res,status,x)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(x));};
 async function body(req){
  let b='';for await(const c of req){b+=c;if(Buffer.byteLength(b)>8192)throw fail('Body too large',413);}
  let x;try{x=JSON.parse(b||'{}');}catch{throw fail('Invalid JSON',400);}
  if(!x||typeof x!=='object'||Array.isArray(x))throw fail('Expected JSON object',400);return x;
 }
 async function handler(req,res){
  try{
   if(req.headers.host!==host||(req.headers.origin&&req.headers.origin!==origin))throw fail('Forbidden origin',403);
   const url=new URL(req.url,origin),route=url.pathname;
   if(req.method==='GET'&&route==='/'){res.writeHead(302,{Location:'/react','Cache-Control':'no-store'});return res.end();}
   if(req.method==='GET'&&reactDir&&['/react','/react.js','/react.css'].includes(route)){
    const asset=route==='/react'?'index.html':route.slice(1);
    const file=fs.readFileSync(path.join(reactDir,asset));
    res.writeHead(200,{'Content-Type':asset.endsWith('.html')?'text/html; charset=utf-8':asset.endsWith('.js')?'text/javascript; charset=utf-8':'text/css; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"});return res.end(file);
   }
   if(req.method==='POST'&&(req.headers.origin!==origin||!/^application\/json(?:;|$)/i.test(req.headers['content-type']||'')))throw fail('Forbidden POST',403);
   if(route==='/api/login'&&req.method==='POST'){
    const x=await body(req),session=await auth.login(x.email,x.password);
    if(!session)throw fail('Invalid local credentials',403);
    return send(res,200,{...session,profileSource:session.admin&&privatePlayer?'private-import':'synthetic',peerEnabled:policy.multiplayerTest===true,backend:'postgres-review',canCreate:session.admin});
   }
   const p=await auth.authenticate(req.headers.authorization);
   if(!canUse(p,policy)&&!(policy.enabled&&policy.multiplayerTest===true&&p?.verified===true&&p.synthetic===true&&p.id===policy.syntheticId))throw fail('Forbidden',403);
   if(route==='/api/logout'&&req.method==='POST'){await body(req);await auth.logout(req.headers.authorization);return send(res,200,{signedOut:true});}
   if(route==='/api/draw'&&req.method==='POST'){
    if(!canUse(p,policy))throw fail('Administrator required',403);
    const x=await body(req);
    const v=await serial(async()=>{
     if(await store.read())throw fail('Existing tournament retained',409);
     const t=now(),args=demo(x,t,crypto.randomInt(0,4294967296),privatePlayer,policy.multiplayerTest===true);
     const state=createWorld?createWorld(args,p,policy,t):world.create(args,p,policy,t);
     await store.save(-1,state);return service.summary(p);
    });return send(res,201,v);
   }
   if(route==='/api/draw'&&req.method==='GET')return send(res,200,await service.summary(p));
   const id=url.searchParams.get('id');
   if(route==='/api/match'&&req.method==='GET')return send(res,200,await service.match(id,p));
   if(['/api/coach','/api/heartbeat'].includes(route)&&req.method==='POST'){
    const x=await body(req);
    if(route==='/api/coach'&&(!Number.isSafeInteger(x.targetGame)||x.targetGame<1||!x.tactics||typeof x.tactics!=='object'||Array.isArray(x.tactics)||!Object.keys(x.tactics).length||Object.entries(x.tactics).some(([k,v])=>!Object.hasOwn(fields,k)||!fields[k].includes(v))))throw fail('Invalid coaching instructions',400);
    const result=await serial(async()=>{
     // Recheck session after waiting behind the worker.
     const current=await auth.authenticate(req.headers.authorization);if(!current||current.id!==p.id)throw fail('Session expired',403);
     return service.command(id,current,route==='/api/coach'?'coach':'heartbeat',x.targetGame,x.tactics);
    });return send(res,200,result);
   }
   throw fail('Unknown endpoint',404);
  }catch(e){
   const status=e.code==='ACE_REVISION_CONFLICT'||e.code==='ACE_STALE_CLOCK'?409:e.status||503;
   return send(res,status,{error:status===503?'Private database temporarily unavailable':status===409&&e.code==='ACE_REVISION_CONFLICT'?'Concurrent update; refresh and retry if still applicable':e.message});
  }
 }
 return {handler,tick,service};
}
function serve(options){
 const port=options.port??8768,g=gateway({...options,port}),server=http.createServer(g.handler);
 const loop=startLoop({tick:g.tick},{onError:e=>console.error('Private worker:',e.code||e.message)});
 let closing=false;
 const close=async()=>{if(closing)return;closing=true;await loop.stop();server.close();};
 process.once('SIGINT',close);process.once('SIGTERM',close);
 server.on('error',e=>{console.error(e.message);void close();process.exitCode=1;});
 server.listen(port,'127.0.0.1',()=>console.log('Private database React pilot: http://127.0.0.1:'+port+'/react'));
 return server;
}
module.exports={gateway,serve};
