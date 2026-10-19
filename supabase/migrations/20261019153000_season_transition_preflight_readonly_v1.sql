-- Read-only, administrator-scoped season-transition preflight for Game Control Center.
-- PHASE 1 ONLY: this RPC never starts a rollover or modifies the game clock.
-- Deploy through the controlled staging -> main release process.
create or replace function public.get_admin_season_transition_readiness_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_clock record;
  v_season integer;
  v_target integer;
  v_day integer;
  v_editions integer;
  v_slots integer;
  v_blockers jsonb := '[]'::jsonb;
  v_seconds_left numeric;
  v_boundary_absolute_day integer;
  v_main_active integer;
  v_main_due integer;
  v_main_crossing integer;
  v_tech_active integer;
  v_tech_due integer;
  v_tech_crossing integer;
begin
  if auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;
  select * into v_clock from public.get_game_clock_v1();
  if not found then
    raise exception 'Game clock unavailable';
  end if;
  v_season := floor(v_clock.game_total_seconds::numeric / (366 * 86400))::integer + 1;
  v_target := v_season + 1;
  v_day := floor(mod(v_clock.game_total_seconds::numeric, 366 * 86400) / 86400)::integer + 1;
  v_seconds_left := (366 * 86400) - mod(v_clock.game_total_seconds::numeric, 366 * 86400);
  v_boundary_absolute_day := v_season * 366;
  -- Read-only sponsor audit; existing crossing agreements must NOT be changed.
  select count(*),
         count(*) filter (where end_absolute_day <= v_boundary_absolute_day),
         count(*) filter (where end_absolute_day > v_boundary_absolute_day)
    into v_main_active,v_main_due,v_main_crossing
  from public.player_sponsor_contracts where status = 'active';
  select count(*),
         count(*) filter (where end_absolute_day <= v_boundary_absolute_day),
         count(*) filter (where end_absolute_day > v_boundary_absolute_day)
    into v_tech_active,v_tech_due,v_tech_crossing
  from public.player_technical_sponsor_contracts where status = 'active';
  select count(*) into v_editions from public.tournament_editions where season_number=v_target;
  select count(*) into v_slots
    from public.tournament_schedule_slots s
    join public.tournament_editions e on e.id=s.tournament_edition_id
    where e.season_number=v_target;

  if v_editions=0 or v_slots=0 then
    v_blockers := v_blockers || jsonb_build_array('Next-season ATP/WTA calendar is missing.');
  end if;
  v_blockers := v_blockers || jsonb_build_array(
    'Transition runner, backup gate, journal and tested clock lock not yet installed.',
    'Annual sponsorship renewals and grandfathered contract registry are not yet implemented.',
    'Season N→N+1 end-to-end dry-run has not been certified.'
  );

  return jsonb_build_object(
    'phase','design_only',
    'execution_enabled',false,
    'as_of',v_clock.server_now,
    'clock',jsonb_build_object(
      'season',v_season,
      'target_season',v_target,
      'game_day',v_day,
      'speed_multiplier',v_clock.speed_multiplier,
      'seconds_remaining',v_seconds_left,
      'real_hours_remaining',round(v_seconds_left / greatest(v_clock.speed_multiplier,0.001) / 3600,1)
    ),
    'calendar',jsonb_build_object(
      'next_season_editions',v_editions,
      'next_season_slots',v_slots,
      'coverage_verified',false
    ),
    'sponsors',jsonb_build_object(
      'policy','annual_new_contracts_grandfather_signed_legacy',
      'boundary_absolute_day',v_boundary_absolute_day,
      'main_active',v_main_active,
      'main_due_by_boundary',v_main_due,
      'main_crossing_existing',v_main_crossing,
      'technical_active',v_tech_active,
      'technical_due_by_boundary',v_tech_due,
      'technical_crossing_existing',v_tech_crossing,
      'compliance_verified',false
    ),
    'blockers',v_blockers
  );
end;
$$;
revoke all on function public.get_admin_season_transition_readiness_v1() from public;
revoke all on function public.get_admin_season_transition_readiness_v1() from anon;
grant execute on function public.get_admin_season_transition_readiness_v1() to authenticated;
