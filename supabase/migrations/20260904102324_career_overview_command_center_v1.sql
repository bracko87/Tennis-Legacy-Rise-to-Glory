create or replace function public.get_overview_dashboard_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  d record;
  v_abs integer;
  v_week smallint;
  v_rank integer;
  v_points integer:=0;
  v_stats jsonb;
  v_next_match jsonb;
  v_next_tournament jsonb;
  v_latest_result jsonb;
  v_today_tournaments jsonb;
  v_game_news jsonb;
  v_notifications jsonb;
  v_finance jsonb;
  v_training jsonb;
  v_equipment jsonb;
  v_club jsonb;
  v_staff jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_player
  from public.players
  where owner_user_id=v_uid and player_type='human'
  order by created_at desc
  limit 1;
  if v_player.id is null then raise exception 'Player not found.'; end if;

  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  select season_week into v_week from public.absolute_game_day_v1(v_abs);

  v_rank:=public.player_current_rank_position_v1(v_player.id);
  select coalesce(ranking_points,0) into v_points from public.player_rankings where player_id=v_player.id;

  select jsonb_build_object(
    'matches',count(*)::integer,
    'wins',count(*) filter(where f.won)::integer,
    'losses',count(*) filter(where not f.won)::integer,
    'win_pct',case when count(*)>0 then round(100.0*count(*) filter(where f.won)/count(*),1) else 0 end,
    'titles',count(*) filter(where f.won and lower(f.round_label)='final')::integer,
    'aces',coalesce(sum(s.aces),0)::bigint,
    'winners',coalesce(sum(s.winners),0)::bigint,
    'unforced_errors',coalesce(sum(s.unforced_errors),0)::bigint,
    'total_points_won',coalesce(sum(s.total_points_won),0)::bigint
  ) into v_stats
  from public.statistics_player_match_facts_v1 f
  left join public.tournament_match_player_stats s on s.match_id=f.match_id and s.player_id=f.player_id
  where f.player_id=v_player.id and f.season=d.season;

  v_next_match:=public.get_player_next_match_v1(v_player.id);

  select jsonb_build_object(
    'competition_id',x.competition_id,
    'tournament_name',x.tournament_name,
    'city',x.city,
    'country_code',x.country_code,
    'category_code',x.category_code,
    'surface',x.surface,
    'season_week',x.season_week,
    'entry_status',x.entry_status,
    'draw_type',x.draw_type
  ) into v_next_tournament
  from (
    select te.competition_id,ts.name tournament_name,ts.city,ts.country_code,ts.category_code,ts.surface,
           min(ss.season_week)::smallint season_week,te.entry_status,te.draw_type
    from public.tournament_entries te
    join public.tournament_world_competitions wc on wc.id=te.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    left join public.tournament_schedule_slots ss on ss.tournament_edition_id=ed.id
    where te.player_id=v_player.id and te.entry_status in ('active','accepted') and ed.season_number>=d.season
    group by te.competition_id,ts.name,ts.city,ts.country_code,ts.category_code,ts.surface,te.entry_status,te.draw_type,ed.season_number
    order by case when ed.season_number=d.season and min(ss.season_week)>=v_week then 0 else 1 end,
             ed.season_number,min(ss.season_week)
    limit 1
  ) x;

  select jsonb_build_object(
    'match_id',m.id,
    'competition_id',m.competition_id,
    'tournament_name',ts.name,
    'city',ts.city,
    'country_code',ts.country_code,
    'round_label',m.round_label,
    'won',m.winner_id=v_player.id,
    'player_side',case when m.player1_id=v_player.id then 1 else 2 end,
    'opponent_id',case when m.player1_id=v_player.id then m.player2_id else m.player1_id end,
    'opponent_first_name',case when m.player1_id=v_player.id then p2.first_name else p1.first_name end,
    'opponent_last_name',case when m.player1_id=v_player.id then p2.last_name else p1.last_name end,
    'opponent_country_code',case when m.player1_id=v_player.id then p2.country_code else p1.country_code end,
    'sets',coalesce((select jsonb_agg(jsonb_build_object('set_number',ms.set_number,'player1_games',ms.player1_games,'player2_games',ms.player2_games,'player1_tiebreak_points',ms.player1_tiebreak_points,'player2_tiebreak_points',ms.player2_tiebreak_points) order by ms.set_number) from public.tournament_match_sets ms where ms.match_id=m.id and ms.status='completed'),'[]'::jsonb)
  ) into v_latest_result
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  left join public.players p1 on p1.id=m.player1_id
  left join public.players p2 on p2.id=m.player2_id
  where (m.player1_id=v_player.id or m.player2_id=v_player.id) and m.status='completed'
  order by ed.season_number desc,m.scheduled_season_week desc,m.scheduled_day desc,m.match_number desc
  limit 1;

  select coalesce(jsonb_agg(to_jsonb(t) order by t.slot_order,t.tournament_name),'[]'::jsonb) into v_today_tournaments
  from (
    select distinct on (wc.id) wc.id competition_id,ts.name tournament_name,ts.city,ts.country_code,ts.category_code,ts.surface,ss.phase,ss.slot_order
    from public.tournament_schedule_slots ss
    join public.tournament_editions ed on ed.id=ss.tournament_edition_id
    join public.tournament_world_competitions wc on wc.tournament_edition_id=ed.id and wc.world=v_player.world
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    where ed.season_number=d.season and ss.season_week=v_week
    order by wc.id,ss.slot_order
    limit 8
  ) t;

  select coalesce(jsonb_agg(to_jsonb(n) order by n.completed_at desc,n.match_id),'[]'::jsonb) into v_game_news
  from (
    select m.id match_id,m.completed_at,ts.name tournament_name,m.round_label,
           w.id winner_id,w.first_name winner_first_name,w.last_name winner_last_name,w.country_code winner_country_code,
           l.id loser_id,l.first_name loser_first_name,l.last_name loser_last_name,l.country_code loser_country_code
    from public.tournament_matches m
    join public.tournament_world_competitions wc on wc.id=m.competition_id and wc.world=v_player.world
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    join public.players w on w.id=m.winner_id
    join public.players l on l.id=case when m.player1_id=m.winner_id then m.player2_id else m.player1_id end
    where m.status='completed' and m.winner_id is not null
    order by coalesce(m.completed_at,m.updated_at) desc,m.scheduled_season_week desc,m.scheduled_day desc,m.match_number desc
    limit 6
  ) n;

  select coalesce(jsonb_agg(to_jsonb(n) order by n.created_at desc),'[]'::jsonb) into v_notifications
  from (
    select id,notification_code,title,message,severity,route,created_at,read_at
    from public.user_notifications
    where user_id=v_uid and archived_at is null
    order by created_at desc
    limit 5
  ) n;

  v_finance:=public.get_career_finance_dashboard_v1(5);
  v_training:=public.get_training_dashboard_v1();
  v_equipment:=public.get_equipment_dashboard_v1();
  v_club:=public.get_tennis_club_dashboard_v1();

  select jsonb_build_object(
    'active_count',count(*) filter(where status='active')::integer,
    'weekly_payroll',coalesce(sum(weekly_salary) filter(where status='active'),0)::bigint
  ) into v_staff
  from public.player_staff_contracts where player_id=v_player.id;

  return jsonb_build_object(
    'game_day',jsonb_build_object('season',d.season,'month',d.month,'day',d.day,'absolute_day',v_abs,'season_week',v_week),
    'player',jsonb_build_object('id',v_player.id,'world',v_player.world,'current_rank',v_rank,'ranking_points',v_points),
    'season_stats',coalesce(v_stats,'{}'::jsonb),
    'next_match',v_next_match,
    'next_tournament',v_next_tournament,
    'latest_result',v_latest_result,
    'today_tournaments',v_today_tournaments,
    'game_news',v_game_news,
    'career_news',v_notifications,
    'finance',v_finance,
    'training',v_training,
    'equipment',v_equipment,
    'club',v_club,
    'staff',v_staff
  );
end;
$$;

revoke all on function public.get_overview_dashboard_v1() from public, anon;
grant execute on function public.get_overview_dashboard_v1() to authenticated;
