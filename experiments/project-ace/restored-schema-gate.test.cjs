'use strict';
const assert=require('node:assert/strict'),{compare}=require('./restored-schema-gate.cjs'),c=require('./restored-schema-contract.json');
const clone=x=>JSON.parse(JSON.stringify(x)),roles=c.roles,grants=Object.fromEntries(roles.map(r=>[r,{select:false,insert:false,update:false,delete:false,truncate:false}]));
const s={schema:'ace-restored-catalog-v1',server_major:'16',roles,tables:Object.entries(c.tables).map(([name,cols])=>({name,columns:cols.map(name=>({name,type:'text'})),grants})),routines:c.routines.map(x=>({name:x.split('(')[0],signature:x.includes('(')?x:x+'()',hash:'0'.repeat(32),execute:Object.fromEntries(roles.map(r=>[r,r==='service_role']))})),triggers:[{table:'public.tournament_matches',name:'finalize',enabled:'O',hash:'1'.repeat(32)}],policies:[],migration_history:[{version:'20261120',name:'fixture'}],has_history:true,has_cron:true,cron:[{name:'game',schedule:'* * * * *',active:false}]};
const ref=clone(s);ref.cron[0].active=true;
assert.equal(compare(s,ref).status,'catalog_match_review_only');assert.equal(compare(s,ref).production_ready,false);assert.equal(compare(s).status,'blocked_missing_reference');
const bad=clone(s);bad.tables[0].columns.pop();bad.routines[0].hash='2'.repeat(32);bad.routines[0].execute.anon=true;bad.triggers[0].enabled='D';bad.cron[0].active=true;bad.migration_history[0].version='different';
const out=compare(bad,ref);assert.equal(out.status,'blocked_catalog_review');for(const kind of ['missing_column','internal_execute_grant_or_unknown','catalog_drift','restored_cron_not_disabled','missing_from_restore','restore_only'])assert.ok(out.issues.some(x=>x.kind===kind),kind);
assert.throws(()=>compare({...s,routines:[...s.routines,s.routines[0]]},ref),/Duplicate/);
if(process.argv[2]){const actual=JSON.parse(require('node:fs').readFileSync(process.argv[2],'utf8'));assert.equal(compare(actual,s).status,'blocked_catalog_review');assert.ok(compare(actual,s).issues.some(x=>x.kind==='missing_table'));}
console.log('PASS catalog comparison, missing reference, object/definition/grant/trigger/history drift, active restored scheduler and duplicate identity rejection');
