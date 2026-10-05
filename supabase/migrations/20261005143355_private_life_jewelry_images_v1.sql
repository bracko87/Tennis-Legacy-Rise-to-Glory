
-- Attach the curated Private Life jewelry images stored in the private Admin bucket.
-- The frontend resolves storage:// references into short-lived signed URLs for authenticated users.

drop policy if exists admin_private_life_jewelry_authenticated_read on storage.objects;
create policy admin_private_life_jewelry_authenticated_read
on storage.objects
for select
to authenticated
using (
  bucket_id='Admin'
  and name like 'Private Life/Jewelry/%'
);

with jewelry_images(code, storage_path) as (
  values
  ('jewelry_tomas_savo_pure_silver_ring', 'Private Life/Jewelry/Tomas Savo - Pure Silver Ring.png'),
  ('jewelry_tomas_savo_crystal_court_bracelet', 'Private Life/Jewelry/Tomas Savo - Crystal Court Bracelet.png'),
  ('jewelry_swarovika_luna_stud_earrings', 'Private Life/Jewelry/Swarovika - Luna Stud Earrings.png'),
  ('jewelry_swarovika_matrix_court_bracelet', 'Private Life/Jewelry/Swarovika - Matrix Court Bracelet.png'),
  ('jewelry_swarovika_luna_angelica_bracelet', 'Private Life/Jewelry/Swarovika - Luna Angelica Bracelet.png'),
  ('jewelry_tomas_savo_royal_pave_hoops', 'Private Life/Jewelry/Tomas Savo - Royal Pave Hoops.png'),
  ('jewelry_tomas_savo_golden_court_bracelet', 'Private Life/Jewelry/Tomas Savo - Golden Court Bracelet.png'),
  ('jewelry_guccio_interlock_silver_ring', 'Private Life/Jewelry/Guccio - Interlock Silver Ring.png'),
  ('jewelry_david_yorman_cable_classic_bracelet', 'Private Life/Jewelry/David Yorman - Cable Classic Bracelet.png'),
  ('jewelry_hermelle_h_click_enamel_bangle', 'Private Life/Jewelry/Hermelle - H-Click Enamel Bangle.png'),
  ('jewelry_guccio_icon_chain_necklace', 'Private Life/Jewelry/Guccio - Icon Chain Necklace.png'),
  ('jewelry_tiffani_return_heart_pendant', 'Private Life/Jewelry/Tiffani & Co. - Return Heart Pendant.png'),
  ('jewelry_diora_wind_rose_bracelet', 'Private Life/Jewelry/Diora - Wind Rose Bracelet.png'),
  ('jewelry_van_clief_sweet_fortune_bracelet', 'Private Life/Jewelry/Van Clief & Arpel Sweet Fortune Bracelet.png'),
  ('jewelry_chopelle_ice_block_ring', 'Private Life/Jewelry/Chopelle - Ice Block Ring.png'),
  ('jewelry_tiffani_t_line_gold_ring', 'Private Life/Jewelry/Tiffani & Co. -  T-Line Gold Ring.png'),
  ('jewelry_messina_motion_one_diamond_bracelet', 'Private Life/Jewelry/Messinav- Motion One Diamond Bracelet.png'),
  ('jewelry_van_clief_frivola_diamond_pendant', 'Private Life/Jewelry/Van Clief & Arpel - Frivola Diamond Pendant.png'),
  ('jewelry_bulvari_b_one_gold_ring', 'Private Life/Jewelry/Bulvari - B-One Gold Ring.png'),
  ('jewelry_piagette_orbit_gold_ring', 'Private Life/Jewelry/Piagette - Orbit Gold Ring.png'),
  ('jewelry_carthier_amour_chain_bracelet', 'Private Life/Jewelry/Carthier - Amour Chain Bracelet.png'),
  ('jewelry_david_yorman_diamond_cable_pendant', 'Private Life/Jewelry/David Yorman - Diamond Cable Pendant.png'),
  ('jewelry_boucherin_serpent_belle_necklace', 'Private Life/Jewelry/Boucherin - Serpent Belle Necklace.png'),
  ('jewelry_van_clief_vintage_fortune_bracelet', 'Private Life/Jewelry/Van Clief & Arpel - Vintage Fortune Bracelet.png'),
  ('jewelry_boucherin_four_classic_gold_ring', 'Private Life/Jewelry/Boucherin - Four Classic Gold Ring.png'),
  ('jewelry_carthier_amour_classic_bracelet', 'Private Life/Jewelry/Carthier - Amour Classic Bracelet.png'),
  ('jewelry_bulvari_serpentina_gold_bracelet', 'Private Life/Jewelry/Bulvari - Serpentina Gold Bracelet.png'),
  ('jewelry_van_clief_fortune_diamond_bracelet', 'Private Life/Jewelry/Van Clief & Arpel - Fortune Diamond Bracelet.png'),
  ('jewelry_henry_winstone_royal_cluster_diamond_earrings', 'Private Life/Jewelry/Henry Winstone - Royal Cluster Diamond Earrings.png'),
  ('jewelry_graffe_riviera_diamond_tennis_bracelet', 'Private Life/Jewelry/Graffe - Riviera Diamond Tennis Bracelet.png')
)
update public.private_life_asset_catalog c
set image_url='storage://Admin/'||j.storage_path,
    metadata=coalesce(c.metadata,'{}'::jsonb) || jsonb_build_object(
      'image_status','curated',
      'image_storage_bucket','Admin',
      'image_storage_path',j.storage_path
    ),
    updated_at=now()
