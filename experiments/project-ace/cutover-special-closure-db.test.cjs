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
 const id='special-close-ci';await register(id);
 const m=(key,p1,p2)=>({match_id:key,player1_id:p1,player2_id:p2});
 const reg={is_guest:false,is_anonymous:false,expires_at:null,converted_at:null};
 const expired={is_guest:true,is_anonymous:true,expires_at:'2026-11-27T08:00:00Z',converted_at:null};
 const freezeGuest=(key,a,b)=>q('external','freeze_guest('+[lit(key),lit('guest-event'),lit('2026-11-27T08:00:00Z')+'::timestamptz',json(a),json(b)].join(',')+')');
 const resolve=key=>q('ace','finish_guest('+lit(key)+',1)');
 const audit=(comp,contract)=>control('audit_special_closure('+lit(comp)+','+json(contract)+')').then(JSON.parse);
 await seed(id,m('close-left','p1','p2'));await claim('ace','close-left');await freezeGuest('close-left',expired,expired);await resolve('close-left');
 await seed(id,m('close-right','p3','p4'));await claim('ace','close-right');await start('close-right');
 await q('ace',"finish_match('close-right',2,'p3',"+json({score:'6-0 6-0'})+")");
 await seed(id,m('close-final','p1','p3'),'close-left','close-right');await claim('ace','close-final');
 const c={matches:[{match_id:'close-left',phase:'main_draw',round_label:'Semifinal',round_number:1},{match_id:'close-right',phase:'main_draw',round_label:'Semifinal',round_number:1},{match_id:'close-final',phase:'main_draw',round_label:'Final',round_number:2}],players:['p1','p2','p3','p4'].map(player_id=>({player_id,player_type:'human'})),rewards:[{stage_code:'semifinal',ranking_points:40,prize_money_usd:2000},{stage_code:'winner',ranking_points:100,prize_money_usd:5000},{stage_code:'runner_up',ranking_points:60,prize_money_usd:3000}],ranking_publish_absolute_day:9};
 await assert.rejects(audit(id,c),/rejected/);
 await q('ace',"continue_void_bracket('close-final',1)");
 await assert.rejects(audit(id,{...c,matches:c.matches.slice(1)}),/rejected/);
 await assert.rejects(q('ace','audit_special_closure('+lit(id)+','+json(c)+')'),/permission denied/);
 const reports=await Promise.all([audit(id,c),audit(id,c)]);
 assert.deepEqual(reports[0],reports[1]);const out=reports[0];
 assert.equal(out.status,'blocked_special_results');assert.equal(out.champion_candidate_id,'p3');
 assert.deepEqual(out.legacy_result_candidates.map(r=>[r.player_id,r.result_stage_code,r.ranking_points_earned]),[['p4','semifinal',40]]);
 assert.equal(out.legacy_prize_candidates[0].amount,2000);assert.equal(out.skipped_matches.length,2);
 assert.ok(out.blockers.includes('final_not_completed_under_legacy_reward_trigger'));
 await assert.rejects(audit(id,{...c,ranking_publish_absolute_day:16}),/rejected/);
 await assert.rejects(seed(id,m('close-extra','p1','p4')),/rejected/);
 assert.equal(await db.sql("SELECT count(*) FROM ace_review.finalized_prizes WHERE competition_id='special-close-ci';"),'0');
 const id2='normal-close-ci';await register(id2);await seed(id2,m('normal-final','p3','p4'));await claim('ace','normal-final');await start('normal-final');
 await q('ace',"finish_match('normal-final',2,'p3',"+json({score:'6-4 6-4'})+")");
 const normal=await audit(id2,{...c,matches:[{match_id:'normal-final',phase:'main_draw',round_label:'Final',round_number:1}]});
 assert.equal(normal.status,'normal_legacy_candidates');assert.equal(normal.champion_candidate_id,'p3');
 assert.deepEqual(normal.legacy_result_candidates.map(r=>r.result_stage_code),['runner_up','winner']);assert.equal(normal.legacy_prize_candidates.length,2);
 const id3='no-champion-ci';await register(id3);await seed(id3,m('empty-final','p1','p2'));await claim('ace','empty-final');await freezeGuest('empty-final',expired,expired);await resolve('empty-final');
 const empty=await audit(id3,{...c,matches:[{match_id:'empty-final',phase:'main_draw',round_label:'Final',round_number:1}]});
 assert.equal(empty.champion_candidate_id,null);assert.ok(empty.blockers.includes('no_champion'));assert.deepEqual(empty.legacy_prize_candidates,[]);
 await control("configure(false,ARRAY[]::text[])");
 console.log('PASS complete owned terminal inventory, legacy-trigger candidates, special final/no champion block, immutable concurrent audit, no actual prize writes');
}
run().catch(e=>{console.error(e);process.exitCode=1});
