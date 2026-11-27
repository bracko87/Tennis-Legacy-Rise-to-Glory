'use strict';
const assert=require('node:assert/strict'),crypto=require('node:crypto'),{inspect}=require('./restored-schema-gate.cjs'),c=require('./restored-schema-contract.json'),{freeze,simulate,digest}=require('./shadow-comparison.cjs'),raw=require('./sample-legacy-snapshot.json'),{evaluate}=require('./authentic-shadow-evidence.cjs');
const roles=c.roles,grants=Object.fromEntries(roles.map(r=>[r,{select:false,insert:false,update:false,delete:false,truncate:false}]));
const catalog={schema:'ace-restored-catalog-v1',server_major:'16',roles,tables:Object.entries(c.tables).map(([name,cols])=>({name,columns:cols.map(name=>({name,type:'text'})),grants})),routines:c.routines.map(x=>({name:x.split('(')[0],signature:x.includes('(')?x:x+'()',hash:'0'.repeat(32),execute:Object.fromEntries(roles.map(r=>[r,r==='service_role']))})),triggers:[],policies:[],migration_history:[{version:'20261120',name:'fixture'}],has_history:true,has_cron:true,cron:[{name:'game',schedule:'* * * * *',active:false}]};
function pack(s,mode,label){const bytes=Buffer.from(JSON.stringify(s));return [bytes,{schema:'ace-catalog-receipt-v1',mode,source_label:label,captured_at:'2026-11-27T00:00:00.000Z',sha256:crypto.createHash('sha256').update(bytes).digest('hex'),issues:inspect(s),production_ready:false,provenance:'operator_supplied_not_authenticated'}];}

const clone=x=>JSON.parse(JSON.stringify(x));
const input=freeze({match_id:'synthetic-m',competition_id:'synthetic-c',source_revision:0,snapshot:raw,seed:321});
const a=simulate(input);
const sets=a.sets.map((x,i)=>({set_number:i+1,player1_games:x.games[0],player2_games:x.games[1],player1_tiebreak_points:x.tiebreak?.[0]??null,player2_tiebreak_points:x.tiebreak?.[1]??null,status:'completed'}));
const capture={schema:'ace-legacy-shadow-capture-v1',restore_id:'synthetic-restore',match:{id:input.match_id,competition_id:input.competition_id,player1_id:input.player_ids[0],player2_id:input.player_ids[1],winner_id:a.winner_id,status:'completed',completion_reason:null,actual_duration_minutes:a.actual_duration_minutes,started_at:'2026-01-01T10:00:00Z',completed_at:'2026-01-01T13:00:00Z',...Object.fromEntries(['draw_type','round_label','scheduled_season_week','scheduled_day','scheduled_start_minute','court_number'].map(k=>[k,raw.match[k]]))},simulation:{match_id:input.match_id,engine_version:'synthetic-control',engine_seed:'fixture-seed',simulation_status:'completed',final_winner_id:a.winner_id,total_games:a.sets.reduce((n,x)=>n+x.games[0]+x.games[1],0),total_points:a.stats.reduce((n,x)=>n+x.total_points_won,0),sets_payload:clone(sets),player1_stats:a.stats[0],player2_stats:a.stats[1]},sets,stats:a.stats.map((x,i)=>({player_id:input.player_ids[i],...x})),routines:['simulate_tournament_match_v1','prepare_tournament_match_simulation_v1','finalize_match_replay_v1','get_match_engine_profile_v1','simulated_tennis_duration_minutes_v1'].map(x=>({signature:'public.'+x+'(uuid)',definition_md5:'a'.repeat(32)}))};
const link=c=>({schema:'ace-legacy-shadow-link-v1',input_sha256:input.input_sha256,capture_sha256:digest(c),restore_id:c.restore_id,legacy_engine_seed:c.simulation.engine_seed,routine_inventory_sha256:digest(c.routines),pre_match_capture_attested:true});

