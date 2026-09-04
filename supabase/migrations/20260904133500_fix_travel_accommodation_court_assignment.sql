create or replace function public.accommodate_match_travel_v1(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare m public.tournament_matches%rowtype;rule public.tournament_match_scheduling_rules%rowtype;r1 jsonb;r2 jsonb;v_day integer;v_required integer;v_candidate integer;v_court integer;v_selected_start integer;v_selected_court integer;v_found boolean:=false;v_max integer;v_reason text:='standard';
begin
  select * into m from public.tournament_matches where id=p_match_id for update;
  if m.id is null or m.round_number<>1 or m.status not in ('scheduled','in_progress') then return jsonb_build_object('status','not_applicable');end if;
  select r.* into rule from public.tournament_world_competitions wc join public.tournament_editions ed on ed.id=wc.tournament_edition_id join public.tournament_series s on s.id=ed.tournament_series_id join public.tournament_match_scheduling_rules r on r.category_code=s.category_code where wc.id=m.competition_id;
  v_day:=public.tournament_match_absolute_day_v2(m.id);v_required:=coalesce(m.scheduled_start_minute,600);
  if m.player1_id is not null then r1:=public.player_ready_for_tournament_match_v1(m.player1_id,m.id);v_required:=greatest(v_required,((r1->>'ready_absolute_minute')::bigint-v_day::bigint*1440)::integer);end if;
  if m.player2_id is not null then r2:=public.player_ready_for_tournament_match_v1(m.player2_id,m.id);v_required:=greatest(v_required,((r2->>'ready_absolute_minute')::bigint-v_day::bigint*1440)::integer);end if;
  if v_required<=coalesce(m.scheduled_start_minute,600) then return jsonb_build_object('status','unchanged','start_minute',m.scheduled_start_minute,'court',m.court_number);end if;
  for v_candidate in select unnest(rule.regular_slot_minutes||rule.late_slot_minutes) loop
    if v_candidate<v_required then continue;end if;
    for v_court in 1..rule.court_count loop
      if not exists(select 1 from public.tournament_matches x where x.competition_id=m.competition_id and x.id<>m.id and x.scheduled_season_week=m.scheduled_season_week and x.scheduled_day=m.scheduled_day and x.scheduled_start_minute=v_candidate and x.court_number=v_court and x.status<>'cancelled') then v_selected_start:=v_candidate;v_selected_court:=v_court;v_found:=true;exit;end if;
    end loop;
    exit when v_found;
  end loop;
  if v_found then v_reason:='travel_accommodation';update public.tournament_matches set scheduled_start_minute=v_selected_start,court_number=v_selected_court,schedule_reason=v_reason,updated_at=now() where id=m.id;
  else select max(x) into v_max from unnest(rule.regular_slot_minutes||rule.late_slot_minutes) x;v_reason:='travel_risk';update public.tournament_matches set scheduled_start_minute=v_max,court_number=coalesce(court_number,1),schedule_reason=v_reason,updated_at=now() where id=m.id;v_selected_start:=v_max;v_selected_court:=coalesce(m.court_number,1);end if;
  return jsonb_build_object('status',v_reason,'start_minute',v_selected_start,'court',v_selected_court,'required_minute',v_required);
end;$$;
revoke all on function public.accommodate_match_travel_v1(uuid) from public,anon,authenticated;
