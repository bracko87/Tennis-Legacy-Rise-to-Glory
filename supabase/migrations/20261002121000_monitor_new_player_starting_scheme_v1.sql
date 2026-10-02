-- System Health integration for New Player Starting Scheme v1.
--
-- Policy: every new production subsystem must register health monitoring and
-- surface its state through the System Health module consumed by Control Center.
--
-- This checker verifies:
-- * the master initialization trigger/function are installed
-- * core starter configuration remains correct
-- * country property tiers remain complete
-- * all new human careers created after scheme enforcement have an audit record
-- * Day-1 cash, Coins and exact starter equipment were created correctly
-- * initialization validation captured zero staff/sponsors/memberships/calendar/training
-- * one safe automatic recovery attempt is made for very recent incomplete careers

create table if not exists public.new_player_scheme_health_config (
  singleton_id boolean primary key default true check(singleton_id),
  scheme_version text not null,
  enforced_from_at timestamptz not null,
  updated_at timestamptz not null default now()
);

insert into public.new_player_scheme_health_config(singleton_id,scheme_version,enforced_from_at)
values(true,'v1','2026-10-02 09:45:00+00'::timestamptz)
on conflict(singleton_id) do update set
  scheme_version=excluded.scheme_version,
  enforced_from_at=least(public.new_player_scheme_health_config.enforced_from_at,excluded.enforced_from_at),
  updated_at=now();

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values
(
  'cron:tennis-new-player-starting-scheme-health-v1',
  'New player initialization health job',
  'Player state',
  'Runs the New Player Starting Scheme integrity and recovery check every 5 minutes.',
  'cron',
  'tennis-new-player-starting-scheme-health-v1',
  true,
  'critical',
  5,
  15,
  true,
  42
),
(
  'check:new_player_starting_scheme',
  'New player starting scheme',
  'Player state',
  'Verifies every newly created human career receives the complete approved Day-1 package exactly once.',
  'business_check',
  null,
  true,
  'critical',
  5,
  10,
  true,
  215
)
on conflict(process_key) do update set
  label=excluded.label,
  category=excluded.category,
  description=excluded.description,
  source_kind=excluded.source_kind,
  source_ref=excluded.source_ref,
  user_sensitive=excluded.user_sensitive,
  incident_severity=excluded.incident_severity,
  expected_interval_minutes=excluded.expected_interval_minutes,
  stale_after_minutes=excluded.stale_after_minutes,
  email_alerts_enabled=excluded.email_alerts_enabled,
  is_enabled=true,
  sort_order=excluded.sort_order,
  updated_at=now();

create or replace function public.check_new_player_starting_scheme_health_v1()
returns jsonb
language plpgsql
security definer
set search_path=public,pg_catalog,pg_temp
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_enforced_from timestamptz;
  v_scheme_version text;
  v_trigger_ok boolean:=false;
  v_finance_ok boolean:=false;
  v_catalog_ok boolean:=false;
  v_country_tiers_ok boolean:=false;
  v_coin_guard_ok boolean:=false;
  v_equipment_guard_ok boolean:=false;
  v_missing_audit integer:=0;
  v_bad_cash integer:=0;
  v_bad_coins integer:=0;
  v_bad_equipment integer:=0;
  v_bad_validation integer:=0;
  v_repair_attempted integer:=0;
  v_repair_succeeded integer:=0;
  v_repair_failed integer:=0;
  v_problem_count integer:=0;
  v_details jsonb;
  r record;
