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
 const c='source-exceptions-ci',players=Array.from({length:8},(_,i)=>({id:c+'-p'+i})),slots=[];
 for(let round=1;round<=3;round++)for(let number=1;number<=8/2**round;number++)slots.push({id:c+'-'+round+'-'+number,competition_id:c,draw_type:'main_draw',round_number:round,match_number:number,status:'scheduled',started_at:null,completed_at:null,winner_id:null,player1_id:round===1?players[number*2-2].id:null,player2_id:round===1?players[number*2-1].id:null,scheduled_season_week:1,scheduled_day:round,scheduled_start_minute:600,court_number:number});
 const input={schema:'ace-source-admission-v1',complete_export:true,competition:{id:c,scope:'singles',field_locked:true,qualification_required:false,status:'published',season_number:1,draw_size:8},players,matches:slots,results:[],simulations:[]};
 assert.throws(()=>freezeSource({...input,competition:{...input.competition,qualification_required:true}}),/singles/);
 await control('import_source_contract('+json(freezeSource(input))+')');await control('bind_source_venue('+[lit(c),lit(c+'-venue')].join(',')+')');await control('enable_source_career_review('+lit(c)+",'hard')");await control('configure(true,ARRAY['+lit(c)+'])');
 await assert.rejects(control('cancel_unstarted('+[lit(c),7,8,lit('minimum_field_not_met')].join(',')+')'),/rejected/);
 const profile={fatigue:30,sharpness:60,morale:60,confidence:60,focus:60,fitness:65,stamina:65,recovery:65,movement:65};
 const injury=[{status:'active',tournamentReturnDay:6,fullRecoveryDay:8}],due=2*86400+36000;
 for(let i=0;i<4;i++){const p=players[i].id;await control('observe_source_career('+[lit(p),-1,json({profile,staff:{},injuries:i%2?injury:[],inventory:[{id:p+'-r',type:'racket',condition:80,wear_per_match:2}],loadout:{racket:p+'-r',shoes:null,apparel:null}})].join(',')+')');}
 await control('publish_source_clock('+[lit(c),-1,due-1,false].join(',')+')');
 const ids=[slots[0].id,slots[1].id];
 const ready=(id,expected,cr,i)=>control('freeze_source_readiness('+[lit(id),expected,1,0,cr,json({player1_id:players[2*i].id,player2_id:players[2*i+1].id,complete_health_export:true,health1:[],health2:injury,travel_ready:true,resources_ready:true})].join(',')+')');
 const medical=(id,rr,cr,role='ace')=>q(role,'finish_source_medical('+[lit(id),1,rr,cr].join(',')+')').then(JSON.parse);
 for(let i=0;i<2;i++){assert.equal(JSON.parse(await q('ace','admit_source('+lit(ids[i])+',0)')).status,'admitted');await ready(ids[i],-1,0,i);}
 assert.equal((await medical(ids[0],0,0)).status,'not_due');
 await control('publish_source_clock('+[lit(c),0,due,false].join(',')+')');
 await assert.rejects(medical(ids[0],0,0),/stale medical readiness/);
 for(let i=0;i<2;i++)await ready(ids[i],0,1,i);
 await assert.rejects(medical(ids[0],1,1,'legacy'),/permission denied/);
 assert.equal(await q('ace','start_source('+lit(ids[0])+',1,1,1)'),'medical_review_required');
 const race=await Promise.all([medical(ids[0],1,1),medical(ids[0],1,1)]);assert.deepEqual(race.map(x=>x.status).sort(),['already_completed','completed']);assert.deepEqual(race[0].receipt,race[1].receipt);
 assert.equal(race[0].receipt.winner_id,players[0].id);assert.equal(race[0].receipt.actual_duration_minutes,null);
 assert.equal((await medical(ids[1],1,1)).status,'completed');
 for(const id of ids){const ack=()=>control('ack_source_no_play('+lit(id)+',2)').then(JSON.parse);await assert.rejects(ack(),/rejected/);await control('sync_source_event('+lit(id)+',2)');const a=await ack();assert.equal(a.status,'no_play_no_effects');assert.deepEqual(await ack(),a);}
 const next=slots.find(x=>x.round_number===2&&x.match_number===1).id;
 await control('observe_source('+[lit(next),0,json({player1_id:players[0].id,player2_id:players[2].id,status:'scheduled',simulation:'none',started:false,winner_id:null})].join(',')+')');
 assert.equal(JSON.parse(await q('ace','admit_source('+lit(next)+',1)')).status,'admitted');
 for(const p of players.slice(0,4)){const x=JSON.parse(await db.sql('SELECT to_jsonb(t) FROM ace_cutover_review.source_career_players t WHERE player_id='+lit(p.id)+';'));assert.equal(x.revision,0);assert.equal(x.state.profile.fatigue,30);assert.equal(x.state.inventory[0].condition,80);}
 for(const table of ['source_starts','source_career_effects','source_rest_history','active_source_resources'])assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.'+table+' WHERE match_id IN ('+ids.map(lit).join(',')+');'),'0');
 await control("configure(false,ARRAY[]::text[])");
 console.log('PASS imported medical readiness, zero-play outcomes, exact retry, synchronized career acknowledgment, feeder advancement and locked-field cancellation rejection');
}
run().catch(e=>{console.error(e);process.exitCode=1});
