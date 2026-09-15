create or replace function public.get_technical_sponsor_catalog_v1()
returns jsonb
language sql
stable
security definer
set search_path='public'
as $$
  select jsonb_build_object(
    'brands', coalesce(jsonb_agg(
      to_jsonb(b) || jsonb_build_object(
        'categories', coalesce((
          select jsonb_agg(jsonb_build_object(
            'category', c.category,
            'is_primary', c.is_primary,
            'product_count_target', c.product_count_target,
            'identity_profile', c.identity_profile
          ) order by c.is_primary desc, c.category)
          from public.technical_sponsor_brand_categories c
          where c.brand_id=b.id
        ), '[]'::jsonb),
        'product_count', (select count(*) from public.equipment_catalog_items e where e.technical_brand_id=b.id and e.is_active),
        'equipment_types', coalesce((select jsonb_agg(distinct e.item_type) from public.equipment_catalog_items e where e.technical_brand_id=b.id and e.is_active), '[]'::jsonb)
      ) order by b.prestige desc, b.name
    ), '[]'::jsonb),
    'tier_benefit_ranges', jsonb_build_object(
      'entry', jsonb_build_object('discount','5–15%','free_equipment','0–2 items','contract_weeks','12–26','requirements','Juniors / lower-ranked professionals'),
      'established', jsonb_build_object('discount','10–26%','free_equipment','1–3 items','contract_weeks','20–40','requirements','Developing professionals / tour regulars'),
      'premium', jsonb_build_object('discount','20–40%','free_equipment','2–6 items','contract_weeks','26–52','requirements','Established professionals / ranked players'),
      'elite', jsonb_build_object('discount','35–60%','free_equipment','5–10 items','contract_weeks','40–78','requirements','Top-ranked / high-reputation players')
    )
  )
  from public.technical_sponsor_brands b
  where b.is_active;
$$;

revoke all on function public.get_technical_sponsor_catalog_v1() from public;
grant execute on function public.get_technical_sponsor_catalog_v1() to authenticated;
