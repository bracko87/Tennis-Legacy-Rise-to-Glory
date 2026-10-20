-- Owner-only Career Intelligence regression. Safe to run after deployment.
begin;
do $qa$
declare
 v_world text;v_player uuid;v_user uuid;v_report jsonb;v_rank jsonb;
 v_season jsonb;v_other uuid;v_denied boolean;v_count int;v_match_count int;
begin
 foreach v_world in array array['ATP','WTA'] loop
   select p.id,p.owner_user_id into v_player,v_user
   from public.players p
   where p.world=v_world and p.player_type='human' and p.owner_user_id is not null
   and (exists(select 1 from public.premium_memberships m
     where m.user_id=p.owner_user_id and m.plan_code='premium'
       and m.status='active' and (m.current_period_end is null or m.current_period_end>now()))
     or exists(select 1 from public.tennis_premium_trials_v1 t
       where t.user_id=p.owner_user_id and t.expires_at>now()))
   order by (select count(*) from public.statistics_player_match_facts_v1 f
     where f.player_id=p.id) desc limit 1;
   if v_player is null then raise exception 'Missing Premium % fixture',v_world;end if;
   perform set_config('request.jwt.claim.sub',v_user::text,true);
   v_report:=public.get_premium_career_intelligence_v1(v_player);
   if v_report->>'player_id'<>v_player::text
     or v_report->>'world'<>v_world
     or jsonb_typeof(v_report->'seasons')<>'array'
     or jsonb_typeof(v_report->'surfaces_by_season')<>'array'
     or jsonb_typeof(v_report->'ranking_weeks')<>'array'
     or jsonb_typeof(v_report->'milestones')<>'array'
     or jsonb_array_length(v_report->'ranking_weeks')>24
     or jsonb_array_length(v_report->'seasons')<>(v_report->>'season_count')::integer
   then raise exception 'Invalid % career response',v_world;end if;

   for v_rank in select value from jsonb_array_elements(v_report->'ranking_weeks') r(value) loop
     if (v_rank->>'game_week')::int not between 1 and 52
       or (v_rank->>'rank')::int<1
       or (v_rank->>'absolute_day')::int>(v_report->>'current_absolute_day')::int
       or (v_rank->>'points')::int<0
     then raise exception 'Invalid observed ranking record';end if;
   end loop;

   for v_season in select value from jsonb_array_elements(v_report->'seasons') s(value) loop
     select count(*)::int into v_match_count
     from public.statistics_player_match_facts_v1 f
     where f.player_id=v_player and f.season=(v_season->>'season')::int;
     if (v_season->>'matches')::int<>v_match_count
        or (v_season->>'wins')::int+(v_season->>'losses')::int<>v_match_count
        or (v_season->>'confirmed_titles')::int<0
        or (v_season->>'confirmed_runner_up')::int<0
     then raise exception 'Season matches inconsistent in %',v_world;end if;
   end loop;

   select count(*)::int into v_count from jsonb_array_elements(v_report->'milestones') q
   where (q->>'game_week')::int not between 1 and 52
     or (q->>'season')::int not between 1 and (v_report->>'current_season')::int;
   if v_count>0 then raise exception 'Milestone game week invalid';end if;
 end loop;

 -- A new career with no completed singles matches must not invent wins or trophies.
 select p.id,p.owner_user_id into v_player,v_user
 from public.players p where p.player_type='human' and p.owner_user_id is not null
   and not exists(select 1 from public.statistics_player_match_facts_v1 facts
     where facts.player_id=p.id)
   and (exists(select 1 from public.premium_memberships m
      where m.user_id=p.owner_user_id and m.status='active' and m.plan_code='premium'
       and (m.current_period_end is null or m.current_period_end>now()))
    or exists(select 1 from public.tennis_premium_trials_v1 t
      where t.user_id=p.owner_user_id and t.expires_at>now()))
 limit 1;
 if v_player is null then raise exception 'Missing no-match Premium fixture';end if;
 perform set_config('request.jwt.claim.sub',v_user::text,true);
 v_report:=public.get_premium_career_intelligence_v1(v_player);
 if exists(select 1 from jsonb_array_elements(v_report->'seasons') rec
    where (rec->>'matches')::int>0 or (rec->>'wins')::int>0)
   or exists(select 1 from jsonb_array_elements(v_report->'milestones') rec
    where rec->>'kind' in ('first_match','first_win','first_final','first_title'))
 then raise exception 'No-match career produced phantom statistics or milestones';end if;

 select id into v_other from public.players p
 where p.owner_user_id is not null and p.owner_user_id<>v_user limit 1;
 v_denied:=false;
 begin perform public.get_premium_career_intelligence_v1(v_other);
 exception when sqlstate '42501' then v_denied:=true;end;
 if not v_denied then raise exception 'Cross-owner career read';end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 v_denied:=false;
 begin perform public.get_premium_career_intelligence_v1(v_player);
 exception when sqlstate '42501' then v_denied:=true;end;
 if not v_denied then raise exception 'Non-Premium career read';end if;
 perform set_config('request.jwt.claim.sub','',true);
 v_denied:=false;
 begin perform public.get_premium_career_intelligence_v1(v_player);
 exception when sqlstate '42501' then v_denied:=true;end;
 if not v_denied then raise exception 'Anonymous career read';end if;
 if has_function_privilege('anon'::regrole,
   'public.get_premium_career_intelligence_v1(uuid)','EXECUTE')
 then raise exception 'Anonymous SQL execution granted';end if;
end
$qa$;
rollback;
