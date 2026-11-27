'use strict';
// Review-only pure proposal from a verified terminal receipt and supplied start snapshot.
// No state write or claim of authoritative source. Uses existing prototype formulas.
const {apply}=require('./career-condition.cjs'),h=require('./career-support.cjs'),{wearUnits}=require('./official-equipment.cjs'),{duration}=require('./schedule-gate.cjs'),{createHash}=require('node:crypto');
const check=(x,m)=>{if(!x)throw Error(m);},copy=x=>JSON.parse(JSON.stringify(x));
const integer=(x,min,max)=>Number.isSafeInteger(x)&&x>=min&&x<=max;
function propose({match,receipt,snapshot}){
 check(match?.status==='completed'&&typeof match.match_id==='string'&&['ace','legacy'].includes(match.owner)&&integer(match.revision,2,Number.MAX_SAFE_INTEGER),'Verified terminal match required');
 check(receipt?.match_id===match.match_id&&receipt.competition_id===match.competition_id&&receipt.player1_id===match.player1_id&&receipt.player2_id===match.player2_id&&receipt.winner_id===match.winner_id&&match.player1_id!==match.player2_id&&[match.player1_id,match.player2_id].includes(match.winner_id),'Receipt identity mismatch');
 check(snapshot?.match_id===match.match_id&&snapshot.competition_id===match.competition_id&&integer(snapshot.start_revision,1,Number.MAX_SAFE_INTEGER)&&snapshot.start_revision+1===match.revision&&integer(snapshot.absolute_day,0,Number.MAX_SAFE_INTEGER)&&['hard','clay','grass'].includes(snapshot.surface),'Start snapshot mismatch');
 check(Array.isArray(snapshot.players)&&snapshot.players.length===2&&snapshot.players.every((x,i)=>x.player_id===[match.player1_id,match.player2_id][i]&&integer(x.career_revision,0,Number.MAX_SAFE_INTEGER)),'Ordered career snapshots required');
 const body={schema:'ace-source-career-proposal-v1',review_only:true,production_ready:false,match_id:match.match_id,competition_id:match.competition_id,match_revision:match.revision,owner:match.owner,snapshot_sha256:createHash('sha256').update(JSON.stringify(snapshot)).digest('hex'),receipt_sha256:createHash('sha256').update(JSON.stringify(receipt)).digest('hex')};
 if(receipt.completion_reason!=null){
  check(['health_walkover','travel_no_show','health_surrender'].includes(receipt.completion_reason)&&receipt.actual_duration_minutes===null&&Array.isArray(receipt.sets)&&receipt.sets.length===0&&Array.isArray(receipt.stats)&&receipt.stats.length===0,'Unsupported non-play receipt');
  return {...body,status:'no_play_no_effects',players:[]};
 }
 check(Array.isArray(receipt.sets)&&[2,3,4,5].includes(receipt.sets.length)&&Array.isArray(receipt.stats)&&receipt.stats.length===2,'Played statistics required');
 check(receipt.sets.every((s,i)=>s.match_id===match.match_id&&s.set_number===i+1&&integer(s.player1_games,0,7)&&integer(s.player2_games,0,7)),'Invalid sets');
 check(receipt.stats.every((s,i)=>s.match_id===match.match_id&&s.player_id===[match.player1_id,match.player2_id][i]&&integer(s.total_points_won,0,10000)),'Invalid ordered statistics');
 const games=receipt.sets.reduce((n,s)=>n+s.player1_games+s.player2_games,0),points=receipt.stats.reduce((n,s)=>n+s.total_points_won,0);
 check(points>=games*4&&receipt.actual_duration_minutes===duration(games,points),'Played duration mismatch');
 const players=snapshot.players.map(x=>{
  const p=x.profile;check(p&&['fatigue','sharpness','morale','confidence','focus','fitness','stamina','recovery','movement'].every(k=>integer(p[k],0,100)),'Invalid career profile');
  const staff=h.staff(x.staff),eligible=h.eligibility(x.injuries,snapshot.absolute_day);check(eligible.eligible,'Medically blocked start');
  const d=apply(p,{totalGames:games,totalPoints:points,sets:receipt.sets},x.player_id===match.winner_id,snapshot.surface),gain=h.adjustedGain(d.gain,staff),after={...d.after,fatigue:Math.min(100,d.before.fatigue+gain)};
  check(Array.isArray(x.inventory)&&x.loadout&&typeof x.loadout==='object','Explicit inventory snapshot required');
  h.resolveGear(x.inventory,x.loadout);
  for(const k of ['racket','shoes','apparel'])check(x.loadout[k]===null||x.inventory.some(i=>i.id===x.loadout[k]&&i.type===k&&i.condition>0),'Invalid loadout');
  const wear=h.wear(x.inventory,x.loadout,wearUnits(x.inventory,x.loadout,snapshot.surface,x.bagProtectionPct??0));
  return {player_id:x.player_id,expected_career_revision:x.career_revision,idempotency_key:'match-career:'+match.match_id+':'+x.player_id,before:d.before,after,fatigue_gain:gain,minutes:d.minutes,equipment_before:copy(x.inventory),equipment_after:wear.inventory,loadout_after:wear.loadout,wear_events:wear.events,injury_risk_percent:h.injuryRisk({...p,...after},{minutes:d.minutes,activeInjuries:eligible.active,support:staff})};
 });
 return {...body,status:'review_proposal',players};
}
module.exports={propose};
