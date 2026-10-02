-- Assign approved WTA AI profile portraits stored in the private Admin bucket.
-- Store stable bucket-relative object paths rather than long-lived signed URLs.
-- The frontend generates fresh authenticated signed URLs at render time.

with portraits(player_id, expected_country, image_path) as (
  values
  ('90f09c40-af0f-488e-91ed-6cd3cc251621'::uuid, 'BA', 'WTA AI Profiles/Lejla Hadzic.png'),
  ('d44d8e02-fa1a-4686-8852-d0f2e0157a38'::uuid, 'GB', 'WTA AI Profiles/Lucy Coleman.png'),
  ('4320c3d9-f92f-4754-b6c6-0d906424606b'::uuid, 'NO', 'WTA AI Profiles/Nora Solberg.png'),
  ('f2479b22-d405-49f1-aa25-9f56fd9fd435'::uuid, 'NL', 'WTA AI Profiles/Sanne van Dijk.png'),
  ('86fb317a-dd65-410c-8a4f-fffcd11d7344'::uuid, 'AU', 'WTA AI Profiles/Brooke Lawson.png'),
  ('b664128a-a6e8-4700-87ce-9eace564460c'::uuid, 'FR', 'WTA AI Profiles/Camille Lefevre.png'),
  ('766071c5-de47-42a5-b108-77a020110cce'::uuid, 'RO', 'WTA AI Profiles/Ioana Popescu.png'),
  ('fa17d9df-c2e8-46bb-a8cc-c87972407621'::uuid, 'BR', 'WTA AI Profiles/Camila Moura.png'),
  ('0fcf3659-f882-4e64-b7ff-32ccebb68ee5'::uuid, 'FR', 'WTA AI Profiles/Manon Mercier.png'),
  ('39a60500-c14c-48b1-8db7-937d715e1bcf'::uuid, 'AR', 'WTA AI Profiles/Lucia Acosta.png'),
  ('bdf84f73-3bdf-4c7d-9af4-c37ff9164b26'::uuid, 'JP', 'WTA AI Profiles/Mio Okada.png'),
  ('8c764e4c-f941-4c1f-82db-336744e0e773'::uuid, 'AT', 'WTA AI Profiles/Laura Steiner.png'),
  ('f26c7e83-b114-480a-94e1-bd4b393d6063'::uuid, 'GB', 'WTA AI Profiles/Hannah Palmer.png'),
  ('1a441420-9ef9-45ad-ab53-389d34795939'::uuid, 'US', 'WTA AI Profiles/Natalie Sullivan.png'),
  ('dd8a505c-251b-4007-8558-8990c1602392'::uuid, 'CA', 'WTA AI Profiles/Sophie Lavoie.png'),
  ('6136dbc1-31c3-48d4-9f7a-64d83a8be44e'::uuid, 'US', 'WTA AI Profiles/Brooke Foster.png'),
  ('d96f31e4-61d6-4124-bcff-0f06d659f7be'::uuid, 'GR', 'WTA AI Profiles/Eleni Karalis.png'),
  ('5f03b1b0-4119-47c9-8700-c14d6d08c9fd'::uuid, 'IT', 'WTA AI Profiles/Martina Lombardi.png'),
  ('20a612f4-5e01-4aec-8294-aead7193e173'::uuid, 'FR', 'WTA AI Profiles/Manon Garnier.png')
),
validated as (
  select p.id, x.image_path
  from portraits x
  join public.players p on p.id=x.player_id
  where p.world='WTA'
    and p.player_type='ai'
    and p.country_code=x.expected_country
    and exists (
      select 1
      from storage.objects o
      where o.bucket_id='Admin'
        and o.name=x.image_path
    )
)
update public.players p
set image_path=v.image_path,
    updated_at=now()
from validated v
where p.id=v.id;

do $$
declare
  v_count integer;
begin
  select count(*)
  into v_count
  from public.players p
  where p.id=any(array[
    '90f09c40-af0f-488e-91ed-6cd3cc251621'::uuid,
    'd44d8e02-fa1a-4686-8852-d0f2e0157a38'::uuid,
    '4320c3d9-f92f-4754-b6c6-0d906424606b'::uuid,
    'f2479b22-d405-49f1-aa25-9f56fd9fd435'::uuid,
    '86fb317a-dd65-410c-8a4f-fffcd11d7344'::uuid,
    'b664128a-a6e8-4700-87ce-9eace564460c'::uuid,
    '766071c5-de47-42a5-b108-77a020110cce'::uuid,
    'fa17d9df-c2e8-46bb-a8cc-c87972407621'::uuid,
    '0fcf3659-f882-4e64-b7ff-32ccebb68ee5'::uuid,
    '39a60500-c14c-48b1-8db7-937d715e1bcf'::uuid,
    'bdf84f73-3bdf-4c7d-9af4-c37ff9164b26'::uuid,
    '8c764e4c-f941-4c1f-82db-336744e0e773'::uuid,
    'f26c7e83-b114-480a-94e1-bd4b393d6063'::uuid,
    '1a441420-9ef9-45ad-ab53-389d34795939'::uuid,
    'dd8a505c-251b-4007-8558-8990c1602392'::uuid,
    '6136dbc1-31c3-48d4-9f7a-64d83a8be44e'::uuid,
    'd96f31e4-61d6-4124-bcff-0f06d659f7be'::uuid,
    '5f03b1b0-4119-47c9-8700-c14d6d08c9fd'::uuid,
    '20a612f4-5e01-4aec-8294-aead7193e173'::uuid
  ])
    and p.world='WTA'
    and p.player_type='ai'
    and p.image_path like 'WTA AI Profiles/%';

  if v_count<>19 then
    raise exception 'Expected 19 WTA AI portraits after update, found %.',v_count;
  end if;
end;
$$;
