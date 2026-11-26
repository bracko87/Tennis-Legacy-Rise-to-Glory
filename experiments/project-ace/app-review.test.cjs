'use strict';
const assert=require('node:assert/strict'),http=require('node:http'),{createAuth}=require('./local-supabase-review-auth.cjs'),{handler}=require('./app-review-http.cjs'),{open}=require('./postgres-store.cjs'),world=require('./world-demo.cjs'),{demo}=require('./tournament-http.cjs');
async function run(){
 const uid='11111111-1111-4111-8111-111111111111',url='http://127.0.0.1:54321',key='test-publishable',token='Bearer a.b.c',appOrigin='http://127.0.0.1:8000';
 let user={id:uid,is_anonymous:false},admin=true,calls=[];
 const auth=createAuth({url,key,userId:uid,fetcher:async(u,o)=>{calls.push(u);assert.equal(o.headers.Authorization,token);assert.equal(o.redirect,'error');return {ok:true,json:async()=>u.endsWith('/user')?user:admin};}});
 assert.throws(()=>createAuth({url:'https://example.supabase.co',key,userId:uid}),/isolated/);
 assert.equal(await auth.authenticate('Bearer fake'),null);assert.equal(calls.length,0);
 assert.equal((await auth.authenticate(token)).id,uid);admin=false;assert.equal(await auth.authenticate(token),null);admin=true;
 user={id:uid,is_anonymous:true};assert.equal(await auth.authenticate(token),null);user={id:'other',is_anonymous:false};assert.equal(await auth.authenticate(token),null);user={id:uid,is_anonymous:false};
 const store=open('app-ci'),p={id:uid,verified:true,isAdmin:true};
 await store.save(-1,world.create(demo({delaySeconds:5,pace:'fast'},0,33),p,auth.policy,0));
 const server=http.createServer();await new Promise(r=>server.listen(0,'127.0.0.1',r));const port=server.address().port;
 server.on('request',handler({auth,store,port,appOrigin}));
 const req=(route,method='GET',origin=appOrigin,authorization=token)=>fetch('http://127.0.0.1:'+port+route,{method,headers:{Origin:origin,Authorization:authorization}});
 try{
  const before=await store.read();
  assert.equal((await req('/api/draw','GET','https://untrusted.invalid')).status,403);
  assert.equal((await req('/api/draw','POST')).status,405);
  assert.equal((await req('/api/draw','GET',appOrigin,'Bearer fake')).status,403);
  const response=await req('/api/draw');assert.equal(response.status,200);assert.equal(response.headers.get('access-control-allow-origin'),appOrigin);
  const draw=await response.json();assert.equal(draw.revision,0);assert.equal(draw.matches.length,2);assert.equal('anchor' in draw,false);
  const match=await (await req('/api/match?id=draw-1')).json();assert.equal(match.status,'scheduled');assert.equal('checkpoint' in match,false);
  admin=false;assert.equal((await req('/api/draw')).status,403);
  assert.deepEqual(await store.read(),before);
 }finally{await new Promise(r=>server.close(r));}
 console.log('PASS local Supabase auth contract, exact admin allowlist, read-only app gateway and unchanged PostgreSQL state');
}
run().catch(e=>{console.error(e);process.exitCode=1});
