-- Finalize and audit the Tennis Legacy main sponsor catalogue import.
-- Source catalogue: ProPeloton (read-only transfer), 866 main sponsors.
-- Intentional target-only correction: Deutsche Telecom -> Deutsche Telekom.

update public.sponsor_companies
set name = 'Deutsche Telekom',
    updated_at = now()
where id = '06feac4b-ab98-41ae-a005-defe191e48a6'::uuid
  and name is distinct from 'Deutsche Telekom';

do $$
declare
  v_count bigint;
  v_distinct bigint;
  v_blank_names bigint;
  v_missing_country bigint;
  v_invalid_country bigint;
  v_missing_logo bigint;
  v_inactive bigint;
  v_non_test bigint;
  v_null_group bigint;
  v_null_macro bigint;
  v_id_hash text;
  v_country_hash text;
  v_logo_hash text;
  v_metadata_hash text;
  v_geography_hash text;
  v_source_equivalent_name_hash text;
begin
  select
    count(*),
    count(distinct id),
    count(*) filter (where name is null or btrim(name) = ''),
    count(*) filter (where country_code is null or btrim(country_code) = ''),
    count(*) filter (where country_code !~ '^[A-Z]{2}$'),
    count(*) filter (where logo_url is null or btrim(logo_url) = ''),
    count(*) filter (where not is_active),
    count(*) filter (where not is_test),
    count(*) filter (where home_group_code is null),
    count(*) filter (where home_macro_region is null)
  into
    v_count,
    v_distinct,
    v_blank_names,
    v_missing_country,
    v_invalid_country,
    v_missing_logo,
    v_inactive,
    v_non_test,
    v_null_group,
    v_null_macro
  from public.sponsor_companies
  where sponsor_kind = 'main';

  if v_count <> 866 then raise exception 'Expected 866 main sponsors, got %.', v_count; end if;
  if v_distinct <> 866 then raise exception 'Expected 866 distinct main sponsor ids, got %.', v_distinct; end if;
  if v_blank_names <> 0 then raise exception 'Blank main sponsor names detected: %.', v_blank_names; end if;
  if v_missing_country <> 0 then raise exception 'Missing main sponsor country codes detected: %.', v_missing_country; end if;
  if v_invalid_country <> 0 then raise exception 'Invalid main sponsor country codes detected: %.', v_invalid_country; end if;
  if v_missing_logo <> 0 then raise exception 'Missing main sponsor logo URLs detected: %.', v_missing_logo; end if;
  if v_inactive <> 0 then raise exception 'Unexpected inactive main sponsors detected: %.', v_inactive; end if;
  if v_non_test <> 0 then raise exception 'Unexpected non-test main sponsors detected: %.', v_non_test; end if;
  if v_null_group <> 56 then raise exception 'Expected 56 null home_group_code values, got %.', v_null_group; end if;
  if v_null_macro <> 56 then raise exception 'Expected 56 null home_macro_region values, got %.', v_null_macro; end if;

  if (select name from public.sponsor_companies where id = '06feac4b-ab98-41ae-a005-defe191e48a6'::uuid) <> 'Deutsche Telekom' then
    raise exception 'Deutsche Telekom correction is missing.';
  end if;

  select
    encode(digest(string_agg(id::text, E'\n' order by id::text), 'sha256'), 'hex'),
    encode(digest(string_agg(jsonb_build_array(id::text, country_code)::text, E'\n' order by id::text), 'sha256'), 'hex'),
    encode(digest(string_agg(jsonb_build_array(id::text, logo_url)::text, E'\n' order by id::text), 'sha256'), 'hex'),
    encode(digest(string_agg(jsonb_build_array(id::text, metadata)::text, E'\n' order by id::text), 'sha256'), 'hex'),
    encode(digest(string_agg(jsonb_build_array(id::text, home_group_code, home_macro_region)::text, E'\n' order by id::text), 'sha256'), 'hex'),
    encode(digest(string_agg(
      jsonb_build_array(
        id::text,
        case when id = '06feac4b-ab98-41ae-a005-defe191e48a6'::uuid then 'Deutsche Telecom' else name end
      )::text,
      E'\n' order by id::text
    ), 'sha256'), 'hex')
  into
    v_id_hash,
    v_country_hash,
    v_logo_hash,
    v_metadata_hash,
    v_geography_hash,
    v_source_equivalent_name_hash
  from public.sponsor_companies
  where sponsor_kind = 'main';

  if v_id_hash <> '298e72aae12f090f113b39f65e44e42c908bba4b9ffe5946084aa945c16688cb' then
    raise exception 'Main sponsor id hash mismatch: %.', v_id_hash;
  end if;
  if v_country_hash <> 'c2bf97ecbbe32071f5d717a5c2be30530b34fc46de5e19d12b69281d054ba83d' then
    raise exception 'Main sponsor country hash mismatch: %.', v_country_hash;
  end if;
  if v_logo_hash <> '46e357ee60e45e86715ed74e31ee56c15d5e6f6550671b82afd8ae44816c6f20' then
    raise exception 'Main sponsor logo hash mismatch: %.', v_logo_hash;
  end if;
  if v_metadata_hash <> '5ad973b5b308443346796014c992932466fec801b111de86a5902de89b64bcdd' then
    raise exception 'Main sponsor metadata hash mismatch: %.', v_metadata_hash;
  end if;
  if v_geography_hash <> '5dad53343c3f3c73c87ff7a8de368873ea1efb7ab6e217e40260fb18ede588d3' then
    raise exception 'Main sponsor geography hash mismatch: %.', v_geography_hash;
  end if;
  if v_source_equivalent_name_hash <> '62f6d31f700043689ecb1a0c94ac5d7e487afbc323c7cb30c4fb2e560268f3dc' then
    raise exception 'Main sponsor source-equivalent name hash mismatch: %.', v_source_equivalent_name_hash;
  end if;
end $$;

drop table if exists public._main_sponsor_import_staging_20260908;
