create temporary table tmp_august_tournament_logos(name text primary key, object_path text not null) on commit drop;
insert into tmp_august_tournament_logos(name,object_path) values
  ('Como Lake Challenger','Tournament Logos/August/Como Lake Challenger.png'),
  ('CT Porto Cup','Tournament Logos/August/CT Porto Cup.png'),
  ('Eindhoven Challenger','Tournament Logos/August/Eindhoven Challenger.png'),
  ('Hanoi Challenger','Tournament Logos/August/Hanoi Challenger.png'),
  ('Manacor Challenger','Tournament Logos/August/Manacor Challenger.png'),
  ('Minneapolis Challenger','Tournament Logos/August/Minneapolos challenger.png'),
  ('San Juan Challenger','Tournament Logos/August/San Juan Challenger.png'),
  ('Varna Challenger','Tournament Logos/August/Varna Challenger.png'),
  ('Yaoundé Challenger','Tournament Logos/August/Yaounde Challenegr.png'),
  ('Zhangjiagang Challenger','Tournament Logos/August/Zhangjiagang Challenger.png'),
  ('Mackay Futures','Tournament Logos/August/Mackay Futures.png'),
  ('US Open','Tournament Logos/August/Us Open.png'),
  ('Winston-Salem Open','Tournament Logos/August/Winston-Salem Open.png'),
  ('Bamako Challenger','Tournament Logos/August/Bamako Challenger.png'),
  ('Montego Bay Challenger','Tournament Logos/August/Montego Bay Challenger.png'),
  ('Reykjavik Challenger','Tournament Logos/August/Reykjavik Challenger.png'),
  ('Richmond Challenger','Tournament Logos/August/Richmond Challenger.png'),
  ('Augsburg Challenger','Tournament Logos/August/Augsburg Challenger.png'),
  ('Bristol Challenger','Tournament Logos/August/Bristol Challenger.png'),
  ('Georgetown Futures','Tournament Logos/August/Georgetown Futures.png'),
  ('Nagano Futures','Tournament Logos/August/Nagano Futures.png'),
  ('Palmerston Futures','Tournament Logos/August/Palmerston Futures.png'),
  ('Cancún Challenger','Tournament Logos/August/Cancun Challenger.png'),
  ('Québec City Challenger','Tournament Logos/August/Quebec City.png'),
  ('Aleksandrovo Challenger','Tournament Logos/August/Aleksandrovo Challenger.png'),
  ('Czech Challenger','Tournament Logos/August/Czech Challenger.png'),
  ('Kingston Challenger','Tournament Logos/August/Kingston Challenger.png'),
  ('Medan Challenger','Tournament Logos/August/Medan Challenger.png'),
  ('Reno Challenger','Tournament Logos/August/Reno Challenger.png'),
  ('Santa Marta Challenger','Tournament Logos/August/Santa Marta Challenger.png'),
  ('Roehampton Challenger','Tournament Logos/August/Rockhampton Futures.png'),
  ('Sion Challenger','Tournament Logos/August/Sion Challenger.png'),
  ('Uzbekistan Challenger','Tournament Logos/August/Uzbekistan Challenger.png'),
  ('Blantyre Futures','Tournament Logos/August/Blantyre Futures.png'),
  ('Rockhampton Futures','Tournament Logos/August/Rockhampton Futures.png'),
  ('Cincinnati Masters','Tournament Logos/August/Cincinnati Masters.png'),
  ('Montreal Masters','Tournament Logos/August/Montreal masters.png'),
  ('Boise Challenger','Tournament Logos/August/Boise Challenger.png'),
  ('Brownsburg Challenger','Tournament Logos/August/Brownsburg Challenger.png'),
  ('Chiang Mai Challenger','Tournament Logos/August/Chiang Mai Challenger.png'),
  ('Fes Challenger','Tournament Logos/August/Fes Challenger.png'),
  ('Hamburg Challenger','Tournament Logos/August/Hamburg Challenger.png'),
  ('Neuquén Challenger','Tournament Logos/August/Neuquen Challenger.png'),
  ('Todi Challenger','Tournament Logos/August/Todi Challenger.png'),
  ('Turku Challenger','Tournament Logos/August/Turku Challenger.png'),
  ('Astana Challenger','Tournament Logos/August/Astana Challenger.png'),
  ('Invercargill Futures','Tournament Logos/August/Invercargill Futures.png'),
  ('Hagen Challenger','Tournament Logos/August/Hagen Challenger.png'),
  ('Boostedt Challenger','Tournament Logos/August/Boostedt Challenger.png'),
  ('Gauteng Challenger','Tournament Logos/August/Gauteng Challenger.png'),
  ('Grodzisk Mazowiecki Challenger','Tournament Logos/August/Grodzisk Mazowiecki Challenger.png'),
  ('Kano Challenger','Tournament Logos/August/Kano Challenger.png'),
  ('Lexington Challenger','Tournament Logos/August/Lexington Challenger.png'),
  ('Omaha Challenger','Tournament Logos/August/Omaha Challenger.png'),
  ('Sendai Challenger','Tournament Logos/August/Sendai Challenger.png'),
  ('Temuco Challenger','Tournament Logos/August/Temuco Challenger.png'),
  ('Istanbul Bosphorus Challenger','Tournament Logos/August/Istanbul Bosphorus Challenger.png'),
  ('Sunshine Coast Futures','Tournament Logos/August/Sunshine Coast Futures.png');

do $$
declare v_expected integer := 58; v_series integer; v_objects integer;
begin
  select count(*) into v_series from tmp_august_tournament_logos i join public.tournament_series ts on ts.name=i.name;
  if v_series <> v_expected then raise exception 'Expected % matching tournament series, found %.',v_expected,v_series; end if;
  select count(*) into v_objects from tmp_august_tournament_logos i join storage.objects o on o.bucket_id='Admin' and o.name=i.object_path;
  if v_objects <> v_expected then raise exception 'Expected % storage objects, found %.',v_expected,v_objects; end if;
end $$;

update public.tournament_series ts
set logo_url='https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/' || replace(i.object_path,' ','%20')
from tmp_august_tournament_logos i
where ts.name=i.name;
