
-- Restrict AI doubles partner candidates to the same tournament's singles field/applications.
-- Also expose Premium doubles ranking protection with the same 5-result cap as singles.

create or replace function public.get_premium_doubles_ranking_protection_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_payload jsonb;
  v_items jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not public.has_active_premium_v1() then
    return jsonb_build_object(
      'premium',false,
      'locked',true,
      'contributions','[]'::jsonb
    );
  end if;

  v_payload:=public.get_player_doubles_ranking_expirations_v1();

  select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb)
  into v_items
  from jsonb_array_elements(coalesce(v_payload->'contributions','[]'::jsonb)) with ordinality
  where ordinality<=5;

  return v_payload || jsonb_build_object(
    'premium',true,
    'locked',false,
    'contributions',v_items
  );
end;
$$;

revoke all on function public.get_premium_doubles_ranking_protection_v1()
from public,anon;
grant execute on function public.get_premium_doubles_ranking_protection_v1()
to authenticated,service_role;

create or replace function public.seed_ai_doubles_partner_marketplace_v1(p_competition_id uuid)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
  v_world text;
  v_draw_size integer;
  v_minimum_teams integer;
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_inserted integer:=0;
begin
  select wc.world,ds.draw_size,ds.minimum_teams
  into v_world,v_draw_size,v_minimum_teams
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds
    on ds.tournament_series_id=ed.tournament_series_id
  where wc.id=p_competition_id
    and ds.is_enabled;

  if v_world is null then
    return 0;
  end if;

  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  if v_now<(v_timeline->>'registration_open_game_second')::bigint
     or v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint then
    return 0;
  end if;

  with same_event_pool as (
    select
      p.id,
      coalesce(pr.ranking_points,0) singles_points,
      case
        when exists(
          select 1
          from public.tournament_entries te
          where te.competition_id=p_competition_id
            and te.player_id=p.id
            and te.entry_status='active'
            and te.draw_type='qualification'
        ) or exists(
          select 1
          from public.tournament_applications ta
          where ta.competition_id=p_competition_id
            and ta.player_id=p.id
            and ta.status='accepted_qualification'
        ) then 0
        when exists(
          select 1
          from public.tournament_entries te
          where te.competition_id=p_competition_id
            and te.player_id=p.id
            and te.entry_status='active'
            and te.draw_type='main_draw'
        ) or exists(
          select 1
          from public.tournament_applications ta
          where ta.competition_id=p_competition_id
            and ta.player_id=p.id
            and ta.status='accepted_main_draw'
        ) then 1
        else 2
      end source_priority,
      ((hashtextextended(p.id::text||':'||p_competition_id::text,0)%100)+100)%100 hash_bucket
    from public.players p
    left join public.player_rankings pr on pr.player_id=p.id
    where p.world=v_world
      and p.player_type='ai'
      and p.moderation_status<>'rejected'
      and (
        exists(
          select 1
          from public.tournament_entries te
          where te.competition_id=p_competition_id
            and te.player_id=p.id
            and te.entry_status='active'
            and te.draw_type in ('main_draw','qualification')
        )
        or exists(
          select 1
          from public.tournament_applications ta
          where ta.competition_id=p_competition_id
            and ta.player_id=p.id
            and ta.status in ('accepted_main_draw','accepted_qualification')
        )
        or exists(
          select 1
          from public.tournament_applications ta
          where ta.competition_id=p_competition_id
            and ta.player_id=p.id
            and ta.status='applied'
            and ta.priority=(
              select min(ta2.priority)
              from public.tournament_applications ta2
              where ta2.player_id=ta.player_id
                and ta2.target_season_week=ta.target_season_week
                and ta2.world=ta.world
                and ta2.status='applied'
            )
        )
      )
      and not exists(
        select 1
        from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
  ),
  available_pool as (
    select *
    from same_event_pool
    where coalesce(
      (public.check_player_competition_availability_v1(id,p_competition_id)->>'available')::boolean,
      false
    )
  ),
  ranked_pool as (
    select
      a.*,
      row_number() over(
        order by a.source_priority,a.singles_points asc,a.hash_bucket,a.id
      ) rn,
      count(*) over() candidate_count
    from available_pool a
  ),
  chosen as (
    select *
    from ranked_pool
    where rn<=least(
      coalesce(v_draw_size,16)*2,
      greatest(
        coalesce(v_minimum_teams,4)*2,
        ceil(candidate_count/2.0)::integer
      )
    )
  )
  insert into public.tournament_doubles_partner_listings(
    competition_id,player_id,owner_user_id,status,created_at,updated_at,closed_at
  )
  select p_competition_id,id,null,'active',now(),now(),null
  from chosen
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

create or replace function public.pair_ai_doubles_teams_v1(p_competition_id uuid)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
  v_draw_size integer;
  v_existing integer;
  v_needed integer;
  v_p1 uuid;
  v_p2 uuid;
  v_team uuid;
  v_created integer:=0;
begin
  select ds.draw_size
  into v_draw_size
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds
    on ds.tournament_series_id=ed.tournament_series_id
  where wc.id=p_competition_id
    and ds.is_enabled;

  if v_draw_size is null then
    return 0;
  end if;

  select count(*)
  into v_existing
  from public.tournament_doubles_teams
  where competition_id=p_competition_id
    and status in ('confirmed','active','alternate');

  v_needed:=greatest(0,v_draw_size-v_existing);

  while v_needed>0 loop
    v_p1:=null;
    v_p2:=null;

    select l.player_id
    into v_p1
    from public.tournament_doubles_partner_listings l
    join public.players p on p.id=l.player_id
    where l.competition_id=p_competition_id
      and l.status='active'
      and p.player_type='ai'
      and (
        exists(
          select 1 from public.tournament_entries te
          where te.competition_id=p_competition_id
            and te.player_id=p.id
            and te.entry_status='active'
            and te.draw_type in ('main_draw','qualification')
        )
        or exists(
          select 1 from public.tournament_applications ta
          where ta.competition_id=p_competition_id
            and ta.player_id=p.id
            and ta.status in ('applied','accepted_main_draw','accepted_qualification')
        )
      )
      and not exists(
        select 1 from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
    order by
      case when exists(
        select 1 from public.tournament_entries te
        where te.competition_id=p_competition_id
          and te.player_id=p.id
          and te.entry_status='active'
          and te.draw_type='qualification'
      ) then 0 else 1 end,
      public.get_doubles_player_entry_strength_v1(p.id,p_competition_id) desc,
      p.id
    limit 1;

    exit when v_p1 is null;

    select l.player_id
    into v_p2
    from public.tournament_doubles_partner_listings l
    join public.players p on p.id=l.player_id
    where l.competition_id=p_competition_id
      and l.status='active'
      and p.player_type='ai'
      and l.player_id<>v_p1
      and (
        exists(
          select 1 from public.tournament_entries te
          where te.competition_id=p_competition_id
            and te.player_id=p.id
            and te.entry_status='active'
            and te.draw_type in ('main_draw','qualification')
        )
        or exists(
          select 1 from public.tournament_applications ta
          where ta.competition_id=p_competition_id
            and ta.player_id=p.id
            and ta.status in ('applied','accepted_main_draw','accepted_qualification')
        )
      )
      and not exists(
        select 1 from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
    order by
      case when exists(
        select 1 from public.tournament_entries te
        where te.competition_id=p_competition_id
          and te.player_id=p.id
          and te.entry_status='active'
          and te.draw_type='qualification'
      ) then 0 else 1 end,
      public.get_doubles_player_entry_strength_v1(p.id,p_competition_id) desc,
      p.id
    limit 1;

    exit when v_p2 is null;

    begin
      v_team:=public.create_doubles_team_internal_v1(
        p_competition_id,v_p1,v_p2,'ai_marketplace'
      );

      update public.tournament_doubles_partner_listings
      set status='matched',closed_at=now(),updated_at=now()
      where competition_id=p_competition_id
        and player_id in (v_p1,v_p2)
        and status='active';

      v_created:=v_created+1;
      v_needed:=v_needed-1;
    exception when others then
      update public.tournament_doubles_partner_listings
      set status='expired',closed_at=now(),updated_at=now()
      where competition_id=p_competition_id
        and player_id in (v_p1,v_p2)
        and status='active';
      exit;
    end;
  end loop;

  return v_created;
end;
$$;

revoke all on function public.pair_ai_doubles_teams_v1(uuid)
from public,anon,authenticated;
grant execute on function public.pair_ai_doubles_teams_v1(uuid)
to service_role;

-- Remove the overly-broad AI listings created by the previous implementation.
update public.tournament_doubles_partner_listings l
set status='expired',
    closed_at=now(),
    updated_at=now()
from public.players p
where p.id=l.player_id
  and p.player_type='ai'
  and l.status='active';

-- Rebuild only currently actionable partner markets from same-event singles players.
do $$
declare
  r record;
  v_n integer;
begin
  for r in
    select wc.id
    from public.tournament_world_competitions wc
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_doubles_settings ds
      on ds.tournament_series_id=ed.tournament_series_id
     and ds.is_enabled
    where wc.status<>'canceled'
      and ed.status<>'canceled'
      and public.get_tournament_doubles_entry_timeline_v1(wc.id)->>'phase'
          in ('marketplace_open','partnership_resolution')
      and not exists(
        select 1
        from public.tournament_doubles_draw_publications dp
        where dp.competition_id=wc.id
      )
  loop
    v_n:=public.seed_ai_doubles_partner_marketplace_v1(r.id);

    insert into public.tournament_doubles_entry_lifecycle(
      competition_id,ai_marketplace_seeded_at,updated_at
    )
    values(r.id,now(),now())
    on conflict(competition_id) do update
    set ai_marketplace_seeded_at=now(),
        updated_at=now();
  end loop;
end;
$$;

