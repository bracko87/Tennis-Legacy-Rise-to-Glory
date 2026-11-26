'use strict';
const $=id=>document.getElementById(id);
const choices={approach:['Defensive','Balanced','Aggressive'],rally:['Shorten points','Balanced rallies','Extend rallies'],serve:['Safe first serve','Balanced','Power serving'],returnGame:['Safe return','Balanced','Attack second serve'],target:['Automatic','Backhand','Forehand','Movement','Stamina']};
const labels={approach:'Playing approach',rally:'Rally strategy',serve:'Serving strategy',returnGame:'Return strategy',target:'Opponent targeting'};
const defaults={approach:'Balanced',rally:'Balanced rallies',serve:'Balanced',returnGame:'Balanced',target:'Automatic'};
let token=null,admin=false,state=null,busy=false,epoch=0,dirty=false,selected=null;

const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n;};
for(const [k,values] of Object.entries(choices)){const label=el('label',labels[k]),s=el('select');s.id='tactic-'+k;for(const v of values){const o=el('option',v);o.value=v;s.append(o);}s.value=defaults[k];s.addEventListener('change',()=>dirty=true);label.append(s);$('fields').append(label);}
function notice(m){$('notice').textContent=m;}
async function api(path,method='GET',body){const headers={};if(token)headers.Authorization='Bearer '+token;if(body!==undefined)headers['Content-Type']='application/json';const r=await fetch(path,{method,headers,body:body===undefined?undefined:JSON.stringify(body),cache:'no-store'});const data=await r.json();if(!r.ok){const e=Error(data.error||'Request failed');e.status=r.status;throw e;}return data;}
function signout(){epoch++;token=null;state=null;dirty=false;selected=null;$('draw').hidden=true;$('pilot').hidden=true;$('login').hidden=false;$('match').hidden=true;$('setup').hidden=true;$('events').replaceChildren();$('score').replaceChildren();$('conditions').replaceChildren();$('statistics').replaceChildren();$('password').value='';}
function metric(k,v){const d=el('div'),line=el('div',undefined,'metric');line.append(el('span',k),el('span',Math.round(v)+'%'));const bar=el('progress');bar.max=100;bar.value=v;d.append(line,bar);return d;}
function pointLabel(a,b,tb){if(tb)return String(a);if(a>=3&&b>=3)return a===b?'40':a>b?'AD':'40';return ['0','15','30','40'][Math.min(a,3)];}
function render(s){
 if(state?.id!==s.id)dirty=false;state=s;
 $('match').hidden=false;$('setup').hidden=true;
 $('status').textContent=s.status.toUpperCase()+(s.phase==='between-games'?' • Change of game':' • Game '+s.gameNumber);
 $('start').textContent=(s.surface||'hard').toUpperCase()+' • '+(s.opponentType==='human'?(s.opponentOnline?'Opponent online':'Opponent offline'):'AI opponent')+' • '+(s.engineVersion==='ace-context-0.5'?'Context v0.5':s.engineVersion==='ace-tactical-0.4'?'Tactical v0.4':'Legacy model')+(s.weather?' • '+s.weather.temperatureC+'°C / '+s.weather.windKmh+' km/h':'')+' • Start '+new Date(s.startAt).toLocaleTimeString();
 for(const id of ['score','conditions','statistics','activeTactics','advice','history'])$(id).replaceChildren();
 const setCount=s.bestOf||3,setIndices=Array.from({length:setCount},(_,i)=>i);$('score').classList.toggle('five-set',setCount===5);
 $('matchDetail').textContent=s.drawPhase?s.drawPhase.replace('_',' ')+' • Round '+s.drawRound+(s.managed?' • Your match':' • Spectating'):s.detail?s.detail.tournament_name+' • '+s.detail.city+' • '+s.detail.round_label+' • Court '+s.detail.court_number+' • Private copy of schedule (not official start)':'';
 const head=el('div',undefined,'scoreline');head.append(el('span','Player'),...[...setIndices.map(i=>'Set '+(i+1)),'Games','Point'].map(x=>el('b',x)));$('score').append(head);
 s.players.forEach((p,i)=>{
  const name=p.name+(i===s.side?' (you)':'');const row=el('div',undefined,'scoreline');
  const label=el('span',name+(s.server===i?' • serving':''),s.server===i?'serving':'');
  row.append(label,...setIndices.map(n=>el('b',s.completedSets[n]?String(s.completedSets[n].games[i]):'—',s.completedSets[n]?.winner===i?'won':'')),el('b',s.status==='completed'?'—':String(s.games[i])),el('b',s.status==='completed'?'—':pointLabel(s.points[i],s.points[1-i],s.tiebreak)));$('score').append(row);
  const card=el('div',undefined,'player');card.append(el('h3',name));if(p.style)card.append(el('p',p.style+' • '+p.hand+'-handed'));
  for(const [k,v] of [['Energy',p.energy],['Fatigue',p.fatigue],['Focus',p.focus],['Confidence',p.confidence],['Momentum (last 12 points)',p.momentum],['Movement',p.movement],['Serve',p.serve],['Rally effectiveness',p.rally]])if(Number.isFinite(v))card.append(metric(k,v));$('conditions').append(card);
  const st=el('div',undefined,'player');st.append(el('strong',name));const a=s.stats[i];
  for(const [k,v] of [['Points won',a.points],['Service points',a.servicePoints],['First serves in',a.servicePoints?Math.round(100*a.firstIn/a.servicePoints)+'% ('+a.firstIn+'/'+a.servicePoints+')':'—'],['Aces',a.aces],['Double faults',a.doubleFaults],['Unforced errors',a.unforcedErrors]]){const line=el('div',undefined,'statline');line.append(el('span',k),el('b',String(v)));st.append(line);}$('statistics').append(st);
 });
 if(s.winner!==null)$('score').append(el('strong','Winner: '+s.players[s.winner].name));
 const applied=s.activeTactics||defaults,active={...defaults,...applied,...s.ownPending};
 if(!dirty)for(const k of Object.keys(choices))$('tactic-'+k).value=active[k];
 const desc=t=>Object.entries(t||{}).map(([k,v])=>labels[k]+': '+v).join(' · ');
 $('activeTactics').append(el('strong','ACTIVE'+(s.ownTactics?' • Game '+s.ownTactics.game:''),'status-active'),el('p',desc(applied)));
 if(s.ownPending)$('activeTactics').append(el('strong','QUEUED • Game '+s.nextCoachingGame,'status-pending'),el('p',desc(s.ownPending)));
 $('coach').hidden=!s.managed||s.status==='completed'||s.coachingMode==='auto';const clock=s.nextGameAt!==null&&s.nextGameAt!==undefined?' • Next game in '+Math.max(0,Math.ceil((s.nextGameAt-s.serverNow)/1000))+'s':s.nextPointAt?' • Next point in '+Math.max(0,Math.ceil((s.nextPointAt-s.serverNow)/1000))+'s':'';
 $('current').textContent='Next coaching game: '+(s.nextCoachingGame??'—')+clock;
 if(s.status!=='completed')$('status').textContent+=clock;
 for(const a of s.recommendations||[]){const c=el('div',undefined,'advice');c.append(el('strong',a.title),el('p',a.reason));if(!$('coach').hidden){const b=el('button','Use suggestion');b.type='button';b.addEventListener('click',()=>{for(const [k,v] of Object.entries(a.patch))$('tactic-'+k).value=v;dirty=true;notice('Suggestion selected. Send instructions to apply it.');});c.append(b);}$('advice').append(c);}
 if(!(s.recommendations||[]).length)$('advice').append(el('p',s.status==='completed'?'Match completed.':'No strong tactical signal yet. Keep monitoring the match.'));
 $('history').replaceChildren(...(s.ownHistory||[]).slice().reverse().map(e=>el('li','Game '+e.game+' • '+desc(e.tactics))));
 $('events').replaceChildren(...s.events.slice(-40).reverse().map(e=>{let line;if(e.kind==='point'){const w=s.players[e.winner].name,l=s.players[1-e.winner].name;line=e.ace?w+' serves an ace':e.df?l+' double faults':e.ue?l+' makes an unforced error':e.long?w+' wins an extended rally':w+' wins the point';line+=' • '+(e.tiebreak?e.points.join('–'):pointLabel(e.points[0],e.points[1],false)+'–'+pointLabel(e.points[1],e.points[0],false));}else if(e.kind==='game_end')line=s.players[e.winner].name+' wins game • '+e.games.join('–');else if(e.kind==='set_end')line=s.players[e.winner].name+' wins set '+e.set+' • '+e.games.join('–');else line='Match completed';return el('li',line);}));
}

