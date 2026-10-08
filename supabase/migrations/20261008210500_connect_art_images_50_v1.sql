-- Connect all 50 curated Private Life Art images.
-- Preserve the exact uploaded Storage filenames in Admin/PL Art/.

create temporary table tmp_art_images_50_v1 (
  catalog_order integer primary key,
  code text unique not null,
  artist text not null,
  artwork_title text not null,
  image_file text not null
) on commit drop;

insert into tmp_art_images_50_v1(
  catalog_order,code,artist,artwork_title,image_file
)
values
  (1,'art_01_quiet_morning','Lena Hartwig','Quiet Morning','Lena Hartwig Quiet Morning.png'),
  (2,'art_02_tuscan_light','Marco Bellini','Tuscan Light','Marco Bellini Tuscan Light.png'),
  (3,'art_03_rain_in_kyoto','Hana Mori','Rain in Kyoto','Hana Mori Rain in Kyoto.png'),
  (4,'art_04_blue_structure_no_4','Adrian Voss','Blue Structure No. 4','Adrian Voss Blue Structure No. 4.png'),
  (5,'art_05_winter_garden','Claire Beaumont','Winter Garden','Claire Beaumont Winter Garden.png'),
  (6,'art_06_calle_roja','Rafael Serrano','Calle Roja','Rafael Serrano Calle Roja.png'),
  (7,'art_07_the_dancer','Elisa Romano','The Dancer','Elisa Romano The Dancer.png'),
  (8,'art_08_northern_silence','Niklas Berg','Northern Silence','Niklas Berg Northern Silence.png'),
  (9,'art_09_golden_fields','Sofia Bellini','Golden Fields','Sofia Bellini Golden Fields.png'),
  (10,'art_10_city_rhythm','Samuel Okoro','City Rhythm','Samuel Okoro City Rhythm.png'),
  (11,'art_11_after_the_storm','Elise Moreau','After the Storm','Elise Moreau After the Storm.png'),
  (12,'art_12_forma_ii','Luca Ferrano','Forma II','Luca Ferrano Forma II.png'),
  (13,'art_13_banat_afternoon','Mila Petrovic','Banat Afternoon','Mila Petrovic Banat Afternoon.png'),
  (14,'art_14_evening_on_the_seine','Henri Valmont','Evening on the Seine','Henri Valmont Evening on the Seine.png'),
  (15,'art_15_fragmented_memory','Clara Weiss','Fragmented Memory','Clara Weiss Fragmented Memory.png'),
  (16,'art_16_pacific_horizon','Diego Marquez','Pacific Horizon','Diego Marquez Pacific Horizon.png'),
  (17,'art_17_ancestral_line','Amara Okafor','Ancestral Line','Amara Okafor Ancestral Line.png'),
  (18,'art_18_neon_tokyo','Yuki Tanaka','Neon Tokyo','Yuki Tanaka Neon Tokyo.png'),
  (19,'art_19_the_red_room','Matteo Caruso','The Red Room','Matteo Caruso The Red Room.png'),
  (20,'art_20_white_noise','Ingrid Falk','White Noise','IngridFalkWhite Noise.png'),
  (21,'art_21_weightless','Pavel Novak','Weightless','Pavel Novak Weightless.png'),
  (22,'art_22_jardim_azul','Gabriela Costa','Jardim Azul','Gabriela Costa Jardim Azul.png'),
  (23,'art_23_paris_04_17','Theo Lambert','Paris, 04:17','Theo Lambert Paris 04 17.png'),
  (24,'art_24_desert_crown','Nadia El-Masri','Desert Crown','Nadia El-Masri Desert Crown.png'),
  (25,'art_25_black_sun','Viktor Dragan','Black Sun','Viktor Dragan Black Sun.png'),
  (26,'art_26_primavera_no_7','Sofia Bellini','Primavera No. 7','Sofia Bellini Primavera No. 7.png'),
  (27,'art_27_continuum_iii','Amara Okafor','Continuum III','Amara Okafor Continuum III.png'),
  (28,'art_28_untitled_no_19','Alexander Reiss','Untitled No. 19','Alexander Reiss Untitled No. 19.png'),
  (29,'art_29_seoul_after_midnight','Jun Park','Seoul After Midnight','Jun Park Seoul After Midnight.png'),
  (30,'art_30_revolution_square','Rafael Serrano','Revolution Square','Rafael Serrano Revolution Square.png'),
  (31,'art_31_eternal_spring','Lucia Verani','Eternal Spring','Lucia Verani Eternal Spring.png'),
  (32,'art_32_la_nuit_rouge','Henri Valmont','La Nuit Rouge','Henri Valmont La Nuit Rouge.png'),
  (33,'art_33_the_crossing','Nikolai Arsenov','The Crossing','Nikolai Arsenov The Crossing.png'),
  (34,'art_34_lumiere_no_3','Amelie Laurent','Lumière No. 3','Amelie Laurent Lumiere No. 3.png'),
  (35,'art_35_floating_city','Kaito Nakamura','Floating City','Kaito Nakamura Floating City.png'),
  (36,'art_36_red_kingdom','Viktor Dragan','Red Kingdom','Viktor Dragan Red Kingdom.png'),
  (37,'art_37_ascension','Amara Okafor','Ascension','Amara Okafor Ascension.png'),
  (38,'art_38_the_last_summer','Elise Moreau','The Last Summer','Elise Moreau The Last Summer.png'),
  (39,'art_39_geometry_of_silence','Adrian Voss','Geometry of Silence','Adrian Voss Geometry of Silence.png'),
  (40,'art_40_imperium','Luca Ferrano','Imperium','Luca Ferrano Imperium.png'),
  (41,'art_41_sakura_forever','Hana Mori','Sakura Forever','Hana Mori Sakura Forever.png'),
  (42,'art_42_nocturne_de_madrid','Mateo Alvarez','Nocturne de Madrid','Mateo Alvarez Nocturne de Madrid.png'),
  (43,'art_43_empire_of_winter','Nikolai Arsenov','Empire of Winter','Nikolai Arsenov Empire of Winter.png'),
  (44,'art_44_infinite_light','Amelie Laurent','Infinite Light','Amelie Laurent Infinite Light.png'),
  (45,'art_45_garden_of_eternity','Sofia Bellini','Garden of Eternity','Sofia Bellini Garden of Eternity.png'),
  (46,'art_46_the_last_emperor','Viktor Dragan','The Last Emperor','Viktor Dragan The Last Emperor.png'),
  (47,'art_47_origin','Amara Okafor','Origin','Amara OkaforOrigin Monumental.png'),
  (48,'art_48_midnight_in_paris','Henri Valmont','Midnight in Paris','Henri Valmont Midnight in Paris.png'),
  (49,'art_49_the_silent_century','Alexander Reiss','The Silent Century','Alexander Reiss The Silent Century.png'),
  (50,'art_50_crown_of_civilization','Viktor Dragan','Crown of Civilization','Viktor Dragan Crown of Civilization.png');

