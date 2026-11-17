-- Compatibility guard for later seasons whose schedule generator may
-- still produce 'full' first-week slots followed by 'main_draw' second week.
-- Main-draw placement always takes precedence. Qualification occurs
-- before main-draw week, without moving played matches or existing results.
CREATE OR REPLACE FUNCTION public.apply_multiweek_tournament_match_schedule_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
 v_slot_count integer;
 v_qual_week integer;
 v_main_first_week integer;
 v_main_last_week integer;
 v_q_rounds integer;
 v_rounds integer;
 v_main_days integer;
 v_first_day integer;
 v_event_day integer;
BEGIN
 IF new.round_number IS NULL OR new.round_number<1
    OR new.draw_type NOT IN ('qualification','main_draw') THEN RETURN new; END IF;

 SELECT count(DISTINCT ss.season_week),
        min(ss.season_week) FILTER (WHERE ss.phase='qualification'),
        min(ss.season_week) FILTER (WHERE ss.phase='main_draw'),
        max(ss.season_week) FILTER (WHERE ss.phase='main_draw'),
        tc.qualification_rounds_max
 INTO v_slot_count,v_qual_week,v_main_first_week,v_main_last_week,v_q_rounds
 FROM public.tournament_world_competitions wc
 JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
 JOIN public.tournament_series ts ON ts.id=ed.tournament_series_id
 JOIN public.tournament_categories tc ON tc.code=ts.category_code
 JOIN public.tournament_schedule_slots ss ON ss.tournament_edition_id=ed.id
 WHERE wc.id=new.competition_id
 GROUP BY tc.qualification_rounds_max;

 IF coalesce(v_slot_count,0)<2 THEN RETURN new; END IF;

 -- Compatibility for future-season calendars still using the legacy 'full'
 -- label for the qualifying week before a separately labelled main draw.
 IF v_qual_week IS NULL AND v_main_first_week IS NOT NULL
    AND coalesce(v_q_rounds,0)>0 THEN
    SELECT min(ss.season_week) INTO v_qual_week
    FROM public.tournament_world_competitions wc
    JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
    JOIN public.tournament_schedule_slots ss ON ss.tournament_edition_id=ed.id
    WHERE wc.id=new.competition_id AND ss.phase='full'
      AND ss.season_week<v_main_first_week;
 END IF;

 -- Fail closed when configured phases cannot produce a sensible calendar.
 IF v_main_first_week IS NULL OR v_main_last_week IS NULL
    OR (v_qual_week IS NOT NULL AND v_qual_week>=v_main_first_week) THEN
    RAISE EXCEPTION 'Invalid configured qualification/main-draw weeks for competition %',new.competition_id;
 END IF;

 IF new.draw_type='qualification' THEN
    IF v_qual_week IS NULL THEN RAISE EXCEPTION 'Qualification week missing for competition %',new.competition_id; END IF;
    v_q_rounds:=greatest(1,least(6,coalesce(v_q_rounds,1)));
    IF new.round_number>v_q_rounds THEN RAISE EXCEPTION 'Qualification round % exceeds configured maximum %',new.round_number,v_q_rounds; END IF;
    new.scheduled_season_week:=v_qual_week;
    new.scheduled_day:=(6-(v_q_rounds-new.round_number))::smallint;
    RETURN new;
 END IF;

 -- Main-draw rounds begin no earlier than the configured main-draw week.
 v_rounds:=ceil(log(2::numeric,greatest(new.bracket_size,2)::numeric))::integer;
 v_main_days:=(v_main_last_week-v_main_first_week+1)*7;
 IF v_rounds>v_main_days OR new.round_number>v_rounds THEN
    RAISE EXCEPTION 'Cannot place round % of % within main-draw weeks %–%',new.round_number,v_rounds,v_main_first_week,v_main_last_week;
 END IF;
 v_first_day:=CASE WHEN v_rounds>=7 THEN 1 ELSE 2 END;
 IF v_rounds=1 THEN
    v_event_day:=v_main_days;
 ELSE
    v_event_day:=round(v_first_day + ((new.round_number-1)::numeric
                       *(v_main_days-v_first_day)::numeric/(v_rounds-1)::numeric))::integer;
 END IF;
 new.scheduled_season_week:=v_main_first_week+(v_event_day-1)/7;
 new.scheduled_day:=(((v_event_day-1)%7)+1)::smallint;
 RETURN new;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.get_player_effective_competition_window_v1(p_player_id uuid, p_competition_id uuid)
 RETURNS TABLE(start_absolute_day integer, end_absolute_day integer)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
