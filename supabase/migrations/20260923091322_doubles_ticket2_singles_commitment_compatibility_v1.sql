-- Doubles Ticket 2 compatibility hardening:
-- pending singles applications are not commitments, but singles allocation
-- must re-check doubles/accepted-entry commitments before confirming a place.

create or replace function public.check_player_competition_availability_v1(
  p_player_id uuid,
  p_competition_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  t record;
  v_player_world text;
  v_block_comp uuid;
  v_block_name text;
  v_block_city text;
begin
  select * into t
  from public.get_competition_window_v1(p_competition_id);

  if t.competition_id is null then
    return jsonb_build_object('available',false,'reason','competition_unavailable');
  end if;

  select world
  into v_player_world
  from public.players
  where id=p_player_id
    and moderation_status<>'rejected';

  if v_player_world is null then
    return jsonb_build_object('available',false,'reason','player_unavailable');
  end if;

  if v_player_world<>t.world then
    return jsonb_build_object('available',false,'reason','different_world');
  end if;

  v_block_comp:=null;
  v_block_name:=null;
  v_block_city:=null;

  select te.competition_id,s.name,s.city
  into v_block_comp,v_block_name,v_block_city
  from public.tournament_entries te
  join public.tournament_world_competitions wc on wc.id=te.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  cross join lateral public.get_competition_window_v1(te.competition_id) w
  where te.player_id=p_player_id
    and te.entry_status='active'
    and te.competition_id<>p_competition_id
    and w.start_absolute_day<=t.end_absolute_day
    and w.end_absolute_day>=t.start_absolute_day
  order by w.start_absolute_day
  limit 1;

  if v_block_comp is not null then
    return jsonb_build_object(
      'available',false,
      'reason','singles_entry_overlap',
      'blocking_competition_id',v_block_comp,
      'blocking_tournament',v_block_name,
      'blocking_city',v_block_city
    );
  end if;

  v_block_comp:=null;
  v_block_name:=null;
  v_block_city:=null;

  select a.competition_id,s.name,s.city
  into v_block_comp,v_block_name,v_block_city
  from public.tournament_applications a
  join public.tournament_world_competitions wc on wc.id=a.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  cross join lateral public.get_competition_window_v1(a.competition_id) w
  where a.player_id=p_player_id
    and a.status in ('accepted_main_draw','accepted_qualification')
    and a.competition_id<>p_competition_id
    and w.start_absolute_day<=t.end_absolute_day
    and w.end_absolute_day>=t.start_absolute_day
  order by
    case a.status
      when 'accepted_main_draw' then 1
      when 'accepted_qualification' then 2
      else 3
    end,
    w.start_absolute_day
  limit 1;

  if v_block_comp is not null then
    return jsonb_build_object(
      'available',false,
      'reason','accepted_singles_overlap',
      'blocking_competition_id',v_block_comp,
      'blocking_tournament',v_block_name,
      'blocking_city',v_block_city
    );
  end if;

  v_block_comp:=null;
  v_block_name:=null;
  v_block_city:=null;

  select dt.competition_id,s.name,s.city
  into v_block_comp,v_block_name,v_block_city
  from public.tournament_doubles_teams dt
  join public.tournament_world_competitions wc on wc.id=dt.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  cross join lateral public.get_competition_window_v1(dt.competition_id) w
  where (dt.player1_id=p_player_id or dt.player2_id=p_player_id)
    and dt.status in ('confirmed','active','alternate')
    and dt.competition_id<>p_competition_id
    and w.start_absolute_day<=t.end_absolute_day
    and w.end_absolute_day>=t.start_absolute_day
  order by w.start_absolute_day
  limit 1;

  if v_block_comp is not null then
    return jsonb_build_object(
      'available',false,
      'reason','doubles_entry_overlap',
      'blocking_competition_id',v_block_comp,
      'blocking_tournament',v_block_name,
      'blocking_city',v_block_city
    );
  end if;

  if exists(
    select 1
    from public.player_calendar_commitments c
    where c.player_id=p_player_id
      and c.status='committed'
      and (c.competition_id is null or c.competition_id<>p_competition_id)
      and c.starts_absolute_day<=t.end_absolute_day
      and c.ends_absolute_day>=t.start_absolute_day
  ) then
    return jsonb_build_object(
      'available',false,
      'reason','calendar_commitment_overlap'
    );
  end if;

  return jsonb_build_object(
    'available',true,
    'reason','available',
    'start_absolute_day',t.start_absolute_day,
    'end_absolute_day',t.end_absolute_day,
    'location_key',t.location_key
  );
end;
$$;

create or replace function public.allocate_tournament_applications_v3(
  p_competition_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_cycle public.tournament_competition_entry_cycles%rowtype;
  v_tl jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_world text;
  v_season integer;
  v_week smallint;
  v_direct_cap integer;
  v_qcap integer;
  v_main_used integer;
  v_q_used integer;
  r record;
  v_main_added integer:=0;
  v_q_added integer:=0;
  v_rejected integer:=0;
  v_availability jsonb;
begin
  if exists(
       select 1 from public.tournament_matches
       where competition_id=p_competition_id
     )
     or exists(
       select 1 from public.tournament_draw_publications
       where competition_id=p_competition_id
     )
  then
    return jsonb_build_object('status','draw_already_exists');
  end if;

  v_tl:=public.get_tournament_entry_timeline_v1(p_competition_id);

  if v_now>=(v_tl->'tournament_start'->>'game_second')::bigint then
    return jsonb_build_object('status','tournament_started');
  end if;

  insert into public.tournament_competition_entry_cycles(competition_id)
  values(p_competition_id)
  on conflict do nothing;

  select *
  into v_cycle
  from public.tournament_competition_entry_cycles
  where competition_id=p_competition_id
  for update;

  if v_cycle.normal_allocation_processed_at is not null then
    return jsonb_build_object('status','already_processed');
  end if;

  if v_now<(v_tl->>'normal_close_game_second')::bigint then
    return jsonb_build_object('status','not_due');
  end if;

  select wc.world,e.season_number,
         (c.main_draw_capacity-c.default_qualifier_slots),
         c.qualifying_capacity_max
  into v_world,v_season,v_direct_cap,v_qcap
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  join public.tournament_categories c on c.code=s.category_code
  where wc.id=p_competition_id;

  v_week:=(v_tl->>'target_season_week')::smallint;

  select count(*)
  into v_main_used
  from public.tournament_entries
  where competition_id=p_competition_id
    and draw_type='main_draw'
    and entry_status='active';

  select count(*)
  into v_q_used
  from public.tournament_entries
  where competition_id=p_competition_id
    and draw_type='qualification'
    and entry_status='active';

  for r in
    select a.*,
           public.get_player_world_rank_position_v1(a.player_id) current_rank,
           coalesce(pr.ranking_points,0) current_points
    from public.tournament_applications a
    left join public.player_rankings pr on pr.player_id=a.player_id
    where a.competition_id=p_competition_id
      and a.status='applied'
    order by
      public.get_player_world_rank_position_v1(a.player_id),
      a.created_at,
      a.id
  loop
    perform pg_advisory_xact_lock(
      hashtextextended(
        format('tournament-entry:%s:%s:%s',r.player_id,v_season,v_week),
        0
      )
    );

    update public.tournament_applications
    set ranking_position_snapshot=r.current_rank,
        ranking_points_snapshot=r.current_points,
        priority=null,
        updated_at=now()
    where id=r.id;

    v_availability:=public.check_player_competition_availability_v1(
      r.player_id,
      p_competition_id
    );

    if not coalesce((v_availability->>'available')::boolean,false) then
      update public.tournament_applications
      set status='superseded',
          decision_reason='competition_commitment_conflict:'||
            coalesce(v_availability->>'reason','unavailable'),
          decided_at=now(),
          updated_at=now()
      where id=r.id;
      continue;
    end if;

    if exists(
      select 1
      from public.tournament_entries te
      join public.tournament_world_competitions wc on wc.id=te.competition_id
      join public.tournament_editions e on e.id=wc.tournament_edition_id
      where te.player_id=r.player_id
        and te.entry_status='active'
        and e.season_number=v_season
        and public.tournament_application_target_week_v1(wc.id)=v_week
        and te.competition_id<>p_competition_id
    ) then
      update public.tournament_applications
      set status='superseded',
          decision_reason='already_committed_same_week',
          decided_at=now(),
          updated_at=now()
      where id=r.id;
      continue;
    end if;

    if v_main_used<v_direct_cap then
      insert into public.tournament_entries(
        competition_id,player_id,world,draw_type,entry_status,
        entry_source,ranking_position_snapshot
      )
      values(
        p_competition_id,r.player_id,v_world,'main_draw','active',
        'application',r.current_rank
      )
      on conflict(competition_id,player_id) do update
      set draw_type='main_draw',
          entry_status='active',
          entry_source='application',
          ranking_position_snapshot=excluded.ranking_position_snapshot,
          updated_at=now();

      v_main_used:=v_main_used+1;
      v_main_added:=v_main_added+1;

      update public.tournament_applications
      set status='accepted_main_draw',
          decision_reason='accepted_by_ranking',
          decided_at=now(),
          updated_at=now()
      where id=r.id;

    elsif r.accept_qualification and v_q_used<v_qcap then
      insert into public.tournament_entries(
        competition_id,player_id,world,draw_type,entry_status,
        entry_source,ranking_position_snapshot
      )
      values(
        p_competition_id,r.player_id,v_world,'qualification','active',
        'application',r.current_rank
      )
      on conflict(competition_id,player_id) do update
      set draw_type='qualification',
          entry_status='active',
          entry_source='application',
          ranking_position_snapshot=excluded.ranking_position_snapshot,
          updated_at=now();

      v_q_used:=v_q_used+1;
      v_q_added:=v_q_added+1;

      update public.tournament_applications
      set status='accepted_qualification',
          decision_reason='accepted_by_ranking',
          decided_at=now(),
          updated_at=now()
      where id=r.id;

    else
      update public.tournament_applications
      set status='rejected',
          decision_reason=case
            when not r.accept_qualification
              then 'main_draw_unavailable_qualification_declined'
            else 'field_capacity'
          end,
          decided_at=now(),
          updated_at=now()
      where id=r.id;

      v_rejected:=v_rejected+1;
    end if;
  end loop;

  update public.tournament_competition_entry_cycles
  set normal_allocation_processed_at=now(),
      normal_allocation_game_second=v_now,
      updated_at=now()
  where competition_id=p_competition_id;

  return jsonb_build_object(
    'status','processed',
    'main_draw_added',v_main_added,
    'qualification_added',v_q_added,
    'rejected',v_rejected,
    'main_draw_total',v_main_used,
    'qualification_total',v_q_used
  );
end;
$$;