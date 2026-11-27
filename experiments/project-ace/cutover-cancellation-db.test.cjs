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
async function run(){
 const cancelled='cancel-unstarted';await register(cancelled);
 const m=(key,p1='p1',p2='p2')=>({match_id:key,player1_id:p1,player2_id:p2});
 await seed(cancelled,m('cancel-fixture'));
 const cancel=(id,count=7)=>control('cancel_unstarted('+lit(id)+','+count+",8,'minimum_field_not_met')");
 await assert.rejects(cancel(cancelled,8),/rejected/);
 await assert.rejects(q('ace',"cancel_unstarted('cancel-unstarted',7,8,'minimum_field_not_met')"),/permission denied/);
 assert.deepEqual((await Promise.all([cancel(cancelled),cancel(cancelled)])).sort(),['already_cancelled','cancelled']);
 await assert.rejects(cancel(cancelled,6),/rejected/);
 await assert.rejects(claim('ace','cancel-fixture'),/competition cancelled/);
 await assert.rejects(seed(cancelled,m('cancel-new')),/rejected/);
 await assert.rejects(q('external',"request_handoff('cancel-fixture','x','admin_repair')"),/competition cancelled/);
 assert.equal(await db.sql("SELECT count(*) FROM ace_review.finalized_prizes WHERE competition_id='cancel-unstarted';"),'0');
 const {s,officialMatches}=fixture('cancel-settlement'),x=project(s,{officialMatches});await register(x.competition_id);await cancel(x.competition_id);
 await assert.rejects(settle(x),/competition cancelled/);
 const id='void-bracket-ci';await register(id);
 const regular={is_guest:false,is_anonymous:false,expires_at:null,converted_at:null};
 const expired={is_guest:true,is_anonymous:true,expires_at:'2026-11-27T08:00:00Z',converted_at:null};
 const frozen=key=>q('external','freeze_guest('+[lit(key),lit('guest-event'),lit('2026-11-27T08:00:00Z')+'::timestamptz',json(expired),json(expired)].join(',')+')');
 const resolve=key=>q('ace','finish_guest('+lit(key)+',1)');
 const continuation=async(key,role='ace')=>JSON.parse(await q(role,'continue_void_bracket('+lit(key)+',1)'));
 for(const key of ['void-left','void-right','void-third']){await seed(id,m(key));await claim('ace',key);await frozen(key);await resolve(key);}
 await assert.rejects(cancel(id),/rejected/);
 await seed(id,m('normal-feeder','p3','p4'));await claim('ace','normal-feeder');
 await seed(id,m('bye-next','p1','p3'),'void-left','normal-feeder');await claim('ace','bye-next');
 await assert.rejects(continuation('bye-next'),/feeder not terminal/);
 await start('normal-feeder');await q('ace',"finish_match('normal-feeder',2,'p3',"+json({score:'6-0 6-0'})+")");
 await assert.rejects(start('bye-next'),/feeder not ready/);
 await assert.rejects(continuation('bye-next','legacy'),/permission denied/);
 const race=await Promise.all([continuation('bye-next'),continuation('bye-next')]);
 assert.deepEqual(race.map(x=>x.status).sort(),['already_resolved','resolved']);
 assert.equal(race[0].receipt.status,'bye');assert.equal(race[0].receipt.player1_id,null);assert.equal(race[0].receipt.winner_id,'p3');
 await seed(id,m('void-next'),'void-right','void-third');await claim('ace','void-next');
 const both=await continuation('void-next');assert.equal(both.receipt.status,'cancelled');assert.equal(both.receipt.winner_id,null);
 await seed(id,m('recursive','p3','p1'),'bye-next','void-next');await claim('ace','recursive');
 assert.equal((await continuation('recursive')).receipt.winner_id,'p3');
 await seed(id,m('mismatch','p4','p1'),'bye-next','void-next');await claim('ace','mismatch');
 await assert.rejects(continuation('mismatch'),/surviving feeder mismatch/);
 assert.equal(await db.sql("SELECT count(*) FROM ace_cutover_review.effects WHERE match_id IN ('bye-next','void-next','recursive');"),'0');
 assert.equal(await db.sql("SELECT count(*) FROM ace_review.finalized_prizes WHERE competition_id='void-bracket-ci';"),'0');
 await control("configure(false,ARRAY[]::text[])");
 console.log('PASS minimum-field cancellation tombstone, claim/seed/settlement blocks, active rejection, confirmed bye and double void propagation, idempotency and no played effects');
}
run().catch(e=>{console.error(e);process.exitCode=1});
