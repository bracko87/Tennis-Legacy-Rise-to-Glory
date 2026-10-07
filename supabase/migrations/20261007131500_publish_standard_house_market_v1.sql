-- Publish the 75-city Standard House market and connect the uploaded city images.
-- Prices are exact launch targets supplied for each city. They remain linked
-- to future house-market movement through baseline-scaled city overrides.

create temporary table tmp_standard_house_desired (
  ord integer primary key,
  country_code text not null,
  city text not null,
  target_price bigint not null,
  image_city text not null
) on commit drop;

insert into tmp_standard_house_desired(ord,country_code,city,target_price,image_city)
values
  (1,'AL','Tirana',162750::bigint,'Tirana'),
  (2,'BA','Sarajevo',124000::bigint,'Sarajevo'),
  (3,'BG','Sofia',186000::bigint,'Sofia'),
  (4,'HR','Zagreb',294500::bigint,'Zagreb'),
  (5,'CZ','Prague',511500::bigint,'Prague'),
  (6,'HU','Budapest',356500::bigint,'Budapest'),
  (7,'RO','Bucharest',195250::bigint,'Bucharest'),
  (8,'RS','Belgrade',185500::bigint,'Belgrade'),
  (9,'SI','Ljubljana',260375::bigint,'Ljubljana'),
  (10,'SK','Bratislava',248000::bigint,'Bratislava'),
  (11,'PL','Warsaw',387500::bigint,'Warsaw'),
  (12,'PL','Krakow',248000::bigint,'Krakow'),
  (13,'PT','Lisbon',461750::bigint,'Lisbon'),
  (14,'PT','Porto',356500::bigint,'Porto'),
  (15,'ES','Madrid',492500::bigint,'Madrid'),
  (16,'ES','Barcelona',545250::bigint,'Barcelona'),
  (17,'ES','Valencia',387500::bigint,'Valencia'),
  (18,'ES','Seville',248000::bigint,'Seville'),
  (19,'IT','Rome',465000::bigint,'Rome'),
  (20,'IT','Turin',341000::bigint,'Turin'),
  (21,'IT','Bologna',358000::bigint,'Bologna'),
  (22,'DE','Berlin',593125::bigint,'Berlin'),
  (23,'DE','Hamburg',636750::bigint,'Hamburg'),
  (24,'DE','Cologne',558000::bigint,'Cologne'),
  (25,'DE','Stuttgart',651000::bigint,'Stuttgart'),
  (26,'AT','Vienna',628875::bigint,'Vienna'),
  (27,'BE','Brussels',527000::bigint,'Brussels'),
  (28,'NL','Rotterdam',604500::bigint,'Rotterdam'),
  (29,'IE','Dublin',852500::bigint,'Dublin'),
  (30,'GB','Manchester',358000::bigint,'Manchester'),
  (31,'US','Atlanta',341000::bigint,'Atlanta'),
  (32,'US','Austin',697500::bigint,'Austin'),
  (33,'US','Chicago',615125::bigint,'Chicago'),
  (34,'US','Dallas',604500::bigint,'Dallas'),
  (35,'US','Denver',744000::bigint,'Denver'),
  (36,'US','Houston',527000::bigint,'Houston'),
  (37,'US','Las Vegas',341000::bigint,'Las Vegas'),
  (38,'US','Washington',930000::bigint,'Washington'),
  (39,'CA','Montreal',651000::bigint,'Montreal'),
  (40,'CA','Ottawa',341000::bigint,'Ottawa'),
  (41,'CA','Calgary',341000::bigint,'Calgary'),
  (42,'CA','Toronto',935750::bigint,'Toronto'),
  (43,'MX','Mexico City',393250::bigint,'Mexico City'),
  (44,'MX','Guadalajara',186000::bigint,'Guadalajara'),
  (45,'MX','Monterrey',248000::bigint,'Monterrey'),
  (46,'AR','Buenos Aires',284875::bigint,'Buenos Aires'),
  (47,'AR','Cordoba',124000::bigint,'Cordoba'),
  (48,'CL','Santiago',358750::bigint,'Santiago'),
  (49,'CO','Bogota',186000::bigint,'Bogota'),
  (50,'CO','Medellin',186000::bigint,'Medellin'),
  (51,'EC','Quito',186000::bigint,'Quito'),
  (52,'PE','Lima',186000::bigint,'Lima'),
  (53,'UY','Montevideo',248000::bigint,'Montevideo'),
  (54,'BR','São Paulo',346250::bigint,'Sao Paolo'),
  (55,'BR','Brasilia',186000::bigint,'Brasilia'),
  (56,'TH','Bangkok',382875::bigint,'Bangkok'),
  (57,'TH','Chiang Mai',186000::bigint,'Chiang Mai'),
  (58,'VN','Hanoi',186000::bigint,'Hanoi'),
  (59,'VN','Da Nang',186000::bigint,'Da Nang'),
  (60,'VN','Ho Chi Minh City',279000::bigint,'Ho Chi Minh City'),
  (61,'MY','Kuala Lumpur',341000::bigint,'Kuala Lumpur'),
  (62,'MY','George Town',248000::bigint,'George Town'),
  (63,'ID','Jakarta',294500::bigint,'Jakarta'),
  (64,'ID','Surabaya',186000::bigint,'Surabaya'),
  (65,'PH','Manila',310000::bigint,'Manila'),
  (66,'PH','Cebu City',186000::bigint,'Cebu City'),
  (67,'IN','Bengaluru',248000::bigint,'Bengaluru'),
  (68,'IN','Hyderabad',186000::bigint,'Hyderabad'),
  (69,'CN','Chengdu',248000::bigint,'Chengdu'),
  (70,'CN','Xi''an',235625::bigint,'Xi''an'),
  (71,'ZA','Cape Town',403625::bigint,'Cape Town'),
  (72,'ZA','Johannesburg',275500::bigint,'Johannesburg'),
  (73,'KE','Nairobi',201500::bigint,'Nairobi'),
  (74,'MA','Casablanca',186000::bigint,'Casablanca'),
  (75,'MA','Marrakech',248000::bigint,'Marrakech');

