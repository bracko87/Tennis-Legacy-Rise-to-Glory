'use strict';
const assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const clean={...process.env};delete clean.TL_SUPABASE_URL;delete clean.TL_SUPABASE_PUBLISHABLE_KEY;
function reject(args,env){
 const r=spawnSync(process.execPath,['scripts/build.mjs',...args],{encoding:'utf8',env:{...clean,TL_ACE_REVIEW:'1',...env}});
 assert.notEqual(r.status,0);assert.match(r.stderr,/Project Ace review requires an explicit loopback Supabase backend and a non-production build/);
}
reject(['--production'],{});
reject(['--compile-local'],{});
reject(['--compile-local'],{TL_SUPABASE_URL:'https://example.supabase.co',TL_SUPABASE_PUBLISHABLE_KEY:'dummy'});
console.log('PASS review flag rejects production and non-loopback backend builds');
