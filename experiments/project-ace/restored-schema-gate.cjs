'use strict';
const fs=require('node:fs'),{isDeepStrictEqual}=require('node:util'),contract=require('./restored-schema-contract.json');
function map(rows,key){if(!Array.isArray(rows))throw Error('Missing catalog array');const m=new Map();for(const x of rows){const k=key(x);if(typeof k!=='string'||!k||m.has(k))throw Error('Duplicate or missing catalog identity');m.set(k,x);}return m;}
function inspect(s){
 if(!s||s.schema!=='ace-restored-catalog-v1')throw Error('Invalid catalog format');
 const issues=[],add=(kind,object)=>issues.push({kind,object}),t=map(s.tables,x=>x.name),f=map(s.routines,x=>x.signature);
 map(s.triggers,x=>JSON.stringify([x.table,x.name]));map(s.policies,x=>JSON.stringify([x.table,x.name]));map(s.migration_history,x=>x.version);
 if(!Array.isArray(s.roles)||new Set(s.roles).size!==s.roles.length)throw Error('Invalid role inventory');
 for(const role of contract.roles)if(!s.roles.includes(role))add('missing_role',role);
 if(s.has_history!==true||s.migration_history.length===0)add('missing_migration_history','supabase_migrations.schema_migrations');
 if(s.has_cron!==true||!Array.isArray(s.cron))add('missing_cron_inventory','cron.job');
 for(const [name,cols] of Object.entries(contract.tables)){
  const row=t.get(name);if(!row){add('missing_table',name);continue;}
  const columns=map(row.columns,x=>x.name);for(const col of cols)if(!columns.has(col))add('missing_column',name+'.'+col);
  if(['public.tournament_matches','public.tournament_match_simulations','public.tournament_match_sets','public.tournament_match_player_stats','public.player_tournament_results','public.career_finance_transactions','public.player_ranking_contributions'].includes(name)){
   for(const role of ['anon','authenticated'])if(!row.grants?.[role]||['insert','update','delete','truncate'].some(k=>row.grants[role][k]!==false))add('client_write_grant_or_unknown',name+':'+role);
  }
 }
 for(const name of contract.routines)if(name.includes('(')?!f.has(name):![...f.values()].some(x=>x.name===name))add('missing_routine',name);
 for(const row of f.values()){
  if(!/^[a-f0-9]{32}$/.test(row.hash))add('invalid_routine_hash',row.signature);
  if(contract.internal.includes(row.name)&&['anon','authenticated'].some(role=>row.execute?.[role]!==false))add('internal_execute_grant_or_unknown',row.signature);
 }
 return issues;
}
function compare(restored,reference){
 const issues=inspect(restored);
 if(Array.isArray(restored.cron)&&restored.cron.some(x=>x.active!==false))issues.push({kind:'restored_cron_not_disabled'});
 if(!reference)return {status:'blocked_missing_reference',issues,production_ready:false,requires_manual_review:true};
 issues.push(...inspect(reference).map(x=>({...x,source:'reference'})));
 const groups={tables:x=>x.name,routines:x=>x.signature,triggers:x=>JSON.stringify([x.table,x.name]),policies:x=>JSON.stringify([x.table,x.name]),migration_history:x=>x.version};
 for(const [group,key] of Object.entries(groups)){
  const a=map(restored[group],key),b=map(reference[group],key);
  for(const k of [...new Set([...a.keys(),...b.keys()])].sort()){
   if(!a.has(k))issues.push({kind:'missing_from_restore',group,object:k});
   else if(!b.has(k))issues.push({kind:'restore_only',group,object:k});
   else if(!isDeepStrictEqual(a.get(k),b.get(k)))issues.push({kind:'catalog_drift',group,object:k});
  }
 }
 if(restored.server_major!==reference.server_major)issues.push({kind:'server_major_drift'});
 if(Array.isArray(restored.cron)&&Array.isArray(reference.cron)){
  const key=x=>JSON.stringify([x.name,x.schedule]);if(!isDeepStrictEqual(restored.cron.map(key).sort(),reference.cron.map(key).sort()))issues.push({kind:'cron_inventory_drift'});
 }
 return {status:issues.length?'blocked_catalog_review':'catalog_match_review_only',issues,production_ready:false,requires_manual_review:true};
}
if(require.main===module){
 const [restored,reference]=process.argv.slice(2);if(!restored)throw Error('Usage: node restored-schema-gate.cjs restored.json [approved-reference.json]');
 const read=p=>JSON.parse(fs.readFileSync(p,'utf8')),report=compare(read(restored),reference?read(reference):null);console.log(JSON.stringify(report,null,2));if(report.status!=='catalog_match_review_only')process.exitCode=2;
}
module.exports={inspect,compare};
