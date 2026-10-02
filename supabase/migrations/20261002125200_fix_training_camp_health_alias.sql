-- Fix PL/pgSQL record-variable collision in the Training Camp health checker.
-- Reinstall the corrected function from the main Training Camp health migration.

do $$
declare
  v_def text;
begin
  select pg_get_functiondef('public.check_training_camp_health_v1()'::regprocedure)
  into v_def;

  v_def:=replace(
    v_def,
    'left join public.training_camp_pricing_rules r' || E'\n' ||
    '    on r.quality_tier=p.quality_tier and r.category=p.category',
    'left join public.training_camp_pricing_rules pr' || E'\n' ||
    '    on pr.quality_tier=p.quality_tier and pr.category=p.category'
  );
  v_def:=replace(v_def,'or r.quality_tier is null','or pr.quality_tier is null');
  v_def:=replace(v_def,'p.weekly_cost<>r.weekly_training_fee','p.weekly_cost<>pr.weekly_training_fee');
  v_def:=replace(v_def,'p.quality_multiplier<>r.quality_multiplier','p.quality_multiplier<>pr.quality_multiplier');
  v_def:=replace(v_def,'p.rating<>r.facility_rating','p.rating<>pr.facility_rating');

  execute v_def;
end;
$$;

select public.check_training_camp_health_v1();
