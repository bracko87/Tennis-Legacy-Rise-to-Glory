update public.tournament_series
set name = case name
  when 'Nonthaburi Challenger II' then 'Thailand Challenger'
  when 'Phan Thiết Challenger II' then 'Bình Thuận Challenger'
  when 'Cape Town Challenger II' then 'Western Cape Challenger'
  when 'Brisbane Challenger II' then 'Queensland Challenger'
  when 'Chennai Challenger II' then 'Tamil Nadu Challenger'
  when 'Tenerife Challenger II' then 'Canary Islands Challenger'
  when 'Antalya Futures II' then 'Türkiye Futures'
  when 'Monastir Futures II' then 'Tunisia Futures'
  when 'Tigre Challenger II' then 'Buenos Aires Province Challenger'
  else name
end,
slug = case name
  when 'Nonthaburi Challenger II' then 'thailand-challenger'
  when 'Phan Thiết Challenger II' then 'binh-thuan-challenger'
  when 'Cape Town Challenger II' then 'western-cape-challenger'
  when 'Brisbane Challenger II' then 'queensland-challenger'
  when 'Chennai Challenger II' then 'tamil-nadu-challenger'
  when 'Tenerife Challenger II' then 'canary-islands-challenger'
  when 'Antalya Futures II' then 'turkiye-futures'
  when 'Monastir Futures II' then 'tunisia-futures'
  when 'Tigre Challenger II' then 'buenos-aires-province-challenger'
  else slug
end
where name in (
  'Nonthaburi Challenger II',
  'Phan Thiết Challenger II',
  'Cape Town Challenger II',
  'Brisbane Challenger II',
  'Chennai Challenger II',
  'Tenerife Challenger II',
  'Antalya Futures II',
  'Monastir Futures II',
  'Tigre Challenger II'
);

create unique index if not exists tournament_series_name_ci_unique
  on public.tournament_series (lower(btrim(name)));

comment on index public.tournament_series_name_ci_unique is
  'Tournament series names must be globally unique, case-insensitively. Repeated events in the same city/country must use a distinct tournament identity rather than II/III numbering.';
