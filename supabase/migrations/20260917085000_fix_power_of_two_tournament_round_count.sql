-- Fix tournament round-count calculation for exact powers of two (64, 128, ...).
-- Using ln(size)/ln(2) produced tiny floating-point overages such as
-- 64 -> 6.0000000000000001, so ceil() incorrectly returned 7 and blocked draw publication.
-- Replace the affected calculations with PostgreSQL's base-2 numeric log().

do $$
declare
  v_def text;
begin
  select pg_get_functiondef('public.publish_tournament_draw_v1(uuid)'::regprocedure) into v_def;
  if position('ceil(ln(greatest(v_main_size,2)::numeric)/ln(2::numeric))::integer' in v_def)=0 then
    raise exception 'Expected round-count expression not found in publish_tournament_draw_v1';
  end if;
  v_def := replace(v_def,
    'ceil(ln(greatest(v_main_size,2)::numeric)/ln(2::numeric))::integer',
    'ceil(log(2::numeric,greatest(v_main_size,2)::numeric))::integer');
  execute v_def;

  select pg_get_functiondef('public.advance_tournament_bracket_v1()'::regprocedure) into v_def;
  if position('ceil(ln(greatest(new.bracket_size,2)::numeric)/ln(2::numeric))::smallint' in v_def)=0 then
    raise exception 'Expected round-count expression not found in advance_tournament_bracket_v1';
  end if;
  v_def := replace(v_def,
    'ceil(ln(greatest(new.bracket_size,2)::numeric)/ln(2::numeric))::smallint',
    'ceil(log(2::numeric,greatest(new.bracket_size,2)::numeric))::smallint');
  execute v_def;

  select pg_get_functiondef('public.default_tournament_match_day_v2(uuid,text,integer)'::regprocedure) into v_def;
  if position('ceil(ln(greatest(v_main_capacity,2)::numeric)/ln(2::numeric))::integer' in v_def)=0 then
    raise exception 'Expected round-count expression not found in default_tournament_match_day_v2';
  end if;
  v_def := replace(v_def,
    'ceil(ln(greatest(v_main_capacity,2)::numeric)/ln(2::numeric))::integer',
    'ceil(log(2::numeric,greatest(v_main_capacity,2)::numeric))::integer');
  execute v_def;
end $$;
