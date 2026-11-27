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
 const c='pilot-preflight-ci',players=Array.from({length:8},(_,i)=>({id:c+'-p'+i})),matches=[];
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
 await control('configure(true,ARRAY['+lit(c)+'])');
 assert.ok((await report()).blockers.includes('routing_enabled'));
 assert.equal(JSON.parse(await q('ace','admit_source('+lit(matches[0].id)+',0)')).status,'admitted');
 await control("configure(false,ARRAY[]::text[])");
 await control('publish_source_clock('+[lit(c),0,due,false].join(',')+')');
 const bad=await report();assert.ok(bad.blockers.includes('existing_match_or_admission'));assert.ok(bad.blockers.includes('first_match_due_or_past'));assert.equal(bad.status,'blocked_review');
 console.log('PASS isolated pilot preflight, fresh eight-player field, missing records, role separation, disabled routing, existing admission and overdue clock checks');
}
run().catch(e=>{console.error(e);process.exitCode=1});
