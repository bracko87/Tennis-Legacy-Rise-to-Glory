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
 const {s,officialMatches}=fixture('cutover-surrender-ok'),x=project(s,{officialMatches}),id=x.competition_id;
 const old=x.matches.find(m=>m.completion_reason==='health_walkover');
 const surrender={...old,completion_reason:'health_surrender',surrendered_player_id:old.player1_id===old.winner_id?old.player2_id:old.player1_id};
 delete surrender.medical_absolute_day;delete surrender.medically_unavailable_player_ids;
 x.matches=x.matches.map(m=>m===old?surrender:m);
 const health=m=>({player_id:m.surrendered_player_id,health_concern:true,human_request_verified:true});
 const freezeS=(m,h=health(m),role='external')=>q(role,'freeze_surrender('+[lit(m.match_id),lit('surrender-event'),lit(m.surrendered_player_id),lit(m.completed_at)+'::timestamptz',json(h)].join(',')+')');
 const done=(m,role='ace',rev=1)=>q(role,'finish_surrender('+[lit(m.match_id),rev,json(m)].join(',')+')');
 await register(id);
 for(const m of x.matches){
  const f=pid=>m===x.matches.at(-1)?x.matches.slice(0,-1).find(z=>z.winner_id===pid).match_id:null;
  await seed(id,m,f(m.player1_id),f(m.player2_id));await claim('ace',m.match_id);
  if(m===surrender){
   await assert.rejects(freezeS(m,{...health(m),health_concern:false}),/verified participant health concern required/);
   await assert.rejects(freezeS(m,{...health(m),human_request_verified:false}),/verified participant health concern required/);
   await assert.rejects(freezeS(m,{...health(m),player_id:'outsider'}),/verified participant health concern required/);
   await assert.rejects(freezeS(m,health(m),'ace'),/permission denied/);
   assert.equal(await freezeS(m),'frozen');assert.equal(await freezeS(m),'already_frozen');
   assert.equal(await start(m.match_id),'handoff_pending');
   await assert.rejects(done(m,'legacy'),/permission denied/);
   await assert.rejects(done(m,'ace',0),/invalid surrender completion/);
   await assert.rejects(done({...m,winner_id:m.surrendered_player_id}),/surrender receipt mismatch/);
   await assert.rejects(done({...m,actual_duration_minutes:1}),/surrender receipt mismatch/);
   assert.deepEqual((await Promise.all([done(m),done(m)])).sort(),['already_completed','completed']);
  }else{
   assert.equal(await start(m.match_id),'started');
   assert.equal(await q('ace','finish_match('+[lit(m.match_id),2,lit(m.winner_id),json(m)].join(',')+')'),'completed');
  }
 }
 const bad=clone(x);bad.conditions.push({match_id:surrender.match_id,player_id:surrender.winner_id});await assert.rejects(settle(bad),/invalid surrender finalization/);
 assert.equal(await db.sql('SELECT count(*) FROM ace_review.finalized_matches WHERE competition_id='+lit(id)+';'),'0');
 assert.equal(await settle(x),'finalized_review');assert.equal(await settle(x),'already_finalized');
 const extra='surrender-extra',m={...surrender,competition_id:extra,match_id:'surrender-live'};
 await register(extra);await seed(extra,m);await claim('ace',m.match_id);await start(m.match_id);
 await assert.rejects(freezeS(m),/unprepared scheduled match required/);
 await assert.rejects(q('ace','finish_match('+[lit(m.match_id),2,lit(m.winner_id),json(m)].join(',')+')'),/use verified surrender completion/);
 const c={...m,match_id:'surrender-conflict'};await seed(extra,c);await claim('ace',c.match_id);await freezeS(c);
 await q('external',"request_handoff('surrender-conflict','travel','travel_no_show')");
 await assert.rejects(done(c),/conflicting external events/);
 await control("configure(false,ARRAY[]::text[])");
 console.log('PASS authenticated-review surrender evidence, zero-play settlement, concurrency, stale revision, live and conflicting event rejection');
}
run().catch(e=>{console.error(e);process.exitCode=1});
