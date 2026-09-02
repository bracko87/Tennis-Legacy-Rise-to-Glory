alter table public.players alter column owner_user_id drop not null;

alter table public.players add column if not exists player_type text not null default 'human';
alter table public.players add column if not exists ai_profile_number smallint;
alter table public.players add column if not exists ai_starting_technical_total smallint;
alter table public.players add column if not exists ai_starting_physical_total smallint;

alter table public.players drop constraint if exists players_player_type_check;
alter table public.players add constraint players_player_type_check check (player_type in ('human','ai'));
alter table public.players drop constraint if exists players_owner_by_type_check;
alter table public.players add constraint players_owner_by_type_check check (
  (player_type='human' and owner_user_id is not null) or
  (player_type='ai' and owner_user_id is null)
);
alter table public.players drop constraint if exists players_ai_profile_number_check;
alter table public.players add constraint players_ai_profile_number_check check (
  (player_type='human' and ai_profile_number is null and ai_starting_technical_total is null and ai_starting_physical_total is null)
  or
  (player_type='ai' and ai_profile_number between 1 and 300 and ai_starting_technical_total between 350 and 400 and ai_starting_physical_total between 176 and 196)
);
create unique index if not exists players_ai_world_profile_number_uidx on public.players(world,ai_profile_number) where player_type='ai';

create table if not exists public.ai_name_pools (
  country_code text primary key references public.countries(code) on update restrict on delete restrict,
  male_first_names text[] not null,
  female_first_names text[] not null,
  surnames text[] not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (cardinality(male_first_names)>=4 and cardinality(female_first_names)>=4 and cardinality(surnames)>=6)
);

