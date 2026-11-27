'use strict';
// Synthetic calibration only: current Ace vs earlier Ace POC. Neither is legacy.
const {freeze,simulate}=require('./shadow-comparison.cjs'),{report}=require('./shadow-cohort-review.cjs'),raw=require('./sample-legacy-snapshot.json');
const clone=x=>JSON.parse(JSON.stringify(x));
function cases(perCohort=10){
 if(!Number.isSafeInteger(perCohort)||perCohort<1||perCohort>200)throw Error('Invalid sample size');
 const out=[];
 for(const surface of ['Hard','Clay','Grass'])for(const gap of [0,12,28])for(const [world,draw_type] of [['ATP','main_draw'],['WTA','main_draw']])for(const style of ['balanced','contrasting'])for(let i=0;i<perCohort;i++){
  const snapshot=clone(raw);Object.assign(snapshot.match,{surface,world,draw_type});
  const [a,b]=snapshot.players;
  if(style==='contrasting'){a.skills.playing_style='Aggressive Baseliner';b.skills.playing_style='Defensive Baseliner';}
  for(const k of ['serve','return_skill','forehand','backhand','volley','movement','stamina','fitness'])a.skills[k]=Math.min(100,a.skills[k]+gap);
  // Alternate which original entrant occupies the first slot.
  if(i%2)snapshot.players.reverse();
  const match_id=['synthetic',surface,gap,world,style,i].join('-'),seed=Math.imul(out.length+1,2654435761)>>>0;
  const setup={match_id,competition_id:'synthetic-shadow-calibration',source_revision:0,snapshot,seed};
  const input=freeze({...setup,ace_version:'ace-context-0.5'});
  const baseline=simulate(freeze({...setup,ace_version:'ace-poc-0.1'}));
  const reference={...baseline,schema:'ace-shadow-legacy-observation-v1',input_sha256:input.input_sha256,engine_version:'synthetic-ace-poc-0.1'};
  delete reference.point_trace_sha256;
  out.push({input,reference,reference_kind:'synthetic_control',cohort:'skill-boost-'+gap+'-'+style});
 }
 return out;
}
if(require.main===module){const n=process.argv[2]===undefined?10:Number(process.argv[2]);console.log(JSON.stringify(report(cases(n)),null,2));}
module.exports={cases};
