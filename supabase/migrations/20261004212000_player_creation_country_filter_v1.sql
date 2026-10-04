-- Restrict player-creation nationality choices to sovereign states used by
-- Tennis Legacy. Use UN member states plus Vatican City; dependencies,
-- territories and disputed/partially-recognized entries stay out of onboarding.

create or replace function public.get_player_creation_countries_v1()
returns table(code text,name text)
language sql
stable
security definer
set search_path to 'public'
as $$
  select c.code,c.name
  from public.countries c
  where c.is_active
    and c.code = any(array[
      'AF','AL','DZ','AD','AO','AG','AR','AM','AU','AT','AZ','BS','BH','BD','BB','BY','BE','BZ','BJ','BT',
      'BO','BA','BW','BR','BN','BG','BF','BI','CV','KH','CM','CA','CF','TD','CL','CN','CO','KM','CG','CD',
      'CR','CI','HR','CU','CY','CZ','DK','DJ','DM','DO','EC','EG','SV','GQ','ER','EE','SZ','ET','FJ','FI',
      'FR','GA','GM','GE','DE','GH','GR','GD','GT','GN','GW','GY','HT','VA','HN','HU','IS','IN','ID','IR',
      'IQ','IE','IL','IT','JM','JP','JO','KZ','KE','KI','KP','KR','KW','KG','LA','LV','LB','LS','LR','LY',
      'LI','LT','LU','MG','MW','MY','MV','ML','MT','MH','MR','MU','MX','FM','MD','MC','MN','ME','MA','MZ',
      'MM','NA','NR','NP','NL','NZ','NI','NE','NG','MK','NO','OM','PK','PW','PA','PG','PY','PE','PH','PL',
      'PT','QA','RO','RU','RW','KN','LC','VC','WS','SM','ST','SA','SN','RS','SC','SL','SG','SK','SI','SB',
      'SO','ZA','SS','ES','LK','SD','SR','SE','CH','SY','TJ','TZ','TH','TL','TG','TO','TT','TN','TR','TM',
      'TV','UG','UA','AE','GB','US','UY','UZ','VU','VE','VN','YE','ZM','ZW'
    ]::text[])
    and exists(
      select 1
      from public.player_home_city_options h
      where h.country_code=c.code
        and h.is_active
    )
  order by c.name;
$$;

grant execute on function public.get_player_creation_countries_v1() to authenticated;

-- Extend the existing player identity/tactics health check with onboarding
-- country integrity. Keep the established checks and add unsupported-country
-- detection without introducing another cron/process.
create or replace function public.check_player_identity_tactics_health_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_catalog','pg_temp'
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_invalid_hands integer:=0;
  v_ai_total integer:=0;
  v_ai_left integer:=0;
  v_ai_left_pct numeric:=0;
  v_bad_reservations integer:=0;
  v_missing_scout_tasks integer:=0;
  v_schema_missing integer:=0;
  v_function_missing integer:=0;
  v_invalid_match_tactics integer:=0;
  v_invalid_default_tactics integer:=0;
  v_unsupported_creation_countries integer:=0;
  v_problem_count integer:=0;
  v_details jsonb;
