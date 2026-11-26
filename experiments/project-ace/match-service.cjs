'use strict';
// Isolated match service. Trusted principals must be supplied by the server auth adapter.
// The serialized record is private, never a client response. One writer per fixture required.
const engine=require('./engine.cjs');
const {recommendations}=require('./analysis.cjs');
const copy=x=>JSON.parse(JSON.stringify(x));
const fail=(message,status)=>{const e=Error(message);e.status=status;throw e;};
const modes=['manual','auto','hybrid'];
const POINT_MS=2000, BREAK_MS=5000, PRESENCE_MS=30000;
const PACES=Object.freeze({standard:Object.freeze({pointMinMs:4000,pointMaxMs:7000,breakMs:5000}),fast:Object.freeze({pointMs:2000,breakMs:5000}),balanced:Object.freeze({pointMs:4000,breakMs:12000}),coaching:Object.freeze({pointMs:6000,breakMs:20000}),extended:Object.freeze({pointMs:8000,breakMs:30000})});
const paceFor=r=>PACES[r.pace??'fast'];
// Independent timing stream: never consume the simulation RNG or use point outcomes.
function pointDelay(r,number){
 const pace=paceFor(r);if(pace.pointMs!==undefined)return pace.pointMs;
 let x=(r.timingSeed^Math.imul(number,0x9e3779b1))>>>0;
 x=Math.imul(x^(x>>>16),0x85ebca6b)>>>0;
 x=Math.imul(x^(x>>>13),0xc2b2ae35)>>>0;
 x=(x^(x>>>16))>>>0;
 return pace.pointMinMs+1000*(x%4);
}
function pointAt(r,index){
 return r.active.revealAt?.[index]??(r.active.startAt+(index+1)*paceFor(r).pointMs);
}
function canUse(principal,policy){
 return !!(policy.enabled && principal && principal.verified===true && principal.isAdmin===true && principal.id===policy.adminId);
}
function sideFor(record,principal,policy){
 if(!policy.enabled||!principal||principal.verified!==true)fail('Forbidden',403);
 const side=record.owners.indexOf(principal.id);
 if(side<0)fail('Forbidden',403);
 if(canUse(principal,policy))return side;
 if(policy.multiplayerTest===true&&principal.synthetic===true&&principal.id===policy.syntheticId&&side===1)return side;
 fail('Forbidden',403);
}
function time(n){if(!Number.isSafeInteger(n)||n<0)fail('Invalid time',400);return n;}
function createFixture({id,players,seed,startAt,opponentId=null,surface='hard',pace='fast',coachingModes=['hybrid','auto']},principal,policy,now){
 if(!canUse(principal,policy))fail('Forbidden',403);
 if(!Object.hasOwn(PACES,pace))fail('Invalid match pace',400);
 time(now);time(startAt);if(startAt<now)fail('Start is in past',400);
 if(typeof id!=='string'||!id||!Array.isArray(coachingModes)||coachingModes.length!==2||coachingModes.some(m=>!modes.includes(m)))fail('Invalid fixture',400);
 if(opponentId!==null&&(!policy.multiplayerTest||opponentId!==policy.syntheticId||opponentId===principal.id))fail('Forbidden opponent',403);
 if(opponentId===null&&coachingModes[1]!=='auto')fail('AI must use automatic coaching',400);
 return {id,pace,timingSeed:(seed^0xa53c9e71)>>>0,owners:[principal.id,opponentId],modes:[...coachingModes],lastSeen:[null,null],lastNow:now,startAt,nextAt:startAt,checkpoint:engine.createMatch({players,seed,surface,version:'ace-tactical-0.4'}),active:null,queued:[null,null],applied:[null,null],revision:0};
}
function ai(s,i){
 const base=engine.observable(s);
 const result={approach:'Balanced',rally:'Balanced rallies',serve:'Balanced',returnGame:'Balanced',target:'Automatic'};
 for(const advice of recommendations(base.players,base.stats,i,base.totalPoints))Object.assign(result,advice.patch);
 return result;
}
function startGame(r,at){
 let s=r.checkpoint;
 for(let i=0;i<2;i++){
  const online=r.lastSeen[i]!==null&&r.lastSeen[i]<=at&&at-r.lastSeen[i]<=PRESENCE_MS;
  const auto=r.modes[i]==='auto'||(r.modes[i]==='hybrid'&&!online);
  const patch=r.queued[i]|| (auto?ai(s,i):null);
  if(patch){s=engine.queueTactics(s,i,patch);r.applied[i]={game:s.gameNumber+1,tactics:{...s.tactics[i],...patch}};}
  r.queued[i]=null;
 }
 const after=engine.stepGame(s),events=after.events.slice(s.events.length);
 const points=events.filter(e=>e.kind==='point');
 let endAt=at;
 const revealAt=points.map(e=>endAt+=pointDelay(r,e.number));
 r.active={startAt:at,endAt,after,points,revealAt};
 r.nextAt=null;r.revision++;
}
function advance(record,now){
 time(now);if(now<record.lastNow)fail('Clock moved backwards',409);
 const r=copy(record);r.lastNow=now;
 for(let loop=0;loop<1000;loop++){
  if(r.active){
   if(now<r.active.endAt)return r;
   const end=r.active.endAt;r.checkpoint=r.active.after;r.active=null;r.revision++;
   if(r.checkpoint.status==='completed'){r.nextAt=null;return r;}
   r.nextAt=end+paceFor(r).breakMs;
  }
  if(r.checkpoint.status==='completed'||r.nextAt===null||now<r.nextAt)return r;
  startGame(r,r.nextAt);
 }
 fail('Advance safety limit',503);
}
function heartbeat(record,principal,policy,now){
 const side=sideFor(record,principal,policy),r=advance(record,now);
 r.lastSeen[side]=now;return r;
}
function coach(record,principal,policy,now,targetGame,patch){
 const side=sideFor(record,principal,policy),r=advance(record,now);
 if(r.checkpoint.status==='completed')fail('Match completed',409);
 if(r.modes[side]==='auto')fail('Automatic coaching mode',409);
 const expected=r.checkpoint.gameNumber+(r.active?2:1);
 if(targetGame!==expected)fail('Stale coaching window',409);
 // Validate without modifying the current checkpoint or opponent's tactics.
 engine.queueTactics(r.checkpoint,side,patch);
 r.queued[side]={...r.queued[side],...patch};r.lastSeen[side]=now;r.revision++;return r;
}
function cleanEvent(e){
 if(e.kind==='tactics')return null;
 const {probability,conditions,...safe}=e;return safe;
}
function view(record,principal,policy,now){
 const side=sideFor(record,principal,policy),r=advance(record,now),s=r.checkpoint;
 const base=engine.observable(s);
 const visible=r.active?r.active.points.filter((_,i)=>pointAt(r,i)<=now):[];
 // Use only revealed point results to update statistics and conditions.
 for(const e of visible){const st=base.stats[e.server];st.servicePoints++;if(e.first)st.firstIn++;if(e.ace)st.aces++;if(e.df)st.doubleFaults++;if(e.ue)base.stats[1-e.winner].unforcedErrors++;base.stats[e.winner].points++;}
 const events=[...base.events,...visible].map(cleanEvent).filter(Boolean);
 const last=visible[visible.length-1];
 const players=copy(last?.conditions||base.players);
 const recent=events.filter(e=>e.kind==='point').slice(-12);
 for(let i=0;i<2;i++)players[i].momentum=recent.length?100*recent.filter(e=>e.winner===i).length/recent.length:50;
 const ownHistory=[...s.events,...(r.active?r.active.after.events.slice(s.events.length).filter(e=>e.kind==='tactics'):[])].filter(e=>e.kind==='tactics'&&e.side===side).map(e=>({game:e.game,tactics:copy(e.tactics)}));
 const tb=!!r.active&&s.games[0]===6&&s.games[1]===6;
 const n=visible.length,server=r.active?(tb&&n>0?(Math.floor((n-1)/2)%2===0?1-s.nextServer:s.nextServer):s.nextServer):null;
 const timing=paceFor(r);
 const nextPointAt=r.active?pointAt(r,visible.length):null;
 // Never expose the hidden game end timestamp or the number of unrevealed points.
 const nextGameAt=r.active?null:r.nextAt;
 return {id:r.id,side,engineVersion:s.version,pace:r.pace??'fast',pointMs:timing.pointMs??null,pointMinMs:timing.pointMinMs??timing.pointMs,pointMaxMs:timing.pointMaxMs??timing.pointMs,breakMs:timing.breakMs,serverNow:now,nextPointAt,nextGameAt,surface:s.surface,opponentType:r.owners[1]?'human':'ai',opponentOnline:r.owners[1]!==null&&r.lastSeen[1-side]!==null&&now-r.lastSeen[1-side]<=PRESENCE_MS,revision:r.revision,status:s.status==='completed'?'completed':now<r.startAt?'scheduled':'live',startAt:r.startAt,gameNumber:s.gameNumber+(r.active?1:0),sets:base.sets,games:base.games,points:last?last.points:[0,0],tiebreak:tb,server,phase:s.status==='completed'?'completed':now<r.startAt?'scheduled':r.active?'playing':'between-games',completedSets:base.completedSets,winner:base.winner,players,stats:base.stats,recommendations:s.status==='completed'?[]:recommendations(players,base.stats,side,base.totalPoints+visible.length),ownHistory,activeTactics:copy(r.applied[side]?.tactics||s.tactics[side]),totalPoints:base.totalPoints+visible.length,events,ownTactics:copy(r.applied[side]),ownPending:copy(r.queued[side]),coachingMode:r.modes[side],nextCoachingGame:s.status==='completed'?null:s.gameNumber+(r.active?2:1)};
}
module.exports={createFixture,advance,heartbeat,coach,view,canUse,POINT_MS,BREAK_MS,PACES};
