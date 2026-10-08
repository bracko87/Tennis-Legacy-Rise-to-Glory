-- Connect all 35 curated Luxury House destination images.
-- Preserve uploaded filenames exactly where they differ from the destination label:
-- Amalfi Coast -> Luxury House Amalfi.png
-- Kitzbühel -> Luxury House Kitzbuhel.png

create temporary table tmp_luxury_house_images (
  ord integer primary key,
  country_code text not null,
  city text not null,
  image_file text not null
) on commit drop;

insert into tmp_luxury_house_images(ord,country_code,city,image_file)
values
  (1,'ES','Mallorca','Luxury House Mallorca.png'),
  (2,'ES','Ibiza','Luxury House Ibiza.png'),
  (3,'ES','Marbella','Luxury House Marbella.png'),
  (4,'FR','Saint-Tropez','Luxury House Saint-Tropez.png'),
  (5,'FR','Cannes','Luxury House Cannes.png'),
  (6,'MC','Monaco','Luxury House Monaco.png'),
  (7,'IT','Lake Como','Luxury House Lake Como.png'),
  (8,'IT','Capri','Luxury House Capri.png'),
  (9,'IT','Amalfi Coast','Luxury House Amalfi.png'),
  (10,'GR','Mykonos','Luxury House Mykonos.png'),
  (11,'GR','Santorini','Luxury House Santorini.png'),
  (12,'PT','Algarve','Luxury House Algarve.png'),
  (13,'HR','Dubrovnik','Luxury House Dubrovnik.png'),
  (14,'HR','Hvar','Luxury House Hvar.png'),
  (15,'TH','Phuket','Luxury House Phuket.png'),
  (16,'ID','Bali','Luxury House Bali.png'),
  (17,'MV','Maldives','Luxury House Maldives.png'),
  (18,'MU','Mauritius','Luxury House Mauritius.png'),
  (19,'SC','Seychelles','Luxury House Seychelles.png'),
  (20,'DO','Punta Cana','Luxury House Punta Cana.png'),
  (21,'MX','Cancun','Luxury House Cancun.png'),
  (22,'MX','Tulum','Luxury House Tulum.png'),
  (23,'BS','Nassau','Luxury House Nassau.png'),
  (24,'US','Maui','Luxury House Maui.png'),
  (25,'US','Aspen','Luxury House Aspen.png'),
  (26,'US','Vail','Luxury House Vail.png'),
  (27,'CA','Whistler','Luxury House Whistler.png'),
  (28,'CA','Banff','Luxury House Banff.png'),
  (29,'CH','Zermatt','Luxury House Zermatt.png'),
  (30,'CH','St. Moritz','Luxury House St. Moritz.png'),
  (31,'CH','Gstaad','Luxury House Gstaad.png'),
  (32,'CH','Interlaken','Luxury House Interlaken.png'),
  (33,'AT','Kitzbühel','Luxury House Kitzbuhel.png'),
  (34,'FR','Courchevel','Luxury House Courchevel.png'),
  (35,'NZ','Queenstown','Luxury House Queenstown.png');

do $$
declare
  v_expected integer;
  v_locations integer;
  v_images integer;
  v_missing text[];
begin
  select count(*) into v_expected from tmp_luxury_house_images;

  select count(*)
  into v_locations
  from tmp_luxury_house_images d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and l.city=d.city;

  select count(*)
  into v_images
  from tmp_luxury_house_images d
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Luxury House/'||d.image_file;

  select array_agg(d.city order by d.ord)
  into v_missing
  from tmp_luxury_house_images d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Luxury House/'||d.image_file
  where o.id is null;

  if v_expected<>35 or v_locations<>35 or v_images<>35 then
    raise exception
      'Luxury House image preflight failed: expected %, locations %, images %, missing %.',
      v_expected,v_locations,v_images,v_missing;
  end if;
end;
$$;

with matched as (
  select
    l.country_code,
    l.city,
    d.image_file
  from tmp_luxury_house_images d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and l.city=d.city
),
payload as (
  select jsonb_object_agg(
    country_code||'|'||city,
    'storage://Admin/Private Life/Luxury House/'||image_file
    order by country_code,city
  ) as image_map
  from matched
)
update public.private_life_asset_catalog c
set image_url='storage://Admin/Private Life/Luxury House/Luxury House Mallorca.png',
    metadata=coalesce(c.metadata,'{}'::jsonb)
      - 'missing_luxury_house_images'
      || jsonb_build_object(
        'city_image_urls',payload.image_map,
        'city_image_count',35,
        'image_status','curated',
        'city_set_status','ready',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Luxury House',
        'fallback_image_city','Mallorca',
        'missing_luxury_house_images','[]'::jsonb,
        'images_connected_at','2026-10-08'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_mountain_chalet'
  and c.category='house_villa';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_luxury_house_authenticated_read'
  ) then
    create policy "admin_private_life_luxury_house_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Luxury House/%'
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
  where c.code='home_mountain_chalet';

  select count(*)
  into v_wrong
  from tmp_luxury_house_images d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and l.city=d.city
  cross join public.private_life_asset_catalog c
  where c.code='home_mountain_chalet'
    and c.metadata->'city_image_urls'->>(l.country_code||'|'||l.city)
        is distinct from
        'storage://Admin/Private Life/Luxury House/'||d.image_file;

  select count(*)
  into v_missing
  from tmp_luxury_house_images d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Luxury House/'||d.image_file
  where o.id is null;

  if v_map<>35 or v_wrong<>0 or v_missing<>0 then
    raise exception
      'Luxury House image validation failed: mapped %, wrong %, missing %.',
      v_map,v_wrong,v_missing;
  end if;
end;
$$;
