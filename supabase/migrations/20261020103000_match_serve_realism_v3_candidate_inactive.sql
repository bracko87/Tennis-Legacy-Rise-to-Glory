-- 2026-10-20: Serve Realism v3 CANDIDATE ONLY. DO NOT ACTIVATE OR REPLACE v2.
-- New names only. Existing simulation dispatch, replay, scores, payouts and
-- completed match records remain unchanged. Test on isolated fixed-seed cases.
-- Baseline: v2 ace probability 0.003..0.20, DF 0.02..0.13.
-- The world argument is required: never silently assume ATP or WTA.

create or replace function public.match_engine_ace_probability_v3_candidate(
  p_server jsonb,p_receiver jsonb,p_surface text,p_world text
) returns numeric language plpgsql immutable set search_path='public' as $body$
declare
  v_world text := upper(coalesce(p_world,''));
  v_skill numeric := coalesce((p_server->'technical'->>'serve')::numeric,43);
  v_style text := lower(coalesce(p_server->>'playing_style',''));
  v numeric;
begin
  if v_world not in ('ATP','WTA') then
    raise exception 'v3 candidate requires ATP or WTA world' using errcode='22023';
  end if;
  v := public.match_engine_ace_probability_v2(p_server,p_receiver,p_surface)
    + case when v_world='ATP' then 0.041 else 0.023 end
    + greatest(-0.014,least(0.023,(v_skill-43)*0.0004))
    + case when v_style like '%serve%' then 0.005 else 0 end;
  return greatest(0.006,least(0.205,v));
end;
$body$;

create or replace function public.match_engine_double_fault_probability_v3_candidate(
  p_profile jsonb,p_world text
) returns numeric language plpgsql stable set search_path='public' as $body$
declare
  v_world text := upper(coalesce(p_world,''));
  v_serve_approach text := lower(coalesce(p_profile->'match_tactic'->>'serve',''));
  v numeric;
begin
  if v_world not in ('ATP','WTA') then
    raise exception 'v3 candidate requires ATP or WTA world' using errcode='22023';
  end if;
  v := public.match_engine_double_fault_probability_v2(p_profile)
    + case when v_world='ATP' then 0.027 else 0.035 end
    + case
        when v_serve_approach like '%aggress%' then 0.005
        when v_serve_approach like '%safe%' then -0.003
        else 0
      end;
  return greatest(0.015,least(0.170,v));
end;
$body$;

-- Clone v2's full point engine, swapping ONLY ace/DF probabilities to v3
-- candidate functions (tiebreak and ordinary-game branches, both players).
-- No production caller is changed. The function remains privileged-only.
do $body$
declare
  d text;
  v_old text;
begin
  select pg_get_functiondef('public.simulate_tournament_match_raw_v2(uuid,text)'::regprocedure)
    into d;
  if d is null or
     position('public.match_engine_ace_probability_v2(a,b,ts.surface)' in d)=0 or
     position('public.match_engine_ace_probability_v2(b,a,ts.surface)' in d)=0 or
     position('public.match_engine_double_fault_probability_v2(a)' in d)=0 or
     position('public.match_engine_double_fault_probability_v2(b)' in d)=0
  then
    raise exception 'Unexpected v2 point engine: cannot safely construct v3 candidate';
  end if;
  d := replace(d,'simulate_tournament_match_raw_v2(','simulate_tournament_match_raw_v3_candidate(');
  d := replace(d,'public.match_engine_ace_probability_v2(a,b,ts.surface)',
                 'public.match_engine_ace_probability_v3_candidate(a,b,ts.surface,wc.world)');
  d := replace(d,'public.match_engine_ace_probability_v2(b,a,ts.surface)',
                 'public.match_engine_ace_probability_v3_candidate(b,a,ts.surface,wc.world)');
  d := replace(d,'public.match_engine_double_fault_probability_v2(a)',
                 'public.match_engine_double_fault_probability_v3_candidate(a,wc.world)');
  d := replace(d,'public.match_engine_double_fault_probability_v2(b)',
                 'public.match_engine_double_fault_probability_v3_candidate(b,wc.world)');
  d := replace(d,'''base-v2.0''','''base-v3.0-candidate''');
  if position('public.match_engine_ace_probability_v2(' in d)>0 or
     position('public.match_engine_double_fault_probability_v2(' in d)>0 or
     position('simulate_tournament_match_raw_v2(' in d)>0 then
    raise exception 'Unconverted v2 serve call remains in candidate';
  end if;
  execute d;
end;
$body$;

revoke all on function public.match_engine_ace_probability_v3_candidate(jsonb,jsonb,text,text) from public,anon,authenticated;
revoke all on function public.match_engine_double_fault_probability_v3_candidate(jsonb,text) from public,anon,authenticated;
revoke all on function public.simulate_tournament_match_raw_v3_candidate(uuid,text) from public,anon,authenticated;

comment on function public.simulate_tournament_match_raw_v3_candidate(uuid,text) is
  'INACTIVE isolated serve calibration candidate; NEVER used by production simulation dispatcher or replay';
