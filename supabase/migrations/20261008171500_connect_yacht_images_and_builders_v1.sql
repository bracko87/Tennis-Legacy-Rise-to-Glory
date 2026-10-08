-- Connect all 30 curated yacht images and publish builder metadata.
-- Actual uploaded folder is preserved exactly as: Admin/PL Yahts/

create temporary table tmp_yacht_images_v1 (
  catalog_order integer primary key,
  code text unique not null,
  model_name text not null,
  yacht_builder text not null,
  image_file text not null
) on commit drop;

insert into tmp_yacht_images_v1(catalog_order,code,model_name,yacht_builder,image_file)
values
  (1,'yacht_m7','M7','Marinera Yachts','Yacht M7.png'),
  (2,'yacht_ventura','Ventura','Solstice Marine','Yacht Ventura.png'),
  (3,'yacht_cx4','CX-4','Cormorant Yachts','Yacht CX-4.png'),
  (4,'yacht_ardent_900','Ardent 900','Ardent Marine','Yacht Ardent 900.png'),
  (5,'yacht_bluewave_s','Bluewave S','Bluewave Yachts','Yacht Bluewave S.png'),
  (6,'yacht_v52x','V52X','Velacraft Marine','Yacht V52X.png'),
  (7,'yacht_bellagio','Bellagio','Bellagio Marine','Yacht Bellagio.png'),
  (8,'yacht_r88','R88','Riviera Works','Yacht R88.png'),
  (9,'yacht_stratos_6','Stratos 6','Stratos Marine','Yacht Stratos 6.png'),
  (10,'yacht_axiom_2000','Axiom 2000','Axiom Yachts','Yacht Axiom 2000.png'),
  (11,'yacht_velaris_gt','Velaris GT','Aurelian Marine','Yacht Velaris GT.png'),
  (12,'yacht_p9','P9','Pelago Yachts','Yacht P9.png'),
  (13,'yacht_zenith_x','Zenith X','Northcrest Marine','Yacht Zenith X.png'),
  (14,'yacht_elysium_850','Elysium 850','Elysian Yachts','Yacht Elysium 850.png'),
  (15,'yacht_black_pearl','Black Pearl','Obsidian Marine','Yacht Black Pearl.png'),
  (16,'yacht_l95r','L95R','Litora Yachts','Yacht L95R.png'),
  (17,'yacht_solaris_one','Solaris One','Solara Marine','Yacht Solaris One.png'),
  (18,'yacht_m1150','M1150','Meridian Yachts','Yacht M1150.png'),
  (19,'yacht_aurelia','Aurelia','Aurelis Yachts','Yacht Aurelia.png'),
  (20,'yacht_titan_g4','Titan G4','Titanis Marine','Yacht Titan G4.png'),
  (21,'yacht_s145x','S145X','Sterling Marine','Yacht S145X.png'),
  (22,'yacht_neptune','Neptune','San Lorenzo Marine','Yacht Neptune.png'),
  (23,'yacht_ox_500','OX-500','Orion Craft','Yacht OX-500.png'),
  (24,'yacht_celestia_55r','Celestia 55R','Celestia Marine','Yacht Celestia 55R.png'),
  (25,'yacht_valkyrie','Valkyrie','Nordhaven Yachts','Yacht Valkyrie.png'),
  (26,'yacht_p7000','P7000','Prestige Oceanworks','Yacht P7000.png'),
  (27,'yacht_aurora_prime','Aurora Prime','Aurora Shipworks','Yacht Aurora Prime.png'),
  (28,'yacht_bs_85','BS-85','BlueStar Marine','Yacht BS-85.png'),
  (29,'yacht_infinity_x1','Infinity X1','Infinity Naval Design','Yacht Infinity X1.png'),
  (30,'yacht_leviathan_12k','Leviathan 12K','Leviathan Global Yachts','Yacht Leviathan 12K.png');

do $$
declare
  v_expected integer;
  v_catalog integer;
  v_images integer;
  v_missing text[];
begin
  select count(*) into v_expected from tmp_yacht_images_v1;

  select count(*)
  into v_catalog
  from tmp_yacht_images_v1 d
  join public.private_life_asset_catalog c
    on c.code=d.code
   and c.category='yacht'
   and c.active=true;

  select count(*)
  into v_images
  from tmp_yacht_images_v1 d
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='PL Yahts/'||d.image_file;

  select array_agg(d.model_name order by d.catalog_order)
  into v_missing
  from tmp_yacht_images_v1 d
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name='PL Yahts/'||d.image_file
  where o.id is null;

  if v_expected<>30 or v_catalog<>30 or v_images<>30 then
    raise exception
      'Yacht image preflight failed: expected %, catalog %, images %, missing %.',
      v_expected,v_catalog,v_images,v_missing;
  end if;
end;
$$;

update public.private_life_asset_catalog c
set image_url='storage://Admin/PL Yahts/'||d.image_file,
    metadata=coalesce(c.metadata,'{}'::jsonb)
      || jsonb_build_object(
        'yacht_builder',d.yacht_builder,
        'manufacturer',d.yacht_builder,
        'model_name',d.model_name,
        'full_display_name',d.yacht_builder||' · '||d.model_name,
        'image_status','curated',
        'image_storage_bucket','Admin',
        'image_storage_folder','PL Yahts',
        'expected_image_storage_path','PL Yahts/'||d.image_file,
        'image_file',d.image_file,
        'image_connected_at','2026-10-08'
      ),
    updated_at=now()
from tmp_yacht_images_v1 d
where c.code=d.code
  and c.category='yacht'
  and c.active=true;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_yachts_authenticated_read'
  ) then
    create policy "admin_private_life_yachts_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'PL Yahts/%'
      );
  end if;
end;
$$;

do $$
declare
  v_connected integer;
  v_wrong integer;
  v_policy boolean;
begin
  select count(*)
  into v_connected
  from public.private_life_asset_catalog c
  join tmp_yacht_images_v1 d on d.code=c.code
  where c.category='yacht'
    and c.active=true
    and c.image_url='storage://Admin/PL Yahts/'||d.image_file
    and c.metadata->>'yacht_builder'=d.yacht_builder
    and c.metadata->>'model_name'=d.model_name
    and c.metadata->>'image_status'='curated';

  select count(*)
  into v_wrong
  from public.private_life_asset_catalog c
  join tmp_yacht_images_v1 d on d.code=c.code
  where c.image_url is distinct from 'storage://Admin/PL Yahts/'||d.image_file
     or c.metadata->>'yacht_builder' is distinct from d.yacht_builder
     or c.metadata->>'model_name' is distinct from d.model_name;

  select exists(
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_yachts_authenticated_read'
  ) into v_policy;

  if v_connected<>30 or v_wrong<>0 or not v_policy then
    raise exception
      'Yacht image validation failed: connected %, wrong %, policy %.',
      v_connected,v_wrong,v_policy;
  end if;
end;
$$;
