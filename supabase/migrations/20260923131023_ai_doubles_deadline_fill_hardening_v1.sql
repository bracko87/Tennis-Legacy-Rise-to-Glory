
create or replace function public.pair_ai_doubles_teams_v1(p_competition_id uuid)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
  v_draw_size integer;
  v_world text;
  v_existing integer;
  v_needed integer;
  v_p1 uuid;
  v_p2 uuid;
  v_team uuid;
  v_created integer:=0;
begin
  select ds.draw_size,wc.world into v_draw_size,v_world
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id
  where wc.id=p_competition_id and ds.is_enabled;

  if v_draw_size is null then return 0; end if;

  select count(*) into v_existing
  from public.tournament_doubles_teams
  where competition_id=p_competition_id
    and status in ('confirmed','active','alternate');

  v_needed:=greatest(0,v_draw_size-v_existing);

  while v_needed>0 loop
    v_p1:=null;
    v_p2:=null;

    select l.player_id into v_p1
    from public.tournament_doubles_partner_listings l
    join public.players p on p.id=l.player_id
    where l.competition_id=p_competition_id
      and l.status='active'
      and p.player_type='ai'
      and not exists(
        select 1 from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
    order by public.get_doubles_player_entry_strength_v1(p.id,p_competition_id) desc,p.id
    limit 1;

    if v_p1 is null then
      select p.id into v_p1
      from public.players p
      left join public.player_rankings pr on pr.player_id=p.id
      where p.world=v_world
        and p.player_type='ai'
        and p.moderation_status<>'rejected'
        and coalesce((public.check_player_competition_availability_v1(p.id,p_competition_id)->>'available')::boolean,false)
        and not exists(
          select 1 from public.tournament_doubles_teams t
          where t.competition_id=p_competition_id
            and t.status in ('confirmed','active','alternate')
            and (t.player1_id=p.id or t.player2_id=p.id)
        )
      order by
        case when exists(
          select 1 from public.tournament_entries te
          where te.competition_id=p_competition_id and te.player_id=p.id
            and te.entry_status='active' and te.draw_type='qualification'
        ) then 0
        when exists(
          select 1 from public.tournament_entries te
          where te.competition_id=p_competition_id and te.player_id=p.id and te.entry_status='active'
        ) then 1 else 2 end,
        coalesce(pr.ranking_points,0) asc,p.id
      limit 1;
    end if;

    exit when v_p1 is null;

    select l.player_id into v_p2
    from public.tournament_doubles_partner_listings l
    join public.players p on p.id=l.player_id
    where l.competition_id=p_competition_id
      and l.status='active'
      and p.player_type='ai'
      and l.player_id<>v_p1
      and not exists(
        select 1 from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
    order by public.get_doubles_player_entry_strength_v1(p.id,p_competition_id) desc,p.id
    limit 1;

    if v_p2 is null then
      select p.id into v_p2
      from public.players p
      left join public.player_rankings pr on pr.player_id=p.id
      where p.world=v_world
        and p.player_type='ai'
        and p.id<>v_p1
        and p.moderation_status<>'rejected'
        and coalesce((public.check_player_competition_availability_v1(p.id,p_competition_id)->>'available')::boolean,false)
        and not exists(
          select 1 from public.tournament_doubles_teams t
          where t.competition_id=p_competition_id
            and t.status in ('confirmed','active','alternate')
            and (t.player1_id=p.id or t.player2_id=p.id)
        )
      order by
        case when exists(
          select 1 from public.tournament_entries te
          where te.competition_id=p_competition_id and te.player_id=p.id
            and te.entry_status='active' and te.draw_type='qualification'
        ) then 0
        when exists(
          select 1 from public.tournament_entries te
          where te.competition_id=p_competition_id and te.player_id=p.id and te.entry_status='active'
        ) then 1 else 2 end,
        coalesce(pr.ranking_points,0) asc,p.id
      limit 1;
    end if;

    exit when v_p2 is null;

    begin
      v_team:=public.create_doubles_team_internal_v1(
        p_competition_id,v_p1,v_p2,'ai_marketplace'
      );

      update public.tournament_doubles_partner_listings
      set status='matched',closed_at=now(),updated_at=now()
      where competition_id=p_competition_id
        and player_id in (v_p1,v_p2)
        and status='active';

      v_created:=v_created+1;
      v_needed:=v_needed-1;
    exception when others then
      update public.tournament_doubles_partner_listings
      set status='expired',closed_at=now(),updated_at=now()
      where competition_id=p_competition_id
        and player_id in (v_p1,v_p2)
        and status='active';
      exit;
    end;
  end loop;

  return v_created;
end;
$$;
revoke all on function public.pair_ai_doubles_teams_v1(uuid) from public,anon,authenticated;
grant execute on function public.pair_ai_doubles_teams_v1(uuid) to service_role;

