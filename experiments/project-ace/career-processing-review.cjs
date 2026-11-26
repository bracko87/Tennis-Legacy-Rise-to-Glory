'use strict';
// Review proposals only. Mirrors checked-in monthly tax and injury selection SQL.
// Never calls a production RPC or alters a world, account or injury record.
const {createHash}=require('node:crypto');
const {isDeepStrictEqual}=require('node:util');
const ensure=(ok,msg)=>{if(!ok)throw Error(msg);};
const int=(x,min=0,max=Number.MAX_SAFE_INTEGER)=>{ensure(Number.isSafeInteger(x)&&x>=min&&x<=max,'Invalid integer');return x;};
const str=x=>{ensure(typeof x==='string'&&x.length>0&&x.length<=256,'Invalid identifier');return x;};
const dec=(x,min,max)=>{ensure(typeof x==='number'&&Number.isFinite(x)&&x>=min&&x<=max,'Invalid decimal');return x;};
const clone=x=>JSON.parse(JSON.stringify(x));
const offsets=[0,31,60,91,121,152,182,213,244,274,305,335,366];
function monthStart(season,month){return (int(season,1,10000)-1)*366+offsets[int(month,1,12)-1];}
function periodOf(day){int(day,0,3660000-1);const season=Math.floor(day/366)+1,d=day%366;return {season,month:offsets.findIndex(x=>x>d)};}
function due(season,month){return month===12?monthStart(season+1,1):monthStart(season,month+1);}
function taxReview({player_id,human,opening_day,through_day,balance,tax_rate_basis_points,transactions,settled_periods}){
 str(player_id);ensure(human===true,'Human career required');int(opening_day);int(through_day,opening_day,3659999);int(balance,-Number.MAX_SAFE_INTEGER);int(tax_rate_basis_points,0,10000);
 ensure(Array.isArray(transactions)&&Array.isArray(settled_periods),'Explicit complete finance history required');
 const keys=new Set();
 for(const t of transactions){ensure(t.player_id===player_id,'Foreign finance row');str(t.idempotency_key);ensure(!keys.has(t.idempotency_key),'Duplicate transaction');keys.add(t.idempotency_key);int(t.amount,-Number.MAX_SAFE_INTEGER);int(t.game_absolute_day,opening_day,through_day);ensure(typeof t.is_taxable==='boolean','Tax flag required');}
 ensure(transactions.length>0&&Math.min(...transactions.map(x=>x.game_absolute_day))===opening_day,'Opening history missing');
 const periods=new Set();
 for(const p of settled_periods){ensure(p.player_id===player_id,'Foreign tax period');const key=p.season+':'+p.month;ensure(!periods.has(key),'Duplicate tax period');periods.add(key);ensure(p.due_absolute_day===due(p.season,p.month)&&p.due_absolute_day<=through_day,'Invalid settled period');}
 const rows=[],payments=[];let nextBalance=balance;const start=periodOf(opening_day),last=periodOf(through_day);
 for(let s=start.season;s<=last.season;s++)for(let m=s===start.season?start.month:1;m<=12;m++){
  const d=due(s,m),key=s+':'+m;if(d>through_day||d<=opening_day||periods.has(key))continue;
  const income=transactions.filter(t=>t.is_taxable&&t.amount>0&&t.game_absolute_day>=monthStart(s,m)&&t.game_absolute_day<d).reduce((sum,t)=>sum+BigInt(t.amount),0n);
  const amount=Number((income*BigInt(tax_rate_basis_points)+5000n)/10000n);int(amount);int(Number(income));
  const id='monthly-tax:'+s+':'+m;ensure(!keys.has(id),'Tax transaction exists without settled period');
  rows.push({player_id,season:s,month:m,taxable_income:Number(income),tax_rate:tax_rate_basis_points/10000,tax_amount:amount,due_absolute_day:d,settled_absolute_day:through_day,transaction_key:amount>0?id:null});
  if(amount>0){const before=nextBalance;nextBalance=int(before-amount,-Number.MAX_SAFE_INTEGER);payments.push({player_id,amount:-amount,category:'tax',subcategory:'monthly_income_tax',source_type:'career_tax',source_id:s+'-'+m,idempotency_key:id,is_taxable:false,game_absolute_day:d,balance_before:before,balance_after:nextBalance});}
 }
 return {review_only:true,periods:rows,transactions:payments,balance:nextBalance};
}
// SQL match_engine_random_v1: first 32 bits of MD5 / 2^32.
function random(seed,index){return parseInt(createHash('md5').update(seed+':'+index).digest('hex').slice(0,8),16)/4294967296;}
function injuryReview({player_id,match_id,absolute_day,risk_percent,catalog,prior_rolls=[]}){
 str(player_id);str(match_id);int(absolute_day);dec(risk_percent,0,7.5);
 ensure(Array.isArray(catalog)&&Array.isArray(prior_rolls),'Explicit injury catalogue and history required');
 const key='match-injury:'+player_id+':'+match_id,seed=player_id+':match:'+match_id;
 const rows=catalog.filter(c=>c.is_active===true&&Array.isArray(c.contexts)&&c.contexts.includes('match')).sort((a,b)=>a.code<b.code?-1:a.code>b.code?1:0);
 ensure(rows.length>0&&new Set(rows.map(c=>c.code)).size===rows.length,'Invalid match injury catalogue');
 for(const c of rows){str(c.code);str(c.treatment_code);ensure(['minor','moderate','major','severe'].includes(c.severity),'Invalid severity');dec(c.relative_weight,0,1000);dec(c.base_performance_penalty,0,1);dec(c.aggravation_risk,0,1);for(const f of ['training_out','tournament_out','recovery']){int(c[f+'_min_days'],0,3660);int(c[f+'_max_days'],c[f+'_min_days'],3660);}}
 const total=rows.reduce((a,c)=>a+c.relative_weight,0);ensure(total>0,'No weighted injury options');
 const roll=random(seed+':injury',1)*100;let injury=null;
 if(roll<risk_percent){
  const pick=random(seed+':type',2)*Math.max(total,1);let running=0,selected=rows.at(-1);
  for(const c of rows){running+=c.relative_weight;if(pick<=running){selected=c;break;}}
  const days=(f,suffix,index)=>selected[f+'_min_days']+Math.floor(random(seed+':'+suffix,index)*(selected[f+'_max_days']-selected[f+'_min_days']+1));
  injury={player_id,injury_code:selected.code,severity:selected.severity,source_type:'match',source_reference_id:match_id,onset_absolute_day:absolute_day,training_return_absolute_day:absolute_day+days('training_out','train',3),tournament_return_absolute_day:absolute_day+days('tournament_out','tour',4),expected_full_recovery_absolute_day:absolute_day+days('recovery','recovery',5),status:'active',performance_penalty:selected.base_performance_penalty,aggravation_risk:selected.aggravation_risk,treatment_code:selected.treatment_code};
 }
 const result={key,review_only:true,player_id,match_id,absolute_day,risk_percent,roll,status:injury?'injured':'clear',injury};
 const prior=prior_rolls.filter(x=>x.key===key);ensure(prior.length<=1,'Duplicate injury history');if(prior.length){ensure(isDeepStrictEqual(prior[0],result),'Conflicting injury roll');return {status:'already_processed',result:clone(prior[0])};}
 return {status:result.status,result};
}
function recoveryReview(injury,day){
 int(day,injury.onset_absolute_day);const i=clone(injury);if(!['active','recovering'].includes(i.status))return i;
 const end=int(i.expected_full_recovery_absolute_day,i.onset_absolute_day);
 if(day>=end)return {...i,status:'recovered',progress_percent:100,recovered_absolute_day:day};
 return {...i,status:day>i.onset_absolute_day?'recovering':i.status,progress_percent:Math.min(99,Math.max(0,Math.round(100*(day-i.onset_absolute_day)/Math.max(1,end-i.onset_absolute_day))))};
}
module.exports={taxReview,injuryReview,recoveryReview,random,monthStart,periodOf};
