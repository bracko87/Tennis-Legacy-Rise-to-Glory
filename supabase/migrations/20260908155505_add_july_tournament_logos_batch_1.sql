-- July tournament logo batch.
-- Store stable Admin signed-object references; TournamentLogoRecovery extracts
-- the object path and creates a fresh signed URL at runtime.
-- Corrections versus the supplied paste:
--   * DB tournament name is Båstad Open; storage file is Baastad Open.png.
--   * Tampere Challenger uses its real Tampere Challenger.png object, not the pasted Segovia URL.
--   * Iași Challenger uses its real Iasi Challenger.png object, not the pasted Iasi open URL.
--   * Banjul Futures intentionally uses the supplied Banjul Challenger.png object because
--     no separate Banjul Futures object currently exists in July storage.

with logo_map(name, storage_path) as (
  values
    ('Washington Open', 'Tournament Logos/July/Washington Open.png'),
    ('Los Cabos Open', 'Tournament Logos/July/Los Cabos Open.png'),
    ('San Marino Challenger', 'Tournament Logos/July/San Marino Challenger.png'),
    ('Lausanne Challenger', 'Tournament Logos/July/Lausanne Challenger.png'),
    ('Bonn Challenger', 'Tournament Logos/July/Bonn Challenger.png'),
    ('Florianópolis Challenger', 'Tournament Logos/July/Florianopolis Challenger.png'),
    ('Liberec Challenger', 'Tournament Logos/July/Liberec Challenger.png'),
    ('Port Louis Challenger', 'Tournament Logos/July/Port Louis Challenger.png'),
    ('Bishkek Futures', 'Tournament Logos/July/Bishkek Futures.png'),
    ('Tulsa Futures', 'Tournament Logos/July/Tulsa Futures.png'),
    ('Nadi Futures', 'Tournament Logos/July/Nadi Futures.png'),
    ('Estoril Open', 'Tournament Logos/July/Estoril Open.png'),
    ('Kitzbühel Open', 'Tournament Logos/July/Kitzbuhel Open.png'),
    ('Prague Open', 'Tournament Logos/July/Prague Open.png'),
    ('Bloomfield Hills Challenger', 'Tournament Logos/July/Bloomfield Hills Challenger.png'),
    ('Zug Challenger', 'Tournament Logos/July/Zug Challenger.png'),
    ('Guangzhou Challenger', 'Tournament Logos/July/Guangzhou Challenger.png'),
    ('Leipzig Challenger', 'Tournament Logos/July/Leipzig Challenger.png'),
    ('Salt Lake City Challenger', 'Tournament Logos/July/Salt Lake City Challenger.png'),
    ('Segovia Challenger', 'Tournament Logos/July/Segovia Challenger.png'),
    ('Tampere Challenger', 'Tournament Logos/July/Tampere Challenger.png'),
    ('Lilongwe Futures', 'Tournament Logos/July/Lilongwe Futures.png'),
    ('Paramaribo Futures', 'Tournament Logos/July/Paramaribo Futures.png'),
    ('Toowoomba Futures', 'Tournament Logos/July/Toowoomba Futures.png'),
    ('Båstad Open', 'Tournament Logos/July/Baastad Open.png'),
    ('Gstaad Open', 'Tournament Logos/July/Gstaad Open.png'),
    ('Iași Open', 'Tournament Logos/July/Iasi open.png'),
    ('Umag Open', 'Tournament Logos/July/Umag Open.png'),
    ('Sacramento Challenger', 'Tournament Logos/July/Sacramento Challenegr.png'),
    ('Bergen Challenger', 'Tournament Logos/July/Bergen Challenegr.png'),
    ('Bunschoten Challenger', 'Tournament Logos/July/Bunschoten Challenger.png'),
    ('Granby Challenger', 'Tournament Logos/July/Granby Challenger.png'),
    ('Kumasi Challenger', 'Tournament Logos/July/Kumasi Challenegr.png'),
    ('Lincoln Challenger', 'Tournament Logos/July/Lincoln Challenger.png'),
    ('Penang Challenger', 'Tournament Logos/July/Penang Challenger.png'),
    ('Pozoblanco Challenger', 'Tournament Logos/July/Pozoblanco Challenger.png'),
    ('Santa Fe Challenger', 'Tournament Logos/July/Santa Fe Challenger.png'),
    ('Wollongong Futures', 'Tournament Logos/July/Wollongong Futures.png'),
    ('Braunschweig Challenger', 'Tournament Logos/July/Braunschweig Challenger.png'),
    ('Newport Challenger', 'Tournament Logos/July/Newport Challenger.png'),
    ('Iași Challenger', 'Tournament Logos/July/Iasi Challenger.png'),
    ('Bogotá Challenger', 'Tournament Logos/July/Bogota Challenger.png'),
    ('Fukuoka Challenger', 'Tournament Logos/July/Fukuoka Challenger.png'),
    ('Milwaukee Challenger', 'Tournament Logos/July/Milwaukee Challenger.png'),
    ('Trieste Challenger', 'Tournament Logos/July/Trieste Challenger.png'),
    ('Utrecht Challenger', 'Tournament Logos/July/Utrecht Challenger.png'),
    ('Liège Challenger', 'Tournament Logos/July/Liege Challenger.png'),
    ('Banjul Futures', 'Tournament Logos/July/Banjul Challenger.png'),
    ('Valdivia Futures', 'Tournament Logos/July/Valdivia Futures.png'),
    ('Palmerston North Futures', 'Tournament Logos/July/Palmerston North Futures.png')
)
update public.tournament_series ts
set logo_url = 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/' || replace(lm.storage_path, ' ', '%20')
from logo_map lm
where ts.name = lm.name;
