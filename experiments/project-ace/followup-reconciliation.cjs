'use strict';
// Review-only reconciliation queue. No official match, ranking or finance writes.
const {isDeepStrictEqual}=require('node:util');
const {slot}=require('./world-clock.cjs');
const start=m=>slot(m.season,m.week,m.day,m.minute??600)/60;
const validPlayers=m=>Array.isArray(m.players)&&m.players.length===2&&m.players.every(x=>typeof x==='string'&&x.length)&&m.players[0]!==m.players[1];
function candidates(played,matches){
 if(!played||played.status!=='completed'||played.actualDuration==null)return [];
 if(!validPlayers(played)||!Number.isSafeInteger(played.actualDuration)||played.actualDuration<0)throw Error('Invalid completed match');
 const estimate=played.estimatedDuration??150;
 if(!Number.isSafeInteger(estimate)||estimate<0)throw Error('Invalid estimate');
 if(played.actualDuration<=estimate)return [];
 const from=start(played),to=Math.max(from+played.actualDuration,played.completedGameMinute??0)+60;
 const selected=matches.filter(m=>m.id!==played.id&&m.status==='scheduled'&&validPlayers(m)&&m.players.some(p=>played.players.includes(p))&&start(m)>=from&&start(m)<=to);
 if(new Set(selected.map(m=>m.id)).size!==selected.length)throw Error('Duplicate match');
 return selected.sort((a,b)=>start(a)-start(b)||(a.id<b.id?-1:a.id>b.id?1:0)).map(m=>m.id);
}
function enqueue(queue,played,matches){
 const ids=candidates(played,matches),existing=queue.find(q=>q.source===played.id);
 const evidence={source:played.id,start:start(played),actual:played.actualDuration??null,estimate:played.estimatedDuration??150,completed:played.completedGameMinute??null,players:[...played.players]};
 if(existing){if(!isDeepStrictEqual(existing.evidence,evidence))throw Error('Conflicting completion evidence');return queue;}
 if(!ids.length)return queue;
 return [...queue,{source:played.id,evidence,items:ids.map(id=>({id,status:'pending',attempts:0}))}];
}
// Pure receipt application: caller must atomically persist schedule mutation and receipt in a future adapter.
function record(queue,source,id,outcome){
 const job=queue.find(q=>q.source===source),item=job?.items.find(i=>i.id===id);
 if(!item)throw Error('Unknown reconciliation item');
 const allowed=['ready','rescheduled','no_longer_scheduled','blocked','waiting_live_conflict','paused','error'];
 if(!allowed.includes(outcome))throw Error('Invalid outcome');
 if(item.status==='done')return queue;
 const done=['ready','rescheduled','no_longer_scheduled'].includes(outcome);
 return queue.map(q=>q.source!==source?q:{...q,items:q.items.map(i=>i.id!==id?i:{...i,status:done?'done':'pending',attempts:i.attempts+1,lastOutcome:outcome})});
}
module.exports={candidates,enqueue,record};
