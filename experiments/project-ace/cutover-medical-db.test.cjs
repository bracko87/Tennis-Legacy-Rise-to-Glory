'use strict';
const assert=require('node:assert/strict'),{spawn}=require('node:child_process'),{connection}=require('./postgres-store.cjs'),{fixture}=require('./medical-settlement.test.cjs'),{project}=require('./official-settlement-review.cjs');
const db=connection(),clone=x=>JSON.parse(JSON.stringify(x));
const lit=x=>x===null?'NULL':"convert_from(decode('"+Buffer.from(String(x)).toString('base64')+"','base64'),'UTF8')";
const json=x=>lit(JSON.stringify(x))+'::jsonb';
function engine(role,sql){
 assert.ok(['ace','legacy','external'].includes(role));assert.equal(process.env.ACE_REVIEW_DB,'1');
 const port=Number(process.env.ACE_REVIEW_DB_PORT||55432);assert.ok(Number.isInteger(port)&&port>=1024&&port<=65535);
 return new Promise((resolve,reject)=>{
  const p=spawn('psql',['-X','-qAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',String(port),'-U','ace_cutover_'+role,'-d','ace_review','-w'],{env:{PATH:process.env.PATH,PGPASSWORD:'ace-disposable-'+role,PGCONNECT_TIMEOUT:'5',PGSSLMODE:'disable'},stdio:['pipe','pipe','pipe']});
  let out='',err='';const t=setTimeout(()=>{p.kill();reject(Error('cutover timeout'));},15000);
  p.stdout.on('data',x=>out+=x);p.stderr.on('data',x=>err+=x);p.stdin.on('error',()=>{});
  p.on('error',e=>{clearTimeout(t);reject(e);});p.on('close',code=>{clearTimeout(t);code===0?resolve(out.trim()):reject(Error(err));});p.stdin.end(sql+'\n');
 });
}
const q=(role,fn)=>engine(role,'SELECT ace_cutover_review.'+fn+';'),control=fn=>db.sql('SELECT ace_cutover_review.'+fn+';');
const freeze=(id,day,a,b)=>control('freeze_medical('+[lit(id),day,json(a),json(b)].join(',')+')');
const finish=(role,m,rev=1)=>q(role,'finish_medical('+[lit(m.match_id),rev,json(m)].join(',')+')');
const claim=async(role,id)=>JSON.parse(await q(role,'claim('+lit(id)+')'));
const start=(id,rev=1)=>q('ace','start_match('+lit(id)+','+rev+')');
const settle=x=>q('ace','settle_owned('+json(x)+',NULL)');
async function register(id){await control('register_competition('+lit(id)+')');await control('configure(true,ARRAY['+lit(id)+'])');}
async function seed(id,m,a=null,b=null){await control('seed_match('+[m.match_id,id,'singles'].map(lit).join(',')+",true,'scheduled','none',false,"+[m.player1_id,m.player2_id].map(lit).join(',')+')');await control('bind_feeders('+[m.match_id,a,b].map(lit).join(',')+')');}
async function run(){
 const {s,officialMatches}=fixture('cutover-medical-ok'),x=project(s,{officialMatches}),id=x.competition_id;
 await register(id);
 const walk=x.matches.find(m=>m.completion_reason==='health_walkover'),e=s.draw.medicalEvidence[0];
 const records=pid=>e.health.find(h=>s.source.players.find(z=>z.local===h.playerId).source===pid).records;
 for(const m of x.matches){
  const f=pid=>m===x.matches.at(-1)?x.matches.slice(0,-1).find(z=>z.winner_id===pid).match_id:null;
  await seed(id,m,f(m.player1_id),f(m.player2_id));
  if(m===walk){
   assert.equal(await freeze(m.match_id,e.absoluteDay,records(m.player1_id),records(m.player2_id)),'frozen');
   assert.equal(await freeze(m.match_id,e.absoluteDay,records(m.player1_id),records(m.player2_id)),'already_frozen');
   await assert.rejects(freeze(m.match_id,e.absoluteDay,[],[]),/rejected/);
   assert.equal((await claim('ace',m.match_id)).status,'claimed');
   await assert.rejects(start(m.match_id),/medical restriction/);
   await assert.rejects(finish('legacy',m),/permission denied/);
   await assert.rejects(finish('ace',{...m,winner_id:m.player1_id===m.winner_id?m.player2_id:m.player1_id}),/medical receipt mismatch/);
   await assert.rejects(finish('ace',{...m,actual_duration_minutes:60}),/medical receipt mismatch/);
   assert.deepEqual((await Promise.all([finish('ace',m),finish('ace',m)])).sort(),['already_completed','completed']);
  }else{
   assert.equal((await claim('ace',m.match_id)).status,'claimed');assert.equal(await start(m.match_id),'started');
   assert.equal(await q('ace','finish_match('+[lit(m.match_id),2,lit(m.winner_id),json(m)].join(',')+')'),'completed');
  }
 }
 const wrong=clone(x);wrong.conditions.push({match_id:walk.match_id,player_id:walk.winner_id});await assert.rejects(settle(wrong),/invalid medical finalization/);
 assert.equal(await db.sql('SELECT count(*) FROM ace_review.finalized_matches WHERE competition_id='+lit(id)+';'),'0');
 assert.equal(await settle(x),'finalized_review');assert.equal(await settle(x),'already_finalized');
 assert.deepEqual(JSON.parse(await db.sql('SELECT payload FROM ace_review.finalized_matches WHERE match_id='+lit(walk.match_id)+';')),walk);
 assert.equal(await db.sql('SELECT started FROM ace_cutover_review.matches WHERE id='+lit(walk.match_id)+';'),'f');
 const eventComp='cutover-medical-handoff',m={...walk,competition_id:eventComp,match_id:'medical-handoff'};
 await register(eventComp);await seed(eventComp,m);
 await freeze(m.match_id,e.absoluteDay,records(walk.player1_id),records(walk.player2_id));
 await claim('ace',m.match_id);
 assert.equal(await q('external',"request_handoff('medical-handoff','guest','guest_retirement')"),'queued');
 assert.equal(await finish('ace',m),'handoff_pending');
 await assert.rejects(q('ace',"resolve_handoff('medical-handoff','guest',1,'walkover',"+lit(m.winner_id)+")"),/dedicated adapter/);
 assert.equal(await db.sql("SELECT status FROM ace_cutover_review.matches WHERE id='medical-handoff';"),'scheduled');
 assert.equal(await db.sql("SELECT count(*) FROM ace_cutover_review.handoffs WHERE match_id='medical-handoff' AND resolution IS NULL;"),'1');
 // Independently test exact clearance and both-blocked tie using a minimal fixture.
 const tieComp='cutover-medical-tie',t={...walk,competition_id:tieComp,match_id:'medical-tie',medical_absolute_day:8,winner_id:walk.player1_id,medically_unavailable_player_ids:[walk.player1_id,walk.player2_id]};
 await register(tieComp);await seed(tieComp,t);
 const blocked=[{status:'active',tournamentReturnDay:9,fullRecoveryDay:10}];
 await freeze(t.match_id,8,blocked,blocked);await claim('ace',t.match_id);
 assert.equal(await finish('ace',t),'completed');
 const clear={...t,match_id:'medical-clear',medically_unavailable_player_ids:[]};await seed(tieComp,clear);
 await freeze(clear.match_id,9,blocked,blocked);await claim('ace',clear.match_id);
 await assert.rejects(finish('ace',{...clear,medical_absolute_day:9}),/both medically eligible/);
 assert.equal(await start(clear.match_id),'started');
 await assert.rejects(q('ace','finish_match('+[lit(clear.match_id),2,lit(clear.winner_id),json(clear)].join(',')+')'),/use verified medical completion/);
 await control("configure(false,ARRAY[]::text[])");
 console.log('PASS frozen medical ownership, zero-play completion, tie and exact clearance, concurrent retry, atomic settlement, pending external handoff and generic finish rejection');
}
run().catch(e=>{console.error(e);process.exitCode=1});