begin
  select scheme_version,enforced_from_at
  into v_scheme_version,v_enforced_from
  from public.new_player_scheme_health_config
  where singleton_id=true;

  select exists(
    select 1
    from pg_trigger tg
    join pg_class c on c.oid=tg.tgrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relname='players'
      and tg.tgname='zz_initialize_new_human_career_v1'
      and not tg.tgisinternal
      and tg.tgenabled<>'D'
  ) into v_trigger_ok;

  select exists(
    select 1
    from public.career_finance_settings
    where id=1 and starting_balance=25000 and currency='USD'
  ) into v_finance_ok;

  select count(*)=4
  into v_catalog_ok
  from public.equipment_catalog_items c
  where c.sku in (
    'RKT-ROSIGNOL-01',
    'SHO-ANTTA-01',
    'APP-BLOKUV-01',
    'APP-WTA-BLOKUV-01'
  )
    and c.is_active
    and c.availability_status='available';

  v_catalog_ok:=v_catalog_ok and exists(
    select 1
    from public.equipment_catalog_items
    where sku='SHO-ANTTA-01'
      and item_type='shoes'
      and tour_scope='unisex'
      and tier=1
      and price_usd=80
  );

  select
    (select count(*) from public.private_life_property_price_tiers)=10
    and
    (select count(*) from public.private_life_country_property_tiers)
      =(select count(*) from public.countries)
  into v_country_tiers_ok;

  select exists(
    select 1
    from pg_indexes
    where schemaname='public'
      and tablename='coin_ledger'
      and indexname='coin_ledger_new_career_starting_uidx'
  ) into v_coin_guard_ok;

  select exists(
    select 1
    from pg_indexes
    where schemaname='public'
      and tablename='player_equipment_inventory'
      and indexname='player_equipment_inventory_one_starter_item_uidx'
  ) into v_equipment_guard_ok;

  -- Automatic recovery is deliberately narrow: only recent new careers with
  -- no initialization audit and no subsequent user-managed state are eligible.
  for r in
    select p.id
    from public.players p
    left join public.new_player_initialization_audit a on a.player_id=p.id
    where p.player_type='human'
      and p.owner_user_id is not null
      and p.created_at>=v_enforced_from
      and a.player_id is null
      and p.created_at>=now()-interval '15 minutes'
      and not exists(select 1 from public.player_staff_contracts s where s.player_id=p.id)
      and not exists(select 1 from public.player_sponsor_contracts s where s.player_id=p.id)
      and not exists(select 1 from public.player_technical_sponsor_contracts s where s.player_id=p.id)
      and not exists(select 1 from public.national_association_memberships m where m.player_id=p.id)
      and not exists(select 1 from public.tennis_club_memberships m where m.player_id=p.id)
      and not exists(select 1 from public.player_calendar_commitments c where c.player_id=p.id)
      and not exists(select 1 from public.player_training_plans t where t.player_id=p.id)
  loop
    v_repair_attempted:=v_repair_attempted+1;
    begin
      perform public.initialize_new_human_career_v1(r.id);
      if exists(select 1 from public.new_player_initialization_audit a where a.player_id=r.id) then
        v_repair_succeeded:=v_repair_succeeded+1;
      else
        v_repair_failed:=v_repair_failed+1;
      end if;
    exception when others then
      v_repair_failed:=v_repair_failed+1;
    end;
  end loop;

  select count(*) into v_missing_audit
  from public.players p
  left join public.new_player_initialization_audit a on a.player_id=p.id
  where p.player_type='human'
    and p.owner_user_id is not null
    and p.created_at>=v_enforced_from
    and a.player_id is null;

  select count(*) into v_bad_cash
  from public.players p
  where p.player_type='human'
    and p.owner_user_id is not null
    and p.created_at>=v_enforced_from
    and not exists(
      select 1
      from public.career_finance_transactions t
      where t.player_id=p.id
        and t.idempotency_key='career-opening-balance'
        and t.amount=25000
        and t.balance_before=0
        and t.balance_after=25000
    );

  select count(*) into v_bad_coins
  from (
    select p.owner_user_id
    from public.players p
    where p.player_type='human'
      and p.owner_user_id is not null
      and p.created_at>=v_enforced_from
    group by p.owner_user_id
    having (
      select count(*)
      from public.coin_ledger l
      where l.user_id=p.owner_user_id
        and l.reference_id='new-career-starting-coins-v1'
        and l.entry_type='signup_reward'
        and l.amount=20
    )<>1
  ) x;

  select count(*) into v_bad_equipment
  from public.players p
  where p.player_type='human'
    and p.owner_user_id is not null
    and p.created_at>=v_enforced_from
    and (
      (
        select count(*)
        from public.player_equipment_inventory i
        join public.equipment_catalog_items c on c.id=i.catalog_item_id
        where i.player_id=p.id
          and i.acquired_source='starter'
          and i.purchase_price_usd=0
          and c.sku in (
            'RKT-ROSIGNOL-01',
            'SHO-ANTTA-01',
            case when p.world='WTA' then 'APP-WTA-BLOKUV-01' else 'APP-BLOKUV-01' end
          )
      )<>3
      or exists(
        select 1
        from public.player_equipment_inventory i
        join public.equipment_catalog_items c on c.id=i.catalog_item_id
        where i.player_id=p.id
          and i.acquired_source='starter'
          and c.item_type='accessory'
      )
    );

  select count(*) into v_bad_validation
  from public.new_player_initialization_audit a
  join public.players p on p.id=a.player_id
  where p.player_type='human'
    and p.owner_user_id is not null
    and p.created_at>=v_enforced_from
    and (
      a.scheme_version<>v_scheme_version
      or coalesce((a.validation_result->>'starter_equipment_count')::integer,-1)<>3
      or coalesce((a.validation_result->>'starter_accessory_count')::integer,-1)<>0
      or coalesce((a.validation_result->>'active_staff_count')::integer,-1)<>0
      or coalesce((a.validation_result->>'active_regular_sponsors')::integer,-1)<>0
      or coalesce((a.validation_result->>'active_technical_sponsors')::integer,-1)<>0
      or coalesce((a.validation_result->>'active_association_memberships')::integer,-1)<>0
      or coalesce((a.validation_result->>'club_memberships')::integer,-1)<>0
      or coalesce((a.validation_result->>'calendar_commitments')::integer,-1)<>0
      or coalesce((a.validation_result->>'configured_training_plans')::integer,-1)<>0
      or coalesce((a.validation_result->>'skill_rows')::integer,-1)<>1
      or coalesce((a.validation_result->>'singles_ranking_points')::bigint,-1)<>0
      or coalesce((a.validation_result->>'doubles_ranking_points')::bigint,-1)<>0
    );

  v_problem_count:=
    (case when v_trigger_ok then 0 else 1 end)
    +(case when v_finance_ok then 0 else 1 end)
    +(case when v_catalog_ok then 0 else 1 end)
    +(case when v_country_tiers_ok then 0 else 1 end)
    +(case when v_coin_guard_ok then 0 else 1 end)
    +(case when v_equipment_guard_ok then 0 else 1 end)
    +v_missing_audit+v_bad_cash+v_bad_coins+v_bad_equipment+v_bad_validation+v_repair_failed;

  v_details:=jsonb_build_object(
    'scheme_version',v_scheme_version,
    'enforced_from_at',v_enforced_from,
    'configuration',jsonb_build_object(
      'master_trigger_enabled',v_trigger_ok,
      'finance_25000_usd',v_finance_ok,
      'starter_catalog_valid',v_catalog_ok,
      'country_tiers_complete',v_country_tiers_ok,
      'coin_idempotency_guard',v_coin_guard_ok,
      'equipment_idempotency_guard',v_equipment_guard_ok
    ),
    'integrity',jsonb_build_object(
      'missing_initialization_audits',v_missing_audit,
      'bad_opening_cash',v_bad_cash,
      'bad_starting_coins',v_bad_coins,
      'bad_starter_equipment',v_bad_equipment,
      'bad_initialization_validation',v_bad_validation
    ),
    'automatic_recovery',jsonb_build_object(
      'attempted',v_repair_attempted,
      'succeeded',v_repair_succeeded,
      'failed',v_repair_failed
    ),
    'problem_count',v_problem_count
  );

  if v_problem_count>0 then
    perform public.raise_system_incident_v1(
      'check:new_player_starting_scheme',
      'critical',
      'New player initialization integrity requires attention',
      format(
        '%s New Player Starting Scheme integrity issue(s) detected. New career creation must not be considered healthy until the package is complete and idempotent.',
        v_problem_count
      ),
      'business:new-player-starting-scheme',
      v_details
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:new-player-starting-scheme',
      'New Player Starting Scheme configuration and all post-enforcement careers are healthy.'
    );
  end if;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  ) values(
    'check:new_player_starting_scheme',
    case when v_problem_count>0 then 'error' else 'success' end,
    v_started,
    clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    case when v_problem_count>0
      then format('%s New Player Starting Scheme integrity issue(s).',v_problem_count)
      else 'New Player Starting Scheme is healthy.'
    end,
    v_details
  );

  return jsonb_build_object(
    'status',case when v_problem_count>0 then 'error' else 'success' end,
    'problems',v_problem_count,
    'details',v_details
  );
exception when others then
  perform public.raise_system_incident_v1(
    'check:new_player_starting_scheme',
    'critical',
    'New player health check failed',
    sqlerrm,
    'business:new-player-starting-scheme',
    jsonb_build_object('sqlstate',sqlstate)
  );

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,error_message,details
  ) values(
    'check:new_player_starting_scheme',
    'error',
    v_started,
    clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    'New Player Starting Scheme health check failed.',
    sqlerrm,
    jsonb_build_object('sqlstate',sqlstate)
  );

  return jsonb_build_object('status','error','error',sqlerrm,'sqlstate',sqlstate);
end;
$$;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname='tennis-new-player-starting-scheme-health-v1'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end;
$$;

select cron.schedule(
  'tennis-new-player-starting-scheme-health-v1',
  '3-58/5 * * * *',
  $cron$select public.check_new_player_starting_scheme_health_v1();$cron$
);

-- Seed a first health run immediately so Control Center does not show the new
-- process as Unknown while waiting for the first cron tick.
select public.check_new_player_starting_scheme_health_v1();
