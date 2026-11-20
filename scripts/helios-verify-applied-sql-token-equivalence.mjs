// H08: SQL token-equivalence guard for applied SQL snapshots vs renamed repo files.
// This does not execute SQL, connect to Supabase or allow a migration to deploy.
// Comments/whitespace outside literals are ignored, including PL/pgSQL bodies.
// NOTE: token equivalence is NOT comprehensive migration equivalence: order and
// environment still need isolated full-schema replay.
import {readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const manifest=JSON.parse(readFileSync(resolve(root,'tests/recovered-migrations/same-name-applied-sources-first-ten.json'),'utf8'));

function tokens(sql){
  // Scan SQL single quoted strings, double quoted identifiers, dollar-quoted
  // PL/pgSQL bodies, line/block comments, whitespace, words and punctuation.
  const expression=/(?:--[^\r\n]*|\/\*[\s\S]*?\*\/)|(?:'(?:''|[^'])*'|"(?:""|[^"])*"|\$[A-Za-z0-9_]*\$[\s\S]*?\$[A-Za-z0-9_]*\$)|(?:[A-Za-z_][A-Za-z0-9_$]*|[0-9]+(?:\.[0-9]+)?)|(?:\s+)|(?:.)/g;
  const output=[];
  let coverage=0;
  for(const match of sql.matchAll(expression)){
    const part=match[0];
    coverage+=part.length;
    if(/^\s+$/.test(part)||part.startsWith('--')||part.startsWith('/*'))continue;
    const delimiter=part.startsWith('$')?part.match(/^\$[A-Za-z0-9_]*\$/)?.[0]:null;
    if(delimiter&&part.length>=2*delimiter.length&&part.endsWith(delimiter)){
      output.push(delimiter,...tokens(part.slice(delimiter.length,-delimiter.length)),delimiter);
    }else output.push(part);
  }
  if(coverage!==sql.length)throw Error('SQL scanner skipped source bytes');
  return output;
}
if(manifest.migrations.length!==10)throw Error('Expected exactly ten authoritative applied sources');
const seen=new Set();
const counts={exact:0,whitespace_only:0,token_equivalent_other_formatting:0};
for(const item of manifest.migrations){
  const {repo_file,name,sql,applied_version}=item;
  if(seen.has(name))throw Error('Duplicate migration name '+name);
  seen.add(name);
  if(!/^\d{14}_[\w]+\.sql$/.test(repo_file)||repo_file.indexOf(name)<0)
    throw Error('Unexpected migration path '+repo_file);
  if(!/^\d{14}$/.test(applied_version))throw Error('Bad applied version');
  const repoSql=readFileSync(resolve(root,'supabase/migrations',repo_file),'utf8');
  if(sql===repoSql){
    counts.exact++;console.log('EXACT '+name);continue;
  }
  if(sql.replace(/\r\n/g,'\n').trim()===repoSql.replace(/\r\n/g,'\n').trim()){
    counts.whitespace_only++;console.log('TRAILING_WHITESPACE '+name);continue;
  }
  const a=tokens(sql),b=tokens(repoSql);
  const max=Math.max(a.length,b.length);
  const mismatch=Array.from({length:max},(_,i)=>i).find(i=>a[i]!==b[i]);
  if(mismatch!==undefined){
    throw Error('MIGRATION SQL TOKEN DRIFT: '+name+
      ' applied version '+applied_version+' vs repo '+repo_file+
      ', first mismatch token '+mismatch+
      ' (applied '+JSON.stringify(a[mismatch]?.slice(0,80))+
      ', repository '+JSON.stringify(b[mismatch]?.slice(0,80))+')');
  }
  counts.token_equivalent_other_formatting++;
  console.log('TOKEN_EQUIVALENT '+name+' ('+a.length+' SQL tokens)');
}
if(counts.exact!==2||counts.whitespace_only!==6||counts.token_equivalent_other_formatting!==2)
 throw Error('Unexpected comparison group counts: '+JSON.stringify(counts));
console.log('PASS: ten applied SQL sources token-equivalent with repo versions; '+JSON.stringify(counts));
