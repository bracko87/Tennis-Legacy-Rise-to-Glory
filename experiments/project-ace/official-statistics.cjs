'use strict';
// Reconstruct the exact legacy statistics convention from elapsed point events.
// Legacy SQL 20260904145523: aces and double faults are separate; all other
// points are either an unforced error or a winner. Tiebreak points never count
// as break points. This is the legacy simulation convention, not shot tracking.
const check=(ok,msg)=>{if(!ok)throw Error(msg);};
function calculate(events){
 const out=Array.from({length:2},()=>({aces:0,double_faults:0,first_serves_in:0,first_serves_total:0,first_serve_points_won:0,first_serve_points_played:0,second_serve_points_won:0,second_serve_points_played:0,winners:0,unforced_errors:0,total_points_won:0,break_points_won:0,break_points_total:0}));
 let game=0,points=[0,0],tb=false,server=null,ended=true;
 for(const [i,e] of events.entries()){
  check(e.number===i+1&&Number.isInteger(e.game)&&[0,1].includes(e.server)&&[0,1].includes(e.winner)&&['first','ace','df','ue','tiebreak'].every(k=>typeof e[k]==='boolean'),'Invalid point event');
  if(e.game!==game){check(e.game===game+1&&ended,'Invalid game sequence');game=e.game;points=[0,0];tb=e.tiebreak;server=e.server;ended=false;}
  check(!ended&&tb===e.tiebreak&&(tb||e.server===server),'Invalid point game');
  check(Number(e.ace)+Number(e.df)+Number(e.ue)<=1&&(!e.ace||e.first&&e.winner===e.server)&&(!e.df||!e.first&&e.winner!==e.server),'Invalid point classification');
  const r=1-e.server,serv=out[e.server],rec=out[r],won=out[e.winner];
  if(!tb&&points[r]>=3&&points[r]>points[e.server]){rec.break_points_total++;if(e.winner===r)rec.break_points_won++;}
  serv.first_serves_total++;if(e.first){serv.first_serves_in++;serv.first_serve_points_played++;if(e.winner===e.server)serv.first_serve_points_won++;}else{serv.second_serve_points_played++;if(e.winner===e.server)serv.second_serve_points_won++;}
  if(e.ace)serv.aces++;else if(e.df)serv.double_faults++;else if(e.ue)out[1-e.winner].unforced_errors++;else won.winners++;
  won.total_points_won++;points[e.winner]++;
  check(Array.isArray(e.points)&&e.points.length===2&&e.points.every((p,k)=>p===points[k]),'Point score mismatch');
  // For a tiebreak, allow 7 or 10 according to match format (the engine owns this).
  if(!tb&&Math.max(...points)>=4&&Math.abs(points[0]-points[1])>=2)ended=true;
  if(tb&&(i===events.length-1||events[i+1].game!==game)){check(Math.max(...points)>=7&&Math.abs(points[0]-points[1])>=2,'Invalid tiebreak ending');ended=true;}
 }
 check(ended,'Unfinished point sequence');return out;
}
module.exports={calculate};
