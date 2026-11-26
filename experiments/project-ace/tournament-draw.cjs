'use strict';
// Private, fully seeded-slot singles draw. Not a production draw publisher.
const t=require('./tournament-lifecycle.cjs'),a=require('./match-service.cjs'),e=require('./engine.cjs'),c=require('./career-condition.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
const fail=(m,status=400)=>{const x=Error(m);x.status=status;throw x;};
const admin=(p,policy)=>{if(!a.canUse(p,policy))fail('Forbidden',403);};
const key=x=>{if(typeof x!=='string'||!/^[A-Za-z0-9][A-Za-z0-9_-]{0,39}$/.test(x))fail('Invalid entrant or court key');return x;};
const size=(x,min,max)=>Array.isArray(x)&&x.length>=min&&x.length<=max&&(x.length&(x.length-1))===0;
function create({entrants,mainSlots,qualification=[],courts,startAt,seed=1,surface='hard',mainBestOf=3,pace='standard',roundGapMs=60000,managedPlayer=null,managedMode='hybrid',peerPlayer=null,peerMode='hybrid',worldMode=false},principal,policy,now){
 admin(principal,policy);
 if(!size(mainSlots,2,32)||!Array.isArray(qualification)||qualification.length>16||!Array.isArray(courts)||!courts.length||courts.length>16||!Array.isArray(entrants)||entrants.length>100||!Number.isSafeInteger(startAt)||startAt<=now||!Number.isInteger(seed)||seed<0||seed>4294967295||!['hard','clay','grass'].includes(surface)||![3,5].includes(mainBestOf)||!Object.hasOwn(a.PACES,pace)||!Number.isInteger(roundGapMs)||roundGapMs<1||roundGapMs>86400000)fail('Invalid draw setup');
 const roster=entrants.map(({id,profile})=>{
  key(id);
  // Validate with the real engine and require the career fields used at settlement.
  e.createMatch({players:[profile,profile],surface,version:'ace-context-0.5'});
  for(const k of ['fitness','stamina','recovery','sharpness','morale','confidence','focus'])if(!Number.isFinite(profile[k])||profile[k]<1||profile[k]>100)fail('Missing or invalid career attribute '+k);
  return {id,profile:clone(profile)};
 });
 const ids=roster.map(x=>x.id);
 if(managedPlayer!==null&&(!ids.includes(managedPlayer)||!['manual','hybrid','auto'].includes(managedMode)))fail('Invalid managed player');
 if(peerPlayer!==null&&(!policy.multiplayerTest||typeof policy.syntheticId!=='string'||policy.syntheticId===principal.id||!ids.includes(peerPlayer)||peerPlayer===managedPlayer||!['manual','hybrid','auto'].includes(peerMode)))fail('Invalid peer assignment',403);
 if(new Set(ids).size!==ids.length||new Set(courts.map(key)).size!==courts.length)fail('Duplicate resource');
 const groups=qualification.map(g=>{if(!size(g.players,2,8))fail('Invalid qualifying section');return {id:key(g.id),players:g.players.map(key),winner:null};});
 if(new Set(groups.map(g=>g.id)).size!==groups.length)fail('Duplicate qualifying section');
 const slots=mainSlots.map(s=>typeof s==='string'?{player:key(s)}:{qualifier:key(s?.qualifier)});
 const direct=slots.filter(s=>s.player).map(s=>s.player),refs=slots.filter(s=>s.qualifier).map(s=>s.qualifier);
 const all=[...direct,...groups.flatMap(g=>g.players)];
 if(new Set(all).size!==all.length||all.length!==ids.length||all.some(id=>!ids.includes(id))||refs.length!==groups.length||new Set(refs).size!==refs.length||refs.some(id=>!groups.some(g=>g.id===id))||all.length-1>100)fail('Invalid or duplicate draw slots');
 const s={version:1,kind:'draw',owner:principal.id,...(worldMode===true?{worldMode:true}:{}),managedPlayer,managedMode,peerPlayer,peerMode,peerOwner:peerPlayer===null?null:policy.syntheticId,seed,surface,mainBestOf,pace,roundGapMs,courts:[...courts],roster,slots,groups,phase:groups.length?'qualification':'main_draw',round:1,stage:[],matches:[],conditionEvents:[],processed:[],champion:null,completedAt:null,scheduler:t.create(now,worldMode===true?{courtRestMs:0,playerRestMs:0}:undefined)};
 enqueue(s,groups.length?groups.map(g=>({group:g.id,players:g.players})): [{group:'main',players:direct}],startAt,principal,policy,now);
 return s;
}
const player=(s,id)=>s.roster.find(x=>x.id===id);
function enqueue(s,groups,startAt,principal,policy,now){
 s.stage=[];
 for(const g of groups){
  for(let i=0;i<g.players.length;i+=2){
   const pair=g.players.slice(i,i+2),id='draw-'+(s.matches.length+1);
   const meta={id,phase:s.phase,round:s.round,group:g.group,players:pair,winner:null};
   const seed=(s.seed^Math.imul(s.matches.length+1,2654435761))>>>0;
   const managed=pair.includes(s.managedPlayer),peer=!!s.peerPlayer&&pair.includes(s.peerPlayer);
   const ordered=(managed&&pair[1]===s.managedPlayer||!managed&&peer&&pair[0]===s.peerPlayer)?[pair[1],pair[0]]:pair;
   s.scheduler=t.schedule(s.scheduler,{id,courtKey:s.courts[s.stage.length%s.courts.length],held:s.worldMode===true,playerKeys:ordered,players:ordered.map(p=>player(s,p).profile),startAt,seed,surface:s.surface,bestOf:s.phase==='qualification'?3:s.mainBestOf,pace:s.pace,opponentId:peer?s.peerOwner:null,coachingModes:[managed?s.managedMode:'auto',peer?s.peerMode:'auto']},principal,policy,now);
   s.matches.push(meta);s.stage.push(id);
  }
 }
}
function process(s,principal,policy,now){
 for(const receipt of s.scheduler.receipts){
  if(s.processed.includes(receipt.matchId))continue;
  const m=s.matches.find(x=>x.id===receipt.matchId);
  if(!m||!m.players.includes(receipt.winnerKey))fail('Invalid draw receipt',409);
  m.winner=receipt.winnerKey;
  if(receipt.completionReason==='health_walkover'){
   m.completionReason=receipt.completionReason;
   s.processed.push(m.id);
   continue;
  }
  for(const id of m.players){
   const p=player(s,id),won=id===m.winner;
   let delta=c.apply(p.profile,receipt,won,s.surface);
   if(s.worldSupport)delta=require('./world-career.cjs').complete(s,p,receipt,delta);
   Object.assign(p.profile,delta.after);
   s.conditionEvents.push({matchId:m.id,playerId:id,won,...delta});
  }
  s.processed.push(m.id);
 }
 if(s.champion||!s.stage.length||s.stage.some(id=>!s.matches.find(m=>m.id===id).winner))return;
 const stage=s.stage.map(id=>s.matches.find(m=>m.id===id));
 const winners=[];
 for(const m of stage){let group=winners.find(g=>g.group===m.group);if(!group){group={group:m.group,players:[]};winners.push(group);}group.players.push(m.winner);}
 if(s.phase==='qualification'){
  for(const g of winners)if(g.players.length===1)s.groups.find(x=>x.id===g.group).winner=g.players[0];
  const remaining=winners.filter(g=>g.players.length>1);
  if(remaining.length){s.round++;enqueue(s,remaining,now+s.roundGapMs,principal,policy,now);}
  else{
   if(s.groups.some(g=>!g.winner))fail('Missing qualifier',409);
   s.phase='main_draw';s.round=1;
   enqueue(s,[{group:'main',players:s.slots.map(x=>x.player??s.groups.find(g=>g.id===x.qualifier).winner)}],now+s.roundGapMs,principal,policy,now);
  }
 }else if(winners[0].players.length===1){
  s.champion=winners[0].players[0];s.completedAt=now;s.phase='completed';s.stage=[];
 }else{s.round++;enqueue(s,winners,now+s.roundGapMs,principal,policy,now);}
}
function advance(state,principal,policy,now){
 admin(principal,policy);if(state.owner!==principal.id)fail('Forbidden',403);
 if(!Number.isSafeInteger(now)||now<state.scheduler.lastNow)fail('Invalid clock',409);
 const s=clone(state);let cursor=s.scheduler.lastNow;
 for(let i=0;i<50000;i++){
  s.scheduler=t.advance(s.scheduler,cursor);process(s,principal,policy,cursor);
  if(cursor===now)return s;
  cursor=Math.min(now,t.nextEventAt(s.scheduler));
 }
 fail('Draw event limit',503);
}
function access(s,p,policy){
 if(a.canUse(p,policy)&&p.id===s.owner)return {worker:p,player:s.managedPlayer??null};
 if(policy.enabled&&policy.multiplayerTest===true&&p?.verified===true&&p.synthetic===true&&p.id===policy.syntheticId&&p.id===s.peerOwner&&s.peerPlayer)return {worker:{id:s.owner,verified:true,isAdmin:true},player:s.peerPlayer};
 fail('Forbidden',403);
}
function summary(state,principal,policy,now){
 const accessInfo=access(state,principal,policy),s=advance(state,accessInfo.worker,policy,now);
 return {managedPlayer:accessInfo.player,entrants:s.roster.map(p=>({id:p.id,name:p.profile.name})),phase:s.phase,round:s.round,champion:s.champion,completedAt:s.completedAt,qualifiers:s.groups.map(g=>({id:g.id,winner:g.winner})),matches:s.matches.map(m=>{const j=s.scheduler.jobs.find(x=>x.id===m.id);return {...m,status:j.status,court:j.courtKey,requestedAt:j.requestedAt,actualStartAt:j.actualStartAt,completedAt:j.completedAt};}),results:clone(s.scheduler.receipts),conditions:clone(s.conditionEvents.filter(e=>e.playerId===accessInfo.player))};
}
function matchView(state,id,p,policy,now){
 const info=access(state,p,policy),s=advance(state,info.worker,policy,now);
 const m=s.matches.find(x=>x.id===id);if(!m)fail('Unknown local match',404);
 const managed=!!info.player&&m.players.includes(info.player);
 const v=t.view(s.scheduler,id,managed?p:info.worker,policy,now);
 if(!managed){delete v.ownHistory;delete v.ownPending;delete v.ownTactics;delete v.activeTactics;delete v.recommendations;delete v.opponentOnline;delete v.opponentType;v.coachingMode='auto';v.side=null;}
 if(managed&&v.status!=='scheduled'){const other=m.players.find(id=>id!==info.player);v.opponentType=(other===s.managedPlayer||other===s.peerPlayer)?'human':'ai';if(v.opponentType==='ai')v.opponentOnline=false;}
 return {...v,managed,drawPhase:m.phase,drawRound:m.round};
}
function command(state,id,p,policy,now,action,targetGame,patch){
 const info=access(state,p,policy),s=advance(state,info.worker,policy,now),m=s.matches.find(x=>x.id===id);
 if(!m||!info.player||!m.players.includes(info.player))fail('Not your match',403);
 s.scheduler=t.command(s.scheduler,id,p,policy,now,action,targetGame,patch);
 return s;
}
module.exports={create,advance,summary,matchView,command,access};
