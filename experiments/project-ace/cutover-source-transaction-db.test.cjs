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
 const c='transaction-source-ci',players=Array.from({length:8},(_,i)=>({id:'p'+i})),matches=[];
 for(let round=1;round<=3;round++)for(let number=1;number<=8/2**round;number++)matches.push({id:c+'-'+round+'-'+number,competition_id:c,draw_type:'main_draw',round_number:round,match_number:number,status:'scheduled',started_at:null,completed_at:null,winner_id:null,player1_id:round===1?'p'+(number*2-2):null,player2_id:round===1?'p'+(number*2-1):null,scheduled_season_week:1,scheduled_day:round,scheduled_start_minute:600,court_number:number});
 const source=freezeSource({schema:'ace-source-admission-v1',complete_export:true,competition:{id:c,scope:'singles',field_locked:true,qualification_required:false,status:'published',draw_size:8},players,matches,results:[],simulations:[]});
 const imp=p=>control('import_source_contract('+json(p)+')');
 const key=(a,b)=>c+'-'+a+'-'+b;
 const obs=(id,rev,p)=>control('observe_source('+[lit(id),rev,json(p)].join(',')+')');
 const admit=async(role,id,rev=0)=>JSON.parse(await q(role,'admit_source('+lit(id)+','+rev+')'));
 const observation=(a,b,simulation='none')=>({player1_id:a,player2_id:b,status:'scheduled',simulation,started:false,winner_id:null});
 await control("configure(false,ARRAY[]::text[])");
 const bad=clone(source);bad.matches.at(-1).feeder1=key(1,1);
 await assert.rejects(imp(bad),/rejected/);
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.source_contracts WHERE competition_id='+lit(c)+';'),'0');
 assert.equal(await imp(source),'imported');assert.equal(await imp(source),'already_imported');
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.matches WHERE competition='+lit(c)+';'),'0');
 assert.equal((await admit('ace',key(1,1))).status,'wrong_engine');
 await assert.rejects(seed(c,{match_id:key(1,1),player1_id:'p0',player2_id:'p1'}),/rejected/);
 await assert.rejects(q('external','admit_source('+lit(key(1,1))+',0)'),/permission denied/);
 await control('configure(true,ARRAY['+lit(c)+'])');
 assert.equal((await admit('ace',key(2,1))).status,'participants_pending');
 assert.equal(await obs(key(2,1),0,observation('p0','p2')),'1');
 assert.equal((await admit('ace',key(2,1),1)).status,'feeder_receipts_pending_or_mismatch');
 assert.equal(await obs(key(1,4),0,observation('p6','p7','prepared')),'1');
 await assert.rejects(admit('ace',key(1,4),0),/stale source observation/);
 assert.equal((await admit('ace',key(1,4),1)).status,'existing_source_state');
 const race=await Promise.all([admit('ace',key(1,1)),admit('legacy',key(1,1)),admit('ace',key(1,1))]);
 assert.deepEqual(race.map(x=>x.status).sort(),['admitted','already_admitted','wrong_engine']);
 await assert.rejects(obs(key(1,1),0,observation('p0','p1','prepared')),/rejected/);
 assert.equal((await admit('ace',key(1,2))).status,'admitted');
 for(const [id,w] of [[key(1,1),'p0'],[key(1,2),'p2']]){await start(id);await q('ace','finish_match('+[lit(id),2,lit(w),json({score:'6-0 6-0'})].join(',')+')');}
 assert.equal(await obs(key(2,1),1,observation('p0','p3')),'2');
 assert.equal((await admit('ace',key(2,1),2)).status,'feeder_receipts_pending_or_mismatch');
 assert.equal(await obs(key(2,1),2,observation('p0','p2')),'3');
 assert.equal((await admit('ace',key(2,1),3)).status,'admitted');assert.equal(await start(key(2,1)),'started');
 await control("configure(false,ARRAY[]::text[])");
 assert.equal((await admit('ace',key(2,1),3)).status,'already_admitted');
 assert.equal((await admit('legacy',key(1,3))).status,'admitted');
 assert.equal((await admit('ace',key(1,3))).status,'wrong_engine');
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.source_admissions a JOIN ace_cutover_review.source_slots s USING(match_id) WHERE s.competition_id='+lit(c)+';'),'4');
 console.log('PASS atomic source import rollback, null future slots, stale observations, concurrent exclusive claim, feeder receipt check, direct bypass rejection and disable routing');
}
run().catch(e=>{console.error(e);process.exitCode=1});
