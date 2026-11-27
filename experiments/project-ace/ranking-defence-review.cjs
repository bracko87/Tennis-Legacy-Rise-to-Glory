'use strict';
// Separate review projection of weekly ranking defence cycles; never writes official rows.
const {nextMonday}=require('./world-clock.cjs'),{digest}=require('./shadow-comparison.cjs');
const check=(v,m)=>{if(!v)throw Error(m)},copy=x=>JSON.parse(JSON.stringify(x));
const integer=(x,min=0)=>Number.isSafeInteger(x)&&x>=min;
const id=x=>typeof x==='string'&&x.length>0&&x.length<=160;
const world=x=>['ATP','WTA'].includes(x);
const edition=x=>JSON.stringify([x.series,x.world,x.season]);
function reconcile(input,day){
 check(integer(day)&&day<=3659999,'Invalid review day');
 const s=copy(input);
 check(s&&Array.isArray(s.editions)&&Array.isArray(s.results)&&Array.isArray(s.contributions)&&Array.isArray(s.cycles),'Complete ranking inventory required');
 check(s.last_day===null||(integer(s.last_day)&&s.last_day<=day),'Ranking clock rollback');
 const editions=new Map(),editionKeys=new Set(),results=new Map(),resultKeys=new Set(),contributions=new Set(),cycles=new Set();
 for(const e of s.editions){
  check(id(e.competition)&&id(e.series)&&world(e.world)&&integer(e.season,1)&&integer(e.publish_day)&&['unfinished','completed','cancelled'].includes(e.status),'Invalid edition');
  check(!editions.has(e.competition)&&!editionKeys.has(edition(e)),'Duplicate edition');editions.set(e.competition,e);editionKeys.add(edition(e));
 }
 for(const r of s.results){
  const e=editions.get(r.competition),k=JSON.stringify([r.competition,r.player]);
  check(e&&id(r.id)&&id(r.player)&&integer(r.points)&&integer(r.publish_day)&&['pending','published'].includes(r.status),'Invalid result');
  check(!results.has(r.id)&&!resultKeys.has(k),'Duplicate result');results.set(r.id,r);resultKeys.add(k);
 }
 for(const c of s.contributions){
  const r=results.get(c.result_id),e=r&&editions.get(r.competition);
  check(r&&r.status==='published'&&e&&c.competition===e.competition&&c.series===e.series&&c.world===e.world&&c.season===e.season&&c.player===r.player&&c.points===r.points&&c.awarded_day===r.publish_day&&c.expires_day===c.awarded_day+366&&typeof c.active==='boolean','Contribution identity mismatch');
  check(!contributions.has(c.result_id),'Duplicate contribution');contributions.add(c.result_id);
  if(!c.active)check(integer(c.deactivated_day,c.awarded_day)&&c.deactivated_day<=day&&typeof c.reason==='string','Invalid inactive contribution');
 }
 for(const c of s.cycles){
  const e=editions.get(c.competition);
  check(e&&e.status!=='unfinished'&&integer(c.processed_day,e.publish_day)&&c.processed_day<=day&&nextMonday(c.processed_day)===c.processed_day&&!cycles.has(c.competition),'Invalid or duplicate defence cycle');
  cycles.add(c.competition);
 }
 for(const r of s.results){
  check(r.status!=='published'||contributions.has(r.id),'Published result missing contribution');
  check(!cycles.has(r.competition)||r.status==='published','Processed edition has pending result');
 }
 const deactivate=(c,reason,competition=null,result=null)=>{c.active=false;c.deactivated_day=day;c.reason=reason;c.replaced_by_competition=competition;c.replaced_by_result=result;};
 const before=digest(s),processed=[];
 if(nextMonday(day)===day){
  const due=s.editions.filter(e=>e.status!=='unfinished'&&e.publish_day<=day&&!cycles.has(e.competition)).sort((a,b)=>a.publish_day-b.publish_day||a.competition.localeCompare(b.competition));
  for(const e of due){
   const rows=s.results.filter(r=>r.competition===e.competition);
   check(rows.every(r=>r.publish_day<=day),'Edition has future-dated result; review required');
   for(const r of rows)r.status='published';
   const replacement=new Map(rows.map(r=>[r.player,r.id]));
   let expired=0,activated=0;
   for(const c of s.contributions)if(c.active&&c.series===e.series&&c.world===e.world&&c.season===e.season-1){
    deactivate(c,e.status==='cancelled'?'next_edition_cancelled':replacement.has(c.player)?'next_edition_result':'next_edition_no_result',e.competition,replacement.get(c.player)??null);expired++;
   }
   for(const r of rows)if(!contributions.has(r.id)){
    s.contributions.push({result_id:r.id,competition:e.competition,series:e.series,world:e.world,season:e.season,player:r.player,points:r.points,awarded_day:r.publish_day,expires_day:r.publish_day+366,active:true});contributions.add(r.id);activated++;
   }
   const receipt={competition:e.competition,processed_day:day,reason:e.status==='cancelled'?'edition_cancelled':'edition_completed',expired,activated};
   s.cycles.push(receipt);cycles.add(e.competition);processed.push(receipt);
  }
  for(const c of s.contributions)if(c.active&&c.expires_day<=day)deactivate(c,'scheduled_expiration');
  for(const c of s.contributions)if(c.active&&s.cycles.some(x=>{const e=editions.get(x.competition);return e.series===c.series&&e.world===c.world&&e.season>c.season;}))deactivate(c,'superseded_safety');
  s.last_day=day;
 }
 const totals={};
 for(const c of s.contributions)if(c.active){const k=JSON.stringify([c.world,c.player]);const sum=(totals[k]??0)+c.points;check(integer(sum),'Ranking total overflow');totals[k]=sum;}
 return {schema:'ace-ranking-defence-review-v1',review_only:true,production_ready:false,source_authenticated:false,status:nextMonday(day)===day?'weekly_review':'not_monday',before_sha256:before,state:s,state_sha256:digest(s),processed,totals,limitations:['Supplied complete normalized inventory, not authenticated database rows','No official ranking snapshots, publication writes or scheduler authority','Future-dated results on due edition require manual review']};
}
module.exports={reconcile};