from jewelry_images j
where c.code=j.code
  and c.category='jewelry';

do $$
declare
  v_active integer;
  v_mapped integer;
  v_storage_missing integer;
  v_placeholder integer;
begin
  select count(*) into v_active
  from public.private_life_asset_catalog
  where category='jewelry' and active=true;

  select count(*) into v_mapped
  from public.private_life_asset_catalog
  where category='jewelry'
    and active=true
    and image_url like 'storage://Admin/Private Life/Jewelry/%'
    and metadata->>'image_status'='curated';

  select count(*) into v_storage_missing
  from public.private_life_asset_catalog c
  where c.category='jewelry'
    and c.active=true
    and not exists (
      select 1
      from storage.objects o
      where o.bucket_id='Admin'
        and o.name=c.metadata->>'image_storage_path'
    );

  select count(*) into v_placeholder
  from public.private_life_asset_catalog
  where category='jewelry'
    and active=true
    and (
      image_url like 'https://images.unsplash.com/%'
      or metadata->>'image_status'='placeholder'
    );

  if v_active<>30 then
    raise exception 'Expected 30 active jewelry rows, found %.',v_active;
  end if;
  if v_mapped<>30 then
    raise exception 'Expected 30 curated jewelry image mappings, found %.',v_mapped;
  end if;
  if v_storage_missing<>0 then
    raise exception 'Jewelry storage objects missing: %.',v_storage_missing;
  end if;
  if v_placeholder<>0 then
    raise exception 'Jewelry placeholder images still remain: %.',v_placeholder;
  end if;
end;
$$;

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values(
  'check:private_life_jewelry_images',
  'Private Life jewelry images',
  'Private Life',
  'Validates that every active jewelry catalog item has its curated Admin storage image and no placeholder mapping remains.',
  'business_check',null,false,'warning',720,1800,false,227
)
on conflict(process_key) do update set
  label=excluded.label,
  category=excluded.category,
  description=excluded.description,
  source_kind=excluded.source_kind,
  source_ref=excluded.source_ref,
  user_sensitive=excluded.user_sensitive,
  incident_severity=excluded.incident_severity,
  expected_interval_minutes=excluded.expected_interval_minutes,
  stale_after_minutes=excluded.stale_after_minutes,
  email_alerts_enabled=excluded.email_alerts_enabled,
  is_enabled=true,
  sort_order=excluded.sort_order,
  updated_at=now();

create or replace function public.check_private_life_jewelry_images_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','storage','pg_catalog','pg_temp'
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_total integer:=0;
  v_missing_storage integer:=0;
  v_placeholders integer:=0;
  v_missing_urls integer:=0;
  v_problem_count integer:=0;
  v_details jsonb;
begin
  select count(*) into v_total
  from public.private_life_asset_catalog
  where category='jewelry' and active=true;

  select count(*) into v_missing_storage
  from public.private_life_asset_catalog c
  where c.category='jewelry'
    and c.active=true
    and not exists (
      select 1
      from storage.objects o
      where o.bucket_id='Admin'
        and o.name=c.metadata->>'image_storage_path'
    );

  select count(*) into v_placeholders
  from public.private_life_asset_catalog
  where category='jewelry'
    and active=true
    and (
      image_url like 'https://images.unsplash.com/%'
      or metadata->>'image_status'='placeholder'
    );

  select count(*) into v_missing_urls
  from public.private_life_asset_catalog
  where category='jewelry'
    and active=true
    and coalesce(image_url,'')='';

  v_problem_count:=v_missing_storage+v_placeholders+v_missing_urls;
  v_details:=jsonb_build_object(
    'active_jewelry_catalog_rows',v_total,
    'missing_storage_objects',v_missing_storage,
    'placeholder_image_urls',v_placeholders,
    'missing_image_urls',v_missing_urls
  );

  if v_problem_count>0 then
    perform public.raise_system_incident_v1(
      'check:private_life_jewelry_images','warning',
      'Private Life jewelry images require attention',
      format('%s jewelry image integrity issue(s) detected.',v_problem_count),
      'business:private-life-jewelry-images',
      v_details
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:private-life-jewelry-images',
      'All Private Life jewelry catalog images are mapped and present in Admin storage.'
    );
  end if;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  ) values(
    'check:private_life_jewelry_images',
    case when v_problem_count>0 then 'warning' else 'success' end,
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    case when v_problem_count>0
      then format('%s Private Life jewelry image issue(s).',v_problem_count)
      else format('%s/%s active jewelry images are mapped and present.',v_total,v_total)
    end,
    v_details
  );

  return jsonb_build_object(
    'status',case when v_problem_count>0 then 'warning' else 'success' end,
    'problems',v_problem_count,
    'details',v_details
  );
end;
$$;

select public.check_private_life_jewelry_images_v1();
