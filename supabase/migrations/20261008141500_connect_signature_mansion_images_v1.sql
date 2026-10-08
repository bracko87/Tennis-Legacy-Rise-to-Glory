-- Connect all 14 curated Signature Mansion city images.
-- Uploaded storage folder is intentionally preserved as-is:
-- Admin/Private Life/Compact City Flat/Signature Mansion/

create temporary table tmp_signature_mansion_images (
  ord integer primary key,
  country_code text not null,
  city text not null,
  image_file text not null
) on commit drop;

insert into tmp_signature_mansion_images(ord,country_code,city,image_file)
values
  (1,'US','Beverly Hills','Signature Mansion Beverly hills.png'),
  (2,'US','Palm Beach','Signature Mansion Palm Beach.png'),
  (3,'US','New York','Signature Mansion New York.png'),
  (4,'GB','London','Signature Mansion London.png'),
  (5,'BL','St. Barts','Signature Mansion St. Barts.png'),
  (6,'FR','Saint-Tropez','Signature Mansion Saint-Tropez.png'),
  (7,'CH','Geneva','Signature Mansion Geneva.png'),
  (8,'AE','Dubai','Signature Mansion Dubai.png'),
  (9,'US','The Hamptons','Signature Mansion The Hamptons.png'),
  (10,'ID','Bali','Signature Mansion Bali.png'),
  (11,'AU','Sydney','Signature Mansion Sydney.png'),
  (12,'ES','Marbella','Signature Mansion Marbella.png'),
  (13,'IT','Lake Como','Signature Mansion Lake Como.png'),
  (14,'RS','Aleksandrovo','Signature Mansion Aleksandrovo.png');

do $$
declare
  v_expected integer;
  v_locations integer;
  v_images integer;
  v_missing text[];
begin
  select count(*) into v_expected from tmp_signature_mansion_images;

  select count(*)
  into v_locations
  from tmp_signature_mansion_images d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city);

  select count(*)
  into v_images
  from tmp_signature_mansion_images d
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Compact City Flat/Signature Mansion/'||d.image_file;

  select array_agg(d.city order by d.ord)
  into v_missing
  from tmp_signature_mansion_images d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Compact City Flat/Signature Mansion/'||d.image_file
  where o.id is null;

  if v_expected<>14 or v_locations<>14 or v_images<>14 then
    raise exception
      'Signature Mansion image preflight failed: expected %, locations %, images %, missing %.',
      v_expected,v_locations,v_images,v_missing;
  end if;
end;
$$;

with matched as (
  select
    l.country_code,
    l.city,
    d.image_file
  from tmp_signature_mansion_images d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city)
),
payload as (
  select jsonb_object_agg(
    country_code||'|'||city,
    'storage://Admin/Private Life/Compact City Flat/Signature Mansion/'||image_file
    order by country_code,city
  ) as image_map
  from matched
)
update public.private_life_asset_catalog c
set image_url='storage://Admin/Private Life/Compact City Flat/Signature Mansion/Signature Mansion Beverly hills.png',
    metadata=coalesce(c.metadata,'{}'::jsonb)
      - 'missing_signature_mansion_images'
      || jsonb_build_object(
        'city_image_urls',payload.image_map,
        'city_image_count',14,
        'image_status','curated',
        'city_set_status','ready',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Compact City Flat/Signature Mansion',
        'expected_image_storage_path','Private Life/Compact City Flat/Signature Mansion/Signature Mansion <City>.png',
        'fallback_image_city','Beverly Hills',
        'missing_signature_mansion_images','[]'::jsonb,
        'images_connected_at','2026-10-08'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_trophy_mansion'
  and c.category='house_villa';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_signature_mansion_authenticated_read'
  ) then
    create policy "admin_private_life_signature_mansion_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Compact City Flat/Signature Mansion/%'
      );
  end if;
end;
$$;

do $$
declare
  v_map integer;
  v_wrong integer;
  v_missing integer;
begin
  select count(*)
  into v_map
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_image_urls','{}'::jsonb))
  where c.code='home_trophy_mansion';

  select count(*)
  into v_wrong
  from tmp_signature_mansion_images d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city)
  cross join public.private_life_asset_catalog c
  where c.code='home_trophy_mansion'
    and c.metadata->'city_image_urls'->>(l.country_code||'|'||l.city)
        is distinct from
        'storage://Admin/Private Life/Compact City Flat/Signature Mansion/'||d.image_file;

  select count(*)
  into v_missing
  from tmp_signature_mansion_images d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Compact City Flat/Signature Mansion/'||d.image_file
  where o.id is null;

  if v_map<>14 or v_wrong<>0 or v_missing<>0 then
    raise exception
      'Signature Mansion image validation failed: mapped %, wrong %, missing %.',
      v_map,v_wrong,v_missing;
  end if;
end;
$$;
