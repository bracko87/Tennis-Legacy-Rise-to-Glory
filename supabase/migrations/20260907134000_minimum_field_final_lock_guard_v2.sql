-- Harden the minimum-field guard so it still uses the current final-field-lock
-- timing even if the user-facing lifecycle RPC cannot be called from cron.
create or replace function public.process_minimum_tournament_fields_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  d record;
  r record;
  v_abs integer;
  v_game_seconds bigint;
  v_lifecycle jsonb;
  v_locked boolean;
  v_count integer:=0;
  v_result jsonb;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  select gc.game_total_seconds::bigint into v_game_seconds from public.get_game_clock_v1() gc;

  for r in
    select
      wc.id,
      min(public.training_camp_week_start_absolute_v1(ed.season_number,sl.season_week::smallint))::integer start_abs
    from public.tournament_world_competitions wc
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_schedule_slots sl on sl.tournament_edition_id=ed.id
    where wc.status<>'canceled'
      and ed.status<>'canceled'
      and not exists(select 1 from public.tournament_draw_publications dp where dp.competition_id=wc.id)
      and not exists(select 1 from public.tournament_matches tm where tm.competition_id=wc.id)
    group by wc.id,ed.season_number
    having min(public.training_camp_week_start_absolute_v1(ed.season_number,sl.season_week::smallint))::integer>=v_abs
       and min(public.training_camp_week_start_absolute_v1(ed.season_number,sl.season_week::smallint))::integer<=v_abs+14
  loop
    v_locked:=false;

    begin
      v_lifecycle:=public.get_tournament_entry_lifecycle_v2(r.id);
      v_locked:=coalesce((v_lifecycle->>'field_locked')::boolean,false);
    exception when others then
      v_lifecycle:=null;
    end;

    -- Current lifecycle rule: final field lock is 18:00 on the day eight
    -- calendar dates before the tournament's Monday start. This mirrors the
    -- published lifecycle timeline and gives cron a deterministic fallback.
    if not v_locked then
      v_locked:=v_game_seconds>=(((r.start_abs-8)::bigint*86400)+(18*3600));
    end if;

    if v_locked then
      v_result:=public.cancel_tournament_for_minimum_field_v1(r.id);
      if v_result->>'status'='canceled_minimum_field' then v_count:=v_count+1; end if;
    end if;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'canceled_tournaments',v_count,
    'game_absolute_day',v_abs,
    'game_total_seconds',v_game_seconds
  );
end;
$$;
revoke all on function public.process_minimum_tournament_fields_v1() from public,anon,authenticated;

select cron.unschedule(jobid) from cron.job where jobname='tennis-minimum-field-v1';
select cron.schedule(
  'tennis-minimum-field-v1',
  '19 * * * *',
  'select public.process_minimum_tournament_fields_v1();'
);
