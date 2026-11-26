'use strict';
const assert=require('node:assert/strict');
const {makeAuth,localBackend}=require('./local-auth.cjs');
async function run(){
 assert.throws(()=>localBackend('https://production.supabase.co'));
 assert.throws(()=>localBackend('http://localhost.evil.com'));
 assert.throws(()=>localBackend('http://localhost:54321/other'));
 assert.equal(localBackend('http://127.0.0.1:54321'),'http://127.0.0.1:54321');
 const cfg={url:'http://127.0.0.1:54321',key:'sb_publishable_local_fixture',adminId:'admin',syntheticId:'peer',multiplayerTest:true};
 assert.throws(()=>makeAuth({...cfg,key:'sb_secret_test'}));
 let role=true,calls=[];
 const fetcher=async(url,opt)=>{calls.push({url,opt});const token=opt.headers.Authorization;const id=token.slice(7);return {ok:!['expired','unknown'].includes(id),json:async()=>url.endsWith('/user')?{id,is_anonymous:id==='anonymous'}:role};};
 const a=makeAuth({...cfg,fetcher});
 assert.equal(await a.authenticate(null),null);
 assert.equal(await a.authenticate('admin'),null);
 assert.equal(await a.authenticate('Bearer expired'),null);
 assert.equal(await a.authenticate('Bearer anonymous'),null);
 assert.equal(await a.authenticate('Bearer ordinary'),null);
 assert.deepEqual(await a.authenticate('Bearer admin'),{id:'admin',verified:true,isAdmin:true});
 assert.deepEqual(await a.authenticate('Bearer peer'),{id:'peer',verified:true,synthetic:true});
 role=false;assert.equal(await a.authenticate('Bearer admin'),null);
 assert.equal(await makeAuth({...cfg,multiplayerTest:false,fetcher}).authenticate('Bearer peer'),null);
 assert.ok(calls.every(c=>c.url.startsWith(cfg.url+'/')&&c.opt.redirect==='error'));
 console.log('PASS local backend restriction, token verification, exact allowlist, admin RPC, optional peer, anonymous denial');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
