'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {plan}=require('./schedule-gate.cjs'),{slot}=require('./world-clock.cjs');
const dir=process.argv[2],source=fs.readFileSync(path.join(__dirname,'../../supabase/migrations/20261117111500_simulated_match_duration_and_safe_start.sql'),'utf8');
assert.equal(crypto.createHash('sha1').update('blob '+Buffer.byteLength(source)+'\0'+source).digest('hex'),'532856b2d13511389dd2a59701da051b16bde7cd');
const fn=source.match(/CREATE OR REPLACE FUNCTION public\.ensure_safe_singles_start_v1[\s\S]*?\$function\$;/)[0];
const uid=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const target={id:uid(102),status:'scheduled',feederReady:true,players:[uid(201),uid(202)],competition:uid(301),season:1,week:1,day:1,minute:600,firstWeek:1,lastWeek:1,courtCount:2,court:1};
const base=slot(1,1,1,0)/60;
const other={id:uid(101),status:'completed',players:[uid(201),uid(203)],competition:uid(301),court:2,startMinute:base+480,durationMinutes:60};
const court={...other,players:[uid(203),uid(204)],court:1,startMinute:base+525};
const cases=[
 ['player_exact',target,[other],600,1,'ready','ready'],
 ['player_short',target,[{...other,durationMinutes:61}],600,1,'rescheduled','rescheduled'],
 ['court_exact',target,[court],600,1,'ready','ready'],
 ['court_short',target,[{...court,durationMinutes:61}],600,1,'rescheduled','rescheduled'],
 ['cross_competition',target,[{...other,competition:uid(302)}],600,1,'rescheduled','rescheduled'],
 ['paused',target,[],600,0,'ready','paused'],
 ['overdue',target,[],615,1,'ready','ready'],
 ['live_unconfirmed',target,[{...other,status:'live'}],1000,1,'ready','waiting_live_conflict'],
 ['phase_exhausted',{...target,day:7},[],6*1440+1291,1,'ready','blocked'],
 ['off_grid',{...target,minute:607},[{...other,durationMinutes:80}],607,1,'rescheduled','rescheduled']
];
const q=x=>"'"+x+"'";
const row=(x,day,minute,duration)=>'('+[q(x.id),q(x.competition),...x.players.map(q),q(x.status==='live'?'in_progress':x.status),q('main_draw'),1,day,minute,x.court,duration,150].join(',')+')';
if(process.argv[3]==='verify'){
 const rows=fs.readFileSync(path.join(dir,'operational-schedule-results.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
 assert.equal(rows.length,cases.length);
 for(let i=0;i<cases.length;i++){
 const [name,t,o,m,s,legacy,ace]=cases[i],r=rows[i],a=plan(t,o,(base+m)*60,s);
 assert.equal(r.name,name);assert.equal(r.result.status,legacy,name+' SQL');assert.equal(a.status,ace,name+' Ace');
 if(name==='player_short'||name==='cross_competition')assert.equal(r.result.new_day*1440+r.result.new_minute,a.gameMinute);
 if(name==='court_short')assert.equal(r.result.court,2);
 if(name==='off_grid'){assert.equal(r.result.new_minute,637);assert.equal(a.gameMinute,base+630);}
 if(name==='overdue')assert.equal(a.gameMinute,base+615);
 console.log(JSON.stringify({name,legacy:r.result,ace:a,production_ready:false}));
 }
 console.log('PASS 10 pinned SQL versus Ace scheduling cases; intentional differences recorded');
}else{
 let sql=`BEGIN;
 DO $$BEGIN IF current_database()<>'ace_legacy_shadow' THEN RAISE EXCEPTION 'isolated database required'; END IF; END$$;
 ALTER TABLE public.tournament_matches ADD COLUMN IF NOT EXISTS estimated_duration_minutes integer, ADD COLUMN IF NOT EXISTS updated_at timestamptz;
 ALTER TABLE public.tournament_match_simulations ADD COLUMN IF NOT EXISTS live_ends_at timestamptz;
 CREATE TABLE IF NOT EXISTS public.tournament_series(id uuid PRIMARY KEY,category_code text);
 CREATE TABLE IF NOT EXISTS public.tournament_editions(id uuid PRIMARY KEY,tournament_series_id uuid,season_number integer);
 CREATE TABLE IF NOT EXISTS public.tournament_world_competitions(id uuid PRIMARY KEY,tournament_edition_id uuid);
 CREATE TABLE IF NOT EXISTS public.tournament_schedule_slots(tournament_edition_id uuid,phase text,season_week integer);
 CREATE TABLE IF NOT EXISTS public.tournament_match_scheduling_rules(category_code text,court_count integer);
 CREATE TABLE IF NOT EXISTS public.game_clock(id integer,speed_multiplier numeric);
 CREATE OR REPLACE FUNCTION public.raise_system_incident_v1(text,text,text,text,text,jsonb) RETURNS void LANGUAGE plpgsql AS $$BEGIN RETURN; END$$;
 `+fn+'\n';
 // Dedicated fixtures are installed in a transaction and rolled back; no existing rows are removed.
 sql+=`INSERT INTO public.tournament_series(id,category_code) VALUES('${uid(401)}','ace_ops_test');
 INSERT INTO public.tournament_editions(id,tournament_series_id,season_number) VALUES('${uid(402)}','${uid(401)}',1);
 INSERT INTO public.tournament_world_competitions(id,tournament_edition_id) VALUES('${uid(301)}','${uid(402)}'),('${uid(302)}','${uid(402)}');
 INSERT INTO public.tournament_schedule_slots(tournament_edition_id,phase,season_week) VALUES('${uid(402)}','main_draw',1);
 INSERT INTO public.tournament_match_scheduling_rules(category_code,court_count) VALUES('ace_ops_test',2);
 DELETE FROM public.game_clock WHERE id=1;
 INSERT INTO public.game_clock(id,speed_multiplier) VALUES(1,1);
 `;
 for(const [name,t,o,m,s] of cases){
 sql+='SAVEPOINT scenario;\nUPDATE public.game_clock SET speed_multiplier='+s+' WHERE id=1;\n';
 sql+='INSERT INTO public.tournament_matches(id,competition_id,player1_id,player2_id,status,draw_type,scheduled_season_week,scheduled_day,scheduled_start_minute,court_number,actual_duration_minutes,estimated_duration_minutes) VALUES '+[row(t,t.day,t.minute,'NULL'),...o.map(x=>row(x,Math.floor((x.startMinute-base)/1440)+1,(x.startMinute-base)%1440,x.durationMinutes))].join(',')+';\n';
 sql+="SELECT jsonb_build_object('name',"+q(name)+",'result',public.ensure_safe_singles_start_v1("+q(t.id)+","+((base+m)*60)+"));\nROLLBACK TO scenario; RELEASE scenario;\n";
 }
 fs.writeFileSync(path.join(dir,'operational-schedule.sql'),sql+'ROLLBACK;\n');
}
