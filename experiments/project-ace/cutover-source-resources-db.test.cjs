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
const {freeze:freezeSource}=require('./source-admission-review.cjs');
async function run(){
 const due=2*86400+600*60;
 async function setup(c,venue,prefix,firstCourt=1,role='ace',shared=null){
  const players=Array.from({length:8},(_,i)=>({id:i===0&&shared?shared:prefix+i})),matches=[];
  for(let round=1;round<=3;round++)for(let number=1;number<=8/2**round;number++)matches.push({id:c+'-'+round+'-'+number,competition_id:c,draw_type:'main_draw',round_number:round,match_number:number,status:'scheduled',started_at:null,completed_at:null,winner_id:null,player1_id:round===1?players[number*2-2].id:null,player2_id:round===1?players[number*2-1].id:null,scheduled_season_week:1,scheduled_day:round,scheduled_start_minute:600,court_number:number===1?firstCourt:number});
  const source=freezeSource({schema:'ace-source-admission-v1',complete_export:true,competition:{id:c,scope:'singles',field_locked:true,qualification_required:false,status:'published',season_number:1,draw_size:8},players,matches,results:[],simulations:[]});
  await control('import_source_contract('+json(source)+')');
  assert.equal(await control('bind_source_venue('+[lit(c),lit(venue)].join(',')+')'),'bound');
  await control('configure('+ (role==='ace')+',ARRAY['+lit(c)+'])');
  const id=matches[0].id;
  assert.equal(JSON.parse(await q(role,'admit_source('+lit(id)+',0)')).status,'admitted');
  assert.equal(await control('publish_source_clock('+[lit(c),-1,due,false].join(',')+')'),'0');
  const e={player1_id:players[0].id,player2_id:players[1].id,complete_health_export:true,health1:[],health2:[],travel_ready:true,resources_ready:true};
  assert.equal(await control('freeze_source_readiness('+[lit(id),-1,1,0,0,json(e)].join(',')+')'),'0');
  return {id,role,c,p1:players[0].id,p2:players[1].id,rev:0};
 }
 const begin=m=>q(m.role,'start_source('+lit(m.id)+',1,'+m.rev+','+m.rev+')');
 const advance=async(m,second)=>{assert.equal(await control('publish_source_clock('+[lit(m.c),m.rev,second,false].join(',')+')'),String(m.rev+1));const e={player1_id:m.p1,player2_id:m.p2,complete_health_export:true,health1:[],health2:[],travel_ready:true,resources_ready:true};assert.equal(await control('freeze_source_readiness('+[lit(m.id),m.rev,1,0,m.rev+1,json(e)].join(',')+')'),String(m.rev+1));m.rev++;};
 const end=m=>q(m.role,'finish_match('+[lit(m.id),2,lit(m.p1),json({score:'6-0 6-0',winner_id:m.p1,actual_duration_minutes:60})].join(',')+')');
 const sync=(m,rev)=>control('sync_source_event('+lit(m.id)+','+rev+')').then(JSON.parse);
 const a=await setup('resource-a-ci','shared-physical-venue','ra');
 const b=await setup('resource-b-ci','shared-physical-venue','rb',1,'legacy');
 const d=await setup('resource-d-ci','other-venue','rd',1,'ace',a.p1);
 const race=await Promise.allSettled([begin(a),begin(b)]);
 assert.equal(race.filter(x=>x.status==='fulfilled'&&x.value==='started').length,1);
 assert.equal(race.filter(x=>x.status==='rejected'&&/source resource conflict: court/.test(x.reason.message)).length,1);
 const won=race[0].status==='fulfilled'?a:b,wait=won===a?b:a;
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.active_source_resources WHERE match_id='+lit(won.id)+';'),'3');
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.source_starts WHERE match_id='+lit(wait.id)+';'),'0');
 assert.equal(await end(won),'completed');await assert.rejects(begin(wait),/source recovery conflict: court/);await advance(wait,due+4500-1);await assert.rejects(begin(wait),/source recovery conflict: court/);await advance(wait,due+4500);assert.equal(await begin(wait),'started');assert.equal(await end(wait),'completed');
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.active_source_resources WHERE match_id IN ('+[a,b].map(x=>lit(x.id)).join(',')+');'),'0');
 // Independent same-player conflict across venues and engines, then release/retry.
 const e=await setup('resource-e-ci','third-venue','re',1,'legacy',a.p1);
 await assert.rejects(begin(d),/source recovery conflict: player/);await advance(d,due+86400);assert.equal(await begin(d),'started');await advance(e,due+86400);await assert.rejects(begin(e),/source resource conflict: player/);
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.active_source_resources WHERE match_id='+lit(e.id)+';'),'0');
 assert.equal(await end(d),'completed');await advance(e,due+86400+7200);await assert.rejects(begin(e),/source recovery conflict: player/);await advance(e,due+2*86400);assert.equal(await begin(e),'started');assert.equal(await end(e),'completed');
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.source_resource_history WHERE match_id IN ('+[a,b,d,e].map(x=>lit(x.id)).join(',')+') AND terminal_revision=3;'),'12');
 await assert.rejects(sync(a,3),/rejected/);
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.source_result_projection WHERE match_id='+lit(a.id)+';'),'0');
 await assert.rejects(q('ace','sync_source_event('+lit(a.id)+',2)'),/permission denied/);
 const started=await sync(a,2);assert.equal(started.status,'in_progress');assert.equal(started.winner_id,null);
 const receipts=await Promise.all([sync(a,3),sync(a,3)]);assert.deepEqual(receipts[0],receipts[1]);assert.equal(receipts[0].winner_id,a.p1);assert.equal(receipts[0].production_ready,false);
 assert.deepEqual(await sync(a,2),started);
 assert.equal(await db.sql('SELECT status FROM ace_cutover_review.source_result_projection WHERE match_id='+lit(a.id)+';'),'completed');
 assert.equal(await db.sql("SELECT payload->>'status' FROM ace_cutover_review.source_observations WHERE match_id="+lit(a.id)+';'),'scheduled');
 await control("configure(false,ARRAY[]::text[])");
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.source_rest_history WHERE match_id IN ('+[a,b,d,e].map(x=>lit(x.id)).join(',')+');'),'12');
 console.log('PASS player recovery, court turnaround, same-day cross-competition hold, exact boundary and retry');
 console.log('PASS shared physical court and cross-venue player exclusion, rollback/retry, exact resource release, ordered immutable source result projection');
}
run().catch(e=>{console.error(e);process.exitCode=1});
