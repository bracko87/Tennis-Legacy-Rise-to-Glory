
alter table public.tournament_matches
  drop constraint if exists tournament_matches_schedule_reason_check;

alter table public.tournament_matches
  add constraint tournament_matches_schedule_reason_check
  check (schedule_reason = any(array[
    'standard'::text,
    'travel_accommodation'::text,
    'travel_risk'::text,
    'national_team'::text
  ]));

insert into public.tournament_categories(
  code,label,winner_points,main_draw_capacity,qualifying_capacity_max,default_qualifier_slots,
  sort_order,competition_weeks,qualification_rounds_max,main_draw_rounds,
  qualification_rest_day_first,main_draw_rest_day_first,one_match_per_player_per_day,same_city_for_qualification
)
values(
  'national_team','National Team',1,32,0,0,
  99,1,0,1,false,false,false,true
)
on conflict(code) do update
set label=excluded.label,
    winner_points=1,
    main_draw_capacity=32,
    qualifying_capacity_max=0,
    default_qualifier_slots=0,
    competition_weeks=1,
    qualification_rounds_max=0,
    main_draw_rounds=1,
    one_match_per_player_per_day=false;

create or replace function public.ensure_national_fixture_engine_competition_v1(
  p_fixture_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  f public.national_team_fixtures%rowtype;
  w public.national_team_windows%rowtype;
  v_home text;
  v_away text;
  v_series uuid;
  v_edition uuid;
  v_comp uuid;
  v_slug text;
begin
  select n.competition_id into v_comp
  from public.national_team_engine_competitions n
  where n.fixture_id=p_fixture_id;

  if v_comp is not null then return v_comp; end if;

  select * into f from public.national_team_fixtures where id=p_fixture_id for update;
  if not found then raise exception 'National fixture not found.'; end if;

  select * into w from public.national_team_windows where id=f.window_id;
  select name into v_home from public.national_associations where id=f.home_association_id;
  select name into v_away from public.national_associations where id=f.away_association_id;

  v_slug:='national-team-'||replace(f.id::text,'-','');

  insert into public.tournament_series(
    slug,name,city,country_code,category_code,surface,environment,
    latitude,longitude,is_active
  )
  values(
    v_slug,
    format('%s vs %s · National Team',v_home,v_away),
    f.host_city,
    f.host_country_code,
    'national_team',
    f.surface,
    f.environment,
    f.host_latitude,
    f.host_longitude,
    false
  )
  on conflict(slug) do update
  set name=excluded.name,
      city=excluded.city,
      country_code=excluded.country_code,
      category_code='national_team',
      surface=excluded.surface,
      environment=excluded.environment,
      latitude=excluded.latitude,
      longitude=excluded.longitude,
      is_active=false
  returning id into v_series;

  insert into public.tournament_editions(
    tournament_series_id,season_number,status
  )
  values(v_series,w.season_number,'in_progress')
  on conflict(tournament_series_id,season_number) do update
  set status='in_progress'
  returning id into v_edition;

  insert into public.tournament_world_competitions(
    tournament_edition_id,world,status
  )
  values(v_edition,w.world,'in_progress')
  on conflict(tournament_edition_id,world) do update
  set status='in_progress'
  returning id into v_comp;

  insert into public.tournament_doubles_settings(
    tournament_series_id,is_enabled,draw_size,minimum_teams,prize_money_multiplier,
    fatigue_multiplier,equipment_wear_multiplier,minimum_recovery_minutes,
    estimated_match_duration_minutes,registration_open_offset_minutes,
    registration_deadline_offset_minutes,partnership_deadline_before_draw_minutes,
    draw_lock_offset_minutes,fallback_singles_points_weight,updated_at
  )
  values(
    v_series,true,4,2,0.01,
    0.72,0.70,180,
    105,0,0,0,0,0,now()
  )
  on conflict(tournament_series_id) do update
  set is_enabled=true,
      draw_size=4,
      minimum_teams=2,
      prize_money_multiplier=0.01,
      fatigue_multiplier=0.72,
      equipment_wear_multiplier=0.70,
      minimum_recovery_minutes=180,
      estimated_match_duration_minutes=105,
      fallback_singles_points_weight=0,
      updated_at=now();

  insert into public.national_team_engine_competitions(
    fixture_id,tournament_series_id,tournament_edition_id,competition_id
  )
  values(f.id,v_series,v_edition,v_comp)
  on conflict(fixture_id) do update
  set tournament_series_id=excluded.tournament_series_id,
      tournament_edition_id=excluded.tournament_edition_id,
      competition_id=excluded.competition_id;

  return v_comp;
end;
$$;

-- Tour-only bracket/result triggers must not treat hidden national engine matches
-- as normal elimination tournaments.
drop trigger if exists advance_tournament_bracket_v1 on public.tournament_matches;
create trigger advance_tournament_bracket_v1
after insert or update of status on public.tournament_matches
for each row
when (not public.is_national_team_engine_competition_v1(new.competition_id))
execute function public.advance_tournament_bracket_v1();

drop trigger if exists finalize_completed_tournament_match_v1 on public.tournament_matches;
create trigger finalize_completed_tournament_match_v1
after insert or update of status on public.tournament_matches
for each row
when (not public.is_national_team_engine_competition_v1(new.competition_id))
execute function public.finalize_completed_tournament_match_v1();

drop trigger if exists trg_advance_doubles_bracket_v1 on public.tournament_doubles_matches;
create trigger trg_advance_doubles_bracket_v1
after insert or update of status,winner_team_id on public.tournament_doubles_matches
for each row
when (not public.is_national_team_engine_competition_v1(new.competition_id))
execute function public.advance_doubles_bracket_v1();

drop trigger if exists trg_finalize_completed_doubles_match_v1 on public.tournament_doubles_matches;
create trigger trg_finalize_completed_doubles_match_v1
after insert or update of status,winner_team_id on public.tournament_doubles_matches
for each row
when (not public.is_national_team_engine_competition_v1(new.competition_id))
execute function public.finalize_completed_doubles_match_v1();

create or replace function public.charge_national_team_accommodation_v1(
  p_fixture_id uuid,
  p_association_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  f public.national_team_fixtures%rowtype;
  w public.national_team_windows%rowtype;
  cfg public.national_team_competition_config%rowtype;
  v_index numeric:=1;
  v_nightly integer;
  v_nights integer;
  s record;
  v_count integer:=0;
begin
  select * into f from public.national_team_fixtures where id=p_fixture_id;
  if not found then return 0; end if;

  select * into w from public.national_team_windows where id=f.window_id;
  select * into cfg from public.national_team_competition_config where id=1;

  select coalesce(hotel_cost_index,1) into v_index
  from public.travel_country_cost_profiles
  where country_code=f.host_country_code;

  v_nightly:=greatest(40,round(cfg.default_accommodation_nightly_usd*coalesce(v_index,1))::integer);
  v_nights:=greatest(1,w.end_absolute_day-w.start_absolute_day+1);

  for s in
    select player_id
    from public.national_team_squad_members
    where fixture_id=f.id and association_id=p_association_id
  loop
    perform public.post_national_association_finance_transaction_v1(
      p_association_id,
      -(v_nightly*v_nights),
      'accommodation',
      format('National-team accommodation in %s',f.host_city),
      'national_window',
      w.id::text,
      format('national-accommodation:%s:%s:%s',w.id,p_association_id,s.player_id),
      jsonb_build_object(
        'fixture_id',f.id,
        'window_id',w.id,
        'player_id',s.player_id,
        'host_city',f.host_city,
        'host_country_code',f.host_country_code,
        'nightly_usd',v_nightly,
        'nights',v_nights
      ),
      w.start_absolute_day
    );
    v_count:=v_count+1;
  end loop;

  return v_count;
end;
$$;

create or replace function public.reveal_national_team_lineups_v1(
  p_fixture_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  f public.national_team_fixtures%rowtype;
  w public.national_team_windows%rowtype;
  home_l public.national_team_lineups%rowtype;
  away_l public.national_team_lineups%rowtype;
  v_comp uuid;
  v_home_s1 uuid; v_home_s2 uuid; v_home_s3 uuid; v_home_s4 uuid; v_home_d1a uuid; v_home_d1b uuid;
  v_away_s1 uuid; v_away_s2 uuid; v_away_s3 uuid; v_away_s4 uuid; v_away_d1a uuid; v_away_d1b uuid;
  v_m1 uuid; v_m2 uuid; v_m4 uuid; v_m5 uuid; v_dm uuid;
  v_home_team uuid; v_away_team uuid;
  v_day1 smallint;
  v_day2 smallint;
  v_now bigint:=public.current_game_second_v1();
  r record;
begin
  select * into f from public.national_team_fixtures where id=p_fixture_id for update;
  if not found then raise exception 'Fixture not found.'; end if;

  if exists(
    select 1 from public.national_team_lineups
    where fixture_id=f.id and revealed_at_game_second is not null
  ) then
    return jsonb_build_object('status','already_revealed','fixture_id',f.id);
  end if;

  select * into home_l
  from public.national_team_lineups
  where fixture_id=f.id and association_id=f.home_association_id
    and status in ('locked','auto_locked');

  select * into away_l
  from public.national_team_lineups
  where fixture_id=f.id and association_id=f.away_association_id
    and status in ('locked','auto_locked');

  if home_l.id is null or away_l.id is null then
    return jsonb_build_object('status','waiting_for_both_lineups');
  end if;

  select player_id into v_home_s1 from public.national_team_lineup_slots where lineup_id=home_l.id and slot_code='S1';
  select player_id into v_home_s2 from public.national_team_lineup_slots where lineup_id=home_l.id and slot_code='S2';
  select player_id into v_home_s3 from public.national_team_lineup_slots where lineup_id=home_l.id and slot_code='S3';
  select player_id into v_home_s4 from public.national_team_lineup_slots where lineup_id=home_l.id and slot_code='S4';
  select player_id into v_home_d1a from public.national_team_lineup_slots where lineup_id=home_l.id and slot_code='D1A';
  select player_id into v_home_d1b from public.national_team_lineup_slots where lineup_id=home_l.id and slot_code='D1B';

  select player_id into v_away_s1 from public.national_team_lineup_slots where lineup_id=away_l.id and slot_code='S1';
  select player_id into v_away_s2 from public.national_team_lineup_slots where lineup_id=away_l.id and slot_code='S2';
  select player_id into v_away_s3 from public.national_team_lineup_slots where lineup_id=away_l.id and slot_code='S3';
  select player_id into v_away_s4 from public.national_team_lineup_slots where lineup_id=away_l.id and slot_code='S4';
  select player_id into v_away_d1a from public.national_team_lineup_slots where lineup_id=away_l.id and slot_code='D1A';
  select player_id into v_away_d1b from public.national_team_lineup_slots where lineup_id=away_l.id and slot_code='D1B';

  if v_home_s1 is null or v_home_s2 is null or v_home_s3 is null or v_home_s4 is null
     or v_home_d1a is null or v_home_d1b is null
     or v_away_s1 is null or v_away_s2 is null or v_away_s3 is null or v_away_s4 is null
     or v_away_d1a is null or v_away_d1b is null then
    raise exception 'Both lineups must be complete before reveal.';
  end if;

  select * into w from public.national_team_windows where id=f.window_id;
  v_comp:=public.ensure_national_fixture_engine_competition_v1(f.id);
  v_day1:=(f.tie_start_absolute_day-w.start_absolute_day+1)::smallint;
  v_day2:=(f.tie_start_absolute_day-w.start_absolute_day+2)::smallint;

  insert into public.tournament_matches(
    competition_id,draw_type,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,scheduled_start_minute,court_number,
    estimated_duration_minutes,player1_id,player2_id,status,schedule_reason
  )
  values
    (v_comp,'main_draw',1,'National Singles 1',1,8,w.season_week,v_day1,600,1,120,v_home_s1,v_away_s1,'scheduled','national_team')
  returning id into v_m1;

  insert into public.tournament_matches(
    competition_id,draw_type,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,scheduled_start_minute,court_number,
    estimated_duration_minutes,player1_id,player2_id,status,schedule_reason
  )
  values
    (v_comp,'main_draw',1,'National Singles 2',2,8,w.season_week,v_day1,780,1,120,v_home_s2,v_away_s2,'scheduled','national_team')
  returning id into v_m2;

  insert into public.tournament_matches(
    competition_id,draw_type,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,scheduled_start_minute,court_number,
    estimated_duration_minutes,player1_id,player2_id,status,schedule_reason
  )
  values
    (v_comp,'main_draw',1,'National Singles 3',3,8,w.season_week,v_day2,660,1,120,v_home_s3,v_away_s3,'scheduled','national_team')
  returning id into v_m4;

  insert into public.tournament_matches(
    competition_id,draw_type,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,scheduled_start_minute,court_number,
    estimated_duration_minutes,player1_id,player2_id,status,schedule_reason
  )
  values
    (v_comp,'main_draw',1,'National Singles 4',4,8,w.season_week,v_day2,840,1,120,v_home_s4,v_away_s4,'scheduled','national_team')
  returning id into v_m5;

  insert into public.tournament_doubles_teams(
    competition_id,world,player1_id,player2_id,status,entry_source,
    combined_ranking_points_snapshot,entry_strength_snapshot
  )
  values(v_comp,w.world,v_home_d1a,v_home_d1b,'active','national_team',0,0)
  returning id into v_home_team;

  insert into public.tournament_doubles_teams(
    competition_id,world,player1_id,player2_id,status,entry_source,
    combined_ranking_points_snapshot,entry_strength_snapshot
  )
  values(v_comp,w.world,v_away_d1a,v_away_d1b,'active','national_team',0,0)
  returning id into v_away_team;

  insert into public.tournament_doubles_matches(
    competition_id,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,scheduled_start_minute,court_number,
    estimated_duration_minutes,team1_id,team2_id,status,schedule_reason
  )
  values(v_comp,1,'National Doubles',1,4,w.season_week,v_day1,960,1,105,v_home_team,v_away_team,'scheduled','national_team')
  returning id into v_dm;

  insert into public.national_team_fixture_match_slots(
    fixture_id,slot_order,discipline,status,
    home_player1_id,home_player2_id,away_player1_id,away_player2_id,
    engine_match_id,engine_doubles_match_id
  )
  values
    (f.id,1,'singles','scheduled',v_home_s1,null,v_away_s1,null,v_m1,null),
    (f.id,2,'singles','scheduled',v_home_s2,null,v_away_s2,null,v_m2,null),
    (f.id,3,'doubles','scheduled',v_home_d1a,v_home_d1b,v_away_d1a,v_away_d1b,null,v_dm),
    (f.id,4,'singles','scheduled',v_home_s3,null,v_away_s3,null,v_m4,null),
    (f.id,5,'singles','scheduled',v_home_s4,null,v_away_s4,null,v_m5,null)
  on conflict(fixture_id,slot_order) do nothing;

  update public.national_team_lineups
  set revealed_at_game_second=v_now,updated_at=now()
  where fixture_id=f.id;

  update public.national_team_fixtures
  set status='ready',updated_at=now()
  where id=f.id and status not in ('completed','cancelled','forfeit');

  perform public.charge_national_team_accommodation_v1(f.id,f.home_association_id);
  perform public.charge_national_team_accommodation_v1(f.id,f.away_association_id);

  for r in
    select distinct p.id,p.owner_user_id
    from public.players p
    where p.id in (
      v_home_s1,v_home_s2,v_home_s3,v_home_s4,v_home_d1a,v_home_d1b,
      v_away_s1,v_away_s2,v_away_s3,v_away_s4,v_away_d1a,v_away_d1b
    )
      and p.owner_user_id is not null
  loop
    perform public.emit_notification_v1(
      r.owner_user_id,r.id,
      'national_team.lineup_revealed',
      'National-team lineup revealed',
      'Both captains have locked their lineups. Match pairings are now visible.',
      '/game/national-team',
      jsonb_build_object('fixture_id',f.id,'competition_id',v_comp),
      format('national-lineup-revealed:%s:%s',f.id,r.id)
    );
  end loop;

  return jsonb_build_object('status','revealed','fixture_id',f.id,'competition_id',v_comp);
end;
$$;

create or replace function public.record_national_team_player_appearance_v1(
  p_fixture_id uuid,
  p_association_id uuid,
  p_player_id uuid,
  p_discipline text,
  p_won boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  f public.national_team_fixtures%rowtype;
  a public.national_team_player_appearances%rowtype;
  v_new_appearance boolean:=false;
  v_owner uuid;
  v_player_type text;
begin
  if p_discipline not in ('singles','doubles') then return; end if;
  select * into f from public.national_team_fixtures where id=p_fixture_id;

  select * into a
  from public.national_team_player_appearances
  where fixture_id=p_fixture_id and player_id=p_player_id
  for update;

  if a.id is null then
    insert into public.national_team_player_appearances(
      fixture_id,association_id,player_id,
      singles_matches,doubles_matches,singles_wins,doubles_wins,
      appearance_fee_usd
    )
    values(
      p_fixture_id,p_association_id,p_player_id,
      case when p_discipline='singles' then 1 else 0 end,
      case when p_discipline='doubles' then 1 else 0 end,
      case when p_discipline='singles' and p_won then 1 else 0 end,
      case when p_discipline='doubles' and p_won then 1 else 0 end,
      f.expected_appearance_fee_usd
    )
    returning * into a;
    v_new_appearance:=true;
  else
    if p_discipline='singles' and a.singles_matches=0 then
      update public.national_team_player_appearances
      set singles_matches=1,
          singles_wins=case when p_won then 1 else 0 end,
          updated_at=now()
      where id=a.id;
    elsif p_discipline='doubles' and a.doubles_matches=0 then
      update public.national_team_player_appearances
      set doubles_matches=1,
          doubles_wins=case when p_won then 1 else 0 end,
          updated_at=now()
      where id=a.id;
    end if;
  end if;

  if v_new_appearance and f.expected_appearance_fee_usd>0 then
    select owner_user_id,player_type into v_owner,v_player_type
    from public.players where id=p_player_id;

    perform public.post_national_association_finance_transaction_v1(
      p_association_id,
      -f.expected_appearance_fee_usd,
      'player_appearance_fee',
      'National-team player appearance fee',
      'national_fixture',
      f.id::text,
      format('national-appearance-fee:%s:%s',f.id,p_player_id),
      jsonb_build_object('fixture_id',f.id,'player_id',p_player_id),
      public.national_team_current_abs_day_v1()
    );

    if v_owner is not null and v_player_type='human' then
      perform public.post_career_finance_transaction_v1(
        p_player_id,
        f.expected_appearance_fee_usd,
        'national_team',
        'appearance_fee',
        'National-team appearance payment',
        'national_fixture',
        f.id::text,
        format('national-appearance-income:%s:%s',f.id,p_player_id),
        jsonb_build_object('fixture_id',f.id,'association_id',p_association_id,'taxable',false),
        false,
        public.national_team_current_abs_day_v1()
      );
    end if;
  end if;
end;
$$;

create or replace function public.finalize_national_division_standings_v1(
  p_division_id uuid,
  p_season_number integer
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  d public.national_team_divisions%rowtype;
  v_total integer;
  r record;
  v_outcome text;
  v_upper_exists boolean;
  v_lower_exists boolean;
  v_count integer:=0;
begin
  select * into d from public.national_team_divisions where id=p_division_id;
  if not found then return 0; end if;

  v_upper_exists:=exists(
    select 1 from public.national_team_divisions x
    where x.world=d.world and x.region_code=d.region_code and x.is_active and x.tier_level<d.tier_level
  );
  v_lower_exists:=exists(
    select 1 from public.national_team_divisions x
    where x.world=d.world and x.region_code=d.region_code and x.is_active and x.tier_level>d.tier_level
  );

  select count(*) into v_total
  from public.national_team_division_entries
  where division_id=d.id and season_number=p_season_number and status in ('active','completed');

  for r in
    select
      e.id entry_id,
      e.association_id,
      row_number() over(
        order by
          coalesce(s.standings_points,0) desc,
          coalesce(s.ties_won,0) desc,
          (coalesce(s.matches_won,0)-coalesce(s.matches_lost,0)) desc,
          coalesce(s.matches_won,0) desc,
          a.country_code
      )::integer pos
    from public.national_team_division_entries e
    join public.national_associations a on a.id=e.association_id
    left join public.national_team_division_standings s
      on s.division_id=e.division_id
     and s.season_number=e.season_number
     and s.association_id=e.association_id
    where e.division_id=d.id
      and e.season_number=p_season_number
      and e.status in ('active','completed')
  loop
    v_outcome:='retained';

    if v_upper_exists and d.promotion_slots>0 and r.pos<=d.promotion_slots then
      v_outcome:='promoted';
    elsif v_lower_exists and d.relegation_slots>0 and r.pos>greatest(0,v_total-d.relegation_slots) then
      v_outcome:='relegated';
    end if;

    update public.national_team_division_entries
    set final_position=r.pos,
        sporting_outcome=v_outcome,
        status='completed',
        updated_at=now()
    where id=r.entry_id;

    v_count:=v_count+1;
  end loop;

  return v_count;
end;
$$;

create or replace function public.finalize_national_fixture_result_v1(
  p_fixture_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  f public.national_team_fixtures%rowtype;
  w public.national_team_windows%rowtype;
  v_home integer;
  v_away integer;
  v_played integer;
  v_winner uuid;
  v_day integer:=public.national_team_current_abs_day_v1();
begin
  select * into f from public.national_team_fixtures where id=p_fixture_id for update;
  if not found or f.completed_game_day is not null then return; end if;

  select
    count(*) filter(where winner_association_id=f.home_association_id),
    count(*) filter(where winner_association_id=f.away_association_id),
    count(*) filter(where status in ('completed','walkover','cancelled_dead_rubber'))
  into v_home,v_away,v_played
  from public.national_team_fixture_match_slots
  where fixture_id=f.id;

  if v_home<3 and v_away<3 and v_played<5 then return; end if;

  if v_home=v_away then return; end if;
  v_winner:=case when v_home>v_away then f.home_association_id else f.away_association_id end;

  update public.national_team_fixtures
  set status='completed',
      home_match_wins=v_home,
      away_match_wins=v_away,
      winner_association_id=v_winner,
      completion_reason=coalesce(completion_reason,'played'),
      completed_game_day=v_day,
      updated_at=now()
  where id=f.id;

  if f.division_id is not null then
    select * into w from public.national_team_windows where id=f.window_id;

    insert into public.national_team_division_standings(
      division_id,season_number,association_id,
      ties_played,ties_won,ties_lost,matches_won,matches_lost,standings_points
    )
    values(
      f.division_id,w.season_number,f.home_association_id,
      1,case when v_winner=f.home_association_id then 1 else 0 end,
      case when v_winner=f.away_association_id then 1 else 0 end,
      v_home,v_away,case when v_winner=f.home_association_id then 2 else 0 end
    )
    on conflict(division_id,season_number,association_id) do update
    set ties_played=public.national_team_division_standings.ties_played+1,
        ties_won=public.national_team_division_standings.ties_won+excluded.ties_won,
        ties_lost=public.national_team_division_standings.ties_lost+excluded.ties_lost,
        matches_won=public.national_team_division_standings.matches_won+excluded.matches_won,
        matches_lost=public.national_team_division_standings.matches_lost+excluded.matches_lost,
        standings_points=public.national_team_division_standings.standings_points+excluded.standings_points,
        updated_at=now();

    insert into public.national_team_division_standings(
      division_id,season_number,association_id,
      ties_played,ties_won,ties_lost,matches_won,matches_lost,standings_points
    )
    values(
      f.division_id,w.season_number,f.away_association_id,
      1,case when v_winner=f.away_association_id then 1 else 0 end,
      case when v_winner=f.home_association_id then 1 else 0 end,
      v_away,v_home,case when v_winner=f.away_association_id then 2 else 0 end
    )
    on conflict(division_id,season_number,association_id) do update
    set ties_played=public.national_team_division_standings.ties_played+1,
        ties_won=public.national_team_division_standings.ties_won+excluded.ties_won,
        ties_lost=public.national_team_division_standings.ties_lost+excluded.ties_lost,
        matches_won=public.national_team_division_standings.matches_won+excluded.matches_won,
        matches_lost=public.national_team_division_standings.matches_lost+excluded.matches_lost,
        standings_points=public.national_team_division_standings.standings_points+excluded.standings_points,
        updated_at=now();
  end if;

  perform public.national_team_record_event_v1(
    f.home_association_id,
    'national_fixture_completed',
    jsonb_build_object(
      'fixture_id',f.id,
      'opponent_association_id',f.away_association_id,
      'home_match_wins',v_home,
      'away_match_wins',v_away,
      'winner_association_id',v_winner
    ),
    (select season_number from public.national_team_windows where id=f.window_id)
  );

  perform public.national_team_record_event_v1(
    f.away_association_id,
    'national_fixture_completed',
    jsonb_build_object(
      'fixture_id',f.id,
      'opponent_association_id',f.home_association_id,
      'home_match_wins',v_home,
      'away_match_wins',v_away,
      'winner_association_id',v_winner
    ),
    (select season_number from public.national_team_windows where id=f.window_id)
  );
end;
$$;

create or replace function public.cancel_national_dead_rubbers_v1(
  p_fixture_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  f public.national_team_fixtures%rowtype;
  fmt public.national_team_fixture_formats%rowtype;
  v_home integer;
  v_away integer;
  s record;
  v_count integer:=0;
begin
  select * into f from public.national_team_fixtures where id=p_fixture_id for update;
  if not found then return 0; end if;
  select * into fmt from public.national_team_fixture_formats where code=f.format_code;

  select
    count(*) filter(where winner_association_id=f.home_association_id),
    count(*) filter(where winner_association_id=f.away_association_id)
  into v_home,v_away
  from public.national_team_fixture_match_slots
  where fixture_id=f.id and status in ('completed','walkover');

  if greatest(v_home,v_away)<fmt.matches_to_win or not fmt.allow_dead_rubber_cancel then
    return 0;
  end if;

  for s in
    select *
    from public.national_team_fixture_match_slots
    where fixture_id=f.id and status='scheduled'
    order by slot_order
  loop
    if s.engine_match_id is not null then
      update public.tournament_matches
      set status='cancelled',
          completed_at=now(),
          updated_at=now()
      where id=s.engine_match_id and status='scheduled';
    end if;

    if s.engine_doubles_match_id is not null then
      update public.tournament_doubles_matches
      set status='cancelled',
          completion_reason='national_dead_rubber',
          completed_at=now(),
          updated_at=now()
      where id=s.engine_doubles_match_id and status='scheduled';
    end if;

    update public.national_team_fixture_match_slots
    set status='cancelled_dead_rubber',updated_at=now()
    where id=s.id;

    v_count:=v_count+1;
  end loop;

  perform public.finalize_national_fixture_result_v1(f.id);
  return v_count;
end;
$$;

create or replace function public.sync_national_fixture_from_singles_v1()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  s public.national_team_fixture_match_slots%rowtype;
  f public.national_team_fixtures%rowtype;
  v_winner_assoc uuid;
  v_simulated boolean;
begin
  if new.status<>'completed' or new.winner_id is null
     or (tg_op='UPDATE' and old.status is not distinct from new.status and old.winner_id is not distinct from new.winner_id) then
    return new;
  end if;

  select * into s
  from public.national_team_fixture_match_slots
  where engine_match_id=new.id
  for update;

  if s.id is null then return new; end if;
  select * into f from public.national_team_fixtures where id=s.fixture_id;

  v_winner_assoc:=case
    when new.winner_id in (s.home_player1_id,s.home_player2_id) then f.home_association_id
    else f.away_association_id
  end;

  update public.national_team_fixture_match_slots
  set status='completed',
      winner_association_id=v_winner_assoc,
      completed_game_day=public.national_team_current_abs_day_v1(),
      updated_at=now()
  where id=s.id;

  select exists(
    select 1 from public.tournament_match_simulations sim where sim.match_id=new.id
  ) into v_simulated;

  if v_simulated then
    perform public.record_national_team_player_appearance_v1(
      f.id,f.home_association_id,s.home_player1_id,'singles',v_winner_assoc=f.home_association_id
    );
    perform public.record_national_team_player_appearance_v1(
      f.id,f.away_association_id,s.away_player1_id,'singles',v_winner_assoc=f.away_association_id
    );
  end if;

  update public.national_team_fixtures
  set status='in_progress',
      home_match_wins=(select count(*) from public.national_team_fixture_match_slots x where x.fixture_id=f.id and x.winner_association_id=f.home_association_id),
      away_match_wins=(select count(*) from public.national_team_fixture_match_slots x where x.fixture_id=f.id and x.winner_association_id=f.away_association_id),
      updated_at=now()
  where id=f.id and status in ('ready','in_progress');

  perform public.cancel_national_dead_rubbers_v1(f.id);
  perform public.finalize_national_fixture_result_v1(f.id);
  return new;
end;
$$;

drop trigger if exists trg_sync_national_fixture_from_singles_v1 on public.tournament_matches;
create trigger trg_sync_national_fixture_from_singles_v1
after update of status,winner_id on public.tournament_matches
for each row
execute function public.sync_national_fixture_from_singles_v1();

create or replace function public.sync_national_fixture_from_doubles_v1()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  s public.national_team_fixture_match_slots%rowtype;
  f public.national_team_fixtures%rowtype;
  t public.tournament_doubles_teams%rowtype;
  v_winner_assoc uuid;
  v_player uuid;
  v_duration integer;
begin
  if new.status<>'completed' or new.winner_team_id is null
     or (tg_op='UPDATE' and old.status is not distinct from new.status and old.winner_team_id is not distinct from new.winner_team_id) then
    return new;
  end if;

  select * into s
  from public.national_team_fixture_match_slots
  where engine_doubles_match_id=new.id
  for update;

  if s.id is null then return new; end if;
  select * into f from public.national_team_fixtures where id=s.fixture_id;
  select * into t from public.tournament_doubles_teams where id=new.winner_team_id;

  if t.player1_id in (s.home_player1_id,s.home_player2_id)
     and t.player2_id in (s.home_player1_id,s.home_player2_id) then
    v_winner_assoc:=f.home_association_id;
  else
    v_winner_assoc:=f.away_association_id;
  end if;

  update public.national_team_fixture_match_slots
  set status='completed',
      winner_association_id=v_winner_assoc,
      completed_game_day=public.national_team_current_abs_day_v1(),
      updated_at=now()
  where id=s.id;

  foreach v_player in array array[s.home_player1_id,s.home_player2_id] loop
    perform public.record_national_team_player_appearance_v1(
      f.id,f.home_association_id,v_player,'doubles',v_winner_assoc=f.home_association_id
    );
  end loop;

  foreach v_player in array array[s.away_player1_id,s.away_player2_id] loop
    perform public.record_national_team_player_appearance_v1(
      f.id,f.away_association_id,v_player,'doubles',v_winner_assoc=f.away_association_id
    );
  end loop;

  v_duration:=greatest(20,coalesce(new.actual_duration_minutes,90));
  foreach v_player in array array[s.home_player1_id,s.home_player2_id,s.away_player1_id,s.away_player2_id] loop
    if v_player is not null then
      perform public.roll_player_injury_v1(v_player,'match',new.id,null,v_duration,0);
    end if;
  end loop;

  update public.national_team_fixtures
  set status='in_progress',
      home_match_wins=(select count(*) from public.national_team_fixture_match_slots x where x.fixture_id=f.id and x.winner_association_id=f.home_association_id),
      away_match_wins=(select count(*) from public.national_team_fixture_match_slots x where x.fixture_id=f.id and x.winner_association_id=f.away_association_id),
      updated_at=now()
  where id=f.id and status in ('ready','in_progress');

  perform public.cancel_national_dead_rubbers_v1(f.id);
  perform public.finalize_national_fixture_result_v1(f.id);
  return new;
end;
$$;

drop trigger if exists trg_sync_national_fixture_from_doubles_v1 on public.tournament_doubles_matches;
create trigger trg_sync_national_fixture_from_doubles_v1
after update of status,winner_team_id on public.tournament_doubles_matches
for each row
execute function public.sync_national_fixture_from_doubles_v1();

create or replace function public.process_national_team_season_standings_v1()
returns integer
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_day integer:=public.national_team_current_abs_day_v1();
  v_season integer:=(public.national_team_current_abs_day_v1()/366)+1;
  d record;
  v_count integer:=0;
begin
  if exists(
    select 1 from public.national_team_windows
    where season_number=v_season and status not in ('completed','cancelled')
  ) then
    return 0;
  end if;

  for d in
    select id from public.national_team_divisions where is_active
  loop
    v_count:=v_count+public.finalize_national_division_standings_v1(d.id,v_season);
  end loop;

  return v_count;
end;
$$;

revoke execute on function public.ensure_national_fixture_engine_competition_v1(uuid) from anon,authenticated;
revoke execute on function public.charge_national_team_accommodation_v1(uuid,uuid) from anon,authenticated;
revoke execute on function public.reveal_national_team_lineups_v1(uuid) from anon,authenticated;
revoke execute on function public.record_national_team_player_appearance_v1(uuid,uuid,uuid,text,boolean) from anon,authenticated;
revoke execute on function public.finalize_national_division_standings_v1(uuid,integer) from anon,authenticated;
revoke execute on function public.finalize_national_fixture_result_v1(uuid) from anon,authenticated;
revoke execute on function public.cancel_national_dead_rubbers_v1(uuid) from anon,authenticated;
revoke execute on function public.sync_national_fixture_from_singles_v1() from anon,authenticated;
revoke execute on function public.sync_national_fixture_from_doubles_v1() from anon,authenticated;
revoke execute on function public.process_national_team_season_standings_v1() from anon,authenticated;