WITH event_window AS(
  SELECT w.start_absolute_day,w.end_absolute_day,w.season_number
  FROM public.get_competition_window_v1(p_competition_id) w
), phases AS (
  SELECT coalesce(min(ss.season_week) FILTER(WHERE ss.phase='qualification'),
           min(ss.season_week) FILTER(WHERE ss.phase='full')) qualification_week,
    min(ss.season_week) FILTER(WHERE ss.phase='main_draw') main_draw_week
  FROM public.tournament_schedule_slots ss
  JOIN public.tournament_world_competitions wc ON wc.tournament_edition_id=ss.tournament_edition_id
  WHERE wc.id=p_competition_id
), admitted AS (
 SELECT EXISTS(
   SELECT 1 FROM public.tournament_entries te
   WHERE te.player_id=p_player_id AND te.competition_id=p_competition_id
     AND te.draw_type='main_draw' AND te.entry_status='active'
 ) AS direct_main
), qualifiers AS (
 SELECT EXISTS(
   SELECT 1 FROM public.tournament_matches m
   WHERE m.competition_id=p_competition_id AND m.draw_type='qualification'
     AND (m.player1_id=p_player_id OR m.player2_id=p_player_id)
     AND m.status NOT IN ('cancelled')
 ) AS did_qualify
)
SELECT CASE WHEN a.direct_main AND NOT q.did_qualify
  AND ph.qualification_week IS NOT NULL AND ph.main_draw_week>ph.qualification_week
  THEN greatest(e.start_absolute_day,
    public.training_camp_week_start_absolute_v1(e.season_number,ph.main_draw_week::smallint))
  ELSE e.start_absolute_day END,
  e.end_absolute_day
