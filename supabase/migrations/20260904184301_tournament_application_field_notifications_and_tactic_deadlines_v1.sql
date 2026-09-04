create or replace function public.get_tournament_application_field_v1(p_competition_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_world text;
  v_name text;
  v_main_capacity integer;
  v_qualifier_slots integer;
  v_direct_slots integer;
  v_qcap integer;
  v_phase text;
  v_rows jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select wc.world,ts.name,c.main_draw_capacity,c.default_qualifier_slots,
         c.main_draw_capacity-c.default_qualifier_slots,c.qualifying_capacity_max
  into v_world,v_name,v_main_capacity,v_qualifier_slots,v_direct_slots,v_qcap
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.tournament_categories c on c.code=ts.category_code
  where wc.id=p_competition_id;
  if v_world is null then raise exception 'Tournament not found.'; end if;

  v_phase:=public.get_tournament_entry_lifecycle_v2(p_competition_id)->>'phase';

  with ranked_world as (
    select p.id player_id,
           row_number() over(order by coalesce(pr.ranking_points,0) desc,coalesce(pr.seed_rating,0) desc,p.created_at,p.id)::integer world_rank
    from public.players p
    left join public.player_rankings pr on pr.player_id=p.id
    where p.world=v_world and p.moderation_status<>'rejected'
  ), base as (
    select a.id application_id,a.player_id,p.first_name,p.last_name,p.country_code,p.player_type,
           a.priority,a.accept_qualification,a.application_source,a.status application_status,a.decision_reason,
           rw.world_rank,te.draw_type entry_draw_type,te.entry_status,
           (p.owner_user_id=v_uid) is_user,
           row_number() over(order by rw.world_rank,a.created_at,a.id)::integer overall_order
    from public.tournament_applications a
    join public.players p on p.id=a.player_id
    join ranked_world rw on rw.player_id=a.player_id
    left join public.tournament_entries te on te.competition_id=a.competition_id and te.player_id=a.player_id
    where a.competition_id=p_competition_id and a.status<>'withdrawn'
  ), staged as (
    select b.*,
           count(*) filter(where b.overall_order>v_direct_slots and b.accept_qualification and b.application_status in ('applied','accepted_qualification'))
             over(order by b.overall_order rows between unbounded preceding and current row)::integer as qualification_order
    from base b
  ), projected as (
    select s.*,
      case
        when s.entry_status='active' and s.entry_draw_type='main_draw' then 'main_draw'
        when s.entry_status='active' and s.entry_draw_type='qualification' then 'qualification'
        when s.application_status='accepted_main_draw' then 'main_draw'
        when s.application_status='accepted_qualification' then 'qualification'
        when s.application_status in ('rejected','superseded') then 'outside'
        when s.application_status='applied' and s.overall_order<=v_direct_slots then 'main_draw'
        when s.application_status='applied' and s.overall_order>v_direct_slots and s.accept_qualification and s.qualification_order<=v_qcap then 'qualification'
        else 'outside'
      end projected_group
    from staged s
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'application_id',application_id,'player_id',player_id,'first_name',first_name,'last_name',last_name,
      'country_code',country_code,'player_type',player_type,'world_rank',world_rank,'priority',priority,
      'accept_qualification',accept_qualification,'application_source',application_source,'application_status',application_status,
      'decision_reason',decision_reason,'entry_draw_type',entry_draw_type,'entry_status',entry_status,'is_user',is_user,
      'projected_group',projected_group
    ) order by case projected_group when 'main_draw' then 1 when 'qualification' then 2 else 3 end,world_rank,application_id),'[]'::jsonb)
  into v_rows from projected;

  return jsonb_build_object(
    'competition_id',p_competition_id,'tournament_name',v_name,'world',v_world,'phase',v_phase,
    'main_draw_total_capacity',v_main_capacity,'direct_main_draw_slots',v_direct_slots,'qualifier_slots',v_qualifier_slots,
    'qualification_capacity',v_qcap,'applicant_count',jsonb_array_length(v_rows),'applicants',v_rows
  );
end;$$;
revoke all on function public.get_tournament_application_field_v1(uuid) from public,anon;
grant execute on function public.get_tournament_application_field_v1(uuid) to authenticated;

