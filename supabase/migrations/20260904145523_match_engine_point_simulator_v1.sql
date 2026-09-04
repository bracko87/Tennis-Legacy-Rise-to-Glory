create or replace function public.match_engine_dynamic_multiplier_v1(p_profile jsonb,p_total_points integer,p_max_points integer)
returns numeric language sql immutable set search_path='public' as $$
  select greatest(0.82,
    coalesce((p_profile->'condition'->>'expression_multiplier')::numeric,0.94)
    * coalesce((p_profile->>'surface_multiplier')::numeric,1.0)
    * (1.0-least(1.0,greatest(0,p_total_points)::numeric/greatest(1,p_max_points))
      *(0.025
        +(100-coalesce((p_profile->'physical'->>'stamina')::numeric,50))*0.00045
        +(100-coalesce((p_profile->'physical'->>'fitness')::numeric,50))*0.00020))
  );
$$;
revoke all on function public.match_engine_dynamic_multiplier_v1(jsonb,integer,integer) from public,anon,authenticated;

create or replace function public.match_engine_server_point_probability_v1(
  p_server jsonb,p_receiver jsonb,p_total_points integer,p_max_points integer,p_surface text,p_first_serve boolean
) returns numeric language plpgsql immutable set search_path='public' as $$
declare sm numeric;rm numeric;diff numeric;surface_bonus numeric;v numeric;begin
  sm:=public.match_engine_dynamic_multiplier_v1(p_server,p_total_points,p_max_points);
  rm:=public.match_engine_dynamic_multiplier_v1(p_receiver,p_total_points,p_max_points);
  diff:=0.65*((p_server->'ratings'->>'serve')::numeric*sm-(p_receiver->'ratings'->>'return')::numeric*rm)
       +0.35*((p_server->'ratings'->>'rally')::numeric*sm-(p_receiver->'ratings'->>'rally')::numeric*rm);
  surface_bonus:=case lower(coalesce(p_surface,'hard')) when 'grass' then 0.035 when 'clay' then -0.020 else 0.005 end;
  if p_first_serve then v:=0.67+0.0045*diff+surface_bonus; return greatest(0.50,least(0.88,v));
  else v:=0.52+0.0038*diff+surface_bonus*0.50; return greatest(0.38,least(0.72,v));end if;
end;$$;
revoke all on function public.match_engine_server_point_probability_v1(jsonb,jsonb,integer,integer,text,boolean) from public,anon,authenticated;

create or replace function public.match_engine_first_serve_in_probability_v1(p_profile jsonb)
returns numeric language sql immutable set search_path='public' as $$
 select greatest(0.50,least(0.75,
   0.54
   +coalesce((p_profile->'technical'->>'serve')::numeric,50)*0.002
   +coalesce((p_profile->'condition'->>'focus')::numeric,50)*0.0007
   -coalesce((p_profile->'condition'->>'fatigue')::numeric,0)*0.0004));
$$;
revoke all on function public.match_engine_first_serve_in_probability_v1(jsonb) from public,anon,authenticated;

create or replace function public.match_engine_double_fault_probability_v1(p_profile jsonb)
returns numeric language sql immutable set search_path='public' as $$
 select greatest(0.01,least(0.10,
   0.025
   +greatest(0,55-coalesce((p_profile->'technical'->>'serve')::numeric,50))*0.001
   +coalesce((p_profile->'condition'->>'fatigue')::numeric,0)*0.00025
   -coalesce((p_profile->'condition'->>'focus')::numeric,50)*0.00015));
$$;
revoke all on function public.match_engine_double_fault_probability_v1(jsonb) from public,anon,authenticated;

create or replace function public.match_engine_ace_probability_v1(p_server jsonb,p_receiver jsonb,p_surface text)
returns numeric language plpgsql immutable set search_path='public' as $$
declare v numeric;begin
 v:=0.025
   +(((p_server->'ratings'->>'serve')::numeric-(p_receiver->'ratings'->>'return')::numeric)*0.0015)
   +case lower(coalesce(p_surface,'hard')) when 'grass' then 0.025 when 'clay' then -0.008 else 0.006 end;
 return greatest(0.004,least(0.18,v));
