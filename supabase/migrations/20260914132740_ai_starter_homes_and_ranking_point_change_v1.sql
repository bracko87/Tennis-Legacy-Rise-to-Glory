create or replace function public.ensure_private_life_starter_home_v1(p_player_id uuid)
returns uuid
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_player record;
  v_existing uuid;
  v_location public.private_life_property_locations%rowtype;
  v_location_code text;
  v_price bigint;
  v_owned_id uuid:=gen_random_uuid();
begin
  select id,owner_user_id,player_type,country_code,home_city
  into v_player
  from public.players
  where id=p_player_id;

  if v_player.id is null or v_player.home_city is null or btrim(v_player.home_city)='' then
    return null;
  end if;

  select id into v_existing
  from public.private_life_player_assets
  where player_id=p_player_id and catalog_code='apt_home_starter'
  order by created_at
  limit 1;

  if v_existing is not null then
    return v_existing;
  end if;

  select * into v_location
  from public.private_life_property_locations
  where active=true
    and upper(country_code)=upper(coalesce(v_player.country_code,''))
    and lower(city)=lower(v_player.home_city)
  limit 1;

  if v_location.code is null then
    v_location_code:='home_'||replace(p_player_id::text,'-','');
    insert into public.private_life_property_locations(
      code,country_code,country_name,city,apartment_base_price,house_base_price,
      annual_value_rate_bps,marketplace_enabled,active,sort_order
    ) values(
      v_location_code,upper(coalesce(v_player.country_code,'XX')),upper(coalesce(v_player.country_code,'XX')),
      v_player.home_city,120000,300000,225,false,true,9999
    ) on conflict (code) do nothing;
    select * into v_location from public.private_life_property_locations where code=v_location_code;
  end if;

  v_price:=greatest(1,round(v_location.apartment_base_price::numeric*0.60)::bigint);

  insert into public.private_life_player_assets(
    id,player_id,catalog_code,location_code,acquisition_type,purchase_absolute_day,purchase_price,
    annual_running_cost_override,annual_value_rate_bps_override,resale_discount_bps_override,
    prestige_override,trade_locked
  ) values(
    v_owned_id,p_player_id,'apt_home_starter',v_location.code,'starter_home',0,v_price,
    0,v_location.annual_value_rate_bps,1200,0,(v_player.player_type='ai')
  );

  return v_owned_id;
end;
$function$;

revoke all on function public.ensure_private_life_starter_home_v1(uuid) from public, anon, authenticated;
grant execute on function public.ensure_private_life_starter_home_v1(uuid) to service_role;

do $backfill$
declare r record;
begin
  for r in select id from public.players where player_type='ai' loop
    perform public.ensure_private_life_starter_home_v1(r.id);
  end loop;
end;
$backfill$;

create or replace function public.get_world_rankings_v3(
  p_world text,
  p_offset integer default 0,
  p_limit integer default 50
)
returns table(
  rank_position bigint,
  player_id uuid,
  first_name text,
  last_name text,
  country_code text,
  image_path text,
  ranking_points integer,
  previous_week_position integer,
  rank_change integer,
  previous_week_points integer,
  points_change integer
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with publication_days as (
    select game_absolute_day,
           row_number() over (order by game_absolute_day desc) as rn
    from (
      select distinct game_absolute_day
      from public.ranking_publication_runs
    ) d
  ),
  previous_publication as (
    select game_absolute_day
    from publication_days
    where rn=2
  ),
  ranked as (
    select
      row_number() over (
        order by coalesce(r.ranking_points,0) desc,
                 coalesce(r.seed_rating,0) desc,
                 p.created_at asc,
                 p.id asc
      ) as rank_position,
      p.id as player_id,
      p.first_name,
      p.last_name,
      p.country_code,
      p.image_path,
      coalesce(r.ranking_points,0)::integer as ranking_points
    from public.players p
    left join public.player_rankings r on r.player_id=p.id
    where p.world=upper(p_world)
      and p.moderation_status<>'rejected'
  )
  select
    ranked.rank_position,
    ranked.player_id,
    ranked.first_name,
    ranked.last_name,
    ranked.country_code,
    ranked.image_path,
    ranked.ranking_points,
    previous_snapshot.ranking_position::integer as previous_week_position,
    case
      when previous_snapshot.ranking_position is null then null
      else (previous_snapshot.ranking_position-ranked.rank_position)::integer
    end as rank_change,
    previous_snapshot.ranking_points::integer as previous_week_points,
    case
      when previous_snapshot.ranking_points is null then null
      else (ranked.ranking_points-previous_snapshot.ranking_points)::integer
    end as points_change
  from ranked
  left join lateral (
    select s.ranking_position,s.ranking_points
    from public.player_ranking_snapshots s
    where s.player_id=ranked.player_id
      and s.world=upper(p_world)
      and s.game_absolute_day=(select game_absolute_day from previous_publication)
    order by s.created_at desc
    limit 1
  ) previous_snapshot on true
  order by ranked.rank_position
  offset greatest(coalesce(p_offset,0),0)
  limit least(greatest(coalesce(p_limit,50),1),100);
$function$;

revoke all on function public.get_world_rankings_v3(text,integer,integer) from public, anon;
grant execute on function public.get_world_rankings_v3(text,integer,integer) to authenticated, service_role;
