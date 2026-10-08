-- Publish the 45-city Executive House market.
-- Executive House is a premium professional/luxury residential property tier,
-- focused mainly on developed-country destinations that have appeared less often.
-- Reuse the currently inactive home_beach_villa catalog slot to avoid creating
-- a duplicate house/villa base type. City images are connected in a later migration.

create temporary table tmp_executive_house_desired (
  ord integer primary key,
  country_code text not null,
  city text not null,
  target_price bigint not null
) on commit drop;

insert into tmp_executive_house_desired(ord,country_code,city,target_price)
values
  (1,'IT','Naples',627500::bigint),
  (2,'JP','Fukuoka',907500::bigint),
  (3,'JP','Sapporo',640000::bigint),
  (4,'LV','Riga',480000::bigint),
  (5,'NZ','Wellington',935000::bigint),
  (6,'ES','Bilbao',925000::bigint),
  (7,'TW','Kaohsiung',660000::bigint),
  (8,'GB','Birmingham',862500::bigint),
  (9,'DE','Dusseldorf',1280000::bigint),
  (10,'IS','Reykjavik',2045000::bigint),
  (11,'IL','Tel Aviv',2177500::bigint),
  (12,'IT','Florence',997500::bigint),
  (13,'IT','Venice',2045000::bigint),
  (14,'JP','Kyoto',1385000::bigint),
  (15,'JP','Nagoya',925000::bigint),
  (16,'LU','Luxembourg',3150000::bigint),
  (17,'NZ','Auckland',2262500::bigint),
  (18,'NZ','Queenstown',1452500::bigint),
  (19,'NO','Bergen',1280000::bigint),
  (20,'SE','Gothenburg',1215000::bigint),
  (21,'GB','Edinburgh',1320000::bigint),
  (22,'BE','Antwerp',880000::bigint),
  (23,'CA','Calgary',907500::bigint),
  (24,'CA','Ottawa',880000::bigint),
  (25,'HR','Zagreb',520000::bigint),
  (26,'EE','Tallinn',640000::bigint),
  (27,'IT','Bologna',925000::bigint),
  (28,'IT','Turin',880000::bigint),
  (29,'PL','Krakow',640000::bigint),
  (30,'PT','Porto',692500::bigint),
  (31,'SK','Bratislava',640000::bigint),
  (32,'SI','Ljubljana',692500::bigint),
  (33,'ES','Seville',640000::bigint),
  (34,'ES','Valencia',725000::bigint),
  (35,'CH','Basel',3100000::bigint),
  (36,'US','Atlanta',935000::bigint),
  (37,'JP','Yokohama',1452500::bigint),
  (38,'AT','Salzburg',1320000::bigint),
  (39,'FR','Bordeaux',1320000::bigint),
  (40,'FR','Lyon',1280000::bigint),
  (41,'DE','Cologne',880000::bigint),
  (42,'DE','Stuttgart',1320000::bigint),
  (43,'KR','Busan',952500::bigint),
  (44,'KR','Incheon',880000::bigint),
  (45,'CH','Lausanne',2045000::bigint);

do $$
declare
  v_desired integer;
  v_matched integer;
  v_duplicate_matches integer;
begin
  select count(*) into v_desired from tmp_executive_house_desired;

  select count(*)
  into v_matched
  from tmp_executive_house_desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city);

  select count(*)
  into v_duplicate_matches
  from (
    select d.ord
    from tmp_executive_house_desired d
    join public.private_life_property_locations l
      on upper(l.country_code)=d.country_code
     and lower(l.city)=lower(d.city)
    group by d.ord
    having count(*)<>1
  ) x;

  if v_desired<>45 or v_matched<>45 or v_duplicate_matches<>0 then
    raise exception
      'Executive House preflight failed: desired %, matched %, duplicate/non-unique %.',
      v_desired,v_matched,v_duplicate_matches;
  end if;
end;
$$;