end;$$;
revoke all on function public.match_engine_ace_probability_v1(jsonb,jsonb,text) from public,anon,authenticated;

create or replace function public.match_engine_point_label_v1(p_own integer,p_other integer)
returns text language plpgsql immutable set search_path='public' as $$
begin
 if p_own>=3 and p_other>=3 then
   if p_own=p_other then return '40';elsif p_own=p_other+1 then return 'AD';else return '40';end if;
 end if;
 return case p_own when 0 then '0' when 1 then '15' when 2 then '30' else '40' end;
end;$$;
revoke all on function public.match_engine_point_label_v1(integer,integer) from public,anon,authenticated;

create or replace function public.match_engine_shot_name_v1(p_style text,p_random double precision)
returns text language plpgsql immutable set search_path='public' as $$
declare s text:=lower(coalesce(p_style,'all-court'));r double precision:=greatest(0,least(0.999999,p_random));begin
 if s like '%serve%' and s like '%volley%' then
   if r<0.30 then return 'forehand';elsif r<0.52 then return 'backhand';elsif r<0.74 then return 'volley';elsif r<0.84 then return 'smash';elsif r<0.90 then return 'slice';elsif r<0.95 then return 'drop shot';else return 'lob';end if;
 elsif s like '%defensive%' then
   if r<0.35 then return 'forehand';elsif r<0.65 then return 'backhand';elsif r<0.75 then return 'slice';elsif r<0.85 then return 'lob';elsif r<0.91 then return 'drop shot';elsif r<0.96 then return 'volley';else return 'smash';end if;
 elsif s like '%aggressive%' then
   if r<0.45 then return 'forehand';elsif r<0.77 then return 'backhand';elsif r<0.85 then return 'volley';elsif r<0.90 then return 'smash';elsif r<0.94 then return 'drop shot';elsif r<0.97 then return 'slice';else return 'lob';end if;
 else
   if r<0.38 then return 'forehand';elsif r<0.66 then return 'backhand';elsif r<0.78 then return 'volley';elsif r<0.85 then return 'smash';elsif r<0.90 then return 'slice';elsif r<0.95 then return 'drop shot';else return 'lob';end if;
 end if;
end;$$;
revoke all on function public.match_engine_shot_name_v1(text,double precision) from public,anon,authenticated;

create or replace function public.simulate_tournament_match_v1(p_match_id uuid,p_seed_override text default null)
returns jsonb language plpgsql stable security definer set search_path='public' as $$
declare
 m public.tournament_matches%rowtype;
 wc public.tournament_world_competitions%rowtype;
 ed public.tournament_editions%rowtype;
 ts public.tournament_series%rowtype;
 p1 public.players%rowtype;p2 public.players%rowtype;
 a jsonb;b jsonb;
 seed text;ri integer:=1;
 best_of integer:=3;sets_needed integer:=2;max_points integer:=220;
 p1_sets integer:=0;p2_sets integer:=0;set_no integer:=1;
 g1 integer;g2 integer;gp1 integer;gp2 integer;server integer;next_server integer;receiver integer;
 tb1 integer;tb2 integer;tb_index integer;tb_first_server integer;
 point_winner integer;game_winner integer;set_winner integer;
 first_in boolean;is_ace boolean:=false;is_df boolean:=false;bp boolean:=false;
 prob numeric;r double precision;r2 double precision;r3 double precision;
 p1_fst_total integer:=0;p2_fst_total integer:=0;p1_fst_in integer:=0;p2_fst_in integer:=0;
 p1_fst_won integer:=0;p2_fst_won integer:=0;p1_fst_played integer:=0;p2_fst_played integer:=0;
 p1_snd_won integer:=0;p2_snd_won integer:=0;p1_snd_played integer:=0;p2_snd_played integer:=0;
 p1_aces integer:=0;p2_aces integer:=0;p1_df integer:=0;p2_df integer:=0;
 p1_bp_won integer:=0;p2_bp_won integer:=0;p1_bp_total integer:=0;p2_bp_total integer:=0;
 p1_winners integer:=0;p2_winners integer:=0;p1_ue integer:=0;p2_ue integer:=0;p1_points integer:=0;p2_points integer:=0;
 total_points integer:=0;total_games integer:=0;deuce_count integer:=0;tiebreak_count integer:=0;long_rally_count integer:=0;
 events_raw jsonb:='[]'::jsonb;events_final jsonb:='[]'::jsonb;sets_payload jsonb:='[]'::jsonb;
 replay_units integer:=0;duration integer;estimated_minutes integer;event jsonb;off integer;
 description text;shot text;loser_style text;winner_style text;loser_fatigue integer;loser_sharp integer;loser_focus integer;ue_prob numeric;
 point_label1 text;point_label2 text;
 set_games integer;winner uuid;score_text text:='';
 stats1 jsonb;stats2 jsonb;profile_snapshot jsonb;
 actual_sets integer;
