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
const {propose}=require('./source-career-proposal.cjs'),{duration}=require('./schedule-gate.cjs'),engineCore=require('./engine.cjs'),{calculate}=require('./official-statistics.cjs');
async function run(){
 const c='integrated-eight-ci',players=Array.from({length:8},(_,i)=>({id:c+'-p'+i})),slots=[];
 const profile={fatigue:30,sharpness:60,morale:60,confidence:60,focus:60,fitness:65,stamina:65,recovery:65,movement:65};
 for(let round=1;round<=3;round++)for(let number=1;number<=8/2**round;number++)slots.push({id:c+'-'+round+'-'+number,competition_id:c,draw_type:'main_draw',round_number:round,match_number:number,status:'scheduled',started_at:null,completed_at:null,winner_id:null,player1_id:round===1?players[number*2-2].id:null,player2_id:round===1?players[number*2-1].id:null,scheduled_season_week:1,scheduled_day:round,scheduled_start_minute:600,court_number:number});
 const frozen=freezeSource({schema:'ace-source-admission-v1',complete_export:true,competition:{id:c,scope:'singles',field_locked:true,qualification_required:false,status:'published',season_number:1,draw_size:8},players,matches:slots,results:[],simulations:[]});
 await control('import_source_contract('+json(frozen)+')');await control('bind_source_venue('+[lit(c),lit(c+'-venue')].join(',')+')');await control('enable_source_career_review('+lit(c)+",'hard')");await control('configure(true,ARRAY['+lit(c)+'])');
 for(const p of players)await control('observe_source_career('+[lit(p.id),-1,json({profile:{...profile},staff:{matchFatigueReduction:.1},injuries:[],inventory:[{id:p.id+'-r',type:'racket',condition:80,wear_per_match:2}],loadout:{racket:p.id+'-r',shoes:null,apparel:null}})].join(',')+')');
 const played=[],conditions=[],support_events=[],winners=new Map(),counts=new Map();
 const rewards=[['quarterfinal',50,2000],['semifinal',100,4000],['runner_up',165,5000],['winner',250,10000]].map(([stage_code,ranking_points,prize_money_usd])=>({stage_code,ranking_points,prize_money_usd}));
 const results=[],transactions=[];
 const payload=()=>({schema:'ace-settlement-review-v1',review_only:true,production_ready:false,participant_order_verified:true,competition_id:c,matches:played,results,transactions,conditions,support_events});
 for(let round=1;round<=3;round++){
  assert.equal(await control('publish_source_clock('+[lit(c),round-2,(round+1)*86400+36000,false].join(',')+')'),String(round-1));
  for(const slot of frozen.matches.filter(x=>x.round_number===round)){
   const id=slot.match_id,p1=round===1?slot.player1_id:winners.get(slot.feeder1),p2=round===1?slot.player2_id:winners.get(slot.feeder2);
   const sr=round===1?0:1;
   if(sr)assert.equal(await control('observe_source('+[lit(id),0,json({player1_id:p1,player2_id:p2,status:'scheduled',simulation:'none',started:false,winner_id:null})].join(',')+')'),'1');
   assert.equal(JSON.parse(await q('ace','admit_source('+lit(id)+','+sr+')')).status,'admitted');
   const ready={player1_id:p1,player2_id:p2,complete_health_export:true,health1:[],health2:[],travel_ready:true,resources_ready:true};
   await control('freeze_source_readiness('+[lit(id),-1,1,sr,round-1,json(ready)].join(',')+')');
   assert.equal(await q('ace','start_source('+lit(id)+',1,0,'+(round-1)+')'),'started');
   const snapshot=JSON.parse(await db.sql('SELECT snapshot FROM ace_cutover_review.source_career_starts WHERE match_id='+lit(id)+';'));
   const profiles=snapshot.players.map((p,i)=>({name:p.player_id,serve:62+i,return:58,rally:60,forehand:65,backhand:55,...p.profile}));
   let s=engineCore.createMatch({players:profiles,seed:100+played.length,bestOf:3});
   while(s.status!=='completed')s=engineCore.stepGame(s);
   const ids=[p1,p2],winner=ids[s.winner],loser=ids[1-s.winner];
   const receipt={match_id:id,competition_id:c,player1_id:p1,player2_id:p2,winner_id:winner,status:'completed',actual_duration_minutes:duration(s.gameNumber,s.totalPoints),score:s.completedSets.map(z=>z.games.join('-')).join(' '),sets:s.completedSets.map((z,i)=>({match_id:id,set_number:i+1,player1_games:z.games[0],player2_games:z.games[1],player1_tiebreak_points:z.tiebreak?.[0]??null,player2_tiebreak_points:z.tiebreak?.[1]??null,status:'completed'})),stats:calculate(s.events.filter(z=>z.kind==='point')).map((z,i)=>({match_id:id,player_id:ids[i],...z})),engine_version:'ace-integrated-review',started_at:'2026-01-01T10:00:00Z',completed_at:'2026-01-01T12:00:00Z'};
   assert.equal(await q('ace','finish_match('+[lit(id),2,lit(winner),json(receipt)].join(',')+')'),'completed');
   played.push(receipt);winners.set(id,winner);
   if(played.length===1)await assert.rejects(settle(payload()),/incomplete imported source inventory/);
   await control('sync_source_event('+lit(id)+',2)');await control('sync_source_event('+lit(id)+',3)');
   const match={...receipt,owner:'ace',revision:3},proposal=propose({match,receipt,snapshot});
   const applied=JSON.parse(await control('apply_source_career('+[lit(id),json(snapshot),json(receipt),json(proposal)].join(',')+')'));assert.equal(applied.status,'applied_review');
   for(const x of proposal.players){counts.set(x.player_id,(counts.get(x.player_id)||0)+1);conditions.push({match_id:id,player_id:x.player_id,won:x.player_id===winner,minutes:x.minutes,fatigue_gain:x.fatigue_gain,before:x.before,after:x.after});support_events.push({match_id:id,player_id:x.player_id,injury_risk_percent:x.injury_risk_percent,equipment_wear:x.wear_events});}
   const award=(player_id,stage)=>{const rule=rewards.find(z=>z.stage_code===stage);results.push({player_id,match_id:id,competition_id:c,result_code:stage==='winner'?'champion':stage,result_stage_code:stage,ranking_points_earned:rule.ranking_points,qualifying_bonus_points:0,prize_money_earned:rule.prize_money_usd,ranking_publish_status:'pending',ranking_publish_absolute_day:9});if(player_id===players[0].id)transactions.push({player_id,amount:rule.prize_money_usd,category:'prize_money',subcategory:stage,source_type:'tournament_result',source_id:c,idempotency_key:'tournament-prize:'+c+':'+player_id,is_taxable:true,balance_before:1000,balance_after:1000+rule.prize_money_usd});};
   award(loser,['quarterfinal','semifinal','runner_up'][round-1]);if(round===3)award(winner,'winner');
  }
 }
 assert.equal(played.length,7);assert.equal(results.length,8);assert.equal(conditions.length,14);assert.equal(transactions.length,1);
 await assert.rejects(settle(payload()),/imported closure audit or reward mismatch/);
 const contract={matches:frozen.matches.map(m=>({match_id:m.match_id,phase:'main_draw',round_label:['Quarterfinal','Semifinal','Final'][m.round_number-1],round_number:m.round_number})),players:players.map((p,i)=>({player_id:p.id,player_type:i===0?'human':'ai'})),rewards,ranking_publish_absolute_day:9};
 const audit=JSON.parse(await control('audit_special_closure('+lit(c)+','+json(contract)+')'));assert.equal(audit.status,'normal_legacy_candidates');assert.equal(audit.champion_candidate_id,played.at(-1).winner_id);
 const bad=clone(payload());bad.results[0].ranking_points_earned++;await assert.rejects(settle(bad),/imported closure audit or reward mismatch/);
 await control("configure(false,ARRAY[]::text[])");
 assert.deepEqual((await Promise.all([settle(payload()),settle(payload())])).sort(),['already_finalized','finalized_review']);
 for(const p of players){const row=JSON.parse(await db.sql('SELECT to_jsonb(t) FROM ace_cutover_review.source_career_players t WHERE player_id='+lit(p.id)+';'));assert.equal(row.revision,counts.get(p.id));assert.equal(row.state.inventory[0].condition,80-2*counts.get(p.id));assert.equal(row.state.profile.fitness,65);}
 assert.equal(await db.sql('SELECT count(*) FROM ace_review.finalized_matches WHERE competition_id='+lit(c)+';'),'7');
 assert.equal(await db.sql('SELECT count(*) FROM ace_review.finalized_prizes WHERE competition_id='+lit(c)+';'),'1');
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.source_career_effects e JOIN ace_cutover_review.source_slots s USING(match_id) WHERE s.competition_id='+lit(c)+';'),'14');
 assert.equal(await db.sql('SELECT count(*) FROM ace_cutover_review.active_source_resources a JOIN ace_cutover_review.source_slots s USING(match_id) WHERE s.competition_id='+lit(c)+';'),'0');
 console.log('PASS eight-player actual Ace engine draw, 7 owned matches, 14 career effects, full closure, one prize and concurrent settlement retry');
}
run().catch(e=>{console.error(e);process.exitCode=1});
