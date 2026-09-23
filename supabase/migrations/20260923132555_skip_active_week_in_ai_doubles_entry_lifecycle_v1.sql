
-- Do not retroactively run entry/draw lifecycle for the already-active competition
-- week when AI doubles support is introduced. Entry automation only needs future
-- competitions whose partnership/draw windows can still be acted on.

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
          between v_current_abs_week+1 and v_current_abs_week+4
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

