do $$
begin
  update public.sponsor_companies
  set name = 'Deutsche Telecom',
      updated_at = now()
  where id = '06feac4b-ab98-41ae-a005-defe191e48a6'::uuid
    and sponsor_kind = 'main';

  if not found then
    raise exception 'Expected Deutsche Telecom sponsor row was not found';
  end if;
end $$;