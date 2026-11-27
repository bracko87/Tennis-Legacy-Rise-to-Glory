'use strict';
// Offline evidence consistency only. No claims of authenticated provenance.
const {verify,assess}=require('./compare-authentic-catalogs.cjs');
const {normalized}=require('./legacy-shadow-capture.cjs');
const {digest}=require('./shadow-comparison.cjs');
const {report}=require('./shadow-cohort-review.cjs');
const check=(v,m)=>{if(!v)throw Error(m)};
const signature=x=>x.startsWith('public.')?x:'public.'+x;
function evaluate({restore,reference,restore_id,cases}){
 const a=verify(restore.bytes,restore.receipt,'restore'),b=verify(reference.bytes,reference.receipt,'reference');
 const catalog=assess(a,b);
 if(catalog.status!=='catalog_match_review_only')return {schema:'ace-linked-shadow-review-v1',status:'blocked_catalog_review',catalog,production_ready:false,legacy_authority_verified:false};
 check(typeof restore_id==='string'&&restore_id.length>0&&restore_id.length<=120,'Missing restore identity');
 check(Array.isArray(cases)&&cases.length>0&&cases.length<=10000,'Invalid capture inventory');
 const fingerprints=new Map(a.catalog.routines.map(x=>[signature(x.signature),x.hash]));
 const seen=new Set(),pairs=[],manifest=[];
 for(const c of cases){
  check(c.capture.restore_id===restore_id,'Restore identity mismatch');
  check(c.link?.restored_catalog_sha256===a.receipt.sha256&&c.link?.reference_catalog_sha256===b.receipt.sha256,'Catalog linkage mismatch');
  check(!/^synthetic[-_]/i.test(c.capture.simulation?.engine_version||''),'Synthetic engine is not an authentic observation');
  const id=JSON.stringify([c.input.competition_id,c.input.match_id,c.input.source_revision]);
  check(!seen.has(id),'Duplicate capture identity');seen.add(id);
  for(const x of c.capture.routines)check(fingerprints.get(signature(x.signature))===x.definition_md5,'Routine catalog fingerprint mismatch: '+x.signature);
  const n=normalized(c.input,c.capture,c.link);
  pairs.push({input:c.input,reference:n.observation,cohort:c.cohort,reference_kind:'supplied_legacy_observation',focal_player_id:c.focal_player_id??null});
  manifest.push({id,input_sha256:c.input.input_sha256,capture_sha256:n.capture_sha256,link_sha256:n.link_sha256});
 }
 manifest.sort((x,y)=>x.id.localeCompare(y.id));
 return {schema:'ace-linked-shadow-review-v1',status:'linked_cohort_review_only',catalog,restore_id,manifest_sha256:digest(manifest),cohort:report(pairs),production_ready:false,legacy_authority_verified:false,limitations:['Catalog and capture hashes establish consistency, not source authenticity','Pre-match attestation requires independent verification','No production authorization']};
}
module.exports={evaluate};
