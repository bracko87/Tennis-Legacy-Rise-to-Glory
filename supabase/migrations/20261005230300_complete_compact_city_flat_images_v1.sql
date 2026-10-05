-- Complete Compact City Flat image coverage for New York and Los Angeles.

update public.private_life_asset_catalog
set
  metadata = jsonb_set(
    jsonb_set(
      metadata,
      '{location_image_urls,us_newyork}',
      to_jsonb('storage://Admin/Private Life/Compact City Flat/Compact City Flat New York.png'::text),
      true
    ),
    '{location_image_urls,us_losangeles}',
    to_jsonb('storage://Admin/Private Life/Compact City Flat/Compact City Flat Los Angeles.png'::text),
    true
  ) || jsonb_build_object('missing_standard_city_images', '[]'::jsonb),
  updated_at = now()
where code='apt_starter_city'
  and category='apartment';
