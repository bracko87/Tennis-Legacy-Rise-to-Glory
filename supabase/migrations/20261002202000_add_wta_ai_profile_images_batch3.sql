-- Add WTA AI profile portraits batch 3 (#61-#80).
-- Source images were verified in Admin/WTA AI Profiles and copied into
-- Admin/WTA Avatars before mapping.
-- Exact player identity is matched by name + country + WTA AI status.

with portraits(first_name,last_name,country_code,image_path) as (
  values
  ('Yui','Fujita','JP','WTA Avatars/Yui Fujita.png'),
  ('Dzejla','Basic','BA','WTA Avatars/Dzejla Basic.png'),
  ('Camila','Sepulveda','CL','WTA Avatars/Camila Sepulveda.png'),
  ('Larissa','Teixeira','BR','WTA Avatars/Larissa Teixeira.png'),
  ('Mariam','Al Falasi','AE','WTA Avatars/Mariam Al Falasi.png'),
  ('Manon','Peeters','BE','WTA Avatars/Manon Peeters.png'),
  ('Sofia','Mendez','UY','WTA Avatars/Sofia Mendez.png'),
  ('Megan','Hughes','GB','WTA Avatars/Megan Hughes.png'),
  ('Mariana','Castillo','MX','WTA Avatars/Mariana Castillo.png'),
  ('Anna','Cerny','CZ','WTA Avatars/Anna Cerny.png'),
  ('Louise','Willems','BE','WTA Avatars/Louise Willems.png'),
  ('Lucija','Vukelic','HR','WTA Avatars/Lucija Vukelic.png'),
  ('Ella','Thompson','NZ','WTA Avatars/Ella Thompson.png'),
  ('Ines','Coelho','PT','WTA Avatars/Ines Coelho.png'),
  ('Alessia','Conti','IT','WTA Avatars/Alessia Conti.png'),
  ('Lucie','Dvorak','CZ','WTA Avatars/Lucie Dvorak.png'),
  ('Emma','De Smet','BE','WTA Avatars/Emma De Smet.png'),
  ('Maria','Lazaridis','GR','WTA Avatars/Maria Lazaridis.png'),
  ('Chloe','Campbell','CA','WTA Avatars/Chloe Campbell.png'),
  ('Katarina','Novak','SK','WTA Avatars/Katarina Novak.png')
),
validated as (
  select p.id,x.image_path
  from portraits x
  join public.players p
    on p.first_name=x.first_name
   and p.last_name=x.last_name
   and p.country_code=x.country_code
   and p.world='WTA'
   and p.player_type='ai'
  where exists(
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
  select count(*) into v_count
  from public.players p
  join (
    values
    ('Yui','Fujita','JP','WTA Avatars/Yui Fujita.png'),
  ('Dzejla','Basic','BA','WTA Avatars/Dzejla Basic.png'),
  ('Camila','Sepulveda','CL','WTA Avatars/Camila Sepulveda.png'),
  ('Larissa','Teixeira','BR','WTA Avatars/Larissa Teixeira.png'),
  ('Mariam','Al Falasi','AE','WTA Avatars/Mariam Al Falasi.png'),
  ('Manon','Peeters','BE','WTA Avatars/Manon Peeters.png'),
  ('Sofia','Mendez','UY','WTA Avatars/Sofia Mendez.png'),
  ('Megan','Hughes','GB','WTA Avatars/Megan Hughes.png'),
  ('Mariana','Castillo','MX','WTA Avatars/Mariana Castillo.png'),
  ('Anna','Cerny','CZ','WTA Avatars/Anna Cerny.png'),
  ('Louise','Willems','BE','WTA Avatars/Louise Willems.png'),
  ('Lucija','Vukelic','HR','WTA Avatars/Lucija Vukelic.png'),
  ('Ella','Thompson','NZ','WTA Avatars/Ella Thompson.png'),
  ('Ines','Coelho','PT','WTA Avatars/Ines Coelho.png'),
  ('Alessia','Conti','IT','WTA Avatars/Alessia Conti.png'),
  ('Lucie','Dvorak','CZ','WTA Avatars/Lucie Dvorak.png'),
  ('Emma','De Smet','BE','WTA Avatars/Emma De Smet.png'),
  ('Maria','Lazaridis','GR','WTA Avatars/Maria Lazaridis.png'),
  ('Chloe','Campbell','CA','WTA Avatars/Chloe Campbell.png'),
  ('Katarina','Novak','SK','WTA Avatars/Katarina Novak.png')
  ) as x(first_name,last_name,country_code,image_path)
    on p.first_name=x.first_name
   and p.last_name=x.last_name
   and p.country_code=x.country_code
   and p.world='WTA'
   and p.player_type='ai'
   and p.image_path=x.image_path
  where exists(
    select 1
    from storage.objects o
    where o.bucket_id='Admin'
      and o.name=p.image_path
  );

  if v_count<>20 then
    raise exception 'Expected 20 WTA AI portraits after batch 3 update, found %.',v_count;
  end if;
end;
$$;

select public.check_wta_ai_portrait_health_v1();
