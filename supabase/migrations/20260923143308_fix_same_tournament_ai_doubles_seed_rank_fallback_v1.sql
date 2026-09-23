
create or replace function public.seed_ai_doubles_partner_marketplace_v1(p_competition_id uuid)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
  v_world text;
  v_draw_size integer;
  v_minimum_teams integer;
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_eligible_count integer:=0;
  v_target integer:=0;
  v_inserted integer:=0;
begin
  select wc.world,ds.draw_size,ds.minimum_teams
  into v_world,v_draw_size,v_minimum_teams
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id
  where wc.id=p_competition_id
    and ds.is_enabled;

  if v_world is null then return 0; end if;

  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  if v_now<(v_timeline->>'registration_open_game_second')::bigint
     or v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint then
    return 0;
  end if;

  select count(distinct p.id)
  into v_eligible_count
  from public.players p
  where p.world=v_world
    and p.player_type='ai'
    and p.moderation_status<>'rejected'
    and (
      exists(
        select 1
        from public.tournament_entries te
        where te.competition_id=p_competition_id
          and te.player_id=p.id
          and te.entry_status='active'
      )
      or exists(
        select 1
        from public.tournament_applications ta
        where ta.competition_id=p_competition_id
          and ta.player_id=p.id
          and ta.status='applied'
      )
    )
    and not exists(
      select 1
      from public.tournament_doubles_teams t
      where t.competition_id=p_competition_id
        and t.status in ('confirmed','active','alternate')
        and (t.player1_id=p.id or t.player2_id=p.id)
    );

  if v_eligible_count=0 then return 0; end if;

  v_target:=least(
    v_eligible_count,
    coalesce(v_draw_size,16)*2,
    greatest(
      coalesce(v_minimum_teams,4)*2,
      ceil(v_eligible_count/2.0)::integer
    )
  );

  with candidates as (
    select
      p.id,
      coalesce(te.draw_type,'') as draw_type,
      coalesce(ta.accept_qualification,false) as accepts_qualification,
      coalesce(te.ranking_position_snapshot,ta.ranking_position_snapshot,999999) as ranking_position,
      ((hashtextextended(p.id::text||':'||p_competition_id::text,0)%100000)+100000)%100000 as hash_bucket
    from public.players p
    left join lateral (
      select te.draw_type,te.ranking_position_snapshot
      from public.tournament_entries te
      where te.competition_id=p_competition_id
        and te.player_id=p.id
        and te.entry_status='active'
      order by
        case te.draw_type when 'qualification' then 0 when 'main_draw' then 1 else 2 end,
        te.updated_at desc
      limit 1
    ) te on true
    left join lateral (
      select ta.accept_qualification,ta.ranking_position_snapshot
      from public.tournament_applications ta
      where ta.competition_id=p_competition_id
        and ta.player_id=p.id
        and ta.status='applied'
      order by ta.updated_at desc
      limit 1
    ) ta on true
    where p.world=v_world
      and p.player_type='ai'
      and p.moderation_status<>'rejected'
      and (te.draw_type is not null or ta.ranking_position_snapshot is not null)
      and not exists(
        select 1
        from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
      and coalesce(
        (public.check_player_competition_availability_v1(p.id,p_competition_id)->>'available')::boolean,
        false
      )
    order by
      case
        when te.draw_type='qualification' then 0
        when te.draw_type='main_draw' then 1
        when coalesce(ta.accept_qualification,false) then 2
        else 3
      end,
      coalesce(te.ranking_position_snapshot,ta.ranking_position_snapshot,999999) desc,
      hash_bucket,
      p.id
    limit v_target
  )
  insert into public.tournament_doubles_partner_listings(
    competition_id,player_id,owner_user_id,status,created_at,updated_at,closed_at
  )
  select p_competition_id,id,null,'active',now(),now(),null
  from candidates
  on conflict(competition_id,player_id) do update
  set owner_user_id=null,
      status=case
        when public.tournament_doubles_partner_listings.status='matched'
          then public.tournament_doubles_partner_listings.status
        else 'active'
      end,
      updated_at=now(),
      closed_at=case
        when public.tournament_doubles_partner_listings.status='matched'
          then public.tournament_doubles_partner_listings.closed_at
        else null
      end;

  get diagnostics v_inserted=row_count;
  return v_inserted;
end;
$$;

revoke all on function public.seed_ai_doubles_partner_marketplace_v1(uuid)
from public,anon,authenticated;
grant execute on function public.seed_ai_doubles_partner_marketplace_v1(uuid)
to service_role;