do $$
declare
  v_expected integer;
  v_catalog integer;
  v_images integer;
  v_missing text[];
begin
  select count(*) into v_expected from tmp_art_images_50_v1;

  select count(*)
  into v_catalog
  from tmp_art_images_50_v1 d
  join public.private_life_asset_catalog c
    on c.code=d.code
   and c.category='art'
   and c.active=true
   and c.name=d.artwork_title
   and c.metadata->>'artist'=d.artist;

  select count(*)
  into v_images
  from tmp_art_images_50_v1 d
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='PL Art/'||d.image_file;

  select array_agg(d.artist||' — '||d.artwork_title order by d.catalog_order)
  into v_missing
  from tmp_art_images_50_v1 d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='PL Art/'||d.image_file
  where o.id is null;

  if v_expected<>50 or v_catalog<>50 or v_images<>50 then
    raise exception
      'Art image preflight failed: expected %, catalog %, images %, missing %.',
      v_expected,v_catalog,v_images,v_missing;
  end if;
end;
$$;

update public.private_life_asset_catalog c
set image_url='storage://Admin/PL Art/'||d.image_file,
    metadata=coalesce(c.metadata,'{}'::jsonb)
      || jsonb_build_object(
        'artist',d.artist,
        'artwork_title',d.artwork_title,
        'full_display_name',d.artist||' · '||d.artwork_title,
        'image_status','curated',
        'image_storage_bucket','Admin',
        'image_storage_folder','PL Art',
        'expected_image_storage_path','PL Art/'||d.image_file,
        'image_file',d.image_file,
        'image_connected_at','2026-10-08'
      ),
    updated_at=now()
from tmp_art_images_50_v1 d
where c.code=d.code
  and c.category='art'
  and c.active=true;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_art_authenticated_read'
  ) then
    create policy "admin_private_life_art_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'PL Art/%'
      );
  end if;
end;
$$;

do $$
declare
  v_connected integer;
  v_wrong integer;
  v_missing_objects integer;
  v_policy boolean;
begin
  select count(*)
  into v_connected
  from public.private_life_asset_catalog c
  join tmp_art_images_50_v1 d on d.code=c.code
  where c.category='art'
    and c.active=true
    and c.image_url='storage://Admin/PL Art/'||d.image_file
    and c.metadata->>'artist'=d.artist
    and c.metadata->>'artwork_title'=d.artwork_title
    and c.metadata->>'image_status'='curated';

  select count(*)
  into v_wrong
  from public.private_life_asset_catalog c
  join tmp_art_images_50_v1 d on d.code=c.code
  where c.image_url is distinct from 'storage://Admin/PL Art/'||d.image_file
     or c.metadata->>'artist' is distinct from d.artist
     or c.metadata->>'artwork_title' is distinct from d.artwork_title
     or c.metadata->>'image_status' is distinct from 'curated';

  select count(*)
  into v_missing_objects
  from public.private_life_asset_catalog c
  left join storage.objects o
    on o.bucket_id='Admin'
   and 'storage://Admin/'||o.name=c.image_url
  where c.category='art'
    and c.active=true
    and o.id is null;

  select exists(
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_art_authenticated_read'
  ) into v_policy;

  if v_connected<>50 or v_wrong<>0 or v_missing_objects<>0 or not v_policy then
    raise exception
      'Art image validation failed: connected %, wrong %, missing objects %, policy %.',
      v_connected,v_wrong,v_missing_objects,v_policy;
  end if;
end;
$$;
