'use strict';
// Local Supabase authentication adapter. Never trust a browser-supplied user ID or role.
function localBackend(raw){
 const u=new URL(raw);
 if(u.protocol!=='http:'||!['127.0.0.1','localhost','[::1]'].includes(u.hostname)||u.username||u.password||u.pathname!=='/'||u.search||u.hash)throw Error('Ace requires local Supabase URL');
 return u.origin;
}
function makeAuth({url,key,adminId,syntheticId=null,multiplayerTest=false,fetcher=globalThis.fetch}){
 const origin=localBackend(url);
 if(typeof key!=='string'||!key||key.startsWith('sb_secret_')||!adminId||adminId===syntheticId)throw Error('Invalid local authentication configuration');
 // Accept local anon JWT or publishable key only. Reject service-role JWTs.
 if(key.split('.').length===3){
  const claims=JSON.parse(Buffer.from(key.split('.')[1],'base64url').toString('utf8'));
  if(claims.role!=='anon')throw Error('Use anon/publishable key only');
 }else if(!key.startsWith('sb_publishable_'))throw Error('Use anon/publishable key only');
 const policy={enabled:true,adminId,syntheticId,multiplayerTest};
 async function authenticate(header){
  if(typeof header!=='string'||!/^Bearer [A-Za-z0-9._~-]+$/.test(header))return null;
  const headers={apikey:key,Authorization:header};
  const res=await fetcher(origin+'/auth/v1/user',{headers,redirect:'error',signal:AbortSignal.timeout(5000)});
  if(!res.ok)return null;
  const user=await res.json();
  if(user.is_anonymous===true||!user.id)return null;
  if(user.id===adminId){
   const role=await fetcher(origin+'/rest/v1/rpc/is_app_admin_v1',{method:'POST',headers:{...headers,'Content-Type':'application/json'},body:'{}',redirect:'error',signal:AbortSignal.timeout(5000)});
   if(!role.ok||await role.json()!==true)return null;
   return {id:user.id,verified:true,isAdmin:true};
  }
  if(multiplayerTest&&user.id===syntheticId)return {id:user.id,verified:true,synthetic:true};
  return null;
 }
 return {policy,authenticate,origin};
}
module.exports={localBackend,makeAuth};
