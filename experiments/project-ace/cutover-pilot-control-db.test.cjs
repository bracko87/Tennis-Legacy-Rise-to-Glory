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
const {freeze:freezeSource}=require('./source-admission-review.cjs');
async function run(){
 const c='pilot-control-ci',players=Array.from({length:8},(_,i)=>({id:c+'-p'+i})),matches=[];
 for(let round=1;round<=3;round++)for(let number=1;number<=8/2**round;number++)matches.push({id:c+'-'+round+'-'+number,competition_id:c,draw_type:'main_draw',round_number:round,match_number:number,status:'scheduled',started_at:null,completed_at:null,winner_id:null,player1_id:round===1?players[number*2-2].id:null,player2_id:round===1?players[number*2-1].id:null,scheduled_season_week:1,scheduled_day:round,scheduled_start_minute:600,court_number:number});
 const source=freezeSource({schema:'ace-source-admission-v1',complete_export:true,competition:{id:c,scope:'singles',field_locked:true,qualification_required:false,status:'published',season_number:1,draw_size:8},players,matches,results:[],simulations:[]});
 const report=()=>control('pilot_preflight('+lit(c)+')').then(JSON.parse);
 await control("configure(false,ARRAY[]::text[])");
 await control('import_source_contract('+json(source)+')');
 const initial=await report();assert.equal(initial.status,'blocked_review');for(const x of ['venue_missing','career_scope_missing','career_records_missing','clock_missing'])assert.ok(initial.blockers.includes(x),x);
 await assert.rejects(q('ace','pilot_preflight('+lit(c)+')'),/permission denied/);
 await control('bind_source_venue('+lit(c)+",'pilot-ci-venue')");
 await control('enable_source_career_review('+lit(c)+",'hard')");
 const profile={fatigue:30,sharpness:60,morale:60,confidence:60,focus:60,fitness:65,stamina:65,recovery:65,movement:65};
 for(const p of players)await control('observe_source_career('+[lit(p.id),-1,json({profile,staff:{},injuries:[],inventory:[{id:p.id+'-r',type:'racket',condition:80,wear_per_match:2}],loadout:{racket:p.id+'-r',shoes:null,apparel:null}})].join(',')+')');
 const due=2*86400+36000;
 await control('publish_source_clock('+[lit(c),-1,due-1,false].join(',')+')');
 const clean=await report();assert.equal(clean.status,'isolated_preflight_matched');assert.deepEqual(clean.blockers,[]);assert.equal(clean.activation_authorized,false);assert.equal(clean.production_ready,false);assert.equal(clean.entrants,8);assert.equal(clean.expected_matches,7);assert.equal(clean.first_due_game_second,due);
 assert.deepEqual(await report(),clean);
 const approval={schema:'ace-isolated-pilot-approval-v1',competition_id:c,scope:'disposable-synthetic-only',explicit_approval:true,rollback_rehearsed:true,monitoring_ready:true,approval_reference:'synthetic-ci-authorization'};
 const activate=(preflight=clean,auth=approval)=>control('activate_pilot('+[lit(c),json(preflight),json(auth)].join(',')+')').then(JSON.parse);
 const stop=reason=>control('stop_pilot('+[lit(c),lit(reason)].join(',')+')').then(JSON.parse);
 const monitor=()=>control('pilot_monitor('+lit(c)+')').then(JSON.parse);
 await assert.rejects(activate(clean,{...approval,explicit_approval:false}),/rejected operation/);
 await assert.rejects(activate({...clean,clock_revision:99}),/rejected operation/);
 await assert.rejects(q('ace','activate_pilot('+[lit(c),json(clean),json(approval)].join(',')+')'),/permission denied/);
 const race=await Promise.all([activate(),activate()]);assert.deepEqual(race.map(x=>x.status).sort(),['activated_isolated','already_active']);
 await assert.rejects(control("configure(false,ARRAY[]::text[])"),/rejected operation/);
 await assert.rejects(control("configure(true,ARRAY['other'])"),/rejected operation/);
 assert.equal((await monitor()).state,'active_isolated');
 const health=()=>control('pilot_health('+lit(c)+',900)').then(JSON.parse);
 const register=expected=>control('register_pilot_worker('+lit(c)+','+expected+')');
 const pulse=(generation,sequence)=>q('ace','pilot_worker_pulse('+lit(c)+','+generation+','+sequence+')');
 const missing=await health();assert.equal(missing.heartbeat_state,'missing');assert.equal(missing.recommendation,'operator_investigation');
 assert.equal(await register(-1),'0');
 await assert.rejects(q('legacy','pilot_worker_pulse('+lit(c)+',0,0)'),/permission denied/);
 await assert.rejects(q('ace','register_pilot_worker('+lit(c)+',0)'),/permission denied/);
 await assert.rejects(pulse(0,1),/out-of-order/);
 assert.equal(await pulse(0,0),'observed');
 const observed=await health();assert.equal(observed.heartbeat_state,'fresh');
 assert.equal(await pulse(0,0),'already_observed');
 assert.equal((await health()).heartbeat_observed_at,observed.heartbeat_observed_at);
 const normal=await health();assert.equal(normal.recommendation,'no_detected_integrity_alert');assert.equal(normal.clock_state,'observed');assert.equal(normal.automatic_stop,false);assert.equal(normal.worker_heartbeat_verified,false);
 await assert.rejects(q('ace','pilot_health('+lit(c)+',900)'),/permission denied/);
 await assert.rejects(control('pilot_health('+lit(c)+',1)'),/rejected operation/);

 const admit=(role,id)=>q(role,'admit_source('+lit(id)+',0)').then(JSON.parse);
 assert.equal((await admit('ace',matches[0].id)).status,'admitted');
 assert.equal(await register(0),'1');
 await assert.rejects(pulse(0,1),/stale worker pulse/);
 const incident=await health();assert.equal(incident.heartbeat_state,'missing');assert.equal(incident.recommendation,'operator_stop_review');assert.ok(incident.alerts.some(a=>a.kind==='worker_heartbeat_missing'&&a.severity==='critical'));assert.equal(incident.state,'active_isolated');
 assert.equal(await pulse(1,0),'observed');
 assert.equal((await health()).heartbeat_state,'fresh');
 await control('publish_source_clock('+[lit(c),0,due+901,false].join(',')+')');
 const late=await health();assert.equal(late.recommendation,'operator_investigation');assert.ok(late.alerts.some(a=>a.kind==='scheduled_match_overdue'&&a.match_id===matches[0].id));assert.equal(late.state,'active_isolated');
 await control('publish_source_clock('+[lit(c),1,due+901,true].join(',')+')');
 const paused=await health();assert.equal(paused.clock_state,'paused');assert.equal(paused.alerts.some(a=>a.kind==='scheduled_match_overdue'),false);


 // Exercise actual process termination during a database transaction, then let
 // the last committed pulse expire naturally. No timestamp injection.
 assert.equal(process.env.ACE_REVIEW_DB,'1');
 const port=Number(process.env.ACE_REVIEW_DB_PORT||55432);
 assert.ok(Number.isInteger(port)&&port>=1024&&port<=65535);
 const child=spawn('psql',['-X','-qAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',String(port),'-U','ace_cutover_ace','-d','ace_review','-w'],{env:{PATH:process.env.PATH,PGPASSWORD:'ace-disposable-ace',PGCONNECT_TIMEOUT:'5',PGSSLMODE:'disable'},stdio:['pipe','pipe','pipe']});
 let out='',err='';child.stdout.on('data',v=>out+=v);child.stderr.on('data',v=>err+=v);child.stdin.on('error',()=>{});
 const closed=new Promise((resolve,reject)=>{child.once('close',(code,signal)=>resolve({code,signal}));child.once('error',reject);});
 const delay=ms=>new Promise(r=>setTimeout(r,ms));
 const waitFor=async(fn,limit)=>{const end=Date.now()+limit;do{if(await fn())return;await delay(200);}while(Date.now()<end);throw Error('Heartbeat recovery observation timed out');};
 const sql='SELECT ace_cutover_review.pilot_worker_pulse('+lit(c)+',1,';
 child.stdin.write(sql+'1);\nBEGIN;\n'+sql+'2);\n\\echo PULSE_UNCOMMITTED\n');
 let killed;
 try{
  await waitFor(()=>out.includes('PULSE_UNCOMMITTED')||child.exitCode!==null,10000);
  assert.ok(out.includes('PULSE_UNCOMMITTED'),err);
  assert.equal((await health()).heartbeat_sequence,1);
 }finally{child.kill('SIGKILL');killed=await closed;}
 assert.equal(killed.signal,'SIGKILL');
 const committed=await health();assert.equal(committed.heartbeat_sequence,1);
 assert.equal(await pulse(1,1),'already_observed');
 assert.equal((await health()).heartbeat_observed_at,committed.heartbeat_observed_at);
 await waitFor(async()=>(await health()).heartbeat_state==='stale',70000);
 const expired=await health();assert.equal(expired.heartbeat_sequence,1);assert.equal(expired.recommendation,'operator_stop_review');assert.ok(expired.alerts.some(a=>a.kind==='worker_heartbeat_stale'&&a.severity==='critical'));
 assert.equal(expired.state,'active_isolated');assert.equal(expired.automatic_stop,false);
 assert.equal(await pulse(1,1),'already_observed');assert.equal((await health()).heartbeat_state,'stale');
 console.log('PASS real worker connection killed during uncommitted pulse, committed sequence preserved, natural 60-second expiry, replay cannot revive liveness');
 assert.equal((await stop('synthetic operator stop')).status,'admissions_stopped');
 assert.equal((await stop('synthetic operator stop')).status,'already_stopped');
 await assert.rejects(stop('different'),/rejected operation/);
 assert.equal((await admit('ace',matches[0].id)).status,'already_admitted');
 await assert.rejects(admit('legacy',matches[1].id),/new admission frozen/);
 assert.equal((await admit('ace',matches[1].id)).status,'wrong_engine');
 await assert.rejects(activate(),/rejected operation/);
 await assert.rejects(control('configure(true,ARRAY['+lit(c)+'])'),/rejected operation/);
 assert.equal(await register(1),'2');
 await assert.rejects(pulse(1,2),/stale worker pulse/);
 assert.equal(await pulse(2,0),'observed'); // Replacement can report while draining.
 const recovered=await health();assert.equal(recovered.heartbeat_state,'fresh');assert.equal(recovered.heartbeat_generation,2);assert.equal(recovered.state,'admissions_stopped');
 assert.equal(await pulse(2,1),'observed');
 console.log('PASS operator stop after heartbeat expiry, old generation fenced and replacement reports during protected drain');
 const m=await monitor();assert.equal(m.state,'admissions_stopped');assert.equal(m.drain.can_stop_match_worker,false);assert.equal(m.can_retire_pilot,false);assert.equal(m.lifecycle.not_admitted,6);
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.source_admissions a JOIN ace_cutover_review.source_slots s USING(match_id) WHERE s.competition_id='+lit(c)+';'),'1');
 console.log('PASS guarded isolated activation, exact replay, stop serialization, frozen new admissions, sticky existing ownership and retirement blocked');
}
run().catch(e=>{console.error(e);process.exitCode=1});
