do $$
declare
  v_player_matches integer;
  v_storage_matches integer;
begin
  with avatar_map(first_name,last_name,image_path) as (
    values
      ('Adrian','Carter','ATP AI Profils/Adrian Carter.png'),
      ('Andre','Correia','ATP AI Profils/Andre Correia.png'),
      ('Ayan','Nurgaliyev','ATP AI Profils/Ayan Nurgaliyev.png'),
      ('Bastien','Chevalier','ATP AI Profils/Bastien Chevalier.png'),
      ('Caleb','Bennett','ATP AI Profils/Caleb Bennett.png'),
      ('Chinedu','Adebayo','ATP AI Profils/Chinedu Adebayo.png'),
      ('David','Horak','ATP AI Profils/David Horak.png'),
      ('David','Horvath','ATP AI Profils/David Horvath.png'),
      ('Diego','Vidal','ATP AI Profils/Diego Vidal.png'),
      ('Gabriel','Teixeira','ATP AI Profils/Gabriel Teixeira.png'),
      ('Haruto','Kondo','ATP AI Profils/Haruto Kondo.png'),
      ('Jakub','Dvorak','ATP AI Profils/Jakub Dvorak.png'),
      ('Jure','Mlakar','ATP AI Profils/Jure Mlakar.png'),
      ('Kittipong','Kittisak','ATP AI Profils/Kittipong Kittisak.png'),
      ('Lachlan','Harris','ATP AI Profils/Lachlan Harris.png'),
      ('Lewis','Walsh','ATP AI Profils/Lewis Walsh.png'),
      ('Liam','Gagnon','ATP AI Profils/Liam Gagnon.png'),
      ('Linus','Holm','ATP AI Profils/Linus Holm.png'),
      ('Louis','Claes','ATP AI Profils/Louis Claes.png'),
      ('Lucas','Moreau','ATP AI Profils/Lucas Moreau.png'),
      ('Marius','Solberg','ATP AI Profils/Marius Solberg.png'),
      ('Mateo','Salazar','ATP AI Profils/Mateo Salazar.png'),
      ('Nemanja','Nikolic','ATP AI Profils/Nemanja Nikolic.png'),
      ('Nicolo','Romano','ATP AI Profils/Nicolo Romano.png'),
      ('Nikolay','Georgiev','ATP AI Profils/Nikolay Georgiev.png'),
      ('Ondrej','Vesely','ATP AI Profils/Ondrej Vesely.png'),
      ('Oskari','Salonen','ATP AI Profils/Oskari Salonen.png'),
      ('Taeyang','Kim','ATP AI Profils/Taeyang Kim.png'),
      ('Tomas','Kovac','ATP AI Profils/Tomas Kovac.png'),
      ('Victor','De Smet','ATP AI Profils/Victor De Smet.png')
  )
  select count(*) into v_player_matches
  from avatar_map m
  join public.players p
    on p.first_name=m.first_name
   and p.last_name=m.last_name
   and p.world='ATP'
   and p.player_type='ai';

  if v_player_matches <> 30 then
    raise exception 'Expected exactly 30 ATP AI player matches, found %', v_player_matches;
  end if;

  with avatar_map(image_path) as (
    values
      ('ATP AI Profils/Adrian Carter.png'),
      ('ATP AI Profils/Andre Correia.png'),
      ('ATP AI Profils/Ayan Nurgaliyev.png'),
      ('ATP AI Profils/Bastien Chevalier.png'),
      ('ATP AI Profils/Caleb Bennett.png'),
      ('ATP AI Profils/Chinedu Adebayo.png'),
      ('ATP AI Profils/David Horak.png'),
      ('ATP AI Profils/David Horvath.png'),
      ('ATP AI Profils/Diego Vidal.png'),
      ('ATP AI Profils/Gabriel Teixeira.png'),
      ('ATP AI Profils/Haruto Kondo.png'),
      ('ATP AI Profils/Jakub Dvorak.png'),
      ('ATP AI Profils/Jure Mlakar.png'),
      ('ATP AI Profils/Kittipong Kittisak.png'),
      ('ATP AI Profils/Lachlan Harris.png'),
      ('ATP AI Profils/Lewis Walsh.png'),
      ('ATP AI Profils/Liam Gagnon.png'),
      ('ATP AI Profils/Linus Holm.png'),
      ('ATP AI Profils/Louis Claes.png'),
      ('ATP AI Profils/Lucas Moreau.png'),
      ('ATP AI Profils/Marius Solberg.png'),
      ('ATP AI Profils/Mateo Salazar.png'),
      ('ATP AI Profils/Nemanja Nikolic.png'),
      ('ATP AI Profils/Nicolo Romano.png'),
      ('ATP AI Profils/Nikolay Georgiev.png'),
      ('ATP AI Profils/Ondrej Vesely.png'),
      ('ATP AI Profils/Oskari Salonen.png'),
      ('ATP AI Profils/Taeyang Kim.png'),
      ('ATP AI Profils/Tomas Kovac.png'),
      ('ATP AI Profils/Victor De Smet.png')
  )
  select count(*) into v_storage_matches
  from avatar_map m
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name=m.image_path;

  if v_storage_matches <> 30 then
    raise exception 'Expected exactly 30 avatar storage objects, found %', v_storage_matches;
  end if;
