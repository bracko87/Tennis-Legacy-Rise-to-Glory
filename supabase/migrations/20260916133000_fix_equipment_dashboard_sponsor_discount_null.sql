-- Only expose technical-sponsor discounts when a matching active contract exists.
-- PostgreSQL LEAST() ignores NULL arguments, which previously turned a missing
-- contract into the 80% cap in the Equipment dashboard JSON.

do $$
declare
  fn text;
begin
  select pg_get_functiondef('public.get_equipment_dashboard_v1()'::regprocedure) into fn;

  fn := replace(
    fn,
    '''technical_sponsor_discount_pct'',coalesce(least(80::numeric,tc.discount_pct+case when c.tier>=4 then tc.premium_discount_bonus_pct else 0 end),0)',
    '''technical_sponsor_discount_pct'',case when tc.id is null then 0 else least(80::numeric,tc.discount_pct+case when c.tier>=4 then tc.premium_discount_bonus_pct else 0 end) end'
  );

  execute fn;
end $$;
