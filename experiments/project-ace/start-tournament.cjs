'use strict';
const path=require('node:path'),os=require('node:os'),crypto=require('node:crypto'),fs=require('node:fs');
const {makeOfflineAuth}=require('./start-offline.cjs'),{serve}=require('./tournament-http.cjs');
const email=(process.env.ACE_ADMIN_EMAIL||'').trim().toLowerCase();
if(!email.includes('@')||email==='ace-peer@example.invalid')throw Error('Set ACE_ADMIN_EMAIL to your local pilot email');
const root=path.join(os.homedir(),'.tennis-ace-offline-v1');
fs.mkdirSync(root,{recursive:true,mode:0o700});
const identity=path.join(root,'identity.json');
if(fs.existsSync(identity)){if(JSON.parse(fs.readFileSync(identity,'utf8')).email!==email)throw Error('Different pilot identity');}
else fs.writeFileSync(identity,JSON.stringify({email}),{flag:'wx',mode:0o600});
const playerFile=process.env.ACE_PLAYER_FILE;
const privatePlayer=playerFile?JSON.parse(fs.readFileSync(playerFile,'utf8')):null;
if(privatePlayer){if(privatePlayer.schema!=='ace-player-v1')throw Error('Invalid private player schema');require('./legacy-snapshot.cjs').importPlayer(privatePlayer,'hard');}
const reactDir=path.join(__dirname,'react-dist');
const useReact=['index.html','react.js','react.css'].every(f=>fs.existsSync(path.join(reactDir,f)));
const world=process.env.ACE_WORLD_TEST==='1';
const password=crypto.randomBytes(18).toString('base64url');
const peerPassword=process.env.ACE_TOURNAMENT_PEER==='1'?crypto.randomBytes(18).toString('base64url'):null;
if(peerPassword)console.log('Synthetic peer: ace-peer@example.invalid\nTemporary local peer password: '+peerPassword);
console.log('Private tournament login: '+email+'\nTemporary local password: '+password);
serve({auth:makeOfflineAuth({email,password,peerPassword}),driver:world?require('./world-demo.cjs'):undefined,stateKind:world?'world':'draw',port:world?8767:8766,dir:path.join(root,(world?'world-v1-':'')+(privatePlayer?'private-player-draw-v1':'draw-v1')+(peerPassword?'-multiplayer':'')),privatePlayer,reactDir:useReact?reactDir:null});
if(useReact)console.log('Tennis Legacy React pilot: http://127.0.0.1:'+(world?8767:8766)+'/react');
console.log(privatePlayer?'Private imported profile (new isolated draw only)':'Synthetic test profiles');
