with seed(slug, name, city, country_code, category_code, surface, environment, month_week) as (
  values
    ('mediterranean-indoor-open','Mediterranean Indoor Open','Montpellier','FR','tour_250','hard','indoor',1),
    ('emirates-desert-open','Emirates Desert Open','Abu Dhabi','AE','tour_500','hard','outdoor',1),
    ('rosario-summer-open','Rosario Summer Open','Rosario','AR','tour_250','clay','outdoor',1),
    ('brisbane-summer-challenger','Brisbane Summer Challenger','Brisbane','AU','challenger_125','hard','outdoor',1),
    ('cleveland-lakes-challenger','Cleveland Lakes Challenger','Cleveland','US','challenger_100','hard','indoor',1),
    ('tenerife-atlantic-challenger','Tenerife Atlantic Challenger','Tenerife','ES','challenger_75','hard','outdoor',1),
    ('cape-town-summer-challenger','Cape Town Summer Challenger','Cape Town','ZA','challenger_75','hard','outdoor',1),
    ('chennai-coast-challenger','Chennai Coast Challenger','Chennai','IN','challenger_75','hard','outdoor',1),
    ('nairobi-equator-futures','Nairobi Equator Futures','Nairobi','KE','futures_25','hard','outdoor',1),
    ('lima-summer-futures','Lima Summer Futures','Lima','PE','futures_25','clay','outdoor',1),

    ('doha-pearl-masters','Doha Pearl Masters','Doha','QA','masters_1000','hard','outdoor',2),
    ('rotterdam-harbour-open','Rotterdam Harbour Open','Rotterdam','NL','tour_500','hard','indoor',2),
    ('dallas-continental-open','Dallas Continental Open','Dallas','US','tour_500','hard','indoor',2),
    ('buenos-aires-clay-championship','Buenos Aires Clay Championship','Buenos Aires','AR','tour_250','clay','outdoor',2),
    ('pyrenees-indoor-challenger','Pyrenees Indoor Challenger','Pau','FR','challenger_125','hard','indoor',2),
    ('tenerife-atlantic-challenger-ii','Tenerife Atlantic Challenger II','Tenerife','ES','challenger_75','hard','outdoor',2),
    ('brisbane-summer-challenger-ii','Brisbane Summer Challenger II','Brisbane','AU','challenger_75','hard','outdoor',2),
    ('chennai-coast-challenger-ii','Chennai Coast Challenger II','Chennai','IN','challenger_75','hard','outdoor',2),
    ('casablanca-winter-challenger','Casablanca Winter Challenger','Casablanca','MA','challenger_50','clay','outdoor',2),
    ('seoul-winter-futures','Seoul Winter Futures','Seoul','KR','futures_25','hard','indoor',2),

    ('rio-coastal-championship','Rio Coastal Championship','Rio de Janeiro','BR','tour_500','clay','outdoor',3),
    ('florida-atlantic-open','Florida Atlantic Open','Delray Beach','US','tour_250','hard','outdoor',3),
    ('lille-northern-challenger','Lille Northern Challenger','Lille','FR','challenger_125','hard','indoor',3),
    ('delhi-capital-challenger','Delhi Capital Challenger','New Delhi','IN','challenger_100','hard','outdoor',3),
    ('mexico-highlands-challenger','Mexico Highlands Challenger','Metepec','MX','challenger_75','hard','outdoor',3),
    ('tigre-river-challenger','Tigre River Challenger','Tigre','AR','challenger_75','clay','outdoor',3),
    ('kigali-highlands-challenger','Kigali Highlands Challenger','Kigali','RW','challenger_75','clay','outdoor',3),
    ('sydney-harbour-challenger','Sydney Harbour Challenger','Sydney','AU','challenger_75','hard','outdoor',3),
    ('monastir-mediterranean-futures','Monastir Mediterranean Futures','Monastir','TN','futures_25','hard','outdoor',3),
    ('antalya-coast-futures','Antalya Coast Futures','Antalya','TR','futures_15','clay','outdoor',3),

    ('dubai-crown-championship','Dubai Crown Championship','Dubai','AE','tour_500','hard','outdoor',4),
    ('acapulco-pacific-open','Acapulco Pacific Open','Acapulco','MX','tour_500','hard','outdoor',4),
    ('santiago-andes-open','Santiago Andes Open','Santiago','CL','tour_250','clay','outdoor',4),
    ('merida-peninsula-open','Mérida Peninsula Open','Mérida','MX','tour_250','hard','outdoor',4),
    ('brittany-indoor-challenger-saint-brieuc','Brittany Indoor Challenger','Saint-Brieuc','FR','challenger_125','hard','indoor',4),
    ('pune-maharashtra-challenger','Pune Maharashtra Challenger','Pune','IN','challenger_100','hard','outdoor',4),
    ('lugano-alpine-challenger','Lugano Alpine Challenger','Lugano','CH','challenger_75','hard','indoor',4),
    ('burnie-island-challenger','Burnie Island Challenger','Burnie','AU','challenger_75','hard','outdoor',4),
    ('johannesburg-highveld-challenger','Johannesburg Highveld Challenger','Johannesburg','ZA','challenger_75','hard','outdoor',4),
    ('tigre-river-challenger-ii','Tigre River Challenger II','Tigre','AR','challenger_50','clay','outdoor',4)
)
insert into public.tournament_series (slug, name, city, country_code, category_code, surface, environment)
select slug, name, city, country_code, category_code, surface, environment
from seed
on conflict (slug) do update set
  name = excluded.name,
  city = excluded.city,
  country_code = excluded.country_code,
  category_code = excluded.category_code,
  surface = excluded.surface,
  environment = excluded.environment,
  is_active = true;

