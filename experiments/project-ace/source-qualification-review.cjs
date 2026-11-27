'use strict';
// Deliberately one-round qualification, explicit final-to-main slot mapping.
const {createHash}=require('node:crypto');
const ok=(x,m)=>{if(!x)throw Error(m)},id=x=>typeof x==='string'&&x.length>0&&x.length<=120&&x.trim()===x;
function freezeQualification(input){
 const c=input?.competition;
 ok(input?.schema==='ace-source-admission-v1'&&input.complete_export===true&&c?.scope==='singles'&&c.field_locked===true&&c.qualification_required===true&&c.status==='published'&&id(c.id),'Locked new qualification required');
 ok([8,16,32,64,128].includes(c.draw_size)&&Number.isInteger(c.season_number)&&c.season_number>=1&&c.season_number<=10000,'Invalid draw or season');
 ok(Array.isArray(input.results)&&!input.results.length&&Array.isArray(input.simulations)&&!input.simulations.length,'Existing source state');
 ok(Array.isArray(input.matches)&&Array.isArray(input.players)&&Array.isArray(input.qualifier_slots),'Complete inventory required');
 const q=input.matches.filter(m=>m.draw_type==='qualification'),main=input.matches.filter(m=>m.draw_type==='main_draw'),n=q.length;
 ok(n>=1&&n<=c.draw_size&&main.length===c.draw_size-1&&input.matches.length===n+main.length&&input.qualifier_slots.length===n,'Incomplete qualification inventory');
 const ids=new Set(input.matches.map(m=>m.id));ok(ids.size===input.matches.length&&[...ids].every(id),'Duplicate match ID');
 const map=new Map(),used=new Set();
 for(const x of input.qualifier_slots){const key=x.match_id+':'+x.slot;ok([1,2].includes(x.slot)&&!map.has(key)&&q.some(m=>m.id===x.qualifier_match_id)&&!used.has(x.qualifier_match_id),'Invalid qualifier mapping');map.set(key,x.qualifier_match_id);used.add(x.qualifier_match_id);}
 const players=new Set(input.players.map(p=>p.id)),entries=new Set(),ordered=[];
 ok(players.size===input.players.length&&players.size===c.draw_size+n&&[...players].every(id),'Incomplete player inventory');
 const entrant=p=>{ok(players.has(p)&&!entries.has(p),'Duplicate or foreign entrant');entries.add(p);};
 const find=(xs,r,k)=>{const found=xs.filter(m=>m.round_number===r&&m.match_number===k);ok(found.length===1,'Invalid phase position');return found[0]};
 const time=m=>((m.scheduled_season_week-1)*7+m.scheduled_day-1)*1440+m.scheduled_start_minute;
 function row(m,a,b){ok(m.competition_id===c.id&&m.status==='scheduled'&&m.started_at===null&&m.completed_at===null&&m.winner_id===null&&Number.isInteger(m.scheduled_season_week)&&m.scheduled_season_week>=1&&m.scheduled_season_week<=52&&Number.isInteger(m.scheduled_day)&&m.scheduled_day>=1&&m.scheduled_day<=7&&Number.isInteger(m.scheduled_start_minute)&&m.scheduled_start_minute>=0&&m.scheduled_start_minute<1440&&Number.isInteger(m.court_number)&&m.court_number>=1,'Invalid schedule or match state');return {match_id:m.id,competition_id:c.id,draw_type:m.draw_type,round_number:m.round_number,match_number:m.match_number,scheduled_season_week:m.scheduled_season_week,scheduled_day:m.scheduled_day,scheduled_start_minute:m.scheduled_start_minute,court_number:m.court_number,player1_id:m.player1_id,player2_id:m.player2_id,feeder1:a,feeder2:b};}
 for(let k=1;k<=n;k++){const m=find(q,1,k);entrant(m.player1_id);entrant(m.player2_id);ordered.push(row(m,null,null));}
 for(let r=1;r<=Math.log2(c.draw_size);r++)for(let k=1;k<=c.draw_size/2**r;k++){
  const m=find(main,r,k);let a,b;
  if(r===1){a=map.get(m.id+':1')??null;b=map.get(m.id+':2')??null;
   for(const [p,f] of [[m.player1_id,a],[m.player2_id,b]]){if(f)ok(p===null,'Qualifier slot must be empty');else entrant(p);}
   ok(q.every(x=>time(x)<time(m)),'Qualification must precede main draw');
  }else{ok(m.player1_id===null&&m.player2_id===null,'Future slots must be empty');a=find(main,r-1,2*k-1).id;b=find(main,r-1,2*k).id;}
  ordered.push(row(m,a,b));
 }
 ok(entries.size===players.size&&ordered.filter(x=>x.draw_type==='main_draw'&&x.round_number===1).flatMap(x=>[x.feeder1,x.feeder2]).filter(Boolean).length===n,'Unused qualifier mapping');
 const body={schema:'ace-frozen-source-qualification-v1',competition_id:c.id,season_number:c.season_number,draw_size:c.draw_size,qualification_count:n,matches:ordered};
 return {...body,sha256:createHash('sha256').update(JSON.stringify(body)).digest('hex')};
}
module.exports={freezeQualification};
