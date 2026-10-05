-- Connect Compact City Flat city-specific images to the apartment catalog.
-- Standard marketplace cities use their own image. Dynamic player home towns use
-- the generic "Home Country" image.

update public.private_life_asset_catalog
set
  image_url = 'storage://Admin/Private Life/Compact City Flat/Compact City Flat Home Country.png',
  metadata = metadata
    - 'expected_image_storage_path'
    || jsonb_build_object(
      'image_status','curated',
      'image_storage_bucket','Admin',
      'image_storage_folder','Private Life/Compact City Flat',
      'home_country_image_url','storage://Admin/Private Life/Compact City Flat/Compact City Flat Home Country.png',
      'location_image_urls', jsonb_build_object(
        'rs_belgrade','storage://Admin/Private Life/Compact City Flat/Compact City Flat Belgrade.png',
        'gb_london','storage://Admin/Private Life/Compact City Flat/Compact City Flat London.png',
        'fr_paris','storage://Admin/Private Life/Compact City Flat/Compact City Flat Paris.png',
        'mc_monaco','storage://Admin/Private Life/Compact City Flat/Compact City Flat Monaco.png',
        'es_madrid','storage://Admin/Private Life/Compact City Flat/Compact City Flat Madrid.png',
        'es_barcelona','storage://Admin/Private Life/Compact City Flat/Compact City Flat Barcelona.png',
        'it_rome','storage://Admin/Private Life/Compact City Flat/Compact City Flat Rome.png',
        'it_milan','storage://Admin/Private Life/Compact City Flat/Compact City Flat Milan.png',
        'ch_geneva','storage://Admin/Private Life/Compact City Flat/Compact City Flat Geneve.png',
        'ch_zurich','storage://Admin/Private Life/Compact City Flat/Compact City Flat Zurich.png',
        'at_vienna','storage://Admin/Private Life/Compact City Flat/Compact City Flat Vienna.png',
        'de_berlin','storage://Admin/Private Life/Compact City Flat/Compact City Flat Berlin.png',
        'de_hamburg','storage://Admin/Private Life/Compact City Flat/Compact City Flat Hamburg.png',
        'de_munich','storage://Admin/Private Life/Compact City Flat/Compact City Flat Munich.png',
        'nl_amsterdam','storage://Admin/Private Life/Compact City Flat/Compact City Flat Amsterdam.png',
        'pt_lisbon','storage://Admin/Private Life/Compact City Flat/Compact City Flat Lisbon.png',
        'gr_athens','storage://Admin/Private Life/Compact City Flat/Compact City Flat Athens.png',
        'ae_dubai','storage://Admin/Private Life/Compact City Flat/Compact City Flat Dubai.png',
        'qa_doha','storage://Admin/Private Life/Compact City Flat/Compact City Flat Doha.png',
        'ae_abudhabi','storage://Admin/Private Life/Compact City Flat/Compact City Flat Abu Dhabi.png',
        'sa_riyadh','storage://Admin/Private Life/Compact City Flat/Compact City Flat Riyadh.png',
        'us_miami','storage://Admin/Private Life/Compact City Flat/Compact City Flat Miami.png',
        'us_sanfrancisco','storage://Admin/Private Life/Compact City Flat/Compact City Flat San Francisco.png',
        'us_chicago','storage://Admin/Private Life/Compact City Flat/Compact City Flat Chicago.png',
        'ca_toronto','storage://Admin/Private Life/Compact City Flat/Compact City Flat Toronto.png',
        'ca_vancouver','storage://Admin/Private Life/Compact City Flat/Compact City Flat Vancouver.png',
        'mx_mexicocity','storage://Admin/Private Life/Compact City Flat/Compact City Flat Mexico City.png',
        'ar_buenosaires','storage://Admin/Private Life/Compact City Flat/Compact City Flat Buenos Aires.png',
        'br_rio','storage://Admin/Private Life/Compact City Flat/Compact City Flat Rio de Janeiro.png',
        'br_saopaulo','storage://Admin/Private Life/Compact City Flat/Compact City Flat Sao Paolo.png',
        'cl_santiago','storage://Admin/Private Life/Compact City Flat/Compact City Flat Santiago.png',
        'za_capetown','storage://Admin/Private Life/Compact City Flat/Compact City Flat Cape Town.png',
        'za_johannesburg','storage://Admin/Private Life/Compact City Flat/Compact City Flat Johannesburg.png',
        'au_melbourne','storage://Admin/Private Life/Compact City Flat/Compact City Flat Melbourne.png',
        'au_sydney','storage://Admin/Private Life/Compact City Flat/Compact City Flat Sydney.png',
        'nz_auckland','storage://Admin/Private Life/Compact City Flat/Compact City Flat Auckland.png',
        'jp_tokyo','storage://Admin/Private Life/Compact City Flat/Compact City Flat Tokyo.png',
        'jp_osaka','storage://Admin/Private Life/Compact City Flat/Compact City Flat Osaka.png',
        'kr_seoul','storage://Admin/Private Life/Compact City Flat/Compact City Flat Seoul.png',
        'sg_singapore','storage://Admin/Private Life/Compact City Flat/Compact City Flat Singapore.png',
        'hk_hongkong','storage://Admin/Private Life/Compact City Flat/Compact City Flat Hong Kong.png',
        'cn_shanghai','storage://Admin/Private Life/Compact City Flat/Compact City Flat Shanghai.png',
        'cn_beijing','storage://Admin/Private Life/Compact City Flat/Compact City Flat Beijing.png',
        'th_bangkok','storage://Admin/Private Life/Compact City Flat/Compact City Flat Bangkok.png',
        'id_bali','storage://Admin/Private Life/Compact City Flat/Compact City Flat Bali.png',
        'in_mumbai','storage://Admin/Private Life/Compact City Flat/Compact City Flat Mumbai.png',
        'in_delhi','storage://Admin/Private Life/Compact City Flat/Compact City Flat Delhi.png',
        'tr_istanbul','storage://Admin/Private Life/Compact City Flat/Compact City Flat Istanbul.png'
      ),
      'missing_standard_city_images', jsonb_build_array('us_newyork','us_losangeles')
    ),
  updated_at = now()
where code='apt_starter_city'
  and category='apartment';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_compact_city_flat_authenticated_read'
  ) then
    create policy "admin_private_life_compact_city_flat_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Compact City Flat/%'
      );
  end if;
end $$;
