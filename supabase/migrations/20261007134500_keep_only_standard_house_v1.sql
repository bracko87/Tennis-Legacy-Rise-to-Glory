-- Keep only Standard House visible in the Houses & Villas marketplace for now.
-- Older house/villa catalog rows are retained as inactive records so they can
-- be restored later without breaking historical references or migrations.

update public.private_life_asset_catalog
set active=false,
    metadata=coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
      'market_status','disabled_for_now',
      'disabled_reason','Standard House is the only active Houses & Villas category for the current release.'
    ),
    updated_at=now()
where category='house_villa'
  and code<>'home_standard_house';

update public.private_life_asset_catalog
set active=true,
    metadata=coalesce(metadata,'{}'::jsonb) - 'market_status' - 'disabled_reason',
    updated_at=now()
where code='home_standard_house'
  and category='house_villa';

update public.private_life_property_catalog_availability
set active=false,
    updated_at=now()
where catalog_code in (
  select code
  from public.private_life_asset_catalog
  where category='house_villa'
    and code<>'home_standard_house'
);

do $$
declare
  v_active_count integer;
  v_standard_active boolean;
begin
  select count(*)
  into v_active_count
  from public.private_life_asset_catalog
  where category='house_villa'
    and active=true;

  select active
  into v_standard_active
  from public.private_life_asset_catalog
  where code='home_standard_house';

  if v_active_count<>1 or v_standard_active is distinct from true then
    raise exception
      'Houses & Villas validation failed: active house/villa count %, Standard House active %.',
      v_active_count,v_standard_active;
  end if;
end;
$$;
