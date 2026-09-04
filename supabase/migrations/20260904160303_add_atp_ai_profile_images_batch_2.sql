with portraits(first_name,last_name,image_path) as (values
('Adrian','Foster','ATP AI Profils/Adrian Foster.png'),
('Benjamin','Figueroa','ATP AI Profils/Benjamin Figueroa.png'),
('Daiki','Mori','ATP AI Profils/Daiki Mori.png'),
('Donghyun','Han','ATP AI Profils/Donghyun Han.png'),
('Elias','Koskinen','ATP AI Profils/Elias Koskinen.png'),
('Emil','Lindberg','ATP AI Profils/Emil Lindberg.png'),
('Etienne','Mercier','ATP AI Profils/Etienne Mercier.png'),
('George','Fletcher','ATP AI Profils/George Fletcher.png'),
('Haris','Avdic','ATP AI Profils/Haris Avdic.png'),
('Jesse','Mulder','ATP AI Profils/Jesse Mulder.png'),
('Jihoon','Yoon','ATP AI Profils/Jihoon Yoon.png'),
('Jonas','Vogel','ATP AI Profils/Jonas Vogel.png'),
('Lachlan','Collins','ATP AI Profils/Lachlan Collins.png'),
('Lucas','Garnier','ATP AI Profils/Lucas Garnier.png'),
('Luka','Vidmar','ATP AI Profils/Luka Vidmar.png'),
('Marcos','Navarro','ATP AI Profils/Marcos Navarro.png'),
('Mason','Foster','ATP AI Profils/Mason Foster.png'),
('Noah','Keller','ATP AI Profils/Noah Keller.png'),
('Oliver','Palmer','ATP AI Profils/Oliver Palmer.png'),
('Piotr','Wojcik','ATP AI Profils/Piotr Wojcik.png'),
('Stefan','Savic','ATP AI Profils/Stefan Savic.png'),
('Thabo','Jacobs','ATP AI Profils/Thabo Jacobs.png')
)
update public.players p
set image_path=portraits.image_path, updated_at=now()
from portraits
where p.first_name=portraits.first_name
  and p.last_name=portraits.last_name
  and p.world='ATP'
  and p.player_type='ai';
