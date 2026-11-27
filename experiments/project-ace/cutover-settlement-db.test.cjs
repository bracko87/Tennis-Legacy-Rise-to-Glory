'use strict';
const assert=require('node:assert/strict'),{spawn}=require('node:child_process'),{connection}=require('./postgres-store.cjs'),{reordered}=require('./official-review.test.cjs');
const db=connection(),clone=x=>JSON.parse(JSON.stringify(x));
const lit=x=>x===null?'NULL':"convert_from(decode('"+Buffer.from(String(x)).toString('base64')+"','base64'),'UTF8')";
const json=x=>lit(JSON.stringify(x))+'::jsonb';
function engine(role,sql){
 assert.ok(['ace','legacy','external'].includes(role));assert.equal(process.env.ACE_REVIEW_DB,'1');
 const port=Number(process.env.ACE_REVIEW_DB_PORT||55432);assert.ok(Number.isInteger(port)&&port>=1024&&port<=65535);
 return new Promise((resolve,reject)=>{
  const p=spawn('psql',['-X','-qAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',String(port),'-U','ace_cutover_'+role,'-d','ace_review','-w'],{env:{PATH:process.env.PATH,PGPASSWORD:'ace-disposable-'+role,PGCONNECT_TIMEOUT:'5',PGSSLMODE:'disable'},stdio:['pipe','pipe','pipe']});
  let out='',err='';const timer=setTimeout(()=>{p.kill();reject(Error('cutover timeout'));},15000);
  p.stdout.on('data',x=>out+=x);p.stderr.on('data',x=>err+=x);p.stdin.on('error',()=>{});
  p.on('error',e=>{clearTimeout(timer);reject(e);});p.on('close',code=>{clearTimeout(timer);code===0?resolve(out.trim()):reject(Error(err));});p.stdin.end(sql+'\n');
 });
}
const q=(role,fn)=>engine(role,'SELECT ace_cutover_review.'+fn+';');
const control=fn=>db.sql('SELECT ace_cutover_review.'+fn+';');
const settle=(role,x,career=null)=>q(role,'settle_owned('+json(x)+','+(career===null?'NULL':json(career))+')');
const counts=async id=>JSON.parse(await db.sql('SELECT jsonb_build_array((SELECT count(*) FROM ace_review.finalization_claims WHERE competition_id='+lit(id)+'),(SELECT count(*) FROM ace_review.settlement_exports WHERE competition_id='+lit(id)+'),(SELECT count(*) FROM ace_review.finalized_matches WHERE competition_id='+lit(id)+'),(SELECT count(*) FROM ace_review.finalized_competitions WHERE competition_id='+lit(id)+'),(SELECT count(*) FROM ace_review.finalized_prizes WHERE competition_id='+lit(id)+'),(SELECT count(*) FROM ace_review.career_exports WHERE competition_id='+lit(id)+'));'));
function fixture(id){
 const x=clone(reordered);x.competition_id=id;
 for(const m of x.matches){m.competition_id=id;m.match_id=id+'-'+m.match_id;for(const row of [...m.sets,...m.stats])row.match_id=m.match_id;}
 for(const row of x.results){row.competition_id=id;row.match_id=id+'-'+row.match_id;}
 for(const row of [...x.conditions,...x.support_events])row.match_id=id+'-'+row.match_id;
 for(const row of x.transactions){row.source_id=id;row.idempotency_key='tournament-prize:'+id+':'+row.player_id;}
 return x;
}
async function prepare(x,{wrongFeeder=false,legacyFirst=false}={}){
 const id=x.competition_id;assert.equal(await control('register_competition('+lit(id)+')'),'registered');
 await control('configure(true,ARRAY['+lit(id)+'])');
 for(const [i,m] of x.matches.entries()){
  await control('seed_match('+[m.match_id,id,'singles'].map(lit).join(',')+",true,'scheduled',"+(i===0&&legacyFirst?"'prepared'":"'none'")+",false,"+[m.player1_id,m.player2_id].map(lit).join(',')+')');
  const earlier=x.matches.slice(0,2),f=p=>i===2?earlier.find(z=>wrongFeeder?z.winner_id!==p:z.winner_id===p).match_id:null;
  await control('bind_feeders('+[m.match_id,f(m.player1_id),f(m.player2_id)].map(lit).join(',')+')');
  const role=i===0&&legacyFirst?'legacy':'ace';
  assert.equal(JSON.parse(await q(role,'claim('+lit(m.match_id)+')')).status,'claimed');
  if(wrongFeeder&&i===2){await assert.rejects(q(role,'start_match('+lit(m.match_id)+',1)'),/feeder not ready or winner mismatch/);continue;}
  assert.equal(await q(role,'start_match('+lit(m.match_id)+',1)'),'started');
  assert.equal(await q(role,'finish_match('+[lit(m.match_id),'2',lit(m.winner_id),json(m)].join(',')+')'),'completed');
 }
}
async function run(){
 const x=fixture('owned-ok');await prepare(x);
 await assert.rejects(db.sql('SELECT ace_review.stage_settlement('+json(x)+');'),/rejected/);
 await assert.rejects(db.sql('INSERT INTO ace_review.settlement_exports VALUES('+lit(x.competition_id)+','+json(x)+');'),/rejected/);
 await assert.rejects(db.sql('SELECT ace_review.claim_finalization('+[x.matches[0].match_id,x.competition_id,'ace',x.matches[0].player1_id,x.matches[0].player2_id,null,null].map(lit).join(',')+');'),/rejected/);
 await assert.rejects(settle('legacy',x),/permission denied/);await assert.rejects(settle('external',x),/permission denied/);
 const changed=clone(x);changed.matches[0].score='0-6 0-6';await assert.rejects(settle('ace',changed),/owned receipt mismatch/);
 assert.deepEqual(await counts(x.competition_id),[0,0,0,0,0,0]);
 const badPrize=clone(x);badPrize.transactions[0].amount++;await assert.rejects(settle('ace',badPrize),/prize\/result mismatch/);
 assert.deepEqual(await counts(x.competition_id),[0,0,0,0,0,0]);
 await assert.rejects(settle('ace',x,{competition_id:'foreign'}),/foreign career proposal/);
 assert.deepEqual(await counts(x.competition_id),[0,0,0,0,0,0]);
 await control("configure(false,ARRAY[]::text[])");
 assert.deepEqual((await Promise.all([settle('ace',x),settle('ace',x)])).sort(),['already_finalized','finalized_review']);
 assert.deepEqual(await counts(x.competition_id),[3,1,3,1,1,0]);
 const late=clone(x);late.results[0].ranking_points_earned++;await assert.rejects(settle('ace',late),/settlement export conflict/);
 assert.deepEqual(await counts(x.competition_id),[3,1,3,1,1,0]);
 const bad=fixture('owned-feeder-conflict');await prepare(bad,{wrongFeeder:true});
 await assert.rejects(settle('ace',bad),/query returned no rows/);assert.deepEqual(await counts(bad.competition_id),[0,0,0,0,0,0]);
 const mixed=fixture('owned-mixed');await prepare(mixed,{legacyFirst:true});
 await assert.rejects(settle('ace',mixed),/owned receipt mismatch/);assert.deepEqual(await counts(mixed.competition_id),[0,0,0,0,0,0]);
 await control("configure(false,ARRAY[]::text[])");
 console.log('PASS ownership-bound settlement, old API rejection, receipt/prize mismatch, rollback after effects, concurrent retry, feeder and mixed-engine rejection, drain after disable');
}
run().catch(e=>{console.error(e);process.exitCode=1});
