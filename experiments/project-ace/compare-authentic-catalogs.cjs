'use strict';
const fs=require('node:fs'),crypto=require('node:crypto'),{isDeepStrictEqual}=require('node:util'),{inspect,compare}=require('./restored-schema-gate.cjs');
function verify(bytes,receipt,mode){
 if(!Buffer.isBuffer(bytes)||bytes.length===0||bytes.length>64*1024*1024)throw Error('Invalid catalog bytes');
 if(!receipt||receipt.schema!=='ace-catalog-receipt-v1'||receipt.mode!==mode||receipt.production_ready!==false||receipt.provenance!=='operator_supplied_not_authenticated')throw Error('Invalid capture receipt');
 if(typeof receipt.source_label!=='string'||!/^[a-zA-Z0-9_-]{1,80}$/.test(receipt.source_label))throw Error('Invalid source label');
 if(typeof receipt.captured_at!=='string'||!Number.isFinite(Date.parse(receipt.captured_at))||new Date(receipt.captured_at).toISOString()!==receipt.captured_at)throw Error('Invalid capture timestamp');
 const hash=crypto.createHash('sha256').update(bytes).digest('hex');
 if(receipt.sha256!==hash)throw Error('Catalog integrity mismatch');
 const catalog=JSON.parse(bytes.toString('utf8'));
 if(!isDeepStrictEqual(inspect(catalog),receipt.issues))throw Error('Receipt findings mismatch');
 return {catalog,receipt};
}
function assess(restored,reference){
 if(restored.receipt.mode!=='restore'||reference.receipt.mode!=='reference')throw Error('Capture modes mismatch');
 if(restored.receipt.source_label.toLowerCase()===reference.receipt.source_label.toLowerCase())throw Error('Separate source labels required');
 const r=compare(restored.catalog,reference.catalog);
 return {...r,reference_sha256:reference.receipt.sha256,restored_sha256:restored.receipt.sha256,source_identity_verified:false,requires_manual_review:true,production_ready:false};
}
function load(file,mode){return verify(fs.readFileSync(file),JSON.parse(fs.readFileSync(file+'.receipt.json','utf8')),mode);}
if(require.main===module){
 try{
  const [restored,reference]=process.argv.slice(2);
  if(process.argv.length!==4)throw Error('Usage: compare-authentic-catalogs.cjs restored.json reference.json');
  const r=assess(load(restored,'restore'),load(reference,'reference'));console.log(JSON.stringify(r,null,2));
  // Even a catalog match is evidence for review, never approval.
  process.exitCode=2;
 }catch(e){console.error(e.message);process.exitCode=2;}
}
module.exports={verify,assess,load};
