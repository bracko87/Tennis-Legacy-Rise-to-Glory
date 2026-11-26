'use strict';
// Separate immutable review proposal. No production tax/health RPCs.
const {project}=require('./official-settlement-review.cjs'),{taxReview,injuryReview,recoveryReview}=require('./career-processing-review.cjs'),{DAY}=require('./world-clock.cjs'),{isDeepStrictEqual}=require('node:util');
const check=(x,m)=>{if(!x)throw Error(m);},copy=x=>JSON.parse(JSON.stringify(x));
function career(s,{officialMatches,finance,catalog,throughDay,prizeDays}){
 const settlement=project(s,{officialMatches});
 check(settlement.participant_order_verified,'Verified participant order required');
 check(Number.isSafeInteger(throughDay)&&throughDay===Math.floor(s.clock.gameSeconds/DAY),'Review must use observed game day');
 check(Array.isArray(finance)&&Array.isArray(catalog)&&prizeDays&&typeof prizeDays==='object','Explicit career inputs required');
 const player=id=>s.source.players.find(x=>x.local===id)?.source;
 const humans=s.config.humanPlayers.map(player);
 check(finance.length===humans.length&&new Set(finance.map(x=>x.player_id)).size===humans.length&&finance.every(x=>humans.includes(x.player_id)),'Complete human finance history required');
 const taxes=[],accounts=[];
 for(const f of finance){
  const tx=settlement.transactions.filter(x=>x.player_id===f.player_id);
  const local=s.source.players.find(x=>x.source===f.player_id).local;
  check(f.balance===(s.config.openingBalances?.[local]??0),'Opening balance mismatch');
  check(Array.isArray(f.transactions)&&Array.isArray(f.settled_periods),'Missing finance history');
  let balance=f.balance;const additions=[];
  for(const t of tx){
   const day=prizeDays[t.idempotency_key],result=settlement.results.find(x=>x.player_id===t.player_id);
   check(Number.isSafeInteger(day)&&day>=f.opening_day&&day<=throughDay&&day<=result.ranking_publish_absolute_day,'Invalid prize game day');
   check(t.balance_before===balance&&!f.transactions.some(x=>x.idempotency_key===t.idempotency_key),'Prize already present or balance conflict');
   const period=require('./career-processing-review.cjs').periodOf(day);
   check(!f.settled_periods.some(x=>x.season===period.season&&x.month===period.month),'Prize would amend settled tax month');
   balance=t.balance_after;additions.push({...t,game_absolute_day:day});
  }
  const plan=taxReview({...f,human:true,through_day:throughDay,balance,transactions:[...f.transactions,...additions]});
  taxes.push({player_id:f.player_id,periods:plan.periods,transactions:plan.transactions});
  accounts.push({player_id:f.player_id,opening_balance:f.balance,gross_prize:additions.reduce((a,x)=>a+x.amount,0),balance_before_tax:balance,balance_after_tax:plan.balance});
 }
 check(Object.keys(prizeDays).length===settlement.transactions.length,'Unexpected prize date mapping');
 const h=s.draw.worldSupport.health;
 check(h&&isDeepStrictEqual(h.catalog,catalog),'Matching frozen injury catalogue required');
 const rolls=[],notices=[];
 const played=settlement.matches.filter(m=>m.completion_reason!=='health_walkover');
 check(h.rolls.length===played.length*2,'Incomplete injury rolls');
 const seen=new Set();
 for(const roll of h.rolls){
  const parts=JSON.parse(roll.match_id),local=parts[1],mid=s.source.matches.find(x=>x.local===local)?.source,pid=player(roll.player_id);
  const ev=s.draw.worldSupport.events.find(x=>x.matchId===local&&x.playerId===roll.player_id);
  const match=played.find(x=>x.match_id===mid);
  check(parts[0]===s.config.competition&&match&&[match.player1_id,match.player2_id].includes(pid)&&ev&&ev.day===roll.absolute_day&&ev.injuryRiskPercent===roll.risk_percent&&roll.absolute_day<=throughDay,'Invalid injury source');
  check(!seen.has(roll.key),'Duplicate injury roll');seen.add(roll.key);
  const original=injuryReview({player_id:roll.player_id,match_id:roll.match_id,absolute_day:roll.absolute_day,risk_percent:roll.risk_percent,catalog}).result;
  check(isDeepStrictEqual(original,roll),'Injury roll mismatch');
  // Source-ID RNG can differ from the synthetic match-ID RNG: expose both, never silently substitute.
  const official=injuryReview({player_id:pid,match_id:mid,absolute_day:roll.absolute_day,risk_percent:roll.risk_percent,catalog}).result;
  const injury=official.injury?recoveryReview(official.injury,throughDay):null;
  rolls.push({player_id:pid,match_id:mid,absolute_day:roll.absolute_day,risk_percent:roll.risk_percent,synthetic_status:roll.status,source_status:official.status,source_roll:official.roll,source_injury:injury,seed_outcome_matches:roll.status===official.status&&(!injury||roll.injury?.injury_code===injury.injury_code)});
  if(injury&&humans.includes(pid)){
   notices.push({player_id:pid,key:'injury:'+pid+':'+mid,code:'player.injury.detected',absolute_day:roll.absolute_day});
   if(injury.status==='recovered')notices.push({player_id:pid,key:'injury-recovered:'+pid+':'+mid,code:'player.injury.recovered',absolute_day:throughDay});
  }
 }
 const ranking=s.ledger.contributions.map(x=>({...x,player:player(x.player)}));
 return copy({schema:'ace-career-settlement-review-v1',review_only:true,production_ready:false,competition_id:settlement.competition_id,through_day:throughDay,taxes,accounts,ranking_contributions:ranking,injury_rolls:rolls,notifications:notices,blockers:['Explicit finance history and prize dates require authoritative verification','Source-ID injury replay uses isolated risk and can differ from synthetic gameplay','No official notification delivery or production career writes']});
}
module.exports={career};
