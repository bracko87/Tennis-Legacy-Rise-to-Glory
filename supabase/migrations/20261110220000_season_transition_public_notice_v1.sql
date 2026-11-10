-- Public, read-only phase for the Season N -> Season N+1 player notice.
-- This function deliberately exposes no private migration journal data.
create or replace function public.get_season_transition_notice_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_total_seconds bigint;
  v_season integer;
  v_source integer;
  v_target integer;
  v_phase text := 'none';
  v_guard record;
  v_run record;
begin
  select c.game_total_seconds into v_total_seconds
  from public.get_game_clock_v1() c;

  if v_total_seconds is null then
    return pg_catalog.jsonb_build_object('phase', 'unavailable');
  end if;

  v_season := pg_catalog.floor(v_total_seconds::numeric / 31622400)::integer + 1;
  v_source := v_season;
  v_target := v_season + 1;

  select g.source_season, g.enabled, g.stop_at_total_seconds
    into v_guard
  from public.season_transition_boundary_guard_v1 g
  where g.id = true;

  select r.source_season, r.target_season, r.status, r.execution_enabled
    into v_run
  from control_center_private.tennis_season_transition_runs_v1 r
  where r.source_season in (v_season, v_season - 1)
  order by r.source_season desc, r.created_at desc
  limit 1;

  if v_run.source_season is not null then
    v_source := v_run.source_season;
    v_target := v_run.target_season;
  end if;

  if v_run.status = 'completed' and v_run.execution_enabled
     and v_season = v_run.target_season
     and v_total_seconds < (v_season - 1)::bigint * 31622400 + 7 * 86400 then
    v_phase := 'completed';
  elsif v_run.status = 'running' and v_run.execution_enabled then
    v_phase := 'running';
  elsif v_run.status in ('failed', 'blocked', 'rolled_back')
        and v_run.source_season = v_season then
    v_phase := 'delayed';
  elsif v_guard.enabled and v_guard.source_season = v_season
        and v_total_seconds >= v_guard.stop_at_total_seconds then
    v_phase := 'preparing';
    v_source := v_season;
    v_target := v_season + 1;
  end if;

  return pg_catalog.jsonb_build_object(
    'phase', v_phase,
    'source_season', v_source,
    'target_season', v_target
  );
end;
$function$;

-- Only an intentionally limited status payload may be read publicly.
revoke all on function public.get_season_transition_notice_v1() from public, anon, authenticated;
grant execute on function public.get_season_transition_notice_v1() to anon, authenticated;

comment on function public.get_season_transition_notice_v1() is
  'Returns only a sanitized public season transition phase, never journal records or operator controls.';
