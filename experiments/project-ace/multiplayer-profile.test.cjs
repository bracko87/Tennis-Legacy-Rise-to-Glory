'use strict';
const assert=require('node:assert/strict');
const {adapt,fixtureProfiles}=require('./profiles.cjs');
const {makeOfflineAuth}=require('./start-offline.cjs');
const {makeHandler,createStore}=require('./local-server.cjs');
const http=require('node:http'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
async function run(){
 const [p,q]=fixtureProfiles('power','defensive','grass',true);
 assert.equal(p.rawServe,82);assert.equal(p.surfaceMultiplier,1.015);assert.equal(q.surfaceMultiplier,.995);
 assert.notEqual(fixtureProfiles('power','defensive','clay')[0].rally,p.rally);
 assert.throws(()=>adapt('missing',{},'hard'));assert.throws(()=>fixtureProfiles('bad','power'));
 let now=1000;
 const auth=makeOfflineAuth({email:'admin@example.invalid',password:'admin-pass',peerPassword:'peer-pass',now:()=>now});
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'ace-multi-')),store=createStore(dir),server=http.createServer();
 try{
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  const port=server.address().port,base='http://127.0.0.1:'+port;server.on('request',makeHandler({store,auth,port,now:()=>now}));
  const req=async(p,method='GET',body,token)=>{const headers={Origin:base};if(body!==undefined)headers['Content-Type']='application/json';if(token)headers.Authorization='Bearer '+token;const r=await fetch(base+p,{method,headers,body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,body:await r.json()};};
  const A=(await req('/api/login','POST',{email:'admin@example.invalid',password:'admin-pass'})).body;
  const B=(await req('/api/login','POST',{email:'ace-peer@example.invalid',password:'peer-pass'})).body;
  assert.equal(A.multiplayerEnabled,true);assert.equal(B.admin,false);
  assert.equal((await req('/api/heartbeat','POST',{},B.token)).status,404);
  const ai=await req('/api/fixture','POST',{delaySeconds:5},A.token);assert.equal(ai.status,201);assert.equal(ai.body.pace,'standard');assert.equal(ai.body.pointMinMs,4000);assert.equal(ai.body.pointMaxMs,7000);assert.equal(ai.body.breakMs,5000);
  assert.equal((await req('/api/heartbeat','POST',{},B.token)).status,404);
  now=4000000;assert.equal((await req('/api/fixture','GET',undefined,A.token)).body.status,'completed');
  const created=await req('/api/fixture','POST',{pace:'fast',delaySeconds:10,humanOpponent:true,mode:'manual',peerMode:'manual',surface:'grass',playerPreset:'power',opponentPreset:'defensive'},A.token);
  assert.equal(created.status,201);const id=created.body.id;assert.equal(created.body.surface,'grass');
  assert.equal((await req('/api/heartbeat','POST',{},B.token)).body.side,1);
  assert.equal((await req('/api/coach','POST',{fixtureId:ai.body.id,targetGame:1,tactics:{serve:'Power serving'}},A.token)).status,409);
  const [x,y]=await Promise.all([req('/api/coach','POST',{fixtureId:id,targetGame:1,tactics:{serve:'Power serving'}},A.token),req('/api/coach','POST',{fixtureId:id,targetGame:1,tactics:{rally:'Shorten points'}},B.token)]);
  assert.equal(x.status,200);assert.equal(y.status,200);
  now+=12000;const a=(await req('/api/fixture','GET',undefined,A.token)).body,b=(await req('/api/fixture','GET',undefined,B.token)).body;
  assert.deepEqual(a.events,b.events);assert.deepEqual(a.players,b.players);assert.equal(a.opponentOnline,true);assert.equal(b.opponentOnline,true);
  assert.equal(a.activeTactics.serve,'Power serving');assert.equal(b.activeTactics.rally,'Shorten points');assert.equal(a.ownHistory.length,1);assert.equal(a.ownHistory[0].tactics.rally,'Balanced rallies');assert.equal(a.ownPending,null);assert.equal(a.activeTactics.rally,'Balanced rallies');assert.ok(a.events.every(e=>e.kind!=='tactics'&&!('probability' in e)&&!('conditions' in e)));assert.equal(b.ownHistory[0].tactics.rally,'Shorten points');
  now+=2000000;const final=(await req('/api/fixture','GET',undefined,A.token)).body;
  const peerFinal=(await req('/api/fixture','GET',undefined,B.token)).body;assert.equal(final.status,'completed');assert.equal(final.winner,peerFinal.winner);assert.deepEqual(final.completedSets,peerFinal.completedSets);
 }finally{await new Promise(r=>server.close(r));store.close();fs.rmSync(dir,{recursive:true,force:true});}
 console.log('PASS two real local HTTP sessions, peer waiting lobby, profile mapping, surfaces, private commands, stale fixture rejection and shared result');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
