
alter table public.tournament_doubles_entry_lifecycle
  add column if not exists ai_marketplace_seeded_at timestamptz;

-- Mark already-populated competitions so the clock does not reseed them.
update public.tournament_doubles_entry_lifecycle l
set ai_marketplace_seeded_at=coalesce(l.ai_marketplace_seeded_at,now()),
    updated_at=now()
where exists(
  select 1
  from public.tournament_doubles_partner_listings pl
  join public.players p on p.id=pl.player_id
  where pl.competition_id=l.competition_id
    and p.player_type='ai'
);

create or replace function public.seed_ai_doubles_partner_marketplace_v1(p_competition_id uuid)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
  v_world text;
  v_draw_size integer;
  v_target integer;
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_inserted integer:=0;
begin
  select wc.world,ds.draw_size
  into v_world,v_draw_size
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id
  where wc.id=p_competition_id and ds.is_enabled;

  if v_world is null then return 0; end if;

  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  if v_now<(v_timeline->>'registration_open_game_second')::bigint
     or v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint then
    return 0;
  end if;

  v_target:=greatest(12,coalesce(v_draw_size,16)*2);

  with cheap_pool as (
    select
      p.id,
      coalesce(pr.ranking_points,0) singles_points,
      exists(
        select 1
        from public.tournament_entries te
        where te.competition_id=p_competition_id
          and te.player_id=p.id
          and te.entry_status='active'
      ) same_event_entry,
      exists(
        select 1
        from public.tournament_entries te
        where te.competition_id=p_competition_id
          and te.player_id=p.id
          and te.entry_status='active'
          and te.draw_type='qualification'
      ) same_event_qual,
      ((hashtextextended(p.id::text||':'||p_competition_id::text,0)%100)+100)%100 hash_bucket
    from public.players p
    left join public.player_rankings pr on pr.player_id=p.id
    where p.world=v_world
      and p.player_type='ai'
      and p.moderation_status<>'rejected'
      and not exists(
        select 1
        from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
    order by
      case when exists(
        select 1 from public.tournament_entries te
        where te.competition_id=p_competition_id
          and te.player_id=p.id and te.entry_status='active'
          and te.draw_type='qualification'
      ) then 0
      when exists(
        select 1 from public.tournament_entries te
        where te.competition_id=p_competition_id
          and te.player_id=p.id and te.entry_status='active'
      ) then 1 else 2 end,
      coalesce(pr.ranking_points,0) asc,
      ((hashtextextended(p.id::text||':'||p_competition_id::text,0)%100)+100)%100,
      p.id
    limit greatest(v_target*4,48)
  ),
  eligible as (
    select *
    from cheap_pool
    where (same_event_qual or hash_bucket<50)
      and coalesce(
        (public.check_player_competition_availability_v1(id,p_competition_id)->>'available')::boolean,
        false
      )
    order by
      case when same_event_qual then 0 when same_event_entry then 1 else 2 end,
      singles_points asc,
      hash_bucket,
      id
    limit v_target
  )
  insert into public.tournament_doubles_partner_listings(
    competition_id,player_id,owner_user_id,status,created_at,updated_at,closed_at
  )
  select p_competition_id,id,null,'active',now(),now(),null
  from eligible
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
  v_result jsonb;
  v_n integer;
  v_seeded_at timestamptz;
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
          between v_current_abs_week and v_current_abs_week+4
      and not (
        life.draw_processed_at is not null
        and exists(
          select 1
          from public.tournament_doubles_draw_publications dp
          where dp.competition_id=wc.id
        )
      )
  loop
    v_timeline:=public.get_tournament_doubles_entry_timeline_v1(r.competition_id);

    insert into public.tournament_doubles_entry_lifecycle(competition_id,updated_at)
    values(r.competition_id,now())
    on conflict(competition_id) do nothing;

    select ai_marketplace_seeded_at,partnership_closed_at
    into v_seeded_at,v_partnership_closed_at
    from public.tournament_doubles_entry_lifecycle
    where competition_id=r.competition_id;

    if v_seeded_at is null
       and v_now>=(v_timeline->>'registration_open_game_second')::bigint
       and v_now<(v_timeline->>'registration_deadline_game_second')::bigint then
      v_n:=public.seed_ai_doubles_partner_marketplace_v1(r.competition_id);
      v_ai_listed:=v_ai_listed+coalesce(v_n,0);

      update public.tournament_doubles_entry_lifecycle
      set ai_marketplace_seeded_at=now(),updated_at=now()
      where competition_id=r.competition_id;
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
        select 1
        from public.tournament_doubles_entry_lifecycle
        where competition_id=r.competition_id
          and allocation_processed_at is not null
      ) then
        v_result:=public.allocate_doubles_entries_v1(r.competition_id);
        if v_result->>'status'='allocated' then
          v_allocated:=v_allocated+1;
        end if;
      end if;
    end if;

    if v_now>=(v_timeline->>'draw_lock_game_second')::bigint
       and not exists(
         select 1
         from public.tournament_doubles_draw_publications
         where competition_id=r.competition_id
       ) then
      v_result:=public.publish_doubles_draw_v1(r.competition_id);
      if v_result->>'status'='published' then
        v_drawn:=v_drawn+1;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'invitations_expired',v_expired,
    'ai_marketplace_listings',v_ai_listed,
    'ai_teams_created',v_ai_paired,
    'competitions_allocated',v_allocated,
    'draws_published',v_drawn
  );
end;
$$;

revoke all on function public.process_due_doubles_entry_lifecycle_v1()
from public,anon,authenticated;
grant execute on function public.process_due_doubles_entry_lifecycle_v1()
to service_role;

