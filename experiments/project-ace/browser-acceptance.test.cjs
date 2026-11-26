'use strict';
// Real Chromium against the isolated React pilot and real review PostgreSQL.
// Auth uses local temporary accounts, not Supabase JWTs.
const assert=require('node:assert/strict'),http=require('node:http'),path=require('node:path'),{chromium}=require('playwright'),{open}=require('./postgres-store.cjs'),{gateway}=require('./postgres-http.cjs'),{makeOfflineAuth}=require('./start-offline.cjs'),{demo}=require('./tournament-http.cjs'),world=require('./world-demo.cjs'),c=require('./world-clock.cjs');
async function run(){
 let ms=0,game=c.slot(1,1,1,600)-300;
 const auth=makeOfflineAuth({email:'admin@example.invalid',password:'admin-pass',peerPassword:'peer-pass',now:()=>ms});
 const p={id:auth.policy.adminId,verified:true,isAdmin:true},store=open('browser-ci');
 await store.save(-1,world.create(demo({delaySeconds:5,pace:'fast',mode:'manual',peerMode:'manual'},0,33,null,true),p,auth.policy,0));
 const server=http.createServer();await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const port=server.address().port,base='http://127.0.0.1:'+port;
 const g=gateway({auth,store,port,reactDir:path.join(__dirname,'react-dist'),now:()=>ms,clock:()=>({server_now:new Date(ms).toISOString(),game_total_seconds:game,speed_multiplier:60})});
 server.on('request',g.handler);
 let browser;const external=[],errors=[];
 async function context(){
  const ctx=await browser.newContext();
  await ctx.route('**/*',route=>{if(new URL(route.request().url()).origin===base)return route.continue();external.push(route.request().url());return route.abort();});
  const page=await ctx.newPage();page.on('pageerror',e=>errors.push(e.message));return {ctx,page};
 }
 async function login(page,email,password){
  await page.goto(base+'/react');
  await page.getByLabel('Email',{exact:true}).fill(email);
  await page.getByLabel('Temporary local password').fill(password);
  await page.getByRole('button',{name:'Sign in',exact:true}).click();
  await page.getByRole('button',{name:'Tournament',exact:true}).waitFor();
 }
 const tick=async(t,day,hour=10)=>{ms=t;game=c.slot(1,1+Math.floor((day-1)/7),(day-1)%7+1,hour*60);await g.tick();};
 try{
  browser=await chromium.launch({headless:true});
  const A=await context(),B=await context(),a=A.page,b=B.page;
  await login(a,'admin@example.invalid','admin-pass');await login(b,'ace-peer@example.invalid','peer-pass');
  await tick(5000,1);await a.getByText('qualification · R1 · live',{exact:true}).first().waitFor();
  await b.getByText('qualification · R1 · live',{exact:true}).first().click();
  await b.getByRole('heading',{name:'Spectating · live',exact:true}).waitFor();
  assert.equal(await b.getByRole('button',{name:'Send next-game instructions'}).count(),0);
  await tick(1000000,1,11);await tick(1100000,2);await tick(2100000,2,11);await tick(2200000,3);
  for(const page of [a,b]){
   await page.getByRole('button',{name:'Tournament',exact:true}).click();
   await page.getByRole('button',{name:'Go to my next match'}).click();
   await page.getByRole('heading',{name:'Your match · live',exact:true}).waitFor();
  }
  await a.getByLabel('Serve',{exact:true}).selectOption('Power serving');
  await b.getByLabel('Rally length',{exact:true}).selectOption('Shorten points');
  for(const page of [a,b]){
   const result=page.waitForResponse(res=>res.url().includes('/api/coach?')&&res.request().method()==='POST');
   await page.getByRole('button',{name:'Send next-game instructions'}).click();
   assert.equal((await result).status(),200);
  }
  await a.getByText(/Queued:.*Power serving/).waitFor();await b.getByText(/Queued:.*Shorten points/).waitFor();
  const state=await store.read(),mine=state.state.draw.scheduler.jobs.find(j=>j.playerKeys.includes('p0')&&j.status==='live'),peer=state.state.draw.scheduler.jobs.find(j=>j.playerKeys.includes('p2')&&j.status==='live');
  assert.ok(mine&&peer);
  ms=Math.max(mine.fixture.active.endAt,peer.fixture.active.endAt)+5000;await g.tick();
  await a.getByText(/Active:.*Power serving/).waitFor();await b.getByText(/Active:.*Shorten points/).waitFor();
  // Browser shutdown must not stop the worker or lose the committed commands.
  await A.ctx.close();await B.ctx.close();
  await tick(3200000,3,11);await tick(3300000,4);await tick(4300000,4,11);await tick(4400000,8);
  const done=await open('browser-ci').read();
  assert.equal(done.state.draw.phase,'completed');assert.equal(done.state.draw.scheduler.receipts.length,6);
  assert.equal(done.state.ledger.transactions.length,2);assert.ok(done.state.ledger.results.every(x=>x.status==='published'));
  const ledger=done.state.ledger,own=ledger.results.find(x=>x.player==='p0'),gear=done.state.draw.worldSupport.players.p0.inventory.find(x=>x.id==='r1');
  assert.ok(own&&gear.condition<21);
  const restored=await context();await login(restored.page,'admin@example.invalid','admin-pass');
  await restored.page.getByRole('heading',{name:/Champion:/}).waitFor();
  await restored.page.getByText('6 matches completed',{exact:true}).waitFor();
  await restored.page.getByRole('button',{name:'Career',exact:true}).click();
  await restored.page.getByText(new RegExp('Published ranking points: '+own.points+' ·')).waitFor();
  await restored.page.getByText('racket r1: '+gear.condition+'% condition',{exact:true}).waitFor();
  assert.deepEqual((await store.read()).state.ledger,ledger);
  await restored.ctx.close();
  // A separate disposable world with an injury-blocked final exercises the W/O UI.
  ms=0;game=c.slot(1,1,1,600)-300;
  const medicalStore=open('browser-medical-ci'),draw=demo({delaySeconds:5,pace:'fast'},0,33,null,true);
  const absoluteDay=Math.floor(c.slot(1,1,1,600)/c.DAY);
  const initial=require('./world-worker.cjs').create({
   draw:{...draw,entrants:draw.entrants.filter(x=>['p0','p2'].includes(x.id)),mainSlots:['p0','p2'],qualification:[],courts:['court-1']},
   config:{competition:'browser-medical',series:'browser-medical',season:1,lastWeek:1,medicalWalkovers:true,slots:[{id:'draw-1',phase:'main_draw',week:1,day:1,minute:600,firstWeek:1,lastWeek:1,court:1}],rewards:[{stage_code:'winner',ranking_points:100,prize_money_usd:1000},{stage_code:'runner_up',ranking_points:60,prize_money_usd:500}]},
   support:{p0:{injuries:[{status:'active',tournamentReturnDay:absoluteDay+1,fullRecoveryDay:absoluteDay+2}]}}
  },p,auth.policy,{server_now:new Date(ms).toISOString(),game_total_seconds:game,speed_multiplier:60});
  await medicalStore.save(-1,initial);
  server.removeListener('request',g.handler);
  const mg=gateway({auth,store:medicalStore,port,reactDir:path.join(__dirname,'react-dist'),now:()=>ms,clock:()=>({server_now:new Date(ms).toISOString(),game_total_seconds:game,speed_multiplier:60})});
  server.on('request',mg.handler);
  const MA=await context(),MB=await context();
  await login(MA.page,'admin@example.invalid','admin-pass');await login(MB.page,'ace-peer@example.invalid','peer-pass');
  ms=5000;game=c.slot(1,1,1,600);await mg.tick();
  for(const page of [MA.page,MB.page]){
   await page.getByText('main draw · R1 · W/O',{exact:true}).waitFor();
   await page.getByText('main draw · R1 · W/O',{exact:true}).click();
   await page.getByRole('heading',{name:'Medical walkover (W/O)',exact:true}).waitFor();
   await page.getByText('Winner: Power Server',{exact:true}).last().waitFor({state:'visible'});
   assert.equal(await page.getByRole('button',{name:'Send next-game instructions'}).count(),0);
   await page.getByRole('button',{name:'Career',exact:true}).click();
  }
  await MA.page.getByText('You were medically unavailable and the opponent advanced.',{exact:true}).waitFor();
  assert.equal(await MB.page.getByText('You were medically unavailable and the opponent advanced.',{exact:true}).count(),0);
  await MA.ctx.close();await MB.ctx.close();
  assert.deepEqual(external,[]);assert.deepEqual(errors,[]);
 }finally{if(browser)await browser.close();await new Promise(r=>server.close(r));}
 console.log('PASS Chromium two-manager browser acceptance, live coaching, offline completion, database restoration, equipment, prize and ranking display; no external requests');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
