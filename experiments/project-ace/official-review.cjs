'use strict';
// Input is an explicitly supplied, normalized export; never queries production.
const w=require('./world-worker.cjs'),c=require('./world-clock.cjs'),{importPlayer}=require('./legacy-snapshot.cjs');
const key=(x)=>{if(typeof x!=='string'||!x.trim()||x.length>120)throw Error('Invalid source identifier');return x;};
const list=(x)=>{if(!Array.isArray(x))throw Error('Missing snapshot array');return x;};
const num=(x)=>{if(!Number.isSafeInteger(x)||x<0)throw Error('Invalid reward or balance');return x;};
function create(raw,p,policy,clock,{managedSourceId,peerSourceId=null,pace='standard',seed=1}={}){
 if(raw?.schema!=='ace-official-review-v1')throw Error('Invalid official review snapshot');
 const t=raw.competition;if(!t||!['atp','wta'].includes(t.world)||!['hard','clay','grass'].includes(t.surface)||!t.category_code)throw Error('Invalid competition');
 const season=t.season_number,series=key(t.tournament_series_id),competition=key(t.id);
 const map=new Map(),support={},openingBalances={};
 const entrants=list(raw.players).map((row,i)=>{
  const source=key(row.player.id),id='p'+i;if(map.has(source))throw Error('Duplicate source player');map.set(source,id);
  const managed=source===managedSourceId||source===peerSourceId;
  if(!['human','ai'].includes(row.player.player_type)||managed!==(row.player.player_type==='human'))throw Error('Only explicitly assigned human entrants supported');
  if(managed){
   const e=row.career;if(!e||!e.staff_effects||!e.loadout||!Array.isArray(e.inventory)||!Array.isArray(e.injuries))throw Error('Incomplete human career snapshot');
   openingBalances[id]=num(e.balance);
   const inventory=e.inventory.filter(i=>['racket','shoes','apparel'].includes(i.item_type)).map(i=>({id:key(i.id),type:i.item_type,condition:i.condition,wear_per_match:i.wear_per_match,surface:i.surface,wrong_surface_wear_multiplier:i.wrong_surface_wear_multiplier}));
   const loadout=Object.fromEntries(['racket','shoes','apparel'].map(k=>[k,e.loadout[k+'_inventory_id']??null]));
   for(const [k,v] of Object.entries(loadout))if(v!==null&&!inventory.some(x=>x.id===v&&x.type===k))throw Error('Foreign or mismatched loadout');
   support[id]={inventory,loadout,catalogWear:true,surface:t.surface,bagProtectionPct:e.racket_wear_reduction_pct??0,staff:{matchFatigueReduction:e.staff_effects.match_fatigue_reduction,injuryReduction:e.staff_effects.injury_prevention_reduction},injuries:e.injuries.map(i=>({status:i.status,tournamentReturnDay:i.tournament_return_absolute_day,fullRecoveryDay:i.expected_full_recovery_absolute_day}))};
  }
  return {id,profile:importPlayer(row,t.surface)};
 });
 const player=x=>{if(!map.has(x))throw Error('Unknown source player');return map.get(x);};
 const managedPlayer=player(managedSourceId),peerPlayer=peerSourceId===null?null:player(peerSourceId);
 const mainSlots=list(raw.main_slots).map(x=>typeof x==='string'?player(x):{qualifier:key(x.qualifier)});
 const qualification=list(raw.qualification).map(x=>({id:key(x.id),players:list(x.players).map(player)}));
 const stages=[];
 for(let round=1;qualification.some(g=>g.players.length/2**round>=1);round++)for(const g of qualification)for(let i=0;i<g.players.length/2**round;i++)stages.push({phase:'qualification',round,group:g.id});
 for(let round=1;mainSlots.length/2**round>=1;round++)for(let i=0;i<mainSlots.length/2**round;i++)stages.push({phase:'main_draw',round,group:'main'});
 const rows=list(raw.match_slots);
 if(rows.length!==stages.length||new Set(rows.map(x=>key(x.id))).size!==rows.length)throw Error('Incomplete schedule');
 const slots=rows.map((m,i)=>{
  if(m.status!=='scheduled'||m.draw_type!==stages[i].phase||m.round_number!==stages[i].round||m.section!==stages[i].group||m.competition_id!==competition)throw Error('Unsupported or mismatched match schedule');
  return {id:'draw-'+(i+1),phase:m.draw_type,week:m.scheduled_season_week,day:m.scheduled_day,minute:m.scheduled_start_minute,firstWeek:m.phase_first_week,lastWeek:m.phase_last_week,court:m.court_number};
 });
 const payouts=new Map(),points=new Map();
 for(const row of list(raw.prize_payouts)){if(row.tournament_series_id!==series||payouts.has(row.stage_code))throw Error('Wrong or duplicate payout rule');payouts.set(key(row.stage_code),num(row.payout_per_player_usd));}
 for(const row of list(raw.ranking_rules)){if(row.category_code!==t.category_code||points.has(row.stage_code))throw Error('Wrong or duplicate point rule');points.set(key(row.stage_code),num(row.points));}
 const rewards=[...points].map(([stage_code,ranking_points])=>{if(stage_code!=='qualified_bonus'&&!payouts.has(stage_code))throw Error('Explicit payout missing for '+stage_code);return {stage_code,ranking_points,prize_money_usd:stage_code==='qualified_bonus'?0:payouts.get(stage_code)};});
 if(!Number.isInteger(t.court_count)||t.court_count<1||t.court_count>16)throw Error('Unsupported court count');
 const startAt=c.sample(clock).realMs+1;
 const state=w.create({draw:{entrants,mainSlots,qualification,courts:Array.from({length:t.court_count},(_,i)=>'court-'+(i+1)),startAt,seed,surface:t.surface,pace,mainBestOf:t.world==='atp'&&t.category_code==='grand_slam_2000'?5:3,managedPlayer,peerPlayer},config:{competition,series,season,lastWeek:t.last_week,slots,rewards,openingBalances},support},p,policy,clock);
 // Keep source identifiers private and preserve exact mapping for later official-result contract.
 state.source={schema:raw.schema,players:[...map].map(([source,local])=>({source,local})),matches:rows.map((m,i)=>({source:m.id,local:'draw-'+(i+1)}))};
 return state;
}
function receipts(s){
 if(s.source?.schema!=='ace-official-review-v1')throw Error('Not an official review world');
 const player=id=>{const x=s.source.players.find(x=>x.local===id);if(!x)throw Error('Missing player mapping');return x.source;};
 return s.draw.scheduler.receipts.map(r=>{
  const m=s.source.matches.find(x=>x.local===r.matchId);if(!m)throw Error('Missing match mapping');
  return {match_id:m.source,competition_id:s.config.competition,winner_id:player(r.winnerKey),loser_id:player(r.loserKey),score:r.score,total_points:r.totalPoints,total_games:r.totalGames,engine_version:r.engineVersion,completed_at:new Date(r.completedAt).toISOString(),review_only:true};
 });
}
module.exports={create,receipts};
