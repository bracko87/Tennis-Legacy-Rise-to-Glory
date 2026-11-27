'use strict';
// Pure review of the legacy cancellation refund contract. No posting or live writes.
const check=(x,m)=>{if(!x)throw Error(m);};
function plan({competition,reason,entries,transactions,travelLegs}){
 check(typeof competition==='string'&&competition.length&&typeof reason==='string'&&reason.length,'Explicit competition and reason required');
 check([entries,transactions,travelLegs].every(Array.isArray),'Complete review inputs required');
 const players=new Set();for(const e of entries){check(typeof e.player_id==='string'&&['human','ai'].includes(e.player_type)&&typeof e.has_owner==='boolean','Invalid entry');if(e.player_type==='human'&&e.has_owner)players.add(e.player_id);}
 const ids=new Set(),keys=new Set();
 for(const t of transactions){check(typeof t.id==='string'&&!ids.has(t.id)&&typeof t.player_id==='string'&&Number.isSafeInteger(t.amount)&&Number.isSafeInteger(t.game_absolute_day)&&t.game_absolute_day>=0,'Invalid transaction');ids.add(t.id);if(t.idempotency_key!=null){const k=JSON.stringify([t.player_id,t.idempotency_key]);check(!keys.has(k),'Duplicate finance key');keys.add(k);}}
 const legs=new Map();for(const l of travelLegs){check(typeof l.id==='string'&&typeof l.player_id==='string'&&!legs.has(l.id),'Invalid travel leg');legs.set(l.id,l);}
 const refunds=[];
 for(const t of [...transactions].sort((a,b)=>a.game_absolute_day-b.game_absolute_day||a.id.localeCompare(b.id))){
  if(!players.has(t.player_id)||t.amount>=0)continue;
  const l=t.source_type==='travel_leg'?legs.get(t.source_id):null;
  if(t.source_id!==competition&&t.metadata?.competition_id!==competition&&!(l&&l.player_id===t.player_id&&(l.destination_reference_id===competition||l.source_reference_id===competition)))continue;
  const key='tournament-cancel-refund:'+competition+':'+t.id;
  const prior=transactions.find(x=>x.player_id===t.player_id&&x.idempotency_key===key);
  if(prior){check(prior.amount===-t.amount,'Conflicting prior refund');continue;}
  refunds.push({player_id:t.player_id,amount:-t.amount,category:'refund',subcategory:'tournament_cancellation',source_type:'tournament_cancellation',source_id:competition,idempotency_key:key,is_taxable:false,metadata:{competition_id:competition,original_transaction_id:t.id,reason_code:reason,original_amount:t.amount}});
 }
 return {review_only:true,production_ready:false,competition_id:competition,refunds,travel_rebuild_player_ids:[...players].sort(),notification_player_ids:[...players].sort()};
}
module.exports={plan};
