'use strict';
// Controlled final-match career and reward review. No source mutation or legacy RPC.
const {compare,digest}=require('./shadow-comparison.cjs'),{propose}=require('./source-career-proposal.cjs'),{duration}=require('./schedule-gate.cjs'),{taxReview,injuryReview,recoveryReview,periodOf}=require('./career-processing-review.cjs');
const check=(v,m)=>{if(!v)throw Error(m)},copy=x=>JSON.parse(JSON.stringify(x)),int=(x,min=0,max=Number.MAX_SAFE_INTEGER)=>Number.isSafeInteger(x)&&x>=min&&x<=max;
const {verifySettled}=require('./historical-tax-review.cjs');
const conditions=['fatigue','sharpness','morale','confidence','focus','fitness','stamina','recovery','movement'];
function freezeCareer(input,context){
 check(input?.schema==='ace-shadow-input-v1'&&input.format.draw_type==='main_draw'&&input.snapshot.match.round_label.toLowerCase()==='final','Main final only');
 const c=copy(context);
 check(c&&int(c.absolute_day,0,3659999)&&int(c.through_day,c.absolute_day,3659999)&&int(c.ranking_publish_absolute_day,c.absolute_day,3659999)&&Array.isArray(c.players)&&c.players.length===2&&Array.isArray(c.injury_catalog)&&c.injury_catalog.length>0,'Explicit career and reward context required');
 check(c.rewards&&['winner','runner_up'].every(k=>int(c.rewards[k]?.ranking_points)&&int(c.rewards[k]?.prize_money_usd))&&int(c.rewards.qualified_bonus),'Invalid final reward rules');
 for(let i=0;i<2;i++){
  const p=c.players[i],raw=input.snapshot.players[i];
  check(p.player_id===input.player_ids[i]&&int(p.career_revision)&&typeof p.human==='boolean'&&typeof p.qualified==='boolean','Ordered career identity required');
  check(p.profile&&conditions.every(k=>int(p.profile[k],0,100)&&p.profile[k]===raw.skills[k]),'Career profile differs from frozen match');
  check(Array.isArray(p.inventory)&&p.loadout&&p.staff&&Array.isArray(p.injuries),'Incomplete career state');
  if(!p.human){check(p.finance===null,'AI finance must be absent');continue;}
  const f=p.finance;check(f&&int(f.opening_day,0,c.absolute_day)&&int(f.balance,-Number.MAX_SAFE_INTEGER)&&int(f.tax_rate_basis_points,0,10000)&&Array.isArray(f.transactions)&&f.transactions.length>0&&Array.isArray(f.settled_periods) ,'Complete finance history required');
  let balance=0;const seen=new Set();
  for(const t of f.transactions){
   check(t.player_id===p.player_id&&typeof t.idempotency_key==='string'&&!seen.has(t.idempotency_key)&&int(t.game_absolute_day,f.opening_day,c.absolute_day)&&int(t.amount,-Number.MAX_SAFE_INTEGER)&&typeof t.is_taxable==='boolean'&&t.balance_before===balance&&int(t.balance_after,-Number.MAX_SAFE_INTEGER)&&t.balance_after===balance+t.amount,'Invalid opening finance chain');
   seen.add(t.idempotency_key);balance=t.balance_after;
  }
  check(balance===f.balance&&f.transactions[0].game_absolute_day===f.opening_day&&f.transactions.every((t,j)=>j===0||t.game_absolute_day>=f.transactions[j-1].game_absolute_day),'Finance balance or chronology mismatch');
  verifySettled(p.player_id,f,c.absolute_day);
 }
 const body={schema:'ace-shadow-career-context-v1',input_sha256:input.input_sha256,context:c};
 return {...body,context_sha256:digest(body)};
}
function project(input,result,context){
 const c=context.context,ids=input.player_ids;
 const games=result.sets.reduce((n,s)=>n+s.games[0]+s.games[1],0),points=result.stats.reduce((n,s)=>n+s.total_points_won,0);
 const receipt={match_id:input.match_id,competition_id:input.competition_id,player1_id:ids[0],player2_id:ids[1],winner_id:result.winner_id,status:'completed',sets:result.sets.map((s,i)=>({match_id:input.match_id,set_number:i+1,player1_games:s.games[0],player2_games:s.games[1]})),stats:result.stats.map((s,i)=>({match_id:input.match_id,player_id:ids[i],total_points_won:s.total_points_won})),actual_duration_minutes:duration(games,points)};
 const snapshot={match_id:input.match_id,competition_id:input.competition_id,start_revision:2,absolute_day:c.absolute_day,surface:input.format.surface,players:c.players.map(({player_id,career_revision,profile,inventory,loadout,staff,injuries})=>({player_id,career_revision,profile,inventory,loadout,staff,injuries}))};
 const career=propose({match:{...receipt,owner:'ace',revision:3},receipt,snapshot});
 const players=career.players.map((x,i)=>{
  const p=c.players[i],won=x.player_id===result.winner_id,stage=won?'winner':'runner_up',rule=c.rewards[stage],bonus=p.qualified?c.rewards.qualified_bonus:0;
  const ranking={stage,ranking_points:rule.ranking_points+bonus,qualifying_bonus_points:bonus,prize_money:rule.prize_money_usd,publish_absolute_day:c.ranking_publish_absolute_day,status:'pending'};
  const roll=injuryReview({player_id:p.player_id,match_id:input.match_id,absolute_day:c.absolute_day,risk_percent:x.injury_risk_percent,catalog:c.injury_catalog}).result;
  const injury=roll.injury?recoveryReview(roll.injury,c.through_day):null;
  let finance=null;
  if(p.human){
   const f=p.finance,prize=rule.prize_money_usd,key='tournament-prize:'+input.competition_id+':'+p.player_id;
   check(!f.transactions.some(t=>t.idempotency_key===key),'Prize already posted in opening history');
   const addition=prize>0?[{player_id:p.player_id,idempotency_key:key,amount:prize,game_absolute_day:c.absolute_day,is_taxable:true,balance_before:f.balance,balance_after:f.balance+prize}]:[];
   const tax=taxReview({...f,player_id:p.player_id,human:true,through_day:c.through_day,balance:f.balance+prize,transactions:[...f.transactions,...addition]});
   finance={opening_balance:f.balance,prize_transactions:addition,tax_periods:tax.periods,tax_transactions:tax.transactions,closing_balance:tax.balance};
  }
  return {player_id:p.player_id,won,career_revision:p.career_revision+1,condition:x.after,equipment:x.equipment_after,loadout:x.loadout_after,injury_risk_percent:x.injury_risk_percent,injury_roll:roll,injury_recovery:injury,ranking,finance};
 });
 return {modeled_duration_minutes:receipt.actual_duration_minutes,observed_duration_minutes:result.actual_duration_minutes,players};
}
function differences(a,b,path='',out=[]){
 if(a===b)return out;
 if(a&&b&&typeof a==='object'&&typeof b==='object'&&Array.isArray(a)===Array.isArray(b)){
  for(const k of [...new Set([...Object.keys(a),...Object.keys(b)])].sort())differences(a[k],b[k],path+'/'+k,out);
 }else out.push({path,expected:a===undefined?null:a,observed:b===undefined?null:b,missing_expected:a===undefined,missing_observed:b===undefined});
 return out;
}
function review(input,legacy,context,observation){
 const frozen=freezeCareer(input,context.context);check(digest(frozen)===digest(context),'Career context changed');
 const cmp=compare(input,legacy),ace=project(input,cmp.ace_result,context),legacyOutcome=project(input,legacy,context);
 check(observation?.schema==='ace-shadow-career-observation-v1'&&observation.input_sha256===input.input_sha256&&observation.context_sha256===context.context_sha256&&observation.legacy_observation_sha256===digest(legacy)&&Array.isArray(observation.players)&&observation.players.length===2&&observation.players.every((p,i)=>p.player_id===input.player_ids[i]),'Career observation identity mismatch');
 const expected=legacyOutcome.players,delta=differences(expected,observation.players);
 return {schema:'ace-shadow-career-comparison-v1',review_only:true,production_ready:false,input_sha256:input.input_sha256,context_sha256:context.context_sha256,observation_sha256:digest(observation),winner_agreement:cmp.winner_agreement,ace_outcome:ace,legacy_outcome_replay:legacyOutcome,outcome_differences:differences(ace.players,expected),processing_differences:delta,status:delta.length?'processing_difference_review':'matched_review',legacy_authority_verified:false,limitations:['Model uses Ace duration formula for both outcomes; observed duration retained separately','Final-match scenario only; supplied reward rules and qualified flags not authoritative','Tax requires complete chronological ledger and reconciled historical settlements; late corrections require manual review','Injury source-ID roll and recovery are modeled, not official','Ranking is pending reward proposal, not actual publication']};
}
module.exports={freezeCareer,review,project};
