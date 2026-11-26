'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const lifecycle=require('./tournament-lifecycle.cjs');
// Dedicated directory, not the existing fixture.json store. Exclusive process lock.
function open(dir,initial,{advance=lifecycle.advance,kind=null}={}){
 if(!path.isAbsolute(dir))throw Error('Use an absolute private tournament state directory');
 fs.mkdirSync(dir,{recursive:true,mode:0o700});
 const lock=path.join(dir,'tournament.lock'),file=path.join(dir,'tournament.json');
 const fd=fs.openSync(lock,'wx',0o600);let closed=false;
 const check=()=>{if(closed)throw Error('Store closed');};
 const read=()=>{check();return JSON.parse(fs.readFileSync(file,'utf8'));};
 const save=s=>{
  check();if(!s||s.version!==1||(s.kind??null)!==kind)throw Error('Unexpected state kind');
  const serialized=JSON.stringify(s);if(typeof serialized!=='string')throw Error('Invalid state');
  const tmp=file+'.'+crypto.randomUUID()+'.tmp';let f;
  try{f=fs.openSync(tmp,'wx',0o600);fs.writeFileSync(f,serialized);fs.fsyncSync(f);fs.closeSync(f);f=undefined;fs.renameSync(tmp,file);}
  finally{if(f!==undefined)fs.closeSync(f);if(fs.existsSync(tmp))fs.unlinkSync(tmp);}
 };
 const close=()=>{if(!closed){closed=true;fs.closeSync(fd);fs.unlinkSync(lock);}};
 try{if(!fs.existsSync(file)){if(!initial)throw Error('No tournament state');if(initial.version!==1||(initial.kind??null)!==kind)throw Error('Unexpected state kind');save(initial);}else{const s=read();if(s.version!==1||(s.kind??null)!==kind)throw Error('Unknown state version or kind');}}
 catch(e){close();throw e;}
 return {read,save,close,tick:now=>{const s=advance(read(),now);save(s);return s;}};
}
module.exports={open};
