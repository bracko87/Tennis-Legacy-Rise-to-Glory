-- Connect the final Shanghai Modern House image and mark the set complete.

do $$
begin
  if not exists (
    select 1
    from storage.objects
    where bucket_id='Admin'
      and name='Private Life/Modern House/Modern House Shanghai.png'
  ) then
    raise exception 'Shanghai Modern House image is not present in storage.';
  end if;
end;
$$;

update public.private_life_asset_catalog
set metadata =
      jsonb_set(
        jsonb_set(
          jsonb_set(
            coalesce(metadata,'{}'::jsonb),
            '{city_image_urls}',
            coalesce(metadata->'city_image_urls','{}'::jsonb)
              || jsonb_build_object(
                'CN|Shanghai',
                'storage://Admin/Private Life/Modern House/Modern House Shanghai.png'
              ),
            true
          ),
          '{city_image_count}',
          to_jsonb(55),
          true
        ),
        '{missing_modern_house_images}',
        '[]'::jsonb,
        true
      )
      || jsonb_build_object(
        'image_status','curated',
        'city_set_status','ready',
        'images_connected_at','2026-10-07'
      ),
    active=true,
    updated_at=now()
where code='home_country_residence'
  and category='house_villa';

do $$
declare
  v_map integer;
  v_path text;
begin
  select count(*)
  into v_map
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_image_urls','{}'::jsonb))
  where c.code='home_country_residence';

  select metadata->'city_image_urls'->>'CN|Shanghai'
  into v_path
  from public.private_life_asset_catalog
  where code='home_country_residence';

  if v_map<>55 or v_path is distinct from
    'storage://Admin/Private Life/Modern House/Modern House Shanghai.png'
  then
    raise exception
      'Final Modern House image validation failed: mapped %, Shanghai path %.',
      v_map,v_path;
  end if;
end;
$$;
