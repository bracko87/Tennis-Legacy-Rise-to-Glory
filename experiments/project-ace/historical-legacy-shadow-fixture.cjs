'use strict';
// Extract exact historical function definitions, not entire historical migrations.
// Synthetic tables and input only; no production data, no routine invocation here.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{createHash}=require('node:crypto');
const raw=require('./sample-legacy-snapshot.json'),{freeze}=require('./shadow-comparison.cjs');
const root=path.resolve(__dirname,'../../supabase/migrations'),out=process.argv[2];
assert.ok(out,'Explicit fixture output directory required');
const migrations={
 '20260904142332_live_match_replay_infrastructure_v1.sql':['calculate_match_replay_duration_v1'],
 '20260904145237_match_engine_profiles_and_condition_effects_v1.sql':['match_engine_random_v1','get_match_engine_profile_v1'],
 '20260904145523_match_engine_point_simulator_v1.sql':['match_engine_dynamic_multiplier_v1','match_engine_server_point_probability_v1','match_engine_first_serve_in_probability_v1','match_engine_double_fault_probability_v1','match_engine_ace_probability_v1','match_engine_point_label_v1','match_engine_shot_name_v1','simulate_tournament_match_v1']
};
const sha=x=>createHash('sha256').update(x).digest('hex');
const manifest=[],defs=[];
for(const [file,names] of Object.entries(migrations)){
 const source=fs.readFileSync(path.join(root,file),'utf8');
 for(const name of names){
  const prefix='create or replace function public.'+name+'(';
  assert.equal(source.split(prefix).length,2,'Expected one historical definition: '+name);
  const start=source.indexOf(prefix),body=source.indexOf('$$',start),end=source.indexOf('$$;',body+2);
  assert.ok(start>=0&&body>start&&end>body,'Missing historical function body');
  const def=source.slice(start,end+3);defs.push(def);manifest.push({migration:file,migration_sha256:sha(source),routine:name,definition_sha256:sha(def)});
 }
}
const id=n=>'00000000-0000-4000-8000-00000000000'+n;
const snapshot=JSON.parse(JSON.stringify(raw));snapshot.match.world='WTA';snapshot.match.category_code='wta_250';
snapshot.players.forEach((p,i)=>{p.player.id=id(i+3);p.skills.player_id=id(i+3);});
const input=freeze({match_id:id(5),competition_id:id(2),source_revision:0,snapshot,seed:321});
const quote=x=>"'"+String(x).replaceAll("'","''")+"'";
const skillNames=['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash','fitness','stamina','recovery','movement','fatigue','sharpness','morale','confidence','focus'];
const schema=[
 "CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN;",
 "CREATE TABLE public.players(id uuid PRIMARY KEY,first_name text,last_name text,preferred_surface text,playing_style text);",
 "CREATE TABLE public.player_skills(player_id uuid PRIMARY KEY,"+skillNames.map(k=>k+" integer NOT NULL").join(",")+",preferred_surface text,playing_style text);",
 "CREATE TABLE public.tournament_series(id uuid PRIMARY KEY,surface text,category_code text);",
 "CREATE TABLE public.tournament_editions(id uuid PRIMARY KEY,tournament_series_id uuid);",
 "CREATE TABLE public.tournament_world_competitions(id uuid PRIMARY KEY,tournament_edition_id uuid,world text);",
 "INSERT INTO public.tournament_series VALUES("+[id(7),'Hard','wta_250'].map(quote).join(',')+");",
 "INSERT INTO public.tournament_editions VALUES("+[id(6),id(7)].map(quote).join(',')+");",
 "INSERT INTO public.tournament_world_competitions VALUES("+[id(2),id(6),'WTA'].map(quote).join(',')+");",
 "INSERT INTO public.tournament_matches(id,competition_id,player1_id,player2_id,status,draw_type,round_number,round_label,scheduled_season_week,scheduled_day,scheduled_start_minute,court_number) VALUES("+[id(5),id(2),id(3),id(4),'scheduled','main_draw'].map(quote).join(',')+",1,'Round 1',5,2,600,1);"
];
for(const {player:p,skills:s} of snapshot.players){
 schema.push("INSERT INTO public.players VALUES("+[p.id,p.first_name,p.last_name,s.preferred_surface,s.playing_style].map(quote).join(',')+");");
 schema.push("INSERT INTO public.player_skills VALUES("+[quote(p.id),...skillNames.map(k=>s[k]),quote(s.preferred_surface),quote(s.playing_style)].join(',')+");");
}
const sql=[...schema,...defs,"REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC,anon,authenticated,ace_shadow_reader;","GRANT EXECUTE ON FUNCTION public.simulate_tournament_match_v1(uuid,text) TO ace_shadow_reader;"].join('\n');
fs.writeFileSync(path.join(out,'historical-fixture.sql'),sql);
fs.writeFileSync(path.join(out,'historical-input.json'),JSON.stringify(input));
fs.writeFileSync(path.join(out,'historical-source-manifest.json'),JSON.stringify(manifest,null,2));
console.log('Prepared '+manifest.length+' unmodified historical function definitions; synthetic data only');
