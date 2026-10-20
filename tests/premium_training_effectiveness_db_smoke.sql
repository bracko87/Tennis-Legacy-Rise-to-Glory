-- Training Effectiveness: read-only database smoke test.
-- Run as a privileged tester in a NON-PRODUCTION fixture when possible.
-- No gameplay rows are inserted or updated. Auth identity is simulated only
-- for this transaction and resets on rollback.
begin;

do $test$
declare
  v_uid uuid;
  v_player uuid;
  v_other_player uuid;
  v_report jsonb;
  v_expected bigint;
  v_count integer;
  v_sum numeric;
  v_levels numeric;
  v_denied boolean;
begin
  select p.owner_user_id,p.id into v_uid,v_player
  from public.players p where p.owner_user_id is not null
    and (
      exists (select 1 from public.premium_memberships m where
        m.user_id=p.owner_user_id and m.plan_code='premium'
        and m.status='active' and (m.current_period_end is null or m.current_period_end>now()))
      or exists (select 1 from public.tennis_premium_trials_v1 t where
        t.user_id=p.owner_user_id and t.expires_at>now())
    ) limit 1;
  if v_uid is null then raise exception 'QA requires active paid or trial fixture'; end if;
  perform set_config('request.jwt.claim.sub',v_uid::text,true);

  v_report:=public.get_premium_training_effectiveness_v1(v_player);
  if v_report->>'player_id' <> v_player::text
    or jsonb_typeof(v_report->'events') <> 'array' then
    raise exception 'Premium owned-player report failed'; end if;

  select count(*) into v_expected from public.player_training_sessions s
  where s.player_id=v_player and s.session_role='planned_training';
  select v_expected+count(*) into v_expected from public.player_training_camp_days c
  where c.player_id=v_player and c.day_role='development';
  v_count:=jsonb_array_length(v_report->'events');
  if (v_report->>'total_events')::bigint<>v_expected or v_count>120
    or (v_report->>'regular_sessions')::integer
       +(v_report->>'camp_days')::integer<>v_count then
    raise exception 'Report count and window mismatch'; end if;

  select coalesce(sum((event->>'progress_total')::numeric),0),
    coalesce(sum((event->>'levels_total')::numeric),0)
  into v_sum,v_levels from jsonb_array_elements(v_report->'events') event;
  if abs(v_sum-(v_report->>'fractional_progress_total')::numeric)>0.0001
    or v_levels<>(v_report->>'whole_level_ups')::numeric then
    raise exception 'Report totals mismatch'; end if;

  if exists (select 1 from jsonb_array_elements(v_report->'events') e
    where (e->>'source') not in ('regular','camp')
      or (e->>'game_week')::integer not between 1 and 52) then
    raise exception 'Invalid source or in-game week'; end if;

  select id into v_other_player from public.players where
    owner_user_id is not null and owner_user_id<>v_uid limit 1;
  if v_other_player is null then raise exception 'QA requires different-owner fixture'; end if;
  v_denied:=false;
  begin
    perform public.get_premium_training_effectiveness_v1(v_other_player);
  exception when sqlstate '42501' then v_denied:=true;
  end;
  if not v_denied then raise exception 'Other-owner report leaked'; end if;

  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  v_denied:=false;
  begin
    perform public.get_premium_training_effectiveness_v1(v_player);
  exception when sqlstate '42501' then v_denied:=true;
  end;
  if not v_denied then raise exception 'Non-Premium fixture could fetch report'; end if;

  perform set_config('request.jwt.claim.sub','',true);
  v_denied:=false;
  begin
    perform public.get_premium_training_effectiveness_v1(v_player);
  exception when sqlstate '42501' then v_denied:=true;
  end;
  if not v_denied then raise exception 'Anonymous session fetched report'; end if;

  if has_function_privilege('anon'::regrole,
      'public.get_premium_training_effectiveness_v1(uuid)','EXECUTE') then
    raise exception 'Anon role must not execute this RPC'; end if;
end;
$test$;
rollback;
