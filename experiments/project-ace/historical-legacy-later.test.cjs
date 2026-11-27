'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{compare,digest}=require('./shadow-comparison.cjs');
const dir=process.argv[2],read=f=>JSON.parse(fs.readFileSync(path.join(dir,f),'utf8'));
const input=read('historical-input.json'),base=read('historical-result.json'),manifest=read('historical-later-manifest.json');
assert.equal(manifest.selected_definition_sha256.length,5);
for(const [file,version] of [['historical-v1.json','base-v1.1'],['historical-v2.json','base-v2.0']]){
 const legacy=read(file),p=legacy.metadata.profile_snapshot;
 assert.equal(legacy.engine_version,version);assert.equal(legacy.engine_seed,'321');assert.equal(p.best_of_sets,input.format.best_of);
 const observation={schema:'ace-shadow-legacy-observation-v1',input_sha256:input.input_sha256,match_id:input.match_id,competition_id:input.competition_id,source_revision:input.source_revision,player_ids:input.player_ids,engine_version:legacy.engine_version,status:'completed',winner_id:legacy.winner_id,sets:legacy.sets.map(s=>({games:[s.player1_games,s.player2_games],tiebreak:s.player1_tiebreak_points==null?null:[s.player1_tiebreak_points,s.player2_tiebreak_points]})),stats:[legacy.player1_stats,legacy.player2_stats],actual_duration_minutes:legacy.metadata.estimated_match_minutes};
 const forced=legacy.events.filter(e=>e.kind==='point'&&e.description==='Rally ends with a forced error').length;
 const classified=observation.stats.reduce((n,s)=>n+s.aces+s.double_faults+s.winners+s.unforced_errors,0);
 assert.equal(legacy.total_points-classified,forced);
 if(version==='base-v1.1'){assert.deepEqual(legacy.sets,base.sets);assert.equal(legacy.winner_id,base.winner_id);assert.equal(legacy.total_points,base.total_points);}
 else{for(const profile of [p.player1,p.player2]){assert.equal(profile.match_tactic.approach,'Balanced');assert.equal(profile.weather.environment,'outdoor');assert.deepEqual(profile.injury_effects.skill_modifiers,{});}}
 const report=compare(input,observation);assert.equal(report.status,'compared_review');assert.equal(report.metrics.legacy.unclassified_point_rate,forced/legacy.total_points);assert.equal(report.metrics.ace.unclassified_point_rate,0);
 const mislabeled={...observation,engine_version:'base-v1.0'};if(forced>0)assert.throws(()=>compare(input,mislabeled),/point totals/);
 console.log(JSON.stringify({schema:'ace-historical-later-code-comparison-v1',engine_version:version,source_manifest_sha256:digest(manifest),forced_errors:forced,winner_agreement:report.winner_agreement,metrics:report.metrics,production_ready:false}));
}
console.log('PASS original historical classification and V2 point engine with controlled fixture dependencies');
