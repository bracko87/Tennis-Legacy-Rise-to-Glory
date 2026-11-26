'use strict';
// Isolated tournament lifecycle. No database calls. All records and receipts are private.
const a=require('./match-service.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
const error=(message,status=400)=>{const e=Error(message);e.status=status;throw e;};
const time=n=>{if(!Number.isSafeInteger(n)||n<0)error('Invalid clock');return n;};
const key=(s)=>{if(typeof s!=='string'||!(/^[A-Za-z0-9][A-Za-z0-9:_-]{0,79}$/).test(s))error('Invalid resource key');return s;};
const admin=(p,policy)=>{if(!a.canUse(p,policy))error('Forbidden',403);};
function create(now,{courtRestMs=15000,playerRestMs=60000}={}){
 time(now);for(const n of [courtRestMs,playerRestMs])if(!Number.isSafeInteger(n)||n<0||n>86400000)error('Invalid rest policy');
 return {version:1,lastNow:now,courtRestMs,playerRestMs,jobs:[],receipts:[]};
}
function schedule(state,input,principal,policy,now){
 admin(principal,policy);time(now);if(now<state.lastNow)error('Clock moved backwards',409);
 const s=advance(state,now),id=key(input.id),court=key(input.courtKey),startAt=time(input.startAt);
 if(startAt<now||s.jobs.some(j=>j.id===id)||s.jobs.length>=100)error('Invalid or duplicate scheduled match',409);
 if(!Array.isArray(input.playerKeys)||input.playerKeys.length!==2)error('Two player keys required');
 const players=input.playerKeys.map(key);if(players[0]===players[1])error('Duplicate player');
 // Validate and freeze the full match setup now; no games are calculated until admission.
 const fixture=a.createFixture({...input,id,startAt},principal,policy,now);
 s.jobs.push({id,courtKey:court,playerKeys:players,requestedAt:startAt,actualStartAt:null,completedAt:null,fixture,status:'scheduled',...(input.held===true?{held:true}:{})});
 return s;
}
function conflicts(x,y){return {court:x.courtKey===y.courtKey,player:x.playerKeys.some(p=>y.playerKeys.includes(p))};}
function readyAt(s,j,now){
 let at=j.requestedAt;
 for(const x of s.jobs){
  if(x.id===j.id||x.status==='scheduled')continue;
  const c=conflicts(x,j);if(!c.court&&!c.player)continue;
  if(x.status==='live')return Infinity;
  at=Math.max(at,x.completedAt+Math.max(c.court?s.courtRestMs:0,c.player?s.playerRestMs:0));
 }
 return at;
}
function boundary(j){return j.fixture.active?.endAt??j.fixture.nextAt??Infinity;}
function settle(s,j,at){
 if(j.status==='completed')return;
 const f=j.fixture.checkpoint;
 if(f.status!=='completed'||!([0,1].includes(f.winner))||s.receipts.some(x=>x.matchId===j.id))error('Invalid settlement state',409);
 const result={matchId:j.id,winnerKey:j.playerKeys[f.winner],loserKey:j.playerKeys[1-f.winner],score:f.completedSets.map(x=>x.games.join('-')).join(' '),sets:clone(f.completedSets),stats:clone(f.stats),totalPoints:f.totalPoints,totalGames:f.gameNumber,engineVersion:f.version,startedAt:j.actualStartAt,completedAt:at};
 // State and receipt are saved together in one atomic replacement by the caller.
 s.receipts.push(result);j.status='completed';j.completedAt=at;
}
function advance(state,now){
 time(now);if(now<state.lastNow)error('Clock moved backwards',409);
 const s=clone(state);let cursor=s.lastNow;
 for(let loops=0;loops<50000;loops++){
  // Settle all active match boundaries before admitting a new match.
  for(const j of s.jobs.filter(x=>x.status==='live')){
   j.fixture=a.advance(j.fixture,cursor);
   if(j.fixture.checkpoint.status==='completed')settle(s,j,cursor);
  }
  // Deterministic order, including simultaneous starts. Active resources are exclusive.
  const due=s.jobs.filter(j=>j.status==='scheduled'&&!j.held&&j.requestedAt<=cursor).sort((x,y)=>x.requestedAt-y.requestedAt||(x.id<y.id?-1:x.id>y.id?1:0));
  for(const j of due){
   if(readyAt(s,j,cursor)>cursor)continue;
   j.status='live';j.actualStartAt=cursor;
   j.fixture={...j.fixture,startAt:cursor,nextAt:cursor,lastNow:cursor};
   j.fixture=a.advance(j.fixture,cursor);
  }
  if(cursor===now){s.lastNow=now;return s;}
  let next=now;
  for(const j of s.jobs){
   const n=j.status==='live'?boundary(j):j.status==='scheduled'&&!j.held?readyAt(s,j,cursor):Infinity;
   if(n>cursor)next=Math.min(next,n);
  }
  if(next<=cursor)error('Scheduler failed to advance',503);
  cursor=next;
 }
 error('Scheduler event limit; retry from unchanged state',503);
}
function find(s,id){const j=s.jobs.find(j=>j.id===id);if(!j)error('Unknown local match',404);return j;}
function authorized(j,p,policy){if(!p||p.verified!==true||!policy.enabled||!(a.canUse(p,policy)||(policy.multiplayerTest===true&&p.synthetic===true&&p.id===policy.syntheticId&&j.fixture.owners[1]===p.id)))error('Forbidden',403);}
function view(state,id,principal,policy,now){
 const before=find(state,id);authorized(before,principal,policy);
 const s=advance(state,now),j=find(s,id);
 if(j.status==='scheduled')return {id,status:'scheduled',requestedAt:j.requestedAt,delayed:j.requestedAt<=now,actualStartAt:null,players:j.fixture.checkpoint.players.map(p=>({name:p.name})),winner:null};
 return {...a.view(j.fixture,principal,policy,now),requestedAt:j.requestedAt,actualStartAt:j.actualStartAt,completedAt:j.completedAt};
}
function command(state,id,principal,policy,now,action,targetGame,patch){
 const before=find(state,id);authorized(before,principal,policy);
 const s=advance(state,now),j=find(s,id);
 if(j.status!=='live')error('Match not live',409);
 if(action==='heartbeat')j.fixture=a.heartbeat(j.fixture,principal,policy,now);
 else if(action==='coach')j.fixture=a.coach(j.fixture,principal,policy,now,targetGame,patch);
 else error('Unknown command');
 return s;
}
function summary(state,principal,policy,now){
 admin(principal,policy);const s=advance(state,now);
 return {lastNow:s.lastNow,matches:s.jobs.map(j=>({id:j.id,courtKey:j.courtKey,status:j.status,requestedAt:j.requestedAt,actualStartAt:j.actualStartAt,completedAt:j.completedAt,delayed:j.status==='scheduled'&&j.requestedAt<=now})),results:clone(s.receipts)};
}
// Call on a state already advanced to its lastNow.
function nextEventAt(s){
 let next=Infinity;
 for(const j of s.jobs){
  const at=j.status==='live'?boundary(j):j.status==='scheduled'&&!j.held?readyAt(s,j,s.lastNow):Infinity;
  if(at>s.lastNow)next=Math.min(next,at);
 }
 return next;
}
module.exports={create,schedule,advance,view,command,summary,nextEventAt};
