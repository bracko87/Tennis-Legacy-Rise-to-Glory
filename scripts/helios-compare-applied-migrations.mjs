// Helios H08: offline comparison of checked-in SQL migrations with version/name
// metadata captured READ-ONLY from Supabase migration history.
// Never connects to Supabase or executes recovered SQL.
import {readFileSync,readdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const snapshot=JSON.parse(readFileSync(resolve(root,'tests/recovered-migrations/applied-migration-manifest-20261120.json'),'utf8'));
const fileNames=readdirSync(resolve(root,'supabase/migrations')).filter(x=>x.endsWith('.sql')).sort();
const found=new Map();
for(const file of fileNames){
 const match=file.match(/^(\d{14})_(.+)\.sql$/);
 if(!match)throw Error('Unexpected migration filename: '+file);
 if(found.has(match[1]))throw Error('Duplicate migration version in repository: '+match[1]);
 found.set(match[1],match[2]);
}
const recovered=readFileSync(resolve(root,'tests/recovered-migrations/20260903072608_staff_market_contracts_effects_and_scouting_foundation.sql'),'utf8');
const original=recovered.slice(recovered.indexOf('\n\n')+2);
const digest=createHash('md5').update(original).digest('hex');
if(digest!=='d510f7741eb0959317c9534d1a7a5c14')
 throw Error('Authoritative recovered staff SQL fingerprint mismatch: '+digest);
if(!original.includes('create table if not exists public.staff_members'))
 throw Error('Original staff base table creation missing in archive');
if(found.has('20260903072608'))
 throw Error('Recovered source now also checked in as normal migration; inspect duplicate before deploying');

const entries=snapshot.versions;
if(entries.length!==812||new Set(entries.map(x=>x.version)).size!==entries.length)
 throw Error('Unexpected captured migration history version count/duplicates');
const appliedSet=new Set(entries.map(x=>x.version));
const missing=entries.filter(x=>!found.has(x.version));
const repositoryOnly=[...found.entries()].filter(([version])=>!appliedSet.has(version));
const renamed=entries.filter(x=>found.has(x.version)&&found.get(x.version)!==x.name);
const beforeStaff=missing.filter(x=>x.version<'20260903081216');
const byName=new Map();
for(const [version,name] of found.entries()){
 const matches=byName.get(name)||[];
 matches.push(version);
 byName.set(name,matches);
}
const differentTimestampSameName=missing.filter(x=>byName.has(x.name));
const genuinelyAbsent=missing.filter(x=>!byName.has(x.name));
const nameAmbiguity=differentTimestampSameName.filter(x=>byName.get(x.name).length!==1);
const beforeStaffGenuine=genuinelyAbsent.filter(x=>x.version<'20260903081216');
console.log('=== HELIOS H08 MIGRATION HISTORY GAP DIAGNOSTIC ===');
console.log('Applied Supabase versions:',entries.length);
console.log('Repository migration files:',fileNames.length);
console.log('Applied versions absent from repository:',missing.length);
console.log('Repository versions absent from applied snapshot:',repositoryOnly.length);
console.log('Matching version with differing descriptive names:',renamed.length);
console.log('Applied versions absent before first staff reference (timestamp only):',beforeStaff.length);
console.log('Applied absent versions with an existing same-name repo migration:',differentTimestampSameName.length);
console.log('Applied sources missing by BOTH version and name:',genuinelyAbsent.length);
console.log('Ambiguous same-name version mappings:',nameAmbiguity.length);
console.log('Applied sources missing by both version and name before first staff reference:',beforeStaffGenuine.length);
console.log('Verified original staff foundation SQL MD5:',digest);
console.log('First 30 applied versions absent from repo (timestamp-only):');
for(const x of missing.slice(0,30))console.log('  '+x.version+'_'+x.name+'.sql');
console.log('First 30 applied migration sources missing by both timestamp and name:');
for(const x of genuinelyAbsent.slice(0,30))console.log('  '+x.version+'_'+x.name+'.sql');
console.log('First 15 matching names with different timestamps:');
for(const x of differentTimestampSameName.slice(0,15))console.log('  applied='+x.version+' repo='+byName.get(x.name).join(',')+' name='+x.name);
if(repositoryOnly.length){
 console.log('Repository-only versions (first 20; may be future/unapplied migrations):');
 for(const [v,n] of repositoryOnly.slice(0,20))console.log('  '+v+'_'+n+'.sql');
}
console.log('=== END DIAGNOSTIC ===');
// Never fail just because migrations are missing: this is a diagnostic.
// Always fail if baseline, archive fidelity, or manifest integrity changes.
