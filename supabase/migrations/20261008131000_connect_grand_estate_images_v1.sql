-- Connect all 20 curated Grand Estate city images.

create temporary table tmp_grand_estate_images (
  ord integer primary key,
  country_code text not null,
  city text not null,
  image_file text not null
) on commit drop;

insert into tmp_grand_estate_images(ord,country_code,city,image_file)
values
  (1,'US','Los Angeles','Grand Estate Los Angeles.png'),
  (2,'US','New York','Grand Estate New York.png'),
  (3,'GB','London','Grand Estate London.png'),
  (4,'FR','Paris','Grand Estate Paris.png'),
  (5,'CH','Geneva','Grand Estate Geneva.png'),
  (6,'FR','Saint-Nazaire','Grand Estate Saint-Nazaire.png'),
  (7,'AE','Dubai','Grand Estate Dubai.png'),
  (8,'FR','Nice','Grand Estate Nice.png'),
  (9,'QA','Doha','Grand Estate Doha.png'),
  (10,'BS','Nassau','Grand Estate Nassau.png'),
  (11,'RU','Moscow','Grand Estate Moscow.png'),
  (12,'TR','Istanbul','Grand Estate Istanbul.png'),
  (13,'IN','Delhi','Grand Estate Delhi.png'),
  (14,'SG','Singapore','Grand Estate Singapore.png'),
  (15,'US','Miami','Grand Estate Miami.png'),
  (16,'AU','Sydney','Grand Estate Sydney.png'),
  (17,'PR','San Juan','Grand Estate San Juan.png'),
  (18,'ZA','Johannesburg','Grand Estate Johannesburg.png'),
  (19,'ES','Marbella','Grand Estate Marbella.png'),
  (20,'MX','Mexico City','Grand Estate Mexico City.png');

do $$
declare
  v_expected integer;
  v_locations integer;
  v_images integer;
  v_missing text[];
begin
  select count(*) into v_expected from tmp_grand_estate_images;

  select count(*)
  into v_locations
  from tmp_grand_estate_images d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city);

  select count(*)
  into v_images
  from tmp_grand_estate_images d
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Grand Estate/'||d.image_file;

  select array_agg(d.city order by d.ord)
  into v_missing
  from tmp_grand_estate_images d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Grand Estate/'||d.image_file
  where o.id is null;

  if v_expected<>20 or v_locations<>20 or v_images<>20 then
    raise exception
      'Grand Estate image preflight failed: expected %, locations %, images %, missing %.',
      v_expected,v_locations,v_images,v_missing;
  end if;
end;
$$;

with matched as (
  select
    l.country_code,
    l.city,
    d.image_file
  from tmp_grand_estate_images d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city)
),
payload as (
  select jsonb_object_agg(
    country_code||'|'||city,
    'storage://Admin/Private Life/Grand Estate/'||image_file
    order by country_code,city
  ) as image_map
  from matched
)
update public.private_life_asset_catalog c
set image_url='storage://Admin/Private Life/Grand Estate/Grand Estate Los Angeles.png',
    metadata=coalesce(c.metadata,'{}'::jsonb)
      - 'missing_grand_estate_images'
      || jsonb_build_object(
        'city_image_urls',payload.image_map,
        'city_image_count',20,
        'image_status','curated',
        'city_set_status','ready',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Grand Estate',
        'fallback_image_city','Los Angeles',
        'missing_grand_estate_images','[]'::jsonb,
        'images_connected_at','2026-10-08'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_signature_mansion'
  and c.category='house_villa';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_grand_estate_authenticated_read'
  ) then
    create policy "admin_private_life_grand_estate_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Grand Estate/%'
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
  where c.code='home_signature_mansion';

  select count(*)
  into v_wrong
  from tmp_grand_estate_images d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city)
  cross join public.private_life_asset_catalog c
  where c.code='home_signature_mansion'
    and c.metadata->'city_image_urls'->>(l.country_code||'|'||l.city)
        is distinct from
        'storage://Admin/Private Life/Grand Estate/'||d.image_file;

  select count(*)
  into v_missing
  from tmp_grand_estate_images d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Grand Estate/'||d.image_file
  where o.id is null;

  if v_map<>20 or v_wrong<>0 or v_missing<>0 then
    raise exception
      'Grand Estate image validation failed: mapped %, wrong %, missing %.',
      v_map,v_wrong,v_missing;
  end if;
end;
$$;
