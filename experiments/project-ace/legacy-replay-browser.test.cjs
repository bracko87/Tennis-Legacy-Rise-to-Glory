'use strict';
const assert=require('node:assert/strict'),http=require('node:http'),path=require('node:path'),fs=require('node:fs'),{build}=require('esbuild'),{chromium}=require('playwright'),a=require('./engine.cjs'),{calculate}=require('./official-statistics.cjs'),{fromCheckpoint}=require('./official-replay-adapter.cjs');
async function run(){
 const root=path.resolve(__dirname,'../..'),stub=path.join(__dirname,'legacy-replay-rpc-stub.ts');
 const out=await build({absWorkingDir:root,entryPoints:[path.join(__dirname,'legacy-replay-browser-harness.tsx')],bundle:true,format:'iife',jsx:'automatic',write:false,outdir:'review-output',metafile:true,plugins:[{name:'isolated-rpc',setup(b){b.onResolve({filter:/lib\/supabase$/},()=>({path:stub}));}}]});
 const allowed=['experiments/project-ace/legacy-replay-browser-harness.tsx','experiments/project-ace/legacy-replay-rpc-stub.ts','src/components/tournament/TournamentMatchReplayModal.tsx','src/components/common/CountryFlag.tsx','src/hooks/usePlayerAvatarUrl.ts','src/styles/tournament-match-replay.css','src/styles/tournament-match-replay-score-v2.css'];
 for(const name of Object.keys(out.metafile.inputs))assert.ok(name.startsWith('node_modules/')||allowed.includes(name),'Unexpected bundle input: '+name);
 const js=out.outputFiles.find(f=>f.path.endsWith('.js')).contents,css=out.outputFiles.find(f=>f.path.endsWith('.css')).contents;
 const p={name:'First Player',serve:62,return:58,rally:60,forehand:65,backhand:55,fitness:65,stamina:68,movement:62,fatigue:10,focus:75,confidence:70},q={...p,name:'Second Player',backhand:42,stamina:55};
 let s=a.createMatch({players:[p,q],seed:6,bestOf:3});while(s.status!=='completed')s=a.stepGame(s);
 const ids=['p1','p2'],stats=calculate(s.events.filter(e=>e.kind==='point')),sets=s.completedSets.map((x,i)=>({match_id:'m',set_number:i+1,player1_games:x.games[1],player2_games:x.games[0],player1_tiebreak_points:x.tiebreak?.[1]??null,player2_tiebreak_points:x.tiebreak?.[0]??null,status:'completed'}));
 const m={match_id:'m',status:'completed',player1_id:'p2',player2_id:'p1',winner_id:ids[s.winner],score:sets.map(x=>x.player1_games+'-'+x.player2_games).join(' '),sets,stats:[1,0].map(i=>({match_id:'m',player_id:ids[i],...stats[i]}))};
 const r=fromCheckpoint(m,s,ids,480),full={status:'completed',player1_id:m.player1_id,player2_id:m.player2_id,player1_name:q.name,player2_name:p.name,winner_id:m.winner_id,final_score:{score:m.score,sets},events:r.events,replay_duration_seconds:480,historical_replay:true,controls_locked:false};
 let mode='completed';
 const server=http.createServer((req,res)=>{
  if(req.url==='/'){res.setHeader('Content-Type','text/html');res.end('<!doctype html><html><head><link rel="stylesheet" href="/style.css"></head><body><div id="root"></div><script src="/app.js"></script></body></html>');}
  else if(req.url==='/app.js'){res.setHeader('Content-Type','application/javascript');res.end(js);}
  else if(req.url==='/style.css'){res.setHeader('Content-Type','text/css');res.end(css);}
  else if(req.url==='/fixture/get_tournament_match_detail_v1'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(null));}
  else if(req.url==='/fixture/get_tournament_match_replay_v1'){res.setHeader('Content-Type','application/json');const elapsed=30,events=full.events.filter(e=>e.offset_seconds<=elapsed);res.end(JSON.stringify(mode==='completed'?full:{...full,status:'live',winner_id:null,final_score:null,controls_locked:true,historical_replay:false,elapsed_seconds:elapsed,events,last_event:events.at(-1)}));}
  else{res.statusCode=404;res.end();}
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const base='http://127.0.0.1:'+server.address().port;
 let browser;const external=[],errors=[];
 try{
  browser=await chromium.launch({headless:true});const ctx=await browser.newContext();
  await ctx.route('**/*',route=>{if(new URL(route.request().url()).origin===base)return route.continue();external.push(route.request().url());return route.abort();});
  const page=await ctx.newPage();page.on('pageerror',e=>errors.push(e.message));
  await page.goto(base);await page.getByRole('heading',{name:m.score,exact:true}).waitFor();
  assert.equal(await page.locator('.tlg-replay-player-card.winner h3').textContent(),m.winner_id==='p1'?p.name:q.name);
  await page.getByRole('button',{name:'Watch Replay'}).click();
  await page.getByRole('button',{name:'Pause',exact:true}).click();
  await page.getByRole('button',{name:'4×',exact:true}).click();
  await page.getByRole('button',{name:'Next Game',exact:true}).click();
  await page.getByRole('button',{name:'Next Set',exact:true}).click();
  await page.getByRole('button',{name:'Final Result',exact:true}).click();
  const rows=page.locator('.tlg-replay-score-row');
  assert.deepEqual((await rows.nth(0).locator('.set-cell').allTextContents()).slice(0,sets.length),sets.map(x=>String(x.player1_games)));
  assert.deepEqual((await rows.nth(1).locator('.set-cell').allTextContents()).slice(0,sets.length),sets.map(x=>String(x.player2_games)));
  assert.equal(await rows.nth(0).locator('.result-cell').textContent(),String(s.sets[1]));
  assert.equal(await rows.nth(1).locator('.result-cell').textContent(),String(s.sets[0]));
  await page.getByRole('button',{name:'Restart',exact:true}).click();
  await page.getByRole('button',{name:'Close replay'}).click();await page.getByText('Closed',{exact:true}).waitFor();
  mode='live';await page.reload();await page.getByText('LIVE · 1× LOCKED',{exact:true}).waitFor();
  for(const name of ['Pause','Restart','Next Game','Next Set','Final Result','4×'])assert.equal(await page.getByRole('button',{name,exact:true}).count(),0);
  assert.equal(await page.locator('.tlg-replay-result-center').count(),0);assert.deepEqual(external,[]);assert.deepEqual(errors,[]);
  await ctx.close();
 }finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
 console.log('PASS actual Legacy replay modal, Ace generated reverse-order final score, historical controls and live control lock; fixture RPC only');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
