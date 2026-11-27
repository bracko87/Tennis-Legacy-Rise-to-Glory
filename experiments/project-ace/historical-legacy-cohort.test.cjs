'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{report}=require('./shadow-cohort-review.cjs'),{digest}=require('./shadow-comparison.cjs');
const dir=process.argv[2],cases=JSON.parse(fs.readFileSync(path.join(dir,'cohort-input.json'),'utf8')),results=fs.readFileSync(path.join(dir,'cohort-results.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
assert.equal(results.length,cases.length);const byId=new Map(results.map(x=>[x.match_id,x]));assert.equal(byId.size,cases.length);
const pairs=cases.map(({input,cohort,focal_player_id})=>{
 const row=byId.get(input.match_id);assert.ok(row);
 const legacy=row.result,p=legacy.metadata.profile_snapshot;
 assert.equal(legacy.engine_version,'base-v2.0');assert.equal(legacy.engine_seed,String(input.seed));assert.equal(p.best_of_sets,input.format.best_of);assert.equal(p.surface,input.format.surface);
 for(const [i,profile] of [p.player1,p.player2].entries()){
  const raw=input.snapshot.players[i];assert.equal(profile.player_id,raw.player.id);assert.equal(profile.match_tactic.approach,'Balanced');assert.equal(profile.weather.environment,'outdoor');assert.equal(profile.playing_style,raw.skills.playing_style);
  for(const group of ['technical','physical','condition'])for(const [key,value] of Object.entries(profile[group]))if(Object.hasOwn(raw.skills,key))assert.equal(value,raw.skills[key]);
 }
 const reference={schema:'ace-shadow-legacy-observation-v1',input_sha256:input.input_sha256,match_id:input.match_id,competition_id:input.competition_id,source_revision:input.source_revision,player_ids:input.player_ids,engine_version:legacy.engine_version,status:'completed',winner_id:legacy.winner_id,sets:legacy.sets.map(s=>({games:[s.player1_games,s.player2_games],tiebreak:s.player1_tiebreak_points==null?null:[s.player1_tiebreak_points,s.player2_tiebreak_points]})),stats:[legacy.player1_stats,legacy.player2_stats],actual_duration_minutes:legacy.metadata.estimated_match_minutes};
 assert.equal(reference.sets.reduce((n,s)=>n+s.games[0]+s.games[1],0),legacy.total_games);
 assert.equal(reference.stats.reduce((n,s)=>n+s.total_points_won,0),legacy.total_points);
 assert.equal(legacy.total_points-reference.stats.reduce((n,s)=>n+s.aces+s.double_faults+s.winners+s.unforced_errors,0),row.forced_errors);
 assert.ok(input.player_ids.includes(focal_player_id));
 return {input,reference,cohort,focal_player_id,reference_kind:'historical_sql_control'};
});
const r=report(pairs);
assert.equal(r.paired_matches,1080);assert.equal(r.historical_sql_pairs,1080);assert.equal(r.synthetic_pairs,0);assert.equal(r.supplied_legacy_pairs,0);assert.equal(r.cohorts.length,36);assert.equal(r.adequate_cohorts,36);assert.equal(r.production_ready,false);
for(const c of r.cohorts){assert.equal(c.n,30);assert.ok(c.focal_player_win_rate);assert.ok(c.focal_player_win_rate.approximate_95pct_mean_delta_interval);assert.equal(c.metrics.unclassified_point_rate.ace.mean,0);assert.ok(c.metrics.unclassified_point_rate.reference.mean>=0);}
fs.writeFileSync(path.join(dir,'historical-cohort-report.json'),JSON.stringify(r,null,2));
const metrics=Object.fromEntries(['games','points','minutes','first_serve_rate','ace_rate','double_fault_rate','unclassified_point_rate'].map(k=>[k,{ace:r.cohorts.reduce((n,c)=>n+c.metrics[k].ace.mean,0)/36,legacy:r.cohorts.reduce((n,c)=>n+c.metrics[k].reference.mean,0)/36}]));
console.log(JSON.stringify({schema:'ace-historical-cohort-summary-v1',historical_sql_pairs:r.historical_sql_pairs,cohorts:r.cohorts.length,metrics,report_sha256:digest(r),duration_kind:'historical estimated versus Ace modeled',production_ready:false}));
const skill_groups=[0,12,28].map(gap=>{
 const rows=r.cohorts.filter(c=>c.cohort.startsWith('skill-boost-'+gap+'-'));assert.equal(rows.length,12);
 const avg=(fn)=>rows.reduce((n,c)=>n+fn(c),0)/rows.length;
 return {skill_boost:gap,n:rows.reduce((n,c)=>n+c.n,0),focal_win_rate:{ace:avg(c=>c.focal_player_win_rate.ace.mean),legacy:avg(c=>c.focal_player_win_rate.reference.mean)},winner_agreement:avg(c=>c.winner_agreement)};
});
console.log(JSON.stringify({schema:'ace-historical-skill-review-v1',skill_groups,cohorts_with_30_cases:r.adequate_cohorts,production_ready:false}));
console.log('PASS 1080 historical V2 SQL and independent Ace comparisons, 36 cohorts, exact profile/statistics checks and focal-player win rates, no policy clearance');
