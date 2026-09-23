-- Harden Doubles Ticket 1 draw sizing and first-round seeding.
-- The configured doubles draw_size is a maximum capacity, not a forced bracket.
-- Actual draws scale to the smallest power of two that fits the selected teams,
-- and high-ranked teams receive byes before lower-ranked teams.

create or replace function public.publish_doubles_draw_v1(p_competition_id uuid)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  v_series uuid;
  v_enabled boolean;
  v_draw_max smallint;
  v_bracket smallint:=4;
  v_min smallint;
  v_count integer;
  v_selected integer;
  v_start_week integer;
  v_team record;
  v_ready record;
  v_rank integer:=0;
  v_match integer;
  v_id uuid;
  v_created integer:=0;
  v_seed_limit integer;
begin
  if exists(select 1 from public.tournament_doubles_draw_publications where competition_id=p_competition_id) then
    return jsonb_build_object('status','already_published');
  end if;

  select e.tournament_series_id,ds.is_enabled,ds.draw_size,ds.minimum_teams,min(ss.season_week)
  into v_series,v_enabled,v_draw_max,v_min,v_start_week
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=e.tournament_series_id
  join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
  where wc.id=p_competition_id
  group by e.tournament_series_id,ds.is_enabled,ds.draw_size,ds.minimum_teams;

  if coalesce(v_enabled,false)=false then
    raise exception 'Doubles is not enabled for this tournament.';
  end if;

  select count(*) into v_count
  from public.tournament_doubles_teams
  where competition_id=p_competition_id and status='confirmed';

  if v_count<v_min then
    return jsonb_build_object('status','insufficient_teams','team_count',v_count,'minimum_teams',v_min);
  end if;

  v_selected:=least(v_count,v_draw_max);

  while v_bracket<v_selected loop
    v_bracket:=(v_bracket*2)::smallint;
  end loop;
  v_bracket:=least(v_bracket,v_draw_max)::smallint;
  v_seed_limit:=least(8,greatest(1,v_bracket/4));

  update public.tournament_doubles_teams
  set status='alternate',seed_number=null,bracket_slot=null,updated_at=now()
  where competition_id=p_competition_id and status='confirmed';

  for v_team in
    select
      t.id,
      coalesce(r1.ranking_points,0)+coalesce(r2.ranking_points,0) pts
    from public.tournament_doubles_teams t
    left join public.player_doubles_rankings r1 on r1.player_id=t.player1_id
    left join public.player_doubles_rankings r2 on r2.player_id=t.player2_id
    where t.competition_id=p_competition_id and t.status='alternate'
    order by
      coalesce(r1.ranking_points,0)+coalesce(r2.ranking_points,0) desc,
      t.created_at,
      t.id
    limit v_selected
  loop
    v_rank:=v_rank+1;
    update public.tournament_doubles_teams
    set status='active',
        seed_number=case when v_rank<=v_seed_limit then v_rank::smallint else null end,
        bracket_slot=case
          when v_rank<=v_bracket/2 then (v_rank*2-1)::smallint
          else ((v_bracket-v_rank+1)*2)::smallint
        end,
        combined_ranking_points_snapshot=v_team.pts,
        updated_at=now()
    where id=v_team.id;
  end loop;

  insert into public.tournament_doubles_draw_publications(competition_id,bracket_size,team_count)
  values(p_competition_id,v_bracket,v_selected);

  for v_match in 1..(v_bracket/2) loop
    insert into public.tournament_doubles_matches(
      competition_id,round_number,round_label,match_number,bracket_size,
      scheduled_season_week,scheduled_day,team1_id,team2_id,status
    )
    values(
      p_competition_id,
      1,
      public.doubles_round_label_v1(v_bracket,1),
      v_match,
      v_bracket,
      v_start_week,
      1,
      (select id from public.tournament_doubles_teams
       where competition_id=p_competition_id and status='active' and bracket_slot=v_match*2-1),
      (select id from public.tournament_doubles_teams
       where competition_id=p_competition_id and status='active' and bracket_slot=v_match*2),
      'scheduled'
    )
    returning id into v_id;
    v_created:=v_created+1;
  end loop;

  update public.tournament_doubles_matches
  set status=case when team1_id is null and team2_id is null then 'cancelled' else 'bye' end,
      winner_team_id=case when (team1_id is null)<>(team2_id is null) then coalesce(team1_id,team2_id) else null end,
      completion_reason=case when (team1_id is null)<>(team2_id is null) then 'draw_bye' else 'empty_draw_slot' end,
      completed_at=now(),
      updated_at=now()
  where competition_id=p_competition_id
    and round_number=1
    and status='scheduled'
    and (team1_id is null or team2_id is null);

  for v_ready in
    select id
    from public.tournament_doubles_matches
    where competition_id=p_competition_id
      and round_number=1
      and status='scheduled'
      and team1_id is not null
      and team2_id is not null
  loop
    perform public.schedule_doubles_match_v1(v_ready.id);
  end loop;

  return jsonb_build_object(
    'status','published',
    'teams',v_selected,
    'bracket_size',v_bracket,
    'maximum_draw_size',v_draw_max,
    'first_round_matches',v_created,
    'byes',greatest(v_bracket-v_selected,0)
  );
end;
$$;

revoke all on function public.publish_doubles_draw_v1(uuid) from public,anon,authenticated;