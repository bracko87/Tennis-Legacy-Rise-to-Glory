-- Connect One-Bedroom Apartment city images for all currently uploaded destinations.
-- Boston and Montreal remain explicitly flagged until their image files are uploaded.

with image_seed(city_key,image_url) as (
  values
    ('RS|Belgrade','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Belgrade.png'),
    ('GB|London','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment London.png'),
    ('FR|Paris','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Paris.png'),
    ('ES|Madrid','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Madrid.png'),
    ('ES|Barcelona','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Barcelona.png'),
    ('IT|Rome','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Rome.png'),
    ('IT|Milan','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Milan.png'),
    ('AT|Vienna','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Vienna.png'),
    ('DE|Berlin','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Berlin.png'),
    ('DE|Munich','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Munich.png'),
    ('NL|Amsterdam','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Amsterdam.png'),
    ('PT|Lisbon','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Lisbon.png'),
    ('GR|Athens','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Athens.png'),
    ('AE|Dubai','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Dubai.png'),
    ('SA|Riyadh','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Riyadh.png'),
    ('US|New York','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment New York.png'),
    ('US|Miami','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Miami.png'),
    ('US|Los Angeles','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Los Angeles.png'),
    ('US|Chicago','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Chicago.png'),
    ('CA|Toronto','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Toronto.png'),
    ('MX|Mexico City','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Mexico City.png'),
    ('AR|Buenos Aires','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Buenos Aires.png'),
    ('BR|São Paulo','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Sao paolo.png'),
    ('ZA|Cape Town','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Cape Town.png'),
    ('AU|Sydney','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Sydney.png'),
    ('JP|Tokyo','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Tokyo.png'),
    ('KR|Seoul','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Seoul.png'),
    ('SG|Singapore','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Singapore.png'),
    ('TH|Bangkok','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Bangkok.png'),
    ('TR|Istanbul','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Istanbul.png'),
    ('AL|Tirana','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Tirana.png'),
    ('HR|Zagreb','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Zagreb.png'),
    ('HU|Budapest','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Budapest.png'),
    ('CZ|Prague','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Prague.png'),
    ('PL|Warsaw','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Warsaw.png'),
    ('DK|Copenhagen','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Copenhagen.png'),
    ('SE|Stockholm','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Stockholm.png'),
    ('NO|Oslo','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Oslo.png'),
    ('IE|Dublin','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Dublin.png'),
    ('BE|Brussels','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Brussels.png'),
    ('PT|Porto','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Porto.png'),
    ('ES|Valencia','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Valencia.png'),
    ('IT|Florence','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Florence.png'),
    ('FR|Nice','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Nice.png'),
    ('DE|Frankfurt','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Frankfurt.png'),
    ('SA|Jeddah','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Jeddah.png'),
    ('IL|Tel Aviv','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Tel Aviv.png'),
    ('EG|Cairo','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Cairo.png'),
    ('KE|Nairobi','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Nairobi.png'),
    ('NG|Lagos','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Lagos.png'),
    ('GE|Tbilisi','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Tbilisi.png'),
    ('JP|Kyoto','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Kyoto.png'),
    ('KR|Busan','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Busan.png'),
    ('TW|Taipei','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Taipei.png'),
    ('MY|Kuala Lumpur','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Kuala Lumpur.png'),
    ('VN|Ho Chi Minh City','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Ho Chi Minh City.png'),
    ('PH|Manila','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Manila.png'),
    ('ID|Jakarta','storage://Admin/Private Life/One Bedroom Apartment/One-Bedroom Apartment Jakarta.png')
),
payload as (
  select jsonb_object_agg(city_key,image_url) as city_images
  from image_seed
)
update public.private_life_asset_catalog c
set
  metadata = c.metadata
    - 'expected_image_storage_path'
    || jsonb_build_object(
      'image_status','curated',
      'image_storage_bucket','Admin',
      'image_storage_folder','Private Life/One Bedroom Apartment',
      'city_image_urls',p.city_images,
      'missing_standard_city_images',jsonb_build_array('US|Boston','CA|Montreal')
    ),
  updated_at=now()
from payload p
where c.code='apt_one_bedroom'
  and c.category='apartment';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_one_bedroom_apartment_authenticated_read'
  ) then
    create policy "admin_private_life_one_bedroom_apartment_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/One Bedroom Apartment/%'
      );
  end if;
end $$;
