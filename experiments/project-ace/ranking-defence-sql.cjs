'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{reconcile}=require('./ranking-defence-review.cjs'),{state}=require('./ranking-defence-review.test.cjs');
const dir=process.argv[2],q=x=>x===null?'NULL':typeof x==='number'?String(x):typeof x==='boolean'?String(x):"'"+String(x).replaceAll("'","''")+"'";
const source=fs.readFileSync(path.resolve(__dirname,'../../supabase/migrations/20260918102000_ranking_contribution_expiration_v1.sql'),'utf8');
const start=source.indexOf('create or replace function public.process_weekly_rankings_v1()'),end=source.indexOf('$function$;',start);
assert.ok(start>=0&&end>start);
const definition=source.slice(start,end+'$function$;'.length);
const ddl=`
DO $$ BEGIN IF current_database()<>'ace_rank_shadow' THEN RAISE EXCEPTION 'disposable ranking database required'; END IF; END $$;
CREATE TABLE fixture_clock(day integer);
INSERT INTO fixture_clock VALUES(374);
CREATE FUNCTION public.get_current_game_day_internal_v1() RETURNS TABLE(season integer,month integer,day integer) LANGUAGE sql AS $$ SELECT fixture_clock.day/366+1,1,fixture_clock.day%366+1 FROM fixture_clock $$;
CREATE FUNCTION public.game_day_absolute_v1(integer,integer,integer) RETURNS integer LANGUAGE sql AS $$ SELECT ($1-1)*366+$3-1 $$;
CREATE FUNCTION public.training_camp_week_start_absolute_v1(integer,smallint) RETURNS integer LANGUAGE sql AS $$ SELECT ($1-1)*366+2+($2-1)*7 $$;
CREATE FUNCTION public.capture_world_ranking_snapshot_internal_v1() RETURNS void LANGUAGE plpgsql AS $$ BEGIN RETURN; END $$;
CREATE TABLE tournament_editions(id text PRIMARY KEY,tournament_series_id text,season_number integer);
CREATE TABLE tournament_world_competitions(id text PRIMARY KEY,tournament_edition_id text,world text);
CREATE TABLE tournament_schedule_slots(tournament_edition_id text,season_week smallint);
CREATE TABLE tournament_cancellations(competition_id text);
CREATE TABLE tournament_matches(competition_id text,draw_type text,round_label text,status text,winner_id text);
CREATE TABLE player_tournament_results(id text PRIMARY KEY,competition_id text,player_id text,ranking_points_earned integer,ranking_publish_status text,ranking_publish_absolute_day integer,ranking_published_at timestamptz,updated_at timestamptz);
CREATE TABLE player_ranking_contributions(source_result_id text PRIMARY KEY,player_id text,competition_id text,tournament_series_id text,world text,season_number integer,ranking_points integer,awarded_absolute_day integer,expires_absolute_day integer,published_at timestamptz,is_active boolean,deactivated_absolute_day integer,deactivated_at timestamptz,replaced_by_result_id text,replaced_by_competition_id text,replacement_reason text,updated_at timestamptz);
CREATE TABLE ranking_defence_cycles(competition_id text PRIMARY KEY,tournament_series_id text,world text,season_number integer,previous_season_number integer,scheduled_publish_absolute_day integer,processed_absolute_day integer,processing_reason text,published_results integer,expired_contributions integer,activated_contributions integer,processed_at timestamptz);
CREATE TABLE player_rankings(player_id text PRIMARY KEY,ranking_points integer,updated_at timestamptz);
CREATE TABLE ranking_publication_runs(game_absolute_day integer PRIMARY KEY,season integer,month integer,day integer,published_results integer,processed_at timestamptz,defence_cycles_processed integer,contributions_expired integer,contributions_activated integer,orphan_contributions_expired integer);
`;
const rows=[];
function insert(table,cols,values){rows.push('INSERT INTO '+table+'('+cols.join(',')+') VALUES('+values.map(q).join(',')+');');}
for(const e of state.editions){
 insert('tournament_editions',['id','tournament_series_id','season_number'],[e.competition,e.series,e.season]);
 insert('tournament_world_competitions',['id','tournament_edition_id','world'],[e.competition,e.competition,e.world]);
 insert('tournament_schedule_slots',['tournament_edition_id','season_week'],[e.competition,(e.publish_day-(e.season-1)*366-2)/7]);
 if(e.status==='cancelled')insert('tournament_cancellations',['competition_id'],[e.competition]);
 if(e.status==='completed')insert('tournament_matches',['competition_id','draw_type','round_label','status','winner_id'],[e.competition,'main_draw','final','completed','fixture-winner']);
}
for(const r of state.results)insert('player_tournament_results',['id','competition_id','player_id','ranking_points_earned','ranking_publish_status','ranking_publish_absolute_day'],[r.id,r.competition,r.player,r.points,r.status,r.publish_day]);
for(const c of state.contributions)insert('player_ranking_contributions',['source_result_id','player_id','competition_id','tournament_series_id','world','season_number','ranking_points','awarded_absolute_day','expires_absolute_day','is_active'],[c.result_id,c.player,c.competition,c.series,c.world,c.season,c.points,c.awarded_day,c.expires_day,c.active]);
for(const c of state.cycles){const e=state.editions.find(x=>x.competition===c.competition);insert('ranking_defence_cycles',['competition_id','tournament_series_id','world','season_number','processed_absolute_day'],[e.competition,e.series,e.world,e.season,c.processed_day]);}
for(const player of new Set(state.results.map(x=>x.player)))insert('player_rankings',['player_id','ranking_points'],[player,0]);
const snapshot=`SELECT jsonb_build_object('contributions',(SELECT jsonb_agg(jsonb_build_object('id',source_result_id,'active',is_active,'reason',replacement_reason,'deactivated',deactivated_absolute_day,'replacement',replaced_by_competition_id,'result',replaced_by_result_id,'award',awarded_absolute_day,'expiry',expires_absolute_day,'points',ranking_points) ORDER BY source_result_id) FROM player_ranking_contributions),'results',(SELECT jsonb_object_agg(id,ranking_publish_status) FROM player_tournament_results),'cycles',(SELECT jsonb_agg(competition_id ORDER BY competition_id) FROM ranking_defence_cycles));`;
const sql=[ddl,definition,...rows,'DO $$ BEGIN PERFORM public.process_weekly_rankings_v1(); END $$;',snapshot,'UPDATE fixture_clock SET day=375;','DO $$ BEGIN PERFORM public.process_weekly_rankings_v1(); END $$;',snapshot,'DO $$ BEGIN PERFORM public.process_weekly_rankings_v1(); END $$;',snapshot,"INSERT INTO tournament_matches VALUES('late','main_draw','final','completed','fixture-winner');",'UPDATE fixture_clock SET day=382;','DO $$ BEGIN PERFORM public.process_weekly_rankings_v1(); END $$;',snapshot];
if(process.argv[3]!=='verify')fs.writeFileSync(path.join(dir,'ranking-shadow.sql'),sql.join('\n'));
else{
 const actual=fs.readFileSync(path.join(dir,'ranking-shadow.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
 const a=reconcile(state,374),b=reconcile(a.state,375),replay=reconcile(b.state,375),late=JSON.parse(JSON.stringify(replay.state));late.editions.find(x=>x.competition==='late').status='completed';
 const expected=[a,b,replay,reconcile(late,382)].map(x=>({contributions:x.state.contributions.map(c=>({id:c.result_id,active:c.active,reason:c.reason??null,deactivated:c.deactivated_day??null,replacement:c.replaced_by_competition??null,result:c.replaced_by_result??null,award:c.awarded_day,expiry:c.expires_day,points:c.points})).sort((a,b)=>a.id.localeCompare(b.id)),results:Object.fromEntries(x.state.results.map(r=>[r.id,r.status])),cycles:x.state.cycles.map(c=>c.competition).sort()}));
 assert.deepEqual(actual,expected);
 console.log('PASS four ranking snapshots against original September Legacy SQL: non-Monday, defence cycle, replay and late completion');
}
