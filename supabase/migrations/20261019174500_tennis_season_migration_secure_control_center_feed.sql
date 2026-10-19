-- Phase 2: independent, read-only Season Migration mirror for the standalone Control Center.
-- Reuse existing server-side Vault telemetry secrets. Never send tokens or game data to browser code.
-- Does NOT create/approve/execute an actual season migration.
create or replace function control_center_private.build_tennis_season_migration_snapshot_v1()
returns jsonb language plpgsql stable security definer
set search_path = pg_catalog, public, control_center_private
as $$
declare
  v_clock record;
  v_clock_cfg record;
  v_guard record;
  v_season integer;
  v_target integer;
  v_day integer;
  v_boundary bigint;
  v_hours numeric;
  v_editions integer;
  v_slots integer;
  v_main_due integer;
  v_main_crossing integer;
  v_tech_due integer;
  v_tech_crossing integer;
  v_blockers jsonb := '[]'::jsonb;
  v_armed boolean := false;
  v_held boolean := false;
begin
  select * into v_clock from public.get_game_clock_v1();
  select * into v_clock_cfg from public.game_clock where id=1;
  select * into v_guard from public.season_transition_boundary_guard_v1 where id=true;
  if not found or v_clock.game_total_seconds is null then
    raise exception 'Season migration clock guard missing or clock unavailable';
  end if;

  v_season := floor(v_clock.game_total_seconds::numeric / (366*86400))::integer+1;
  v_target := v_season+1;
  v_day := floor(mod(v_clock.game_total_seconds::numeric,366*86400)/86400)::integer+1;
  v_boundary := v_season::bigint*366*86400;
  v_armed := v_guard.enabled and v_guard.source_season=v_season and
    v_guard.stop_at_total_seconds=v_boundary-1;
  v_held := v_armed and v_clock.speed_multiplier=0 and
    v_clock.game_total_seconds=v_guard.stop_at_total_seconds;
  v_hours := case when v_held then 0
    else round(greatest(0,v_boundary-v_clock.game_total_seconds)::numeric/
      greatest(v_clock_cfg.speed_multiplier,0.001)/3600,2)
  end;

  select count(*) into v_editions from public.tournament_editions where season_number=v_target;
  select count(*) into v_slots
    from public.tournament_schedule_slots ss
    join public.tournament_editions e on e.id=ss.tournament_edition_id
    where e.season_number=v_target;

  select count(*) filter(where end_absolute_day<=v_boundary/86400),
         count(*) filter(where end_absolute_day>v_boundary/86400)
    into v_main_due,v_main_crossing
    from public.player_sponsor_contracts where status='active';
  select count(*) filter(where end_absolute_day<=v_boundary/86400),
         count(*) filter(where end_absolute_day>v_boundary/86400)
    into v_tech_due,v_tech_crossing
    from public.player_technical_sponsor_contracts where status='active';

  if not v_armed then
    v_blockers := v_blockers||jsonb_build_array('The shared game clock has no armed source-season boundary guard.');
  end if;
  if v_editions=0 or v_slots=0 then
    v_blockers := v_blockers||jsonb_build_array('Next-season ATP/WTA tournament editions and schedule slots are missing.');
  end if;
  v_blockers := v_blockers||jsonb_build_array(
    'Season transition step runner, signed-contract grandfather registry and recovery journal are not installed.',
    'A verified snapshot/restore exercise and two-season dry run must pass before migration can be approved.'
  );

  return jsonb_build_object(
    'schema_version','tennis_season_migration_v1',
    'as_of',now(),
    'execution_enabled',false,
    'clock',jsonb_build_object(
      'season',v_season,'target_season',v_target,'game_day',v_day,
      'game_total_seconds',v_clock.game_total_seconds,
      'speed_multiplier',v_clock_cfg.speed_multiplier,
      'effective_speed_multiplier',v_clock.speed_multiplier,
      'real_hours_remaining',v_hours,'boundary_guard_armed',v_armed,'boundary_held',v_held
    ),
    'calendar',jsonb_build_object(
      'next_season_editions',v_editions,'next_season_slots',v_slots,'coverage_verified',false
    ),
    'sponsors',jsonb_build_object(
      'main_due_by_boundary',v_main_due,'main_crossing_existing',v_main_crossing,
      'technical_due_by_boundary',v_tech_due,'technical_crossing_existing',v_tech_crossing,
      'compliance_verified',false
    ),
    'steps',jsonb_build_array(
      jsonb_build_object('step_key','discover','status','blocked'),
      jsonb_build_object('step_key','lock','status','waiting'),
      jsonb_build_object('step_key','settle','status','waiting'),
      jsonb_build_object('step_key','snapshot','status','waiting'),
      jsonb_build_object('step_key','rankings','status','waiting'),
      jsonb_build_object('step_key','contracts','status','waiting'),
      jsonb_build_object('step_key','finance','status','waiting'),
      jsonb_build_object('step_key','development','status','waiting'),
      jsonb_build_object('step_key','identity','status','waiting'),
      jsonb_build_object('step_key','calendar','status','blocked'),
      jsonb_build_object('step_key','switch','status','blocked'),
      jsonb_build_object('step_key','postcheck','status','waiting'),
      jsonb_build_object('step_key','close','status','waiting')
    ),
    'run',null,
    'blockers',v_blockers
  );
end;
$$;

revoke all on function control_center_private.build_tennis_season_migration_snapshot_v1() from public, anon, authenticated;

create or replace function control_center_private.push_tennis_season_migration_snapshot_v1()
returns bigint language plpgsql security definer
set search_path = pg_catalog, public, vault, control_center_private
as $$
declare
  v_endpoint text;
  v_token text;
  v_request_id bigint;
begin
  select decrypted_secret into v_endpoint from vault.decrypted_secrets
  where name='game_control_center_telemetry_endpoint';
  select decrypted_secret into v_token from vault.decrypted_secrets
  where name='game_control_center_telemetry_token';
  if v_endpoint is null or v_token is null then
    raise exception 'Game Control Center telemetry secrets are missing';
  end if;
  select net.http_post(
    url := v_endpoint,
    headers := jsonb_build_object('Content-Type','application/json',
      'Authorization','Bearer '||v_token),
    body := jsonb_build_object(
      'sourceProjectRef','cwfznmroiqcyhfkfcrow',
      'adminModules',jsonb_build_array(
        jsonb_build_object(
          'moduleKey','migration-process','status','warning',
          'payload',control_center_private.build_tennis_season_migration_snapshot_v1()
        )
      )
    ),
    timeout_milliseconds := 30000
  ) into v_request_id;
  return v_request_id;
end;
$$;
revoke all on function control_center_private.push_tennis_season_migration_snapshot_v1() from public, anon, authenticated;

select cron.schedule('tennis-season-migration-snapshot-v1','*/5 * * * *',
  'select control_center_private.push_tennis_season_migration_snapshot_v1();');
