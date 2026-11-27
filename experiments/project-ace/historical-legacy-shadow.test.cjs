'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{compare,digest}=require('./shadow-comparison.cjs');
const dir=process.argv[2],read=f=>JSON.parse(fs.readFileSync(path.join(dir,f),'utf8'));
const input=read('historical-input.json'),legacy=read('historical-result.json'),manifest=read('historical-source-manifest.json');
assert.equal(manifest.length,11);assert.equal(legacy.engine_version,'base-v1.0');assert.equal(legacy.engine_seed,'321');
const p=legacy.metadata.profile_snapshot;
assert.equal(p.best_of_sets,input.format.best_of);assert.equal(p.surface,input.format.surface);
for(const [i,profile] of [p.player1,p.player2].entries()){
 const raw=input.snapshot.players[i];
 assert.equal(profile.player_id,raw.player.id);
 for(const group of ['technical','physical','condition'])for(const [key,value] of Object.entries(profile[group]))if(Object.hasOwn(raw.skills,key))assert.equal(value,raw.skills[key]);
}
const observation={schema:'ace-shadow-legacy-observation-v1',input_sha256:input.input_sha256,match_id:input.match_id,competition_id:input.competition_id,source_revision:input.source_revision,player_ids:input.player_ids,engine_version:legacy.engine_version,status:'completed',winner_id:legacy.winner_id,sets:legacy.sets.map(s=>({games:[s.player1_games,s.player2_games],tiebreak:s.player1_tiebreak_points==null?null:[s.player1_tiebreak_points,s.player2_tiebreak_points]})),stats:[legacy.player1_stats,legacy.player2_stats],actual_duration_minutes:legacy.metadata.estimated_match_minutes};
assert.equal(observation.sets.reduce((n,s)=>n+s.games[0]+s.games[1],0),legacy.total_games);
assert.equal(observation.stats.reduce((n,s)=>n+s.total_points_won,0),legacy.total_points);
const report=compare(input,observation);
assert.equal(report.status,'compared_review');assert.equal(report.production_ready,false);
console.log(JSON.stringify({schema:'ace-historical-code-comparison-v1',provenance:'checked-in September 2026 base-v1.0 SQL executed on synthetic inputs',source_manifest_sha256:digest(manifest),legacy_result_sha256:digest(legacy),legacy_duration_kind:'historical estimated minutes, not finalized duration',winner_agreement:report.winner_agreement,score_agreement:report.score_agreement,metrics:report.metrics,production_ready:false}));
console.log('PASS historical legacy SQL engine execution and Ace comparison on the same synthetic player skill snapshot');
