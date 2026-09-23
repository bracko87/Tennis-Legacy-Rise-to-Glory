
-- Doubles AI participation balance + singles/doubles player calendar rows.
-- Normal AI doubles interest is drawn only from AI players who already hold an
-- active singles entry in the exact same competition:
--   qualification: deterministic 40%
--   main draw: deterministic 15%
-- High-tier events can fill remaining doubles places in the final five game
-- minutes before the partnership deadline, using same-event singles entrants
-- first and only then AI players with no competing singles commitment/application
-- in that tournament week.

create or replace function public.seed_ai_doubles_partner_marketplace_v1(p_competition_id uuid)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
  v_world text;
  v_draw_size integer;
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_inserted integer:=0;
begin
  select wc.world,ds.draw_size
  into v_world,v_draw_size
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id
  where wc.id=p_competition_id
    and ds.is_enabled;

  if v_world is null then return 0; end if;

  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  if v_now<(v_timeline->>'registration_open_game_second')::bigint
     or v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint then
    return 0;
  end if;

  with candidates as (
    select
      p.id,
      te.draw_type,
      coalesce(te.ranking_position_snapshot,999999) ranking_position,
      ((hashtextextended(p.id::text||':'||p_competition_id::text,0)%100)+100)%100 as bucket
    from public.tournament_entries te
    join public.players p on p.id=te.player_id
    where te.competition_id=p_competition_id
      and te.entry_status='active'
      and te.draw_type in ('qualification','main_draw')
      and p.world=v_world
      and p.player_type='ai'
      and p.moderation_status<>'rejected'
      and not exists(
        select 1
        from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
  ),
  selected as (
    select *
    from candidates
    where (draw_type='qualification' and bucket<40)
       or (draw_type='main_draw' and bucket<15)
    order by
      case when draw_type='qualification' then 0 else 1 end,
      ranking_position desc,
      bucket,
      id
    limit greatest(0,coalesce(v_draw_size,16)*2)
  )
  insert into public.tournament_doubles_partner_listings(
    competition_id,player_id,owner_user_id,status,created_at,updated_at,closed_at
  )
  select p_competition_id,id,null,'active',now(),now(),null
  from selected
  on conflict(competition_id,player_id) do update
  set owner_user_id=null,
      status=case
        when public.tournament_doubles_partner_listings.status='matched'
          then public.tournament_doubles_partner_listings.status
        else 'active'
      end,
      updated_at=now(),
      closed_at=case
        when public.tournament_doubles_partner_listings.status='matched'
          then public.tournament_doubles_partner_listings.closed_at
        else null
      end;

  get diagnostics v_inserted=row_count;
  return v_inserted;
end;
$$;

revoke all on function public.seed_ai_doubles_partner_marketplace_v1(uuid)
from public,anon,authenticated;
grant execute on function public.seed_ai_doubles_partner_marketplace_v1(uuid)
to service_role;

create or replace function public.fill_high_tier_ai_doubles_teams_v1(p_competition_id uuid)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
  v_world text;
  v_category text;
  v_draw_size integer;
  v_season integer;
  v_week integer;
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_existing integer;
  v_needed integer;
  v_created integer:=0;
  v_p1 uuid;
  v_p2 uuid;
begin
  select wc.world,ts.category_code,ds.draw_size,ed.season_number,
         coalesce(
           max(ss.season_week) filter(where ss.phase='full'),
           max(ss.season_week) filter(where ss.phase='main_draw'),
           max(ss.season_week)
         )::integer
  into v_world,v_category,v_draw_size,v_season,v_week
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ts.id
  left join public.tournament_schedule_slots ss on ss.tournament_edition_id=ed.id
  where wc.id=p_competition_id
    and ds.is_enabled
  group by wc.world,ts.category_code,ds.draw_size,ed.season_number;

  if v_world is null
     or v_category not in ('tour_250','tour_500','masters_1000','grand_slam_2000') then
    return 0;
  end if;

  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  if v_now < (v_timeline->>'partnership_deadline_game_second')::bigint - 300
     or v_now >= (v_timeline->>'partnership_deadline_game_second')::bigint then
    return 0;
  end if;

  select count(*) into v_existing
  from public.tournament_doubles_teams
  where competition_id=p_competition_id
    and status in ('confirmed','active','alternate');

  v_needed:=greatest(0,coalesce(v_draw_size,0)-v_existing);

  while v_needed>0 loop
    v_p1:=null;
    v_p2:=null;

    -- First preference: AI already playing singles in this exact tournament.
    select p.id into v_p1
    from public.tournament_entries te
    join public.players p on p.id=te.player_id
    where te.competition_id=p_competition_id
      and te.entry_status='active'
      and te.draw_type in ('qualification','main_draw')
      and p.player_type='ai'
      and not exists(
        select 1 from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
    order by
      case te.draw_type when 'qualification' then 0 else 1 end,
      coalesce(te.ranking_position_snapshot,999999) desc,
      p.id
    limit 1;

    -- Only when the same-event pool is exhausted may a truly free AI be added.
    if v_p1 is null then
      select p.id into v_p1
      from public.players p
      where p.world=v_world
        and p.player_type='ai'
        and p.moderation_status<>'rejected'
        and coalesce(
          (public.check_player_competition_availability_v1(p.id,p_competition_id)->>'available')::boolean,
          false
        )
        and not exists(
          select 1
          from public.tournament_entries te2
          join public.tournament_world_competitions wc2 on wc2.id=te2.competition_id
          join public.tournament_editions ed2 on ed2.id=wc2.tournament_edition_id
          join public.tournament_schedule_slots ss2 on ss2.tournament_edition_id=ed2.id
          where te2.player_id=p.id
            and te2.entry_status='active'
            and ed2.season_number=v_season
            and ss2.season_week=v_week
            and te2.competition_id<>p_competition_id
        )
        and not exists(
          select 1
          from public.tournament_applications ta2
          join public.tournament_world_competitions wc2 on wc2.id=ta2.competition_id
          join public.tournament_editions ed2 on ed2.id=wc2.tournament_edition_id
          join public.tournament_schedule_slots ss2 on ss2.tournament_edition_id=ed2.id
          where ta2.player_id=p.id
            and ta2.status='applied'
            and ed2.season_number=v_season
            and ss2.season_week=v_week
            and ta2.competition_id<>p_competition_id
        )
        and not exists(
          select 1 from public.tournament_doubles_teams t
          where t.competition_id=p_competition_id
            and t.status in ('confirmed','active','alternate')
            and (t.player1_id=p.id or t.player2_id=p.id)
        )
      order by p.id
      limit 1;
    end if;

    exit when v_p1 is null;

    select p.id into v_p2
    from public.tournament_entries te
    join public.players p on p.id=te.player_id
    where te.competition_id=p_competition_id
      and te.entry_status='active'
      and te.draw_type in ('qualification','main_draw')
      and p.player_type='ai'
      and p.id<>v_p1
      and not exists(
        select 1 from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
    order by
      case te.draw_type when 'qualification' then 0 else 1 end,
      coalesce(te.ranking_position_snapshot,999999) desc,
      p.id
    limit 1;

    if v_p2 is null then
      select p.id into v_p2
      from public.players p
      where p.world=v_world
        and p.player_type='ai'
        and p.id<>v_p1
        and p.moderation_status<>'rejected'
        and coalesce(
          (public.check_player_competition_availability_v1(p.id,p_competition_id)->>'available')::boolean,
          false
        )
        and not exists(
          select 1
          from public.tournament_entries te2
          join public.tournament_world_competitions wc2 on wc2.id=te2.competition_id
          join public.tournament_editions ed2 on ed2.id=wc2.tournament_edition_id
          join public.tournament_schedule_slots ss2 on ss2.tournament_edition_id=ed2.id
          where te2.player_id=p.id
            and te2.entry_status='active'
            and ed2.season_number=v_season
            and ss2.season_week=v_week
            and te2.competition_id<>p_competition_id
        )
        and not exists(
          select 1
          from public.tournament_applications ta2
          join public.tournament_world_competitions wc2 on wc2.id=ta2.competition_id
          join public.tournament_editions ed2 on ed2.id=wc2.tournament_edition_id
          join public.tournament_schedule_slots ss2 on ss2.tournament_edition_id=ed2.id
          where ta2.player_id=p.id
            and ta2.status='applied'
            and ed2.season_number=v_season
            and ss2.season_week=v_week
            and ta2.competition_id<>p_competition_id
        )
        and not exists(
          select 1 from public.tournament_doubles_teams t
          where t.competition_id=p_competition_id
            and t.status in ('confirmed','active','alternate')
            and (t.player1_id=p.id or t.player2_id=p.id)
        )
      order by p.id
      limit 1;
    end if;

    exit when v_p2 is null;

    begin
      perform public.create_doubles_team_internal_v1(
        p_competition_id,v_p1,v_p2,'ai_last_minute_fill'
      );

      update public.tournament_doubles_partner_listings
      set status='matched',closed_at=now(),updated_at=now()
      where competition_id=p_competition_id
        and player_id in (v_p1,v_p2)
        and status='active';

      v_created:=v_created+1;
      v_needed:=v_needed-1;
    exception when others then
      exit;
    end;
  end loop;

  return v_created;
end;
$$;

revoke all on function public.fill_high_tier_ai_doubles_teams_v1(uuid)
from public,anon,authenticated;
grant execute on function public.fill_high_tier_ai_doubles_teams_v1(uuid)
to service_role;

create or replace function public.process_due_doubles_entry_lifecycle_v1()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_now bigint:=public.current_game_second_v1();
  v_day record;
  v_current_week integer;
  v_current_abs_week integer;
  r record;
  v_timeline jsonb;
  v_expired integer:=0;
  v_allocated integer:=0;
  v_drawn integer:=0;
  v_ai_listed integer:=0;
  v_ai_paired integer:=0;
  v_ai_late_fill integer:=0;
  v_result jsonb;
  v_n integer;
  v_partnership_closed_at timestamptz;
begin
  select * into v_day from public.get_current_game_day_internal_v1();
  select season_week into v_current_week
  from public.absolute_game_day_v1(
    public.game_day_absolute_v1(v_day.season,v_day.month,v_day.day)
  );
  v_current_abs_week:=(v_day.season-1)*52+v_current_week;

  for r in
    select wc.id competition_id
    from public.tournament_world_competitions wc
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_doubles_settings ds
      on ds.tournament_series_id=ed.tournament_series_id
     and ds.is_enabled
    join lateral (
      select coalesce(
        max(ss.season_week) filter(where ss.phase='full'),
        max(ss.season_week) filter(where ss.phase='main_draw'),
        max(ss.season_week)
      )::integer season_week
      from public.tournament_schedule_slots ss
      where ss.tournament_edition_id=ed.id
    ) slot on slot.season_week is not null
    left join public.tournament_doubles_entry_lifecycle life
      on life.competition_id=wc.id
    where wc.status<>'canceled'
      and ed.status<>'canceled'
      and ((ed.season_number-1)*52+slot.season_week)
          between v_current_abs_week+1 and v_current_abs_week+4
      and not (
        life.draw_processed_at is not null
        and exists(
          select 1 from public.tournament_doubles_draw_publications dp
          where dp.competition_id=wc.id
        )
      )
  loop
    v_timeline:=public.get_tournament_doubles_entry_timeline_v1(r.competition_id);

    insert into public.tournament_doubles_entry_lifecycle(competition_id,updated_at)
    values(r.competition_id,now())
    on conflict(competition_id) do nothing;

    select partnership_closed_at
    into v_partnership_closed_at
    from public.tournament_doubles_entry_lifecycle
    where competition_id=r.competition_id;

    -- Cheap/idempotent and intentionally rerun while open so singles selection
    -- decisions made after doubles registration opens can feed the marketplace.
    if v_now>=(v_timeline->>'registration_open_game_second')::bigint
       and v_now<(v_timeline->>'partnership_deadline_game_second')::bigint then
      v_n:=public.seed_ai_doubles_partner_marketplace_v1(r.competition_id);
      v_ai_listed:=v_ai_listed+coalesce(v_n,0);
    end if;

    -- Five game minutes before partnership close, high-tier events may fill
    -- genuine remaining doubles vacancies without stealing AI already committed
    -- to another singles event in the same week.
    if v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint-300
       and v_now<(v_timeline->>'partnership_deadline_game_second')::bigint then
      v_n:=public.fill_high_tier_ai_doubles_teams_v1(r.competition_id);
      v_ai_late_fill:=v_ai_late_fill+coalesce(v_n,0);
    end if;

    if v_now>=(v_timeline->>'registration_deadline_game_second')::bigint then
      update public.tournament_doubles_entry_lifecycle
      set registration_closed_at=coalesce(registration_closed_at,now()),updated_at=now()
      where competition_id=r.competition_id;
    end if;

    if v_partnership_closed_at is null
       and v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint then
      v_n:=public.expire_doubles_partner_invitations_v1(r.competition_id,v_now);
      v_expired:=v_expired+coalesce(v_n,0);

      v_n:=public.pair_ai_doubles_teams_v1(r.competition_id);
      v_ai_paired:=v_ai_paired+coalesce(v_n,0);

      update public.tournament_doubles_partner_listings
      set status='expired',closed_at=now(),updated_at=now()
      where competition_id=r.competition_id and status='active';

      update public.tournament_doubles_entry_lifecycle
      set partnership_closed_at=now(),updated_at=now()
      where competition_id=r.competition_id;

      if not exists(
        select 1 from public.tournament_doubles_entry_lifecycle
        where competition_id=r.competition_id and allocation_processed_at is not null
      ) then
        v_result:=public.allocate_doubles_entries_v1(r.competition_id);
        if v_result->>'status'='allocated' then v_allocated:=v_allocated+1; end if;
      end if;
    end if;

    if v_now>=(v_timeline->>'draw_lock_game_second')::bigint
       and not exists(
         select 1 from public.tournament_doubles_draw_publications
         where competition_id=r.competition_id
       ) then
      v_result:=public.publish_doubles_draw_v1(r.competition_id);
      if v_result->>'status'='published' then v_drawn:=v_drawn+1; end if;
    end if;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'invitations_expired',v_expired,
    'ai_marketplace_listings',v_ai_listed,
    'ai_teams_created',v_ai_paired,
    'ai_last_minute_teams',v_ai_late_fill,
    'competitions_allocated',v_allocated,
    'draws_published',v_drawn
  );
end;
$$;

revoke all on function public.process_due_doubles_entry_lifecycle_v1()
from public,anon,authenticated;
grant execute on function public.process_due_doubles_entry_lifecycle_v1()
to service_role;

create or replace function public.get_player_calendar_activity_v1(
  p_season integer,
  p_month smallint
)
returns table(
  season integer,
  month smallint,
  day smallint,
  activity_type text,
  source text,
  note text,
  reference_id text
)
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_player_id uuid;
  v_current_abs integer;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if p_season<1 then raise exception 'Invalid season.'; end if;
  if p_month<1 or p_month>12 then raise exception 'Invalid month.'; end if;

  select id into v_player_id
  from public.players
  where owner_user_id=auth.uid() and player_type='human';

  if v_player_id is null then raise exception 'Player not found.'; end if;

  select public.game_day_absolute_v1(d.season,d.month,d.day)
  into v_current_abs
  from public.get_current_game_day_internal_v1() d;

  return query
  with base_rows as (
    select
      a.season,a.month,a.day,a.activity_type,a.source,a.note,a.reference_id,
      case a.activity_type when 'injured' then 1 when 'training_camp' then 4 else 6 end priority
    from public.player_daily_activity a
    where a.player_id=v_player_id
      and a.season=p_season
      and a.month=p_month
      and a.activity_type not in ('home','tournament','travel')
  ),
  travel_rows as (
    select
      gd.season,gd.month,gd.day,
      'travel'::text activity_type,
      case when l.status='completed' then 'travel_completed' else 'travel_plan' end::text source,
      format('Travel to %s',coalesce(nullif(l.destination_city,''),l.destination_country_code))::text note,
      l.id::text reference_id,
      3 priority
    from public.player_travel_legs l
    cross join lateral public.absolute_game_day_v1(l.departure_absolute_day) gd
    where l.player_id=v_player_id
      and l.status in ('planned','completed')
      and gd.season=p_season
      and gd.month=p_month
  ),
  singles_confirmed as (
    select
      gd.season,gd.month,gd.day,
      'tournament'::text activity_type,
      case
        when bool_and(m.status='completed') or min(x.abs_day)<v_current_abs then 'tournament_completed'
        else 'tournament_confirmed'
      end::text source,
      format('%s (S) · %s',ts.name,string_agg(distinct m.round_label,' + '))::text note,
      m.competition_id::text reference_id,
      2 priority
    from public.tournament_matches m
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    cross join lateral (
      select (((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer abs_day
    ) x
    cross join lateral public.absolute_game_day_v1(x.abs_day) gd
    where (m.player1_id=v_player_id or m.player2_id=v_player_id)
      and m.status not in ('bye','cancelled')
      and gd.season=p_season
      and gd.month=p_month
    group by gd.season,gd.month,gd.day,ts.name,m.competition_id
  ),
  singles_entry as (
    select te.competition_id,te.draw_type,ed.season_number,ts.name tournament_name,
      (
        select min(pm.round_number)
        from public.tournament_matches pm
        where pm.competition_id=te.competition_id
          and pm.draw_type=te.draw_type
          and (pm.player1_id=v_player_id or pm.player2_id=v_player_id)
          and pm.status not in ('bye','cancelled')
      ) first_playable_round
    from public.tournament_entries te
    join public.tournament_world_competitions wc on wc.id=te.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    where te.player_id=v_player_id
      and te.entry_status='active'
      and wc.status<>'canceled'
      and ed.status<>'canceled'
  ),
  singles_accepted_context as (
    select te.competition_id,ed.season_number,ts.name tournament_name,slot.season_week
    from public.tournament_entries te
    join public.tournament_world_competitions wc on wc.id=te.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    join lateral (
      select s.season_week
      from public.tournament_schedule_slots s
      where s.tournament_edition_id=ed.id and s.phase in ('main_draw','full')
      order by case when s.phase='main_draw' then 0 else 1 end,s.slot_order
      limit 1
    ) slot on true
    where te.player_id=v_player_id
      and te.entry_status='active'
      and te.draw_type='main_draw'
      and wc.status<>'canceled'
      and ed.status<>'canceled'
      and not exists(
        select 1 from public.tournament_matches own_match
        where own_match.competition_id=te.competition_id
          and own_match.draw_type='main_draw'
          and (own_match.player1_id=v_player_id or own_match.player2_id=v_player_id)
          and own_match.status not in ('bye','cancelled')
      )
  ),
  singles_accepted as (
    select
      gd.season,gd.month,gd.day,'tournament'::text activity_type,
      'tournament_accepted'::text source,
      format('%s (S)',sac.tournament_name)::text note,
      sac.competition_id::text reference_id,8 priority
    from singles_accepted_context sac
    cross join generate_series(1,7) td(day_number)
    cross join lateral (
      select (((sac.season_number-1)*366)+2+((sac.season_week-1)*7)+(td.day_number-1))::integer abs_day
    ) x
    cross join lateral public.absolute_game_day_v1(x.abs_day) gd
    where x.abs_day>=v_current_abs
      and gd.season=p_season and gd.month=p_month
  ),
  singles_predicted as (
    select distinct
      gd.season,gd.month,gd.day,'tournament'::text activity_type,
      'tournament_predicted'::text source,
      format('%s (S) · Possible %s',se.tournament_name,r.round_label)::text note,
      se.competition_id::text reference_id,9 priority
    from singles_entry se
    join public.tournament_matches r
      on r.competition_id=se.competition_id
      and r.draw_type=se.draw_type
      and se.first_playable_round is not null
      and r.round_number>se.first_playable_round
      and r.status<>'cancelled'
    cross join lateral (
      select (((se.season_number-1)*366)+2+((r.scheduled_season_week-1)*7)+(r.scheduled_day-1))::integer abs_day
    ) x
    cross join lateral public.absolute_game_day_v1(x.abs_day) gd
    where x.abs_day>=v_current_abs
      and gd.season=p_season and gd.month=p_month
      and not exists(
        select 1 from public.tournament_matches own_round
        where own_round.competition_id=se.competition_id
          and own_round.draw_type=se.draw_type
          and own_round.round_number=r.round_number
          and (own_round.player1_id=v_player_id or own_round.player2_id=v_player_id)
      )
  ),
  doubles_team as (
    select
      t.id team_id,t.competition_id,ed.season_number,ts.name tournament_name,
      coalesce(
        max(ss.season_week) filter(where ss.phase='full'),
        max(ss.season_week) filter(where ss.phase='main_draw'),
        max(ss.season_week)
      )::integer season_week,
      coalesce(max(dm.round_number) filter(
        where (dm.team1_id=t.id or dm.team2_id=t.id)
          and dm.status not in ('bye','cancelled')
      ),0)::integer last_own_round,
      exists(
        select 1 from public.tournament_doubles_matches lost
        where lost.competition_id=t.competition_id
          and (lost.team1_id=t.id or lost.team2_id=t.id)
          and lost.status in ('completed','walkover')
          and lost.winner_team_id is not null
          and lost.winner_team_id<>t.id
      ) eliminated
    from public.tournament_doubles_teams t
    join public.tournament_world_competitions wc on wc.id=t.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    left join public.tournament_schedule_slots ss on ss.tournament_edition_id=ed.id
    left join public.tournament_doubles_matches dm on dm.competition_id=t.competition_id
    where (t.player1_id=v_player_id or t.player2_id=v_player_id)
      and t.status in ('confirmed','active','alternate')
      and wc.status<>'canceled'
      and ed.status<>'canceled'
    group by t.id,t.competition_id,ed.season_number,ts.name
  ),
  doubles_confirmed as (
    select
      gd.season,gd.month,gd.day,'tournament'::text activity_type,
      case
        when dm.status='completed' or x.abs_day<v_current_abs then 'doubles_tournament_completed'
        else 'doubles_tournament_confirmed'
      end::text source,
      format('%s (D) · %s',dt.tournament_name,dm.round_label)::text note,
      dt.competition_id::text reference_id,2 priority
    from doubles_team dt
    join public.tournament_doubles_matches dm
      on dm.competition_id=dt.competition_id
      and (dm.team1_id=dt.team_id or dm.team2_id=dt.team_id)
      and dm.status not in ('bye','cancelled')
    cross join lateral (
      select (((dt.season_number-1)*366)+2+((dm.scheduled_season_week-1)*7)+(dm.scheduled_day-1))::integer abs_day
    ) x
    cross join lateral public.absolute_game_day_v1(x.abs_day) gd
    where gd.season=p_season and gd.month=p_month
  ),
  doubles_accepted as (
    select
      gd.season,gd.month,gd.day,'tournament'::text activity_type,
      'doubles_tournament_accepted'::text source,
      format('%s (D)',dt.tournament_name)::text note,
      dt.competition_id::text reference_id,8 priority
    from doubles_team dt
    cross join generate_series(1,7) td(day_number)
    cross join lateral (
      select (((dt.season_number-1)*366)+2+((dt.season_week-1)*7)+(td.day_number-1))::integer abs_day
    ) x
    cross join lateral public.absolute_game_day_v1(x.abs_day) gd
    where dt.last_own_round=0
      and not dt.eliminated
      and x.abs_day>=v_current_abs
      and gd.season=p_season and gd.month=p_month
  ),
  doubles_predicted as (
    select distinct
      gd.season,gd.month,gd.day,'tournament'::text activity_type,
      'doubles_tournament_predicted'::text source,
      format('%s (D) · Possible %s',dt.tournament_name,dm.round_label)::text note,
      dt.competition_id::text reference_id,9 priority
    from doubles_team dt
    join public.tournament_doubles_matches dm
      on dm.competition_id=dt.competition_id
      and dm.round_number>dt.last_own_round
      and dm.status<>'cancelled'
    cross join lateral (
      select (((dt.season_number-1)*366)+2+((dm.scheduled_season_week-1)*7)+(dm.scheduled_day-1))::integer abs_day
    ) x
    cross join lateral public.absolute_game_day_v1(x.abs_day) gd
    where dt.last_own_round>0
      and not dt.eliminated
      and x.abs_day>=v_current_abs
      and gd.season=p_season and gd.month=p_month
  ),
  combined as (
    select * from base_rows
    union all select * from travel_rows
    union all select * from singles_confirmed
    union all select * from singles_accepted
    union all select * from singles_predicted
    union all select * from doubles_confirmed
    union all select * from doubles_accepted
    union all select * from doubles_predicted
  ),
  dedup as (
    select c.*,
      row_number() over(
        partition by c.season,c.month,c.day,c.activity_type,c.source,c.note,c.reference_id
        order by c.priority
      ) rn
    from combined c
  )
  select d.season,d.month,d.day,d.activity_type,d.source,d.note,d.reference_id
  from dedup d
  where d.rn=1
  order by d.day,d.priority,d.source,d.note;
end;
$$;

-- Remove stale auto-generated AI marketplace rows which no longer match the
-- 40% qualifier / 15% main-draw rule. Preserve any AI with a pending human
-- invitation, and never touch human listings or confirmed teams.
with active_competitions as (
  select wc.id competition_id
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id and ds.is_enabled
  where wc.status<>'canceled' and ed.status<>'canceled'
),
selected_ai as (
  select te.competition_id,te.player_id
  from public.tournament_entries te
  join public.players p on p.id=te.player_id
  join active_competitions ac on ac.competition_id=te.competition_id
  where te.entry_status='active'
    and p.player_type='ai'
    and (
      (te.draw_type='qualification' and (((hashtextextended(p.id::text||':'||te.competition_id::text,0)%100)+100)%100)<40)
      or
      (te.draw_type='main_draw' and (((hashtextextended(p.id::text||':'||te.competition_id::text,0)%100)+100)%100)<15)
    )
)
update public.tournament_doubles_partner_listings l
set status='expired',closed_at=now(),updated_at=now()
where l.status='active'
  and l.owner_user_id is null
  and not exists(
    select 1 from selected_ai s
    where s.competition_id=l.competition_id and s.player_id=l.player_id
  )
  and not exists(
    select 1 from public.tournament_doubles_partner_invitations i
    where i.competition_id=l.competition_id
      and i.status='pending'
      and (i.inviter_player_id=l.player_id or i.invitee_player_id=l.player_id)
  );

