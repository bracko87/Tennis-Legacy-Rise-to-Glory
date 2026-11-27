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
 const c='source-void-ci',players=Array.from({length:8},(_,i)=>({id:c+'-p'+i})),slots=[];
 for(let round=1;round<=3;round++)for(let number=1;number<=8/2**round;number++)slots.push({id:c+'-'+round+'-'+number,competition_id:c,draw_type:'main_draw',round_number:round,match_number:number,status:'scheduled',started_at:null,completed_at:null,winner_id:null,player1_id:round===1?players[number*2-2].id:null,player2_id:round===1?players[number*2-1].id:null,scheduled_season_week:1,scheduled_day:round,scheduled_start_minute:600,court_number:number});
 const frozen=freezeSource({schema:'ace-source-admission-v1',complete_export:true,competition:{id:c,scope:'singles',field_locked:true,qualification_required:false,status:'published',season_number:1,draw_size:8},players,matches:slots,results:[],simulations:[]});
 await control('import_source_contract('+json(frozen)+')');await control('configure(true,ARRAY['+lit(c)+'])');
 const k=(r,n)=>c+'-'+r+'-'+n;
 const resolve=(id,rev=0,role='ace')=>q(role,'resolve_source_void('+lit(id)+','+rev+')').then(JSON.parse);
 const sync=id=>control('sync_source_event('+lit(id)+',2)').then(JSON.parse);
 const observe=(id,p1,p2)=>control('observe_source('+[lit(id),0,json({player1_id:p1,player2_id:p2,status:'scheduled',simulation:'none',started:false,winner_id:null})].join(',')+')');
 const reg={is_guest:false,is_anonymous:false,expires_at:null,converted_at:null},expired={is_guest:true,is_anonymous:true,expires_at:'2026-11-27T08:00:00Z',converted_at:null};
 const at=lit('2026-11-27T09:00:00Z')+'::timestamptz';
 assert.equal((await resolve(k(2,1))).status,'feeder_sync_pending');
 await assert.rejects(resolve(k(2,1),0,'legacy'),/permission denied/);
 await assert.rejects(resolve(k(1,1)),/two source feeders required/);
 for(let i=1;i<=4;i++){
  const id=k(1,i);assert.equal(JSON.parse(await q('ace','admit_source('+lit(id)+',0)')).status,'admitted');
  assert.equal(await q('external','freeze_guest('+[lit(id),lit('expire-'+i),at,json(i===4?reg:expired),json(expired)].join(',')+')'),'frozen');
  const out=JSON.parse(await q('ace','finish_guest('+lit(id)+',1)'));assert.equal(out.status,'resolved');assert.equal(out.receipt.status,i===4?'walkover':'cancelled');
  if(i!==2)await sync(id);
 }
 assert.equal((await resolve(k(2,1))).status,'feeder_sync_pending');await sync(k(1,2));
 const race=await Promise.all([resolve(k(2,1)),resolve(k(2,1))]);assert.deepEqual(race.map(x=>x.status).sort(),['already_resolved','resolved']);assert.equal(race[0].receipt.winner_id,null);
 assert.equal(race[0].receipt.player1_id,null);assert.equal(race[0].receipt.player2_id,null);await sync(k(2,1));
 const survivor=players[6].id;
 await assert.rejects(resolve(k(2,2)),/source void slot mismatch/);
 assert.equal(await observe(k(2,2),null,survivor),'1');assert.equal((await resolve(k(2,2),1)).receipt.winner_id,survivor);await sync(k(2,2));
 assert.equal(await observe(k(3,1),null,survivor),'1');
 await control("configure(false,ARRAY[]::text[])");assert.equal((await resolve(k(3,1),1)).status,'routing_disabled');
 await control('configure(true,ARRAY['+lit(c)+'])');const final=await resolve(k(3,1),1);assert.equal(final.receipt.status,'bye');assert.equal(final.receipt.winner_id,survivor);await sync(k(3,1));
 await assert.rejects(resolve(k(3,1),0),/conflicting void replay/);
 const audit=JSON.parse(await control('audit_special_closure('+lit(c)+','+json({matches:frozen.matches.map(x=>({match_id:x.match_id,phase:'main_draw',round_label:['Quarterfinal','Semifinal','Final'][x.round_number-1],round_number:x.round_number})),players:players.map(p=>({player_id:p.id,player_type:'human'})),rewards:[],ranking_publish_absolute_day:9})+')'));
 assert.equal(audit.status,'blocked_special_results');assert.equal(audit.champion_candidate_id,survivor);assert.equal(audit.skipped_matches.length,7);assert.deepEqual(audit.legacy_result_candidates,[]);
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.matches WHERE competition='+lit(c)+' AND (player1 IS NULL OR player2 IS NULL);'),'3');
 for(const t of ['effects','source_starts','source_career_effects','active_source_resources','source_rest_history'])assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.'+t+' x JOIN ace_cutover_review.source_slots s USING(match_id) WHERE s.competition_id='+lit(c)+';'),'0');
 assert.equal(await db.sql('SELECT count(*) FROM ace_review.finalized_prizes WHERE competition_id='+lit(c)+';'),'0');
 await control("configure(false,ARRAY[]::text[])");
 console.log('PASS imported guest withdrawal, synchronized empty feeders, null slot bye/cancelled progression, disabled routing, immutable replay and blocked exceptional rewards');
}
run().catch(e=>{console.error(e);process.exitCode=1});
