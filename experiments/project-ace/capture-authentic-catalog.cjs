'use strict';
// No connection strings or credentials in arguments or evidence files.
const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process'),crypto=require('node:crypto');
const {inspect}=require('./restored-schema-gate.cjs');
function options(args,env){
 const [mode,output]=args;
 if(args.length!==2||!['reference','restore'].includes(mode)||!output||!output.endsWith('.json'))throw Error('Usage: capture-authentic-catalog.cjs reference|restore output.json');
 if(env.ACE_CATALOG_APPROVAL!=='metadata-only-approved'||env.ACE_CATALOG_MODE!==mode)throw Error('Explicit capture approval and matching mode required');
 if(!env.PGSERVICE||!/^[a-zA-Z0-9_-]{1,80}$/.test(env.PGSERVICE))throw Error('Use an approved local PostgreSQL service profile');
 if(['PGHOST','PGHOSTADDR','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOPTIONS','PGSSLMODE','PGSSLROOTCERT'].some(k=>env[k]))throw Error('Remove connection overrides; use service profile and password file');
 if(!env.ACE_CATALOG_SOURCE_LABEL||!/^[a-zA-Z0-9_-]{1,80}$/.test(env.ACE_CATALOG_SOURCE_LABEL))throw Error('Explicit nonsecret source label required');
 return {mode,output:path.resolve(output),label:env.ACE_CATALOG_SOURCE_LABEL,service:env.PGSERVICE};
}
function capture(args,env=process.env){
 const o=options(args,env);
 const receipt=o.output+'.receipt.json';
 if(fs.existsSync(o.output)||fs.existsSync(receipt))throw Error('Evidence destination already exists');
 const childEnv={...Object.fromEntries(['PATH','Path','SYSTEMROOT','SystemRoot','WINDIR','HOME','USERPROFILE','APPDATA','PGSERVICEFILE','PGPASSFILE'].filter(k=>env[k]!==undefined).map(k=>[k,env[k]])),PGSERVICE:o.service,PGCONNECT_TIMEOUT:'5',PGSSLMODE:'verify-full',PGOPTIONS:'-c default_transaction_read_only=on'};
 const r=spawnSync('psql',['-X','-qAt','-w','-v','ON_ERROR_STOP=1','-f',path.join(__dirname,'capture-restored-schema.sql')],{env:childEnv,encoding:'utf8',timeout:90000,maxBuffer:64*1024*1024});
 if(r.error||r.status!==0)throw Error('Metadata capture failed; inspect approved connection profile privately');
 const catalog=JSON.parse(r.stdout);const issues=inspect(catalog);
 if(o.mode==='restore'&&(!Array.isArray(catalog.cron)||catalog.cron.some(x=>x.active!==false)))throw Error('Restored scheduler must be disabled');
 const bytes=JSON.stringify(catalog,null,2)+'\n';
 fs.writeFileSync(o.output,bytes,{flag:'wx',mode:0o600});
 fs.writeFileSync(receipt,JSON.stringify({schema:'ace-catalog-receipt-v1',mode:o.mode,source_label:o.label,captured_at:new Date().toISOString(),sha256:crypto.createHash('sha256').update(bytes).digest('hex'),issues,production_ready:false,provenance:'operator_supplied_not_authenticated'},null,2)+'\n',{flag:'wx',mode:0o600});
 return {issues:issues.length,production_ready:false};
}
if(require.main===module){try{console.log(JSON.stringify(capture(process.argv.slice(2))));}catch(e){console.error(e.message);process.exitCode=2;}}
module.exports={options,capture};
