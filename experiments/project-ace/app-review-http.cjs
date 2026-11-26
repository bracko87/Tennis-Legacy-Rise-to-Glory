'use strict';
// Read-only route for the actual app's isolated admin page.
const http=require('node:http'),{createService}=require('./postgres-service.cjs');
function handler({auth,store,port=8769,appOrigin='http://127.0.0.1:8000'}){
 if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(appOrigin))throw Error('Loopback app origin required');
 const service=createService({store,principal:{id:auth.policy.adminId,verified:true,isAdmin:true},policy:auth.policy});
 return async(req,res)=>{
  const send=(status,x)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff',...(req.headers.origin===appOrigin?{'Access-Control-Allow-Origin':appOrigin,Vary:'Origin'}:{})});res.end(JSON.stringify(x));};
  try{
   if(req.headers.host!=='127.0.0.1:'+port||req.headers.origin!==appOrigin)return send(403,{error:'Forbidden origin'});
   if(req.method==='OPTIONS'){res.writeHead(204,{'Access-Control-Allow-Origin':appOrigin,'Access-Control-Allow-Methods':'GET, OPTIONS','Access-Control-Allow-Headers':'Authorization',Vary:'Origin'});return res.end();}
   if(req.method!=='GET')return send(405,{error:'Read-only review'});
   const p=await auth.authenticate(req.headers.authorization);if(!p)return send(403,{error:'Verified review administrator required'});
   const url=new URL(req.url,'http://127.0.0.1:'+port);
   if(url.pathname==='/api/draw')return send(200,await service.summary(p));
   if(url.pathname==='/api/match')return send(200,await service.match(url.searchParams.get('id'),p));
   return send(404,{error:'Unknown review endpoint'});
  }catch(e){return send(e.status||503,{error:e.status?e.message:'Private review unavailable'});}
 };
}
function serve(options){const port=options.port??8769;return http.createServer(handler({...options,port})).listen(port,'127.0.0.1');}
module.exports={handler,serve};
