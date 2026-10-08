-- Connect all 25 curated Private Villa city images.
-- Preserve the uploaded Istanbul filename exactly: "Private Villa Istanbu.png".

create temporary table tmp_private_villa_images (
  ord integer primary key,
  country_code text not null,
  city text not null,
  image_file text not null
) on commit drop;

insert into tmp_private_villa_images(ord,country_code,city,image_file)
values
  (1,'RU','Moscow','Private Villa Moscow.png'),
  (2,'RU','Saint Petersburg','Private Villa Saint Petersburg.png'),
  (3,'SA','Riyadh','Private Villa Riyadh.png'),
  (4,'SA','Jeddah','Private Villa Jeddah.png'),
  (5,'QA','Doha','Private Villa Doha.png'),
  (6,'TW','Taipei','Private Villa Taipei.png'),
  (7,'IN','Delhi','Private Villa Delhi.png'),
  (8,'PH','Manila','Private Villa Manila.png'),
  (9,'ID','Jakarta','Private Villa Jakarta.png'),
  (10,'MY','Kuala Lumpur','Private Villa Kuala Lumpur.png'),
  (11,'ZA','Johannesburg','Private Villa Johannesburg.png'),
  (12,'KE','Nairobi','Private Villa Nairobi.png'),
  (13,'NG','Lagos','Private Villa Lagos.png'),
  (14,'EG','Cairo','Private Villa Cairo.png'),
  (15,'MA','Casablanca','Private Villa Casablanca.png'),
  (16,'TR','Istanbul','Private Villa Istanbu.png'),
  (17,'AZ','Baku','Private Villa Baku.png'),
  (18,'GE','Tbilisi','Private Villa Tbilisi.png'),
  (19,'KZ','Astana','Private Villa Astana.png'),
  (20,'UZ','Tashkent','Private Villa Tashkent.png'),
  (21,'AR','Buenos Aires','Private Villa Buenos Aires.png'),
  (22,'CL','Santiago','Private Villa Santiago.png'),
  (23,'PE','Lima','Private Villa Lima.png'),
  (24,'CO','Bogota','Private Villa Bogota.png'),
  (25,'MX','Mexico City','Private Villa Mexico City.png');

do $$
declare
  v_expected integer;
  v_locations integer;
  v_images integer;
  v_missing text[];
begin
  select count(*) into v_expected from tmp_private_villa_images;

  select count(*)
  into v_locations
  from tmp_private_villa_images d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city);

  select count(*)
  into v_images
  from tmp_private_villa_images d
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Private Villa/'||d.image_file;

  select array_agg(d.city order by d.ord)
  into v_missing
  from tmp_private_villa_images d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Private Villa/'||d.image_file
  where o.id is null;

  if v_expected<>25 or v_locations<>25 or v_images<>25 then
    raise exception
      'Private Villa image preflight failed: expected %, locations %, images %, missing %.',
      v_expected,v_locations,v_images,v_missing;
  end if;
end;
$$;

with matched as (
  select
    l.country_code,
    l.city,
    d.image_file
  from tmp_private_villa_images d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city)
),
payload as (
  select jsonb_object_agg(
    country_code||'|'||city,
    'storage://Admin/Private Life/Private Villa/'||image_file
    order by country_code,city
  ) as image_map
  from matched
)
update public.private_life_asset_catalog c
set image_url='storage://Admin/Private Life/Private Villa/Private Villa Moscow.png',
    metadata=coalesce(c.metadata,'{}'::jsonb)
      - 'missing_private_villa_images'
      || jsonb_build_object(
        'city_image_urls',payload.image_map,
        'city_image_count',25,
        'image_status','curated',
        'city_set_status','ready',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Private Villa',
        'fallback_image_city','Moscow',
        'missing_private_villa_images','[]'::jsonb,
        'images_connected_at','2026-10-08'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_grand_estate'
  and c.category='house_villa';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_private_villa_authenticated_read'
  ) then
    create policy "admin_private_life_private_villa_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Private Villa/%'
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
  where c.code='home_grand_estate';

  select count(*)
  into v_wrong
  from tmp_private_villa_images d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city)
  cross join public.private_life_asset_catalog c
  where c.code='home_grand_estate'
    and c.metadata->'city_image_urls'->>(l.country_code||'|'||l.city)
        is distinct from
        'storage://Admin/Private Life/Private Villa/'||d.image_file;

  select count(*)
  into v_missing
  from tmp_private_villa_images d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Private Villa/'||d.image_file
  where o.id is null;

  if v_map<>25 or v_wrong<>0 or v_missing<>0 then
    raise exception
      'Private Villa image validation failed: mapped %, wrong %, missing %.',
      v_map,v_wrong,v_missing;
  end if;
end;
$$;
