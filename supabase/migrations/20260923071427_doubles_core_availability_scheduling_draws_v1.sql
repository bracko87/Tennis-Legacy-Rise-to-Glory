-- ---------------------------------------------------------------------------
-- 3. Core helper functions and central availability
-- ---------------------------------------------------------------------------

create or replace function public.get_competition_window_v1(p_competition_id uuid)
returns table(
  competition_id uuid, tournament_series_id uuid, season_number integer, world text,
  city text, country_code text, location_key text, start_absolute_day integer, end_absolute_day integer
)
language sql stable security definer set search_path=public
as $$
  select wc.id,e.tournament_series_id,e.season_number,wc.world,ts.city,ts.country_code,
         lower(ts.country_code||':'||ts.city),
         public.training_camp_week_start_absolute_v1(e.season_number,min(ss.season_week)::smallint),
         public.training_camp_week_start_absolute_v1(e.season_number,max(ss.season_week)::smallint)+6
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=e.tournament_series_id
  join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
  where wc.id=p_competition_id
  group by wc.id,e.tournament_series_id,e.season_number,wc.world,ts.city,ts.country_code;
$$;

create or replace function public.check_player_competition_availability_v1(p_player_id uuid,p_competition_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public
as $$
declare
  t record;
  v_player_world text;
  v_block_comp uuid;
  v_block_name text;
  v_block_city text;
begin
  select * into t from public.get_competition_window_v1(p_competition_id);
  if t.competition_id is null then return jsonb_build_object('available',false,'reason','competition_unavailable'); end if;
  select world into v_player_world from public.players where id=p_player_id and moderation_status<>'rejected';
  if v_player_world is null then return jsonb_build_object('available',false,'reason','player_unavailable'); end if;
  if v_player_world<>t.world then return jsonb_build_object('available',false,'reason','different_world'); end if;

  v_block_comp:=null;v_block_name:=null;v_block_city:=null;
  select te.competition_id,s.name,s.city into v_block_comp,v_block_name,v_block_city
  from public.tournament_entries te
  join public.tournament_world_competitions wc on wc.id=te.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  cross join lateral public.get_competition_window_v1(te.competition_id) w
  where te.player_id=p_player_id and te.entry_status='active'
    and te.competition_id<>p_competition_id
    and w.start_absolute_day<=t.end_absolute_day and w.end_absolute_day>=t.start_absolute_day
  limit 1;
  if v_block_comp is not null then
    return jsonb_build_object('available',false,'reason','singles_entry_overlap','blocking_competition_id',v_block_comp,'blocking_tournament',v_block_name,'blocking_city',v_block_city);
  end if;

  v_block_comp:=null;v_block_name:=null;v_block_city:=null;
  select a.competition_id,s.name,s.city into v_block_comp,v_block_name,v_block_city
  from public.tournament_applications a
  join public.tournament_world_competitions wc on wc.id=a.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  cross join lateral public.get_competition_window_v1(a.competition_id) w
  where a.player_id=p_player_id and a.status in ('accepted_main_draw','accepted_qualification')
    and a.competition_id<>p_competition_id
    and w.start_absolute_day<=t.end_absolute_day and w.end_absolute_day>=t.start_absolute_day
  limit 1;
  if v_block_comp is not null then
    return jsonb_build_object('available',false,'reason','accepted_singles_overlap','blocking_competition_id',v_block_comp,'blocking_tournament',v_block_name,'blocking_city',v_block_city);
  end if;

  v_block_comp:=null;v_block_name:=null;v_block_city:=null;
  select dt.competition_id,s.name,s.city into v_block_comp,v_block_name,v_block_city
  from public.tournament_doubles_teams dt
  join public.tournament_world_competitions wc on wc.id=dt.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  cross join lateral public.get_competition_window_v1(dt.competition_id) w
  where (dt.player1_id=p_player_id or dt.player2_id=p_player_id)
    and dt.status in ('confirmed','active')
    and dt.competition_id<>p_competition_id
    and w.start_absolute_day<=t.end_absolute_day and w.end_absolute_day>=t.start_absolute_day
  limit 1;
  if v_block_comp is not null then
    return jsonb_build_object('available',false,'reason','doubles_entry_overlap','blocking_competition_id',v_block_comp,'blocking_tournament',v_block_name,'blocking_city',v_block_city);
  end if;

  if exists(
    select 1 from public.player_calendar_commitments c
    where c.player_id=p_player_id and c.status='committed'
      and (c.competition_id is null or c.competition_id<>p_competition_id)
      and c.starts_absolute_day<=t.end_absolute_day and c.ends_absolute_day>=t.start_absolute_day
  ) then
    return jsonb_build_object('available',false,'reason','calendar_commitment_overlap');
  end if;

  return jsonb_build_object('available',true,'reason','available','start_absolute_day',t.start_absolute_day,'end_absolute_day',t.end_absolute_day,'location_key',t.location_key);
end;
$$;

create or replace function public.ensure_player_doubles_ranking_trigger_v1()
returns trigger language plpgsql security definer set search_path=public
as $$ begin
  insert into public.player_doubles_rankings(player_id,world,ranking_points,seed_rating)
  values(new.id,new.world,0,0) on conflict(player_id) do nothing;
  return new;
end; $$;
drop trigger if exists trg_ensure_player_doubles_ranking_v1 on public.players;
create trigger trg_ensure_player_doubles_ranking_v1 after insert on public.players
for each row execute function public.ensure_player_doubles_ranking_trigger_v1();

create or replace function public.create_doubles_team_internal_v1(
  p_competition_id uuid,p_player1_id uuid,p_player2_id uuid,p_entry_source text default 'partner'
)
returns uuid
language plpgsql security definer set search_path=public
as $$
declare
  v_world text;
  v_series uuid;
  v_enabled boolean;
  v_a jsonb;
  v_b jsonb;
  v_points integer;
  v_id uuid;
begin
  if p_player1_id=p_player2_id then raise exception 'A doubles team requires two different players.'; end if;
  select wc.world,e.tournament_series_id,ds.is_enabled into v_world,v_series,v_enabled
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=e.tournament_series_id
  where wc.id=p_competition_id and wc.status<>'canceled';
  if coalesce(v_enabled,false)=false then raise exception 'Doubles is not enabled for this tournament.'; end if;
  if exists(select 1 from public.tournament_doubles_draw_publications where competition_id=p_competition_id) then raise exception 'The doubles draw is already published.'; end if;
  if not exists(select 1 from public.players where id=p_player1_id and world=v_world and moderation_status<>'rejected')
     or not exists(select 1 from public.players where id=p_player2_id and world=v_world and moderation_status<>'rejected') then
    raise exception 'Both doubles partners must belong to the same tournament world.';
  end if;
  if exists(select 1 from public.tournament_doubles_teams where competition_id=p_competition_id and status in ('confirmed','active') and (player1_id in (p_player1_id,p_player2_id) or player2_id in (p_player1_id,p_player2_id))) then
    raise exception 'One of these players already has a doubles partner for this tournament.';
  end if;
  v_a:=public.check_player_competition_availability_v1(p_player1_id,p_competition_id);
  v_b:=public.check_player_competition_availability_v1(p_player2_id,p_competition_id);
  if not coalesce((v_a->>'available')::boolean,false) then raise exception 'First player is unavailable: %',v_a->>'reason'; end if;
  if not coalesce((v_b->>'available')::boolean,false) then raise exception 'Second player is unavailable: %',v_b->>'reason'; end if;
  select coalesce(sum(ranking_points),0)::integer into v_points from public.player_doubles_rankings where player_id in (p_player1_id,p_player2_id);
  insert into public.tournament_doubles_teams(competition_id,world,player1_id,player2_id,status,entry_source,combined_ranking_points_snapshot)
  values(p_competition_id,v_world,p_player1_id,p_player2_id,'confirmed',coalesce(p_entry_source,'partner'),coalesce(v_points,0))
  returning id into v_id;
  return v_id;
end;
$$;

-- Internal team creation is deliberately not user-callable. Ticket 2 will wrap it with the partner/invitation rules.
revoke all on function public.create_doubles_team_internal_v1(uuid,uuid,uuid,text) from public,anon,authenticated;

create or replace function public.doubles_round_label_v1(p_bracket_size integer,p_round integer)
returns text language plpgsql immutable set search_path=public
as $$
declare v_max integer;v_remaining integer;begin
  v_max:=ceil(log(2::numeric,greatest(p_bracket_size,2)::numeric))::integer;
  if p_round=v_max then return 'Final'; end if;
  if p_round=v_max-1 then return 'Semifinal'; end if;
  if p_round=v_max-2 then return 'Quarterfinal'; end if;
  v_remaining:=p_bracket_size/(2^(p_round-1));
  return 'Round of '||v_remaining::text;
end;$$;

create or replace function public.player_match_slot_conflict_v1(
  p_player_id uuid,p_competition_id uuid,p_season integer,p_week integer,p_day integer,
  p_start_minute integer,p_duration_minutes integer,p_recovery_minutes integer,p_exclude_doubles_match uuid default null
)
returns boolean
language sql stable security definer set search_path=public
as $$
  select exists(
    select 1
    from public.tournament_matches m
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    where e.season_number=p_season
      and m.scheduled_season_week=p_week and m.scheduled_day=p_day
      and m.status not in ('cancelled','bye')
      and m.scheduled_start_minute is not null
      and (m.player1_id=p_player_id or m.player2_id=p_player_id)
      and p_start_minute < m.scheduled_start_minute + coalesce(m.actual_duration_minutes,m.estimated_duration_minutes,150) + p_recovery_minutes
      and m.scheduled_start_minute < p_start_minute + p_duration_minutes + p_recovery_minutes
    union all
    select 1
    from public.tournament_doubles_matches dm
    join public.tournament_world_competitions wc on wc.id=dm.competition_id
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    left join public.tournament_doubles_teams t1 on t1.id=dm.team1_id
    left join public.tournament_doubles_teams t2 on t2.id=dm.team2_id
    where e.season_number=p_season
      and dm.scheduled_season_week=p_week and dm.scheduled_day=p_day
      and dm.status not in ('cancelled','bye')
      and dm.scheduled_start_minute is not null
      and dm.id is distinct from p_exclude_doubles_match
      and p_player_id in (t1.player1_id,t1.player2_id,t2.player1_id,t2.player2_id)
      and p_start_minute < dm.scheduled_start_minute + coalesce(dm.actual_duration_minutes,dm.estimated_duration_minutes,105) + p_recovery_minutes
      and dm.scheduled_start_minute < p_start_minute + p_duration_minutes + p_recovery_minutes
  );
$$;

create or replace function public.player_match_count_on_game_day_v1(
  p_player_id uuid,p_season integer,p_week integer,p_day integer,p_exclude_doubles_match uuid default null
)
returns integer
language sql stable security definer set search_path=public
as $$
  select count(*)::integer from (
    select m.id
    from public.tournament_matches m
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    where e.season_number=p_season and m.scheduled_season_week=p_week and m.scheduled_day=p_day
      and m.status not in ('cancelled','bye') and (m.player1_id=p_player_id or m.player2_id=p_player_id)
    union all
    select dm.id
    from public.tournament_doubles_matches dm
    join public.tournament_world_competitions wc on wc.id=dm.competition_id
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    left join public.tournament_doubles_teams t1 on t1.id=dm.team1_id
    left join public.tournament_doubles_teams t2 on t2.id=dm.team2_id
    where e.season_number=p_season and dm.scheduled_season_week=p_week and dm.scheduled_day=p_day
      and dm.status not in ('cancelled','bye') and dm.id is distinct from p_exclude_doubles_match
      and p_player_id in (t1.player1_id,t1.player2_id,t2.player1_id,t2.player2_id)
  ) x;
$$;

create or replace function public.schedule_doubles_match_v1(p_match_id uuid)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  m public.tournament_doubles_matches%rowtype;
  v_season integer;v_category text;v_start_abs integer;v_end_abs integer;v_preferred_abs integer;v_abs integer;
  v_week integer;v_day integer;v_base integer;v_duration integer;v_recovery integer;v_courts integer;
  v_slots smallint[];v_slot integer;v_court integer;v_player uuid;v_players uuid[];v_conflict boolean;v_surface text;
  t1 public.tournament_doubles_teams%rowtype;t2 public.tournament_doubles_teams%rowtype;
begin
  select * into m from public.tournament_doubles_matches where id=p_match_id for update;
  if m.id is null then return jsonb_build_object('status','missing'); end if;
  if m.status<>'scheduled' or m.team1_id is null or m.team2_id is null then return jsonb_build_object('status','not_ready'); end if;
  select * into t1 from public.tournament_doubles_teams where id=m.team1_id;
  select * into t2 from public.tournament_doubles_teams where id=m.team2_id;
  v_players:=array[t1.player1_id,t1.player2_id,t2.player1_id,t2.player2_id];
  select e.season_number,ts.category_code,ts.surface,w.start_absolute_day,w.end_absolute_day,
         ds.estimated_match_duration_minutes,ds.minimum_recovery_minutes,sr.court_count,
         sr.regular_slot_minutes||sr.late_slot_minutes
  into v_season,v_category,v_surface,v_start_abs,v_end_abs,v_duration,v_recovery,v_courts,v_slots
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=e.tournament_series_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ts.id
  join public.tournament_match_scheduling_rules sr on sr.category_code=ts.category_code
  cross join lateral public.get_competition_window_v1(wc.id) w
  where wc.id=m.competition_id;
  v_preferred_abs:=least(v_end_abs,v_start_abs+greatest(m.round_number-1,0));
  v_base:=(v_season-1)*366+2;
  for v_abs in v_preferred_abs..v_end_abs loop
    v_week:=floor((v_abs-v_base)::numeric/7)::integer+1;
    v_day:=mod(v_abs-v_base,7)+1;
    if v_week<1 or v_day not between 1 and 7 then continue; end if;
    foreach v_slot in array v_slots loop
      for v_court in 1..v_courts loop
        if exists(
          select 1 from public.tournament_matches sm
          where sm.competition_id=m.competition_id and sm.scheduled_season_week=v_week and sm.scheduled_day=v_day
            and sm.court_number=v_court and sm.scheduled_start_minute is not null and sm.status not in ('cancelled','bye')
            and v_slot < sm.scheduled_start_minute+coalesce(sm.actual_duration_minutes,sm.estimated_duration_minutes,150)
            and sm.scheduled_start_minute < v_slot+v_duration
        ) or exists(
          select 1 from public.tournament_doubles_matches dm
          where dm.competition_id=m.competition_id and dm.id<>m.id and dm.scheduled_season_week=v_week and dm.scheduled_day=v_day
            and dm.court_number=v_court and dm.scheduled_start_minute is not null and dm.status not in ('cancelled','bye')
            and v_slot < dm.scheduled_start_minute+coalesce(dm.actual_duration_minutes,dm.estimated_duration_minutes,v_duration)
            and dm.scheduled_start_minute < v_slot+v_duration
        ) then continue; end if;
        v_conflict:=false;
        foreach v_player in array v_players loop
          if public.player_match_count_on_game_day_v1(v_player,v_season,v_week,v_day,m.id)>=2
             or public.player_match_slot_conflict_v1(v_player,m.competition_id,v_season,v_week,v_day,v_slot,v_duration,v_recovery,m.id) then
            v_conflict:=true;exit;
          end if;
        end loop;
        if not v_conflict then
          update public.tournament_doubles_matches
          set scheduled_season_week=v_week,scheduled_day=v_day,scheduled_start_minute=v_slot,court_number=v_court,
              estimated_duration_minutes=v_duration,schedule_reason=case when v_abs=v_preferred_abs then 'standard' else 'conflict_rescheduled' end,updated_at=now()
          where id=m.id;
          return jsonb_build_object('status','scheduled','season_week',v_week,'day',v_day,'start_minute',v_slot,'court_number',v_court);
        end if;
      end loop;
    end loop;
  end loop;
  update public.tournament_doubles_matches set scheduled_start_minute=null,court_number=null,schedule_reason='conflict_pending',updated_at=now() where id=m.id;
  return jsonb_build_object('status','no_valid_slot');
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Draw publishing / advancement / withdrawal
-- ---------------------------------------------------------------------------

create or replace function public.publish_doubles_draw_v1(p_competition_id uuid)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  v_series uuid;v_enabled boolean;v_draw smallint;v_min smallint;v_count integer;v_max_round integer;v_start_week integer;v_team record;v_ready record;v_slot integer:=0;v_match integer;v_id uuid;v_created integer:=0;
begin
  if exists(select 1 from public.tournament_doubles_draw_publications where competition_id=p_competition_id) then return jsonb_build_object('status','already_published'); end if;
  select e.tournament_series_id,ds.is_enabled,ds.draw_size,ds.minimum_teams,min(ss.season_week)
  into v_series,v_enabled,v_draw,v_min,v_start_week
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=e.tournament_series_id
  join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
  where wc.id=p_competition_id
  group by e.tournament_series_id,ds.is_enabled,ds.draw_size,ds.minimum_teams;
  if coalesce(v_enabled,false)=false then raise exception 'Doubles is not enabled for this tournament.'; end if;
  select count(*) into v_count from public.tournament_doubles_teams where competition_id=p_competition_id and status='confirmed';
  if v_count<v_min then return jsonb_build_object('status','insufficient_teams','team_count',v_count,'minimum_teams',v_min); end if;

  update public.tournament_doubles_teams set status='alternate',seed_number=null,bracket_slot=null,updated_at=now()
  where competition_id=p_competition_id and status='confirmed';

  for v_team in
    select t.id,row_number() over(order by coalesce(r1.ranking_points,0)+coalesce(r2.ranking_points,0) desc,t.created_at,t.id) rn,
           coalesce(r1.ranking_points,0)+coalesce(r2.ranking_points,0) pts
    from public.tournament_doubles_teams t
    left join public.player_doubles_rankings r1 on r1.player_id=t.player1_id
    left join public.player_doubles_rankings r2 on r2.player_id=t.player2_id
    where t.competition_id=p_competition_id and t.status='alternate'
    order by rn
    limit v_draw
  loop
    v_slot:=v_slot+1;
    update public.tournament_doubles_teams set status='active',seed_number=case when v_slot<=least(8,v_draw/4) then v_slot else null end,
      bracket_slot=v_slot,combined_ranking_points_snapshot=v_team.pts,updated_at=now() where id=v_team.id;
  end loop;

  insert into public.tournament_doubles_draw_publications(competition_id,bracket_size,team_count)
  values(p_competition_id,v_draw,v_slot);

  for v_match in 1..(v_draw/2) loop
    insert into public.tournament_doubles_matches(
      competition_id,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,team1_id,team2_id,status
    )
    values(
      p_competition_id,1,public.doubles_round_label_v1(v_draw,1),v_match,v_draw,v_start_week,1,
      (select id from public.tournament_doubles_teams where competition_id=p_competition_id and status='active' and bracket_slot=v_match*2-1),
      (select id from public.tournament_doubles_teams where competition_id=p_competition_id and status='active' and bracket_slot=v_match*2),
      'scheduled'
    ) returning id into v_id;
    v_created:=v_created+1;
  end loop;

  update public.tournament_doubles_matches
  set status=case when team1_id is null and team2_id is null then 'cancelled' else 'bye' end,
      winner_team_id=case when (team1_id is null)<>(team2_id is null) then coalesce(team1_id,team2_id) else null end,
      completed_at=now(),updated_at=now()
  where competition_id=p_competition_id and round_number=1 and status='scheduled' and (team1_id is null or team2_id is null);

  for v_ready in select id from public.tournament_doubles_matches where competition_id=p_competition_id and round_number=1 and status='scheduled' and team1_id is not null and team2_id is not null loop
    perform public.schedule_doubles_match_v1(v_ready.id);
  end loop;
  return jsonb_build_object('status','published','teams',v_slot,'bracket_size',v_draw,'first_round_matches',v_created);
end;
$$;
revoke all on function public.publish_doubles_draw_v1(uuid) from public,anon,authenticated;

create or replace function public.advance_doubles_bracket_v1()
returns trigger language plpgsql security definer set search_path=public
as $$
declare
  v_max integer;v_next_no integer;v_next_id uuid;v_loser uuid;v_feeders integer;v_t1 uuid;v_t2 uuid;v_s1 text;v_s2 text;
begin
  if new.status not in ('completed','walkover','bye','cancelled') then return new; end if;
  if tg_op='UPDATE' and old.status is not distinct from new.status and old.winner_team_id is not distinct from new.winner_team_id then return new; end if;
  v_max:=ceil(log(2::numeric,greatest(new.bracket_size,2)::numeric))::integer;
  if new.winner_team_id is not null then
    v_loser:=case when new.team1_id=new.winner_team_id then new.team2_id when new.team2_id=new.winner_team_id then new.team1_id else null end;
    if v_loser is not null then
      update public.tournament_doubles_teams set status=case when status='withdrawn' then 'withdrawn' else 'eliminated' end,updated_at=now() where id=v_loser;
    end if;
  end if;
  if new.round_number<v_max then
    v_next_no:=(new.match_number+1)/2;
    select id into v_next_id from public.tournament_doubles_matches where competition_id=new.competition_id and round_number=new.round_number+1 and match_number=v_next_no;
    if v_next_id is null then
      insert into public.tournament_doubles_matches(competition_id,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,status)
      values(new.competition_id,new.round_number+1,public.doubles_round_label_v1(new.bracket_size,new.round_number+1),v_next_no,new.bracket_size,new.scheduled_season_week,least(7,new.scheduled_day+1),'scheduled')
      on conflict(competition_id,round_number,match_number) do nothing returning id into v_next_id;
      if v_next_id is null then select id into v_next_id from public.tournament_doubles_matches where competition_id=new.competition_id and round_number=new.round_number+1 and match_number=v_next_no; end if;
    end if;
    if new.winner_team_id is not null then
      if mod(new.match_number,2)=1 then update public.tournament_doubles_matches set team1_id=new.winner_team_id,updated_at=now() where id=v_next_id;
      else update public.tournament_doubles_matches set team2_id=new.winner_team_id,updated_at=now() where id=v_next_id; end if;
    end if;
    select count(*) into v_feeders from public.tournament_doubles_matches f
    where f.competition_id=new.competition_id and f.round_number=new.round_number and f.match_number in (v_next_no*2-1,v_next_no*2)
      and f.status in ('completed','walkover','bye','cancelled');
    if v_feeders=2 then
      select team1_id,team2_id into v_t1,v_t2 from public.tournament_doubles_matches where id=v_next_id;
      if v_t1 is null and v_t2 is null then
        update public.tournament_doubles_matches set status='cancelled',completed_at=now(),updated_at=now() where id=v_next_id and status='scheduled';
      elsif (v_t1 is null)<>(v_t2 is null) then
        update public.tournament_doubles_matches set status='bye',winner_team_id=coalesce(v_t1,v_t2),completed_at=now(),updated_at=now() where id=v_next_id and status='scheduled';
      else
        select status into v_s1 from public.tournament_doubles_teams where id=v_t1;
        select status into v_s2 from public.tournament_doubles_teams where id=v_t2;
        if v_s1='withdrawn' and v_s2<>'withdrawn' then
          update public.tournament_doubles_matches set status='walkover',winner_team_id=v_t2,completion_reason='team_withdrawal',completed_at=now(),updated_at=now() where id=v_next_id;
        elsif v_s2='withdrawn' and v_s1<>'withdrawn' then
          update public.tournament_doubles_matches set status='walkover',winner_team_id=v_t1,completion_reason='team_withdrawal',completed_at=now(),updated_at=now() where id=v_next_id;
        elsif v_s1='withdrawn' and v_s2='withdrawn' then
          update public.tournament_doubles_matches set status='cancelled',completion_reason='both_teams_withdrawn',completed_at=now(),updated_at=now() where id=v_next_id;
        else
          perform public.schedule_doubles_match_v1(v_next_id);
        end if;
      end if;
    end if;
  elsif new.winner_team_id is not null then
    update public.tournament_doubles_teams set status='champion',updated_at=now() where id=new.winner_team_id;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_advance_doubles_bracket_v1 on public.tournament_doubles_matches;
create trigger trg_advance_doubles_bracket_v1 after insert or update of status,winner_team_id on public.tournament_doubles_matches
for each row execute function public.advance_doubles_bracket_v1();

create or replace function public.withdraw_from_doubles_v1(p_competition_id uuid)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  v_player uuid;v_team public.tournament_doubles_teams%rowtype;v_match public.tournament_doubles_matches%rowtype;v_other uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=auth.uid() limit 1;
  if v_player is null then raise exception 'A player profile is required.'; end if;
  select * into v_team from public.tournament_doubles_teams where competition_id=p_competition_id and status in ('confirmed','active') and (player1_id=v_player or player2_id=v_player) order by created_at desc limit 1 for update;
  if v_team.id is null then raise exception 'No active doubles team found for this tournament.'; end if;
  update public.tournament_doubles_teams set status='withdrawn',withdrawn_at=now(),updated_at=now() where id=v_team.id;
  select * into v_match from public.tournament_doubles_matches
  where competition_id=p_competition_id and status='scheduled' and (team1_id=v_team.id or team2_id=v_team.id)
  order by round_number,match_number limit 1 for update;
  if v_match.id is null then return jsonb_build_object('status','withdrawn','team_id',v_team.id,'walkover_created',false); end if;
  v_other:=case when v_match.team1_id=v_team.id then v_match.team2_id else v_match.team1_id end;
  if v_other is not null then
    update public.tournament_doubles_matches set status='walkover',winner_team_id=v_other,completion_reason='team_withdrawal',completed_at=now(),updated_at=now() where id=v_match.id;
    return jsonb_build_object('status','withdrawn','team_id',v_team.id,'walkover_created',true,'match_id',v_match.id);
  end if;
  return jsonb_build_object('status','withdrawn','team_id',v_team.id,'walkover_created',false,'waiting_for_opponent',true);
end;
$$;