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
 const {s,officialMatches}=fixture('cutover-travel-ok'),x=project(s,{officialMatches}),id=x.competition_id;
 const old=x.matches.find(m=>m.completion_reason==='health_walkover');
 const travel={...old,completion_reason:'travel_no_show',travel_absolute_day:old.medical_absolute_day,travel_unavailable_player_ids:old.medically_unavailable_player_ids};
 delete travel.medical_absolute_day;delete travel.medically_unavailable_player_ids;
 x.matches=x.matches.map(m=>m===old?travel:m);
 await register(id);
 for(const m of x.matches){
  const f=pid=>m===x.matches.at(-1)?x.matches.slice(0,-1).find(z=>z.winner_id===pid).match_id:null;
  await seed(id,m,f(m.player1_id),f(m.player2_id));
 }
 const final=x.matches.at(-1);
 await claim('ace',final.match_id);
 await assert.rejects(start(final.match_id),/feeder not ready/);
 const ft=(m,b1,b2,r1='NULL',r2='NULL')=>q('external','freeze_travel('+[lit(m.match_id),lit('travel-event'),m.travel_absolute_day,b1,b2,r1,r2].join(',')+')');
 const done=(m,role='ace')=>q(role,'finish_travel('+[lit(m.match_id),1,json(m)].join(',')+')');
 for(const m of x.matches){
  if(m!==final)await claim('ace',m.match_id);
  if(m===travel){
   const blocked=m.travel_unavailable_player_ids;
   assert.equal(await ft(m,blocked.includes(m.player1_id),blocked.includes(m.player2_id)),'frozen');
   assert.equal(await ft(m,blocked.includes(m.player1_id),blocked.includes(m.player2_id)),'already_frozen');
   await assert.rejects(ft(m,true,true),/conflicting travel evidence/);
   assert.equal(await start(m.match_id),'handoff_pending');
   await assert.rejects(done(m,'legacy'),/permission denied/);
   await assert.rejects(done({...m,winner_id:m.player1_id===m.winner_id?m.player2_id:m.player1_id}),/travel receipt mismatch/);
   assert.deepEqual((await Promise.all([done(m),done(m)])).sort(),['already_completed','completed']);
  }else{
   assert.equal(await start(m.match_id),'started');
   assert.equal(await q('ace','finish_match('+[lit(m.match_id),2,lit(m.winner_id),json(m)].join(',')+')'),'completed');
  }
 }
 const bad=clone(x);bad.support_events.push({match_id:travel.match_id,player_id:travel.winner_id});await assert.rejects(settle(bad),/invalid travel finalization/);
 assert.equal(await db.sql('SELECT count(*) FROM ace_review.finalized_matches WHERE competition_id='+lit(id)+';'),'0');
 assert.equal(await settle(x),'finalized_review');assert.equal(await settle(x),'already_finalized');
 assert.deepEqual(JSON.parse(await db.sql('SELECT payload FROM ace_review.finalized_matches WHERE match_id='+lit(travel.match_id)+';')),travel);
 const tieComp='travel-tie',t={...travel,competition_id:tieComp,match_id:'travel-tie-match',winner_id:travel.player1_id,travel_unavailable_player_ids:[travel.player1_id,travel.player2_id]};
 await register(tieComp);await seed(tieComp,t);await claim('ace',t.match_id);await ft(t,true,true,100,100);assert.equal(await done(t),'completed');
 const conflict={...t,match_id:'travel-conflict'};await seed(tieComp,conflict);await claim('ace',conflict.match_id);await ft(conflict,true,true,100,200);
 await q('external',"request_handoff('travel-conflict','guest','guest_retirement')");
 await assert.rejects(done(conflict),/conflicting external events/);
 assert.equal(await db.sql("SELECT count(*) FROM ace_cutover_review.handoffs WHERE match_id='travel-conflict' AND resolution IS NULL;"),'2');
 // Medical zero-play result must also wait for feeder confirmation.
 const med={...old,competition_id:tieComp,match_id:'medical-feeder',player1_id:t.player1_id,player2_id:t.player2_id,winner_id:t.player2_id,medically_unavailable_player_ids:[t.player1_id],medical_absolute_day:8};
 const f={...t,match_id:'unfinished-feeder'};await seed(tieComp,f);await seed(tieComp,med,f.match_id,null);
 await freeze(med.match_id,8,[{status:'active',tournamentReturnDay:9,fullRecoveryDay:10}],[]);await claim('ace',med.match_id);
 await assert.rejects(finish('ace',med),/feeder not ready/);
 assert.equal(await db.sql("SELECT count(*) FROM ace_cutover_review.effects WHERE match_id='medical-feeder';"),'0');
 await control("configure(false,ARRAY[]::text[])");
 console.log('PASS feeder admission guard for played and medical matches, travel evidence, duplicate completion, zero-play settlement and external conflict retention');
}
run().catch(e=>{console.error(e);process.exitCode=1});
