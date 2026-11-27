'use strict';
// Explicit offline file ingestion. No database transport, no network, no production authorization.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {evaluate}=require('./authentic-shadow-evidence.cjs');
const check=(v,m)=>{if(!v)throw Error(m)};
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function load(directory){
 const root=path.resolve(directory);check(fs.lstatSync(root).isDirectory(),'Package must be a real directory');
 let total=0;const seen=new Set();
 function read(name,expected,max){
  check(typeof name==='string'&&/^[A-Za-z0-9_-]{1,100}\.json$/.test(name),'Invalid package filename');
  check(!seen.has(name),'Duplicate package filename');seen.add(name);
  const filename=path.join(root,name);
  check(fs.lstatSync(filename).isFile(),'Package file must be a regular file');
  const fd=fs.openSync(filename,fs.constants.O_RDONLY|(fs.constants.O_NOFOLLOW||0)|(fs.constants.O_NONBLOCK||0));
  try{
   const st=fs.fstatSync(fd);check(st.isFile()&&st.size>0&&st.size<=max,'Invalid package file size or type');
   total+=st.size;check(total<=256*1024*1024,'Package exceeds size limit');
   const b=Buffer.alloc(st.size);let pos=0;
   while(pos<b.length){const count=fs.readSync(fd,b,pos,b.length-pos,null);check(count>0,'Package changed during reading');pos+=count;}
   check(fs.readSync(fd,Buffer.alloc(1),0,1,null)===0&&fs.fstatSync(fd).size===st.size,'Package changed during reading');
   if(expected!==null)check(typeof expected==='string'&&hash(b)===expected,'Package file integrity mismatch');
   return b;
  }finally{fs.closeSync(fd);}
 }
 const manifestBytes=read('manifest.json',null,4*1024*1024),manifest=JSON.parse(manifestBytes);
 check(manifest.schema==='ace-shadow-package-v1'&&manifest.review_only===true,'Invalid package manifest');
 check(Array.isArray(manifest.cases)&&manifest.cases.length>0&&manifest.cases.length<=10000,'Invalid package inventory');
 const item=(x,max)=>{check(x&&typeof x==='object'&&typeof x.sha256==='string'&&/^[a-f0-9]{64}$/.test(x.sha256),'Invalid file descriptor hash');return read(x.file,x.sha256,max);};
 const catalog=x=>({bytes:item(x.catalog,64*1024*1024),receipt:JSON.parse(item(x.receipt,4*1024*1024))});
 const restore=catalog(manifest.restore),reference=catalog(manifest.reference);
 const cases=manifest.cases.map(x=>JSON.parse(item(x,2*1024*1024)));
 const r=evaluate({restore,reference,restore_id:manifest.restore_id,cases});
 return {...r,package_manifest_sha256:hash(manifestBytes),package_bytes:total};
}
if(require.main===module){
 try{
  check(process.argv.length===4,'Usage: authentic-shadow-package.cjs package-directory output.json');
  check(process.env.ACE_SHADOW_PACKAGE_REVIEW==='offline-review-only','Explicit offline review opt-in required');
  const result=load(process.argv[2]);
  fs.writeFileSync(process.argv[3],JSON.stringify(result,null,2)+'\n',{flag:'wx',mode:0o600});
  console.log(JSON.stringify({status:result.status,production_ready:false}));
  process.exitCode=2;
 }catch(e){console.error(e.message);process.exitCode=2;}
}
module.exports={load};
