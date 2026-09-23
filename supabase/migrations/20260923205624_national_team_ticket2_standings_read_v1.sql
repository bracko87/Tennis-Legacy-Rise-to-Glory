
create or replace function public.get_my_national_division_standings_v1()
returns table(
  rank_position integer,
  association_id uuid,
  association_name text,
  country_code text,
  ties_played integer,
  ties_won integer,
  ties_lost integer,
  matches_won integer,
  matches_lost integer,
  standings_points integer,
  is_my_association boolean
)
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  v_assoc uuid;
  v_division uuid;
  v_season integer:=public.national_team_current_season_v1();
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_player
  from public.players
  where owner_user_id=v_uid
  limit 1;

  if v_player.id is null then return; end if;

  select a.id into v_assoc
  from public.national_associations a
  where a.world=v_player.world and a.country_code=v_player.country_code
  limit 1;

  select e.division_id into v_division
  from public.national_team_division_entries e
  where e.association_id=v_assoc
    and e.season_number=v_season
    and e.status in ('active','completed')
  limit 1;

  if v_division is null then return; end if;

  return query
  select
    row_number() over(
      order by
        coalesce(s.standings_points,0) desc,
        coalesce(s.ties_won,0) desc,
        (coalesce(s.matches_won,0)-coalesce(s.matches_lost,0)) desc,
        coalesce(s.matches_won,0) desc,
        a.country_code
    )::integer,
    a.id,
    a.name,
    a.country_code,
    coalesce(s.ties_played,0),
    coalesce(s.ties_won,0),
    coalesce(s.ties_lost,0),
    coalesce(s.matches_won,0),
    coalesce(s.matches_lost,0),
    coalesce(s.standings_points,0),
    a.id=v_assoc
  from public.national_team_division_entries e
  join public.national_associations a on a.id=e.association_id
  left join public.national_team_division_standings s
    on s.division_id=e.division_id
   and s.season_number=e.season_number
   and s.association_id=e.association_id
  where e.division_id=v_division
    and e.season_number=v_season
    and e.status in ('active','completed')
  order by 1;
end;
$$;

revoke execute on function public.get_my_national_division_standings_v1() from anon;
grant execute on function public.get_my_national_division_standings_v1() to authenticated;