create table if not exists public.ai_country_distribution (
  country_code text primary key references public.countries(code) on update restrict on delete restrict,
  players_per_world smallint not null check (players_per_world between 1 and 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.player_rankings add column if not exists seed_rating integer not null default 0;
alter table public.player_rankings drop constraint if exists player_rankings_seed_rating_check;
alter table public.player_rankings add constraint player_rankings_seed_rating_check check (seed_rating>=0);
update public.player_rankings r set seed_rating=45000 from public.players p where p.id=r.player_id and p.player_type='human' and r.seed_rating=0;

create or replace function public.build_starting_nine_skill_profile_v1(
  p_surface text,
  p_style text,
  p_total integer,
  p_rotation integer default 0
)
returns jsonb
language plpgsql
immutable
set search_path=public
as $$
declare
  v integer[] := array[50,50,50,50,50,50,50,50,50];
  s integer[] := array[0,0,0,0,0,0,0,0,0];
  i integer;
  j integer;
  idx integer;
  v_sum integer:=0;
  v_residual integer;
begin
  if p_total not between 300 and 450 then raise exception 'Starting technical total out of range.'; end if;

  if p_surface='Hard' then v:=array[51,52,51,52,48,48,48,50,50];
  elsif p_surface='Clay' then v:=array[47,53,52,53,47,49,49,53,47];
  elsif p_surface='Grass' then v:=array[54,50,48,47,54,52,45,46,54];
  end if;

  if p_style='Aggressive Baseliner' then
    v[1]:=v[1]+1; v[2]:=v[2]+3; v[3]:=v[3]+1; v[5]:=v[5]-2; v[6]:=v[6]-1; v[7]:=v[7]-2; v[8]:=v[8]-1; v[9]:=v[9]+1;
  elsif p_style='Defensive Baseliner' then
    v[1]:=v[1]-2; v[2]:=v[2]+1; v[3]:=v[3]+2; v[4]:=v[4]+3; v[5]:=v[5]-2; v[6]:=v[6]-1; v[7]:=v[7]-1; v[8]:=v[8]+2; v[9]:=v[9]-2;
  elsif p_style='Serve & Volley' then
    v[1]:=v[1]+3; v[2]:=v[2]-1; v[3]:=v[3]-2; v[4]:=v[4]-2; v[5]:=v[5]+4; v[6]:=v[6]+1; v[7]:=v[7]-3; v[8]:=v[8]-2; v[9]:=v[9]+2;
  end if;

  for i in 1..9 loop
    s[i]:=floor(v[i]::numeric*p_total::numeric/450.0)::integer;
    v_sum:=v_sum+s[i];
  end loop;
  v_residual:=p_total-v_sum;
  if v_residual>0 then
    for j in 1..v_residual loop
      idx:=mod(coalesce(p_rotation,0)+j-1,9)+1;
      s[idx]:=s[idx]+1;
    end loop;
  end if;

  return jsonb_build_object(
    'serve',s[1],'forehand',s[2],'backhand',s[3],'return_skill',s[4],'volley',s[5],
    'slice',s[6],'drop_shot',s[7],'lob',s[8],'smash',s[9]
  );
end;
$$;

create or replace function public.build_starting_physical_profile_v1(
  p_style text,
  p_total integer,
  p_rotation integer default 0
)
returns jsonb
language plpgsql
immutable
set search_path=public
as $$
declare
  v integer[]:=array[0,0,0,0];
  base integer;
  rem integer;
  i integer;
  idx integer;
begin
  if p_total not between 160 and 200 then raise exception 'Starting physical total out of range.'; end if;
  base:=floor(p_total::numeric/4)::integer;
  v:=array[base,base,base,base];
  rem:=p_total-base*4;
  if rem>0 then
    for i in 1..rem loop
      idx:=mod(coalesce(p_rotation,0)+i-1,4)+1;
      v[idx]:=v[idx]+1;
    end loop;
  end if;
  if p_style='Aggressive Baseliner' then
    v[1]:=v[1]+2; v[4]:=v[4]+1; v[2]:=v[2]-1; v[3]:=v[3]-2;
  elsif p_style='Defensive Baseliner' then
    v[2]:=v[2]+2; v[3]:=v[3]+2; v[1]:=v[1]-2; v[4]:=v[4]-2;
  elsif p_style='Serve & Volley' then
    v[4]:=v[4]+2; v[1]:=v[1]+1; v[2]:=v[2]-1; v[3]:=v[3]-2;
  end if;
  return jsonb_build_object('fitness',v[1],'stamina',v[2],'recovery',v[3],'movement',v[4]);
end;
$$;

create or replace function public.initialize_player_skills_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_surface text:=coalesce(new.preferred_surface,'Hard');
  v_style text:=coalesce(new.playing_style,'All-court');
  v_technical_total integer:=case when new.player_type='ai' then new.ai_starting_technical_total else 450 end;
  v_physical_total integer:=case when new.player_type='ai' then new.ai_starting_physical_total else 200 end;
  t jsonb;
  p jsonb;
begin
  t:=public.build_starting_nine_skill_profile_v1(v_surface,v_style,v_technical_total,coalesce(new.ai_profile_number,0));
  p:=public.build_starting_physical_profile_v1(v_style,v_physical_total,coalesce(new.ai_profile_number,0));
  insert into public.player_skills(
    player_id,preferred_surface,playing_style,
    serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,
    fitness,stamina,recovery,movement,fatigue,sharpness,morale,confidence,focus
  ) values(
    new.id,v_surface,v_style,
    (t->>'serve')::smallint,(t->>'forehand')::smallint,(t->>'backhand')::smallint,(t->>'return_skill')::smallint,
    (t->>'volley')::smallint,(t->>'slice')::smallint,(t->>'drop_shot')::smallint,(t->>'lob')::smallint,(t->>'smash')::smallint,
    (p->>'fitness')::smallint,(p->>'stamina')::smallint,(p->>'recovery')::smallint,(p->>'movement')::smallint,
    0,50,50,50,50
  ) on conflict(player_id) do nothing;
  return new;
end;
$$;

create or replace function public.ensure_player_ranking_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  insert into public.player_rankings(player_id,seed_rating)
  values(
    new.id,
    case when new.player_type='ai'
      then coalesce(new.ai_starting_technical_total,350)*100+coalesce(new.ai_starting_physical_total,176)
      else 45000
    end
  ) on conflict(player_id) do nothing;
  return new;
end;
$$;

create or replace function public.get_world_rankings_v1(p_world text,p_offset integer default 0,p_limit integer default 50)
returns table(rank_position bigint,player_id uuid,first_name text,last_name text,country_code text,image_path text,ranking_points integer)
language sql
stable security definer
set search_path=public
as $$
  with ranked as(
    select row_number() over(
      order by coalesce(r.ranking_points,0) desc,coalesce(r.seed_rating,0) desc,p.created_at asc,p.id asc
    ) rank_position,
    p.id player_id,p.first_name,p.last_name,p.country_code,p.image_path,coalesce(r.ranking_points,0)::integer ranking_points
    from public.players p left join public.player_rankings r on r.player_id=p.id
    where p.world=upper(p_world) and p.moderation_status<>'rejected'
  )
  select * from ranked order by rank_position
  offset greatest(coalesce(p_offset,0),0)
  limit least(greatest(coalesce(p_limit,50),1),100);
$$;

create or replace function public.get_player_profile_v2(p_player_id uuid)
returns table(
  player_id uuid,first_name text,last_name text,world text,country_code text,home_city text,image_path text,
  preferred_surface text,playing_style text,ranking_points integer,rank_position bigint,is_own_player boolean,is_ai boolean
)
language sql
stable security definer
set search_path=public
as $$
  with target as(
    select p.* from public.players p where p.id=p_player_id and p.moderation_status<>'rejected'
  ), ranked as(
    select p.id,row_number() over(
      order by coalesce(r.ranking_points,0) desc,coalesce(r.seed_rating,0) desc,p.created_at asc,p.id asc
    ) rank_position
    from public.players p left join public.player_rankings r on r.player_id=p.id
    where p.world=(select world from target) and p.moderation_status<>'rejected'
  )
  select t.id,t.first_name,t.last_name,t.world,t.country_code,t.home_city,t.image_path,t.preferred_surface,t.playing_style,
    coalesce(pr.ranking_points,0)::integer,ranked.rank_position,(t.owner_user_id=auth.uid()),(t.player_type='ai')
  from target t left join public.player_rankings pr on pr.player_id=t.id left join ranked on ranked.id=t.id;
$$;
grant execute on function public.get_player_profile_v2(uuid) to authenticated;

create or replace function public.get_or_create_player_conversation_v1(p_target_player_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare v_me uuid; v_one uuid; v_two uuid; v_id uuid;
begin
  select id into v_me from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_me is null then raise exception 'Current player not found'; end if;
  if p_target_player_id=v_me then raise exception 'You cannot message yourself'; end if;
  if not exists(select 1 from public.players where id=p_target_player_id and moderation_status<>'rejected' and player_type='human' and owner_user_id is not null) then
    raise exception 'Computer-controlled players cannot receive messages';
  end if;
  v_one:=least(v_me,p_target_player_id); v_two:=greatest(v_me,p_target_player_id);
  insert into public.player_conversations(player_one_id,player_two_id) values(v_one,v_two)
  on conflict(player_one_id,player_two_id) do update set updated_at=public.player_conversations.updated_at
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.configure_ai_training_plan_v1(p_player_id uuid,p_season integer,p_month smallint,p_day smallint)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  s public.player_skills%rowtype;
  p public.players%rowtype;
  v_type text;
  v_focus text;
  v_intensity text;
  v_selector integer;
  v_week smallint;
begin
  select * into p from public.players where id=p_player_id and player_type='ai';
  if p.id is null then raise exception 'AI player not found.'; end if;
  select * into s from public.player_skills where player_id=p_player_id;
  if s.player_id is null then raise exception 'AI player skills not found.'; end if;
  select season_week into v_week from public.absolute_game_day_v1(public.game_day_absolute_v1(p_season,p_month,p_day));
  v_selector:=mod(abs(hashtext(p_player_id::text||':'||p_season::text||':'||coalesce(v_week,0)::text)),100);

  if s.fatigue>=60 then
    v_type:='day_off'; v_focus:=null; v_intensity:='standard';
  elsif v_selector<66 then
    v_type:='technical';
    select x.skill into v_focus from (values
      ('serve',s.serve,case when p.preferred_surface in ('Hard','Grass') then 0 else 1 end),
      ('forehand',s.forehand,case when p.preferred_surface in ('Hard','Clay') then 0 else 1 end),
      ('backhand',s.backhand,case when p.preferred_surface='Clay' then 0 else 1 end),
      ('return_skill',s.return_skill,case when p.preferred_surface in ('Hard','Clay') then 0 else 1 end),
      ('volley',s.volley,case when p.preferred_surface='Grass' then 0 else 1 end),
      ('slice',s.slice,case when p.preferred_surface='Grass' then 0 else 1 end),
      ('drop_shot',s.drop_shot,case when p.preferred_surface='Clay' then 0 else 1 end),
      ('lob',s.lob,case when p.preferred_surface='Clay' then 0 else 1 end),
      ('smash',s.smash,case when p.preferred_surface='Grass' then 0 else 1 end)
    ) x(skill,val,surface_priority) order by x.val asc,x.surface_priority asc,x.skill limit 1;
    v_intensity:=case when s.fatigue>=40 then 'light' else 'standard' end;
  else
    v_type:='physical';
    select x.skill into v_focus from (values ('fitness',s.fitness),('stamina',s.stamina),('recovery',s.recovery),('movement',s.movement)) x(skill,val)
    order by x.val asc,x.skill limit 1;
    v_intensity:=case when s.fatigue>=40 then 'light' else 'standard' end;
  end if;

  insert into public.player_training_plans(player_id,training_type,focus_attribute,intensity,focus_share,is_active,updated_at)
  values(p_player_id,v_type,v_focus,v_intensity,0.85,true,now())
  on conflict(player_id) do update set training_type=excluded.training_type,focus_attribute=excluded.focus_attribute,
    intensity=excluded.intensity,focus_share=0.85,is_active=true,updated_at=now();
  return jsonb_build_object('training_type',v_type,'focus_attribute',v_focus,'intensity',v_intensity,'selector',v_selector);
end;
$$;

create or replace function public.process_ai_training_day_v1(p_player_id uuid,p_season integer,p_month smallint,p_day smallint)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_plan jsonb; v_result jsonb;
begin
  if not exists(select 1 from public.players where id=p_player_id and player_type='ai') then raise exception 'AI player not found.'; end if;
  v_plan:=public.configure_ai_training_plan_v1(p_player_id,p_season,p_month,p_day);
  v_result:=public.process_regular_training_for_player_v1(p_player_id,p_season,p_month,p_day,'daily_engine');
  return jsonb_build_object('plan',v_plan,'result',v_result);
end;
$$;

create table if not exists public.ai_simulation_state(
  singleton boolean primary key default true check(singleton),
  last_training_absolute_day integer not null default -1,
  updated_at timestamptz not null default now()
);
insert into public.ai_simulation_state(singleton,last_training_absolute_day) values(true,-1) on conflict(singleton) do nothing;

create or replace function public.process_all_ai_training_for_day_v1(p_season integer,p_month smallint,p_day smallint)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare r record; v jsonb; v_completed integer:=0; v_blocked integer:=0; v_already integer:=0;
begin
  for r in select id from public.players where player_type='ai' and moderation_status<>'rejected' order by id loop
    v:=public.process_ai_training_day_v1(r.id,p_season,p_month,p_day);
    if v->'result'->>'status'='completed' then v_completed:=v_completed+1;
    elsif v->'result'->>'status'='already_processed' then v_already:=v_already+1;
    else v_blocked:=v_blocked+1; end if;
  end loop;
  return jsonb_build_object('season',p_season,'month',p_month,'day',p_day,'completed',v_completed,'blocked',v_blocked,'already_processed',v_already);
end;
$$;

create or replace function public.process_ai_training_to_current_day_v1()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare d record; v_current integer; v_last integer; a integer; gd record; v_result jsonb; v_days integer:=0; v_completed integer:=0;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_current:=public.game_day_absolute_v1(d.season,d.month,d.day);
  select last_training_absolute_day into v_last from public.ai_simulation_state where singleton=true for update;
  if v_last is null then v_last:=v_current-1; end if;
  if v_last>=v_current then return jsonb_build_object('status','already_current','absolute_day',v_current); end if;
  for a in (v_last+1)..v_current loop
    select * into gd from public.absolute_game_day_v1(a);
    v_result:=public.process_all_ai_training_for_day_v1(gd.season,gd.month,gd.day);
    v_days:=v_days+1; v_completed:=v_completed+coalesce((v_result->>'completed')::integer,0);
    update public.ai_simulation_state set last_training_absolute_day=a,updated_at=now() where singleton=true;
  end loop;
  return jsonb_build_object('status','processed','days',v_days,'completed_sessions',v_completed,'through_absolute_day',v_current);
end;
$$;

revoke all on function public.configure_ai_training_plan_v1(uuid,integer,smallint,smallint) from public,anon,authenticated;
revoke all on function public.process_ai_training_day_v1(uuid,integer,smallint,smallint) from public,anon,authenticated;
revoke all on function public.process_all_ai_training_for_day_v1(integer,smallint,smallint) from public,anon,authenticated;
revoke all on function public.process_ai_training_to_current_day_v1() from public,anon,authenticated;
grant execute on function public.configure_ai_training_plan_v1(uuid,integer,smallint,smallint) to service_role;
grant execute on function public.process_ai_training_day_v1(uuid,integer,smallint,smallint) to service_role;
grant execute on function public.process_all_ai_training_for_day_v1(integer,smallint,smallint) to service_role;
grant execute on function public.process_ai_training_to_current_day_v1() to service_role;
