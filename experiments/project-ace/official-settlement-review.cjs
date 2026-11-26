'use strict';
// Review-only output for the existing singles finalizer contracts. No RPC writes.
const {isDeepStrictEqual}=require('node:util'),ledger=require('./isolated-settlement.cjs'),clock=require('./world-clock.cjs'),{duration}=require('./schedule-gate.cjs');
const {calculate}=require('./official-statistics.cjs'),{decide}=require('./health-walkover.cjs');
const copy=x=>JSON.parse(JSON.stringify(x));
const requireThat=(ok,message)=>{if(!ok)throw Error(message);};
function unique(rows,k){requireThat(Array.isArray(rows)&&new Set(rows.map(x=>x[k])).size===rows.length,'Duplicate or invalid mapping');}
function project(s,{officialMatches=null}={}){
 requireThat(s?.kind==='world'&&s.source?.schema==='ace-official-review-v1','Official review snapshot required');
 requireThat(s.draw.phase==='completed','Tournament not complete');
 const medicalReceipts=s.draw.scheduler.receipts.filter(r=>r.completionReason==='health_walkover');
 if(medicalReceipts.length){requireThat(officialMatches!==null,'Official participant rows required for medical walkovers');unique(s.draw.medicalEvidence,'matchId');requireThat(s.draw.medicalEvidence.length===medicalReceipts.length,'Incomplete medical evidence');}
 unique(s.source.players,'source');unique(s.source.players,'local');unique(s.source.matches,'source');unique(s.source.matches,'local');unique(s.draw.scheduler.receipts,'matchId');
 const map=(rows,id)=>{const row=rows.find(x=>x.local===id);requireThat(row&&typeof row.source==='string'&&row.source.length,'Missing source mapping');return row.source;};
 const player=id=>map(s.source.players,id),match=id=>map(s.source.matches,id);
 const expected=ledger.publish(ledger.settle(ledger.create(),s.draw,s.config),Math.floor(s.clock.gameSeconds/clock.DAY));
 requireThat(isDeepStrictEqual(expected,s.ledger),'Settlement ledger mismatch');
 requireThat(s.draw.scheduler.receipts.length===s.source.matches.length,'Incomplete match receipts');
 if(officialMatches!==null){unique(officialMatches,'match_id');requireThat(officialMatches.length===s.source.matches.length,'Incomplete official participant rows');}
 const matches=s.draw.scheduler.receipts.map(r=>{
  const j=s.draw.scheduler.jobs.find(x=>x.id===r.matchId),m=s.draw.matches.find(x=>x.id===r.matchId);
  requireThat(j&&m&&j.status==='completed'&&m.winner===r.winnerKey,'Invalid final checkpoint');
  const f=j.fixture.checkpoint,keys=j.playerKeys;
  requireThat(keys.length===2&&keys.includes(r.winnerKey)&&keys.includes(r.loserKey)&&r.winnerKey!==r.loserKey,'Invalid receipt participants');
  const id=match(r.matchId);
  let ordered=[0,1];
  if(officialMatches!==null){
   const row=officialMatches.find(x=>x.match_id===id);
   requireThat(row&&row.competition_id===s.config.competition&&['scheduled','in_progress'].includes(row.status)&&row.player1_id!==row.player2_id,'Invalid official match row');
   ordered=[keys.findIndex(k=>player(k)===row.player1_id),keys.findIndex(k=>player(k)===row.player2_id)];
   requireThat(ordered.every(i=>i>=0)&&ordered[0]!==ordered[1],'Official participant mismatch');
  }
  const [a,b]=ordered;
  if(r.completionReason==='health_walkover'){
   const row=officialMatches.find(x=>x.match_id===id);
   requireThat(row.status==='scheduled','Medical walkover requires unstarted official match');
   const e=s.draw.medicalEvidence.find(x=>x.matchId===r.matchId);
   requireThat(e&&e.absoluteDay===r.absoluteDay&&isDeepStrictEqual(e.players,m.players)&&Array.isArray(e.health)&&e.health.length===2,'Missing frozen medical evidence');
   unique(e.health,'playerId');
   requireThat(e.health.every(x=>keys.includes(x.playerId)&&Array.isArray(x.records)),'Invalid medical participant evidence');
   const health=Object.fromEntries(e.health.map(x=>[x.playerId,{injuries:x.records}]));
   const outcome=decide([keys[a],keys[b]],health,e.absoluteDay);
   requireThat(outcome&&outcome.winnerKey===r.winnerKey&&outcome.loserKey===r.loserKey&&isDeepStrictEqual([...outcome.blockedPlayers].sort(),[...r.blockedPlayers].sort()),'Medical result disagrees with official participant order or evidence');
   requireThat(j.actualStartAt===null&&r.startedAt===null&&f.totalPoints===0&&f.events.every(x=>x.kind!=='point')&&r.totalPoints===0&&r.totalGames===0&&r.score==='W/O'&&r.sets.length===0&&r.stats.length===0&&r.engineVersion===null&&j.completedAt===r.completedAt,'Medical receipt contains played activity');
   const completed=new Date(r.completedAt).toISOString();
   return {match_id:id,competition_id:s.config.competition,player1_id:player(keys[a]),player2_id:player(keys[b]),winner_id:player(r.winnerKey),status:'completed',completion_reason:'health_walkover',actual_duration_minutes:null,score:'W/O',sets:[],stats:[],engine_version:null,started_at:completed,completed_at:completed,medical_absolute_day:e.absoluteDay,medically_unavailable_player_ids:outcome.blockedPlayers.map(player)};
  }
  requireThat(f.status==='completed'&&keys[f.winner]===r.winnerKey&&keys[1-f.winner]===r.loserKey&&isDeepStrictEqual(f.completedSets,r.sets)&&isDeepStrictEqual(f.stats,r.stats)&&f.totalPoints===r.totalPoints&&f.gameNumber===r.totalGames&&r.score===r.sets.map(x=>x.games.join('-')).join(' '),'Receipt disagrees with checkpoint');
  const events=f.events.filter(x=>x.kind==='point');requireThat(events.length===r.totalPoints&&events.every((e,i)=>e.number===i+1&&[0,1].includes(e.server)&&[0,1].includes(e.winner)),'Incomplete point events');
  const sets=r.sets.map((x,i)=>({match_id:id,set_number:i+1,player1_games:x.games[a],player2_games:x.games[b],player1_tiebreak_points:x.tiebreak?.[a]??null,player2_tiebreak_points:x.tiebreak?.[b]??null,status:'completed'}));
  const computed=calculate(events);
  const stats=ordered.map(i=>{
   const x=r.stats[i],v=computed[i];
   requireThat(x.servicePoints===v.first_serves_total&&x.firstIn===v.first_serves_in&&x.points===v.total_points_won&&x.aces===v.aces&&x.doubleFaults===v.double_faults&&x.unforcedErrors===v.unforced_errors,'Point statistics mismatch');
   return {match_id:id,player_id:player(keys[i]),...v};
  });
  return {match_id:id,competition_id:s.config.competition,player1_id:player(keys[a]),player2_id:player(keys[b]),winner_id:player(r.winnerKey),status:'completed',actual_duration_minutes:duration(r.totalGames,r.totalPoints),score:sets.map(x=>x.player1_games+'-'+x.player2_games).join(' '),sets,stats,engine_version:r.engineVersion,started_at:new Date(r.startedAt).toISOString(),completed_at:new Date(r.completedAt).toISOString()};
 });
 const results=s.ledger.results.map(x=>({player_id:player(x.player),competition_id:x.competition,match_id:match(x.matchId),result_code:x.stage==='winner'?'champion':x.stage.startsWith('qualifying_')?'qualifying':x.stage,result_stage_code:x.stage,ranking_points_earned:x.points,qualifying_bonus_points:x.bonus,prize_money_earned:x.prize,ranking_publish_status:x.status,ranking_publish_absolute_day:x.publishDay}));
 const transactions=s.ledger.transactions.map(x=>{
  const result=results.find(r=>r.player_id===player(x.player));requireThat(result&&x.amount===result.prize_money_earned&&x.balanceAfter-x.balanceBefore===x.amount,'Prize mismatch');
  return {player_id:result.player_id,amount:x.amount,category:'prize_money',subcategory:result.result_stage_code,source_type:'tournament_result',source_id:result.competition_id,idempotency_key:'tournament-prize:'+result.competition_id+':'+result.player_id,is_taxable:true,balance_before:x.balanceBefore,balance_after:x.balanceAfter};
 });
 const conditionEvents=s.draw.conditionEvents;
 requireThat(conditionEvents.length===matches.filter(m=>m.completion_reason!=='health_walkover').length*2&&new Set(conditionEvents.map(e=>e.matchId+':'+e.playerId)).size===conditionEvents.length,'Invalid career condition events');
 const conditions=conditionEvents.map(e=>{const m=matches.find(x=>x.match_id===match(e.matchId)),id=player(e.playerId);requireThat(m&&m.completion_reason!=='health_walkover'&&[m.player1_id,m.player2_id].includes(id)&&e.won===(m.winner_id===id)&&e.minutes===m.actual_duration_minutes,'Career event mismatch');return {match_id:m.match_id,player_id:id,won:e.won,minutes:e.minutes,fatigue_gain:e.gain,before:e.before,after:e.after};});
 const supportEvents=s.draw.worldSupport.events.map(e=>{const id=player(e.playerId),mid=match(e.matchId);requireThat(conditions.some(x=>x.player_id===id&&x.match_id===mid),'Unmatched support event');return {match_id:mid,player_id:id,injury_risk_percent:e.injuryRiskPercent,equipment_wear:e.wear};});
 return copy({schema:'ace-settlement-review-v1',review_only:true,production_ready:false,competition_id:s.config.competition,matches,results,transactions,conditions,support_events:supportEvents,participant_order_verified:officialMatches!==null,statistics_convention:'legacy-v1-point-classification',blockers:[...(officialMatches===null?['official participant order verification required']:[]),'authoritative feeder verification required','official finalizer/trigger integration not implemented',...(medicalReceipts.length?['authoritative medical evidence revalidation required']:[]),'monthly tax and remaining career effects not applied']});
}
module.exports={project};
