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
const {fixture:qualificationFixture}=require('./source-qualification-review.test.cjs'),{freezeQualification}=require('./source-qualification-review.cjs');
async function run(){
 const input=qualificationFixture('qualification-source-ci'),c=input.competition.id,f=freezeQualification(input);
 const imp=x=>control('import_source_qualification('+json(x)+')');
 const bad=clone(f);bad.matches[3].feeder1=bad.matches[2].feeder1;await assert.rejects(imp(bad),/rejected/);
 assert.equal(await imp(f),'imported');assert.equal(await imp(f),'already_imported');
 await control('bind_source_venue('+[lit(c),lit(c+'-venue')].join(',')+')');await control('configure(true,ARRAY['+lit(c)+'])');
 const winners=new Map(),played=[],results=[],transactions=[],conditions=[],support_events=[];
 const rewards=[['qualifying_final_loss',7,100],['qualified_bonus',13,0],['quarterfinal',50,200],['semifinal',100,400],['runner_up',165,500],['winner',250,1000]].map(([stage_code,ranking_points,prize_money_usd])=>({stage_code,ranking_points,prize_money_usd}));
 const admit=(id,rev=0)=>q('ace','admit_source('+lit(id)+','+rev+')').then(JSON.parse);
 const observe=(id,p1,p2)=>control('observe_source('+[lit(id),0,json({player1_id:p1,player2_id:p2,status:'scheduled',simulation:'none',started:false,winner_id:null})].join(',')+')');
 const sync=async id=>{await control('sync_source_event('+lit(id)+',2)');await control('sync_source_event('+lit(id)+',3)');};
 assert.equal((await admit(f.matches[4].match_id)).status,'qualification_sync_pending');
 let cr=-1;
 for(const [phase,round] of [['qualification',1],['main_draw',1],['main_draw',2],['main_draw',3]]){
  const day=phase==='qualification'?2:8+round;
  assert.equal(await control('publish_source_clock('+[lit(c),cr,day*86400+36000,false].join(',')+')'),String(++cr));
  for(const s of f.matches.filter(x=>x.draw_type===phase&&x.round_number===round)){
   const id=s.match_id,p1=s.feeder1?winners.get(s.feeder1):s.player1_id,p2=s.feeder2?winners.get(s.feeder2):s.player2_id,rev=s.feeder1||s.feeder2?1:0;
   if(rev){if(phase==='main_draw'&&round===1&&s.feeder1){await observe(id,input.players[1].id,p2);assert.equal((await admit(id,1)).status,'feeder_receipts_pending_or_mismatch');await control('observe_source('+[lit(id),1,json({player1_id:p1,player2_id:p2,status:'scheduled',simulation:'none',started:false,winner_id:null})].join(',')+')');}else await observe(id,p1,p2);}
   const sr=phase==='main_draw'&&round===1&&s.feeder1?2:rev;
   assert.equal((await admit(id,sr)).status,'admitted');
   await control('freeze_source_readiness('+[lit(id),-1,1,sr,cr,json({player1_id:p1,player2_id:p2,complete_health_export:true,health1:[],health2:[],travel_ready:true,resources_ready:true})].join(',')+')');
   assert.equal(await q('ace','start_source('+lit(id)+',1,0,'+cr+')'),'started');
   const m={match_id:id,competition_id:c,player1_id:p1,player2_id:p2,winner_id:p1,status:'completed',score:'6-0 6-0',actual_duration_minutes:68,sets:[{match_id:id,set_number:1,player1_games:6,player2_games:0},{match_id:id,set_number:2,player1_games:6,player2_games:0}],stats:[{match_id:id,player_id:p1,total_points_won:48},{match_id:id,player_id:p2,total_points_won:10}]};
   await q('ace','finish_match('+[lit(id),2,lit(p1),json(m)].join(',')+')');played.push(m);winners.set(id,p1);
   if(phase==='qualification'&&played.length===2)assert.equal((await admit(f.matches[4].match_id)).status,'qualification_sync_pending');
   await sync(id);
  }
 }
 const contract={matches:f.matches.map(x=>({match_id:x.match_id,phase:x.draw_type,round_number:x.round_number,round_label:x.draw_type==='qualification'?'Final Qualifying':['Quarterfinal','Semifinal','Final'][x.round_number-1]})),players:input.players.map(p=>({player_id:p.id,player_type:'ai'})),rewards,ranking_publish_absolute_day:16};
 const audit=JSON.parse(await control('audit_special_closure('+lit(c)+','+json(contract)+')'));assert.equal(audit.status,'normal_legacy_candidates');assert.equal(audit.legacy_result_candidates.length,10);assert.equal(audit.legacy_result_candidates.filter(x=>x.result_stage_code==='qualifying_final_loss').length,2);assert.equal(audit.legacy_result_candidates.filter(x=>x.qualifying_bonus_points===13).length,2);assert.equal(audit.champion_candidate_id,input.players[0].id);
 results.push(...audit.legacy_result_candidates.map(x=>({...x,result_code:x.result_stage_code==='winner'?'champion':x.result_stage_code==='qualifying_final_loss'?'qualifying':x.result_stage_code})));
 const payload={schema:'ace-settlement-review-v1',review_only:true,production_ready:false,participant_order_verified:true,competition_id:c,matches:played,results,transactions,conditions,support_events};
 assert.equal(await settle(payload),'finalized_review');assert.equal(await settle(payload),'already_finalized');
 assert.equal(await db.sql('SELECT count(*) FROM ace_review.finalized_matches WHERE competition_id='+lit(c)+';'),'9');
 await control("configure(false,ARRAY[]::text[])");console.log('PASS imported single-round qualification, synchronized winners, exact main slots, qualified bonus, final loss and full review settlement');
}
run().catch(e=>{console.error(e);process.exitCode=1});
