with image_map(player_name, image_path) as (
  values
  ('Alonso Caceres','ATP AI Profils/Alonso Caceres.png'),
  ('Ante Babic','ATP AI Profils/Ante Babic.png'),
  ('Bartosz Kowalski','ATP AI Profils/Bartosz Kowalski.png'),
  ('Blake Murray','ATP AI Profils/Blake Murray.png'),
  ('Brian Omondi','ATP AI Profils/Brian Omondi.png'),
  ('Georgi Kolev','ATP AI Profils/Georgi Kolev.png'),
  ('Harry Bennett','ATP AI Profils/Harry Bennett.png'),
  ('Haruto Nakamura','ATP AI Profils/Haruto Nakamura.png'),
  ('Henrik Strand','ATP AI Profils/Henrik Strand.png'),
  ('Ivan Dimitrov','ATP AI Profils/Ivan Dimitrov.png'),
  ('Javier Mendoza','ATP AI Profils/Javier Mendoza.png'),
  ('Jian Huang','ATP AI Profils/Jian Huang.png'),
  ('Jonas Neumann','ATP AI Profils/Jonas Neumann.png'),
  ('Karan Bhat','ATP AI Profils/Karan Bhat.png'),
  ('Kasper Larsen','ATP AI Profils/Kasper Larsen.png'),
  ('Kristijan Nikolov','ATP AI Profils/Kristijan Nikolov.png'),
  ('Majid Al Mansoori','ATP AI Profils/Majid Al Mansoori.png'),
  ('Matias Pereyra','ATP AI Profils/Matias Pereyra.png'),
  ('Milos Ilic','ATP AI Profils/Milos Ilic.png'),
  ('Minjun Choi','ATP AI Profils/Minjun Choi.png'),
  ('Niklas Schneider','ATP AI Profils/Niklas Schneider.png'),
  ('Quentin Perrin','ATP AI Profils/Quentin Perrin.png'),
  ('Ruan Pretorius','ATP AI Profils/Ruan Pretorius.png'),
  ('Seojun Lee','ATP AI Profils/Seojun Lee.png'),
  ('Sota Tanaka','ATP AI Profils/Sota Tanaka.png'),
  ('Stefan Iliev','ATP AI Profils/Stefan Iliev.png'),
  ('Tao Liu','ATP AI Profils/Tao Liu.png'),
  ('Tomas Sosa','ATP AI Profils/Tomas Sosa.png'),
  ('Viktor Sjoberg','ATP AI Profils/Viktor Sjoberg.png'),
  ('Yassine Hamdi','ATP AI Profils/Yassine Hamdi.png')
)
update public.players p
set image_path = m.image_path,
    updated_at = now()
from image_map m
where p.player_type = 'ai'
  and p.world = 'ATP'
  and (p.first_name || ' ' || p.last_name) = m.player_name;
