'use strict';
// D8-C3-D: offline, source-shaped equipment and tactic projection. Never an official result.
const {adaptMatch}=require('./legacy-prematch-adapter-review.cjs');
const {digest}=require('./shadow-comparison.cjs'),{importSnapshot}=require('./legacy-snapshot.cjs');
const engine=require('./engine.cjs');
const check=(v,m)=>{if(!v)throw Error(m)};
const clamp=(n,l,h)=>Math.max(l,Math.min(h,n));
const fields=['serve_pct','return_pct','rally_pct','net_pct','focus_pct','stamina_pct','heat_resistance_pct','cold_resistance_pct'];
const slots=['racket','shoes','apparel'];
const options={approach:['Defensive','Balanced','Aggressive'],rally:['Shorten points','Balanced rallies','Extend rallies'],serve:['Safe first serve','Balanced','Power serving','Serve + 1'],servePlacement:['Automatic','Wide','Body','T'],returnGame:['Safe return','Balanced','Aggressive return','Attack second serve'],returnPosition:['Normal','Closer','Deeper'],courtPosition:['Deep baseline','Normal baseline','Inside baseline','Net attack'],target:['Automatic','Backhand','Forehand','Movement','Stamina','Second serve'],risk:['Safe','Balanced','Aggressive']};
const implemented={approach:options.approach,rally:options.rally,serve:options.serve.slice(0,3),returnGame:['Safe return','Balanced','Attack second serve'],target:options.target.slice(0,5)};
const neutralOnly={servePlacement:'Automatic',returnPosition:'Normal',courtPosition:'Normal baseline',risk:'Balanced'};
// SQL migration 20261103213000: explicit raw equipment support, independent missing flags.
// Bounds here are review input hygiene, not authoritative catalogue ranges.
function equipmentProjection(e,temperature){
 check(e&&typeof e.human==='boolean'&&e.support&&e.missing,'Explicit equipment observation required');
 check(Number.isFinite(temperature),'Explicit temperature required');
 const support=Object.fromEntries(fields.map(k=>{const v=e.support[k];check(typeof v==='number'&&Number.isFinite(v)&&Math.abs(v)<=100,'Invalid equipment '+k);return [k,v]}));
 const missing=Object.fromEntries(slots.map(k=>{check(typeof e.missing[k]==='boolean','Missing equipment flag '+k);return [k,e.missing[k]]}));
 check(e.human||slots.every(k=>!missing[k]),'AI cannot have human missing-equipment penalties');
 const climate=temperature>=28?support.heat_resistance_pct*.35:temperature<=12?support.cold_resistance_pct*.35:0;
 const pct={serve:clamp(support.serve_pct+support.focus_pct*.10,-4,4),return:clamp(support.return_pct+support.focus_pct*.12+climate,-4,4),rally:clamp(support.rally_pct+support.stamina_pct*.22+climate,-4,4),net:clamp(support.net_pct+support.focus_pct*.10,-4,4)};
 pct.effective_overall=(pct.serve+pct.return+pct.rally+pct.net)/4;
 const multipliers=Object.fromEntries(Object.entries(pct).map(([k,v])=>[k,(1+v/100)*(missing.racket?.65:1)*(missing.shoes?(k==='serve'?1:k==='effective_overall'?.95:.93):1)*(missing.apparel?.97:1)]));
 return {human:e.human,support,missing,climate,pct,multipliers};
}
function tacticProjection(t,version='ace-context-0.5'){
 check(['ace-context-0.5','ace-tactical-review-0.6'].includes(version),'Unsupported review engine');
 check(t&&['match_override','tournament_default','automatic_default','ai_automatic'].includes(t.source),'Explicit effective tactic source required');
 check(['Balanced','Attack','Counterpunch','Serve + 1','Defensive / Grind','Net Attack'].includes(t.preset),'Invalid tactic preset');
 const observed={source:t.source,preset:t.preset},mapped={},unsupported=[];
 for(const [k,values] of Object.entries(options)){
  const v=t[k];check(values.includes(v),'Invalid tactic '+k);observed[k]=v;
  if(version==='ace-tactical-review-0.6')mapped[k]=v;
  else if(Object.hasOwn(implemented,k)){if(implemented[k].includes(v))mapped[k]=v;else unsupported.push(k);}
  else if(v!==neutralOnly[k])unsupported.push(k);
 }
 return {observed,mapped,unsupported};
}
function prepare(source,context,observations,version='ace-context-0.5'){
 check(['ace-context-0.5','ace-tactical-review-0.6'].includes(version),'Unsupported review engine');
 check(Array.isArray(observations)&&observations.length===2,'Two ordered equipment and tactic observations required');
 // The old class is deliberately neutralized; never apply both an approximate class and numeric support.
 const neutral={...context,players:context.players.map(x=>({...x,equipment_class:'standard'}))};
 const base=adaptMatch(source,neutral);
 const projected=observations.map((o,i)=>{
  check(o&&o.player_id===base.frozen.player_ids[i]&&o.match_id===base.frozen.match_id&&o.match_updated_at===context.match_updated_at,'Observation identity or revision mismatch');
  check(typeof o.evidence_revision==='string'&&o.evidence_revision.trim().length>0,'Explicit observation evidence required');
  const equipment=equipmentProjection(o.equipment,base.frozen.snapshot.weather.temperatureC),tactic=tacticProjection(o.tactic,version);
  check(tactic.observed.source!=='ai_automatic'||!equipment.human,'Human cannot use AI automatic tactic evidence');
  return {player_id:o.player_id,evidence_revision:o.evidence_revision,equipment,tactic};
 });
 const blockers=projected.flatMap((p,i)=>p.tactic.unsupported.map(k=>'player '+(i+1)+': unsupported tactic '+k));
 const body={schema:'ace-legacy-prematch-effects-review-v1',review_only:true,production_ready:false,activation_authorized:false,source_authenticated:false,base,projected,blockers,...(version==='ace-tactical-review-0.6'?{review_engine_version:version}:{})};
 return {...body,review_sha256:digest(body)};
}
function simulate(source,context,observations,expectedSha,version='ace-context-0.5'){
 const review=prepare(source,context,observations,version);
 check(review.review_sha256===expectedSha,'Review input changed');
 check(review.blockers.length===0,'Unsupported tactical semantics: '+review.blockers.join(', '));
 const input=importSnapshot(review.base.frozen.snapshot);
 // Review approximation: apply SQL-equivalent multipliers to Ace's raw-derived
 // ratings, before Ace condition/weather/style. Net and overall are audit-only.
 const players=input.players.map((p,i)=>{const m=review.projected[i].equipment.multipliers;return version==='ace-tactical-review-0.6'?{...p,equipmentMultipliers:{serve:m.serve,return:m.return,rally:m.rally}}:{...p,serve:clamp(p.serve*m.serve,0,100),return:clamp(p.return*m.return,0,100),rally:clamp(p.rally*m.rally,0,100)}});
 let s=engine.createMatch({players,seed:review.base.frozen.seed,surface:input.surface,bestOf:input.bestOf,weather:input.weather,version});
 for(let i=0;i<2;i++)s=engine.queueTactics(s,i,review.projected[i].tactic.mapped);
 let games=0;while(s.status!=='completed'){check(++games<=100,'Match game safety limit');s=engine.stepGame(s);}
 const points=s.events.filter(x=>x.kind==='point');check(points.length===s.totalPoints,'Point accounting mismatch');
 return {schema:'ace-legacy-prematch-effects-simulation-review-v1',review_only:true,production_ready:false,activation_authorized:false,review_sha256:review.review_sha256,winner_id:review.base.frozen.player_ids[s.winner],sets:s.completedSets,total_points:s.totalPoints,point_trace_sha256:digest(points),tactics:s.tactics,...(version==='ace-tactical-review-0.6'?{review_engine_version:version}:{})};
}
module.exports={equipmentProjection,tacticProjection,prepare,simulate};
