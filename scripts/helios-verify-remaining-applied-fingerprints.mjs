// Helios H08: compare 211 applied migration SQL fingerprints to same-name
// repo migration files. Reads only committed source and token fingerprints.
// Fingerprints are non-cryptographic FNV-1a/64 used only as drift signals.
// This is NOT a semantic SQL parser and does not replay migrations.
import {readFileSync,existsSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const base=resolve(root,'tests/recovered-migrations');
const sourceDir=resolve(root,'supabase/migrations');

function tokens(sql){
 const expression=/(?:--[^\r\n]*|\/\*[\s\S]*?\*\/)|(?:'(?:''|[^'])*'|"(?:""|[^"])*"|\$[A-Za-z0-9_]*\$[\s\S]*?\$[A-Za-z0-9_]*\$)|(?:[A-Za-z_][A-Za-z0-9_$]*|[0-9]+(?:\.[0-9]+)?)|(?:\s+)|(?:.)/g;
 const output=[];let covered=0;
 for(const match of sql.matchAll(expression)){
  const token=match[0];covered+=token.length;
  if(/^\s+$/.test(token)||token.startsWith('--')||token.startsWith('/*'))continue;
  const delimiter=token.startsWith('$')?token.match(/^\$[A-Za-z0-9_]*\$/)?.[0]:null;
  if(delimiter&&token.length>=delimiter.length*2&&token.endsWith(delimiter))
   output.push(delimiter,...tokens(token.slice(delimiter.length,-delimiter.length)),delimiter);
  else output.push(token);
 }
 if(covered!==sql.length)throw Error('SQL tokenizer skipped characters');
 return output;
}
function fnv64(values){
 let hash=0xcbf29ce484222325n;
 for(const value of values){
  for(let i=0;i<value.length;i++){
   hash^=BigInt(value.charCodeAt(i));
   hash=BigInt.asUintN(64,hash*0x100000001b3n);
  }
  hash=BigInt.asUintN(64,hash*0x100000001b3n);
 }
 return hash.toString(16).padStart(16,'0');
}
const all=[],seen=new Set();
for(let group=1;group<=6;group++){
 const file=resolve(base,'remaining-applied-fingerprints-'+String(group).padStart(2,'0')+'.json');
 const data=JSON.parse(readFileSync(file,'utf8'));
 if(data.batch!==group||data.expected_groups!==6)throw Error('Invalid fingerprint group '+group);
 for(const item of data.items){
  if(seen.has(item.name))throw Error('Duplicate migration '+item.name);
  if(!/^\d{14}_[a-zA-Z0-9_]+\.sql$/.test(item.repo_file)
    ||item.repo_file.slice(15,-4)!==item.name)
   throw Error('Invalid migration path '+item.repo_file);
  if(!/^\d{14}$/.test(item.applied_version))throw Error('Invalid applied version');
  seen.add(item.name);all.push(item);
 }
}
if(all.length!==211)throw Error('Expected exactly 211 remaining same-name timestamp-renamed migrations; got '+all.length);
const knownData=JSON.parse(readFileSync(resolve(base,'known-applied-sql-divergences.json'),'utf8'));
if(knownData.safe_to_replay!==false||knownData.review_status!=='REVIEW_REQUIRED'||knownData.mismatches.length!==9)
 throw Error('Missing or prematurely approved migration replay divergence register');
const known=new Map(knownData.mismatches.map(x=>[x.name,x]));
if(known.size!==9)throw Error('Duplicate reviewed divergence name');
const mismatches=[],same=[],missing=[];
for(const item of all){
 const path=resolve(sourceDir,item.repo_file);
 if(!existsSync(path)){missing.push(item.repo_file);continue}
 const actual=tokens(readFileSync(path,'utf8'));
 const checksum=fnv64(actual);
 if(checksum!==item.fnv64||actual.length!==item.tokens)
  mismatches.push({name:item.name,applied_version:item.applied_version,repo_file:item.repo_file,expected_tokens:item.tokens,repo_tokens:actual.length,repo_hash:checksum});
 else same.push(item.name);
}
console.log('=== HELIOS H08 RENAMED MIGRATION FINGERPRINT COMPARISON ===');
console.log('Applied migration fingerprints checked:',all.length);
console.log('SQL token-equivalent:',same.length);
console.log('SQL token mismatches:',mismatches.length);
console.log('Repository files missing:',missing.length);
for(const item of mismatches.slice(0,100))
 console.log('REPLAY_BLOCKER_TOKEN_MISMATCH '+JSON.stringify(item));
for(const file of missing.slice(0,50))console.log('MISSING_FILE '+file);
const unexpected=mismatches.filter(item=>{
 const reviewed=known.get(item.name);
 return !reviewed||reviewed.repo_token_fingerprint!==item.repo_hash
   ||reviewed.review_status!=='REVIEW_REQUIRED'||reviewed.replay_blocker!==true;
});
const resolved=[...known.keys()].filter(name=>!mismatches.some(x=>x.name===name));
if(unexpected.length||missing.length||resolved.length||mismatches.length!==9)
 throw Error('Applied SQL drift review changed: '+unexpected.length+' unexpected, '+
 missing.length+' missing, '+resolved.length+' resolved without review; keep historical migration replay BLOCKED');
console.log('AUDIT PASS: 202 token-equivalent and 9 KNOWN REVIEW_REQUIRED replay blockers; total 211 checked.');
console.log('FULL HISTORICAL MIGRATION REPLAY IS STILL BLOCKED: nine applied-vs-repository SQL differences require explicit reconciliation.');
// Note: coverage by source names does not prove original SQL byte identity,
// correct migration timestamps, or replay against a full Supabase environment.
