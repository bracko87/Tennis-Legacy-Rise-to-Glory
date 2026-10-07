-- Publish the 65-city Family House market.
-- Family House is a larger, more comfortable family property and intentionally
-- uses a mostly different city set from Standard House: 50 new cities + 15 repeats.
-- City images will be connected in a follow-up migration after upload.

create temporary table tmp_family_house_desired (
  ord integer primary key,
  country_code text not null,
  city text not null,
  target_price bigint not null
) on commit drop;

insert into tmp_family_house_desired(ord,country_code,city,target_price)
values
  (1,'DZ','Algiers',192000::bigint),
  (2,'AO','Luanda',372000::bigint),
  (3,'AM','Yerevan',180000::bigint),
  (4,'AU','Adelaide',533500::bigint),
  (5,'AU','Brisbane',752000::bigint),
  (6,'AU','Gold Coast',728000::bigint),
  (7,'AU','Melbourne',1448250::bigint),
  (8,'AU','Perth',760000::bigint),
  (9,'AU','Sydney',1837250::bigint),
  (10,'AT','Salzburg',712000::bigint),
  (11,'AZ','Baku',384000::bigint),
  (12,'BH','Manama',744000::bigint),
  (13,'BD','Dhaka',171500::bigint),
  (14,'BE','Antwerp',521750::bigint),
  (15,'BR','Florianopolis',376000::bigint),
  (16,'BR','Rio de Janeiro',642500::bigint),
  (17,'BR','Salvador',294000::bigint),
  (18,'CA','Vancouver',1848500::bigint),
  (19,'CN','Beijing',1571250::bigint),
  (20,'CN','Chongqing',338250::bigint),
  (21,'CN','Guangzhou',528000::bigint),
  (22,'CN','Hangzhou',756500::bigint),
  (23,'CN','Nanjing',495000::bigint),
  (24,'CN','Shanghai',1748250::bigint),
  (25,'CN','Shenzhen',1184500::bigint),
  (26,'CN','Wuhan',345750::bigint),
  (27,'CO','Cartagena',392000::bigint),
  (28,'CR','San Jose',380000::bigint),
  (29,'DK','Copenhagen',1159250::bigint),
  (30,'EG','Alexandria',178000::bigint),
  (31,'EG','Cairo',288000::bigint),
  (32,'EE','Tallinn',379750::bigint),
  (33,'ET','Addis Ababa',184250::bigint),
  (34,'FI','Helsinki',776000::bigint),
  (35,'FR','Bordeaux',763500::bigint),
  (36,'FR','Lyon',739250::bigint),
  (37,'FR','Marseille',539000::bigint),
  (38,'FR','Nice',1254000::bigint),
  (39,'FR','Paris',1484250::bigint),
  (40,'GE','Tbilisi',267000::bigint),
  (41,'CH','Basel',1920000::bigint),
  (42,'CH','Geneva',1859500::bigint),
  (43,'CH','Lausanne',1188000::bigint),
  (44,'CH','Zurich',2118250::bigint),
  (45,'KR','Busan',542750::bigint),
  (46,'KR','Incheon',500500::bigint),
  (47,'KR','Seoul',1478000::bigint),
  (48,'TH','Phuket',548500::bigint),
  (49,'TR','Istanbul',655750::bigint),
  (50,'AE','Dubai',1653750::bigint),
  (51,'CZ','Prague',665000::bigint),
  (52,'ES','Madrid',776500::bigint),
  (53,'ES','Barcelona',832250::bigint),
  (54,'DE','Berlin',834000::bigint),
  (55,'AT','Vienna',933000::bigint),
  (56,'IE','Dublin',1269500::bigint),
  (57,'US','Austin',906750::bigint),
  (58,'US','Chicago',1095500::bigint),
  (59,'US','Denver',967250::bigint),
  (60,'CA','Toronto',1481250::bigint),
  (61,'BR','São Paulo',607250::bigint),
  (62,'TH','Bangkok',681750::bigint),
  (63,'MY','Kuala Lumpur',506000::bigint),
  (64,'ZA','Cape Town',645000::bigint),
  (65,'ZA','Johannesburg',454250::bigint);

