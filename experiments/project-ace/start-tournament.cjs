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
const password=crypto.randomBytes(18).toString('base64url');
console.log('Private tournament login: '+email+'\nTemporary local password: '+password);
serve({auth:makeOfflineAuth({email,password}),dir:path.join(root,'draw-v1')});
