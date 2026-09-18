create or replace function public.get_my_sponsor_tournament_objectives_v1(p_season integer)
returns table(
  competition_id uuid,
  objective_id uuid,
  tournament_name text,
  requirement_label text,
  reward_amount bigint,
  status text
)
language sql
stable
security definer
set search_path=public,pg_temp
as $function$
  select
    o.competition_id,
    o.id as objective_id,
    o.tournament_name,
    o.requirement_label,
    o.reward_amount,
    o.status
  from public.player_sponsor_objectives o
  join public.player_sponsor_contracts c
    on c.id=o.contract_id
   and c.player_id=o.player_id
  join public.players p
    on p.id=o.player_id
  where p.owner_user_id=auth.uid()
    and p.player_type='human'
    and c.season=p_season
    and c.status='active'
    and o.competition_id is not null
    and o.objective_code in ('tournament_appearance','tournament_result')
  order by o.start_absolute_day nulls last,o.id;
$function$;

revoke all on function public.get_my_sponsor_tournament_objectives_v1(integer) from public;
revoke all on function public.get_my_sponsor_tournament_objectives_v1(integer) from anon;
grant execute on function public.get_my_sponsor_tournament_objectives_v1(integer) to authenticated;

comment on function public.get_my_sponsor_tournament_objectives_v1(integer) is
  'Returns tournament-specific objectives from the authenticated player active main sponsor contract for calendar badges.';
