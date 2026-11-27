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
 const {s,officialMatches}=fixture('rollback-drain-ci'),x=project(s,{officialMatches}),id=x.competition_id;
 const med=x.matches.find(m=>m.completion_reason==='health_walkover');
 await register(id);
 for(const m of x.matches){
  const f=pid=>m===x.matches.at(-1)?x.matches.slice(0,-1).find(z=>z.winner_id===pid).match_id:null;
  await seed(id,m,f(m.player1_id),f(m.player2_id));
  if(m===med){const blocked=m.medically_unavailable_player_ids;const records=[{status:'active',tournamentReturnDay:m.medical_absolute_day+1,fullRecoveryDay:m.medical_absolute_day+2}];await freeze(m.match_id,m.medical_absolute_day,blocked.includes(m.player1_id)?records:[],blocked.includes(m.player2_id)?records:[]);}
  await claim('ace',m.match_id);
 }
 const report=()=>control('drain_status('+lit(id)+')').then(JSON.parse);
 assert.equal((await report()).routing_disabled,false);
 // Disable admissions; existing ownership must be preserved.
 await control("configure(false,ARRAY[]::text[])");
 const first=await report();assert.equal(first.unfinished_matches.length,x.matches.length);assert.equal(first.can_stop_match_worker,false);
 const fresh='rollback-fresh-ci';await control("seed_match('rollback-fresh-match',"+lit(fresh)+",'singles',true,'scheduled','none',false,'a','b')");
 assert.equal((await claim('ace','rollback-fresh-match')).status,'wrong_engine');assert.equal((await claim('legacy','rollback-fresh-match')).status,'claimed');
 assert.equal(await q('legacy',"start_match('rollback-fresh-match',1)"),'started');
 assert.equal(await q('legacy',"finish_match('rollback-fresh-match',2,'a','{}'::jsonb)"),'completed');
 for(const m of x.matches){
  assert.equal((await claim('ace',m.match_id)).status,'already_claimed');
  assert.equal((await claim('legacy',m.match_id)).status,'wrong_engine');
  if(m===med){assert.equal(await finish('ace',m),'completed');}
  else{assert.equal(await start(m.match_id),'started');assert.equal(await q('ace','finish_match('+[lit(m.match_id),2,lit(m.winner_id),json(m)].join(',')+')'),'completed');}
 }
 const drained=await report();assert.equal(drained.can_stop_match_worker,true);assert.equal(drained.can_retire_review_runtime,false);assert.deepEqual(drained.unsettled_protected_competitions,[id]);
 assert.equal(await settle(x),'finalized_review');assert.equal(await settle(x),'already_finalized');assert.equal((await report()).can_retire_review_runtime,true);
 // Dedicated recovery fixtures persist in the dump with routing disabled.
 await control("configure(true,ARRAY['rollback-recovery-ci'])");
 for(const key of ['rollback-recovery-live','rollback-recovery-held']){
  await control("seed_match("+lit(key)+",'rollback-recovery-ci','singles',true,'scheduled','none',false,'p1','p2')");
  assert.equal((await claim('ace',key)).status,'claimed');assert.equal(await start(key),'started');
 }
 await q('external',"request_handoff('rollback-recovery-held','repair','admin_repair')");
 await control("configure(false,ARRAY[]::text[])");
 const held=JSON.parse(await control("drain_status('rollback-recovery-ci')"));assert.equal(held.unfinished_matches.length,2);assert.equal(held.unresolved_handoffs.length,1);assert.equal(held.can_retire_review_runtime,false);
 assert.equal(await q('ace',"finish_match('rollback-recovery-held',2,'p1','{}'::jsonb)"),'handoff_pending');
 assert.equal(JSON.parse(await control("drain_status(NULL)")).can_retire_review_runtime,false);
 console.log('PASS disable/drain, sticky ownership, legacy admissions, settlement gate, unresolved handoff retained for recovery');
}
run().catch(e=>{console.error(e);process.exitCode=1});