do $$
declare
  v_desired integer;
  v_matched integer;
  v_duplicate_matches integer;
  v_images integer;
begin
  select count(*) into v_desired from tmp_standard_house_desired;

  select count(*)
  into v_matched
  from tmp_standard_house_desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city);

  select count(*)
  into v_duplicate_matches
  from (
    select d.ord
    from tmp_standard_house_desired d
    join public.private_life_property_locations l
      on upper(l.country_code)=d.country_code
     and lower(l.city)=lower(d.city)
    group by d.ord
    having count(*)<>1
  ) x;

  select count(*)
  into v_images
  from tmp_standard_house_desired d
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Standard House/Standard House '||d.image_city||'.png';

  if v_desired<>75 or v_matched<>75 or v_duplicate_matches<>0 or v_images<>75 then
    raise exception
      'Standard House preflight failed: desired %, matched %, duplicate/non-unique %, images %.',
      v_desired,v_matched,v_duplicate_matches,v_images;
  end if;
end;
$$;

insert into public.private_life_asset_catalog(
  code,category,name,tier,description,purchase_price,prestige,rarity,
  annual_running_cost,annual_value_rate_bps,resale_discount_bps,image_url,active,metadata
)
values(
  'home_standard_house',
  'house_villa',
  'Standard House',
  1,
  'A practical standard family house priced by destination.',
  186000,
  1,
  'common',
  22320,
  150,
  1050,
  'storage://Admin/Private Life/Standard House/Standard House Tirana.png',
  true,
  jsonb_build_object(
    'property_kind','house_villa',
    'location_priced',true,
    'location_availability_enforced',true,
    'market_currency','USD',
    'pricing_currency','USD',
    'catalog_order',1,
    'price_multiplier_bps',10000,
    'value_rate_adjustment_bps',0,
    'pricing_model','city_base_x_category_multiplier_v1',
    'city_price_model','baseline_scaled_override_v1',
    'city_price_version','standard_house_v1',
    'city_price_status','curated',
    'pricing_reviewed_at','2026-10-07',
    'planned_city_count',75,
    'city_set_status','ready',
    'image_status','curated',
    'image_storage_bucket','Admin',
    'image_storage_folder','Private Life/Standard House',
    'fallback_image_city','Tirana'
  )
)
on conflict(code) do update set
  category=excluded.category,
  name=excluded.name,
  tier=excluded.tier,
  description=excluded.description,
  purchase_price=excluded.purchase_price,
  prestige=excluded.prestige,
  rarity=excluded.rarity,
  annual_running_cost=excluded.annual_running_cost,
  annual_value_rate_bps=excluded.annual_value_rate_bps,
  resale_discount_bps=excluded.resale_discount_bps,
  image_url=excluded.image_url,
  active=true,
  metadata=coalesce(public.private_life_asset_catalog.metadata,'{}'::jsonb) || excluded.metadata,
  updated_at=now();

insert into public.private_life_property_catalog_availability(location_code,catalog_code,active)
select l.code,'home_standard_house',true
from tmp_standard_house_desired d
join public.private_life_property_locations l
  on upper(l.country_code)=d.country_code
 and lower(l.city)=lower(d.city)
on conflict(location_code,catalog_code) do update set
  active=true,
  updated_at=now();

update public.private_life_property_catalog_availability a
set active=false,
    updated_at=now()
where a.catalog_code='home_standard_house'
  and not exists (
    select 1
    from tmp_standard_house_desired d
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
  from tmp_standard_house_desired d
  where upper(l.country_code)=d.country_code
    and lower(l.city)=lower(d.city)
);