begin
  perform public.ensure_due_opponent_scouting_tasks_v1();

  select count(*) into v_invalid_hands
  from public.players
  where playing_hand not in ('right','left') or playing_hand is null;

  select count(*),count(*) filter(where playing_hand='left')
  into v_ai_total,v_ai_left
  from public.players
  where player_type='ai';

  if v_ai_total>0 then
    v_ai_left_pct:=round(v_ai_left::numeric/v_ai_total*100,2);
  end if;

  select count(*) into v_bad_reservations
  from public.player_avatar_reservations r
  left join public.players p on p.id=r.player_id
  where p.id is null
     or p.image_path is distinct from r.avatar_path;

  select count(*) into v_missing_scout_tasks
  from public.tournament_matches m
  join public.players hp
    on hp.id in (m.player1_id,m.player2_id)
   and hp.player_type='human'
   and hp.owner_user_id is not null
  join public.player_staff_contracts c
    on c.player_id=hp.id
   and c.role='performance_analyst'
   and c.status='active'
  where m.status='scheduled'
    and m.player1_id is not null
    and m.player2_id is not null
    and public.tournament_match_game_second_v1(m.id)>public.current_game_second_v1()
    and not exists(
      select 1 from public.player_opponent_scouting_tasks st
      where st.player_id=hp.id and st.match_id=m.id
    );

  select 4-count(*) into v_schema_missing
  from information_schema.columns
  where table_schema='public'
    and (
      (table_name='player_tournament_match_tactics'
       and column_name in ('tactic_serve_placement','tactic_return_position'))
      or
      (table_name='player_tournament_preparation_plans'
       and column_name in ('tactic_serve_placement','tactic_return_position'))
    );

  select 5-count(distinct p.proname) into v_function_missing
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname in(
      'get_automatic_singles_tactic_v1',
      'get_effective_match_tactic_internal_v2',
      'get_player_scouting_report_v1',
      'get_match_engine_profile_for_match_base_v2',
      'ensure_due_opponent_scouting_tasks_v1'
    );

  select count(*) into v_invalid_match_tactics
  from public.player_tournament_match_tactics t
  where t.tactic_serve_placement not in ('Automatic','Wide','Body','T')
     or t.tactic_return_position not in ('Normal','Closer','Deeper');

  select count(*) into v_invalid_default_tactics
  from public.player_tournament_preparation_plans t
  where t.tactic_serve_placement not in ('Automatic','Wide','Body','T')
     or t.tactic_return_position not in ('Normal','Closer','Deeper');

  select count(*) into v_unsupported_creation_countries
  from public.get_player_creation_countries_v1() c
  where c.code <> all(array[
    'AF','AL','DZ','AD','AO','AG','AR','AM','AU','AT','AZ','BS','BH','BD','BB','BY','BE','BZ','BJ','BT',
    'BO','BA','BW','BR','BN','BG','BF','BI','CV','KH','CM','CA','CF','TD','CL','CN','CO','KM','CG','CD',
    'CR','CI','HR','CU','CY','CZ','DK','DJ','DM','DO','EC','EG','SV','GQ','ER','EE','SZ','ET','FJ','FI',
    'FR','GA','GM','GE','DE','GH','GR','GD','GT','GN','GW','GY','HT','VA','HN','HU','IS','IN','ID','IR',
    'IQ','IE','IL','IT','JM','JP','JO','KZ','KE','KI','KP','KR','KW','KG','LA','LV','LB','LS','LR','LY',
    'LI','LT','LU','MG','MW','MY','MV','ML','MT','MH','MR','MU','MX','FM','MD','MC','MN','ME','MA','MZ',
    'MM','NA','NR','NP','NL','NZ','NI','NE','NG','MK','NO','OM','PK','PW','PA','PG','PY','PE','PH','PL',
    'PT','QA','RO','RU','RW','KN','LC','VC','WS','SM','ST','SA','SN','RS','SC','SL','SG','SK','SI','SB',
    'SO','ZA','SS','ES','LK','SD','SR','SE','CH','SY','TJ','TZ','TH','TL','TG','TO','TT','TN','TR','TM',
    'TV','UG','UA','AE','GB','US','UY','UZ','VU','VE','VN','YE','ZM','ZW'
  ]::text[]);

  v_problem_count :=
    v_invalid_hands
    +v_bad_reservations
    +v_missing_scout_tasks
    +greatest(0,v_schema_missing)
    +greatest(0,v_function_missing)
    +v_invalid_match_tactics
    +v_invalid_default_tactics
    +v_unsupported_creation_countries;

  if v_ai_total>0 and (v_ai_left_pct<8 or v_ai_left_pct>18) then
    v_problem_count:=v_problem_count+1;
  end if;

  v_details:=jsonb_build_object(
    'invalid_handedness_rows',v_invalid_hands,
    'ai_players',v_ai_total,
    'ai_left_handed',v_ai_left,
    'ai_left_handed_percent',v_ai_left_pct,
    'stale_avatar_reservations',v_bad_reservations,
    'scheduled_human_matches_missing_scout_task',v_missing_scout_tasks,
    'missing_tactic_schema_columns',greatest(0,v_schema_missing),
    'missing_tactic_engine_functions',greatest(0,v_function_missing),
    'invalid_match_tactic_rows',v_invalid_match_tactics,
    'invalid_tournament_default_tactic_rows',v_invalid_default_tactics,
    'unsupported_player_creation_countries',v_unsupported_creation_countries
  );

  if v_problem_count>0 then
    perform public.raise_system_incident_v1(
      'check:player_identity_tactics',
      'high',
      'Player identity or tactical preparation requires attention',
      format('%s player identity/tactical integrity issue(s) detected.',v_problem_count),
      'business:player-identity-tactics',
      v_details
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:player-identity-tactics',
      'Player handedness, onboarding countries, avatar reservations, scouting preparation and tactical engine contract are healthy.'
    );
  end if;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  ) values(
    'check:player_identity_tactics',
    case when v_problem_count>0 then 'warning' else 'success' end,
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    case when v_problem_count>0
      then format('%s player identity/tactical issue(s).',v_problem_count)
      else 'Player identity, onboarding countries, scouting and tactical engine are healthy.'
    end,
    v_details
  );

  return jsonb_build_object(
    'status',case when v_problem_count>0 then 'warning' else 'success' end,
    'problems',v_problem_count,
    'details',v_details
  );
end;
$$;

select public.check_player_identity_tactics_health_v1();
