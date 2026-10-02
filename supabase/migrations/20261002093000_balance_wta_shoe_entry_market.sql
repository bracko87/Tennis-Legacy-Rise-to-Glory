-- Balance the WTA shoe market against ATP without weakening existing premium WTA items.
--
-- Finding: the 36 WTA-specific shoes already match their same-brand ATP
-- counterparts exactly on price, tier, durability, wear and gameplay bonuses.
-- The imbalance came from assortment: WTA had no access to ATP's lower-price
-- Tier 1-3 shoes ($80-$400), so its market started at $420 / Tier 3.
--
-- Make the existing ATP lower-market shoe range unisex. ATP players retain the
-- same items, while WTA players gain the same starter/advanced progression and
-- identical bonuses. No duplicate catalog rows or artificial WTA discounts are
-- introduced.

update public.equipment_catalog_items
set tour_scope='unisex'
where item_type='shoes'
  and tour_scope='ATP'
  and is_active
  and availability_status='available'
  and price_usd < 420;

-- Guardrail: this migration should expose the full entry progression to WTA.
do $$
declare
  v_tier1 integer;
  v_cheapest bigint;
begin
  select count(*) filter (where tier=1),
         min(price_usd)
  into v_tier1,v_cheapest
  from public.equipment_catalog_items
  where item_type='shoes'
    and is_active
    and availability_status='available'
    and tour_scope in ('unisex','WTA');

  if coalesce(v_tier1,0) < 4 or coalesce(v_cheapest,0) <> 80 then
    raise exception 'WTA shoe market balance validation failed: tier1=%, cheapest=%',v_tier1,v_cheapest;
  end if;
end;
$$;