do $$
declare
  v_desired integer;
  v_matched integer;
  v_duplicate_matches integer;
begin
  select count(*) into v_desired from tmp_family_house_desired;

  select count(*)
  into v_matched
  from tmp_family_house_desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city);

  select count(*)
  into v_duplicate_matches
  from (
    select d.ord
    from tmp_family_house_desired d
    join public.private_life_property_locations l
      on upper(l.country_code)=d.country_code
     and lower(l.city)=lower(d.city)
    group by d.ord
    having count(*)<>1
  ) x;

  if v_desired<>65 or v_matched<>65 or v_duplicate_matches<>0 then
    raise exception
      'Family House preflight failed: desired %, matched %, duplicate/non-unique %.',
      v_desired,v_matched,v_duplicate_matches;
  end if;
end;
$$;

update public.private_life_asset_catalog
set name='Family House',
    category='house_villa',
    tier=2,
    description='A larger, comfortable family property priced by destination.',
    purchase_price=500000,
    prestige=2,
    rarity='common',
    annual_running_cost=60000,
    annual_value_rate_bps=175,
    resale_discount_bps=1000,
    active=true,
    metadata=coalesce(metadata,'{}'::jsonb)
      - 'market_status'
      - 'disabled_reason'
      || jsonb_build_object(
        'property_kind','house_villa',
        'location_priced',true,
        'location_availability_enforced',true,
        'market_currency','USD',
        'pricing_currency','USD',
        'catalog_order',2,
        'price_multiplier_bps',10000,
        'value_rate_adjustment_bps',0,
        'city_price_model','baseline_scaled_override_v1',
        'city_price_version','family_house_v1',
        'city_price_status','curated',
        'pricing_reviewed_at','2026-10-07',
        'planned_city_count',65,
        'city_set_status','database_ready_waiting_for_images',
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Family House',
        'expected_image_storage_path','Private Life/Family House/Family House <City>.png'
      ),
    updated_at=now()
where code='home_family_house';

insert into public.private_life_property_catalog_availability(location_code,catalog_code,active)
select l.code,'home_family_house',true
from tmp_family_house_desired d
join public.private_life_property_locations l
  on upper(l.country_code)=d.country_code
 and lower(l.city)=lower(d.city)
on conflict(location_code,catalog_code) do update set
  active=true,
  updated_at=now();

update public.private_life_property_catalog_availability a
set active=false,
    updated_at=now()
where a.catalog_code='home_family_house'
  and not exists (
    select 1
    from tmp_family_house_desired d
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
  from tmp_family_house_desired d
  where upper(l.country_code)=d.country_code
    and lower(l.city)=lower(d.city)
);

with matched as (
  select
    l.code as location_code,
    d.target_price,
    l.house_base_price as base_snapshot
  from tmp_family_house_desired d
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
        'city_price_count',65,
        'city_price_status','curated',
        'city_price_version','family_house_v1',
        'city_price_model','baseline_scaled_override_v1',
        'planned_city_count',65,
        'city_set_status','database_ready_waiting_for_images',
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Family House',
        'missing_family_house_images','pending_upload'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_family_house'
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
  where catalog_code='home_family_house'
    and active=true;

  select count(*)
  into v_price_map
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_price_overrides','{}'::jsonb))
  where c.code='home_family_house';

  select count(*)
  into v_bad_prices
  from tmp_family_house_desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
  where public.private_life_property_effective_price_v1('home_family_house',l.code)<>d.target_price;

  select count(*)
  into v_active_house_types
  from public.private_life_asset_catalog
  where category='house_villa'
    and active=true;

  if v_availability<>65 or v_price_map<>65 or v_bad_prices<>0 or v_active_house_types<>2 then
    raise exception
      'Family House validation failed: availability %, prices %, bad prices %, active house types %.',
      v_availability,v_price_map,v_bad_prices,v_active_house_types;
  end if;
end;
$$;
