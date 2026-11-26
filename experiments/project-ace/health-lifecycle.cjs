'use strict';
// Explicit synthetic health snapshots only. No RPCs or production writes.
const {injuryReview,recoveryReview}=require('./career-processing-review.cjs'),{eligibility}=require('./career-support.cjs');
const performance=require('./health-performance.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
const ensure=(x,m)=>{if(!x)throw Error(m);};
const validDay=x=>Number.isSafeInteger(x)&&x>=0;
function init(draw,config,day){
 const opts=config.autoHealth;if(opts===undefined)return;
 ensure(config.medicalWalkovers===true&&opts&&Array.isArray(opts.catalog),'Automatic health requires explicit catalogue and medical walkovers');
 ensure(typeof config.competition==='string'&&config.competition.length<=120,'Invalid health competition identifier');
 // Validate the catalogue even when the first roll would be clear.
 injuryReview({player_id:'validation',match_id:'validation',absolute_day:day,risk_percent:0,catalog:opts.catalog});
 const active=opts.catalog.filter(x=>x.is_active===true&&x.contexts?.includes('match'));
 ensure(active.every(x=>x.recovery_min_days>=Math.max(x.training_out_max_days,x.tournament_out_max_days)),'Recovery range must cover clearance dates');
 if(opts.performanceEffects===true)for(const row of active)performance.validate(row.base_performance_penalty,row.skill_effects);
 const players=draw.worldSupport.players;
 ensure(draw.roster.every(x=>Object.hasOwn(players,x.id)),'Explicit health support required for every entrant');
 for(const [id,p] of Object.entries(players)){
  const rows=p.injuries;eligibility(rows,day);
  const keys=new Set();
  for(const x of rows){
   ensure(typeof x.key==='string'&&x.key.length>0&&x.key.length<=200&&!keys.has(x.key),'Unique imported health key required');keys.add(x.key);
   ensure(['injury','illness'].includes(x.kind)&&validDay(x.onsetDay)&&x.onsetDay<=day&&validDay(x.trainingReturnDay)&&x.trainingReturnDay>=x.onsetDay&&x.tournamentReturnDay>=x.onsetDay&&x.fullRecoveryDay>=x.trainingReturnDay,'Invalid health snapshot dates');
   ensure(x.status!=='recovered'||x.fullRecoveryDay<=day,'Premature recovered snapshot');
   if(opts.performanceEffects===true)performance.validate(x.performancePenalty,x.skillEffects);
  }
 }
 draw.worldSupport.health={competition:config.competition,catalog:clone(opts.catalog),lastDay:day,rolls:[],...(opts.performanceEffects===true?{performanceEffects:true}:{})};
 draw.healthNotices=[];
 // Normalize past due imported records without emitting old notifications.
 recover(draw,day);
}
function notice(draw,id,record,kind,day){
 if(![draw.managedPlayer,draw.peerPlayer].includes(id))return;
 const key=record.key+':'+kind;
 if(draw.healthNotices.some(n=>n.key===key&&n.playerId===id))return;
 draw.healthNotices.push({key,playerId:id,day,code:kind,healthKind:record.kind,healthKey:record.key});
}
function recover(draw,day){
 const h=draw.worldSupport.health;if(!h)return;
 ensure(validDay(day)&&day>=h.lastDay,'Health clock rollback');
 for(const [id,p] of Object.entries(draw.worldSupport.players))for(const x of p.injuries){
  if(x.status==='recovered')continue;
  const before=h.lastDay;
  const v=recoveryReview({status:x.status,onset_absolute_day:x.onsetDay,expected_full_recovery_absolute_day:x.fullRecoveryDay},day);
  x.status=v.status;x.progressPercent=v.progress_percent;
  if(v.status==='recovered')x.recoveredDay=x.fullRecoveryDay;
  for(const [date,code] of [[x.trainingReturnDay,'training_clear'],[x.tournamentReturnDay,'competition_clear'],[x.fullRecoveryDay,'fully_recovered']]){
   if(date>before&&date<=day)notice(draw,id,x,code,date);
  }
 }
 h.lastDay=day;
}
function completed(draw,id,receipt,risk){
 const h=draw.worldSupport.health;if(!h||receipt.completionReason==='health_walkover')return;
 const p=draw.worldSupport.players[id],day=draw.worldSupport.day;
 ensure(p&&validDay(day),'Missing health support');
 const match_id=JSON.stringify([h.competition,receipt.matchId]);
 const args={player_id:id,match_id,absolute_day:day,risk_percent:risk,catalog:h.catalog,prior_rolls:h.rolls};
 const roll=injuryReview(args);
 if(roll.status==='already_processed')return;
 h.rolls.push(roll.result);
 const i=roll.result.injury;if(!i)return;
 const record={key:roll.result.key,kind:'injury',code:i.injury_code,severity:i.severity,status:i.status,onsetDay:i.onset_absolute_day,trainingReturnDay:i.training_return_absolute_day,tournamentReturnDay:i.tournament_return_absolute_day,fullRecoveryDay:i.expected_full_recovery_absolute_day,progressPercent:0};
 if(h.performanceEffects){record.performancePenalty=i.performance_penalty;record.skillEffects=clone(h.catalog.find(x=>x.code===i.injury_code).skill_effects);}
 p.injuries.push(record);notice(draw,id,record,'injury_detected',day);
}
module.exports={init,recover,completed};
