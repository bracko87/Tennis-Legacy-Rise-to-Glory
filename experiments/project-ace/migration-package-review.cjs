'use strict';
// Review manifest only: no SQL execution or deployment authority.
const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process'),{createHash}=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),relative='experiments/project-ace/';
const hash=b=>createHash('sha256').update(b).digest('hex');
const git=(...args)=>execFileSync('git',args,{cwd:root,maxBuffer:16*1024*1024});
const check=(v,m)=>{if(!v)throw Error(m)};
function list(script){
 const m=/^files=\(\n([\s\S]*?)^\)\n/m.exec(script);
 check(m,'Missing explicit migration order');
 const names=m[1].trim().split('\n').map(x=>x.trim());
 check(names.length===22&&new Set(names).size===names.length&&names.every(x=>/^[a-z0-9-]+\.sql$/.test(x)),'Invalid migration order');
 check(names[0]==='postgres-review.sql'&&names.at(-1)==='cutover-pilot-control-review.sql','Invalid migration boundaries');
 return names;
}
function manifest(){
 const candidate=git('rev-parse','HEAD').toString().trim();
 check(/^[a-f0-9]{40}$/.test(candidate),'Invalid candidate revision');
 function bytes(name){
  const file=path.join(__dirname,name);check(fs.lstatSync(file).isFile(),'Not a regular package file: '+name);
  const committed=git('show',candidate+':'+relative+name),actual=fs.readFileSync(file);
  check(committed.equals(actual),'Working tree differs from candidate: '+name);return actual;
 }
 const installer=bytes('migration-rehearsal.sh');
 const entries=list(installer.toString()).map((filename,i)=>{
  const b=bytes(filename),s=b.toString(),lines=s.split(/\r?\n/).filter(x=>x==='BEGIN;'||x==='COMMIT;');
  check(lines.join(' ')==='BEGIN; COMMIT;','Invalid transaction wrapper: '+filename);
  return {ordinal:i+1,filename,sha256:hash(b)};
 });
 const body={schema:'ace-disposable-migration-manifest-v1',candidate_sha:candidate,installer_sha256:hash(installer),verifier_sha256:hash(bytes('migration-rehearsal-verify.sql')),entries,review_only:true,production_ready:false,activation_authorized:false};
 return {...body,manifest_sha256:hash(JSON.stringify(body))};
}
function verifyJournal(expected,journal){
 check(Array.isArray(journal),'Missing installed journal');
 assert.deepEqual(journal,expected.entries,'Installed migration journal differs from candidate');
 return {status:'disposable_journal_matched',candidate_sha:expected.candidate_sha,manifest_sha256:expected.manifest_sha256,entries:journal.length,production_ready:false};
}
if(require.main===module){
 const mode=process.argv[2];check(['manifest','verify'].includes(mode),'Expected manifest or verify');
 const expected=manifest();
 if(mode==='manifest')console.log(JSON.stringify(expected,null,2));
 else {check(process.argv.length===5,'Usage: migration-package-review.cjs verify manifest.json journal.json');assert.deepEqual(JSON.parse(fs.readFileSync(process.argv[3],'utf8')),expected,'Candidate manifest changed');console.log(JSON.stringify(verifyJournal(expected,JSON.parse(fs.readFileSync(process.argv[4],'utf8')))));}
}
module.exports={manifest,list,verifyJournal};
