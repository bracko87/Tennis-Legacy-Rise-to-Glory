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
const {propose}=require('./source-career-proposal.cjs'),{duration}=require('./schedule-gate.cjs'),engineCore=require('./engine.cjs'),{calculate}=require('./official-statistics.cjs');
async function run(qr){
 const input=qualificationFixture('qualification-source-ci-'+qr,qr),c=input.competition.id,f=freezeQualification(input);
 const imp=x=>control('import_source_qualification('+json(x)+')');
 const main=f.matches.filter(x=>x.draw_type==='main_draw');const bad=clone(f);bad.matches.find(x=>x.match_id===main[1].match_id).feeder1=main[0].feeder1;await assert.rejects(imp(bad),/rejected/);
 assert.equal(await imp(f),'imported');assert.equal(await imp(f),'already_imported');
 await control('bind_source_venue('+[lit(c),lit(c+'-venue')].join(',')+')');await control('enable_source_career_review('+lit(c)+",'hard')");await control('configure(true,ARRAY['+lit(c)+'])');
 const profile={fatigue:30,sharpness:60,morale:60,confidence:60,focus:60,fitness:65,stamina:65,recovery:65,movement:65};
 for(const p of input.players)await control('observe_source_career('+[lit(p.id),-1,json({profile:{...profile},staff:{matchFatigueReduction:.1},injuries:[],inventory:[{id:p.id+'-r',type:'racket',condition:80,wear_per_match:2}],loadout:{racket:p.id+'-r',shoes:null,apparel:null}})].join(',')+')');
 const counts=new Map(),qualifiers=new Set(),human=input.players[0].id;
 const winners=new Map(),played=[],results=[],transactions=[],conditions=[],support_events=[];
 const rewards=[['qualifying_round_1_loss',1,20],['qualifying_round_2_loss',3,50],['qualifying_final_loss',7,100],['qualified_bonus',13,0],['quarterfinal',50,200],['semifinal',100,400],['runner_up',165,500],['winner',250,1000]].map(([stage_code,ranking_points,prize_money_usd])=>({stage_code,ranking_points,prize_money_usd}));
 const award=(id,player_id,stage)=>{
  const rule=rewards.find(z=>z.stage_code===stage);assert.ok(rule);
  const bonus=qualifiers.has(player_id)&&!stage.startsWith('qualifying_')?13:0;
  assert.ok(!results.some(x=>x.player_id===player_id));
  const row={match_id:id,player_id,competition_id:c,result_code:stage==='winner'?'champion':stage.startsWith('qualifying_')?'qualifying':stage,result_stage_code:stage,ranking_points_earned:rule.ranking_points+bonus,qualifying_bonus_points:bonus,prize_money_earned:rule.prize_money_usd,ranking_publish_status:'pending',ranking_publish_absolute_day:16};
  results.push(row);
  if(player_id===human&&rule.prize_money_usd>0)transactions.push({player_id,amount:rule.prize_money_usd,category:'prize_money',subcategory:stage,source_type:'tournament_result',source_id:c,idempotency_key:'tournament-prize:'+c+':'+player_id,is_taxable:true,balance_before:1000,balance_after:1000+rule.prize_money_usd});
 };
 const admit=(id,rev=0)=>q('ace','admit_source('+lit(id)+','+rev+')').then(JSON.parse);
 const observe=(id,p1,p2)=>control('observe_source('+[lit(id),0,json({player1_id:p1,player2_id:p2,status:'scheduled',simulation:'none',started:false,winner_id:null})].join(',')+')');
 const sync=async id=>{await control('sync_source_event('+lit(id)+',2)');await control('sync_source_event('+lit(id)+',3)');};
 assert.equal((await admit(main[2].match_id)).status,'qualification_sync_pending');
 let cr=-1;
 for(const [phase,round] of [...Array.from({length:qr},(_,i)=>['qualification',i+1]),['main_draw',1],['main_draw',2],['main_draw',3]]){
  const day=phase==='qualification'?round+1:8+round;
  assert.equal(await control('publish_source_clock('+[lit(c),cr,day*86400+36000,false].join(',')+')'),String(++cr));
  for(const s of f.matches.filter(x=>x.draw_type===phase&&x.round_number===round)){
   const id=s.match_id,p1=s.feeder1?winners.get(s.feeder1):s.player1_id,p2=s.feeder2?winners.get(s.feeder2):s.player2_id,rev=s.feeder1||s.feeder2?1:0;
   if(rev){if(phase==='main_draw'&&round===1&&s.feeder1){const feeder=played.find(x=>x.match_id===s.feeder1);const wrong=feeder.player1_id===feeder.winner_id?feeder.player2_id:feeder.player1_id;await observe(id,wrong,p2);assert.equal((await admit(id,1)).status,'feeder_receipts_pending_or_mismatch');await control('observe_source('+[lit(id),1,json({player1_id:p1,player2_id:p2,status:'scheduled',simulation:'none',started:false,winner_id:null})].join(',')+')');}else await observe(id,p1,p2);}
   const sr=phase==='main_draw'&&round===1&&s.feeder1?2:rev;
   assert.equal((await admit(id,sr)).status,'admitted');
   await control('freeze_source_readiness('+[lit(id),-1,1,sr,cr,json({player1_id:p1,player2_id:p2,complete_health_export:true,health1:[],health2:[],travel_ready:true,resources_ready:true})].join(',')+')');
   assert.equal(await q('ace','start_source('+lit(id)+',1,0,'+cr+')'),'started');
   const snapshot=JSON.parse(await db.sql('SELECT snapshot FROM ace_cutover_review.source_career_starts WHERE match_id='+lit(id)+';'));
   assert.equal(snapshot.absolute_day,day);
   for(const p of snapshot.players)assert.equal(p.career_revision,counts.get(p.player_id)||0);
   const profiles=snapshot.players.map((p,i)=>({name:p.player_id,serve:62+i,return:58,rally:60,forehand:65,backhand:55,...p.profile}));
   let state=engineCore.createMatch({players:profiles,seed:100+played.length,bestOf:3});
   while(state.status!=='completed')state=engineCore.stepGame(state);
   const ids=[p1,p2],winner=ids[state.winner],loser=ids[1-state.winner],minutes=duration(state.gameNumber,state.totalPoints);
   const startMs=Date.UTC(2026,0,1)+day*86400000+36000000;
   const m={match_id:id,competition_id:c,player1_id:p1,player2_id:p2,winner_id:winner,status:'completed',actual_duration_minutes:minutes,score:state.completedSets.map(z=>z.games.join('-')).join(' '),sets:state.completedSets.map((z,i)=>({match_id:id,set_number:i+1,player1_games:z.games[0],player2_games:z.games[1],player1_tiebreak_points:z.tiebreak?.[0]??null,player2_tiebreak_points:z.tiebreak?.[1]??null,status:'completed'})),stats:calculate(state.events.filter(z=>z.kind==='point')).map((z,i)=>({match_id:id,player_id:ids[i],...z})),engine_version:'ace-integrated-review',started_at:new Date(startMs).toISOString(),completed_at:new Date(startMs+minutes*60000).toISOString()};
   assert.equal(m.stats.reduce((n,x)=>n+x.total_points_won,0),state.totalPoints);
   assert.equal(await q('ace','finish_match('+[lit(id),2,lit(winner),json(m)].join(',')+')'),'completed');played.push(m);winners.set(id,winner);
   if(phase==='qualification'){award(id,loser,round===qr?'qualifying_final_loss':'qualifying_round_'+round+'_loss');if(round===qr)qualifiers.add(winner);}
   else{award(id,loser,['quarterfinal','semifinal','runner_up'][round-1]);if(round===3)award(id,winner,'winner');}
   if(phase==='qualification'&&played.length===2*(2**qr-1))assert.equal((await admit(main[2].match_id)).status,'qualification_sync_pending');
   await sync(id);
   const proposal=propose({match:{...m,owner:'ace',revision:3},receipt:m,snapshot});
   const apply=()=>control('apply_source_career('+[lit(id),json(snapshot),json(m),json(proposal)].join(',')+')').then(JSON.parse);
   const applied=await apply();assert.equal(applied.status,'applied_review');assert.deepEqual(await apply(),applied);
   for(const x of proposal.players){counts.set(x.player_id,(counts.get(x.player_id)||0)+1);conditions.push({match_id:id,player_id:x.player_id,won:x.player_id===winner,minutes:x.minutes,fatigue_gain:x.fatigue_gain,before:x.before,after:x.after});support_events.push({match_id:id,player_id:x.player_id,injury_risk_percent:x.injury_risk_percent,equipment_wear:x.wear_events});}
  }
 }
 const contract={matches:f.matches.map(x=>({match_id:x.match_id,phase:x.draw_type,round_number:x.round_number,round_label:x.draw_type==='qualification'?(x.round_number===qr?'Final Qualifying':'Qualifying Round '+x.round_number):['Quarterfinal','Semifinal','Final'][x.round_number-1]})),players:input.players.map(p=>({player_id:p.id,player_type:p.id===human?'human':'ai'})),rewards,ranking_publish_absolute_day:16};
 const audit=JSON.parse(await control('audit_special_closure('+lit(c)+','+json(contract)+')'));assert.equal(audit.status,'normal_legacy_candidates');assert.equal(audit.legacy_result_candidates.length,input.players.length);assert.equal(audit.legacy_result_candidates.filter(x=>x.result_stage_code==='qualifying_final_loss').length,2);assert.equal(audit.legacy_result_candidates.filter(x=>x.qualifying_bonus_points===13).length,2);assert.equal(audit.champion_candidate_id,played.at(-1).winner_id);for(let r=1;r<qr;r++)assert.equal(audit.legacy_result_candidates.filter(x=>x.result_stage_code==='qualifying_round_'+r+'_loss').length,2*2**(qr-r));
 assert.equal(qualifiers.size,2);assert.equal(results.length,input.players.length);assert.equal(transactions.length,1);
 for(const candidate of audit.legacy_result_candidates){const actual=results.find(x=>x.player_id===candidate.player_id);assert.ok(actual);for(const [key,value] of Object.entries(candidate))assert.deepEqual(actual[key],value);}
 assert.deepEqual(new Set(results.filter(x=>x.qualifying_bonus_points===13).map(x=>x.player_id)),qualifiers);
 for(const p of input.players){const row=JSON.parse(await db.sql('SELECT to_jsonb(t) FROM ace_cutover_review.source_career_players t WHERE player_id='+lit(p.id)+';'));assert.equal(row.revision,counts.get(p.id));assert.equal(row.state.inventory[0].condition,80-2*counts.get(p.id));assert.equal(row.state.profile.fitness,65);}
 assert.equal(conditions.length,2*f.matches.length);
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.source_career_effects e JOIN ace_cutover_review.source_slots s USING(match_id) WHERE s.competition_id='+lit(c)+';'),String(2*f.matches.length));
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.active_source_resources a JOIN ace_cutover_review.source_slots s USING(match_id) WHERE s.competition_id='+lit(c)+';'),'0');
 const payload={schema:'ace-settlement-review-v1',review_only:true,production_ready:false,participant_order_verified:true,competition_id:c,matches:played,results,transactions,conditions,support_events};
 const altered=clone(payload);altered.results.find(x=>x.qualifying_bonus_points===13).qualifying_bonus_points=0;await assert.rejects(settle(altered),/imported closure audit or reward mismatch/);
 assert.deepEqual((await Promise.all([settle(payload),settle(payload)])).sort(),['already_finalized','finalized_review']);
 assert.equal(await db.sql('SELECT count(*) FROM ace_review.finalized_prizes WHERE competition_id='+lit(c)+';'),'1');
 assert.equal(await db.sql('SELECT count(*) FROM ace_review.finalized_matches WHERE competition_id='+lit(c)+';'),String(f.matches.length));
 await control("configure(false,ARRAY[]::text[])");console.log('PASS actual Ace '+qr+'-round qualification, '+f.matches.length+' matches, '+conditions.length+' career effects, synchronized winners, independent rewards and exact settlement replay');
}
(async()=>{for(const qr of [1,2,3])await run(qr);})().catch(e=>{console.error(e);process.exitCode=1});
