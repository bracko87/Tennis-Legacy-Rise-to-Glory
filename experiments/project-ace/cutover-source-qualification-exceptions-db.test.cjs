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
async function run(missing){
 const input=qualificationFixture('qual-exceptions-'+(missing?'missing':'survivor')+'-ci',2),c=input.competition.id,f=freezeQualification(input);
 await control('import_source_qualification('+json(f)+')');await control('configure(true,ARRAY['+lit(c)+'])');
 const k=(phase,r,n)=>c+'-'+phase+'-'+r+'-'+n,Q=(r,n)=>k('qualification',r,n),M=(r,n)=>k('main_draw',r,n);
 const slot=id=>f.matches.find(x=>x.match_id===id);
 const admit=(id,rev=0)=>q('ace','admit_source('+lit(id)+','+rev+')').then(JSON.parse);
 const sync=(id,rev=2)=>control('sync_source_event('+lit(id)+','+rev+')').then(JSON.parse);
 const observe=(id,p1,p2,rev=0)=>control('observe_source('+[lit(id),rev,json({player1_id:p1,player2_id:p2,status:'scheduled',simulation:'none',started:false,winner_id:null})].join(',')+')');
 const reg={is_guest:false,is_anonymous:false,expires_at:null,converted_at:null},expired={is_guest:true,is_anonymous:true,expires_at:'2026-11-27T08:00:00Z',converted_at:null};
 const at=lit('2026-11-27T09:00:00Z')+'::timestamptz';
 const guest=async(id,both)=>{assert.equal(await q('external','freeze_guest('+[lit(id),lit('expiry'),at,json(both?expired:reg),json(expired)].join(',')+')'),'frozen');return JSON.parse(await q('ace','finish_guest('+lit(id)+',1)')).receipt;};
 const injury=[{status:'active',tournamentReturnDay:6,fullRecoveryDay:8}];
 const medical=async(id,sourceRev,cr,p1,p2)=>{
  await control('freeze_source_readiness('+[lit(id),-1,1,sourceRev,cr,json({player1_id:p1,player2_id:p2,complete_health_export:true,health1:[],health2:injury,travel_ready:true,resources_ready:true})].join(',')+')');
  assert.equal(await q('ace','start_source('+lit(id)+',1,0,'+cr+')'),'medical_review_required');
  const result=JSON.parse(await q('ace','finish_source_medical('+lit(id)+',1,0,'+cr+')'));assert.equal(result.status,'completed');assert.equal(result.receipt.winner_id,p1);return result.receipt;
 };
 const voidMatch=(id,rev)=>q('ace','resolve_source_void('+lit(id)+','+rev+')').then(JSON.parse);
 const wins=new Map();
 await control('publish_source_clock('+[lit(c),-1,2*86400+36000,false].join(',')+')');
 for(let i=1;i<=4;i++){
  const id=Q(1,i),s=slot(id);assert.equal((await admit(id)).status,'admitted');
  const receipt=i===3?await medical(id,0,0,s.player1_id,s.player2_id):await guest(id,i===1||(i===2&&missing));
  wins.set(id,receipt.winner_id);if(i!==4)await sync(id);
 }
 const q2a=Q(2,1),q2b=Q(2,2);
 const left=wins.get(Q(1,1)),right=wins.get(Q(1,2)),left2=wins.get(Q(1,3)),right2=wins.get(Q(1,4));
 const revA=Number(await observe(q2a,left,right));const a=await voidMatch(q2a,revA);
 assert.equal(a.status,'resolved');assert.equal(a.receipt.status,missing?'cancelled':'bye');assert.equal(a.receipt.winner_id,right);
 await sync(q2a);wins.set(q2a,right);
 assert.equal(await observe(q2b,left2,right2),'1');
 assert.equal((await admit(q2b,1)).status,'qualification_feeder_sync_pending');await sync(Q(1,4));
 assert.equal((await admit(q2b,1)).status,'admitted');
 await control('publish_source_clock('+[lit(c),0,3*86400+36000,false].join(',')+')');
 const b=await medical(q2b,1,1,left2,right2);wins.set(q2b,b.winner_id);
 assert.equal((await admit(M(1,3))).status,'qualification_sync_pending');await sync(q2b);
 if(missing){
  assert.equal((await admit(M(1,3))).status,'qualifier_replacement_review_required');
  const first=slot(M(1,1));await observe(first.match_id,input.players[1].id,first.player2_id);
  assert.equal((await admit(first.match_id,1)).status,'qualifier_replacement_review_required');
  assert.equal(await db.sql("SELECT count(*) FROM ace_cutover_review.source_admissions a JOIN ace_cutover_review.source_slots s USING(match_id) WHERE s.competition_id="+lit(c)+" AND s.slot->>'draw_type'='main_draw';"),'0');
 }else{
  for(let r=1;r<=3;r++)for(let n=1;n<=8/2**r;n++){
   const id=M(r,n),s=slot(id),p1=s.feeder1?wins.get(s.feeder1):s.player1_id,p2=s.feeder2?wins.get(s.feeder2):s.player2_id,rev=s.feeder1||s.feeder2?1:0;
   if(rev)assert.equal(await observe(id,p1,p2),'1');
   assert.equal((await admit(id,rev)).status,'admitted');
   const out=await guest(id,false);assert.equal(out.winner_id,p1);wins.set(id,out.winner_id);await sync(id);
  }
  const contract={matches:f.matches.map(x=>({match_id:x.match_id,phase:x.draw_type,round_number:x.round_number,round_label:x.draw_type==='qualification'?(x.round_number===2?'Final Qualifying':'Qualifying Round 1'):['Quarterfinal','Semifinal','Final'][x.round_number-1]})),players:input.players.map(p=>({player_id:p.id,player_type:'ai'})),rewards:[{stage_code:'qualifying_round_1_loss',ranking_points:1,prize_money_usd:20},{stage_code:'qualifying_final_loss',ranking_points:7,prize_money_usd:100},{stage_code:'qualified_bonus',ranking_points:13,prize_money_usd:0}],ranking_publish_absolute_day:16};
  const audit=JSON.parse(await control('audit_special_closure('+lit(c)+','+json(contract)+')'));assert.equal(audit.status,'blocked_special_results');assert.equal(audit.champion_candidate_id,wins.get(M(3,1)));assert.equal(audit.legacy_result_candidates.length,2);
  assert.equal(await db.sql('SELECT count(*) FROM ace_review.finalized_prizes WHERE competition_id='+lit(c)+';'),'0');
 }
 for(const t of ['source_starts','source_career_effects','active_source_resources','source_rest_history'])assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.'+t+' x JOIN ace_cutover_review.source_slots s USING(match_id) WHERE s.competition_id='+lit(c)+';'),'0');
 await control("configure(false,ARRAY[]::text[])");
 console.log('PASS qualifying exceptions '+(missing?'missing qualifier replacement hold':'synchronized bye and medical advancement, exceptional reward hold'));
}
(async()=>{await run(false);await run(true);})().catch(e=>{console.error(e);process.exitCode=1});
