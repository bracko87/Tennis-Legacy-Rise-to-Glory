-- Kosovo was explicitly approved after the original onboarding-country
-- integrity check was introduced. Extend that check without changing any of
-- its other handedness/tactics/scouting assertions.

do $$
declare
  v_def text;
begin
  select pg_get_functiondef(p.oid)
  into v_def
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='check_player_identity_tactics_health_v1'
  order by p.oid desc
  limit 1;

  if v_def is null then
    raise exception 'check_player_identity_tactics_health_v1 is unavailable.';
  end if;

  if position('''ZM'',''ZW''' in v_def)=0 then
    raise exception 'Unable to locate onboarding-country allowlist tail.';
  end if;

  v_def:=replace(v_def,'''ZM'',''ZW''','''ZM'',''ZW'',''XK''');
  execute v_def;
end;
$$;

select public.check_player_identity_tactics_health_v1();
select public.check_wta_ai_population_expansion_v1();
