'use strict';
const assert=require('node:assert/strict'),{freezeQualification}=require('./source-qualification-review.cjs');
function fixture(c='qual-ci'){
 const players=Array.from({length:10},(_,i)=>({id:c+'-p'+i})),matches=[];
 const slot=(draw_type,r,k,p1,p2)=>({id:c+'-'+draw_type+'-'+r+'-'+k,competition_id:c,draw_type,round_number:r,match_number:k,status:'scheduled',started_at:null,completed_at:null,winner_id:null,player1_id:p1,player2_id:p2,scheduled_season_week:draw_type==='qualification'?1:2,scheduled_day:r,scheduled_start_minute:600,court_number:k});
 for(let k=1;k<=2;k++)matches.push(slot('qualification',1,k,players[2*k-2].id,players[2*k-1].id));
 for(let r=1;r<=3;r++)for(let k=1;k<=8/2**r;k++)matches.push(slot('main_draw',r,k,r===1&&k>2?players[2*k].id:null,r===1?players[k<=2?3+k:2*k+1].id:null));
 return {schema:'ace-source-admission-v1',complete_export:true,competition:{id:c,scope:'singles',field_locked:true,qualification_required:true,status:'published',season_number:1,draw_size:8},players,matches,results:[],simulations:[],qualifier_slots:[1,2].map(k=>({match_id:c+'-main_draw-1-'+k,slot:1,qualifier_match_id:c+'-qualification-1-'+k}))};
}
if(require.main===module){
 const input=fixture(),f=freezeQualification(input);assert.equal(f.matches.length,9);assert.equal(f.matches[2].feeder1,f.matches[0].match_id);assert.deepEqual(freezeQualification({...input,matches:[...input.matches].reverse()}),f);
 const bad=JSON.parse(JSON.stringify(input));bad.qualifier_slots[1].qualifier_match_id=bad.qualifier_slots[0].qualifier_match_id;assert.throws(()=>freezeQualification(bad),/mapping/);
 const early=JSON.parse(JSON.stringify(input));early.matches[2].scheduled_season_week=1;assert.throws(()=>freezeQualification(early),/precede/);
 console.log('PASS one-round qualifying inventory, explicit mappings, deterministic source contract and schedule validation');
}
module.exports={fixture};
