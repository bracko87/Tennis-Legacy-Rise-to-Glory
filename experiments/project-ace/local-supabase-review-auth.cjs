'use strict';
// Auth validates against the explicitly configured loopback Supabase gateway.
// Only the exact allowlisted account with server-confirmed admin membership is accepted.
function createAuth({url,key,userId,fetcher=fetch}){
 if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(url)||!key||!(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(userId)))throw Error('Explicit isolated Supabase configuration required');
 const policy={enabled:true,adminId:userId,multiplayerTest:false,syntheticId:null};
 async function authenticate(header){
  if(typeof header!=='string'||header.length>8192||!/^Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(header))return null;
  const headers={apikey:key,Authorization:header,'Content-Type':'application/json'};
  try{
   const response=await fetcher(url+'/auth/v1/user',{headers,redirect:'error',signal:AbortSignal.timeout(5000)});
   if(!response.ok)return null;
   const user=await response.json();if(user.id!==userId||user.is_anonymous!==false)return null;
   const check=await fetcher(url+'/rest/v1/rpc/is_app_admin_v1',{method:'POST',headers,body:'{}',redirect:'error',signal:AbortSignal.timeout(5000)});
   if(!check.ok||await check.json()!==true)return null;
   return {id:userId,verified:true,isAdmin:true};
  }catch{return null;}
 }
 return {policy,authenticate};
}
module.exports={createAuth};
