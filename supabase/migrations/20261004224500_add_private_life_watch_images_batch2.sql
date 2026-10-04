-- Add the remaining 10 curated Private Life watch images.
-- Names/prices/prestige/rarity remain unchanged.

with supplied(name,image_url) as (
  values
  ('Ralex Submarina Date','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Private%20Life/Watches/Ralex%20Submarina%20Date.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Qcml2YXRlIExpZmUvV2F0Y2hlcy9SYWxleCBTdWJtYXJpbmEgRGF0ZS5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkxMTQ1MjM2LCJleHAiOjQ5MTMyMDkyMzZ9.Yb-9JgnghmUpzoXr_NTYrmbFMrojJeyWb_hXI1y5isn--fapxGC27rOX-2cVSeqkSadodPN0KB65_t4YhPOt9g'),
  ('Ralex Cosmograf Datona Steel','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Private%20Life/Watches/Ralex%20Cosmograf%20Datona%20Steel.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Qcml2YXRlIExpZmUvV2F0Y2hlcy9SYWxleCBDb3Ntb2dyYWYgRGF0b25hIFN0ZWVsLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTExNDUyNDksImV4cCI6NDkxMzIwOTI0OX0.5_jSIy8wpUlVj063fn-Qh7Q29wqgt5JCeeSCnvXED-_TyC45g_y9oGMddI41aPeCCT3-ZfAKh0QAtT25U2z1EA'),
  ('Ralex Skydweller','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Private%20Life/Watches/Ralex%20Skydweller.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Qcml2YXRlIExpZmUvV2F0Y2hlcy9SYWxleCBTa3lkd2VsbGVyLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTExNDUyNzcsImV4cCI6NDkxMzIwOTI3N30.yTEjpZZlpE5XwLoM-KXQm8OLMN63Qbve5CJ7A9aVWpVtmWS2HbPimPVAW4I3PTof2h_QP-kgl4ZBG46B7dCIRw'),
  ('Hublex Grand Bang Unico','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Private%20Life/Watches/Hublex%20Grand%20Bang%20Unico.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Qcml2YXRlIExpZmUvV2F0Y2hlcy9IdWJsZXggR3JhbmQgQmFuZyBVbmljby5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkxMTQ1MjkyLCJleHAiOjQ5MTMyMDkyOTJ9.8sO1F5Z47Rp2mDMJi2gtLlTOudyjocf08XSCb7w3umFV4D1u8K3YQvD0pB1ExSnfGHUpWTi1Bta6DOv8Fk1qLA'),
  ('Ralex Cosmograf Datona Steel & Gold','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Private%20Life/Watches/Ralex%20Cosmograf%20Datona%20Steel%20&%20Gold.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Qcml2YXRlIExpZmUvV2F0Y2hlcy9SYWxleCBDb3Ntb2dyYWYgRGF0b25hIFN0ZWVsICYgR29sZC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkxMTQ1MjY1LCJleHAiOjQ5MTMyMDkyNjV9.pEQUB_xrOiz-PlvOoEiZgZpOFXmHFLoMvr5E-5l35hrjNAE5vb5HEaM1t9ou7tL0fl8JF6yV0XWV59oHHlB_rg'),
  ('Patek Phillene AquaNaut 5167A','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Private%20Life/Watches/Patek%20Phillene%20AquaNaut%205167A.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Qcml2YXRlIExpZmUvV2F0Y2hlcy9QYXRlayBQaGlsbGVuZSBBcXVhTmF1dCA1MTY3QS5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkxMTQ1MzA0LCJleHAiOjQ5MTMyMDkzMDR9.SEJnv7BXWaG7zZpY9gXHCCadzVcyM4AdBqbqc7eanipKNPl8KKo2J3I6uNszkj1HdnbMvm-KQYIWEfJOkqn37A'),
  ('Audemar Piquet Royal Oak Selfwind 41','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Private%20Life/Watches/Audemar%20Piquet%20Royal%20Oak%20Selfwind%2041.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Qcml2YXRlIExpZmUvV2F0Y2hlcy9BdWRlbWFyIFBpcXVldCBSb3lhbCBPYWsgU2VsZndpbmQgNDEucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MTE0NTMxNCwiZXhwIjo0OTEzMjA5MzE0fQ.PZsDQtvdJVwYdqtMzRmBpyWfvCZ9cuNswSba7WLBE5r9fC30f8tMmbcCSPE8_twZdvrm8ynRQpbmHiA2fajfjg'),
  ('Ralex Cosmograf Datona Yellow Gold','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Private%20Life/Watches/Ralex%20Cosmograf%20Datona%20Yellow%20Gold.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Qcml2YXRlIExpZmUvV2F0Y2hlcy9SYWxleCBDb3Ntb2dyYWYgRGF0b25hIFllbGxvdyBHb2xkLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTExNDUzMjksImV4cCI6NDkxMzIwOTMyOX0.V5po1NuAu2-Hl0Cj6QuMUvfnJE6C8PBslV7U3DMo4YnjrBbKsKcKnx9BVpsdnN6VYunrwGqD5DcPlKjtP4hyaQ'),
  ('Hublex Grand Bang Tourbillon Champion Edition','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Private%20Life/Watches/Hublex%20Grand%20Bang%20Tourbillon%20Champion%20Edition.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Qcml2YXRlIExpZmUvV2F0Y2hlcy9IdWJsZXggR3JhbmQgQmFuZyBUb3VyYmlsbG9uIENoYW1waW9uIEVkaXRpb24ucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MTE0NTM0MywiZXhwIjo0OTEzMjA5MzQzfQ.y_gvXixkdWkH4cGe-6qnuLvuCwDmwqAvFCUXOfU6K43EyGaX3GtUZ75WhKUeUL04LAkNFFy6FxUPEMX602XnIg'),
  ('Richard Mielle RM 35-03 Grand Slam Legend','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Private%20Life/Watches/Richard%20Mielle%20RM%2035-03%20Grand%20Slam%20Legend.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Qcml2YXRlIExpZmUvV2F0Y2hlcy9SaWNoYXJkIE1pZWxsZSBSTSAzNS0wMyBHcmFuZCBTbGFtIExlZ2VuZC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkxMTQ1MzU0LCJleHAiOjQ5MTMyMDkzNTR9.3h_Peaehifu1SHRQkwg7UOZ9vqY5vSQ8TS7mgdQIG-hz-9d0LoMrDUHwqBNsP4AOtNzU_PUuAdrrdgSsf52w4w')
)
update public.private_life_asset_catalog c
set image_url=s.image_url,
    updated_at=now()