begin
 select * into m from public.tournament_matches where id=p_match_id;
 if m.id is null then raise exception 'Match not found.';end if;
 if m.player1_id is null or m.player2_id is null then raise exception 'Both players are required.';end if;
 select * into wc from public.tournament_world_competitions where id=m.competition_id;
 select * into ed from public.tournament_editions where id=wc.tournament_edition_id;
 select * into ts from public.tournament_series where id=ed.tournament_series_id;
 select * into p1 from public.players where id=m.player1_id;select * into p2 from public.players where id=m.player2_id;
 a:=public.get_match_engine_profile_v1(m.player1_id,ts.surface);b:=public.get_match_engine_profile_v1(m.player2_id,ts.surface);
 if lower(coalesce(wc.world,''))='atp' and ts.category_code='grand_slam_2000' then best_of:=5;sets_needed:=3;max_points:=360;end if;
 seed:=coalesce(nullif(trim(p_seed_override),''),md5(p_match_id::text||':'||to_jsonb(a)::text||':'||to_jsonb(b)::text||':base-v1.0'));

 r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;next_server:=case when r<0.5 then 1 else 2 end;
 events_raw:=events_raw||jsonb_build_array(jsonb_build_object('unit',0,'kind','match_start','description','Match started','p1_sets',0,'p2_sets',0,'p1_games',0,'p2_games',0,'p1_points','0','p2_points','0','set_number',1,'game_number',1));

 while p1_sets<sets_needed and p2_sets<sets_needed loop
   g1:=0;g2:=0;set_games:=0;
   loop
     if g1=6 and g2=6 then
       tiebreak_count:=tiebreak_count+1;tb1:=0;tb2:=0;tb_index:=1;tb_first_server:=next_server;
       loop
         if tb_index=1 then server:=tb_first_server;
         elsif mod(floor((tb_index-2)::numeric/2)::integer,2)=0 then server:=3-tb_first_server;
         else server:=tb_first_server;end if;
         receiver:=3-server;is_ace:=false;is_df:=false;bp:=false;
         if server=1 then
           p1_fst_total:=p1_fst_total+1;r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;first_in:=r<public.match_engine_first_serve_in_probability_v1(a);
           if first_in then p1_fst_in:=p1_fst_in+1;p1_fst_played:=p1_fst_played+1;r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;is_ace:=r<public.match_engine_ace_probability_v1(a,b,ts.surface);
             if is_ace then point_winner:=1;p1_aces:=p1_aces+1;p1_fst_won:=p1_fst_won+1;description:=p1.first_name||' '||p1.last_name||' ace';
             else prob:=public.match_engine_server_point_probability_v1(a,b,total_points,max_points,ts.surface,true);r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;point_winner:=case when r<prob then 1 else 2 end;if point_winner=1 then p1_fst_won:=p1_fst_won+1;end if;end if;
           else p1_snd_played:=p1_snd_played+1;r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;is_df:=r<public.match_engine_double_fault_probability_v1(a);
             if is_df then point_winner:=2;p1_df:=p1_df+1;description:=p1.first_name||' '||p1.last_name||' double fault';
             else prob:=public.match_engine_server_point_probability_v1(a,b,total_points,max_points,ts.surface,false);r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;point_winner:=case when r<prob then 1 else 2 end;if point_winner=1 then p1_snd_won:=p1_snd_won+1;end if;end if;end if;
         else
           p2_fst_total:=p2_fst_total+1;r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;first_in:=r<public.match_engine_first_serve_in_probability_v1(b);
           if first_in then p2_fst_in:=p2_fst_in+1;p2_fst_played:=p2_fst_played+1;r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;is_ace:=r<public.match_engine_ace_probability_v1(b,a,ts.surface);
             if is_ace then point_winner:=2;p2_aces:=p2_aces+1;p2_fst_won:=p2_fst_won+1;description:=p2.first_name||' '||p2.last_name||' ace';
             else prob:=public.match_engine_server_point_probability_v1(b,a,total_points,max_points,ts.surface,true);r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;point_winner:=case when r<prob then 2 else 1 end;if point_winner=2 then p2_fst_won:=p2_fst_won+1;end if;end if;
           else p2_snd_played:=p2_snd_played+1;r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;is_df:=r<public.match_engine_double_fault_probability_v1(b);
             if is_df then point_winner:=1;p2_df:=p2_df+1;description:=p2.first_name||' '||p2.last_name||' double fault';
             else prob:=public.match_engine_server_point_probability_v1(b,a,total_points,max_points,ts.surface,false);r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;point_winner:=case when r<prob then 2 else 1 end;if point_winner=2 then p2_snd_won:=p2_snd_won+1;end if;end if;end if;
         end if;
         total_points:=total_points+1;if point_winner=1 then p1_points:=p1_points+1;tb1:=tb1+1;else p2_points:=p2_points+1;tb2:=tb2+1;end if;
         if not is_ace and not is_df then
           r2:=public.match_engine_random_v1(seed,ri);ri:=ri+1;
           if point_winner=1 then loser_fatigue:=(b->'condition'->>'fatigue')::int;loser_sharp:=(b->'condition'->>'sharpness')::int;loser_focus:=(b->'condition'->>'focus')::int;winner_style:=p1.playing_style;loser_style:=p2.playing_style;
           else loser_fatigue:=(a->'condition'->>'fatigue')::int;loser_sharp:=(a->'condition'->>'sharpness')::int;loser_focus:=(a->'condition'->>'focus')::int;winner_style:=p2.playing_style;loser_style:=p1.playing_style;end if;
           ue_prob:=greatest(0.10,least(0.34,0.22+loser_fatigue*0.0010-loser_sharp*0.0007-loser_focus*0.0004));
           r3:=public.match_engine_random_v1(seed,ri);ri:=ri+1;
           if r2<ue_prob then shot:=case when r3<0.62 then 'forehand' else 'backhand' end;if point_winner=1 then p2_ue:=p2_ue+1;description:=p2.first_name||' '||p2.last_name||' '||shot||' unforced error';else p1_ue:=p1_ue+1;description:=p1.first_name||' '||p1.last_name||' '||shot||' unforced error';end if;
           else shot:=public.match_engine_shot_name_v1(winner_style,r3);if point_winner=1 then p1_winners:=p1_winners+1;description:=p1.first_name||' '||p1.last_name||' '||shot||' winner';else p2_winners:=p2_winners+1;description:=p2.first_name||' '||p2.last_name||' '||shot||' winner';end if;end if;
         end if;
         r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;if r<0.15 then long_rally_count:=long_rally_count+1;end if;
         replay_units:=replay_units+case when r<0.15 then 5 else 3 end;
         events_raw:=events_raw||jsonb_build_array(jsonb_build_object('unit',replay_units,'kind','point','description',description,'p1_sets',p1_sets,'p2_sets',p2_sets,'p1_games',g1,'p2_games',g2,'p1_points',tb1,'p2_points',tb2,'set_number',set_no,'game_number',13));
         exit when (tb1>=7 or tb2>=7) and abs(tb1-tb2)>=2;tb_index:=tb_index+1;
       end loop;
       if tb1>tb2 then set_winner:=1;g1:=7;p1_sets:=p1_sets+1;else set_winner:=2;g2:=7;p2_sets:=p2_sets+1;end if;
       total_games:=total_games+1;set_games:=set_games+1;replay_units:=replay_units+10;
       sets_payload:=sets_payload||jsonb_build_array(jsonb_build_object('set_number',set_no,'player1_games',g1,'player2_games',g2,'player1_tiebreak_points',tb1,'player2_tiebreak_points',tb2));
       events_raw:=events_raw||jsonb_build_array(jsonb_build_object('unit',replay_units,'kind','set_end','description',format('Set %s completed',set_no),'p1_sets',p1_sets,'p2_sets',p2_sets,'p1_games',g1,'p2_games',g2,'p1_points','0','p2_points','0','set_number',set_no,'game_number',13));
       next_server:=3-tb_first_server;exit;
     end if;

     server:=next_server;receiver:=3-server;gp1:=0;gp2:=0;game_winner:=0;
     loop
       bp:=case when receiver=1 then gp1>=3 and gp1-gp2>=1 else gp2>=3 and gp2-gp1>=1 end;
       if bp then if receiver=1 then p1_bp_total:=p1_bp_total+1;else p2_bp_total:=p2_bp_total+1;end if;end if;
       is_ace:=false;is_df:=false;
       if server=1 then
         p1_fst_total:=p1_fst_total+1;r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;first_in:=r<public.match_engine_first_serve_in_probability_v1(a);
         if first_in then p1_fst_in:=p1_fst_in+1;p1_fst_played:=p1_fst_played+1;r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;is_ace:=r<public.match_engine_ace_probability_v1(a,b,ts.surface);
           if is_ace then point_winner:=1;p1_aces:=p1_aces+1;p1_fst_won:=p1_fst_won+1;description:=p1.first_name||' '||p1.last_name||' ace';
           else prob:=public.match_engine_server_point_probability_v1(a,b,total_points,max_points,ts.surface,true);r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;point_winner:=case when r<prob then 1 else 2 end;if point_winner=1 then p1_fst_won:=p1_fst_won+1;end if;end if;
         else p1_snd_played:=p1_snd_played+1;r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;is_df:=r<public.match_engine_double_fault_probability_v1(a);
           if is_df then point_winner:=2;p1_df:=p1_df+1;description:=p1.first_name||' '||p1.last_name||' double fault';
           else prob:=public.match_engine_server_point_probability_v1(a,b,total_points,max_points,ts.surface,false);r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;point_winner:=case when r<prob then 1 else 2 end;if point_winner=1 then p1_snd_won:=p1_snd_won+1;end if;end if;end if;
       else
         p2_fst_total:=p2_fst_total+1;r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;first_in:=r<public.match_engine_first_serve_in_probability_v1(b);
         if first_in then p2_fst_in:=p2_fst_in+1;p2_fst_played:=p2_fst_played+1;r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;is_ace:=r<public.match_engine_ace_probability_v1(b,a,ts.surface);
           if is_ace then point_winner:=2;p2_aces:=p2_aces+1;p2_fst_won:=p2_fst_won+1;description:=p2.first_name||' '||p2.last_name||' ace';
           else prob:=public.match_engine_server_point_probability_v1(b,a,total_points,max_points,ts.surface,true);r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;point_winner:=case when r<prob then 2 else 1 end;if point_winner=2 then p2_fst_won:=p2_fst_won+1;end if;end if;
         else p2_snd_played:=p2_snd_played+1;r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;is_df:=r<public.match_engine_double_fault_probability_v1(b);
           if is_df then point_winner:=1;p2_df:=p2_df+1;description:=p2.first_name||' '||p2.last_name||' double fault';
           else prob:=public.match_engine_server_point_probability_v1(b,a,total_points,max_points,ts.surface,false);r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;point_winner:=case when r<prob then 2 else 1 end;if point_winner=2 then p2_snd_won:=p2_snd_won+1;end if;end if;end if;
       end if;
       total_points:=total_points+1;if point_winner=1 then p1_points:=p1_points+1;gp1:=gp1+1;else p2_points:=p2_points+1;gp2:=gp2+1;end if;
       if gp1>=3 and gp2>=3 and gp1=gp2 then deuce_count:=deuce_count+1;end if;
       if not is_ace and not is_df then
         r2:=public.match_engine_random_v1(seed,ri);ri:=ri+1;
         if point_winner=1 then loser_fatigue:=(b->'condition'->>'fatigue')::int;loser_sharp:=(b->'condition'->>'sharpness')::int;loser_focus:=(b->'condition'->>'focus')::int;winner_style:=p1.playing_style;
         else loser_fatigue:=(a->'condition'->>'fatigue')::int;loser_sharp:=(a->'condition'->>'sharpness')::int;loser_focus:=(a->'condition'->>'focus')::int;winner_style:=p2.playing_style;end if;
         ue_prob:=greatest(0.10,least(0.34,0.22+loser_fatigue*0.0010-loser_sharp*0.0007-loser_focus*0.0004));r3:=public.match_engine_random_v1(seed,ri);ri:=ri+1;
         if r2<ue_prob then shot:=case when r3<0.62 then 'forehand' else 'backhand' end;if point_winner=1 then p2_ue:=p2_ue+1;description:=p2.first_name||' '||p2.last_name||' '||shot||' unforced error';else p1_ue:=p1_ue+1;description:=p1.first_name||' '||p1.last_name||' '||shot||' unforced error';end if;
         else shot:=public.match_engine_shot_name_v1(winner_style,r3);if point_winner=1 then p1_winners:=p1_winners+1;description:=p1.first_name||' '||p1.last_name||' '||shot||' winner';else p2_winners:=p2_winners+1;description:=p2.first_name||' '||p2.last_name||' '||shot||' winner';end if;end if;
       end if;
       r:=public.match_engine_random_v1(seed,ri);ri:=ri+1;if r<0.15 then long_rally_count:=long_rally_count+1;end if;replay_units:=replay_units+case when r<0.15 then 5 else 3 end;
       point_label1:=public.match_engine_point_label_v1(gp1,gp2);point_label2:=public.match_engine_point_label_v1(gp2,gp1);
       events_raw:=events_raw||jsonb_build_array(jsonb_build_object('unit',replay_units,'kind','point','description',description,'p1_sets',p1_sets,'p2_sets',p2_sets,'p1_games',g1,'p2_games',g2,'p1_points',point_label1,'p2_points',point_label2,'set_number',set_no,'game_number',set_games+1));
       if (gp1>=4 or gp2>=4) and abs(gp1-gp2)>=2 then game_winner:=case when gp1>gp2 then 1 else 2 end;exit;end if;
     end loop;
     if bp and point_winner=receiver then if receiver=1 then p1_bp_won:=p1_bp_won+1;else p2_bp_won:=p2_bp_won+1;end if;end if;
     if game_winner=1 then g1:=g1+1;else g2:=g2+1;end if;total_games:=total_games+1;set_games:=set_games+1;next_server:=3-next_server;replay_units:=replay_units+3;
     events_raw:=events_raw||jsonb_build_array(jsonb_build_object('unit',replay_units,'kind','game_end','description',format('Game %s — %s–%s',set_games,g1,g2),'p1_sets',p1_sets,'p2_sets',p2_sets,'p1_games',g1,'p2_games',g2,'p1_points','0','p2_points','0','set_number',set_no,'game_number',set_games));
     if (g1>=6 or g2>=6) and abs(g1-g2)>=2 then
       if g1>g2 then p1_sets:=p1_sets+1;set_winner:=1;else p2_sets:=p2_sets+1;set_winner:=2;end if;replay_units:=replay_units+10;
       sets_payload:=sets_payload||jsonb_build_array(jsonb_build_object('set_number',set_no,'player1_games',g1,'player2_games',g2,'player1_tiebreak_points',null,'player2_tiebreak_points',null));
       events_raw:=events_raw||jsonb_build_array(jsonb_build_object('unit',replay_units,'kind','set_end','description',format('Set %s completed',set_no),'p1_sets',p1_sets,'p2_sets',p2_sets,'p1_games',g1,'p2_games',g2,'p1_points','0','p2_points','0','set_number',set_no,'game_number',set_games));exit;
     end if;
     if mod(set_games,2)=1 and set_games>1 then replay_units:=replay_units+6;events_raw:=events_raw||jsonb_build_array(jsonb_build_object('unit',replay_units,'kind','changeover','description','Changeover','p1_sets',p1_sets,'p2_sets',p2_sets,'p1_games',g1,'p2_games',g2,'p1_points','0','p2_points','0','set_number',set_no,'game_number',set_games));end if;
   end loop;
   set_no:=set_no+1;
 end loop;
 actual_sets:=p1_sets+p2_sets;winner:=case when p1_sets>p2_sets then m.player1_id else m.player2_id end;
 select string_agg(format('%s–%s',x.p1,x.p2),', ' order by x.n) into score_text from (select (e->>'set_number')::int n,(e->>'player1_games')::int p1,(e->>'player2_games')::int p2 from jsonb_array_elements(sets_payload)e)x;
 estimated_minutes:=greatest(35,least(480,round(20+total_points*0.55+total_games*1.10+deuce_count*0.70+tiebreak_count*5+greatest(0,actual_sets-2)*8)));
 duration:=public.calculate_match_replay_duration_v1(total_points,total_games,actual_sets,deuce_count,tiebreak_count,long_rally_count);
 replay_units:=greatest(1,replay_units+4);
 events_raw:=events_raw||jsonb_build_array(jsonb_build_object('unit',replay_units,'kind','match_end','description','Match completed','p1_sets',p1_sets,'p2_sets',p2_sets,'p1_games',0,'p2_games',0,'p1_points','0','p2_points','0','set_number',actual_sets,'game_number',0));
 for event in select value from jsonb_array_elements(events_raw) loop
   off:=least(duration,greatest(0,round(coalesce((event->>'unit')::numeric,0)/replay_units*duration)));
   events_final:=events_final||jsonb_build_array((event-'unit')||jsonb_build_object('offset_seconds',off));
 end loop;
 stats1:=jsonb_build_object('aces',p1_aces,'double_faults',p1_df,'first_serves_in',p1_fst_in,'first_serves_total',p1_fst_total,'first_serve_points_won',p1_fst_won,'first_serve_points_played',p1_fst_played,'second_serve_points_won',p1_snd_won,'second_serve_points_played',p1_snd_played,'break_points_won',p1_bp_won,'break_points_total',p1_bp_total,'winners',p1_winners,'unforced_errors',p1_ue,'total_points_won',p1_points);
 stats2:=jsonb_build_object('aces',p2_aces,'double_faults',p2_df,'first_serves_in',p2_fst_in,'first_serves_total',p2_fst_total,'first_serve_points_won',p2_fst_won,'first_serve_points_played',p2_fst_played,'second_serve_points_won',p2_snd_won,'second_serve_points_played',p2_snd_played,'break_points_won',p2_bp_won,'break_points_total',p2_bp_total,'winners',p2_winners,'unforced_errors',p2_ue,'total_points_won',p2_points);
 profile_snapshot:=jsonb_build_object('player1',a,'player2',b,'surface',lower(ts.surface),'world',wc.world,'category',ts.category_code,'best_of_sets',best_of);
 return jsonb_build_object('engine_version','base-v1.0','engine_seed',seed,'winner_id',winner,'final_score',jsonb_build_object('score',score_text,'sets',sets_payload),'sets',sets_payload,'player1_stats',stats1,'player2_stats',stats2,'events',events_final,'replay_duration_seconds',duration,'total_points',total_points,'total_games',total_games,'metadata',jsonb_build_object('estimated_match_minutes',estimated_minutes,'deuce_count',deuce_count,'tiebreak_count',tiebreak_count,'long_rally_points',long_rally_count,'profile_snapshot',profile_snapshot));
