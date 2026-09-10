do $$
declare
  v_player_matches integer;
  v_storage_matches integer;
begin
  with avatar_map(first_name,last_name,image_path) as (
    values
    ('Andres','Ospina','ATP AI Profils/Andres Ospina.png'),
    ('Arjun','Kapoor','ATP AI Profils/Arjun Kapoor.png'),
    ('Aziz','Rakhimov','ATP AI Profils/Aziz Rakhimov.png'),
    ('Bekzat','Omarov','ATP AI Profils/Bekzat Omarov.png'),
    ('Chaiwat','Sukjai','ATP AI Profils/Chaiwat Sukjai (1).png'),
    ('Cooper','Bennett','ATP AI Profils/Cooper Bennett.png'),
    ('Davide','Conti','ATP AI Profils/Davide Conti.png'),
    ('Domagoj','Bozic','ATP AI Profils/Domagoj Bozic.png'),
    ('Fabian','Ammann','ATP AI Profils/Fabian Ammann.png'),
    ('Facundo','Cabrera','ATP AI Profils/Facundo Cabrera.png'),
    ('Felix','Kruger','ATP AI Profils/Felix Kruger.png'),
    ('Filip','Cerny','ATP AI Profils/Filip Cerny.png'),
    ('Frederik','Nielsen','ATP AI Profils/Frederik Nielsen.png'),
    ('Hugo','Cabrera','ATP AI Profils/Hugo Cabrera.png'),
    ('Ivan','Vukelic','ATP AI Profils/Ivan Vukelic.png'),
    ('Jakub','Prochazka','ATP AI Profils/Jakub Prochazka.png'),
    ('Jasur','Tursunov','ATP AI Profils/Jasur Tursunov (1).png'),
    ('Juho','Lehtinen','ATP AI Profils/Juho Lehtinen.png'),
    ('Levente','Farkas','ATP AI Profils/Levente Farkas.png'),
    ('Logan','Taylor','ATP AI Profils/Logan Taylor.png'),
    ('Luka','Horvat','ATP AI Profils/Luka Horvat.png'),
    ('Lukas','Keller','ATP AI Profils/Lukas Keller.png'),
    ('Magnus','Hansen','ATP AI Profils/Magnus Hansen.png'),
    ('Marko','Nikolic','ATP AI Profils/Marko Nikolic.png'),
    ('Mate','Nagy','ATP AI Profils/Mate Nagy.png'),
    ('Matteo','Greco','ATP AI Profils/Matteo Greco.png'),
    ('Matteo','Lombardi','ATP AI Profils/Matteo Lombardi.png'),
    ('Mehdi','Mansouri','ATP AI Profils/Mehdi Mansouri.png'),
    ('Michal','Krawczyk','ATP AI Profils/Michal Krawczyk.png'),
    ('Ming','Wu','ATP AI Profils/Ming Wu.png'),
    ('Narin','Chantarangsu','ATP AI Profils/Narin Chantarangsu.png'),
    ('Nathan','Campbell','ATP AI Profils/Nathan Campbell.png'),
    ('Nejc','Zupan','ATP AI Profils/Nejc Zupan.png'),
    ('Nico','Frei','ATP AI Profils/Nico Frei.png'),
    ('Nicolas','Cardenas','ATP AI Profils/Nicolas Cardenas.png'),
    ('Nicolas','Ibarra','ATP AI Profils/Nicolas Ibarra.png'),
    ('Nicolas','Silva','ATP AI Profils/Nicolas Silva.png'),
    ('Nicolas','Sosa','ATP AI Profils/Nicolas Sosa.png'),
    ('Nicolo','Lombardi','ATP AI Profils/Nicolo Lombardi.png'),
    ('Rafael','Rocha','ATP AI Profils/Rafael Rocha.png'),
    ('Riccardo','Ferrari','ATP AI Profils/Riccardo Ferrari.png'),
    ('Rohan','Iyer','ATP AI Profils/Rohan Iyer.png'),
    ('Santiago','Cortes','ATP AI Profils/Santiago Cortes.png'),
    ('Santiago','Salazar','ATP AI Profils/Santiago Salazar.png'),
    ('Simon','Moser','ATP AI Profils/Simon Moser.png'),
    ('Tiago','Pinto','ATP AI Profils/Tiago Pinto.png'),
    ('Tobias','Vogel','ATP AI Profils/Tobias Vogel.png'),
    ('Victor','Kiptoo','ATP AI Profils/Victor Kiptoo.png'),
    ('Wei','Xu','ATP AI Profils/Wei Xu.png'),
    ('Zan','Novak','ATP AI Profils/Zan Novak.png')
  )
  select count(*) into v_player_matches
  from avatar_map m
  join public.players p
    on p.first_name=m.first_name
   and p.last_name=m.last_name
   and p.world='ATP'
   and p.player_type='ai';

  if v_player_matches <> 50 then
    raise exception 'Expected exactly 50 ATP AI player matches, found %', v_player_matches;
  end if;

  with avatar_map(image_path) as (
    values
    ('ATP AI Profils/Andres Ospina.png'),
    ('ATP AI Profils/Arjun Kapoor.png'),
    ('ATP AI Profils/Aziz Rakhimov.png'),
    ('ATP AI Profils/Bekzat Omarov.png'),
    ('ATP AI Profils/Chaiwat Sukjai (1).png'),
    ('ATP AI Profils/Cooper Bennett.png'),
    ('ATP AI Profils/Davide Conti.png'),
    ('ATP AI Profils/Domagoj Bozic.png'),
    ('ATP AI Profils/Fabian Ammann.png'),
    ('ATP AI Profils/Facundo Cabrera.png'),
    ('ATP AI Profils/Felix Kruger.png'),
    ('ATP AI Profils/Filip Cerny.png'),
    ('ATP AI Profils/Frederik Nielsen.png'),
    ('ATP AI Profils/Hugo Cabrera.png'),
    ('ATP AI Profils/Ivan Vukelic.png'),
    ('ATP AI Profils/Jakub Prochazka.png'),
    ('ATP AI Profils/Jasur Tursunov (1).png'),
    ('ATP AI Profils/Juho Lehtinen.png'),
    ('ATP AI Profils/Levente Farkas.png'),
    ('ATP AI Profils/Logan Taylor.png'),
    ('ATP AI Profils/Luka Horvat.png'),
    ('ATP AI Profils/Lukas Keller.png'),
    ('ATP AI Profils/Magnus Hansen.png'),
    ('ATP AI Profils/Marko Nikolic.png'),
    ('ATP AI Profils/Mate Nagy.png'),
    ('ATP AI Profils/Matteo Greco.png'),
    ('ATP AI Profils/Matteo Lombardi.png'),
    ('ATP AI Profils/Mehdi Mansouri.png'),
    ('ATP AI Profils/Michal Krawczyk.png'),
    ('ATP AI Profils/Ming Wu.png'),
    ('ATP AI Profils/Narin Chantarangsu.png'),
    ('ATP AI Profils/Nathan Campbell.png'),
    ('ATP AI Profils/Nejc Zupan.png'),
    ('ATP AI Profils/Nico Frei.png'),
    ('ATP AI Profils/Nicolas Cardenas.png'),
    ('ATP AI Profils/Nicolas Ibarra.png'),
    ('ATP AI Profils/Nicolas Silva.png'),
    ('ATP AI Profils/Nicolas Sosa.png'),
    ('ATP AI Profils/Nicolo Lombardi.png'),
    ('ATP AI Profils/Rafael Rocha.png'),
    ('ATP AI Profils/Riccardo Ferrari.png'),
    ('ATP AI Profils/Rohan Iyer.png'),
    ('ATP AI Profils/Santiago Cortes.png'),
    ('ATP AI Profils/Santiago Salazar.png'),
    ('ATP AI Profils/Simon Moser.png'),
    ('ATP AI Profils/Tiago Pinto.png'),
    ('ATP AI Profils/Tobias Vogel.png'),
    ('ATP AI Profils/Victor Kiptoo.png'),
    ('ATP AI Profils/Wei Xu.png'),
    ('ATP AI Profils/Zan Novak.png')
  )
  select count(*) into v_storage_matches
  from avatar_map m
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name=m.image_path;

  if v_storage_matches <> 50 then
    raise exception 'Expected exactly 50 avatar storage objects, found %', v_storage_matches;
  end if;