function renderDraw(d){
 $('draw').hidden=false;$('setup').hidden=true;
 const names=Object.fromEntries(d.entrants.map(p=>[p.id,p.name]));
 $('drawTitle').textContent=d.phase==='completed'?'Tournament completed':d.phase.replace('_',' ').toUpperCase()+' • Round '+d.round;
 $('drawSummary').textContent=d.champion?'Champion: '+names[d.champion]:d.results.length+' matches completed';
 if(!selected||!d.matches.some(m=>m.id===selected))selected=(d.matches.find(m=>m.players.includes(d.managedPlayer)&&m.status!=='completed')||d.matches.find(m=>m.status==='live')||d.matches.at(-1))?.id;
 const current=$('matchSelect').value;
 const signature=d.matches.map(m=>m.id+':'+m.status+':'+(m.winner||'')).join('|');
 if($('matchSelect').dataset.signature!==signature){
  $('matchSelect').replaceChildren(...d.matches.map(m=>{const o=el('option',m.players.map(p=>names[p]).join(' vs ')+' • '+m.status);o.value=m.id;return o;}));$('matchSelect').dataset.signature=signature;
 }
 $('matchSelect').value=selected||current;
 $('drawMatches').replaceChildren(...d.matches.map(m=>el('li',m.phase.replace('_',' ')+' R'+m.round+' • '+m.players.map(p=>names[p]).join(' vs ')+' • '+m.court+' • '+m.status+(m.winner?' • Winner: '+names[m.winner]:''))));
}
function showMatch(s){if(s.status==='scheduled'){$('match').hidden=true;state=null;notice(s.delayed?'Waiting for court or player availability.':'Match scheduled for '+new Date(s.requestedAt).toLocaleTimeString());return;}render(s);}
async function refresh(){if(!token||busy)return;busy=true;const run=epoch;try{
 const d=await api('/api/draw');if(run!==epoch)return;renderDraw(d);
 if(selected){const id=selected;let s=await api('/api/match?id='+encodeURIComponent(id));if(s.managed&&s.status==='live')s=await api('/api/heartbeat?id='+encodeURIComponent(id),'POST',{});if(run===epoch&&id===selected)showMatch(s);}
 }catch(e){if(run!==epoch)return;if(e.status===404){$('setup').hidden=false;$('draw').hidden=true;$('match').hidden=true;notice('Create a private tournament.');}else if(e.status===403){signout();notice('Session expired or access denied.');}else notice(e.message);}finally{busy=false;}}
