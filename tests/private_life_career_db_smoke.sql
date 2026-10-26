-- Run on an isolated Supabase development branch AFTER the 20261026 Private Life migrations.
-- Read-only checks; no player balances, assets or itineraries are changed.
begin;
do $$
declare v_count integer; v_r record; v_mode text;
begin
  select count(*) into v_count from information_schema.tables
  where table_schema='public' and table_name in (
   'player_lifestyle_state','player_lifestyle_morale_events',
   'player_private_jet_positions','player_tournament_travel_selection');
  if v_count<>4 then raise exception 'Missing lifestyle career tables: found % of 4',v_count; end if;

  select count(*) into v_count from information_schema.columns
  where table_schema='public' and table_name='player_travel_legs'
   and column_name in ('travel_mode','jet_asset_id','jet_quote');
  if v_count<>3 then raise exception 'Missing jet booking fields'; end if;

  select count(*) into v_count from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in (
    'get_my_private_life_career_v1','get_player_home_base_v1',
    'set_private_life_home_base_v1','set_private_life_travel_preference_v1',
    'set_private_life_tournament_travel_v1','get_private_life_tournament_travel_v1',
    'quote_private_jet_leg_v1','refresh_player_lifestyle_morale_v1',
    'process_lifestyle_morale_due_v1','process_due_lifestyle_moves_v1');
  if v_count<>10 then raise exception 'Expected ten new lifestyle career RPC/helpers, found %',v_count; end if;

  select count(*) into v_count from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in (
    'player_lifestyle_state','player_lifestyle_morale_events',
    'player_private_jet_positions','player_tournament_travel_selection') and c.relrowsecurity;
  if v_count<>4 then raise exception 'One or more private data tables missing RLS'; end if;

  select count(*) into v_count from public.private_life_asset_catalog
  where category='private_jet' and
    (metadata->>'tournament_travel_eligible')::boolean=true and
    (metadata->>'travel_fatigue_reduction_bps')::integer>5000;
  if v_count<>0 then raise exception 'Jet fatigue benefit exceeds 50%% cap'; end if;

  select count(*) into v_count from public.private_life_asset_catalog
  where category='private_jet' and metadata->>'propulsion' in ('piston','turboprop')
    and coalesce((metadata->>'tournament_travel_eligible')::boolean,false);
  if v_count<>0 then raise exception 'A hobby aircraft was enabled for tournament travel'; end if;

  select count(*) into v_count from public.player_lifestyle_state
  where applied_morale_bonus not between 0 and 3
    or preferred_travel_mode not in ('commercial','cheapest','best_owned_jet','ask_every_time');
  if v_count<>0 then raise exception 'Invalid lifestyle state'; end if;

  select count(*) into v_count from public.player_travel_legs
  where status='completed' and travel_mode='private_jet' and jet_asset_id is null;
  if v_count<>0 then raise exception 'Completed jet journey missing selected aircraft'; end if;

  select count(*) into v_count from public.player_lifestyle_state s
  join public.private_life_player_assets a on a.id=s.active_residence_asset_id
  where a.player_id<>s.player_id or a.sold_absolute_day is not null;
  if v_count<>0 then raise exception 'Residence ownership mismatch'; end if;

  -- Inspect choices without changing the data. Idempotency is enforced by the existing travel finance ledger.
  if not exists(select 1 from pg_constraint where conrelid='public.player_tournament_travel_selection'::regclass
    and contype='p') then raise exception 'Missing unique tournament selection constraint'; end if;

  raise notice 'PASS: lifestyle schema, RLS, tenure, flight eligibility and fatigue limits';
end $$;

-- Validate the required queue without manually running the recurring settlement.
select jobname,schedule from cron.job where jobname='tennis-private-life-career-hourly';

-- Interpret any zero results in test environments with no purchased assets as "not exercised":
-- the functional test plan also requires purchase/sale/relocation/flight transitions by a human test player.
rollback;