with matched as (
  select
    l.code as location_code,
    l.country_code,
    l.city,
    d.target_price,
    l.house_base_price as base_snapshot,
    d.image_city
  from tmp_standard_house_desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
),
payload as (
  select
    jsonb_object_agg(location_code,target_price order by location_code) as price_map,
    jsonb_object_agg(location_code,base_snapshot order by location_code) as snapshot_map,
    jsonb_object_agg(
      country_code||'|'||city,
      'storage://Admin/Private Life/Standard House/Standard House '||image_city||'.png'
      order by country_code,city
    ) as image_map
  from matched
)
update public.private_life_asset_catalog c
set metadata=coalesce(c.metadata,'{}'::jsonb)
      || jsonb_build_object(
        'city_price_overrides',payload.price_map,
        'city_price_base_snapshots',payload.snapshot_map,
        'city_image_urls',payload.image_map,
        'city_price_count',75,
        'city_image_count',75,
        'city_price_status','curated',
        'city_price_version','standard_house_v1',
        'city_price_model','baseline_scaled_override_v1',
        'city_set_status','ready',
        'planned_city_count',75,
        'image_status','curated',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Standard House',
        'missing_standard_house_images','[]'::jsonb,
        'pricing_reviewed_at','2026-10-07'
      ),
    image_url='storage://Admin/Private Life/Standard House/Standard House Tirana.png',
    active=true,
    updated_at=now()
from payload
where c.code='home_standard_house'
  and c.category='house_villa';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_standard_house_authenticated_read'
  ) then
    create policy "admin_private_life_standard_house_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Standard House/%'
      );
  end if;
end;
$$;

create or replace function public.get_private_life_dashboard_v3()
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_base jsonb;
  v_player uuid;
  v_locations jsonb;
begin
  v_base:=public.get_private_life_dashboard_v2();
  v_player:=(v_base->>'player_id')::uuid;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'code',l.code,
      'country_code',l.country_code,
      'country_name',l.country_name,
      'city',l.city,
      'apartment_base_price',l.apartment_base_price,
      'house_base_price',l.house_base_price,
      'annual_value_rate_bps',l.annual_value_rate_bps,
      'sort_order',l.sort_order,
      'monthly_change_bps',hist.monthly_change_bps,
      'previous_apartment_base_price',hist.previous_apartment_base_price,
      'previous_house_base_price',hist.previous_house_base_price,
      'market_season',hist.season,
      'market_month',hist.month,
      'is_standard_location',coalesce((
        select pl.marketplace_enabled
        from public.private_life_property_locations pl
        where pl.code=l.code
      ),false),
      'available_apartment_codes',
        case
          when not coalesce((
            select pl.marketplace_enabled
            from public.private_life_property_locations pl
            where pl.code=l.code
          ),false) then jsonb_build_array('apt_starter_city')
          else coalesce((
            select jsonb_agg(a.catalog_code order by coalesce((c.metadata->>'catalog_order')::integer,999),a.catalog_code)
            from public.private_life_property_catalog_availability a
            join public.private_life_asset_catalog c on c.code=a.catalog_code
            where a.location_code=l.code
              and a.active=true
              and c.active=true
              and c.category='apartment'
          ),'[]'::jsonb)
        end,
      'available_house_codes',
        case
          when not coalesce((
            select pl.marketplace_enabled
            from public.private_life_property_locations pl
            where pl.code=l.code
          ),false) then '[]'::jsonb
          else coalesce((
            select jsonb_agg(a.catalog_code order by coalesce((c.metadata->>'catalog_order')::integer,999),a.catalog_code)
            from public.private_life_property_catalog_availability a
            join public.private_life_asset_catalog c on c.code=a.catalog_code
            where a.location_code=l.code
              and a.active=true
              and c.active=true
              and c.category='house_villa'
          ),'[]'::jsonb)
        end
    ) order by l.sort_order,l.country_name,l.city
  ),'[]'::jsonb)
  into v_locations
  from public.private_life_property_locations_for_player_v1(v_player) l
  left join lateral (
    select h.*
    from public.private_life_property_market_history h
    where h.location_code=l.code
    order by h.season desc,h.month desc
    limit 1
  ) hist on true;

  return v_base || jsonb_build_object('property_locations',v_locations);
end;
$function$;

do $$
declare
  v_availability integer;
  v_price_map integer;
  v_image_map integer;
  v_bad_prices integer;
  v_bad_images integer;
begin
  select count(*)
  into v_availability
  from public.private_life_property_catalog_availability
  where catalog_code='home_standard_house'
    and active=true;

  select count(*)
  into v_price_map
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_price_overrides','{}'::jsonb))
  where c.code='home_standard_house';

  select count(*)
  into v_image_map
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_image_urls','{}'::jsonb))
  where c.code='home_standard_house';

  select count(*)
  into v_bad_prices
  from tmp_standard_house_desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
  where public.private_life_property_effective_price_v1('home_standard_house',l.code)<>d.target_price;

  select count(*)
  into v_bad_images
  from tmp_standard_house_desired d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Standard House/Standard House '||d.image_city||'.png'
  where o.id is null;

  if v_availability<>75 or v_price_map<>75 or v_image_map<>75 or v_bad_prices<>0 or v_bad_images<>0 then
    raise exception
      'Standard House validation failed: availability %, prices %, images %, bad prices %, missing images %.',
      v_availability,v_price_map,v_image_map,v_bad_prices,v_bad_images;
  end if;
end;
$$;
