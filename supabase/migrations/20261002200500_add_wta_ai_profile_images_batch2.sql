-- Add WTA AI profile portraits batch 2.
-- Source images were supplied in Admin/WTA AI Profiles and copied into the
-- already-supported Admin/WTA Avatars folder before player mapping.
-- Exact player identity is verified by name + country + WTA AI status.

with portraits(first_name,last_name,country_code,image_path) as (
  values
  ('Katarina','Petrovic','RS','WTA Avatars/Katarina Petrovic.png'),
  ('Irene','Ortega','ES','WTA Avatars/Irene Ortega.png'),
  ('Milica','Nikolic','RS','WTA Avatars/Milica Nikolic.png'),
  ('Luciana','Rojas','PE','WTA Avatars/Luciana Rojas.png'),
  ('Petra','Juric','HR','WTA Avatars/Petra Juric.png'),
  ('Mara','Kruger','DE','WTA Avatars/Mara Kruger.png'),
  ('Pimchanok','Chantarangsu','TH','WTA Avatars/Pimchanok Chantarangsu.png'),
  ('Martina','Romano','IT','WTA Avatars/Martina Romano.png'),
  ('Barbora','Kucera','CZ','WTA Avatars/Barbora Kucera.png'),
  ('Avery','Carter','US','WTA Avatars/Avery Carter.png'),
  ('Tahlia','Fletcher','AU','WTA Avatars/Tahlia Fletcher.png'),
  ('Ana','Maric','HR','WTA Avatars/Ana Maric.png'),
  ('Madison','Mitchell','US','WTA Avatars/Madison Mitchell.png'),
  ('Natalie','Mitchell','US','WTA Avatars/Natalie Mitchell.png'),
  ('Leonie','Neumann','DE','WTA Avatars/Leonie Neumann.png'),
  ('Gabriela','Salazar','CO','WTA Avatars/Gabriela Salazar.png'),
  ('Theresa','Eder','AT','WTA Avatars/Theresa Eder.png'),
  ('Alejandra','Quispe','PE','WTA Avatars/Alejandra Quispe.png'),
  ('Freja','Berg','DK','WTA Avatars/Freja Berg.png'),
  ('Daniela','Mendoza','MX','WTA Avatars/Daniela Mendoza.png'),
  ('Beatriz','Azevedo','BR','WTA Avatars/Beatriz Azevedo.png'),
  ('Tereza','Vesely','CZ','WTA Avatars/Tereza Vesely.png'),
  ('Nika','Kovacevic','HR','WTA Avatars/Nika Kovacevic.png'),
  ('Luca','Farkas','HU','WTA Avatars/Luca Farkas.png'),
  ('Madison','Hughes','US','WTA Avatars/Madison Hughes.png'),
  ('Chiara','Greco','IT','WTA Avatars/Chiara Greco.png'),
  ('Weronika','Zielinski','PL','WTA Avatars/Weronika Zielinski.png'),
  ('Tereza','Prochazka','CZ','WTA Avatars/Tereza Prochazka.png'),
  ('Marta','Horvat','HR','WTA Avatars/Marta Horvat.png'),
  ('Julia','Rocha','BR','WTA Avatars/Julia Rocha.png'),
  ('Jovana','Ilic','RS','WTA Avatars/Jovana Ilic.png'),
  ('Sofia','Vlachos','GR','WTA Avatars/Sofia Vlachos.png'),
  ('Lili','Huang','CN','WTA Avatars/Lili Huang.png'),
  ('Georgia','Harris','AU','WTA Avatars/Georgia Harris.png'),
  ('Tina','Kranjc','SI','WTA Avatars/Tina Kranjc.png'),
  ('Katerina','Horak','CZ','WTA Avatars/Katerina Horak.png'),
  ('Amna','Al Mazrouei','AE','WTA Avatars/Amna Al Mazrouei.png'),
  ('Claudia','Soler','ES','WTA Avatars/Claudia Soler.png'),
  ('Aruzhan','Akhmetov','KZ','WTA Avatars/Aruzhan Akhmetov.png'),
  ('Camille','Dumont','FR','WTA Avatars/Camille Dumont.png')
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
    ('Katarina','Petrovic','RS','WTA Avatars/Katarina Petrovic.png'),
  ('Irene','Ortega','ES','WTA Avatars/Irene Ortega.png'),
  ('Milica','Nikolic','RS','WTA Avatars/Milica Nikolic.png'),
  ('Luciana','Rojas','PE','WTA Avatars/Luciana Rojas.png'),
  ('Petra','Juric','HR','WTA Avatars/Petra Juric.png'),
  ('Mara','Kruger','DE','WTA Avatars/Mara Kruger.png'),
  ('Pimchanok','Chantarangsu','TH','WTA Avatars/Pimchanok Chantarangsu.png'),
  ('Martina','Romano','IT','WTA Avatars/Martina Romano.png'),
  ('Barbora','Kucera','CZ','WTA Avatars/Barbora Kucera.png'),
  ('Avery','Carter','US','WTA Avatars/Avery Carter.png'),
  ('Tahlia','Fletcher','AU','WTA Avatars/Tahlia Fletcher.png'),
  ('Ana','Maric','HR','WTA Avatars/Ana Maric.png'),
  ('Madison','Mitchell','US','WTA Avatars/Madison Mitchell.png'),
  ('Natalie','Mitchell','US','WTA Avatars/Natalie Mitchell.png'),
  ('Leonie','Neumann','DE','WTA Avatars/Leonie Neumann.png'),
  ('Gabriela','Salazar','CO','WTA Avatars/Gabriela Salazar.png'),
  ('Theresa','Eder','AT','WTA Avatars/Theresa Eder.png'),
  ('Alejandra','Quispe','PE','WTA Avatars/Alejandra Quispe.png'),
  ('Freja','Berg','DK','WTA Avatars/Freja Berg.png'),
  ('Daniela','Mendoza','MX','WTA Avatars/Daniela Mendoza.png'),
  ('Beatriz','Azevedo','BR','WTA Avatars/Beatriz Azevedo.png'),
  ('Tereza','Vesely','CZ','WTA Avatars/Tereza Vesely.png'),
  ('Nika','Kovacevic','HR','WTA Avatars/Nika Kovacevic.png'),
  ('Luca','Farkas','HU','WTA Avatars/Luca Farkas.png'),
  ('Madison','Hughes','US','WTA Avatars/Madison Hughes.png'),
  ('Chiara','Greco','IT','WTA Avatars/Chiara Greco.png'),
  ('Weronika','Zielinski','PL','WTA Avatars/Weronika Zielinski.png'),
  ('Tereza','Prochazka','CZ','WTA Avatars/Tereza Prochazka.png'),
  ('Marta','Horvat','HR','WTA Avatars/Marta Horvat.png'),
  ('Julia','Rocha','BR','WTA Avatars/Julia Rocha.png'),
  ('Jovana','Ilic','RS','WTA Avatars/Jovana Ilic.png'),
  ('Sofia','Vlachos','GR','WTA Avatars/Sofia Vlachos.png'),
  ('Lili','Huang','CN','WTA Avatars/Lili Huang.png'),
  ('Georgia','Harris','AU','WTA Avatars/Georgia Harris.png'),
  ('Tina','Kranjc','SI','WTA Avatars/Tina Kranjc.png'),
  ('Katerina','Horak','CZ','WTA Avatars/Katerina Horak.png'),
  ('Amna','Al Mazrouei','AE','WTA Avatars/Amna Al Mazrouei.png'),
  ('Claudia','Soler','ES','WTA Avatars/Claudia Soler.png'),
  ('Aruzhan','Akhmetov','KZ','WTA Avatars/Aruzhan Akhmetov.png'),
  ('Camille','Dumont','FR','WTA Avatars/Camille Dumont.png')
  ) as x(first_name,last_name,country_code,image_path)
    on p.first_name=x.first_name
   and p.last_name=x.last_name
   and p.country_code=x.country_code
   and p.world='WTA'
   and p.player_type='ai'
   and p.image_path=x.image_path
  where exists(
    select 1 from storage.objects o
    where o.bucket_id='Admin' and o.name=p.image_path
  );

  if v_count<>40 then
    raise exception 'Expected 40 WTA AI portraits after batch 2 update, found %.',v_count;
  end if;
end;
$$;

select public.check_wta_ai_portrait_health_v1();
