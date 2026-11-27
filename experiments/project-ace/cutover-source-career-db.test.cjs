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
const {propose}=require('./source-career-proposal.cjs'),{duration}=require('./schedule-gate.cjs');
async function run(){
 const due=2*86400+600*60;
 const profile={fatigue:30,sharpness:60,morale:60,confidence:60,focus:60,fitness:65,stamina:65,recovery:65,movement:65};
 const state=id=>({profile:{...profile},staff:{matchFatigueReduction:.1},injuries:[],inventory:[{id:id+'-r',type:'racket',condition:21,wear_per_match:2}],loadout:{racket:id+'-r',shoes:null,apparel:null}});
 const observe=(id,rev,s)=>control('observe_source_career('+[lit(id),rev,json(s)].join(',')+')');
 async function setup(c){
  const players=Array.from({length:8},(_,i)=>({id:c+'-p'+i})),matches=[];
  for(let round=1;round<=3;round++)for(let number=1;number<=8/2**round;number++)matches.push({id:c+'-'+round+'-'+number,competition_id:c,draw_type:'main_draw',round_number:round,match_number:number,status:'scheduled',started_at:null,completed_at:null,winner_id:null,player1_id:round===1?players[number*2-2].id:null,player2_id:round===1?players[number*2-1].id:null,scheduled_season_week:1,scheduled_day:round,scheduled_start_minute:600,court_number:number});
  const source=freezeSource({schema:'ace-source-admission-v1',complete_export:true,competition:{id:c,scope:'singles',field_locked:true,qualification_required:false,status:'published',season_number:1,draw_size:8},players,matches,results:[],simulations:[]});
  await control('import_source_contract('+json(source)+')');
  await control('bind_source_venue('+[lit(c),lit(c+'-venue')].join(',')+')');
  await control('enable_source_career_review('+lit(c)+",'hard')");
  await control('configure(true,ARRAY['+lit(c)+'])');
  const id=matches[0].id,p1=players[0].id,p2=players[1].id;
  await q('ace','admit_source('+lit(id)+',0)');
  await control('publish_source_clock('+[lit(c),-1,due,false].join(',')+')');
  await control('freeze_source_readiness('+[lit(id),-1,1,0,0,json({player1_id:p1,player2_id:p2,complete_health_export:true,health1:[],health2:[],travel_ready:true,resources_ready:true})].join(',')+')');
  const begin=()=>q('ace','start_source('+lit(id)+',1,0,0)');
  assert.equal(await observe(p1,-1,state(p1)),'0');await assert.rejects(begin(),/missing player career state/);
  assert.equal(await observe(p2,-1,state(p2)),'0');assert.equal(await begin(),'started');
  const snapshot=JSON.parse(await db.sql('SELECT snapshot FROM ace_cutover_review.source_career_starts WHERE match_id='+lit(id)+';'));
  const match={match_id:id,competition_id:c,player1_id:p1,player2_id:p2,winner_id:p1,owner:'ace',status:'completed',revision:3};
  const receipt={...match,sets:[1,2].map(set_number=>({match_id:id,set_number,player1_games:6,player2_games:0})),stats:[{match_id:id,player_id:p1,total_points_won:48},{match_id:id,player_id:p2,total_points_won:10}],actual_duration_minutes:duration(12,58)};
  await q('ace','finish_match('+[lit(id),2,lit(p1),json(receipt)].join(',')+')');
  const proposal=propose({match,receipt,snapshot});
  const apply=(p=proposal,s=snapshot,rec=receipt)=>control('apply_source_career('+[lit(id),json(s),json(rec),json(p)].join(',')+')').then(JSON.parse);
  const sync=async()=>{await control('sync_source_event('+lit(id)+',2)');await control('sync_source_event('+lit(id)+',3)');};
  const read=async p=>JSON.parse(await db.sql('SELECT to_jsonb(t) FROM ace_cutover_review.source_career_players t WHERE player_id='+lit(p)+';'));
  return {id,p1,p2,proposal,snapshot,receipt,apply,sync,read};
 }
 const a=await setup('career-atomic-ci');
 await assert.rejects(a.apply(),/rejected/);await a.sync();
 const bad=clone(a.proposal);bad.players[1].equipment_after[0].condition=99;
 await assert.rejects(a.apply(bad),/rejected/);assert.equal((await a.read(a.p1)).revision,0);assert.equal((await a.read(a.p2)).revision,0);
 await assert.rejects(a.apply(a.proposal,{...a.snapshot,surface:'grass'}),/rejected/);
 await assert.rejects(q('ace','apply_source_career('+[lit(a.id),json(a.snapshot),json(a.receipt),json(a.proposal)].join(',')+')'),/permission denied/);
 const race=await Promise.all([a.apply(),a.apply()]);assert.deepEqual(race[0],race[1]);assert.equal(race[0].status,'applied_review');
 for(const p of [a.p1,a.p2]){const x=await a.read(p);assert.equal(x.revision,1);assert.equal(x.state.inventory[0].condition,19);assert.ok(x.state.profile.fatigue>30);}
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.source_career_effects WHERE match_id='+lit(a.id)+';'),'2');
 const changed=clone(a.proposal);changed.players[0].fatigue_gain++;await assert.rejects(a.apply(changed),/rejected/);
 const b=await setup('career-stale-ci');await b.sync();
 const newer=state(b.p2);newer.profile.fatigue=44;assert.equal(await observe(b.p2,0,newer),'1');
 await assert.rejects(b.apply(),/rejected/);assert.equal((await b.read(b.p1)).revision,0);assert.equal((await b.read(b.p2)).state.profile.fatigue,44);
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.source_career_effects WHERE match_id='+lit(b.id)+';'),'0');
 await control("configure(false,ARRAY[]::text[])");
 console.log('PASS atomic two-player career changes, exact replay, equipment rollback, stale revision rejection, synchronized receipt and unauthorized apply');
}
run().catch(e=>{console.error(e);process.exitCode=1});
