-- Connect all curated Family House city images.
-- Storage path convention: Admin/Private Life/Family House/Family House <City>.png
-- São Paulo intentionally maps to the uploaded filename "Family House Sao Paolo.png".

create temporary table tmp_family_house_images (
  ord integer primary key,
  country_code text not null,
  city text not null,
  image_city text not null
) on commit drop;

insert into tmp_family_house_images(ord,country_code,city,image_city)
values
  (1,'DZ','Algiers','Algiers'),
  (2,'AO','Luanda','Luanda'),
  (3,'AM','Yerevan','Yerevan'),
  (4,'AU','Adelaide','Adelaide'),
  (5,'AU','Brisbane','Brisbane'),
  (6,'AU','Gold Coast','Gold Coast'),
  (7,'AU','Melbourne','Melbourne'),
  (8,'AU','Perth','Perth'),
  (9,'AU','Sydney','Sydney'),
  (10,'AT','Salzburg','Salzburg'),
  (11,'AZ','Baku','Baku'),
  (12,'BH','Manama','Manama'),
  (13,'BD','Dhaka','Dhaka'),
  (14,'BE','Antwerp','Antwerp'),
  (15,'BR','Florianopolis','Florianopolis'),
  (16,'BR','Rio de Janeiro','Rio de Janeiro'),
  (17,'BR','Salvador','Salvador'),
  (18,'CA','Vancouver','Vancouver'),
  (19,'CN','Beijing','Beijing'),
  (20,'CN','Chongqing','Chongqing'),
  (21,'CN','Guangzhou','Guangzhou'),
  (22,'CN','Hangzhou','Hangzhou'),
  (23,'CN','Nanjing','Nanjing'),
  (24,'CN','Shanghai','Shanghai'),
  (25,'CN','Shenzhen','Shenzhen'),
  (26,'CN','Wuhan','Wuhan'),
  (27,'CO','Cartagena','Cartagena'),
  (28,'CR','San Jose','San Jose'),
  (29,'DK','Copenhagen','Copenhagen'),
  (30,'EG','Alexandria','Alexandria'),
  (31,'EG','Cairo','Cairo'),
  (32,'EE','Tallinn','Tallinn'),
  (33,'ET','Addis Ababa','Addis Ababa'),
  (34,'FI','Helsinki','Helsinki'),
  (35,'FR','Bordeaux','Bordeaux'),
  (36,'FR','Lyon','Lyon'),
  (37,'FR','Marseille','Marseille'),
  (38,'FR','Nice','Nice'),
  (39,'FR','Paris','Paris'),
  (40,'GE','Tbilisi','Tbilisi'),
  (41,'CH','Basel','Basel'),
  (42,'CH','Geneva','Geneva'),
  (43,'CH','Lausanne','Lausanne'),
  (44,'CH','Zurich','Zurich'),
  (45,'KR','Busan','Busan'),
  (46,'KR','Incheon','Incheon'),
  (47,'KR','Seoul','Seoul'),
  (48,'TH','Phuket','Phuket'),
  (49,'TR','Istanbul','Istanbul'),
  (50,'AE','Dubai','Dubai'),
  (51,'CZ','Prague','Prague'),
  (52,'ES','Madrid','Madrid'),
  (53,'ES','Barcelona','Barcelona'),
  (54,'DE','Berlin','Berlin'),
  (55,'AT','Vienna','Vienna'),
  (56,'IE','Dublin','Dublin'),
  (57,'US','Austin','Austin'),
  (58,'US','Chicago','Chicago'),
  (59,'US','Denver','Denver'),
  (60,'CA','Toronto','Toronto'),
  (61,'BR','São Paulo','Sao Paolo'),
  (62,'TH','Bangkok','Bangkok'),
  (63,'MY','Kuala Lumpur','Kuala Lumpur'),
  (64,'ZA','Cape Town','Cape Town'),
  (65,'ZA','Johannesburg','Johannesburg');

do $$
declare
  v_desired integer;
  v_locations integer;
  v_images integer;
  v_duplicate_locations integer;
begin
  select count(*) into v_desired from tmp_family_house_images;

  select count(*)
  into v_locations
  from tmp_family_house_images d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city);

  select count(*)
  into v_images
  from tmp_family_house_images d
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Family House/Family House '||d.image_city||'.png';

  select count(*)
  into v_duplicate_locations
  from (
    select d.ord
    from tmp_family_house_images d
    join public.private_life_property_locations l
      on upper(l.country_code)=d.country_code
     and lower(l.city)=lower(d.city)
    group by d.ord
    having count(*)<>1
  ) x;

  if v_desired<>65 or v_locations<>65 or v_images<>65 or v_duplicate_locations<>0 then
    raise exception
      'Family House image preflight failed: desired %, locations %, images %, duplicate/non-unique locations %.',
      v_desired,v_locations,v_images,v_duplicate_locations;
  end if;
end;
$$;

with matched as (
  select
    l.country_code,
    l.city,
    d.image_city
  from tmp_family_house_images d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
),
payload as (
  select jsonb_object_agg(
    country_code||'|'||city,
    'storage://Admin/Private Life/Family House/Family House '||image_city||'.png'
    order by country_code,city
  ) as image_map
  from matched
)
update public.private_life_asset_catalog c
set image_url='storage://Admin/Private Life/Family House/Family House Algiers.png',
    metadata=coalesce(c.metadata,'{}'::jsonb)
      - 'missing_family_house_images'
      || jsonb_build_object(
        'city_image_urls',payload.image_map,
        'city_image_count',65,
        'image_status','curated',
        'city_set_status','ready',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Family House',
        'fallback_image_city','Algiers',
        'images_connected_at','2026-10-07'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_family_house'
  and c.category='house_villa';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_family_house_authenticated_read'
  ) then
    create policy "admin_private_life_family_house_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Family House/%'
      );
  end if;
end;
$$;

do $$
declare
  v_image_map integer;
  v_missing integer;
  v_wrong integer;
begin
  select count(*)
  into v_image_map
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_image_urls','{}'::jsonb))
  where c.code='home_family_house';

  select count(*)
  into v_missing
  from tmp_family_house_images d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Family House/Family House '||d.image_city||'.png'
  where o.id is null;

  select count(*)
  into v_wrong
  from tmp_family_house_images d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
  cross join public.private_life_asset_catalog c
  where c.code='home_family_house'
    and c.metadata->'city_image_urls'->>(l.country_code||'|'||l.city)
        is distinct from
        'storage://Admin/Private Life/Family House/Family House '||d.image_city||'.png';

  if v_image_map<>65 or v_missing<>0 or v_wrong<>0 then
    raise exception
      'Family House image validation failed: mapped %, missing %, wrong mappings %.',
      v_image_map,v_missing,v_wrong;
  end if;
end;
$$;
