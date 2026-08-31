alter table public.tournament_series
  add column if not exists logo_url text;

update public.tournament_series as s
set logo_url = v.logo_url
from (values
  ('Brisbane Open', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Brisbane%20Open.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvQnJpc2JhbmUgT3Blbi5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg4MTkzNzEzLCJleHAiOjQ5MTAyNTc3MTN9.5OT3Th7QrCdcNzpOqCDh5UC9-1rsY5b-RSbIOMCZ-tZ0qhuzcuNFSGdPous9HRjFkldR0_ofHj0P9DTGBTjQTA'),
  ('Auckland Open', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Auckland%20Open.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvQXVja2xhbmQgT3Blbi5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg4MTkzNzIyLCJleHAiOjQ5MTAyNTc3MjJ9.Jcd3MBNDoiO_caWR1wztQGjpve47B9QGOx85NsGulkfFvIo-MQTjUhtaZCaei7roCxCD9pEjhxUBmKF-KmYzSA'),
  ('Hong Kong Open', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Hong%20Kong%20Open.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvSG9uZyBLb25nIE9wZW4ucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc4ODE5MzczMiwiZXhwIjo0OTEwMjU3NzMyfQ.NkKyTAqSXkcr09ZHVbaYDHbqTOeQ9cmTyaJRok_LFly-eQvQakFZI-OjprDAviPmXuBrT_U55Vw6lbJxvYTZ-g'),
  ('Bengaluru Challenger', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Bengalu%20Challenger.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvQmVuZ2FsdSBDaGFsbGVuZ2VyLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgxOTM3NDMsImV4cCI6NDkxMDI1Nzc0M30.v8IzrQDoSoIbqGxIddfMxWZYQyUX3gX1-9ivvHtRAmiy71NqynrowFBVZTGgjGPzJppCW2uUgV2ouq4iyGgPMw'),
  ('Canberra Challenger', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Canberra%20Challenger.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvQ2FuYmVycmEgQ2hhbGxlbmdlci5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg4MTkzNzU3LCJleHAiOjQ5MTAyNTc3NTd9.FunY53xVu1Gm9utk3TeKYZLmt9LHBAhtJR0xK-lNsLArCQ2M_NM0p2JJ7HygQ1c4MenxdyHcUfTWpW1u-hbycg'),
  ('Cape Town Challenger', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Cape%20Town%20Challenger.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvQ2FwZSBUb3duIENoYWxsZW5nZXIucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc4ODE5Mzc2OSwiZXhwIjo0OTEwMjU3NzY5fQ.5rMTO6FKWGoA0Z-K4nbZPP8V6P-5I8CWaCV_5z-UUG7EmIRHfYCucGsFn_31bLF68wnJoVuvO1VyiF_5rFfH5w'),
  ('Nouméa Challenger', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Noumea%20Challenger%2075.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvTm91bWVhIENoYWxsZW5nZXIgNzUucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc4ODE5Mzc5NCwiZXhwIjo0OTEwMjU3Nzk0fQ.deO19gv90bGSc3Hpr8M4ujBeFqyZmrGLWz2LrbiZa2GH5wvo3a9P5MURCBaLCGn3Jks3_RhcuhGuKrKYWKn-ow'),
  ('Nonthaburi Challenger', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Nonthaburi%20Challenger.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvTm9udGhhYnVyaSBDaGFsbGVuZ2VyLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgxOTM4MDUsImV4cCI6NDkxMDI1NzgwNX0.hyh_4KHab7lt8_cMRQwWcqBFRIdubaU8ExUThONGA1NhZpLqBSV52ovWo3mF35HcWlWCliHyMiD3NVKVxA27Xg'),
  ('Nottingham Challenger', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Nothingham%20Challenger.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvTm90aGluZ2hhbSBDaGFsbGVuZ2VyLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgxOTM4MjcsImV4cCI6NDkxMDI1NzgyN30.5mflMUKYpcj9dHA3fZQtgcMnfGco7KXbn2wNJnnXZOwHL5k6BR0OMCQcRCPwP8ZihcVQhdTzekcPE_n3kaSI9g'),
  ('Orlando Futures', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Orlando%20Futures.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvT3JsYW5kbyBGdXR1cmVzLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgxOTM4NDAsImV4cCI6NDkxMDI1Nzg0MH0.ISjQI0EmTod42--Tr77Z-G6d7lIb7dIn2x_Ij5xYAN-j5qNSVyqECLSJWtEpv3fUpYymQNDXI8pEVJrt2TCbrA'),
  ('Melbourne Grand Championship', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Melbourne%20Grand%20Championship.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvTWVsYm91cm5lIEdyYW5kIENoYW1waW9uc2hpcC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg4MTkzOTkxLCJleHAiOjQ5MTAyNTc5OTF9.iGJ0cMALWkDtoqtlAnAUCaASQP42ipze1XmwiUbRGGNPYSOcfWJQRk4zOXQxO3NWNvvM8e_crtQ9KwplKW9_rQ'),
  ('Adelaide Open', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Adelaide%20Open.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvQWRlbGFpZGUgT3Blbi5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg4MTk0MDA0LCJleHAiOjQ5MTAyNTgwMDR9.YXiN0Bq6zNQAbKxRXsT41OeJIl-zykq9WZ1VsBXmE3cpyMCapH1SaFhanWkieTM5XS3IlH-LcFWeuXzWuuJ4EA'),
  ('Hobart Open', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Hobart%20open.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvSG9iYXJ0IG9wZW4ucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc4ODE5NDAxOSwiZXhwIjo0OTEwMjU4MDE5fQ.c0fTOxKdcXEa9FGfMadiwboMnwl70MX9OofJrAHdd4xxv-W-p2tHodSEwEuCAx305vMYhfd-wQLqYHlxOupnkw'),
  ('Marrakech Challenger', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Marrkakech%20Challenger.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvTWFycmtha2VjaCBDaGFsbGVuZ2VyLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgxOTQwMzEsImV4cCI6NDkxMDI1ODAzMX0.EYbqRsRwOh7Wo8tC5-MOmphEXTUFZ-t9KBRQWNpoq_hah0EJJcEWTCITzQfxPYnMATRY327YVll5PS6i_hoBWA'),
  ('Thailand Challenger', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Thailand%20Challenger.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvVGhhaWxhbmQgQ2hhbGxlbmdlci5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg4MTk0MTUxLCJleHAiOjQ5MTAyNTgxNTF9.awq6cuX2Pf5Q6P0bIOf6HyXpGCjPcmhmiXTRA4ee6hAVihkux3CPfyomgUGPswqU1yiytqsQ6XhNW_Q3If2Ekg'),
  ('Buenos Aires Challenger', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Buenos%20Aires%20Challenger.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvQnVlbm9zIEFpcmVzIENoYWxsZW5nZXIucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc4ODE5NDA3NywiZXhwIjo0OTEwMjU4MDc3fQ.8vJCBVlmXCmnAv5gWvftm97IhC-A81_igAbefxVIYsjxBlIHxdtt2Vz7uoulog-6JZwbg2GpFrEzqWldSrwWNg'),
  ('Glasgow Challenger', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Glasgow%20Challenger.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvR2xhc2dvdyBDaGFsbGVuZ2VyLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgxOTQwODksImV4cCI6NDkxMDI1ODA4OX0.yaDlq7fiOsniourlfh8dBuAdq4vGCkJOjc93cTbApytniBJyNrJ-CrKq3wUNG_zHglBJfo06pO_xxw2kY4VwHg'),
  ('Winston-Salem Futures', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Winston%20Salem%20Futures.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvV2luc3RvbiBTYWxlbSBGdXR1cmVzLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgxOTQxMDEsImV4cCI6NDkxMDI1ODEwMX0.zG97WQYfHPTZ1PNKG8Ucoh9aRURQGKB_QPno0aci0FdJKAiQhbrBMh2UG4s-qaIr5isIwexDuFxSssen6oimCQ'),
  ('Manacor Futures', 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Manacor%20Futures.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvTWFuYWNvciBGdXR1cmVzLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgxOTQxMTMsImV4cCI6NDkxMDI1ODExM30.NEJfvtHFhlIKH-ujrhE08mxb0kjNeqvBu0i8Wgg-XLQmCAU0PT2uTP_AmNlfG8iCwyhjTxM0NCXWvBi2FZU18Q')
) as v(name, logo_url)
where s.name = v.name;

drop function if exists public.get_tournament_detail_v1(uuid);
create function public.get_tournament_detail_v1(p_competition_id uuid)
returns table (
  competition_id uuid, tournament_id uuid, edition_id uuid, world text,
  competition_status text, season_number integer, tournament_name text,
  logo_url text, city text, country_code text, country_name text,
  category_code text, category_label text, winner_points integer,
  main_draw_capacity integer, qualifying_capacity_max integer,
  default_qualifier_slots integer, competition_weeks smallint,
  qualification_rounds_max smallint, main_draw_rounds smallint,
  qualification_rest_day_first boolean, main_draw_rest_day_first boolean,
  one_match_per_player_per_day boolean, same_city_for_qualification boolean,
  surface text, environment text, schedule_slots jsonb
)
language sql stable security invoker set search_path = public
as $$
  select wc.id, s.id, e.id, wc.world, wc.status, e.season_number,
    s.name, s.logo_url, s.city, s.country_code, co.name, c.code, c.label,
    c.winner_points, c.main_draw_capacity, c.qualifying_capacity_max,
    c.default_qualifier_slots, c.competition_weeks, c.qualification_rounds_max,
    c.main_draw_rounds, c.qualification_rest_day_first,
    c.main_draw_rest_day_first, c.one_match_per_player_per_day,
    c.same_city_for_qualification, s.surface, s.environment,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'season_week', sl.season_week,
        'calendar_month', sl.calendar_month,
        'month_week', sl.month_week,
        'phase', sl.phase,
        'slot_order', sl.slot_order
      ) order by sl.season_week, sl.slot_order)
      from public.tournament_schedule_slots sl
      where sl.tournament_edition_id = e.id
    ), '[]'::jsonb)
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id = wc.tournament_edition_id
  join public.tournament_series s on s.id = e.tournament_series_id and s.is_active
  join public.tournament_categories c on c.code = s.category_code
  join public.countries co on co.code = s.country_code
  where wc.id = p_competition_id
    and wc.status <> 'canceled'
    and e.status <> 'canceled';
$$;
revoke execute on function public.get_tournament_detail_v1(uuid) from public, anon;
grant execute on function public.get_tournament_detail_v1(uuid) to authenticated;
