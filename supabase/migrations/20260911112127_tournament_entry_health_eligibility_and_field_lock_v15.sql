create or replace function public.player_tournament_entry_health_eligible_v1(p_player_id uuid,p_competition_id uuid)
returns boolean
language plpgsql
stable security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_tl jsonb;
  v_start integer;
begin
  v_tl:=public.get_tournament_entry_timeline_v1(p_competition_id);
  v_start:=nullif(v_tl->'tournament_start'->>'absolute_day','')::integer;
  if v_start is null then return false; end if;
  return not public.player_tournament_blocked_by_health_v1(p_player_id,v_start);
end;
$$;

revoke all on function public.player_tournament_entry_health_eligible_v1(uuid,uuid) from public;
grant execute on function public.player_tournament_entry_health_eligible_v1(uuid,uuid) to authenticated,service_role;

create or replace function public.get_tournament_entry_health_status_v1(p_competition_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_player uuid;
  v_tl jsonb;
  v_start integer;
  v_eligible boolean;
  v_return integer;
  v_summary jsonb;
  v_condition jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=auth.uid() and player_type='human' order by created_at desc limit 1;
  if v_player is null then raise exception 'Player profile required.'; end if;
  v_tl:=public.get_tournament_entry_timeline_v1(p_competition_id);
  v_start:=nullif(v_tl->'tournament_start'->>'absolute_day','')::integer;
  if v_start is null then raise exception 'Tournament start date is unavailable.'; end if;
  v_eligible:=public.player_tournament_entry_health_eligible_v1(v_player,p_competition_id);
  v_summary:=public.get_player_health_summary_v1(v_player,null);
  v_condition:=v_summary->'primary_condition';
  select min(x.return_day) into v_return from (
    select tournament_return_absolute_day return_day from public.player_injuries
      where player_id=v_player and status in('active','recovering') and v_start<tournament_return_absolute_day
    union all
    select tournament_return_absolute_day from public.player_illnesses
      where player_id=v_player and status in('active','recovering') and v_start<tournament_return_absolute_day
  ) x;
  return jsonb_build_object(
    'eligible',v_eligible,
    'tournament_start_absolute_day',v_start,
    'projected_tournament_return_absolute_day',v_return,
    'current_health',v_summary,
    'primary_condition',v_condition,
    'reason',case when v_eligible then 'Projected medically available by tournament start.' else 'Projected medically unavailable when the tournament begins.' end
  );
end;
$$;

revoke all on function public.get_tournament_entry_health_status_v1(uuid) from public;
grant execute on function public.get_tournament_entry_health_status_v1(uuid) to authenticated,service_role;

create or replace function public.guard_human_tournament_application_health_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
begin
  if new.owner_user_id is null then return new; end if;
  if not exists(select 1 from public.players p where p.id=new.player_id and p.player_type='human') then return new; end if;
  if new.status='applied' or (new.application_source='human_late' and new.status in('accepted_main_draw','accepted_qualification')) then
    if not public.player_tournament_entry_health_eligible_v1(new.player_id,new.competition_id) then
      raise exception 'Medical restriction: your current recovery date is after this tournament begins. Choose a later tournament.' using errcode='P0001';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_human_tournament_application_health on public.tournament_applications;
create trigger guard_human_tournament_application_health
before insert or update of status on public.tournament_applications
for each row execute function public.guard_human_tournament_application_health_v1();

insert into public.notification_catalog(code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,source_name,title_template,message_template,default_route,severity,default_in_app,default_email,default_push,is_user_configurable,is_active)
values(
  'player.health.tournament_withdrawn','player_health','Tournament withdrawn for health','Explain when an accepted tournament entry is removed before the draw because the player will still be medically unavailable at tournament start.','tournament field lock','Accepted player remains medically unavailable at tournament start.','Tournament health','tournament_entries','Tournament entry withdrawn for health','Your tournament entry was withdrawn because your medical return date is after the tournament begins.','/game/injuries','warning',true,false,false,false,true
)
on conflict(code) do update set label=excluded.label,reason=excluded.reason,trigger_event=excluded.trigger_event,trigger_condition=excluded.trigger_condition,trigger_mechanism=excluded.trigger_mechanism,source_name=excluded.source_name,title_template=excluded.title_template,message_template=excluded.message_template,default_route=excluded.default_route,severity=excluded.severity,is_active=true,updated_at=now();

create or replace function public.lock_tournament_field_v1(p_competition_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_tl jsonb;
  v_now bigint:=public.current_game_second_v1();
  r record;
  v_removed integer:=0;
begin
  if exists(select 1 from public.tournament_matches where competition_id=p_competition_id) then return jsonb_build_object('status','draw_already_exists'); end if;
  v_tl:=public.get_tournament_entry_timeline_v1(p_competition_id);
  if v_now>=(v_tl->'tournament_start'->>'game_second')::bigint then return jsonb_build_object('status','tournament_started'); end if;
  insert into public.tournament_competition_entry_cycles(competition_id) values(p_competition_id) on conflict do nothing;
  if exists(select 1 from public.tournament_competition_entry_cycles where competition_id=p_competition_id and field_locked_at is not null) then return jsonb_build_object('status','already_locked'); end if;
  if v_now<(v_tl->>'late_close_game_second')::bigint then return jsonb_build_object('status','not_due'); end if;

  for r in
    select te.id entry_id,te.player_id,p.owner_user_id,ts.name tournament_name
    from public.tournament_entries te
    join public.players p on p.id=te.player_id
    join public.tournament_world_competitions wc on wc.id=te.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    where te.competition_id=p_competition_id and te.entry_status='active'
      and not public.player_tournament_entry_health_eligible_v1(te.player_id,p_competition_id)
  loop
    update public.tournament_entries set entry_status='withdrawn',updated_at=now() where id=r.entry_id;
    update public.tournament_applications
      set status='withdrawn',decision_reason='medical_unavailable_at_tournament_start',decided_at=coalesce(decided_at,now()),updated_at=now()
      where competition_id=p_competition_id and player_id=r.player_id and status in('accepted_main_draw','accepted_qualification','applied');
    v_removed:=v_removed+1;
    if r.owner_user_id is not null then
      perform public.emit_notification_v1(
        r.owner_user_id,r.player_id,'player.health.tournament_withdrawn','Tournament entry withdrawn for health',
        format('Your %s entry was withdrawn because your medical return date is after the tournament begins.',r.tournament_name),
        '/game/injuries',jsonb_build_object('competition_id',p_competition_id,'reason','medical_unavailable_at_tournament_start'),
        'health-tournament-withdrawn:'||p_competition_id::text||':'||r.player_id::text
      );
    end if;
  end loop;

  perform public.fill_ai_late_tournament_vacancies_v1(p_competition_id);
  update public.tournament_competition_entry_cycles set field_locked_at=now(),field_locked_game_second=v_now,updated_at=now() where competition_id=p_competition_id;
  update public.tournament_applications set status='rejected',decision_reason=coalesce(decision_reason,'late_entry_closed_without_place'),decided_at=coalesce(decided_at,now()),updated_at=now() where competition_id=p_competition_id and status='applied';
  return jsonb_build_object('status','locked','health_withdrawals',v_removed);
end;
$$;
