
create or replace function public.game_day_absolute_v1(
  p_season integer,
  p_month integer,
  p_day integer
)
returns integer
language sql
immutable
set search_path=public
as $$
  select public.game_day_absolute_v1(
    p_season,
    p_month::smallint,
    p_day::smallint
  );
$$;

revoke all on function public.game_day_absolute_v1(integer,integer,integer)
  from public,anon,authenticated;
