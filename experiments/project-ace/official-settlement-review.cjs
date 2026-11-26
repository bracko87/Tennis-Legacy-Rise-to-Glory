'use strict';
// Review-only output for the existing singles finalizer contracts. No RPC writes.
const {isDeepStrictEqual}=require('node:util'),ledger=require('./isolated-settlement.cjs'),clock=require('./world-clock.cjs'),{duration}=require('./schedule-gate.cjs');
const copy=x=>JSON.parse(JSON.stringify(x));
const requireThat=(ok,message)=>{if(!ok)throw Error(message);};
function unique(rows,k){requireThat(Array.isArray(rows)&&new Set(rows.map(x=>x[k])).size===rows.length,'Duplicate or invalid mapping');}
function project(s){
 requireThat(s?.kind==='world'&&s.source?.schema==='ace-official-review-v1','Official review snapshot required');
 requireThat(s.draw.phase==='completed','Tournament not complete');
 unique(s.source.players,'source');unique(s.source.players,'local');unique(s.source.matches,'source');unique(s.source.matches,'local');unique(s.draw.scheduler.receipts,'matchId');
 const map=(rows,id)=>{const row=rows.find(x=>x.local===id);requireThat(row&&typeof row.source==='string'&&row.source.length,'Missing source mapping');return row.source;};
 const player=id=>map(s.source.players,id),match=id=>map(s.source.matches,id);
 const expected=ledger.publish(ledger.settle(ledger.create(),s.draw,s.config),Math.floor(s.clock.gameSeconds/clock.DAY));
 requireThat(isDeepStrictEqual(expected,s.ledger),'Settlement ledger mismatch');
 requireThat(s.draw.scheduler.receipts.length===s.source.matches.length,'Incomplete match receipts');
 const matches=s.draw.scheduler.receipts.map(r=>{
  const j=s.draw.scheduler.jobs.find(x=>x.id===r.matchId),m=s.draw.matches.find(x=>x.id===r.matchId);
  requireThat(j&&m&&j.status==='completed'&&j.fixture.checkpoint.status==='completed'&&m.winner===r.winnerKey,'Invalid final checkpoint');
  const f=j.fixture.checkpoint,keys=j.playerKeys;
  requireThat(keys.length===2&&keys[f.winner]===r.winnerKey&&keys[1-f.winner]===r.loserKey&&isDeepStrictEqual(f.completedSets,r.sets)&&isDeepStrictEqual(f.stats,r.stats)&&f.totalPoints===r.totalPoints&&f.gameNumber===r.totalGames&&r.score===r.sets.map(x=>x.games.join('-')).join(' '),'Receipt disagrees with checkpoint');
  const events=f.events.filter(x=>x.kind==='point');requireThat(events.length===r.totalPoints&&events.every((e,i)=>e.number===i+1&&[0,1].includes(e.server)&&[0,1].includes(e.winner)),'Incomplete point events');
  const id=match(r.matchId);
  const sets=r.sets.map((x,i)=>({match_id:id,set_number:i+1,player1_games:x.games[0],player2_games:x.games[1],player1_tiebreak_points:x.tiebreak?.[0]??null,player2_tiebreak_points:x.tiebreak?.[1]??null,status:'completed'}));
  const stats=keys.map((key,i)=>{
   const served=events.filter(e=>e.server===i),first=served.filter(e=>e.first),second=served.filter(e=>!e.first);
   const x=r.stats[i];requireThat(x.servicePoints===served.length&&x.firstIn===first.length&&x.points===events.filter(e=>e.winner===i).length&&x.aces===served.filter(e=>e.ace).length&&x.doubleFaults===served.filter(e=>e.df).length,'Point statistics mismatch');
   return {match_id:id,player_id:player(key),aces:x.aces,double_faults:x.doubleFaults,first_serves_in:x.firstIn,first_serves_total:x.servicePoints,first_serve_points_won:first.filter(e=>e.winner===i).length,first_serve_points_played:first.length,second_serve_points_won:second.filter(e=>e.winner===i).length,second_serve_points_played:second.length,unforced_errors:x.unforcedErrors,total_points_won:x.points,
    // No explicit winner classification or break-point counters in current engine.
    winners:null,break_points_won:null,break_points_total:null};
  });
  return {match_id:id,competition_id:s.config.competition,player1_id:player(keys[0]),player2_id:player(keys[1]),winner_id:player(r.winnerKey),status:'completed',actual_duration_minutes:duration(r.totalGames,r.totalPoints),score:r.score,sets,stats,engine_version:r.engineVersion,started_at:new Date(r.startedAt).toISOString(),completed_at:new Date(r.completedAt).toISOString()};
 });
 const results=s.ledger.results.map(x=>({player_id:player(x.player),competition_id:x.competition,match_id:match(x.matchId),result_code:x.stage==='winner'?'champion':x.stage.startsWith('qualifying_')?'qualifying':x.stage,result_stage_code:x.stage,ranking_points_earned:x.points,qualifying_bonus_points:x.bonus,prize_money_earned:x.prize,ranking_publish_status:x.status,ranking_publish_absolute_day:x.publishDay}));
 const transactions=s.ledger.transactions.map(x=>{
  const result=results.find(r=>r.player_id===player(x.player));requireThat(result&&x.amount===result.prize_money_earned&&x.balanceAfter-x.balanceBefore===x.amount,'Prize mismatch');
  return {player_id:result.player_id,amount:x.amount,category:'prize_money',subcategory:result.result_stage_code,source_type:'tournament_result',source_id:result.competition_id,idempotency_key:'tournament-prize:'+result.competition_id+':'+result.player_id,is_taxable:true,balance_before:x.balanceBefore,balance_after:x.balanceAfter};
 });
 return copy({schema:'ace-settlement-review-v1',review_only:true,production_ready:false,competition_id:s.config.competition,matches,results,transactions,blockers:['missing official winner and break-point statistics','official participant order and feeder verification required','official finalizer/trigger integration not implemented','monthly tax and remaining career effects not applied']});
}
module.exports={project};