end;$$;
revoke all on function public.simulate_tournament_match_v1(uuid,text) from public,anon,authenticated;

create or replace function public.prepare_tournament_match_simulation_v1(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare sim jsonb;existing public.tournament_match_simulations%rowtype;r jsonb;begin
 select * into existing from public.tournament_match_simulations where match_id=p_match_id;
 if existing.match_id is not null then return jsonb_build_object('status',existing.simulation_status,'match_id',p_match_id,'already_exists',true);end if;
 sim:=public.simulate_tournament_match_v1(p_match_id,null);
 r:=public.register_tournament_match_simulation_v1(p_match_id,sim->>'engine_version',sim->>'engine_seed',(sim->>'winner_id')::uuid,sim->'final_score',sim->'sets',sim->'player1_stats',sim->'player2_stats',sim->'events',(sim->>'replay_duration_seconds')::integer,(sim->>'total_points')::integer,(sim->>'total_games')::integer,sim->'metadata');
 return r||jsonb_build_object('engine_version',sim->>'engine_version');
end;$$;
revoke all on function public.prepare_tournament_match_simulation_v1(uuid) from public,anon,authenticated;

create or replace function public.process_due_match_engine_v1()
returns jsonb language plpgsql security definer set search_path='public' as $$
declare r record;v_game bigint;v_count integer:=0;res jsonb;begin
 select game_total_seconds into v_game from public.get_game_clock_v1() limit 1;
 for r in
   select m.id
   from public.tournament_matches m
   join public.tournament_world_competitions wc on wc.id=m.competition_id
   join public.tournament_editions ed on ed.id=wc.tournament_edition_id
   left join public.tournament_match_simulations sim on sim.match_id=m.id
   where m.status='scheduled' and m.player1_id is not null and m.player2_id is not null and sim.match_id is null
     and ((((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::bigint*86400+coalesce(m.scheduled_start_minute,600)::bigint*60)<=v_game
   order by m.scheduled_season_week,m.scheduled_day,m.scheduled_start_minute,m.court_number
   for update of m skip locked
 loop
   begin res:=public.prepare_tournament_match_simulation_v1(r.id);if res->>'status'='prepared' then v_count:=v_count+1;end if;exception when others then null;end;
 end loop;
 return jsonb_build_object('status','processed','prepared',v_count);
end;$$;
revoke all on function public.process_due_match_engine_v1() from public,anon,authenticated;

create or replace function public.process_match_replay_clock_v1()
returns jsonb language plpgsql security definer set search_path='public' as $$
declare e jsonb;a jsonb;b jsonb;begin
 e:=public.process_due_match_engine_v1();
 a:=public.start_due_match_replays_v1();
 b:=public.finalize_due_match_replays_v1();
 return jsonb_build_object('prepared',coalesce((e->>'prepared')::int,0),'started',coalesce((a->>'started')::int,0),'completed',coalesce((b->>'completed')::int,0));
end;$$;
revoke all on function public.process_match_replay_clock_v1() from public,anon,authenticated;