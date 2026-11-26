'use strict';
// Separate opt-in local review browser; never reads a production connection URL.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {open}=require('./postgres-store.cjs'),{makeOfflineAuth}=require('./start-offline.cjs'),{serve}=require('./postgres-http.cjs');
async function main(){
 const email=(process.env.ACE_ADMIN_EMAIL||'').trim().toLowerCase();
 if(!email.includes('@')||email==='ace-peer@example.invalid')throw Error('Set ACE_ADMIN_EMAIL');
 const id=process.env.ACE_REVIEW_WORLD_ID;if(!id)throw Error('Set ACE_REVIEW_WORLD_ID');
 const store=open(id),peerEnabled=process.env.ACE_TOURNAMENT_PEER==='1';
 const password=crypto.randomBytes(18).toString('base64url'),peerPassword=peerEnabled?crypto.randomBytes(18).toString('base64url'):null;
 const auth=makeOfflineAuth({email,password,peerPassword});
 const existing=await store.read();
 if(existing&&(existing.state.draw.owner!==auth.policy.adminId||(existing.state.draw.peerOwner??null)!==auth.policy.syntheticId))throw Error('Existing review world belongs to a different test configuration');
 const reactDir=path.join(__dirname,'react-dist');if(!['index.html','react.js','react.css'].every(f=>fs.existsSync(path.join(reactDir,f))))throw Error('Build the isolated React pilot first');
 const privatePlayer=process.env.ACE_PLAYER_FILE?JSON.parse(fs.readFileSync(process.env.ACE_PLAYER_FILE,'utf8')):null;
 if(privatePlayer){if(privatePlayer.schema!=='ace-player-v1')throw Error('Invalid private profile');require('./legacy-snapshot.cjs').importPlayer(privatePlayer,'hard');}
 console.log('Local administrator: '+email+'\nTemporary local password: '+password);
 if(peerPassword)console.log('Synthetic peer: ace-peer@example.invalid\nTemporary local peer password: '+peerPassword);
 serve({auth,store,reactDir,privatePlayer});
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
