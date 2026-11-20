// Helios: verify nine original migration sources recovered from the existing
// Supabase applied-migration registry. No DB connection or SQL execution.
// Sources are intentionally NONDEPLOYABLE; full historical replay remains blocked.
import {readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const base=resolve(root,'tests/recovered-migrations/applied-divergences');
const manifest=JSON.parse(readFileSync(resolve(base,'manifest.json'),'utf8'));
const registered=JSON.parse(readFileSync(resolve(root,'tests/recovered-migrations/known-applied-sql-divergences.json'),'utf8'));
if(manifest.sources.length!==9||registered.mismatches.length!==9||registered.safe_to_replay!==false)
 throw Error('Nine-source archive cannot remove historical replay gate');
const seen=new Set();
for(const x of manifest.sources){
 if(seen.has(x.name))throw Error('Duplicate recovered migration: '+x.name);
 seen.add(x.name);
 if(!/^\d{14}$/.test(x.version)||!/^\w+$/.test(x.name)||
 x.path!==`tests/recovered-migrations/applied-divergences/${x.version}_${x.name}.sql`)
 throw Error('Unsafe recovered source location: '+x.path);
 const sql=readFileSync(resolve(root,x.path),'utf8');
 const hash=createHash('md5').update(sql).digest('hex');
 if(hash!==x.md5||sql.length!==x.length)
 throw Error('Applied source not byte-for-byte equivalent: '+x.name);
 if(!registered.mismatches.some(m=>m.name===x.name&&m.replay_blocker===true&&m.review_status==='REVIEW_REQUIRED'))
 throw Error('Recovered SQL source lacks safety blocker: '+x.name);
 if(x.path.startsWith('supabase/migrations/'))
 throw Error('Archived source must not be auto deployed');
 console.log('RECOVERED_VERIFIED '+x.version+'_'+x.name+' '+hash);
}
console.log('PASS: all 9 original applied SQL sources archived and verified. Full-schema historical replay remains BLOCKED.');
