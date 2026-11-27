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
 const id='cutover-guest-ci';await register(id);
 const regular={is_guest:false,is_anonymous:false,expires_at:null,converted_at:null};
 const expired={is_guest:true,is_anonymous:true,expires_at:'2026-11-27T08:00:00Z',converted_at:null};
 const converted={...expired,is_anonymous:false,converted_at:'2026-11-27T07:59:59Z'};
 const valid={...expired,expires_at:'2026-11-27T08:00:01Z'};
 const observed='2026-11-27T08:00:00Z';
 const m=(key,p1='p1',p2='p2')=>({match_id:key,player1_id:p1,player2_id:p2});
 const freezeGuest=(key,a,b,role='external')=>q(role,'freeze_guest('+[lit(key),lit('guest-event'),lit(observed)+'::timestamptz',json(a),json(b)].join(',')+')');
 const resolve=async(key,role='ace',rev=1)=>JSON.parse(await q(role,'finish_guest('+lit(key)+','+rev+')'));
 await seed(id,m('guest-one'));await claim('ace','guest-one');
 assert.equal(await freezeGuest('guest-one',converted,regular),'no_expired_guest');
 assert.equal(await freezeGuest('guest-one',valid,regular),'no_expired_guest');
 assert.equal(await freezeGuest('guest-one',expired,regular),'frozen');
 assert.equal(await freezeGuest('guest-one',expired,regular),'already_frozen');
 await assert.rejects(freezeGuest('guest-one',regular,expired),/conflicting guest evidence/);
 await assert.rejects(freezeGuest('guest-one',expired,regular,'ace'),/permission denied/);
 assert.equal(await start('guest-one'),'handoff_pending');
 await assert.rejects(resolve('guest-one','legacy'),/permission denied/);
 await assert.rejects(resolve('guest-one','ace',0),/invalid guest completion/);
 await assert.rejects(q('ace',"resolve_handoff('guest-one','guest-event',1,'walkover','p2')"),/dedicated adapter/);
 const race=await Promise.all([resolve('guest-one'),resolve('guest-one')]);
 assert.deepEqual(race.map(x=>x.status).sort(),['already_resolved','resolved']);
 assert.deepEqual(race[0].receipt,race[1].receipt);
 assert.equal(race[0].receipt.winner_id,'p2');assert.equal(race[0].receipt.status,'walkover');
 assert.equal(race[0].receipt.started_at,null);assert.deepEqual(race[0].receipt.stats,[]);
 assert.equal(await db.sql("SELECT count(*) FROM ace_cutover_review.effects WHERE match_id='guest-one';"),'0');
 await seed(id,m('guest-next','p2','p3'),'guest-one');await claim('ace','guest-next');assert.equal(await start('guest-next'),'started');
 await seed(id,m('guest-both'));await claim('ace','guest-both');await freezeGuest('guest-both',expired,expired);
 const cancel=await resolve('guest-both');assert.equal(cancel.receipt.status,'cancelled');assert.equal(cancel.receipt.winner_id,null);
 assert.equal(await db.sql("SELECT count(*) FROM ace_cutover_review.effects WHERE match_id='guest-both';"),'0');
 await seed(id,m('guest-no-feeder','p2','p3'),'guest-both');await claim('ace','guest-no-feeder');
 await assert.rejects(start('guest-no-feeder'),/feeder not ready/);
 await seed(id,m('guest-live'));await claim('ace','guest-live');await start('guest-live');
 await assert.rejects(freezeGuest('guest-live',expired,regular),/unstarted match required/);
 await assert.rejects(q('ace','finish_match('+[lit('guest-live'),2,lit('p2'),json(race[0].receipt)].join(',')+')'),/guest resolution is not a played effect/);
 await seed(id,m('guest-conflict'));await claim('ace','guest-conflict');
 await freezeGuest('guest-conflict',expired,regular);await q('external',"request_handoff('guest-conflict','travel','travel_no_show')");
 await assert.rejects(resolve('guest-conflict'),/conflicting external events/);
 assert.equal(await db.sql("SELECT count(*) FROM ace_cutover_review.handoffs WHERE match_id='guest-conflict' AND resolution IS NULL;"),'2');
 // A guest in a not-yet-confirmed round cannot fabricate advancement.
 await seed(id,m('guest-early','p2','p3'),'guest-both');await claim('ace','guest-early');await freezeGuest('guest-early',regular,expired);
 await assert.rejects(resolve('guest-early'),/feeder not ready/);
 assert.equal(await db.sql("SELECT count(*) FROM ace_cutover_review.guest_evidence WHERE match_id='guest-early' AND receipt IS NULL;"),'1');
 assert.equal(await db.sql("SELECT count(*) FROM ace_review.finalized_prizes WHERE competition_id='cutover-guest-ci';"),'0');
 await control("configure(false,ARRAY[]::text[])");
 console.log('PASS guest expiry boundary, conversion evidence, single walkover, both-expired cancellation, feeder protection, replay, role separation, live and conflicting event rejection');
}
run().catch(e=>{console.error(e);process.exitCode=1});