with seed(slug) as (
  values
    ('mediterranean-indoor-open'),('emirates-desert-open'),('rosario-summer-open'),('brisbane-summer-challenger'),('cleveland-lakes-challenger'),('tenerife-atlantic-challenger'),('cape-town-summer-challenger'),('chennai-coast-challenger'),('nairobi-equator-futures'),('lima-summer-futures'),
    ('doha-pearl-masters'),('rotterdam-harbour-open'),('dallas-continental-open'),('buenos-aires-clay-championship'),('pyrenees-indoor-challenger'),('tenerife-atlantic-challenger-ii'),('brisbane-summer-challenger-ii'),('chennai-coast-challenger-ii'),('casablanca-winter-challenger'),('seoul-winter-futures'),
    ('rio-coastal-championship'),('florida-atlantic-open'),('lille-northern-challenger'),('delhi-capital-challenger'),('mexico-highlands-challenger'),('tigre-river-challenger'),('kigali-highlands-challenger'),('sydney-harbour-challenger'),('monastir-mediterranean-futures'),('antalya-coast-futures'),
    ('dubai-crown-championship'),('acapulco-pacific-open'),('santiago-andes-open'),('merida-peninsula-open'),('brittany-indoor-challenger-saint-brieuc'),('pune-maharashtra-challenger'),('lugano-alpine-challenger'),('burnie-island-challenger'),('johannesburg-highveld-challenger'),('tigre-river-challenger-ii')
)
insert into public.tournament_editions (tournament_series_id, season_number)
select ts.id, 1
from seed s
join public.tournament_series ts on ts.slug = s.slug
on conflict (tournament_series_id, season_number) do nothing;

with seed(slug, month_week) as (
  values
    ('mediterranean-indoor-open',1),('emirates-desert-open',1),('rosario-summer-open',1),('brisbane-summer-challenger',1),('cleveland-lakes-challenger',1),('tenerife-atlantic-challenger',1),('cape-town-summer-challenger',1),('chennai-coast-challenger',1),('nairobi-equator-futures',1),('lima-summer-futures',1),
    ('doha-pearl-masters',2),('rotterdam-harbour-open',2),('dallas-continental-open',2),('buenos-aires-clay-championship',2),('pyrenees-indoor-challenger',2),('tenerife-atlantic-challenger-ii',2),('brisbane-summer-challenger-ii',2),('chennai-coast-challenger-ii',2),('casablanca-winter-challenger',2),('seoul-winter-futures',2),
    ('rio-coastal-championship',3),('florida-atlantic-open',3),('lille-northern-challenger',3),('delhi-capital-challenger',3),('mexico-highlands-challenger',3),('tigre-river-challenger',3),('kigali-highlands-challenger',3),('sydney-harbour-challenger',3),('monastir-mediterranean-futures',3),('antalya-coast-futures',3),
    ('dubai-crown-championship',4),('acapulco-pacific-open',4),('santiago-andes-open',4),('merida-peninsula-open',4),('brittany-indoor-challenger-saint-brieuc',4),('pune-maharashtra-challenger',4),('lugano-alpine-challenger',4),('burnie-island-challenger',4),('johannesburg-highveld-challenger',4),('tigre-river-challenger-ii',4)
)
insert into public.tournament_schedule_slots (tournament_edition_id, calendar_month, month_week, phase, slot_order)
select e.id, 2, s.month_week, 'full', 1
from seed s
join public.tournament_series ts on ts.slug = s.slug
join public.tournament_editions e on e.tournament_series_id = ts.id and e.season_number = 1
on conflict (tournament_edition_id, calendar_month, month_week, phase) do nothing;

with seed(slug) as (
  values
    ('mediterranean-indoor-open'),('emirates-desert-open'),('rosario-summer-open'),('brisbane-summer-challenger'),('cleveland-lakes-challenger'),('tenerife-atlantic-challenger'),('cape-town-summer-challenger'),('chennai-coast-challenger'),('nairobi-equator-futures'),('lima-summer-futures'),
    ('doha-pearl-masters'),('rotterdam-harbour-open'),('dallas-continental-open'),('buenos-aires-clay-championship'),('pyrenees-indoor-challenger'),('tenerife-atlantic-challenger-ii'),('brisbane-summer-challenger-ii'),('chennai-coast-challenger-ii'),('casablanca-winter-challenger'),('seoul-winter-futures'),
    ('rio-coastal-championship'),('florida-atlantic-open'),('lille-northern-challenger'),('delhi-capital-challenger'),('mexico-highlands-challenger'),('tigre-river-challenger'),('kigali-highlands-challenger'),('sydney-harbour-challenger'),('monastir-mediterranean-futures'),('antalya-coast-futures'),
    ('dubai-crown-championship'),('acapulco-pacific-open'),('santiago-andes-open'),('merida-peninsula-open'),('brittany-indoor-challenger-saint-brieuc'),('pune-maharashtra-challenger'),('lugano-alpine-challenger'),('burnie-island-challenger'),('johannesburg-highveld-challenger'),('tigre-river-challenger-ii')
)
insert into public.tournament_world_competitions (tournament_edition_id, world)
select e.id, w.world
from seed s
join public.tournament_series ts on ts.slug = s.slug
join public.tournament_editions e on e.tournament_series_id = ts.id and e.season_number = 1
cross join (values ('ATP'), ('WTA')) as w(world)
on conflict (tournament_edition_id, world) do nothing;
