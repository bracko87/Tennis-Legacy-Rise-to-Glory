-- Read-only Premium Staff Advisory regression. Run with test fixture; rollback assures no writes.
begin;
do $check$
declare
  v_player uuid;v_user uuid;v_other uuid;v_world text;v_report jsonb;
  v_contract jsonb;v_denied boolean;
  v_contract_count integer;v_total_weekly bigint;v_remaining bigint;
begin
  foreach v_world in array array['ATP','WTA'] loop
    select p.id,p.owner_user_id into v_player,v_user
    from public.players p where p.world=v_world and p.player_type='human'
      and p.owner_user_id is not null
      and (exists(select 1 from public.premium_memberships m
        where m.user_id=p.owner_user_id and m.plan_code='premium'
          and m.status='active'
          and (m.current_period_end is null or m.current_period_end>now()))
        or exists(select 1 from public.tennis_premium_trials_v1 trial
          where trial.user_id=p.owner_user_id and trial.expires_at>now()))
    order by (select count(*) from public.player_staff_contracts c
      where c.player_id=p.id and c.status='active') desc limit 1;
    if v_player is null then raise exception 'Missing paid/trial player in %',v_world;end if;
    perform set_config('request.jwt.claim.sub',v_user::text,true);
    v_report:=public.get_premium_staff_advisory_v1(v_player);
    if v_report->>'player_id'<>v_player::text or jsonb_typeof(v_report->'staff')<>'array'
      or jsonb_array_length(v_report->'staff')<>(v_report->>'staff_count')::integer
      then raise exception 'Invalid Premium staff report in %',v_world;end if;
    select count(*),coalesce(sum(c.weekly_salary),0)::bigint into v_contract_count,v_total_weekly
    from public.player_staff_contracts c
    where c.player_id=v_player and c.status='active';
    if (v_report->>'staff_count')::integer<>v_contract_count
      or (v_report->>'weekly_salary_run_rate_usd')::bigint<>v_total_weekly
      or (v_report->>'four_week_salary_run_rate_usd')::bigint<>v_total_weekly*4
      or (v_report->>'thirteen_week_salary_run_rate_usd')::bigint<>v_total_weekly*13
      then raise exception 'Staff salary totals disagree in %',v_world;end if;
    select coalesce(sum((item->>'estimated_remaining_salaries')::bigint),0) into v_remaining
    from jsonb_array_elements(v_report->'staff') item;
    if (v_report->>'remaining_salary_commitments_estimate_usd')::bigint<>v_remaining then
      raise exception 'Remaining commitments disagree in %',v_world;end if;
    for v_contract in select value from jsonb_array_elements(v_report->'staff') loop
      if (v_contract->>'weeks_remaining')::integer<0
        or (v_contract->>'posted_cost_all_time')::numeric<0
        or (v_contract->>'rating')::numeric not between 0 and 100
      then raise exception 'Contract cost, rating or weeks invalid';end if;
    end loop;
  end loop;

  select id into v_other from public.players p
  where p.owner_user_id is not null and p.owner_user_id<>v_user limit 1;
  v_denied:=false;
  begin perform public.get_premium_staff_advisory_v1(v_other);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Cross-owner read allowed';end if;

  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  v_denied:=false;
  begin perform public.get_premium_staff_advisory_v1(v_player);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Free account read allowed';end if;

  perform set_config('request.jwt.claim.sub','',true);
  v_denied:=false;
  begin perform public.get_premium_staff_advisory_v1(v_player);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Anonymous read allowed';end if;

  if has_function_privilege('anon'::regrole,
    'public.get_premium_staff_advisory_v1(uuid)','EXECUTE') then
    raise exception 'Anonymous RPC execution allowed';end if;
end
$check$;
rollback;