update public.private_life_asset_catalog
set name='Executive House',
    category='house_villa',
    tier=4,
    description='Premium professional/luxury residential property.',
    purchase_price=1500000,
    prestige=5,
    rarity='rare',
    annual_running_cost=180000,
    annual_value_rate_bps=225,
    resale_discount_bps=900,
    active=true,
    metadata=coalesce(metadata,'{}'::jsonb)
      - 'market_status'
      - 'disabled_reason'
      - 'city_image_urls'
      - 'city_image_count'
      - 'fallback_image_city'
      - 'images_connected_at'
      || jsonb_build_object(
        'property_kind','house_villa',
        'location_priced',true,
        'location_availability_enforced',true,
        'market_currency','USD',
        'pricing_currency','USD',
        'catalog_order',4,
        'price_multiplier_bps',10000,
        'running_cost_bps',120,
        'value_rate_adjustment_bps',25,
        'city_price_model','baseline_scaled_override_v1',
        'city_price_version','executive_house_v1',
        'city_price_status','curated',
        'pricing_reviewed_at','2026-10-08',
        'planned_city_count',45,
        'city_set_status','database_ready_waiting_for_images',
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Executive House',
        'expected_image_storage_path','Private Life/Executive House/Executive House <City>.png',
        'missing_executive_house_images','pending_upload'
      ),
    updated_at=now()
where code='home_beach_villa';

insert into public.private_life_property_catalog_availability(location_code,catalog_code,active)
select l.code,'home_beach_villa',true
from tmp_executive_house_desired d
join public.private_life_property_locations l
  on upper(l.country_code)=d.country_code
 and lower(l.city)=lower(d.city)
on conflict(location_code,catalog_code) do update set
  active=true,
  updated_at=now();

update public.private_life_property_catalog_availability a
set active=false,
    updated_at=now()
where a.catalog_code='home_beach_villa'
  and not exists (
    select 1
    from tmp_executive_house_desired d
    join public.private_life_property_locations l
      on upper(l.country_code)=d.country_code
     and lower(l.city)=lower(d.city)
    where l.code=a.location_code
  );

update public.private_life_property_locations l
set marketplace_enabled=true,
    active=true,
    updated_at=now()
where exists (
  select 1
  from tmp_executive_house_desired d
  where upper(l.country_code)=d.country_code
    and lower(l.city)=lower(d.city)
);

with matched as (
  select
    l.code as location_code,
    d.target_price,
    l.house_base_price as base_snapshot
  from tmp_executive_house_desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
),
payload as (
  select
    jsonb_object_agg(location_code,target_price order by location_code) as price_map,
    jsonb_object_agg(location_code,base_snapshot order by location_code) as snapshot_map
  from matched
)
update public.private_life_asset_catalog c
set metadata=coalesce(c.metadata,'{}'::jsonb)
      || jsonb_build_object(
        'city_price_overrides',payload.price_map,
        'city_price_base_snapshots',payload.snapshot_map,
        'city_price_count',45,
        'city_price_status','curated',
        'city_price_version','executive_house_v1',
        'city_price_model','baseline_scaled_override_v1',
        'planned_city_count',45,
        'city_set_status','database_ready_waiting_for_images',
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Executive House',
        'missing_executive_house_images','pending_upload'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_beach_villa'
  and c.category='house_villa';

do $$
declare
  v_availability integer;
  v_price_map integer;
  v_bad_prices integer;
  v_active_house_types integer;
begin
  select count(*)
  into v_availability
  from public.private_life_property_catalog_availability
  where catalog_code='home_beach_villa'
    and active=true;

  select count(*)
  into v_price_map
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_price_overrides','{}'::jsonb))
  where c.code='home_beach_villa';

  select count(*)
  into v_bad_prices
  from tmp_executive_house_desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
  where public.private_life_property_effective_price_v1('home_beach_villa',l.code)<>d.target_price;

  select count(*)
  into v_active_house_types
  from public.private_life_asset_catalog
  where category='house_villa'
    and active=true;

  if v_availability<>45 or v_price_map<>45 or v_bad_prices<>0 or v_active_house_types<>4 then
    raise exception
      'Executive House validation failed: availability %, prices %, bad prices %, active house types %.',
      v_availability,v_price_map,v_bad_prices,v_active_house_types;
  end if;
end;
$$;
