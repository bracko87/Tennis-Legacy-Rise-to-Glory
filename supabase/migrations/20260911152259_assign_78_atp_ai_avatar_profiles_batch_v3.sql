do $$
declare
  v_player_matches integer;
  v_storage_matches integer;
begin
  with avatar_map(first_name,last_name,country_code) as (
    values
    ('Agustin','Fernandez','AR'),('Emiliano','Castillo','MX'),('Dimitris','Manolis','GR'),('Ren','Okada','JP'),('Jian','Chen','CN'),('Vlad','Ionescu','RO'),('Harrison','Lawson','AU'),('Andreas','Georgiou','GR'),('Dylan','Botha','ZA'),('Marko','Markovic','RS'),('Kacper','Zielinski','PL'),('Omar','Al Suwaidi','AE'),('Callum','Foster','GB'),('Tarek','Hassan','EG'),('Jan','Graf','CH'),('Bruno','Carvalho','BR'),('Noah','Fraser','CA'),('Agustin','Benitez','AR'),('Domagoj','Juric','HR'),('Mateo','Restrepo','CO'),('Niels','Smit','NL'),('Mitchell','Walker','AU'),('Mikael','Laine','FI'),('Matej','Krejci','CZ'),('Giorgos','Vlachos','GR'),('Hugo','Lefevre','FR'),('Hyunwoo','Jung','KR'),('Ethan','Roy','CA'),('Mason','Reed','US'),('Mikkel','Thomsen','DK'),('Miguel','Nunes','PT'),('Caleb','Hughes','US'),('Sergio','Mendoza','ES'),('Arman','Iskakov','KZ'),('Amar','Delic','BA'),('Felix','Fischer','DE'),('Thiago','Barbosa','BR'),('Daiki','Shimizu','JP'),('Vikram','Reddy','IN'),('Julien','Lavoie','CA'),('Vicente','Sepulveda','CL'),('Matias','Contreras','CL'),('Nemanja','Petrovic','RS'),('Mehdi','Jaziri','TN'),('Ethan','Mokoena','ZA'),('Cristobal','Araya','CL'),('Marcos','Soler','ES'),('Tobias','Bauer','DE'),('Julian','Hughes','US'),('Nathan','Hughes','GB'),('Bram','Bakker','NL'),('Liam','van Wyk','ZA'),('Nathan','Bouchard','CA'),('Nursultan','Kassenov','KZ'),('Filip','Trajkovski','MK'),('Jorge','Vargas','MX'),('Mathias','Maes','BE'),('Liam','McKenzie','NZ'),('Arthur','Lambert','BE'),('Tommaso','Marino','IT'),('Diogo','Tavares','PT'),('Jun','Zhang','CN'),('Luca','Brunner','CH'),('Lorenzo','Ferrari','IT'),('Finn','Bennett','NZ'),('Lorenzo','Rinaldi','IT'),('Mihai','Munteanu','RO'),('Daan','Dekker','NL'),('Matheus','Freitas','BR'),('Etienne','Garnier','FR'),('Ahmed','Gharbi','TN'),('Youssef','Berrada','MA'),('Bruno','Moura','BR'),('Victor','Ogunleye','NG'),('Stelios','Lazaridis','GR'),('Lukas','Novak','SK'),('Lucas','Almeida','BR'),('Radu','Stan','RO')
  )
  select count(*) into v_player_matches
  from avatar_map m
  join public.players p
    on p.first_name=m.first_name
   and p.last_name=m.last_name
   and p.country_code=m.country_code
   and p.world='ATP'
   and p.player_type='ai';

  if v_player_matches <> 78 then
    raise exception 'Expected exactly 78 ATP AI player matches, found %', v_player_matches;
  end if;

  with avatar_map(first_name,last_name,country_code) as (
    values
    ('Agustin','Fernandez','AR'),('Emiliano','Castillo','MX'),('Dimitris','Manolis','GR'),('Ren','Okada','JP'),('Jian','Chen','CN'),('Vlad','Ionescu','RO'),('Harrison','Lawson','AU'),('Andreas','Georgiou','GR'),('Dylan','Botha','ZA'),('Marko','Markovic','RS'),('Kacper','Zielinski','PL'),('Omar','Al Suwaidi','AE'),('Callum','Foster','GB'),('Tarek','Hassan','EG'),('Jan','Graf','CH'),('Bruno','Carvalho','BR'),('Noah','Fraser','CA'),('Agustin','Benitez','AR'),('Domagoj','Juric','HR'),('Mateo','Restrepo','CO'),('Niels','Smit','NL'),('Mitchell','Walker','AU'),('Mikael','Laine','FI'),('Matej','Krejci','CZ'),('Giorgos','Vlachos','GR'),('Hugo','Lefevre','FR'),('Hyunwoo','Jung','KR'),('Ethan','Roy','CA'),('Mason','Reed','US'),('Mikkel','Thomsen','DK'),('Miguel','Nunes','PT'),('Caleb','Hughes','US'),('Sergio','Mendoza','ES'),('Arman','Iskakov','KZ'),('Amar','Delic','BA'),('Felix','Fischer','DE'),('Thiago','Barbosa','BR'),('Daiki','Shimizu','JP'),('Vikram','Reddy','IN'),('Julien','Lavoie','CA'),('Vicente','Sepulveda','CL'),('Matias','Contreras','CL'),('Nemanja','Petrovic','RS'),('Mehdi','Jaziri','TN'),('Ethan','Mokoena','ZA'),('Cristobal','Araya','CL'),('Marcos','Soler','ES'),('Tobias','Bauer','DE'),('Julian','Hughes','US'),('Nathan','Hughes','GB'),('Bram','Bakker','NL'),('Liam','van Wyk','ZA'),('Nathan','Bouchard','CA'),('Nursultan','Kassenov','KZ'),('Filip','Trajkovski','MK'),('Jorge','Vargas','MX'),('Mathias','Maes','BE'),('Liam','McKenzie','NZ'),('Arthur','Lambert','BE'),('Tommaso','Marino','IT'),('Diogo','Tavares','PT'),('Jun','Zhang','CN'),('Luca','Brunner','CH'),('Lorenzo','Ferrari','IT'),('Finn','Bennett','NZ'),('Lorenzo','Rinaldi','IT'),('Mihai','Munteanu','RO'),('Daan','Dekker','NL'),('Matheus','Freitas','BR'),('Etienne','Garnier','FR'),('Ahmed','Gharbi','TN'),('Youssef','Berrada','MA'),('Bruno','Moura','BR'),('Victor','Ogunleye','NG'),('Stelios','Lazaridis','GR'),('Lukas','Novak','SK'),('Lucas','Almeida','BR'),('Radu','Stan','RO')
  )
  select count(*) into v_storage_matches
  from avatar_map m
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name=('ATP AI Profils/' || m.first_name || ' ' || m.last_name || '.png');

  if v_storage_matches <> 78 then
    raise exception 'Expected exactly 78 avatar storage objects, found %', v_storage_matches;
  end if;