insert into public.notification_catalog(code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,source_name,title_template,message_template,default_route,severity,default_in_app,default_email,default_push,is_user_configurable,is_active)
values
('tournament.application.submitted','tournament','Tournament application submitted','Confirm that a player application has been recorded.','tournament_application_created','A human player submits a normal tournament application.','Tournament application trigger','Tournament Entry','Application submitted','Your tournament application has been submitted.','/game/calendar?tab=tournament-calendar','info',true,false,false,true,true),
('tournament.application.withdrawn','tournament','Tournament application withdrawn','Confirm a deliberate tournament application withdrawal.','tournament_application_withdrawn','A human player withdraws an application.','Tournament application trigger','Tournament Entry','Application withdrawn','Your tournament application has been withdrawn.','/game/calendar?tab=tournament-calendar','info',true,false,false,true,true),
('tournament.entry.accepted_main','tournament','Accepted into Main Draw','Inform a player that tournament allocation placed them directly into the Main Draw.','tournament_application_decided','A human application becomes accepted_main_draw.','Tournament allocation trigger','Tournament Entry','Main Draw accepted','You were accepted into the tournament Main Draw.','/game/calendar?tab=tournament-calendar','success',true,false,false,true,true),
('tournament.entry.accepted_qualification','tournament','Accepted into Qualification','Inform a player that tournament allocation placed them into Qualification.','tournament_application_decided','A human application becomes accepted_qualification.','Tournament allocation trigger','Tournament Entry','Qualification accepted','You were accepted into tournament Qualification.','/game/calendar?tab=tournament-calendar','success',true,false,false,true,true),
('tournament.entry.rejected','tournament','Tournament application rejected','Inform a player that the normal allocation did not produce a tournament place.','tournament_application_decided','A human application becomes rejected.','Tournament allocation trigger','Tournament Entry','Tournament application rejected','Your tournament application was not accepted.','/game/calendar?tab=tournament-calendar','warning',true,false,false,true,true),
('tournament.preparation.available','tournament','Tournament preparation available','Prompt an accepted player to prepare travel, hotel, staff and default tactic.','tournament_entry_accepted','A human player receives a tournament place.','Tournament application trigger','Tournament Preparation','Prepare your tournament','Your tournament place is confirmed. Open Schedule and prepare travel, hotel, staff and your default tactic.','/game/schedule','info',true,false,false,true,true),
('tournament.draw.published','tournament','Tournament draw published','Tell an entered player when the official draw becomes available.','tournament_draw_published','A draw publication is created for a competition containing the player.','Tournament draw trigger','Tournament Draw','Tournament draw published','The official tournament draw is now available.','/game/calendar?tab=tournament-calendar','info',true,false,false,true,true)
on conflict(code) do update set label=excluded.label,reason=excluded.reason,trigger_event=excluded.trigger_event,trigger_condition=excluded.trigger_condition,trigger_mechanism=excluded.trigger_mechanism,source_name=excluded.source_name,title_template=excluded.title_template,message_template=excluded.message_template,default_route=excluded.default_route,severity=excluded.severity,default_in_app=excluded.default_in_app,is_active=true,updated_at=now();