from supplied s
where c.category='watch'
  and c.name=s.name;

do $$
declare
  v_supplied_rows integer;
  v_storage_missing integer;
  v_placeholder_rows integer;
begin
  select count(*) into v_supplied_rows
  from public.private_life_asset_catalog
  where category='watch'
    and name in (
      'Ralex Submarina Date',
      'Ralex Cosmograf Datona Steel',
      'Ralex Skydweller',
      'Hublex Grand Bang Unico',
      'Ralex Cosmograf Datona Steel & Gold',
      'Patek Phillene AquaNaut 5167A',
      'Audemar Piquet Royal Oak Selfwind 41',
      'Ralex Cosmograf Datona Yellow Gold',
      'Hublex Grand Bang Tourbillon Champion Edition',
      'Richard Mielle RM 35-03 Grand Slam Legend'
    )
    and image_url like 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Private%';

  select count(*) into v_storage_missing
  from public.private_life_asset_catalog c
  where c.category='watch'
    and not exists(
      select 1
      from storage.objects o
      where o.bucket_id='Admin'
        and o.name='Private Life/Watches/'||c.name||'.png'
    );

  select count(*) into v_placeholder_rows
  from public.private_life_asset_catalog
  where category='watch'
    and image_url like 'https://images.unsplash.com/%';

  if v_supplied_rows<>10 then
    raise exception 'Expected 10 updated watch image rows, got %.',v_supplied_rows;
  end if;
  if v_storage_missing<>0 then
    raise exception 'Watch storage objects missing: %.',v_storage_missing;
  end if;
  if v_placeholder_rows<>0 then
    raise exception 'Placeholder watch images still remain: %.',v_placeholder_rows;
  end if;
end;
$$;

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values(
  'check:private_life_watch_images',
  'Private Life watch images',
  'Private Life',
  'Validates that every active watch catalog item has its corresponding curated Admin storage image and no placeholder URL remains.',
  'business_check',null,false,'warning',720,1800,false,226
)
on conflict(process_key) do update set
  label=excluded.label,
  category=excluded.category,
  description=excluded.description,
  source_kind=excluded.source_kind,
  source_ref=excluded.source_ref,
  user_sensitive=excluded.user_sensitive,
  incident_severity=excluded.incident_severity,
  expected_interval_minutes=excluded.expected_interval_minutes,
  stale_after_minutes=excluded.stale_after_minutes,
  email_alerts_enabled=excluded.email_alerts_enabled,
  is_enabled=true,
  sort_order=excluded.sort_order,
  updated_at=now();

create or replace function public.check_private_life_watch_images_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','storage','pg_catalog','pg_temp'
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_total integer:=0;
  v_missing_storage integer:=0;
  v_placeholders integer:=0;
  v_missing_urls integer:=0;
  v_problem_count integer:=0;
  v_details jsonb;
begin
  select count(*) into v_total
  from public.private_life_asset_catalog
  where category='watch' and active;

  select count(*) into v_missing_storage
  from public.private_life_asset_catalog c
  where c.category='watch' and c.active
    and not exists(
      select 1 from storage.objects o
      where o.bucket_id='Admin'
        and o.name='Private Life/Watches/'||c.name||'.png'
    );

  select count(*) into v_placeholders
  from public.private_life_asset_catalog
  where category='watch' and active
    and image_url like 'https://images.unsplash.com/%';

  select count(*) into v_missing_urls
  from public.private_life_asset_catalog
  where category='watch' and active
    and coalesce(image_url,'')='';

  v_problem_count:=v_missing_storage+v_placeholders+v_missing_urls;
  v_details:=jsonb_build_object(
    'active_watch_catalog_rows',v_total,
    'missing_storage_objects',v_missing_storage,
    'placeholder_image_urls',v_placeholders,
    'missing_image_urls',v_missing_urls
  );

  if v_problem_count>0 then
    perform public.raise_system_incident_v1(
      'check:private_life_watch_images','warning',
      'Private Life watch images require attention',
      format('%s watch image integrity issue(s) detected.',v_problem_count),
      'business:private-life-watch-images',
      v_details
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:private-life-watch-images',
      'All Private Life watch catalog images are mapped and present in Admin storage.'
    );
  end if;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  ) values(
    'check:private_life_watch_images',
    case when v_problem_count>0 then 'warning' else 'success' end,
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    case when v_problem_count>0
      then format('%s Private Life watch image issue(s).',v_problem_count)
      else format('%s/%s active watch images are mapped and present.',v_total,v_total)
    end,
    v_details
  );

  return jsonb_build_object(
    'status',case when v_problem_count>0 then 'warning' else 'success' end,
    'problems',v_problem_count,
    'details',v_details
  );
end;
$$;

select public.check_private_life_watch_images_v1();
