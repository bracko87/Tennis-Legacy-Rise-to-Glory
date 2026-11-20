// Helios H08: investigate migration replay dependency ordering.
// Offline read of repository SQL files only. Does not connect to Supabase,
// run migrations, modify schema, or change a historical migration.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { resolve, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const folder=resolve(root,'supabase/migrations');
if(!existsSync(folder))throw new Error('No supabase/migrations directory in repository');
const files=readdirSync(folder).filter(x=>x.endsWith('.sql')).sort();
if(!files.length)throw new Error('No SQL migrations found');
const table='staff_members';
const reference=/\b(?:public\s*\.\s*)?staff_members\b/ig;
const definition=/\bCREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:"?public"?\s*\.\s*)?"?staff_members"?\b/i;
const entries=[];
for (let i=0;i<files.length;i++){
 const filename=files[i];
 const full=resolve(folder,filename);
 const lines=readFileSync(full,'utf8').split(/\r?\n/);
 const matches=[];
 for(let j=0;j<lines.length;j++){
  const line=lines[j];
  if (reference.test(line)){
    matches.push({line:j+1,kind:definition.test(line)?'CREATE_TABLE':'REFERENCE',excerpt:line.trim().slice(0,180)});
  }
  reference.lastIndex=0;
 }
 if(matches.length)entries.push({i,filename,matches});
}
console.log('=== HELIOS MIGRATION ORDER DIAGNOSTIC (READ ONLY) ===');
console.log('SQL migrations:',files.length);
console.log('Files mentioning '+table+':',entries.length);
for(const item of entries){
 console.log('\n'+item.filename+' (position '+(item.i+1)+'/'+files.length+')');
 for(const m of item.matches.slice(0,12))console.log('  '+m.kind+' line '+m.line+': '+m.excerpt);
 if(item.matches.length>12)console.log('  ... plus '+(item.matches.length-12)+' more occurrences');
}
const earliestDefinition=entries.flatMap(e=>e.matches.filter(m=>m.kind==='CREATE_TABLE').map(m=>({...m,filename:e.filename,i:e.i})))
 .sort((a,b)=>a.i-b.i||a.line-b.line)[0];
const earliestReference=entries.flatMap(e=>e.matches.filter(m=>m.kind==='REFERENCE').map(m=>({...m,filename:e.filename,i:e.i})))
 .sort((a,b)=>a.i-b.i||a.line-b.line)[0];
console.log('\n=== DIAGNOSIS ===');
console.log('Earliest CREATE TABLE line:',earliestDefinition?earliestDefinition.filename+':'+earliestDefinition.line:'NOT FOUND BY SCANNER');
console.log('Earliest other reference:',earliestReference?earliestReference.filename+':'+earliestReference.line:'NONE');
if(earliestReference&&(!earliestDefinition||earliestReference.i<earliestDefinition.i
 ||(earliestReference.i===earliestDefinition.i&&earliestReference.line<earliestDefinition.line))){
 console.log('WARNING: textual reference precedes first detected definition. Could be a comment, function body, or real migration-order dependency; inspect SQL context.');
}
console.log('Limitations: textual scanner cannot parse dynamic SQL, views, split CREATE statements, search_path resolution, or implicit dependencies. This diagnostic is NOT a complete migration replay.');
console.log('=== END ===');
