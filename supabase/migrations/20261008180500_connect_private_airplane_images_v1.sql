-- Connect all 18 curated Private Airplanes images.
-- Actual uploaded folder is preserved exactly as: Admin/PL Airplanes/

create temporary table tmp_private_airplane_images_v1 (
  catalog_order integer primary key,
  code text unique not null,
  manufacturer text not null,
  model_name text not null,
  image_file text not null
) on commit drop;

insert into tmp_private_airplane_images_v1(
  catalog_order,code,manufacturer,model_name,image_file
)
values
  (1,'air_cessaro_c180','Cessaro','Skyhawk C180','Cessaro Skyhawk C180.png'),
  (2,'air_pipera_archer_lx','Pipera','Archer LX','Pipera Archer LX.png'),
  (3,'air_cirron_sr6_vision','Cirron','SR6 Vision','Cirron SR6 Vision.png'),
  (4,'air_beechmore_baron_b60','Beechmore','Baron B60','Beechmore Baron B60.png'),
  (5,'air_cessaro_grand_caravan_ex','Cessaro','Grand Caravan EX','Cessaro Grand Caravan EX.png'),
  (6,'air_daherion_tbm_980','Daherion','TBM 980','Daherion TBM 980.png'),
  (7,'air_pilara_pc14','Pilara','PC-14','Pilara PC-14.png'),
  (8,'air_beechmore_kingair_x360','Beechmore','KingAir X360','Beechmore KingAir X360.png'),
  (9,'air_hondara_hj_one','Hondara Aviation','HJ-One','Hondara Aviation HJ-One.png'),
  (10,'air_cessaro_citation_m3','Cessaro','Citation M3','Cessaro Citation M3.png'),
  (11,'air_emborgier_phenom_350e','Emborgier','Phenom 350E','Emborgier Phenom 350E.png'),
  (12,'air_bombara_challenger_420','Bombara','Challenger 420','Bombara Challenger 420.png'),
  (13,'air_cessaro_citation_latitude_x','Cessaro','Citation Latitude X','Cessaro Citation Latitude X.png'),
  (14,'air_emborgier_praetor_680','Emborgier','Praetor 680','EmborgierPraetor680.png'),
  (15,'air_dassier_falcon_9x','Dassier','Falcon 9X','Dassier Falcon 9X.png'),
  (16,'air_gulfstar_g650_lx','Gulfstar','G650 LX','Gulfstar G650 LX.png'),
  (17,'air_bombara_global_8000x','Bombara','Global 8000X','Bombara Global 8000X.png'),
  (18,'air_gulfstar_g900_sovereign','Gulfstar','G900 Sovereign','Gulfstar G900 Sovereign.png');

do $$
declare
  v_expected integer;
  v_catalog integer;
  v_images integer;
  v_missing text[];
begin
  select count(*) into v_expected from tmp_private_airplane_images_v1;

  select count(*)
  into v_catalog
  from tmp_private_airplane_images_v1 d
  join public.private_life_asset_catalog c
    on c.code=d.code
   and c.category='private_jet'
   and c.active=true;

  select count(*)
  into v_images
  from tmp_private_airplane_images_v1 d
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='PL Airplanes/'||d.image_file;

  select array_agg(d.manufacturer||' '||d.model_name order by d.catalog_order)
  into v_missing
  from tmp_private_airplane_images_v1 d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='PL Airplanes/'||d.image_file
  where o.id is null;

  if v_expected<>18 or v_catalog<>18 or v_images<>18 then
    raise exception
      'Private Airplanes image preflight failed: expected %, catalog %, images %, missing %.',
      v_expected,v_catalog,v_images,v_missing;
  end if;
end;
$$;

update public.private_life_asset_catalog c
set image_url='storage://Admin/PL Airplanes/'||d.image_file,
    metadata=coalesce(c.metadata,'{}'::jsonb)
      || jsonb_build_object(
        'manufacturer',d.manufacturer,
        'aircraft_builder',d.manufacturer,
        'model_name',d.model_name,
        'full_display_name',d.manufacturer||' · '||d.model_name,
        'image_status','curated',
        'image_storage_bucket','Admin',
        'image_storage_folder','PL Airplanes',
        'expected_image_storage_path','PL Airplanes/'||d.image_file,
        'image_file',d.image_file,
        'image_connected_at','2026-10-08'
      ),
    updated_at=now()
from tmp_private_airplane_images_v1 d
where c.code=d.code
  and c.category='private_jet'
  and c.active=true;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_airplanes_authenticated_read'
  ) then
    create policy "admin_private_life_airplanes_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'PL Airplanes/%'
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
  join tmp_private_airplane_images_v1 d on d.code=c.code
  where c.category='private_jet'
    and c.active=true
    and c.image_url='storage://Admin/PL Airplanes/'||d.image_file
    and c.metadata->>'manufacturer'=d.manufacturer
    and c.metadata->>'model_name'=d.model_name
    and c.metadata->>'image_status'='curated';

  select count(*)
  into v_wrong
  from public.private_life_asset_catalog c
  join tmp_private_airplane_images_v1 d on d.code=c.code
  where c.image_url is distinct from 'storage://Admin/PL Airplanes/'||d.image_file
     or c.metadata->>'manufacturer' is distinct from d.manufacturer
     or c.metadata->>'model_name' is distinct from d.model_name
     or c.metadata->>'image_status' is distinct from 'curated';

  select count(*)
  into v_missing_objects
  from public.private_life_asset_catalog c
  left join storage.objects o
    on o.bucket_id='Admin'
   and 'storage://Admin/'||o.name=c.image_url
  where c.category='private_jet'
    and c.active=true
    and o.id is null;

  select exists(
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_airplanes_authenticated_read'
  ) into v_policy;

  if v_connected<>18 or v_wrong<>0 or v_missing_objects<>0 or not v_policy then
    raise exception
      'Private Airplanes image validation failed: connected %, wrong %, missing objects %, policy %.',
      v_connected,v_wrong,v_missing_objects,v_policy;
  end if;
end;
$$;
