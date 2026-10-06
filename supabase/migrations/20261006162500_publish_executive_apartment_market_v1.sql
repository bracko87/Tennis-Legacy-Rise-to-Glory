-- Publish and calibrate the 55-city Executive Apartment market.
-- Uses city-specific target prices so the category does not inherit repeated
-- base-price multiples. Targets remain linked to each city's future property
-- market movement through the existing baseline-scaled override model.

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from public.private_life_property_catalog_availability
  where catalog_code='apt_executive';

  if v_count <> 55 then
    raise exception 'Expected 55 Executive Apartment destinations, found %.', v_count;
  end if;
end;
$$;

with desired(country_code,city,target_price) as (
  values
    ('SI','Ljubljana',561000::bigint),
    ('BG','Sofia',279750::bigint),
    ('RO','Bucharest',323500::bigint),
    ('PL','Krakow',518250::bigint),
    ('SK','Bratislava',539250::bigint),
    ('BE','Antwerp',767500::bigint),
    ('ES','Seville',508000::bigint),
    ('ES','Bilbao',777750::bigint),
    ('IT','Naples',486500::bigint),
    ('FR','Marseille',756000::bigint),
    ('DE','Cologne',842500::bigint),
    ('EE','Tallinn',528500::bigint),
    ('LV','Riga',301500::bigint),
    ('JO','Amman',355500::bigint),
    ('LB','Beirut',637000::bigint),
    ('MA','Casablanca',400000::bigint),
    ('MA','Marrakech',583000::bigint),
    ('GH','Accra',431750::bigint),
    ('NG','Abuja',452750::bigint),
    ('AO','Luanda',681000::bigint),
    ('KZ','Astana',335000::bigint),
    ('KZ','Almaty',615000::bigint),
    ('AZ','Baku',691250::bigint),
    ('JP','Sapporo',659500::bigint),
    ('TW','Kaohsiung',594500::bigint),
    ('CN','Guangzhou',798750::bigint),
    ('CN','Chengdu',723500::bigint),
    ('CN','Chongqing',701500::bigint),
    ('CN','Nanjing',788000::bigint),
    ('CN','Wuhan',669500::bigint),
    ('CN','Xi''an',625750::bigint),
    ('MY','George Town',550500::bigint),
    ('VN','Hanoi',377500::bigint),
    ('VN','Da Nang',474500::bigint),
    ('PH','Cebu City',269000::bigint),
    ('ID','Surabaya',258750::bigint),
    ('TH','Chiang Mai',291000::bigint),
    ('LK','Colombo',421500::bigint),
    ('IN','Bengaluru',734000::bigint),
    ('IN','Hyderabad',496500::bigint),
    ('CA','Calgary',810000::bigint),
    ('CA','Ottawa',820500::bigint),
    ('MX','Monterrey',712250::bigint),
    ('MX','Guadalajara',442000::bigint),
    ('CR','San Jose',604750::bigint),
    ('CO','Bogota',345250::bigint),
    ('CO','Medellin',410000::bigint),
    ('CO','Cartagena',573000::bigint),
    ('PE','Lima',366250::bigint),
    ('EC','Quito',313500::bigint),
    ('UY','Montevideo',647500::bigint),
    ('BR','Brasilia',464000::bigint),
    ('BR','Florianopolis',746000::bigint),
    ('BR','Salvador',388000::bigint),
    ('AU','Adelaide',832500::bigint)
),
matched as (
  select l.code as location_code,
         d.target_price,
         l.apartment_base_price as base_snapshot
  from desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
  join public.private_life_property_catalog_availability a
    on a.location_code=l.code
   and a.catalog_code='apt_executive'
)
update public.private_life_asset_catalog c
set metadata=coalesce(c.metadata,'{}'::jsonb)
      || jsonb_build_object(
        'city_price_overrides',
        (select jsonb_object_agg(location_code,target_price order by location_code) from matched),
        'city_price_base_snapshots',
        (select jsonb_object_agg(location_code,base_snapshot order by location_code) from matched),
        'city_price_status','calibrated_unique',
        'city_price_version','executive_apartment_v1',
        'city_price_model','baseline_scaled_override_v1',
        'city_price_count',55,
        'city_set_status','database_ready_waiting_for_images',
        'planned_city_count',55,
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Executive Apartment',
        'expected_image_storage_path','Private Life/Executive Apartment/Executive Apartment Home Country.png'
      ),
    updated_at=now()
where c.code='apt_executive'
  and c.category='apartment';

update public.private_life_property_catalog_availability
set active=true,
    updated_at=now()
where catalog_code='apt_executive';

update public.private_life_property_locations l
set marketplace_enabled=true,
    active=true,
    updated_at=now()
where exists (
  select 1
  from public.private_life_property_catalog_availability a
  where a.location_code=l.code
    and a.catalog_code='apt_executive'
    and a.active=true
);

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_executive_apartment_authenticated_read'
  ) then
    create policy "admin_private_life_executive_apartment_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Executive Apartment/%'
      );
  end if;
end $$;

do $$
declare
  v_prices integer;
  v_distinct integer;
  v_hidden integer;
begin
  select count(*)
  into v_prices
  from public.private_life_asset_catalog c,
       lateral jsonb_object_keys(coalesce(c.metadata->'city_price_overrides','{}'::jsonb)) k
  where c.code='apt_executive';

  select count(distinct (value::text)::bigint)
  into v_distinct
  from public.private_life_asset_catalog c,
       lateral jsonb_each(c.metadata->'city_price_overrides')
  where c.code='apt_executive';

  select count(*)
  into v_hidden
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l on l.code=a.location_code
  where a.catalog_code='apt_executive'
    and (a.active=false or l.active=false or l.marketplace_enabled=false);

  if v_prices<>55 or v_distinct<>55 or v_hidden<>0 then
    raise exception 'Executive Apartment validation failed: price count %, distinct %, hidden %.',
      v_prices,v_distinct,v_hidden;
  end if;
end;
$$;
