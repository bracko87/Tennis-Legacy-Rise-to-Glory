-- Connect uploaded Modern House images to their city-specific marketplace entries.
-- At creation time, 54 of the 55 approved images are present; Shanghai is still missing.
-- Two uploaded US filenames contain a double space after "Modern House" and São Paulo
-- uses the uploaded filename "Modern House Sao Paolo.png"; preserve those exact paths.

create temporary table tmp_modern_house_images (
  ord integer primary key,
  country_code text not null,
  city text not null,
  image_file text not null
) on commit drop;

insert into tmp_modern_house_images(ord,country_code,city,image_file)
values
  (1,'GB','London','Modern House London.png'),
  (2,'FR','Paris','Modern House Paris.png'),
  (3,'DE','Munich','Modern House Munich.png'),
  (4,'DE','Frankfurt','Modern House Frankfurt.png'),
  (5,'DE','Berlin','Modern House Berlin.png'),
  (6,'NL','Amsterdam','Modern House Amsterdam.png'),
  (7,'NL','Rotterdam','Modern House Rotterdam.png'),
  (8,'CH','Zurich','Modern House Zurich.png'),
  (9,'CH','Geneva','Modern House Geneva.png'),
  (10,'AT','Vienna','Modern House Vienna.png'),
  (11,'DK','Copenhagen','Modern House Copenhagen.png'),
  (12,'SE','Stockholm','Modern House Stockholm.png'),
  (13,'NO','Oslo','Modern House Oslo.png'),
  (14,'FI','Helsinki','Modern House Helsinki.png'),
  (15,'IT','Milan','Modern House Milan.png'),
  (16,'IT','Rome','Modern House Rome.png'),
  (17,'ES','Barcelona','Modern House Barcelona.png'),
  (18,'ES','Madrid','Modern House Madrid.png'),
  (19,'PT','Lisbon','Modern House Lisbon.png'),
  (20,'CZ','Prague','Modern House Prague.png'),
  (21,'PL','Warsaw','Modern House Warsaw.png'),
  (22,'TR','Istanbul','Modern House Istanbul.png'),
  (23,'GR','Athens','Modern House Athens.png'),
  (24,'IE','Dublin','Modern House Dublin.png'),
  (25,'BE','Brussels','Modern House Brussels.png'),
  (26,'US','New York','Modern House New York.png'),
  (27,'US','Los Angeles','Modern House Los Angeles.png'),
  (28,'US','San Francisco','Modern House San Francisco.png'),
  (29,'US','Miami','Modern House Miami.png'),
  (30,'US','Boston','Modern House  Boston.png'),
  (31,'US','Seattle','Modern House Seattle.png'),
  (32,'US','Washington','Modern House Washington.png'),
  (33,'US','Chicago','Modern House Chicago.png'),
  (34,'US','Austin','Modern House  Austin.png'),
  (35,'CA','Toronto','Modern House Toronto.png'),
  (36,'CA','Vancouver','Modern House Vancouver.png'),
  (37,'MX','Mexico City','Modern House Mexico City.png'),
  (38,'BR','São Paulo','Modern House Sao Paolo.png'),
  (39,'BR','Rio de Janeiro','Modern House Rio de Janeiro.png'),
  (40,'AR','Buenos Aires','Modern House Buenos Aires.png'),
  (41,'CL','Santiago','Modern House Santiago.png'),
  (42,'JP','Tokyo','Modern House Tokyo.png'),
  (43,'JP','Osaka','Modern House Osaka.png'),
  (44,'KR','Seoul','Modern House Seoul.png'),
  (45,'CN','Beijing','Modern House Beijing.png'),
  (46,'CN','Shanghai','Modern House Shanghai.png'),
  (47,'CN','Shenzhen','Modern House Shenzhen.png'),
  (48,'HK','Hong Kong','Modern House Hong Kong.png'),
  (49,'SG','Singapore','Modern House Singapore.png'),
  (50,'TH','Bangkok','Modern House Bangkok.png'),
  (51,'MY','Kuala Lumpur','Modern House Kuala Lumpur.png'),
  (52,'AE','Dubai','Modern House Dubai.png'),
  (53,'IN','Mumbai','Modern House Mumbai.png'),
  (54,'AU','Melbourne','Modern House Melbourne.png'),
  (55,'AU','Sydney','Modern House Sydney.png');

do $$
declare
  v_expected integer;
  v_locations integer;
  v_images integer;
  v_missing text[];
begin
  select count(*) into v_expected from tmp_modern_house_images;

  select count(*)
  into v_locations
  from tmp_modern_house_images d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city);

  select count(*)
  into v_images
  from tmp_modern_house_images d
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Modern House/'||d.image_file;

  select array_agg(d.city order by d.ord)
  into v_missing
  from tmp_modern_house_images d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Modern House/'||d.image_file
  where o.id is null;

  if v_expected<>55 or v_locations<>55 or v_images<>54 or v_missing is distinct from array['Shanghai']::text[] then
    raise exception
      'Modern House image preflight failed: expected %, locations %, images %, missing %.',
      v_expected,v_locations,v_images,v_missing;
  end if;
end;
$$;

with matched as (
  select
    l.country_code,
    l.city,
    d.image_file
  from tmp_modern_house_images d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Modern House/'||d.image_file
),
payload as (
  select jsonb_object_agg(
    country_code||'|'||city,
    'storage://Admin/Private Life/Modern House/'||image_file
    order by country_code,city
  ) as image_map
  from matched
)
update public.private_life_asset_catalog c
set metadata=coalesce(c.metadata,'{}'::jsonb)
      || jsonb_build_object(
        'city_image_urls',payload.image_map,
        'city_image_count',54,
        'image_status','partial',
        'city_set_status','waiting_for_missing_image',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Modern House',
        'missing_modern_house_images',jsonb_build_array('Shanghai'),
        'images_connected_at','2026-10-07'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_country_residence'
  and c.category='house_villa';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_modern_house_authenticated_read'
  ) then
    create policy "admin_private_life_modern_house_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Modern House/%'
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
  where c.code='home_country_residence';

  select count(*)
  into v_wrong
  from tmp_modern_house_images d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Modern House/'||d.image_file
  cross join public.private_life_asset_catalog c
  where c.code='home_country_residence'
    and c.metadata->'city_image_urls'->>(l.country_code||'|'||l.city)
        is distinct from
        'storage://Admin/Private Life/Modern House/'||d.image_file;

  select count(*)
  into v_missing
  from tmp_modern_house_images d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Modern House/'||d.image_file
  where o.id is null;

  if v_map<>54 or v_wrong<>0 or v_missing<>1 then
    raise exception
      'Modern House image validation failed: mapped %, wrong %, missing %.',
      v_map,v_wrong,v_missing;
  end if;
end;
$$;