create or replace function public.notify_human_tournament_application_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_name text;
  v_timeline jsonb;
  v_start jsonb;
  v_start_text text;
  v_route text;
  v_months text[]:=array['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  v_code text;
  v_title text;
  v_message text;
begin
  if new.owner_user_id is null then return new; end if;
  if not exists(select 1 from public.players p where p.id=new.player_id and p.player_type='human') then return new; end if;

  select ts.name into v_name
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=new.competition_id;
  v_timeline:=public.get_tournament_entry_timeline_v1(new.competition_id);
  v_start:=v_timeline->'tournament_start';
  v_start_text:=format('%s %s',v_months[(v_start->>'month')::integer],v_start->>'day');
  v_route:=format('/game/tournaments/%s',new.competition_id);

  if new.status='applied' and (tg_op='INSERT' or old.status is distinct from new.status) then
    v_code:='tournament.application.submitted';
    v_title:='Application submitted · '||v_name;
    v_message:=format('Priority #%s application submitted. Qualification: %s.',coalesce(new.priority,1),case when new.accept_qualification then 'accepted if Main Draw is unavailable' else 'Main Draw only' end);
    perform public.emit_notification_v1(new.owner_user_id,new.player_id,v_code,v_title,v_message,v_route,jsonb_build_object('competition_id',new.competition_id,'priority',new.priority,'accept_qualification',new.accept_qualification),format('tournament-app:%s:submitted:%s',new.id,coalesce(new.updated_at,new.created_at)));
  elsif new.status='accepted_main_draw' and (tg_op='INSERT' or old.status is distinct from new.status) then
    perform public.emit_notification_v1(new.owner_user_id,new.player_id,'tournament.entry.accepted_main','Accepted · Main Draw · '||v_name,format('You are in the Main Draw. Tournament starts %s.',v_start_text),v_route,jsonb_build_object('competition_id',new.competition_id,'draw_type','main_draw','tournament_start',v_start),format('tournament-app:%s:accepted-main',new.id));
    perform public.emit_notification_v1(new.owner_user_id,new.player_id,'tournament.preparation.available','Prepare tournament · '||v_name,format('Your place is confirmed for %s. Open Schedule to prepare travel, hotel, travelling staff and your default tactic.',v_start_text),'/game/schedule',jsonb_build_object('competition_id',new.competition_id,'draw_type','main_draw','tournament_start',v_start),format('tournament-app:%s:prepare',new.id));
  elsif new.status='accepted_qualification' and (tg_op='INSERT' or old.status is distinct from new.status) then
    perform public.emit_notification_v1(new.owner_user_id,new.player_id,'tournament.entry.accepted_qualification','Accepted · Qualification · '||v_name,format('You are in Qualification. Tournament qualification starts %s.',v_start_text),v_route,jsonb_build_object('competition_id',new.competition_id,'draw_type','qualification','tournament_start',v_start),format('tournament-app:%s:accepted-qual',new.id));
    perform public.emit_notification_v1(new.owner_user_id,new.player_id,'tournament.preparation.available','Prepare tournament · '||v_name,format('Your qualification place is confirmed for %s. Open Schedule to prepare your trip and default tactic.',v_start_text),'/game/schedule',jsonb_build_object('competition_id',new.competition_id,'draw_type','qualification','tournament_start',v_start),format('tournament-app:%s:prepare',new.id));
  elsif new.status='rejected' and (tg_op='INSERT' or old.status is distinct from new.status) then
    perform public.emit_notification_v1(new.owner_user_id,new.player_id,'tournament.entry.rejected','Application rejected · '||v_name,'You did not receive a place in this tournament. Check Late Entry or another tournament in the same week if vacancies are available.','/game/calendar?tab=tournament-calendar',jsonb_build_object('competition_id',new.competition_id),format('tournament-app:%s:rejected',new.id));
  elsif new.status='withdrawn' and new.decision_reason='user_withdrawn' and (tg_op='INSERT' or old.status is distinct from new.status or old.decision_reason is distinct from new.decision_reason) then
    perform public.emit_notification_v1(new.owner_user_id,new.player_id,'tournament.application.withdrawn','Application withdrawn · '||v_name,'Your tournament application has been withdrawn.','/game/calendar?tab=tournament-calendar',jsonb_build_object('competition_id',new.competition_id),format('tournament-app:%s:withdrawn',new.id));
  end if;
  return new;
end;$$;

drop trigger if exists trg_notify_human_tournament_application_v1 on public.tournament_applications;
create trigger trg_notify_human_tournament_application_v1
after insert or update of status,decision_reason on public.tournament_applications
for each row execute function public.notify_human_tournament_application_v1();

create or replace function public.notify_human_tournament_draw_published_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare r record;v_name text;begin
  select ts.name into v_name from public.tournament_world_competitions wc join public.tournament_editions ed on ed.id=wc.tournament_edition_id join public.tournament_series ts on ts.id=ed.tournament_series_id where wc.id=new.competition_id;
  for r in select p.owner_user_id,p.id player_id from public.tournament_entries e join public.players p on p.id=e.player_id where e.competition_id=new.competition_id and e.entry_status='active' and p.player_type='human' and p.owner_user_id is not null loop
    perform public.emit_notification_v1(r.owner_user_id,r.player_id,'tournament.draw.published','Draw published · '||v_name,'The official draw is available. Open the tournament to see the qualification/main-draw bracket and your scheduled match.',format('/game/tournaments/%s',new.competition_id),jsonb_build_object('competition_id',new.competition_id),format('tournament-draw:%s:%s',new.competition_id,r.player_id));
  end loop;
  return new;
end;$$;

drop trigger if exists trg_notify_human_tournament_draw_published_v1 on public.tournament_draw_publications;
create trigger trg_notify_human_tournament_draw_published_v1
after insert on public.tournament_draw_publications
for each row execute function public.notify_human_tournament_draw_published_v1();

create or replace function public.get_tournament_match_tactic_v1(p_player_id uuid,p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid:=auth.uid();v_match public.tournament_matches%rowtype;v_override public.player_tournament_match_tactics%rowtype;v_plan public.player_tournament_preparation_plans%rowtype;v_tournament jsonb;v_effective jsonb;v_override_json jsonb:=null;v_source text:='automatic_default';v_lock bigint;v_now bigint:=public.current_game_second_v1();v_editable boolean;
begin
  if v_uid is null then raise exception 'Authentication required.';end if;
  if not exists(select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid) then raise exception 'Player access denied.';end if;
  select * into v_match from public.tournament_matches m where m.id=p_match_id;if not found then raise exception 'Match not found.';end if;
  if p_player_id is distinct from v_match.player1_id and p_player_id is distinct from v_match.player2_id then raise exception 'This player is not in the selected match.';end if;
  v_lock:=public.tournament_match_game_second_v1(p_match_id)-3600;v_editable:=v_match.status='scheduled' and (v_lock is null or v_now<v_lock);
  select * into v_plan from public.player_tournament_preparation_plans p where p.player_id=p_player_id and p.competition_id=v_match.competition_id;
  if found then v_tournament:=jsonb_build_object('preset',v_plan.tactic_preset,'approach',v_plan.tactic_approach,'rally',v_plan.tactic_rally,'serve',v_plan.tactic_serve,'returnGame',v_plan.tactic_return,'courtPosition',v_plan.tactic_court_position,'target',v_plan.tactic_target,'risk',v_plan.tactic_risk);v_source:='tournament_default';
  else v_tournament:=jsonb_build_object('preset','Balanced','approach','Balanced','rally','Balanced rallies','serve','Balanced','returnGame','Balanced','courtPosition','Normal baseline','target','Automatic','risk','Balanced');end if;
  select * into v_override from public.player_tournament_match_tactics t where t.player_id=p_player_id and t.match_id=p_match_id;
  if found then v_override_json:=jsonb_build_object('preset',v_override.tactic_preset,'approach',v_override.tactic_approach,'rally',v_override.tactic_rally,'serve',v_override.tactic_serve,'returnGame',v_override.tactic_return,'courtPosition',v_override.tactic_court_position,'target',v_override.tactic_target,'risk',v_override.tactic_risk);v_effective:=v_override_json;v_source:='match_override';else v_effective:=v_tournament;end if;
  return jsonb_build_object('match_status',v_match.status,'editable',v_editable,'tactic_lock_game_second',v_lock,'source',v_source,'tournament_default',v_tournament,'override',v_override_json,'effective',v_effective);
end;$$;

create or replace function public.save_tournament_match_tactic_v1(p_player_id uuid,p_match_id uuid,p_tactic_preset text,p_tactic_approach text,p_tactic_rally text,p_tactic_serve text,p_tactic_return text,p_tactic_court_position text,p_tactic_target text,p_tactic_risk text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare v_uid uuid:=auth.uid();v_match public.tournament_matches%rowtype;v_lock bigint;begin
  if v_uid is null then raise exception 'Authentication required.';end if;
  if not exists(select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid) then raise exception 'Player access denied.';end if;
  select * into v_match from public.tournament_matches m where m.id=p_match_id;if not found then raise exception 'Match not found.';end if;
  if p_player_id is distinct from v_match.player1_id and p_player_id is distinct from v_match.player2_id then raise exception 'This player is not in the selected match.';end if;
  if v_match.status<>'scheduled' then raise exception 'Match tactic can only be changed before the match starts.';end if;
  v_lock:=public.tournament_match_game_second_v1(p_match_id)-3600;
  if v_lock is not null and public.current_game_second_v1()>=v_lock then raise exception 'Match-specific tactics lock 60 minutes before the scheduled match start.';end if;
  insert into public.player_tournament_match_tactics(owner_user_id,player_id,match_id,tactic_preset,tactic_approach,tactic_rally,tactic_serve,tactic_return,tactic_court_position,tactic_target,tactic_risk,updated_at)
  values(v_uid,p_player_id,p_match_id,p_tactic_preset,p_tactic_approach,p_tactic_rally,p_tactic_serve,p_tactic_return,p_tactic_court_position,p_tactic_target,p_tactic_risk,now())
  on conflict(player_id,match_id) do update set owner_user_id=excluded.owner_user_id,tactic_preset=excluded.tactic_preset,tactic_approach=excluded.tactic_approach,tactic_rally=excluded.tactic_rally,tactic_serve=excluded.tactic_serve,tactic_return=excluded.tactic_return,tactic_court_position=excluded.tactic_court_position,tactic_target=excluded.tactic_target,tactic_risk=excluded.tactic_risk,updated_at=now();
  return public.get_tournament_match_tactic_v1(p_player_id,p_match_id);
end;$$;