end $$;

with avatar_map(first_name,last_name,image_path) as (
  values
    ('Adrian','Carter','ATP AI Profils/Adrian Carter.png'),
    ('Andre','Correia','ATP AI Profils/Andre Correia.png'),
    ('Ayan','Nurgaliyev','ATP AI Profils/Ayan Nurgaliyev.png'),
    ('Bastien','Chevalier','ATP AI Profils/Bastien Chevalier.png'),
    ('Caleb','Bennett','ATP AI Profils/Caleb Bennett.png'),
    ('Chinedu','Adebayo','ATP AI Profils/Chinedu Adebayo.png'),
    ('David','Horak','ATP AI Profils/David Horak.png'),
    ('David','Horvath','ATP AI Profils/David Horvath.png'),
    ('Diego','Vidal','ATP AI Profils/Diego Vidal.png'),
    ('Gabriel','Teixeira','ATP AI Profils/Gabriel Teixeira.png'),
    ('Haruto','Kondo','ATP AI Profils/Haruto Kondo.png'),
    ('Jakub','Dvorak','ATP AI Profils/Jakub Dvorak.png'),
    ('Jure','Mlakar','ATP AI Profils/Jure Mlakar.png'),
    ('Kittipong','Kittisak','ATP AI Profils/Kittipong Kittisak.png'),
    ('Lachlan','Harris','ATP AI Profils/Lachlan Harris.png'),
    ('Lewis','Walsh','ATP AI Profils/Lewis Walsh.png'),
    ('Liam','Gagnon','ATP AI Profils/Liam Gagnon.png'),
    ('Linus','Holm','ATP AI Profils/Linus Holm.png'),
    ('Louis','Claes','ATP AI Profils/Louis Claes.png'),
    ('Lucas','Moreau','ATP AI Profils/Lucas Moreau.png'),
    ('Marius','Solberg','ATP AI Profils/Marius Solberg.png'),
    ('Mateo','Salazar','ATP AI Profils/Mateo Salazar.png'),
    ('Nemanja','Nikolic','ATP AI Profils/Nemanja Nikolic.png'),
    ('Nicolo','Romano','ATP AI Profils/Nicolo Romano.png'),
    ('Nikolay','Georgiev','ATP AI Profils/Nikolay Georgiev.png'),
    ('Ondrej','Vesely','ATP AI Profils/Ondrej Vesely.png'),
    ('Oskari','Salonen','ATP AI Profils/Oskari Salonen.png'),
    ('Taeyang','Kim','ATP AI Profils/Taeyang Kim.png'),
    ('Tomas','Kovac','ATP AI Profils/Tomas Kovac.png'),
    ('Victor','De Smet','ATP AI Profils/Victor De Smet.png')
)
update public.players p
set image_path=m.image_path,
    updated_at=now()
from avatar_map m
where p.first_name=m.first_name
  and p.last_name=m.last_name
  and p.world='ATP'
  and p.player_type='ai';
