// Isolated build alias: no actual Supabase module or credentials.
export const supabase={rpc:async(name:string,args:{p_match_id:string})=>{
 if(args.p_match_id!=='review-match'||!['get_tournament_match_detail_v1','get_tournament_match_replay_v1'].includes(name))throw Error('Unexpected RPC')
 const response=await fetch('/fixture/'+name)
 if(!response.ok)throw Error('Fixture request failed')
 return {data:await response.json(),error:null}
}}
