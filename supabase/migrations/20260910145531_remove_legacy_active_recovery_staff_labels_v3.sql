update public.staff_role_catalog
set systems=array['Regular training','Training camps']::text[]
where role='fitness_coach';

update public.staff_role_catalog
set effects='[{"key":"recovery","label":"Fatigue recovery efficiency","maximum":"+15%","cadence":"Player-selected Day Off"},{"key":"injury_prevention","label":"Injury-risk reduction","maximum":"-12% relative risk","cadence":"Every injury-risk roll"},{"key":"rehabilitation","label":"Full-recovery duration","maximum":"-15%","cadence":"When a new injury is created"},{"key":"return_to_play","label":"Training/tournament return delay","maximum":"-10%","cadence":"When a new injury is created"}]'::jsonb
where role='physiotherapist';

comment on table public.staff_role_catalog is 'Central staff role definitions and measurable effects. Normal weekly Active Recovery and Full Rest day types were removed in favour of player-selected Day Off; travel uses its own fixed recovery credit.';