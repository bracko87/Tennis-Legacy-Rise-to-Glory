'use strict';
// Explicit synthetic calendar and reward table for the private world browser.
const w=require('./world-worker.cjs'),c=require('./world-clock.cjs');
function create(draw,p,policy,now){
 const slots=[1,1,2,3,3,4].map((day,i)=>({id:'draw-'+(i+1),phase:i<3?'qualification':'main_draw',week:1,day,minute:600,firstWeek:1,lastWeek:1,court:i===1||i===4?2:1}));
 const rewards=[['winner',250,10000],['runner_up',150,5000],['semifinal',90,2000],['qualifying_final_loss',6,500],['qualifying_round_1_loss',0,250],['qualified_bonus',12,0]].map(([stage_code,ranking_points,prize_money_usd])=>({stage_code,ranking_points,prize_money_usd}));
 const speed=60,game=c.slot(1,1,1,600)-Math.ceil((draw.startAt-now)*speed/1000);
 const inventory=[{id:'r1',type:'racket',condition:21},{id:'r2',type:'racket',condition:85},{id:'s1',type:'shoes',condition:80},{id:'a1',type:'apparel',condition:80}];
 const support={p0:{inventory,loadout:{racket:'r1',shoes:'s1',apparel:'a1'},wearPerMatch:{racket:2,shoes:1,apparel:1},staff:{matchFatigueReduction:.10,injuryReduction:.12},injuries:[]}};
 return w.create({draw,config:{competition:'private-cup-1',series:'private-cup',season:1,lastWeek:1,slots,rewards,openingBalances:{p0:1000,p2:1000}},support},p,policy,{server_now:new Date(now).toISOString(),game_total_seconds:game,speed_multiplier:speed});
}
module.exports={...w,create};