capture.simulation.engine_version='fixture-legacy-control';
for(const x of capture.routines){const existing=catalog.routines.find(r=>r.signature===x.signature);if(existing)existing.hash=x.definition_md5;else catalog.routines.push({name:x.signature.split('(')[0],signature:x.signature,hash:x.definition_md5,execute:Object.fromEntries(roles.map(r=>[r,r==='service_role']))});}
const bundle=(s,mode,label)=>{const [bytes,receipt]=pack(s,mode,label);return {bytes,receipt};};
const restore=bundle(catalog,'restore','restore'),reference=bundle(catalog,'reference','reference');
const entry={input,capture,link:{...link(capture),restored_catalog_sha256:restore.receipt.sha256,reference_catalog_sha256:reference.receipt.sha256},cohort:'fixture'};
const args={restore,reference,restore_id:capture.restore_id,cases:[entry]};
const result=evaluate(args);assert.equal(result.status,'linked_cohort_review_only');assert.equal(result.cohort.paired_matches,1);assert.equal(result.production_ready,false);assert.equal(result.legacy_authority_verified,false);
assert.throws(()=>evaluate({...args,cases:[entry,entry]}),/Duplicate/);
assert.throws(()=>evaluate({...args,restore_id:'other'}),/Restore identity/);
assert.throws(()=>evaluate({...args,cases:[{...entry,link:{...entry.link,restored_catalog_sha256:'bad'}}]}),/Catalog linkage/);
const changed=clone(capture);changed.routines[0].definition_md5='b'.repeat(32);
assert.throws(()=>evaluate({...args,cases:[{...entry,capture:changed,link:{...entry.link,...link(changed)}}]}),/fingerprint mismatch/);
const synthetic=clone(capture);synthetic.simulation.engine_version='synthetic-control';
assert.throws(()=>evaluate({...args,cases:[{...entry,capture:synthetic}]}),/Synthetic/);
const drift=clone(catalog);drift.routines[0].hash='f'.repeat(32);
assert.equal(evaluate({...args,restore:bundle(drift,'restore','restore')}).status,'blocked_catalog_review');
console.log('PASS linked catalog and capture cohort, tampering, duplicate, synthetic-label and schema drift rejection (synthetic fixture only)');

const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{load}=require('./authentic-shadow-package.cjs');
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'ace-shadow-package-'));
try{
 const put=(name,value)=>{const bytes=Buffer.isBuffer(value)?value:Buffer.from(JSON.stringify(value));fs.writeFileSync(path.join(dir,name),bytes);return {file:name,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};};
 const manifest={schema:'ace-shadow-package-v1',review_only:true,restore_id:capture.restore_id,restore:{catalog:put('restore.json',restore.bytes),receipt:put('restore-receipt.json',restore.receipt)},reference:{catalog:put('reference.json',reference.bytes),receipt:put('reference-receipt.json',reference.receipt)},cases:[put('case-1.json',entry)]};
 const save=()=>put('manifest.json',manifest);save();
 assert.equal(load(dir).status,'linked_cohort_review_only');
 fs.appendFileSync(path.join(dir,'case-1.json'),' ');
 assert.throws(()=>load(dir),/integrity/);
 manifest.cases=[put('case-1.json',entry)];save();
 manifest.cases[0].file='../case-1.json';save();assert.throws(()=>load(dir),/filename/);
 manifest.cases=[put('case-1.json',entry),put('case-1.json',entry)];save();assert.throws(()=>load(dir),/Duplicate package filename/);
 manifest.cases=[put('case-1.json',entry)];save();
 if(process.platform!=='win32'){fs.renameSync(path.join(dir,'case-1.json'),path.join(dir,'original.json'));fs.symlinkSync('original.json',path.join(dir,'case-1.json'));assert.throws(()=>load(dir));}
 console.log('PASS offline evidence package ingestion, raw file integrity, traversal, duplicate files and symlink rejection');
}finally{fs.rmSync(dir,{recursive:true,force:true});}
