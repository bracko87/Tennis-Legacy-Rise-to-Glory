'use strict';
// Project Ace v0.1: isolated synthetic singles POC. No database, clock, or production imports.
const clamp=(x,lo,hi)=>Math.max(lo,Math.min(hi,x));
const clone=x=>JSON.parse(JSON.stringify(x));
const modes={approach:['Defensive','Balanced','Aggressive'],rally:['Shorten points','Balanced rallies','Extend rallies'],serve:['Safe first serve','Balanced','Power serving'],returnGame:['Safe return','Balanced','Attack second serve'],target:['Automatic','Backhand','Forehand','Movement','Stamina']};
const balanced={approach:'Balanced',rally:'Balanced rallies',serve:'Balanced',returnGame:'Balanced',target:'Automatic'};
function validateTactics(patch){
 if(!patch||typeof patch!=='object'||Array.isArray(patch)||!Object.keys(patch).length)throw Error('Invalid tactics');
 for(const [k,v] of Object.entries(patch))if(!Object.hasOwn(modes,k)||!modes[k].includes(v))throw Error('Invalid tactic '+k);
}
function profile(p){
 if(!p||typeof p.name!=='string'||!p.name.trim())throw Error('Missing player name');
 const o={name:p.name};
 for(const k of ['serve','return','rally','forehand','backhand','fitness','stamina','movement','fatigue','focus','confidence']){
  if(!Number.isFinite(p[k])||p[k]<0||p[k]>100)throw Error('Invalid player '+k);o[k]=p[k];
 }
 for(const k of ['rawServe','sharpness','morale','surfaceMultiplier'])if(p[k]!==undefined){const hi=k==='surfaceMultiplier'?1.05:100,lo=k==='surfaceMultiplier'?.95:0;if(!Number.isFinite(p[k])||p[k]<lo||p[k]>hi)throw Error('Invalid player '+k);o[k]=p[k];}
 return o;
}
function draw(s){s.rng=(Math.imul(s.rng,1664525)+1013904223)>>>0;return s.rng/4294967296;}
function createMatch({players,seed=1,surface='hard',bestOf=3}){
 if(!Array.isArray(players)||players.length!==2||!Number.isInteger(seed)||seed<0||seed>4294967295||!['hard','grass','clay'].includes(surface)||![3,5].includes(bestOf))throw Error('Invalid match setup');
 const s={version:'ace-poc-0.1',surface,bestOf,rng:seed,players:players.map(profile),tactics:[{...balanced},{...balanced}],pending:[null,null],sets:[0,0],games:[0,0],completedSets:[],gameNumber:0,totalPoints:0,stats:players.map(()=>({points:0,servicePoints:0,firstIn:0,aces:0,doubleFaults:0,unforcedErrors:0})),events:[],winner:null,status:'ready'};
 s.nextServer=draw(s)<.5?0:1;return s;
}
function queueTactics(state,side,patch){
 if(state.status==='completed'||![0,1].includes(side))throw Error('Cannot coach');
 validateTactics(patch);const s=clone(state);
 s.pending[side]={...s.pending[side],...patch};return s;
}
function effective(p,t){
 const expression=p.sharpness===undefined?clamp((1-.22*(p.fatigue/100)**1.5)*(.96+.0004*p.focus),.65,1):(1-.12*(p.fatigue/100)**1.35)*(.94+.06*p.sharpness/100)*(.96+.04*(p.focus*.45+p.confidence*.30+p.morale*.25)/100)*(p.surfaceMultiplier??1);
 const rawServe=p.rawServe??p.serve;
 const agg=t.approach==='Aggressive'?1:t.approach==='Defensive'?-1:0;
 const power=t.serve==='Power serving'?1:t.serve==='Safe first serve'?-1:0;
 return {serve:(p.serve+.35*agg+.65*power)*expression,ret:(p.return+.2*agg)*expression,rally:(p.rally+.55*agg)*expression,first:clamp(.54+rawServe*.002+p.focus*.0007-p.fatigue*.0004-.035*power,.47,.78),df:clamp(.025+Math.max(0,55-rawServe)*.001+p.fatigue*.00025-p.focus*.00015+.009*power,.006,.14),aceDelta:.014*power,ue:clamp(.12+p.fatigue*.001+.025*agg,.06,.34)};
}
function wing(t,opp){
 if(t.target==='Backhand'||t.target==='Forehand')return clamp(((opp.forehand+opp.backhand)/2-opp[t.target.toLowerCase()])*.0015,-.01,.01);
 if(t.target==='Movement')return clamp((50-opp.movement)*.0003,-.015,.015);
 if(t.target==='Stamina')return clamp((50-opp.stamina)*.0003,-.015,.015);
 return 0;
}
function probabilities(s,server,first){
 const receiver=1-server,a=s.players[server],b=s.players[receiver],ta=s.tactics[server],tb=s.tactics[receiver],x=effective(a,ta),y=effective(b,tb);
 const surface=s.surface==='grass'?.035:s.surface==='clay'?-.020:.005;
 const diff=.65*(x.serve-y.ret)+.35*(x.rally-y.rally);
 const ret=tb.returnGame==='Attack second serve'&&!first?-.015:tb.returnGame==='Safe return'?.003:0;
 return {firstIn:x.first,doubleFault:x.df,ace:clamp(.025+(x.serve-y.ret)*.0015+(s.surface==='grass'?.025:s.surface==='clay'?-.008:.006)+x.aceDelta,.003,.20),serverWin:clamp((first?.67:.52)+(first?.0045:.0038)*diff+surface*(first?1:.5)+wing(ta,b)-wing(tb,a)+ret+(y.ue-x.ue)*.2,first?.50:.38,first?.88:.72)};
}
function point(s,server){
 const receiver=1-server, first=draw(s)<probabilities(s,server,true).firstIn, q=probabilities(s,server,first),special=draw(s),outcome=draw(s),error=draw(s),rallyDraw=draw(s);
 const ace=first&&special<q.ace,df=!first&&special<q.doubleFault;
 const winner=ace?server:df?receiver:outcome<q.serverWin?server:receiver;
 const loser=1-winner,ue=!ace&&!df&&error<effective(s.players[loser],s.tactics[loser]).ue;
 const lengths=s.tactics.map(t=>t.rally==='Extend rallies'?1:t.rally==='Shorten points'?-1:0);
 const long=!ace&&!df&&rallyDraw<clamp(.22+.11*(lengths[0]+lengths[1]),.04,.55);
 s.totalPoints++;s.stats[server].servicePoints++;if(first)s.stats[server].firstIn++;if(ace)s.stats[server].aces++;if(df)s.stats[server].doubleFaults++;if(ue)s.stats[loser].unforcedErrors++;s.stats[winner].points++;
 for(let i=0;i<2;i++){
  const p=s.players[i],cost=(ace||df?.035:long?.28:.115)*(1+(100-p.stamina)/100)* (1+(100-p.fitness)/200);
  p.fatigue=clamp(p.fatigue+cost,0,100);
  p.focus=clamp(p.focus+(i===winner?.12:-.12)-cost*.15,0,100);
  p.confidence=clamp(p.confidence+(i===winner?.22:-.22),0,100);
 }
 return {kind:'point',number:s.totalPoints,server,winner,first,ace,df,ue,long,probability:q.serverWin,conditions:conditions(s)};
}
function stepGame(state,expectedGame=state.gameNumber){
 if(state.status==='completed')return clone(state);
 if(expectedGame!==state.gameNumber)throw Error('Stale game revision');
 const s=clone(state);s.status='live';s.gameNumber++;
 for(let i=0;i<2;i++)if(s.pending[i]){s.tactics[i]={...s.tactics[i],...s.pending[i]};s.events.push({kind:'tactics',game:s.gameNumber,side:i,tactics:{...s.tactics[i]}});s.pending[i]=null;}
 const tb=s.games[0]===6&&s.games[1]===6, target=tb?(s.bestOf===5&&s.completedSets.length===4?10:7):4;
 const points=[0,0],firstServer=s.nextServer;
 for(let n=0;;n++){
  if(n>=10000)throw Error('Game safety limit; retry from unchanged checkpoint');
  const server=tb&&n>0?(Math.floor((n-1)/2)%2===0?1-firstServer:firstServer):firstServer;
  const e=point(s,server);points[e.winner]++;
  s.events.push({...e,game:s.gameNumber,set:s.completedSets.length+1,points:[...points],tiebreak:tb});
  if(Math.max(...points)>=target&&Math.abs(points[0]-points[1])>=2)break;
 }
 const w=points[0]>points[1]?0:1;s.games[w]++;s.nextServer=1-firstServer;
 s.events.push({kind:'game_end',game:s.gameNumber,set:s.completedSets.length+1,winner:w,games:[...s.games],points:[...points],tiebreak:tb});
 if(tb||(Math.max(...s.games)>=6&&Math.abs(s.games[0]-s.games[1])>=2)){
  s.sets[w]++;const result={games:[...s.games],tiebreak:tb?[...points]:null,winner:w};
  s.completedSets.push(result);s.events.push({kind:'set_end',set:s.completedSets.length,...clone(result),sets:[...s.sets]});
  s.games=[0,0];
  if(s.sets[w]===Math.floor(s.bestOf/2)+1){s.winner=w;s.status='completed';s.events.push({kind:'match_end',winner:w,sets:[...s.sets]});}
 }
 return s;
}
function conditions(s){
 return s.players.map((p,i)=>({name:p.name,energy:100-p.fatigue,fatigue:p.fatigue,focus:p.focus,confidence:p.confidence,movement:p.movement*(1-p.fatigue*.002),serve:clamp(effective(p,s.tactics[i]).serve,0,100),rally:clamp(effective(p,s.tactics[i]).rally,0,100)}));
}
function observable(s){return {status:s.status,gameNumber:s.gameNumber,totalPoints:s.totalPoints,sets:[...s.sets],games:[...s.games],completedSets:clone(s.completedSets),winner:s.winner,players:conditions(s),stats:clone(s.stats),events:clone(s.events)};}
module.exports={createMatch,queueTactics,stepGame,observable,probabilities};
