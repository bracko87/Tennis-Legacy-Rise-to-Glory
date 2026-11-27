'use strict';
const assert=require('node:assert/strict'),{freezeQualification}=require('./source-qualification-review.cjs');
function fixture(c='qual-ci',qr=1){
 const n=2,qn=n*2**qr,players=Array.from({length:qn+6},(_,i)=>({id:c+'-p'+i})),matches=[];
 const slot=(draw_type,r,k,p1,p2)=>({id:c+'-'+draw_type+'-'+r+'-'+k,competition_id:c,draw_type,round_number:r,match_number:k,status:'scheduled',started_at:null,completed_at:null,winner_id:null,player1_id:p1,player2_id:p2,scheduled_season_week:draw_type==='qualification'?1:2,scheduled_day:r,scheduled_start_minute:600,court_number:k});
 for(let r=1;r<=qr;r++)for(let k=1;k<=n*2**(qr-r);k++)matches.push(slot('qualification',r,k,r===1?players[2*k-2].id:null,r===1?players[2*k-1].id:null));
 for(let r=1;r<=3;r++)for(let k=1;k<=8/2**r;k++)matches.push(slot('main_draw',r,k,r===1&&k>2?players[qn+2*k-4].id:null,r===1?players[qn+(k<=2?k-1:2*k-3)].id:null));
 return {schema:'ace-source-admission-v1',complete_export:true,competition:{id:c,scope:'singles',field_locked:true,qualification_required:true,qualification_rounds:qr,status:'published',season_number:1,draw_size:8},players,matches,results:[],simulations:[],qualifier_slots:[1,2].map(k=>({match_id:c+'-main_draw-1-'+k,slot:1,qualifier_match_id:c+'-qualification-'+qr+'-'+k}))};
}
if(require.main===module){
 const input=fixture(),f=freezeQualification(input);assert.equal(f.matches.length,9);assert.equal(f.matches[2].feeder1,f.matches[0].match_id);assert.deepEqual(freezeQualification({...input,matches:[...input.matches].reverse()}),f);
 const bad=JSON.parse(JSON.stringify(input));bad.qualifier_slots[1].qualifier_match_id=bad.qualifier_slots[0].qualifier_match_id;assert.throws(()=>freezeQualification(bad),/mapping/);
 const early=JSON.parse(JSON.stringify(input));early.matches[2].scheduled_season_week=1;assert.throws(()=>freezeQualification(early),/precede/);
 for(const qr of [2,3]){const input=fixture('multi-'+qr,qr),f=freezeQualification(input);assert.equal(f.matches.length,7+2*(2**qr-1));const bad=JSON.parse(JSON.stringify(input));bad.qualifier_slots[0].qualifier_match_id=bad.matches[0].id;assert.throws(()=>freezeQualification(bad),/mapping/);const early=JSON.parse(JSON.stringify(input));early.matches.find(m=>m.draw_type==='qualification'&&m.round_number===2).scheduled_day=1;assert.throws(()=>freezeQualification(early),/precede/);}
 console.log('PASS one- to three-round qualifying inventory, explicit mappings, deterministic source contract and schedule validation');
}
module.exports={fixture};
