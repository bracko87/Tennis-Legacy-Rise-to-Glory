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

 const target=await setup('ops-projection-target','ops-projection-venue','opsproj');
 const source='ops-projection-source';
 await control('seed_match('+[source,'ops-projection-unprotected','singles'].map(lit).join(',')+",true,'scheduled','none',false,"+[target.p1,'ops-projection-other'].map(lit).join(',')+')');
 await control('configure(true,ARRAY['+lit('ops-projection-unprotected')+'])');
 assert.equal((await claim('ace',source)).status,'claimed');
 assert.equal(await start(source),'started');
 assert.equal(await q('ace','finish_match('+[lit(source),2,lit(target.p1),json({actual_duration_minutes:180})].join(',')+')'),'completed');
 const stage='stage_followup('+[lit(source),lit(target.id),1].join(',')+')';
 assert.equal(await control(stage),'staged_review');
 const apply=(key,rev,minute)=>control('apply_followup_delay('+[lit(source),lit(target.id),lit(key),rev,minute].join(',')+')');
 const effective=()=>control('effective_schedule('+lit(target.id)+')').then(JSON.parse);
 assert.equal((await effective()).scheduled_start_minute,600);
 await assert.rejects(apply('stale',1,720),/rejected/);
 await assert.rejects(apply('early',0,605),/rejected/);
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.followup_attempts WHERE source_id='+lit(source)+';'),'0');
 assert.equal(await apply('delay',0,720),'applied_review');
 assert.equal(await apply('delay',0,720),'already_applied_review');
 await assert.rejects(apply('delay',0,750),/rejected/);
 assert.equal((await effective()).scheduled_start_minute,720);
 assert.equal(await db.sql("SELECT slot->>'scheduled_start_minute' FROM ace_cutover_review.source_slots WHERE match_id="+lit(target.id)+';'),'600');
 assert.equal(await db.sql('SELECT match_revision FROM ace_cutover_review.source_readiness WHERE match_id='+lit(target.id)+';'),'-1');
 await assert.rejects(begin(target),/stale readiness or clock/);
 const evidence={player1_id:target.p1,player2_id:target.p2,complete_health_export:true,health1:[],health2:[],travel_ready:true,resources_ready:true};
 assert.equal(await control('freeze_source_readiness('+[lit(target.id),0,1,0,0,json(evidence)].join(',')+')'),'1');
 assert.equal(await q('ace','start_source('+lit(target.id)+',1,1,0)'),'not_due');
 assert.equal(await control('publish_source_clock('+[lit(target.c),0,due+7200,false].join(',')+')'),'1');
 assert.equal(await control('freeze_source_readiness('+[lit(target.id),1,1,0,1,json(evidence)].join(',')+')'),'2');
 assert.equal(await q('ace','start_source('+lit(target.id)+',1,2,1)'),'started');
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.active_source_resources WHERE match_id='+lit(target.id)+';'),'3');
 assert.equal(await end(target),'completed');
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.schedule_revisions WHERE match_id='+lit(target.id)+';'),'1');
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.followup_attempts WHERE source_id='+lit(source)+';'),'1');
 await control("configure(false,ARRAY[]::text[])");
 console.log('PASS same-day projection, stale and unsafe rollback, exact retry, immutable original, refreshed readiness, revised activation and resource reservation');
}
run().catch(e=>{console.error(e);process.exitCode=1});
