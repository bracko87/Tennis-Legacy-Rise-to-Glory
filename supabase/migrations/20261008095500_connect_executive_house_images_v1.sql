-- Connect all 45 curated Executive House city images.

create temporary table tmp_executive_house_images (
  ord integer primary key,
  country_code text not null,
  city text not null,
  image_file text not null
) on commit drop;

insert into tmp_executive_house_images(ord,country_code,city,image_file)
values
  (1,'IT','Naples','Executive House Naples.png'),
  (2,'JP','Fukuoka','Executive House Fukuoka.png'),
  (3,'JP','Sapporo','Executive House Sapporo.png'),
  (4,'LV','Riga','Executive House Riga.png'),
  (5,'NZ','Wellington','Executive House Wellington.png'),
  (6,'ES','Bilbao','Executive House Bilbao.png'),
  (7,'TW','Kaohsiung','Executive House Kaohsiung.png'),
  (8,'GB','Birmingham','Executive House Birmingham.png'),
  (9,'DE','Dusseldorf','Executive House Dusseldorf.png'),
  (10,'IS','Reykjavik','Executive House Reykjavik.png'),
  (11,'IL','Tel Aviv','Executive House Tel Aviv.png'),
  (12,'IT','Florence','Executive House Florence.png'),
  (13,'IT','Venice','Executive House Venice.png'),
  (14,'JP','Kyoto','Executive House Kyoto.png'),
  (15,'JP','Nagoya','Executive House Nagoya.png'),
  (16,'LU','Luxembourg','Executive House Luxembourg.png'),
  (17,'NZ','Auckland','Executive House Auckland.png'),
  (18,'NZ','Queenstown','Executive House Queenstown.png'),
  (19,'NO','Bergen','Executive House Bergen.png'),
  (20,'SE','Gothenburg','Executive House Gothenburg.png'),
  (21,'GB','Edinburgh','Executive House Edinburgh.png'),
  (22,'BE','Antwerp','Executive House Antwerp.png'),
  (23,'CA','Calgary','Executive House Calgary.png'),
  (24,'CA','Ottawa','Executive House Ottawa.png'),
  (25,'HR','Zagreb','Executive House Zagreb.png'),
  (26,'EE','Tallinn','Executive House Tallinn.png'),
  (27,'IT','Bologna','Executive House Bologna.png'),
  (28,'IT','Turin','Executive House Turin.png'),
  (29,'PL','Krakow','Executive House Krakow.png'),
  (30,'PT','Porto','Executive House Porto.png'),
  (31,'SK','Bratislava','Executive House Bratislava.png'),
  (32,'SI','Ljubljana','Executive House Ljubljana.png'),
  (33,'ES','Seville','Executive House Seville.png'),
  (34,'ES','Valencia','Executive House Valencia.png'),
  (35,'CH','Basel','Executive House Basel.png'),
  (36,'US','Atlanta','Executive House Atlanta.png'),
  (37,'JP','Yokohama','Executive House Yokohama.png'),
  (38,'AT','Salzburg','Executive House Salzburg.png'),
  (39,'FR','Bordeaux','Executive House Bordeaux.png'),
  (40,'FR','Lyon','Executive House Lyon.png'),
  (41,'DE','Cologne','Executive House Cologne.png'),
  (42,'DE','Stuttgart','Executive House Stuttgart.png'),
  (43,'KR','Busan','Executive House Busan.png'),
  (44,'KR','Incheon','Executive House Incheon.png'),
  (45,'CH','Lausanne','Executive House Lausanne.png');

do $$
declare
  v_expected integer;
  v_locations integer;
  v_images integer;
begin
  select count(*) into v_expected from tmp_executive_house_images;

  select count(*)
  into v_locations
  from tmp_executive_house_images d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city);

  select count(*)
  into v_images
  from tmp_executive_house_images d
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Executive House/'||d.image_file;

  if v_expected<>45 or v_locations<>45 or v_images<>45 then
    raise exception
      'Executive House image preflight failed: expected %, locations %, images %.',
      v_expected,v_locations,v_images;
  end if;
end;
$$;

with matched as (
  select
    l.country_code,
    l.city,
    d.image_file
  from tmp_executive_house_images d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
),
payload as (
  select jsonb_object_agg(
    country_code||'|'||city,
    'storage://Admin/Private Life/Executive House/'||image_file
    order by country_code,city
  ) as image_map
  from matched
)
update public.private_life_asset_catalog c
set image_url='storage://Admin/Private Life/Executive House/Executive House Naples.png',
    metadata=coalesce(c.metadata,'{}'::jsonb)
      - 'missing_executive_house_images'
      || jsonb_build_object(
        'city_image_urls',payload.image_map,
        'city_image_count',45,
        'image_status','curated',
        'city_set_status','ready',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Executive House',
        'fallback_image_city','Naples',
        'missing_executive_house_images','[]'::jsonb,
        'images_connected_at','2026-10-08'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_beach_villa'
  and c.category='house_villa';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_executive_house_authenticated_read'
  ) then
    create policy "admin_private_life_executive_house_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Executive House/%'
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
  where c.code='home_beach_villa';

  select count(*)
  into v_wrong
  from tmp_executive_house_images d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
  cross join public.private_life_asset_catalog c
  where c.code='home_beach_villa'
    and c.metadata->'city_image_urls'->>(l.country_code||'|'||l.city)
        is distinct from
        'storage://Admin/Private Life/Executive House/'||d.image_file;

  select count(*)
  into v_missing
  from tmp_executive_house_images d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Executive House/'||d.image_file
  where o.id is null;

  if v_map<>45 or v_wrong<>0 or v_missing<>0 then
    raise exception
      'Executive House image validation failed: mapped %, wrong %, missing %.',
      v_map,v_wrong,v_missing;
  end if;
end;
$$;