end $$;

with avatar_map(first_name,last_name,country_code) as (
  values
  ('Agustin','Fernandez','AR'),('Emiliano','Castillo','MX'),('Dimitris','Manolis','GR'),('Ren','Okada','JP'),('Jian','Chen','CN'),('Vlad','Ionescu','RO'),('Harrison','Lawson','AU'),('Andreas','Georgiou','GR'),('Dylan','Botha','ZA'),('Marko','Markovic','RS'),('Kacper','Zielinski','PL'),('Omar','Al Suwaidi','AE'),('Callum','Foster','GB'),('Tarek','Hassan','EG'),('Jan','Graf','CH'),('Bruno','Carvalho','BR'),('Noah','Fraser','CA'),('Agustin','Benitez','AR'),('Domagoj','Juric','HR'),('Mateo','Restrepo','CO'),('Niels','Smit','NL'),('Mitchell','Walker','AU'),('Mikael','Laine','FI'),('Matej','Krejci','CZ'),('Giorgos','Vlachos','GR'),('Hugo','Lefevre','FR'),('Hyunwoo','Jung','KR'),('Ethan','Roy','CA'),('Mason','Reed','US'),('Mikkel','Thomsen','DK'),('Miguel','Nunes','PT'),('Caleb','Hughes','US'),('Sergio','Mendoza','ES'),('Arman','Iskakov','KZ'),('Amar','Delic','BA'),('Felix','Fischer','DE'),('Thiago','Barbosa','BR'),('Daiki','Shimizu','JP'),('Vikram','Reddy','IN'),('Julien','Lavoie','CA'),('Vicente','Sepulveda','CL'),('Matias','Contreras','CL'),('Nemanja','Petrovic','RS'),('Mehdi','Jaziri','TN'),('Ethan','Mokoena','ZA'),('Cristobal','Araya','CL'),('Marcos','Soler','ES'),('Tobias','Bauer','DE'),('Julian','Hughes','US'),('Nathan','Hughes','GB'),('Bram','Bakker','NL'),('Liam','van Wyk','ZA'),('Nathan','Bouchard','CA'),('Nursultan','Kassenov','KZ'),('Filip','Trajkovski','MK'),('Jorge','Vargas','MX'),('Mathias','Maes','BE'),('Liam','McKenzie','NZ'),('Arthur','Lambert','BE'),('Tommaso','Marino','IT'),('Diogo','Tavares','PT'),('Jun','Zhang','CN'),('Luca','Brunner','CH'),('Lorenzo','Ferrari','IT'),('Finn','Bennett','NZ'),('Lorenzo','Rinaldi','IT'),('Mihai','Munteanu','RO'),('Daan','Dekker','NL'),('Matheus','Freitas','BR'),('Etienne','Garnier','FR'),('Ahmed','Gharbi','TN'),('Youssef','Berrada','MA'),('Bruno','Moura','BR'),('Victor','Ogunleye','NG'),('Stelios','Lazaridis','GR'),('Lukas','Novak','SK'),('Lucas','Almeida','BR'),('Radu','Stan','RO')
)
update public.players p
set image_path=('ATP AI Profils/' || m.first_name || ' ' || m.last_name || '.png'),
    updated_at=now()
from avatar_map m
where p.first_name=m.first_name
  and p.last_name=m.last_name
  and p.country_code=m.country_code
  and p.world='ATP'
  and p.player_type='ai';