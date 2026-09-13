do $$
declare
  v_requested integer;
  v_matched integer;
  v_storage integer;
begin
  with requested(full_name,country_code,home_city,image_path) as (
    values
    ('Alvaro Soler','ES','Bilbao','ATP AI Profils/Alvaro Soler.png'),
    ('Thanawat Wattanakul','TH','Bangkok','ATP AI Profils/Thanawat Wattanakul.png'),
    ('Moritz Hartmann','DE','Berlin','ATP AI Profils/Moritz Hartmann.png'),
    ('Emil Kristensen','DK','Copenhagen','ATP AI Profils/Emil Kristensen.png'),
    ('Rachid Fassi','MA','Kenitra','ATP AI Profils/Rachid Fassi.png'),
    ('Sebastian Rincon','CO','Cúcuta','ATP AI Profils/Sebastian Rincon.png'),
    ('Sander Bakken','NO','Ålesund','ATP AI Profils/Sander Bakken.png'),
    ('Lautaro Acosta','AR','Salta','ATP AI Profils/Lautaro Acosta.png'),
    ('Oskar Ekstrom','SE','Helsingborg','ATP AI Profils/Oskar Ekstrom.png'),
    ('Logan Sullivan','US','Dallas','ATP AI Profils/Logan Sullivan.png'),
    ('Kaito Ishikawa','JP','Tokyo','ATP AI Profils/Kaito Ishikawa.png'),
    ('Ethan Reed','US','New York','ATP AI Profils/Ethan Reed.png'),
    ('Tomas Molina','AR','San Miguel de Tucumán','ATP AI Profils/Tomas Molina.png'),
    ('Piotr Pawlak','PL','Szczecin','ATP AI Profils/Piotr Pawlak.png'),
    ('David Novak','CZ','Olomouc','ATP AI Profils/David Novak.png'),
    ('Gabriel Azevedo','BR','Recife','ATP AI Profils/Gabriel Azevedo.png'),
    ('Erik Forsberg','SE','Gothenburg','ATP AI Profils/Erik Forsberg.png'),
    ('Amine Alaoui','MA','Tetouan','ATP AI Profils/Amine Alaoui.png'),
    ('Mathieu Chevalier','FR','Paris','ATP AI Profils/Mathieu Chevalier.png'),
    ('Agustin Olivera','UY','Las Piedras','ATP AI Profils/Agustin Olivera.png'),
    ('Jakub Nowak','PL','Warsaw','ATP AI Profils/Jakub Nowak.png'),
    ('Quentin Moreau','FR','Lille','ATP AI Profils/Quentin Moreau.png'),
    ('Diego Rojas','CL','Santiago','ATP AI Profils/Diego Rojas.png'),
    ('Mateusz Mazur','PL','Bydgoszcz','ATP AI Profils/Mateusz Mazur.png'),
    ('Thomas Jacobs','BE','Hasselt','ATP AI Profils/Thomas Jacobs.png'),
    ('Florian Leitner','AT','Graz','ATP AI Profils/Florian Leitner.png'),
    ('Simon Koch','CH','Basel','ATP AI Profils/Simon Koch.png'),
    ('Wei Zhao','CN','Chengdu','ATP AI Profils/Wei Zhao.png'),
    ('Lars Visser','NL','The Hague','ATP AI Profils/Lars Visser.png'),
    ('Harry Coleman','GB','Birmingham','ATP AI Profils/Harry Coleman.png'),
    ('Mauricio Rojas','PE','Chiclayo','ATP AI Profils/Mauricio Rojas.png'),
    ('Lukas Fischer','DE','Leipzig','ATP AI Profils/Lukas Fischer.png'),
    ('Mathieu Dumont','FR','Marseille','ATP AI Profils/Mathieu Dumont.png'),
    ('Tomas Kucera','CZ','Liberec','ATP AI Profils/Tomas Kucera.png'),
    ('Jack Bennett','AU','Wollongong','ATP AI Profils/Jack Bennett.png'),
    ('Bastien Rousseau','FR','Montpellier','ATP AI Profils/Bastien Rousseau.png'),
    ('Kenan Hadzic','BA','Sarajevo','ATP AI Profils/Kenan Hadzic.png'),
    ('Dias Zhaksybek','KZ','Almaty','ATP AI Profils/Dias Zhaksybek.png'),
    ('Nikola Jovanovic','RS','Kragujevac','ATP AI Profils/Nikola Jovanovic.png'),
    ('Joao Ferreira','PT','Aveiro','ATP AI Profils/Joao Ferreira.png'),
    ('Oliver Turner','GB','Manchester','ATP AI Profils/Oliver Turner.png'),
    ('Ethan Parker','US','Philadelphia','ATP AI Profils/Ethan Parker.png'),
    ('Riccardo Gatti','IT','Catania','ATP AI Profils/Riccardo Gatti.png'),
    ('Cooper Fletcher','AU','Wollongong','ATP AI Profils/Cooper Fletcher.png'),
    ('Jakub Hudak','SK','Žilina','ATP AI Profils/Jakub Hudak.png'),
    ('Maximilian Wagner','AT','Graz','ATP AI Profils/Maximilian Wagner.png'),
    ('Nikola Stojanovic','RS','Novi Sad','ATP AI Profils/Nikola Stojanovic.png'),
    ('Julian Mitchell','US','Los Angeles','ATP AI Profils/Julian Mitchell.png'),
    ('Martin Pereira','UY','Rivera','ATP AI Profils/Martin Pereira.png'),
    ('Bence Molnar','HU','Szeged','ATP AI Profils/Bence Molnar.png'),
    ('Lucas Carvalho','BR','Rio de Janeiro','ATP AI Profils/Lucas Carvalho.png'),
    ('Omar Mansour','EG','Alexandria','ATP AI Profils/Omar Mansour.png'),
    ('Luka Vukovic','RS','Novi Pazar','ATP AI Profils/Luka Vukovic.png'),
    ('Liam MacDonald','CA','Victoria','ATP AI Profils/Liam MacDonald.png'),
    ('Alvaro Vidal','ES','Alicante','ATP AI Profils/Alvaro Vidal.png'),
    ('Jack Parker','AU','Hobart','ATP AI Profils/Jack Parker.png'),
    ('Blake Collins','AU','Adelaide','ATP AI Profils/Blake Collins.png'),
    ('Javier Serrano','ES','Alicante','ATP AI Profils/Javier Serrano.png'),
    ('Aditya Patel','IN','Ahmedabad','ATP AI Profils/Aditya Patel.png'),
    ('Gabor Balogh','HU','Budapest','ATP AI Profils/Gabor Balogh.png'),
    ('Matej Kovacevic','HR','Split','ATP AI Profils/Matej Kovacevic.png'),
    ('Facundo Benitez','AR','Salta','ATP AI Profils/Facundo Benitez.png'),
    ('Caleb Rangi','NZ','Tauranga','ATP AI Profils/Caleb Rangi.png'),
    ('Tane Wilson','NZ','Nelson','ATP AI Profils/Tane Wilson.png'),
    ('Owen Murray','CA','Winnipeg','ATP AI Profils/Owen Murray.png'),
    ('Nathan Bennett','GB','Leeds','ATP AI Profils/Nathan Bennett.png'),
    ('Marin Peric','HR','Pula','ATP AI Profils/Marin Peric.png'),
    ('Yuto Fujita','JP','Hiroshima','ATP AI Profils/Yuto Fujita.png'),
    ('Andrei Dumitru','RO','Ploiești','ATP AI Profils/Andrei Dumitru.png'),
    ('Thijs de Vries','NL','Nijmegen','ATP AI Profils/Thijs de Vries.png')
  )
  select count(*),
         count(p.id),
         count(*) filter (where o.name is not null)
  into v_requested,v_matched,v_storage
  from requested r
  left join public.players p
    on lower(trim(p.first_name||' '||p.last_name))=lower(trim(r.full_name))
   and upper(p.country_code)=upper(r.country_code)
   and lower(coalesce(p.home_city,''))=lower(r.home_city)
   and p.player_type='ai'
  left join storage.objects o
    on o.bucket_id='Admin'
   and o.name=r.image_path;

  if v_requested <> 70 then
    raise exception 'Expected 70 requested ATP AI avatar mappings, found %', v_requested;
  end if;
  if v_matched <> 70 then
    raise exception 'Expected 70 matching ATP AI players, found %', v_matched;
  end if;
  if v_storage <> 70 then
    raise exception 'Expected 70 matching Admin storage objects, found %', v_storage;
  end if;
