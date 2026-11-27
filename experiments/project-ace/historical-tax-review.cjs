'use strict';
// Verify supplied settled periods against the complete opening ledger.
// Historical rates are preserved; late corrections require manual reconciliation.
const {monthStart,periodOf}=require('./career-processing-review.cjs');
const check=(v,m)=>{if(!v)throw Error(m)};
function verifySettled(player,finance,day){
 const {opening_day,transactions,settled_periods}=finance;
 const byKey=new Map(transactions.map(t=>[t.idempotency_key,t])),seen=new Set(),claimed=new Set();
 const start=periodOf(opening_day);
 for(const p of settled_periods){
  check(p.player_id===player&&Number.isSafeInteger(p.season)&&p.season>=1&&Number.isInteger(p.month)&&p.month>=1&&p.month<=12,'Invalid historical tax identity');
  const key=p.season+':'+p.month,due=p.month===12?monthStart(p.season+1,1):monthStart(p.season,p.month+1),begin=monthStart(p.season,p.month);
  check(!seen.has(key)&&due>opening_day&&due<=day&&p.due_absolute_day===due&&Number.isSafeInteger(p.settled_absolute_day)&&p.settled_absolute_day>=due&&p.settled_absolute_day<=day,'Invalid historical tax period');
  seen.add(key);
  check(Number.isFinite(p.tax_rate)&&p.tax_rate>=0&&p.tax_rate<=1&&Math.abs(p.tax_rate*10000-Math.round(p.tax_rate*10000))<1e-8,'Invalid historical tax rate');
  const income=transactions.filter(t=>t.is_taxable&&t.amount>0&&t.game_absolute_day>=begin&&t.game_absolute_day<due).reduce((n,t)=>n+BigInt(t.amount),0n);
  const tax=(income*BigInt(Math.round(p.tax_rate*10000))+5000n)/10000n;
  check(Number.isSafeInteger(p.taxable_income)&&BigInt(p.taxable_income)===income&&Number.isSafeInteger(p.tax_amount)&&BigInt(p.tax_amount)===tax,'Historical taxable income or amount mismatch');
  const id='monthly-tax:'+key;
  if(tax===0n){check(p.transaction_key===null&&!byKey.has(id),'Unexpected zero-tax payment');}
  else{
   const t=byKey.get(id);
   check(p.transaction_key===id&&t&&t.player_id===player&&BigInt(t.amount)===-tax&&t.is_taxable===false&&t.game_absolute_day===due,'Historical tax payment mismatch');
   claimed.add(id);
  }
 }
 for(const t of transactions)if(t.idempotency_key.startsWith('monthly-tax:'))check(claimed.has(t.idempotency_key),'Unlinked historical tax payment');
 // A later settled month must not hide a hole in the earlier settlement sequence.
 let latest=-1;for(const p of settled_periods)latest=Math.max(latest,(p.season-1)*12+p.month-1);
 for(let i=(start.season-1)*12+start.month-1;i<=latest;i++)check(seen.has((Math.floor(i/12)+1)+':'+(i%12+1)),'Missing earlier settled tax period');
 return true;
}
module.exports={verifySettled};
