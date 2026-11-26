'use strict';
// Read-only by default; explicitly enabled private coaching only.
const http=require('node:http'),{createService}=require('./postgres-service.cjs');
function handler({auth,store,port=8769,appOrigin='http://127.0.0.1:8000',coaching=false,now=Date.now,clock}){
 if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(appOrigin))throw Error('Loopback app origin required');
 const service=createService({store,principal:{id:auth.policy.adminId,verified:true,isAdmin:true},policy:auth.policy,now,clock});
 const fields={approach:['Defensive','Balanced','Aggressive'],rally:['Shorten points','Balanced rallies','Extend rallies'],serve:['Safe first serve','Balanced','Power serving'],returnGame:['Safe return','Balanced','Attack second serve'],target:['Automatic','Backhand','Forehand','Movement','Stamina']};
 let queue=Promise.resolve();
 function serial(fn){const result=queue.then(fn);queue=result.catch(()=>{});return result;}
 async function body(req){let b='';for await(const chunk of req){b+=chunk;if(Buffer.byteLength(b)>8192)throw Object.assign(Error('Body too large'),{status:413});}let x;try{x=JSON.parse(b);}catch{throw Object.assign(Error('Invalid JSON'),{status:400});}if(!x||typeof x!=='object'||Array.isArray(x))throw Object.assign(Error('Expected JSON object'),{status:400});return x;}
 return async(req,res)=>{
  const send=(status,x)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff',...(req.headers.origin===appOrigin?{'Access-Control-Allow-Origin':appOrigin,Vary:'Origin'}:{})});res.end(JSON.stringify(x));};
  try{
   if(req.headers.host!=='127.0.0.1:'+port||req.headers.origin!==appOrigin)return send(403,{error:'Forbidden origin'});
   if(req.method==='OPTIONS'){res.writeHead(204,{'Access-Control-Allow-Origin':appOrigin,'Access-Control-Allow-Methods':coaching?'GET, POST, OPTIONS':'GET, OPTIONS','Access-Control-Allow-Headers':'Authorization, Content-Type',Vary:'Origin'});return res.end();}
   if(req.method!=='GET'&&!(coaching&&req.method==='POST'))return send(405,{error:'Read-only review'});
   const p=await auth.authenticate(req.headers.authorization);if(!p)return send(403,{error:'Verified review administrator required'});
   const url=new URL(req.url,'http://127.0.0.1:'+port);
   if(req.method==='GET'&&url.pathname==='/api/draw')return send(200,{...await service.summary(p),coachingEnabled:coaching});
   if(req.method==='GET'&&url.pathname==='/api/match')return send(200,await service.match(url.searchParams.get('id'),p));
   if(req.method==='POST'&&['/api/coach','/api/heartbeat'].includes(url.pathname)){
    if(!/^application\/json(?:;|$)/i.test(req.headers['content-type']||''))return send(415,{error:'JSON required'});
    const x=await body(req),id=url.searchParams.get('id'),action=url.pathname==='/api/coach'?'coach':'heartbeat';
    if(!id||!/^draw-[1-9]\d{0,3}$/.test(id))return send(400,{error:'Invalid match ID'});
    if(action==='coach'&&(!Number.isSafeInteger(x.targetGame)||x.targetGame<1||!x.tactics||typeof x.tactics!=='object'||Array.isArray(x.tactics)||!Object.keys(x.tactics).length||Object.keys(x).some(k=>!['targetGame','tactics'].includes(k))||Object.entries(x.tactics).some(([k,v])=>!Object.hasOwn(fields,k)||!fields[k].includes(v))))return send(400,{error:'Invalid coaching instructions'});
    if(action==='heartbeat'&&Object.keys(x).length)return send(400,{error:'Unexpected heartbeat fields'});
    const out=await serial(async()=>{
     const current=await auth.authenticate(req.headers.authorization);
     if(!current||current.id!==p.id)throw Object.assign(Error('Session no longer authorized'),{status:403});
     return service.command(id,current,action,x.targetGame,x.tactics);
    });return send(200,out);
   }
   return send(404,{error:'Unknown review endpoint'});
  }catch(e){const status=['ACE_REVISION_CONFLICT','ACE_STALE_CLOCK'].includes(e.code)?409:e.status||503;return send(status,{error:e.code==='ACE_REVISION_CONFLICT'?'Concurrent update; refresh and submit again only if applicable':status===503?'Private review unavailable':e.message});}
 };
}
function serve(options){const port=options.port??8769;return http.createServer(handler({...options,port})).listen(port,'127.0.0.1');}
module.exports={handler,serve};
