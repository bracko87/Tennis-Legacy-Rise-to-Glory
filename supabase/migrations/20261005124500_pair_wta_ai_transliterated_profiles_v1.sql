-- Pair five WTA AI players whose player names use native diacritics while
-- the uploaded portrait filenames use ASCII transliterations.
--
-- Elif Yilmaz.png and Elif Yilmaz (1).png are byte-identical in storage
-- (same eTag/size); use the canonical filename without the duplicate suffix.

with mappings(first_name,last_name,country_code,image_path) as (
  values
    ('Elīna','Ozoliņa','LV','WTA AI Profiles/Elina Ozolina.png'),
    ('Marta','Bērziņa','LV','WTA AI Profiles/Marta Berzina.png'),
    ('Jelena','Radović','ME','WTA AI Profiles/Jelena Radovic.png'),
    ('Elif','Yılmaz','TR','WTA AI Profiles/Elif Yilmaz.png'),
    ('Selin','Aydın','TR','WTA AI Profiles/Selin Aydin.png')
),
validated as (
  select
    p.id,
    m.image_path
  from mappings m
  join public.players p
    on p.world='WTA'
   and p.player_type='ai'
   and p.first_name=m.first_name
   and p.last_name=m.last_name
   and p.country_code=m.country_code
  where exists (
    select 1
    from storage.objects o
    where o.bucket_id='Admin'
      and o.name=m.image_path
  )
)
update public.players p
set image_path=v.image_path,
    updated_at=now()
from validated v
where p.id=v.id;

do $$
declare
  v_mapped integer;
  v_missing integer;
begin
  select count(*) into v_mapped
  from public.players
  where world='WTA'
    and player_type='ai'
    and (
      (first_name='Elīna' and last_name='Ozoliņa' and image_path='WTA AI Profiles/Elina Ozolina.png')
      or (first_name='Marta' and last_name='Bērziņa' and image_path='WTA AI Profiles/Marta Berzina.png')
      or (first_name='Jelena' and last_name='Radović' and image_path='WTA AI Profiles/Jelena Radovic.png')
      or (first_name='Elif' and last_name='Yılmaz' and image_path='WTA AI Profiles/Elif Yilmaz.png')
      or (first_name='Selin' and last_name='Aydın' and image_path='WTA AI Profiles/Selin Aydin.png')
    );

  select count(*) into v_missing
  from public.players p
  where p.world='WTA'
    and p.player_type='ai'
    and p.image_path in (
      'WTA AI Profiles/Elina Ozolina.png',
      'WTA AI Profiles/Marta Berzina.png',
      'WTA AI Profiles/Jelena Radovic.png',
      'WTA AI Profiles/Elif Yilmaz.png',
      'WTA AI Profiles/Selin Aydin.png'
    )
    and not exists (
      select 1
      from storage.objects o
      where o.bucket_id='Admin'
        and o.name=p.image_path
    );

  if v_mapped<>5 then
    raise exception 'Expected 5 WTA AI portrait mappings, got %.',v_mapped;
  end if;

  if v_missing<>0 then
    raise exception 'Mapped WTA AI portrait objects missing from storage: %.',v_missing;
  end if;
end;
$$;

select public.check_wta_ai_portrait_health_v1();
