'use strict';
// Isolated projection of tournament result / finance / ranking contribution contracts.
// Explicit payout and point snapshot, never hardcode or guess a production purse.
const {mondayAfterPhase,nextMonday}=require('./world-clock.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
const money=x=>{if(!Number.isSafeInteger(x)||x<0)throw Error('Invalid nonnegative integer');return x;};
const id=x=>{if(typeof x!=='string'||!x||x.length>120)throw Error('Invalid ledger key');return x;};
function create(){return {version:1,results:[],transactions:[],contributions:[],balances:[],lastPublishedDay:null};}
function settle(state,draw,config){
 const s=clone(state),competition=id(config.competition),series=id(config.series);
 if(!Number.isInteger(config.season)||config.season<1)throw Error('Invalid season');
 const publishDay=nextMonday(mondayAfterPhase(config.season,config.lastWeek));
 if(!Array.isArray(config.rewards)||!Array.isArray(config.humanPlayers))throw Error('Reward snapshot required');
 const rewards=new Map();
 for(const r of config.rewards){if(rewards.has(r.stage_code))throw Error('Duplicate reward stage');rewards.set(id(r.stage_code),{points:money(r.ranking_points),prize:money(r.prize_money_usd)});}
 const terminal=[];
 for(const m of draw.matches){
  if(!m.winner)continue;
  const receipt=draw.scheduler.receipts.find(r=>r.matchId===m.id);
  if(!receipt||receipt.winnerKey!==m.winner||!m.players.includes(receipt.loserKey)||!m.players.includes(m.winner)||receipt.loserKey===m.winner)throw Error('Invalid match receipt');
  if(m.phase==='qualification'){
   const group=draw.groups.find(g=>g.id===m.group);
   const stage=m.round===Math.log2(group.players.length)?'qualifying_final_loss':'qualifying_round_'+m.round+'_loss';
   terminal.push({player:receipt.loserKey,stage,receipt});
  }else{
   const remaining=draw.slots.length/2**(m.round-1);
   const stage=remaining===2?'runner_up':remaining===4?'semifinal':remaining===8?'quarterfinal':'round_'+remaining;
   terminal.push({player:receipt.loserKey,stage,receipt});
   if(remaining===2)terminal.push({player:m.winner,stage:'winner',receipt});
  }
 }
 for(const x of terminal){
  const prior=s.results.find(r=>r.competition===competition&&r.player===x.player);
  const reward=rewards.get(x.stage);if(!reward)throw Error('Missing reward stage '+x.stage);
  const qualified=!x.stage.startsWith('qualifying_')&&draw.groups.some(g=>g.winner===x.player);
  if(qualified&&!rewards.has('qualified_bonus'))throw Error('Missing qualifier bonus rule (explicit zero allowed)');
  const bonus=qualified?rewards.get('qualified_bonus').points:0;
  const row={competition,series,season:config.season,player:x.player,matchId:x.receipt.matchId,stage:x.stage,points:money(reward.points+bonus),bonus,prize:reward.prize,publishDay,status:'pending'};
  if(prior){if(Object.keys(row).some(k=>k!=='status'&&prior[k]!==row[k]))throw Error('Conflicting terminal result');continue;}
  s.results.push(row);
  if(config.humanPlayers.includes(x.player)&&row.prize>0){
   const key='tournament-prize:'+competition+':'+x.player;
   if(s.transactions.some(t=>t.key===key))throw Error('Duplicate finance transaction');
   let account=s.balances.find(b=>b.player===x.player);
   if(!account){account={player:x.player,balance:money(config.openingBalances?.[x.player]??0)};s.balances.push(account);}
   const before=account.balance;account.balance=money(before+row.prize);
   s.transactions.push({key,player:x.player,category:'prize_money',amount:row.prize,balanceBefore:before,balanceAfter:account.balance,taxable:true});
  }
 }
 return s;
}
function publish(state,day){
 money(day);const s=clone(state);if(s.lastPublishedDay!==null&&day<s.lastPublishedDay)throw Error('Publication clock rollback');
 const lastMonday=(()=>{for(let d=day;d>=Math.max(0,day-9);d--)if(nextMonday(d)===d)return d;return null;})();
 if(lastMonday===null)return s;
 const pending=s.results.filter(r=>r.status==='pending'&&r.publishDay<=lastMonday).sort((a,b)=>a.publishDay-b.publishDay||a.season-b.season);
 for(const r of pending){
  const previous=s.contributions.filter(x=>x.player===r.player&&x.series===r.series&&x.active);
  if(previous.some(x=>x.season>=r.season))throw Error('Out-of-order or duplicate edition');
  for(const x of previous){x.active=false;x.reason='replacement';}
  r.status='published';s.contributions.push({competition:r.competition,series:r.series,player:r.player,season:r.season,points:r.points,awardedDay:r.publishDay,expiresDay:r.publishDay+366,active:true});
 }
 for(const x of s.contributions)if(x.active&&x.expiresDay<=lastMonday){x.active=false;x.reason='expiration';}
 s.lastPublishedDay=day;return s;
}
function points(s,player){return s.contributions.filter(x=>x.player===player&&x.active).reduce((a,b)=>a+b.points,0);}
module.exports={create,settle,publish,points};
