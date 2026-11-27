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
 // Fixtures are frozen by preceding closure test in this same disposable CI DB.
 const comp='normal-close-ci';
 const audit=JSON.parse(await db.sql('SELECT report FROM ace_cutover_review.closure_audits WHERE competition_id='+lit(comp)+';'));
 const results=audit.legacy_result_candidates.map(x=>({...x,id:'result-'+x.player_id,result_code:x.result_stage_code==='winner'?'champion':x.result_stage_code}));
 const prizes=audit.legacy_prize_candidates.map(x=>({...x,id:'prize-'+x.player_id,category:'prize_money',subcategory:results.find(r=>r.player_id===x.player_id).result_stage_code,source_type:'tournament_result',balance_before:1000,balance_after:1000+x.amount}));
 const snap={competition_id:comp,complete_export:true,observed_absolute_day:8,season_number:1,tournament_series_id:'series-test',world:'ATP',results,prizes,contributions:[]};
 const recon=(id,s=snap,c=comp)=>control('reconcile_rewards('+[lit(c),lit(id),json(s)].join(',')+')').then(JSON.parse);
 const good=await Promise.all([recon('good'),recon('good')]);assert.deepEqual(good[0],good[1]);assert.equal(good[0].status,'matched_review');
 assert.ok(good[0].players.every(x=>x.result==='matched'&&x.prize==='already_posted'&&x.ranking==='pending_not_due'));
 await assert.rejects(recon('good',{...snap,observed_absolute_day:9}),/rejected/);
 await assert.rejects(recon('duplicate',{...snap,prizes:[...prizes,prizes[0]]}),/rejected/);
 await assert.rejects(recon('incomplete',{...snap,complete_export:false}),/rejected/);
 await assert.rejects(q('ace','reconcile_rewards('+[lit(comp),lit('forbidden'),json(snap)].join(',')+')'),/permission denied/);
 const bad=clone(snap);bad.prizes[0].amount++;bad.results[1].ranking_points_earned++;bad.prizes.push({...prizes[0],id:'wrong-key',idempotency_key:'unexpected'});
 const conflicts=await recon('conflict',bad);assert.equal(conflicts.status,'blocked_review');assert.ok(conflicts.players.every(x=>x.prize==='conflict'));assert.ok(conflicts.issues.some(x=>x.kind==='unmapped_existing_prize'));
 const missing=await recon('missing',{...snap,results:[],prizes:[]});assert.ok(missing.players.every(x=>x.result==='missing'&&x.prize==='missing'));
 const due=await recon('due',{...snap,observed_absolute_day:9});assert.ok(due.players.every(x=>x.ranking==='due_review'));
 const published=clone(snap);published.observed_absolute_day=10;published.results.forEach(x=>x.ranking_publish_status='published');
 published.contributions=published.results.map(x=>({id:'contrib-'+x.player_id,source_result_id:x.id,player_id:x.player_id,competition_id:comp,tournament_series_id:snap.tournament_series_id,world:'ATP',season_number:1,ranking_points:x.ranking_points_earned,awarded_absolute_day:9,expires_absolute_day:375,is_active:true}));
 assert.ok((await recon('published',published)).players.every(x=>x.ranking==='already_active'));
 const history=clone(published);history.observed_absolute_day=376;history.contributions.forEach(x=>{x.is_active=false;x.deactivated_absolute_day=375;});
 assert.ok((await recon('history',history)).players.every(x=>x.ranking==='historical_inactive'));
 const expired=clone(published);expired.observed_absolute_day=375;
 assert.ok((await recon('expired',expired)).players.every(x=>x.ranking==='expiry_review'));
 const orphan=clone(published);orphan.contributions[0].source_result_id='missing-result';assert.ok((await recon('orphan',orphan)).issues.some(x=>x.kind==='orphan_or_mismatched_contribution'));
 const special='special-close-ci',existing={...snap,competition_id:special,results:[],prizes:[],contributions:[]};
 const sp=await recon('special',existing,special);assert.equal(sp.status,'blocked_review');assert.ok(sp.closure_blockers.includes('special_terminal_reward_policy_requires_review'));
 assert.equal(await db.sql("SELECT count(*) FROM ace_review.finalized_prizes WHERE competition_id IN ('normal-close-ci','special-close-ci');"),'0');
 console.log('PASS immutable reward reconciliation snapshots, existing prize and rank protection, conflicts, missing rows, expiry and special closure blockers, no posting');
}
run().catch(e=>{console.error(e);process.exitCode=1});
