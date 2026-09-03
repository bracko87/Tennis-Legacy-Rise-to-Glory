with avatar_map(first_name, last_name, image_path) as (
  values
    ('Sergio', 'Iglesias', 'ATP AI Profils/Sergio Iglesias.png'),
    ('Stefan', 'Popescu', 'ATP AI Profils/Stefan Popescu.png'),
    ('Rahul', 'Sharma', 'ATP AI Profils/Rahul Sharma.png'),
    ('Logan', 'Bennett', 'ATP AI Profils/Logan Bennett.png'),
    ('Youssef', 'Hamza', 'ATP AI Profils/Youssef Hamza.png'),
    ('Petar', 'Nikolov', 'ATP AI Profils/Petar Nikolov.png'),
    ('Akmal', 'Ismoilov', 'ATP AI Profils/Akmal Ismoilov.png'),
    ('Lukas', 'Pichler', 'ATP AI Profils/Lukas Pichler.png'),
    ('Diego', 'Navarro', 'ATP AI Profils/Diego Navarro.png'),
    ('Diego', 'Ortega', 'ATP AI Profils/Diego Ortega.png'),
    ('Jakub', 'Sikora', 'ATP AI Profils/Jakub Sikora.png'),
    ('Santiago', 'Bentancur', 'ATP AI Profils/Santiago Bentancur.png'),
    ('Fabian', 'Steiner', 'ATP AI Profils/Fabian Steiner.png'),
    ('Hao', 'Yang', 'ATP AI Profils/Hao Yang.png'),
    ('George', 'Palmer', 'ATP AI Profils/George Palmer.png'),
    ('Nikos', 'Nikolaou', 'ATP AI Profils/Nikos Nikolaou.png'),
    ('Diego', 'Salazar', 'ATP AI Profils/Diego Salazar.png'),
    ('Rafael', 'Ramirez', 'ATP AI Profils/Rafael Ramirez.png'),
    ('Martin', 'Kral', 'ATP AI Profils/Martin Kral.png')
)
update public.players p
set image_path = m.image_path,
    updated_at = now()
from avatar_map m
where p.first_name = m.first_name
  and p.last_name = m.last_name
  and p.world = 'ATP'
  and p.player_type = 'ai';