$('matchSelect').addEventListener('change',()=>{selected=$('matchSelect').value;state=null;dirty=false;$('match').hidden=true;refresh();});
$('loginForm').addEventListener('submit',async e=>{e.preventDefault();if(busy)return;busy=true;try{const s=await api('/api/login','POST',{email:$('email').value,password:$('password').value});token=s.token;admin=s.admin;$('password').value='';$('login').hidden=true;$('pilot').hidden=false;$('session').textContent='Private tournament administrator';notice('Local session active.');}catch(e){notice(e.message);}finally{busy=false;}await refresh();});
$('logout').addEventListener('click',()=>{signout();notice('Signed out. Tournament continues on server.');});
$('schedule').addEventListener('submit',async e=>{e.preventDefault();if(busy)return;busy=true;try{renderDraw(await api('/api/draw','POST',{delaySeconds:Number($('delay').value),surface:$('surface').value,pace:$('pace').value,mode:$('mode').value}));notice('Private tournament scheduled.');}catch(e){notice(e.message);}finally{busy=false;}await refresh();});
$('coach').addEventListener('submit',async e=>{e.preventDefault();if(busy||!state?.managed||state.id!==selected){notice('Refresh in progress or no managed match selected; retry.');return;}busy=true;const id=selected,run=epoch;try{const tactics=Object.fromEntries(Object.keys(choices).map(k=>[k,$('tactic-'+k).value]));const s=await api('/api/coach?id='+encodeURIComponent(id),'POST',{targetGame:state.nextCoachingGame,tactics});if(run===epoch&&id===selected){dirty=false;render(s);notice('Instructions queued for game '+s.nextCoachingGame);}}catch(e){notice(e.message);}finally{busy=false;}});
setInterval(refresh,1000);