end $$;

with requested(full_name,country_code,home_city,image_path) as (
  values
  ('Alvaro Soler','ES','Bilbao','ATP AI Profils/Alvaro Soler.png'),
  ('Thanawat Wattanakul','TH','Bangkok','ATP AI Profils/Thanawat Wattanakul.png'),
  ('Moritz Hartmann','DE','Berlin','ATP AI Profils/Moritz Hartmann.png'),
  ('Emil Kristensen','DK','Copenhagen','ATP AI Profils/Emil Kristensen.png'),
  ('Rachid Fassi','MA','Kenitra','ATP AI Profils/Rachid Fassi.png'),
  ('Sebastian Rincon','CO','Cúcuta','ATP AI Profils/Sebastian Rincon.png'),
  ('Sander Bakken','NO','Ålesund','ATP AI Profils/Sander Bakken.png'),
  ('Lautaro Acosta','AR','Salta','ATP AI Profils/Lautaro Acosta.png'),
  ('Oskar Ekstrom','SE','Helsingborg','ATP AI Profils/Oskar Ekstrom.png'),
  ('Logan Sullivan','US','Dallas','ATP AI Profils/Logan Sullivan.png'),
  ('Kaito Ishikawa','JP','Tokyo','ATP AI Profils/Kaito Ishikawa.png'),
  ('Ethan Reed','US','New York','ATP AI Profils/Ethan Reed.png'),
  ('Tomas Molina','AR','San Miguel de Tucumán','ATP AI Profils/Tomas Molina.png'),
  ('Piotr Pawlak','PL','Szczecin','ATP AI Profils/Piotr Pawlak.png'),
  ('David Novak','CZ','Olomouc','ATP AI Profils/David Novak.png'),
  ('Gabriel Azevedo','BR','Recife','ATP AI Profils/Gabriel Azevedo.png'),
  ('Erik Forsberg','SE','Gothenburg','ATP AI Profils/Erik Forsberg.png'),
  ('Amine Alaoui','MA','Tetouan','ATP AI Profils/Amine Alaoui.png'),
  ('Mathieu Chevalier','FR','Paris','ATP AI Profils/Mathieu Chevalier.png'),
  ('Agustin Olivera','UY','Las Piedras','ATP AI Profils/Agustin Olivera.png'),
  ('Jakub Nowak','PL','Warsaw','ATP AI Profils/Jakub Nowak.png'),
  ('Quentin Moreau','FR','Lille','ATP AI Profils/Quentin Moreau.png'),
  ('Diego Rojas','CL','Santiago','ATP AI Profils/Diego Rojas.png'),
  ('Mateusz Mazur','PL','Bydgoszcz','ATP AI Profils/Mateusz Mazur.png'),
  ('Thomas Jacobs','BE','Hasselt','ATP AI Profils/Thomas Jacobs.png'),
  ('Florian Leitner','AT','Graz','ATP AI Profils/Florian Leitner.png'),
  ('Simon Koch','CH','Basel','ATP AI Profils/Simon Koch.png'),
  ('Wei Zhao','CN','Chengdu','ATP AI Profils/Wei Zhao.png'),
  ('Lars Visser','NL','The Hague','ATP AI Profils/Lars Visser.png'),
  ('Harry Coleman','GB','Birmingham','ATP AI Profils/Harry Coleman.png'),
  ('Mauricio Rojas','PE','Chiclayo','ATP AI Profils/Mauricio Rojas.png'),
  ('Lukas Fischer','DE','Leipzig','ATP AI Profils/Lukas Fischer.png'),
  ('Mathieu Dumont','FR','Marseille','ATP AI Profils/Mathieu Dumont.png'),
  ('Tomas Kucera','CZ','Liberec','ATP AI Profils/Tomas Kucera.png'),
  ('Jack Bennett','AU','Wollongong','ATP AI Profils/Jack Bennett.png'),
  ('Bastien Rousseau','FR','Montpellier','ATP AI Profils/Bastien Rousseau.png'),
  ('Kenan Hadzic','BA','Sarajevo','ATP AI Profils/Kenan Hadzic.png'),
  ('Dias Zhaksybek','KZ','Almaty','ATP AI Profils/Dias Zhaksybek.png'),
  ('Nikola Jovanovic','RS','Kragujevac','ATP AI Profils/Nikola Jovanovic.png'),
  ('Joao Ferreira','PT','Aveiro','ATP AI Profils/Joao Ferreira.png'),
  ('Oliver Turner','GB','Manchester','ATP AI Profils/Oliver Turner.png'),
  ('Ethan Parker','US','Philadelphia','ATP AI Profils/Ethan Parker.png'),
  ('Riccardo Gatti','IT','Catania','ATP AI Profils/Riccardo Gatti.png'),
  ('Cooper Fletcher','AU','Wollongong','ATP AI Profils/Cooper Fletcher.png'),
  ('Jakub Hudak','SK','Žilina','ATP AI Profils/Jakub Hudak.png'),
  ('Maximilian Wagner','AT','Graz','ATP AI Profils/Maximilian Wagner.png'),
  ('Nikola Stojanovic','RS','Novi Sad','ATP AI Profils/Nikola Stojanovic.png'),
  ('Julian Mitchell','US','Los Angeles','ATP AI Profils/Julian Mitchell.png'),
  ('Martin Pereira','UY','Rivera','ATP AI Profils/Martin Pereira.png'),
  ('Bence Molnar','HU','Szeged','ATP AI Profils/Bence Molnar.png'),
  ('Lucas Carvalho','BR','Rio de Janeiro','ATP AI Profils/Lucas Carvalho.png'),
  ('Omar Mansour','EG','Alexandria','ATP AI Profils/Omar Mansour.png'),
  ('Luka Vukovic','RS','Novi Pazar','ATP AI Profils/Luka Vukovic.png'),
  ('Liam MacDonald','CA','Victoria','ATP AI Profils/Liam MacDonald.png'),
  ('Alvaro Vidal','ES','Alicante','ATP AI Profils/Alvaro Vidal.png'),
  ('Jack Parker','AU','Hobart','ATP AI Profils/Jack Parker.png'),
  ('Blake Collins','AU','Adelaide','ATP AI Profils/Blake Collins.png'),
  ('Javier Serrano','ES','Alicante','ATP AI Profils/Javier Serrano.png'),
  ('Aditya Patel','IN','Ahmedabad','ATP AI Profils/Aditya Patel.png'),
  ('Gabor Balogh','HU','Budapest','ATP AI Profils/Gabor Balogh.png'),
  ('Matej Kovacevic','HR','Split','ATP AI Profils/Matej Kovacevic.png'),
  ('Facundo Benitez','AR','Salta','ATP AI Profils/Facundo Benitez.png'),
  ('Caleb Rangi','NZ','Tauranga','ATP AI Profils/Caleb Rangi.png'),
  ('Tane Wilson','NZ','Nelson','ATP AI Profils/Tane Wilson.png'),
  ('Owen Murray','CA','Winnipeg','ATP AI Profils/Owen Murray.png'),
  ('Nathan Bennett','GB','Leeds','ATP AI Profils/Nathan Bennett.png'),
  ('Marin Peric','HR','Pula','ATP AI Profils/Marin Peric.png'),
  ('Yuto Fujita','JP','Hiroshima','ATP AI Profils/Yuto Fujita.png'),
  ('Andrei Dumitru','RO','Ploiești','ATP AI Profils/Andrei Dumitru.png'),
  ('Thijs de Vries','NL','Nijmegen','ATP AI Profils/Thijs de Vries.png')
)
update public.players p
set image_path=r.image_path,
    updated_at=now()
from requested r
where lower(trim(p.first_name||' '||p.last_name))=lower(trim(r.full_name))
  and upper(p.country_code)=upper(r.country_code)
  and lower(coalesce(p.home_city,''))=lower(r.home_city)
  and p.player_type='ai'
  and p.image_path is distinct from r.image_path;
