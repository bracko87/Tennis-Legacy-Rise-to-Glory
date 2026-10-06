-- Rebalance double-fault frequency for future tournament match simulations.
-- Zero double faults remains possible, but should be uncommon rather than routine.

create or replace function public.match_engine_double_fault_probability_v2(p_profile jsonb)
returns numeric
language sql
stable
set search_path to 'public'
as $function$
  select greatest(
    0.02,
    least(
      0.13,
      0.055
      + greatest(
          0,
          55 - coalesce((p_profile->'technical'->>'serve')::numeric, 50)
        ) * 0.0011
      - greatest(
          0,
          coalesce((p_profile->'technical'->>'serve')::numeric, 50) - 55
        ) * 0.00035
      + coalesce((p_profile->'condition'->>'fatigue')::numeric, 0) * 0.00028
      - coalesce((p_profile->'condition'->>'focus')::numeric, 50) * 0.00017
      + coalesce((p_profile->'match_modifiers'->>'double_fault_delta')::numeric, 0)
    )
  );
$function$;