FROM event_window e CROSS JOIN phases ph CROSS JOIN admitted a CROSS JOIN qualifiers q
$function$
;
CREATE OR REPLACE FUNCTION public.fill_high_tier_ai_doubles_teams_v1(p_competition_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_world text;
  v_category text;
  v_draw_size integer;
  v_season integer;
  v_week integer;
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_existing integer;
  v_needed integer;
  v_created integer:=0;
  v_p1 uuid;
  v_p2 uuid;
begin
  select wc.world,ts.category_code,ds.draw_size,ed.season_number,
         coalesce(
           max(ss.season_week) filter(where ss.phase='main_draw'),
           max(ss.season_week) filter(where ss.phase='full'),
           max(ss.season_week)
         )::integer
  into v_world,v_category,v_draw_size,v_season,v_week
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ts.id
  left join public.tournament_schedule_slots ss on ss.tournament_edition_id=ed.id
  where wc.id=p_competition_id
    and ds.is_enabled
  group by wc.world,ts.category_code,ds.draw_size,ed.season_number;

  if v_world is null
     or v_category not in ('tour_250','tour_500','masters_1000','grand_slam_2000') then
    return 0;
  end if;

  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  if v_now < (v_timeline->>'partnership_deadline_game_second')::bigint - 300
     or v_now >= (v_timeline->>'partnership_deadline_game_second')::bigint then
    return 0;
  end if;

  select count(*) into v_existing
  from public.tournament_doubles_teams
  where competition_id=p_competition_id
    and status in ('confirmed','active','alternate');

  v_needed:=greatest(0,coalesce(v_draw_size,0)-v_existing);

  while v_needed>0 loop
    v_p1:=null;
    v_p2:=null;

    -- First preference: AI already playing singles in this exact tournament.
    select p.id into v_p1
    from public.tournament_entries te
    join public.players p on p.id=te.player_id
    where te.competition_id=p_competition_id
      and te.entry_status='active'
      and te.draw_type in ('qualification','main_draw')
      and p.player_type='ai'
      and not exists(
        select 1 from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
    order by
      case te.draw_type when 'qualification' then 0 else 1 end,
      coalesce(te.ranking_position_snapshot,999999) desc,
      p.id
    limit 1;

    -- Only when the same-event pool is exhausted may a truly free AI be added.
    if v_p1 is null then
      select p.id into v_p1
      from public.players p
      where p.world=v_world
        and p.player_type='ai'
        and p.moderation_status<>'rejected'
        and coalesce(
          (public.check_player_competition_availability_v1(p.id,p_competition_id)->>'available')::boolean,
          false
        )
        and not exists(
          select 1
          from public.tournament_entries te2
          join public.tournament_world_competitions wc2 on wc2.id=te2.competition_id
          join public.tournament_editions ed2 on ed2.id=wc2.tournament_edition_id
          join public.tournament_schedule_slots ss2 on ss2.tournament_edition_id=ed2.id
          where te2.player_id=p.id
            and te2.entry_status='active'
            and ed2.season_number=v_season
            and ss2.season_week=v_week
            and te2.competition_id<>p_competition_id
        )
        and not exists(
          select 1
          from public.tournament_applications ta2
          join public.tournament_world_competitions wc2 on wc2.id=ta2.competition_id
          join public.tournament_editions ed2 on ed2.id=wc2.tournament_edition_id
          join public.tournament_schedule_slots ss2 on ss2.tournament_edition_id=ed2.id
          where ta2.player_id=p.id
            and ta2.status='applied'
            and ed2.season_number=v_season
            and ss2.season_week=v_week
            and ta2.competition_id<>p_competition_id
        )
        and not exists(
          select 1 from public.tournament_doubles_teams t
          where t.competition_id=p_competition_id
            and t.status in ('confirmed','active','alternate')
            and (t.player1_id=p.id or t.player2_id=p.id)
        )
      order by p.id
      limit 1;
    end if;

    exit when v_p1 is null;

    select p.id into v_p2
    from public.tournament_entries te
    join public.players p on p.id=te.player_id
    where te.competition_id=p_competition_id
      and te.entry_status='active'
      and te.draw_type in ('qualification','main_draw')
      and p.player_type='ai'
      and p.id<>v_p1
      and not exists(
        select 1 from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
    order by
      case te.draw_type when 'qualification' then 0 else 1 end,
      coalesce(te.ranking_position_snapshot,999999) desc,
      p.id
    limit 1;

    if v_p2 is null then
      select p.id into v_p2
      from public.players p
      where p.world=v_world
        and p.player_type='ai'
        and p.id<>v_p1
        and p.moderation_status<>'rejected'
        and coalesce(
          (public.check_player_competition_availability_v1(p.id,p_competition_id)->>'available')::boolean,
          false
        )
        and not exists(
          select 1
          from public.tournament_entries te2
          join public.tournament_world_competitions wc2 on wc2.id=te2.competition_id
          join public.tournament_editions ed2 on ed2.id=wc2.tournament_edition_id
          join public.tournament_schedule_slots ss2 on ss2.tournament_edition_id=ed2.id
          where te2.player_id=p.id
            and te2.entry_status='active'
            and ed2.season_number=v_season
            and ss2.season_week=v_week
            and te2.competition_id<>p_competition_id
        )
        and not exists(
          select 1
          from public.tournament_applications ta2
          join public.tournament_world_competitions wc2 on wc2.id=ta2.competition_id
          join public.tournament_editions ed2 on ed2.id=wc2.tournament_edition_id
          join public.tournament_schedule_slots ss2 on ss2.tournament_edition_id=ed2.id
          where ta2.player_id=p.id
            and ta2.status='applied'
            and ed2.season_number=v_season
            and ss2.season_week=v_week
            and ta2.competition_id<>p_competition_id
        )
        and not exists(
          select 1 from public.tournament_doubles_teams t
          where t.competition_id=p_competition_id
            and t.status in ('confirmed','active','alternate')
            and (t.player1_id=p.id or t.player2_id=p.id)
        )
      order by p.id
      limit 1;
    end if;

    exit when v_p2 is null;

    begin
      perform public.create_doubles_team_internal_v1(
        p_competition_id,v_p1,v_p2,'ai_last_minute_fill'
      );

      update public.tournament_doubles_partner_listings
      set status='matched',closed_at=now(),updated_at=now()
      where competition_id=p_competition_id
        and player_id in (v_p1,v_p2)
        and status='active';

      v_created:=v_created+1;
      v_needed:=v_needed-1;
    exception when others then
      exit;
    end;
  end loop;

  return v_created;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.process_due_doubles_entry_lifecycle_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_now bigint:=public.current_game_second_v1();
  v_day record;
  v_current_week integer;
  v_current_abs_week integer;
  r record;
  v_timeline jsonb;
  v_expired integer:=0;
  v_allocated integer:=0;
  v_drawn integer:=0;
  v_ai_listed integer:=0;
  v_ai_paired integer:=0;
  v_ai_late_fill integer:=0;
  v_result jsonb;
  v_n integer;
  v_partnership_closed_at timestamptz;
begin
  select * into v_day from public.get_current_game_day_internal_v1();
  select season_week into v_current_week
  from public.absolute_game_day_v1(
    public.game_day_absolute_v1(v_day.season,v_day.month,v_day.day)
  );
  v_current_abs_week:=(v_day.season-1)*52+v_current_week;

  for r in
    select wc.id competition_id
    from public.tournament_world_competitions wc
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_doubles_settings ds
      on ds.tournament_series_id=ed.tournament_series_id
     and ds.is_enabled
    join lateral (
      select coalesce(
        max(ss.season_week) filter(where ss.phase='main_draw'),
        max(ss.season_week) filter(where ss.phase='full'),
        max(ss.season_week)
      )::integer season_week
      from public.tournament_schedule_slots ss
      where ss.tournament_edition_id=ed.id
    ) slot on slot.season_week is not null
    left join public.tournament_doubles_entry_lifecycle life
      on life.competition_id=wc.id
    where wc.status<>'canceled'
      and ed.status<>'canceled'
      and ((ed.season_number-1)*52+slot.season_week)
          between v_current_abs_week+1 and v_current_abs_week+4
      and not (
        life.draw_processed_at is not null
        and exists(
          select 1 from public.tournament_doubles_draw_publications dp
          where dp.competition_id=wc.id
        )
      )
  loop
    v_timeline:=public.get_tournament_doubles_entry_timeline_v1(r.competition_id);

    insert into public.tournament_doubles_entry_lifecycle(competition_id,updated_at)
    values(r.competition_id,now())
    on conflict(competition_id) do nothing;

    select partnership_closed_at
    into v_partnership_closed_at
    from public.tournament_doubles_entry_lifecycle
    where competition_id=r.competition_id;

    -- Cheap/idempotent and intentionally rerun while open so singles selection
    -- decisions made after doubles registration opens can feed the marketplace.
    if v_now>=(v_timeline->>'registration_open_game_second')::bigint
       and v_now<(v_timeline->>'partnership_deadline_game_second')::bigint then
      v_n:=public.seed_ai_doubles_partner_marketplace_v1(r.competition_id);
      v_ai_listed:=v_ai_listed+coalesce(v_n,0);
    end if;

    -- Five game minutes before partnership close, high-tier events may fill
    -- genuine remaining doubles vacancies without stealing AI already committed
    -- to another singles event in the same week.
    if v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint-300
       and v_now<(v_timeline->>'partnership_deadline_game_second')::bigint then
      v_n:=public.fill_high_tier_ai_doubles_teams_v1(r.competition_id);
      v_ai_late_fill:=v_ai_late_fill+coalesce(v_n,0);
    end if;

    if v_now>=(v_timeline->>'registration_deadline_game_second')::bigint then
      update public.tournament_doubles_entry_lifecycle
      set registration_closed_at=coalesce(registration_closed_at,now()),updated_at=now()
      where competition_id=r.competition_id;
    end if;

    if v_partnership_closed_at is null
       and v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint then
      v_n:=public.expire_doubles_partner_invitations_v1(r.competition_id,v_now);
      v_expired:=v_expired+coalesce(v_n,0);

      v_n:=public.pair_ai_doubles_teams_v1(r.competition_id);
      v_ai_paired:=v_ai_paired+coalesce(v_n,0);

      update public.tournament_doubles_partner_listings
      set status='expired',closed_at=now(),updated_at=now()
      where competition_id=r.competition_id and status='active';

      update public.tournament_doubles_entry_lifecycle
      set partnership_closed_at=now(),updated_at=now()
      where competition_id=r.competition_id;

      if not exists(
        select 1 from public.tournament_doubles_entry_lifecycle
        where competition_id=r.competition_id and allocation_processed_at is not null
      ) then
        v_result:=public.allocate_doubles_entries_v1(r.competition_id);
        if v_result->>'status'='allocated' then v_allocated:=v_allocated+1; end if;
      end if;
    end if;

    if v_now>=(v_timeline->>'draw_lock_game_second')::bigint
       and not exists(
         select 1 from public.tournament_doubles_draw_publications
         where competition_id=r.competition_id
       ) then
      v_result:=public.publish_doubles_draw_v1(r.competition_id);
      if v_result->>'status'='published' then v_drawn:=v_drawn+1; end if;
    end if;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'invitations_expired',v_expired,
    'ai_marketplace_listings',v_ai_listed,
    'ai_teams_created',v_ai_paired,
    'ai_last_minute_teams',v_ai_late_fill,
    'competitions_allocated',v_allocated,
    'draws_published',v_drawn
  );
end;
$function$
;
