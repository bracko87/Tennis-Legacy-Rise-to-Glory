'use strict';
// One private state owns calendar, draw, career support and reward ledger.
// Every mutation returns a new state; caller saves the entire state atomically.
const d=require('./tournament-draw.cjs'),c=require('./world-clock.cjs'),g=require('./schedule-gate.cjs'),l=require('./isolated-settlement.cjs'),h=require('./world-career.cjs'),a=require('./match-service.cjs');
const medical=require('./health-walkover.cjs'),healthLifecycle=require('./health-lifecycle.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
const fail=(m,status=400)=>{const e=Error(m);e.status=status;throw e;};
function create(args,p,policy,raw){
 if(!a.canUse(p,policy))fail('Forbidden',403);
 const clock=c.sample(raw),now=clock.realMs;
 const draw=d.create({...args.draw,worldMode:true},p,policy,now);
 draw.worldSupport=h.validate(args.support,draw.roster.map(p=>p.id),Math.floor(clock.gameSeconds/c.DAY));
 const config=clone(args.config);
 if(!config||typeof config.competition!=='string'||!config.competition||!Array.isArray(config.slots)||config.slots.length!==draw.roster.length-1||!Array.isArray(config.rewards))fail('Invalid world configuration');
 if(config.slots.some((s,i)=>s.id!=='draw-'+(i+1)||!['qualification','main_draw'].includes(s.phase)))fail('Invalid slot sequence');
 for(const s of config.slots){c.slot(config.season,s.week,s.day,s.minute);c.slot(config.season,s.firstWeek,1,0);c.slot(config.season,s.lastWeek,7,0);if(s.firstWeek>s.week||s.lastWeek<s.week||s.lastWeek>config.lastWeek||!Number.isInteger(s.court)||s.court<1||s.court>draw.courts.length)fail('Invalid slot phase or court');}
 const rewards=new Set(config.rewards.map(x=>x.stage_code));
 const required=['winner','runner_up'];
 for(let n=4;n<=draw.slots.length;n*=2)required.push(n===4?'semifinal':n===8?'quarterfinal':'round_'+n);
 if(draw.groups.length){required.push('qualified_bonus','qualifying_final_loss');for(const group of draw.groups)for(let r=1;r<Math.log2(group.players.length);r++)required.push('qualifying_round_'+r+'_loss');}
 if(required.some(x=>!rewards.has(x))||config.rewards.some(x=>!Number.isSafeInteger(x.ranking_points)||x.ranking_points<0||!Number.isSafeInteger(x.prize_money_usd)||x.prize_money_usd<0)||rewards.size!==config.rewards.length)fail('Incomplete or invalid reward table');
 config.humanPlayers=[draw.managedPlayer,draw.peerPlayer].filter(Boolean);
 healthLifecycle.init(draw,config,Math.floor(clock.gameSeconds/c.DAY));
 return {version:1,kind:'world',clock,anchor:clock,draw,config,admissions:[],completed:[],gates:[],ledger:l.create()};
}
function access(s,p,policy){return d.access(s.draw,p,policy);}
function target(s,j){
 const slot=s.config.slots.find(x=>x.id===j.id),m=s.draw.matches.find(x=>x.id===j.id);
 if(!slot||slot.phase!==m.phase)fail('Slot does not match draw phase',409);
 return {...slot,season:s.config.season,competition:s.config.competition,courtCount:s.draw.courts.length,players:[...j.playerKeys],status:'scheduled',feederReady:true};
}
function gateStatus(s,id,status){const prior=s.gates.find(x=>x.id===id);if(prior)prior.status=status;else s.gates.push({id,status});}
function tick(state,raw,p,policy){
 if(!a.canUse(p,policy)||state.draw.owner!==p.id)fail('Forbidden',403);
 const clock=c.sample(raw),now=clock.realMs;
 if(now<state.clock.realMs||clock.gameSeconds<state.clock.gameSeconds||now===state.clock.realMs&&clock.gameSeconds!==state.clock.gameSeconds)fail('Clock rollback or inconsistent sample',409);
 const s=clone(state);s.clock=clock;
 const day=Math.floor(clock.gameSeconds/c.DAY);s.draw.worldSupport.day=day;
 healthLifecycle.recover(s.draw,day);
 s.draw=d.advance(s.draw,p,policy,now);
 for(const r of s.draw.scheduler.receipts)if(!s.completed.some(x=>x.id===r.matchId)){
  const admission=s.admissions.find(x=>x.id===r.matchId);if(!admission)fail('Result without admission',409);
  s.completed.push({...admission,status:'completed',completedGameMinute:Math.floor(clock.gameSeconds/60),durationMinutes:g.duration(r.totalGames,r.totalPoints)});
 }
 const held=s.draw.scheduler.jobs.filter(j=>j.held&&j.status==='scheduled').map(j=>target(s,j)).sort((a,b)=>c.slot(a.season,a.week,a.day,a.minute)-c.slot(b.season,b.week,b.day,b.minute)||a.id.localeCompare(b.id));
 for(const item of held){
  const j=s.draw.scheduler.jobs.find(j=>j.id===item.id);
  if(j.requestedAt>now){gateStatus(s,item.id,'waiting_round_gap');continue;}
  const live=s.admissions.filter(x=>!s.completed.some(y=>y.id===x.id)).map(x=>({...x,status:'live'}));
  const earlier=held.filter(x=>x.id!==item.id&&s.draw.scheduler.jobs.find(j=>j.id===x.id).held&&!['waiting_live_conflict','blocked_injury','blocked'].includes(s.gates.find(g=>g.id===x.id)?.status)).map(x=>({...x,startMinute:c.slot(x.season,x.week,x.day,x.minute)/60}));
  const result=g.plan(item,[...live,...s.completed.filter(x=>x.completionReason!=='health_walkover'),...earlier],clock.gameSeconds,clock.speed);gateStatus(s,item.id,result.status);
  if(result.status==='rescheduled'){Object.assign(s.config.slots.find(x=>x.id===item.id),{week:result.week,day:result.day,minute:result.minute,court:result.court});continue;}
  if(result.status!=='ready')continue;
  if(s.config.medicalWalkovers===true){
   const receipt=medical.resolve(s.draw,j,day,now);
   if(receipt){
    gateStatus(s,item.id,'health_walkover');
    s.completed.push({id:item.id,competition:item.competition,court:result.court,players:item.players,startMinute:result.gameMinute,completedGameMinute:result.gameMinute,status:'completed',durationMinutes:0,completionReason:'health_walkover'});
    continue;
   }
  }
  const health=h.prepare(s.draw,j,day);
  if(health.status!=='ready'){gateStatus(s,item.id,health.status);continue;}
  j.held=false;j.requestedAt=now;j.courtKey=s.draw.courts[result.court-1];
  s.admissions.push({id:item.id,competition:item.competition,court:result.court,players:item.players,startMinute:result.gameMinute,durationMinutes:150});
 }
 s.draw=d.advance(s.draw,p,policy,now);
 s.ledger=l.publish(l.settle(s.ledger,s.draw,s.config),day);
 return s;
}
function sampleAt(s,now){return {server_now:new Date(now).toISOString(),game_total_seconds:c.at(s.anchor,now),speed_multiplier:s.anchor.speed};}
function advance(s,p,policy,now){return tick(s,sampleAt(s,now),p,policy);}
function observed(s,now){if(now!==s.clock.realMs)fail('Fresh world clock tick required',409);}
function summary(s,p,policy,now){
 observed(s,now);
 const who=access(s,p,policy),v=d.summary(s.draw,p,policy,now),player=who.player;
 const game=s.clock.gameSeconds,career=s.draw.worldSupport.players[player];
 return {...v,world:{season:Math.floor(game/(c.DAY*c.SEASON))+1,absoluteDay:Math.floor(game/c.DAY),minute:Math.floor(game/60)%1440,speed:s.clock.speed,synthetic:true},matches:v.matches.map(m=>({...m,gameSlot:s.config.slots.find(x=>x.id===m.id),gate:s.gates.find(x=>x.id===m.id)?.status??'waiting'})),career:{...(s.config.medicalWalkovers===true?{healthNotices:(s.draw.healthNotices??[]).filter(n=>n.playerId===player),...(s.draw.worldSupport.health?{healthRecords:clone(career?.injuries??[])}:{})}:{}),points:l.points(s.ledger,player),results:s.ledger.results.filter(x=>x.player===player),transactions:s.ledger.transactions.filter(x=>x.player===player),balance:s.ledger.balances.find(x=>x.player===player)?.balance??s.config.openingBalances?.[player]??0,condition:s.draw.roster.find(x=>x.id===player)?.profile.fatigue??null,support:career?{inventory:career.inventory,loadout:career.loadout,events:s.draw.worldSupport.events.filter(x=>x.playerId===player)}:null}};
}
function matchView(s,id,p,policy,now){observed(s,now);const v=d.matchView(s.draw,id,p,policy,now);return {...v,gameSlot:s.config.slots.find(x=>x.id===id),gate:s.gates.find(x=>x.id===id)?.status??'waiting'};}
function command(s,id,p,policy,now,action,targetGame,patch){observed(s,now);const next=clone(s);next.draw=d.command(next.draw,id,p,policy,now,action,targetGame,patch);return next;}
module.exports={create,tick,advance,summary,matchView,command,access};
