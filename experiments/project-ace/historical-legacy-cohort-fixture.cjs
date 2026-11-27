'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{freeze}=require('./shadow-comparison.cjs'),raw=require('./sample-legacy-snapshot.json');
const dir=process.argv[2];assert.ok(dir);
const clone=x=>JSON.parse(JSON.stringify(x)),quote=x=>"'"+String(x).replaceAll("'","''")+"'";
const id=n=>'10000000-0000-4000-8000-'+String(n).padStart(12,'0');
const skills=['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash','fitness','stamina','recovery','movement','fatigue','sharpness','morale','confidence','focus'];
const cases=[],sql=[],queryRows=[];
let group=0;const perCohort=Number(process.env.ACE_HISTORICAL_COHORT_SIZE||30);assert.ok([30,100].includes(perCohort));
for(const surface of ['Hard','Clay','Grass'])for(const gap of [0,12,28])for(const world of ['ATP','WTA'])for(const style of ['balanced','contrasting']){for(let i=0;i<perCohort;i++){
 const snapshot=clone(raw),category=world==='ATP'?'grand_slam_2000':'wta_250';
 Object.assign(snapshot.match,{surface,world,category_code:category,draw_type:'main_draw'});
 const [a,b]=snapshot.players;
 for(const k of ['serve','forehand','backhand','return_skill','volley','movement','stamina','fitness'])a.skills[k]=Math.min(100,a.skills[k]+gap);
 if(style==='contrasting'){a.skills.playing_style='Aggressive Baseliner';b.skills.playing_style='Defensive Baseliner';}
 if(i%2)snapshot.players.reverse();
 const serial=i<10?group*10+i+1:i<30?360+group*20+i-10+1:1080+group*70+i-30+1,match=id(serial*10+1),comp=id(serial*10+2),edition=id(serial*10+3),series=id(serial*10+4);
 snapshot.players.forEach((p,j)=>{p.player.id=id(serial*10+5+j);p.skills.player_id=p.player.id;});
 const seed=Math.imul(serial,2654435761)>>>0,input=freeze({match_id:match,competition_id:comp,source_revision:0,snapshot,seed});
 sql.push("INSERT INTO public.tournament_series VALUES("+[series,surface,category].map(quote).join(',')+");");
 sql.push("INSERT INTO public.tournament_editions VALUES("+[edition,series].map(quote).join(',')+");");
 sql.push("INSERT INTO public.tournament_world_competitions VALUES("+[comp,edition,world].map(quote).join(',')+");");
 for(const {player:p,skills:s} of snapshot.players){
  sql.push("INSERT INTO public.players VALUES("+[p.id,p.first_name,p.last_name,s.preferred_surface,s.playing_style].map(quote).join(',')+");");
  sql.push("INSERT INTO public.player_skills VALUES("+[quote(p.id),...skills.map(k=>s[k]),quote(s.preferred_surface),quote(s.playing_style)].join(',')+");");
 }
 sql.push("INSERT INTO public.tournament_matches(id,competition_id,player1_id,player2_id,status,draw_type,round_number,round_label,scheduled_season_week,scheduled_day,scheduled_start_minute,court_number) VALUES("+[match,comp,...input.player_ids,'scheduled','main_draw'].map(quote).join(',')+",1,'Round 1',5,2,600,1);");
 queryRows.push("("+quote(match)+"::uuid,"+quote(String(seed))+"::text)");
 cases.push({input,cohort:'skill-boost-'+gap+'-'+style,focal_player_id:a.player.id});
}group++;}
assert.equal(group,36);assert.equal(cases.length,36*perCohort);assert.equal(new Set(cases.map(c=>c.input.match_id)).size,36*perCohort);
fs.writeFileSync(path.join(dir,'cohort-fixture.sql'),sql.join('\n'));
fs.writeFileSync(path.join(dir,'cohort-input.json'),JSON.stringify(cases));
// Extract only the exact immutable November duration calculator; no scheduler/finalizer writes.
const pin=require('./current-legacy-source-pin.json'),durationSource=fs.readFileSync(path.resolve(__dirname,'../..',pin.duration_migration));
const blob=require('node:crypto').createHash('sha1').update('blob '+durationSource.length+'\0').update(durationSource).digest('hex');assert.equal(blob,pin.duration_blob_sha);
const source=durationSource.toString('utf8'),prefix='CREATE OR REPLACE FUNCTION public.simulated_tennis_duration_minutes_v1(',start=source.indexOf(prefix),body=source.indexOf('$function$',start),end=source.indexOf('$function$;',body+10);
assert.ok(start>=0&&body>start&&end>body);
const definition=source.slice(start,end+'$function$;'.length);
fs.writeFileSync(path.join(dir,'current-duration-fixture.sql'),definition+"\nREVOKE EXECUTE ON FUNCTION public.simulated_tennis_duration_minutes_v1(integer,integer) FROM PUBLIC,anon,authenticated;\nGRANT EXECUTE ON FUNCTION public.simulated_tennis_duration_minutes_v1(integer,integer) TO ace_shadow_reader;\n");
fs.writeFileSync(path.join(dir,'cohort-query.sql'),"BEGIN READ ONLY;\nSET LOCAL statement_timeout='360s';\nWITH results AS MATERIALIZED (SELECT match_id,public.simulate_tournament_match_v2(match_id,seed) AS j FROM (VALUES "+queryRows.join(',')+") AS x(match_id,seed)) SELECT jsonb_build_object('match_id',match_id,'result',j-'events'-'final_score','current_duration_minutes',public.simulated_tennis_duration_minutes_v1((j->>'total_games')::integer,(j->>'total_points')::integer),'forced_errors',(SELECT count(*) FROM jsonb_array_elements(j->'events') e WHERE e->>'kind'='point' AND e->>'description'='Rally ends with a forced error')) FROM results ORDER BY match_id;\nROLLBACK;\n");
console.log('Prepared '+cases.length+' historical V2 cases across 36 synthetic cohorts');