end $$;

with avatar_map(first_name,last_name,image_path) as (
  values
  ('Andres','Ospina','ATP AI Profils/Andres Ospina.png'),
    ('Arjun','Kapoor','ATP AI Profils/Arjun Kapoor.png'),
    ('Aziz','Rakhimov','ATP AI Profils/Aziz Rakhimov.png'),
    ('Bekzat','Omarov','ATP AI Profils/Bekzat Omarov.png'),
    ('Chaiwat','Sukjai','ATP AI Profils/Chaiwat Sukjai (1).png'),
    ('Cooper','Bennett','ATP AI Profils/Cooper Bennett.png'),
    ('Davide','Conti','ATP AI Profils/Davide Conti.png'),
    ('Domagoj','Bozic','ATP AI Profils/Domagoj Bozic.png'),
    ('Fabian','Ammann','ATP AI Profils/Fabian Ammann.png'),
    ('Facundo','Cabrera','ATP AI Profils/Facundo Cabrera.png'),
    ('Felix','Kruger','ATP AI Profils/Felix Kruger.png'),
    ('Filip','Cerny','ATP AI Profils/Filip Cerny.png'),
    ('Frederik','Nielsen','ATP AI Profils/Frederik Nielsen.png'),
    ('Hugo','Cabrera','ATP AI Profils/Hugo Cabrera.png'),
    ('Ivan','Vukelic','ATP AI Profils/Ivan Vukelic.png'),
    ('Jakub','Prochazka','ATP AI Profils/Jakub Prochazka.png'),
    ('Jasur','Tursunov','ATP AI Profils/Jasur Tursunov (1).png'),
    ('Juho','Lehtinen','ATP AI Profils/Juho Lehtinen.png'),
    ('Levente','Farkas','ATP AI Profils/Levente Farkas.png'),
    ('Logan','Taylor','ATP AI Profils/Logan Taylor.png'),
    ('Luka','Horvat','ATP AI Profils/Luka Horvat.png'),
    ('Lukas','Keller','ATP AI Profils/Lukas Keller.png'),
    ('Magnus','Hansen','ATP AI Profils/Magnus Hansen.png'),
    ('Marko','Nikolic','ATP AI Profils/Marko Nikolic.png'),
    ('Mate','Nagy','ATP AI Profils/Mate Nagy.png'),
    ('Matteo','Greco','ATP AI Profils/Matteo Greco.png'),
    ('Matteo','Lombardi','ATP AI Profils/Matteo Lombardi.png'),
    ('Mehdi','Mansouri','ATP AI Profils/Mehdi Mansouri.png'),
    ('Michal','Krawczyk','ATP AI Profils/Michal Krawczyk.png'),
    ('Ming','Wu','ATP AI Profils/Ming Wu.png'),
    ('Narin','Chantarangsu','ATP AI Profils/Narin Chantarangsu.png'),
    ('Nathan','Campbell','ATP AI Profils/Nathan Campbell.png'),
    ('Nejc','Zupan','ATP AI Profils/Nejc Zupan.png'),
    ('Nico','Frei','ATP AI Profils/Nico Frei.png'),
    ('Nicolas','Cardenas','ATP AI Profils/Nicolas Cardenas.png'),
    ('Nicolas','Ibarra','ATP AI Profils/Nicolas Ibarra.png'),
    ('Nicolas','Silva','ATP AI Profils/Nicolas Silva.png'),
    ('Nicolas','Sosa','ATP AI Profils/Nicolas Sosa.png'),
    ('Nicolo','Lombardi','ATP AI Profils/Nicolo Lombardi.png'),
    ('Rafael','Rocha','ATP AI Profils/Rafael Rocha.png'),
    ('Riccardo','Ferrari','ATP AI Profils/Riccardo Ferrari.png'),
    ('Rohan','Iyer','ATP AI Profils/Rohan Iyer.png'),
    ('Santiago','Cortes','ATP AI Profils/Santiago Cortes.png'),
    ('Santiago','Salazar','ATP AI Profils/Santiago Salazar.png'),
    ('Simon','Moser','ATP AI Profils/Simon Moser.png'),
    ('Tiago','Pinto','ATP AI Profils/Tiago Pinto.png'),
    ('Tobias','Vogel','ATP AI Profils/Tobias Vogel.png'),
    ('Victor','Kiptoo','ATP AI Profils/Victor Kiptoo.png'),
    ('Wei','Xu','ATP AI Profils/Wei Xu.png'),
    ('Zan','Novak','ATP AI Profils/Zan Novak.png')
)
update public.players p
set image_path=m.image_path,
    updated_at=now()
from avatar_map m
where p.first_name=m.first_name
  and p.last_name=m.last_name
  and p.world='ATP'
  and p.player_type='ai';
