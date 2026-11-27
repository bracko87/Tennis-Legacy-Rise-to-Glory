'use strict';
const assert=require('node:assert/strict'),{plan}=require('./cancellation-refund-review.cjs');
const comp='cup',p='p',a={competition:comp,reason:'minimum_field_not_met',entries:[{player_id:p,player_type:'human',has_owner:true},{player_id:'ai',player_type:'ai',has_owner:false}],travelLegs:[{id:'leg',player_id:p,destination_reference_id:comp}],transactions:[{id:'fee',player_id:p,amount:-100,source_id:comp,game_absolute_day:1},{id:'trip',player_id:p,amount:-200,source_type:'travel_leg',source_id:'leg',game_absolute_day:2},{id:'hotel',player_id:p,amount:-150,metadata:{competition_id:comp},game_absolute_day:3},{id:'foreign',player_id:p,amount:-999,source_id:'other',game_absolute_day:3},{id:'ai',player_id:'ai',amount:-100,source_id:comp,game_absolute_day:1}]};
const out=plan(a);assert.deepEqual(out.refunds.map(x=>x.amount),[100,200,150]);assert.ok(out.refunds.every(x=>x.is_taxable===false));
assert.deepEqual(out.notification_player_ids,[p]);assert.deepEqual(plan(a),out);
const prior={id:'refund',player_id:p,amount:100,idempotency_key:'tournament-cancel-refund:cup:fee',game_absolute_day:4};
assert.deepEqual(plan({...a,transactions:[...a.transactions,prior]}).refunds.map(x=>x.amount),[200,150]);
assert.throws(()=>plan({...a,transactions:[...a.transactions,{...prior,amount:99}]}),/Conflicting prior refund/);
console.log('PASS cancellation refund eligibility, direct/metadata/travel links, unrelated and AI exclusion, idempotency and conflict rejection');
