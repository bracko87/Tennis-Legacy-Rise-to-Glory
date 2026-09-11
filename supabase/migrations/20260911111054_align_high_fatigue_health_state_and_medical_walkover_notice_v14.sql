insert into public.notification_catalog(code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,source_name,title_template,message_template,default_route,severity,default_in_app,default_email,default_push,is_user_configurable,is_active)
values(
  'player.health.medical_walkover','player_health','Medical walkover','Explain when a player cannot compete because the medical return date has not been reached.','match health resolution','A scheduled tournament match reaches preparation while the player is medically unavailable.','Tournament health','tournament_matches','Medical walkover','You were medically unavailable for this match, so the opponent advanced by walkover.','/game/injuries','warning',true,false,false,false,true
)
on conflict(code) do update set label=excluded.label,reason=excluded.reason,trigger_event=excluded.trigger_event,trigger_condition=excluded.trigger_condition,trigger_mechanism=excluded.trigger_mechanism,source_name=excluded.source_name,title_template=excluded.title_template,message_template=excluded.message_template,default_route=excluded.default_route,severity=excluded.severity,is_active=true,updated_at=now();

create or replace function public.get_player_health_summary_v1(p_player_id uuid, p_absolute_day integer default null::integer)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public','pg_temp'
as $function$
declare
 v_day integer:=p_absolute_day;e jsonb;ir jsonb;sr jsonb;v_injury_count integer;v_illness_count integer;v_primary jsonb;v_state text;v_latest_recovery integer;v_expected_today boolean:=false;v_fatigue integer:=0;
begin
 if v_day is null then select public.game_day_absolute_v1(d.season,d.month,d.day) into v_day from public.get_current_game_day_internal_v1() d; end if;
 select coalesce(fatigue,0) into v_fatigue from public.player_skills where player_id=p_player_id;
 e:=public.get_player_active_injury_effects_v1(p_player_id,v_day);ir:=public.get_player_injury_risk_v1(p_player_id,'general',null,0,0);sr:=public.get_player_illness_risk_v1(p_player_id);
 select count(*) into v_injury_count from public.player_injuries where player_id=p_player_id and status in('active','recovering') and v_day<expected_full_recovery_absolute_day;
 select count(*) into v_illness_count from public.player_illnesses where player_id=p_player_id and status in('active','recovering') and v_day<expected_full_recovery_absolute_day;
 select exists(
   select 1 from public.player_injuries where player_id=p_player_id and expected_full_recovery_absolute_day=v_day and status in('active','recovering','recovered')
   union all select 1 from public.player_illnesses where player_id=p_player_id and expected_full_recovery_absolute_day=v_day and status in('active','recovering','recovered')
 ) into v_expected_today;
 select x.obj into v_primary from (
   select jsonb_build_object('kind','injury','id',i.id,'code',i.injury_code,'name',c.name,'body_area',c.body_area,'severity',i.severity,'onset_absolute_day',i.onset_absolute_day,
     'progress_percent',public.health_recovery_progress_v1(i.onset_absolute_day,i.expected_full_recovery_absolute_day,v_day),
     'training_return_absolute_day',i.training_return_absolute_day,'tournament_return_absolute_day',i.tournament_return_absolute_day,'expected_full_recovery_absolute_day',i.expected_full_recovery_absolute_day,'performance_penalty',i.performance_penalty) obj,
     case i.severity when 'severe' then 4 when 'major' then 3 when 'moderate' then 2 else 1 end sev,i.onset_absolute_day
   from public.player_injuries i join public.injury_catalog c on c.code=i.injury_code where i.player_id=p_player_id and i.status in('active','recovering') and v_day<i.expected_full_recovery_absolute_day
   union all
   select jsonb_build_object('kind','illness','id',i.id,'code',i.illness_code,'name',c.name,'body_area',null,'severity',i.severity,'onset_absolute_day',i.onset_absolute_day,
     'progress_percent',public.health_recovery_progress_v1(i.onset_absolute_day,i.expected_full_recovery_absolute_day,v_day),
     'training_return_absolute_day',i.training_return_absolute_day,'tournament_return_absolute_day',i.tournament_return_absolute_day,'expected_full_recovery_absolute_day',i.expected_full_recovery_absolute_day,'performance_penalty',i.performance_penalty),
     case i.severity when 'severe' then 4 when 'moderate' then 2 else 1 end,i.onset_absolute_day
   from public.player_illnesses i join public.illness_catalog c on c.code=i.illness_code where i.player_id=p_player_id and i.status in('active','recovering') and v_day<i.expected_full_recovery_absolute_day
   order by sev desc,onset_absolute_day desc limit 1
 ) x;
 select max(recovered_absolute_day) into v_latest_recovery from (
   select recovered_absolute_day from public.player_injuries where player_id=p_player_id and status='recovered'
   union all select recovered_absolute_day from public.player_illnesses where player_id=p_player_id and status='recovered'
 ) z;
 if v_injury_count+v_illness_count>0 then
   if not (e->>'can_train')::boolean then
     if coalesce((v_primary->>'onset_absolute_day')::integer,-1)=v_day then
       v_state:=case when coalesce(v_primary->>'kind','')='illness' then 'ill' else 'injured' end;
     else v_state:='recovering'; end if;
   elsif not (e->>'can_compete')::boolean then v_state:='recovering';
   else v_state:='not_fully_fit';end if;
 elsif v_expected_today or v_latest_recovery=v_day then v_state:='fully_recovered';
 elsif v_fatigue>=65 or (ir->>'risk_level') in('elevated','high','very_high') or (sr->>'risk_level') in('elevated','high','very_high') then v_state:='at_risk';
 else v_state:='healthy';end if;
 return jsonb_build_object('state',v_state,'label',case v_state when 'healthy' then 'Healthy' when 'at_risk' then 'At risk' when 'ill' then 'Ill' when 'injured' then 'Injured' when 'recovering' then 'Recovering' when 'not_fully_fit' then 'Not fully fit' when 'fully_recovered' then 'Fully recovered' else initcap(replace(v_state,'_',' ')) end,
   'can_train',(e->>'can_train')::boolean,'can_compete',(e->>'can_compete')::boolean,'performance_penalty',(e->>'overall_penalty')::numeric,'injury_count',v_injury_count,'illness_count',v_illness_count,'primary_condition',v_primary,'injury_risk',ir,'illness_risk',sr,'last_recovered_absolute_day',coalesce(v_latest_recovery,case when v_expected_today then v_day else null end),'absolute_day',v_day,'fatigue',v_fatigue);
end;
$function$;

create or replace function public.prepare_tournament_match_simulation_v1(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  sim jsonb; existing public.tournament_match_simulations%rowtype; r jsonb; w jsonb; m public.tournament_matches%rowtype;
  v_day integer; p1_block boolean; p2_block boolean; v_winner uuid; v_r1 integer; v_r2 integer;
  v_owner uuid; v_blocked uuid;
begin
  select * into existing from public.tournament_match_simulations where match_id=p_match_id;
  if existing.match_id is not null then return jsonb_build_object('status',existing.simulation_status,'match_id',p_match_id,'already_exists',true); end if;
  select * into m from public.tournament_matches where id=p_match_id for update;
  if m.id is null then raise exception 'Match not found.'; end if;
  if m.status<>'scheduled' or m.player1_id is null or m.player2_id is null then raise exception 'Scheduled match with two players required.'; end if;
  v_day:=public.tournament_match_absolute_day_v2(p_match_id);
  p1_block:=public.player_tournament_blocked_by_health_v1(m.player1_id,v_day);
  p2_block:=public.player_tournament_blocked_by_health_v1(m.player2_id,v_day);
  if p1_block or p2_block then
    if p1_block and not p2_block then v_winner:=m.player2_id;
    elsif p2_block and not p1_block then v_winner:=m.player1_id;
    else
      select coalesce(min(return_day),v_day+999) into v_r1 from (
        select tournament_return_absolute_day as return_day from public.player_injuries where player_id=m.player1_id and status in('active','recovering') and v_day<tournament_return_absolute_day
        union all select tournament_return_absolute_day from public.player_illnesses where player_id=m.player1_id and status in('active','recovering') and v_day<tournament_return_absolute_day
      ) q;
      select coalesce(min(return_day),v_day+999) into v_r2 from (
        select tournament_return_absolute_day as return_day from public.player_injuries where player_id=m.player2_id and status in('active','recovering') and v_day<tournament_return_absolute_day
        union all select tournament_return_absolute_day from public.player_illnesses where player_id=m.player2_id and status in('active','recovering') and v_day<tournament_return_absolute_day
      ) q;
      v_winner:=case when v_r1<=v_r2 then m.player1_id else m.player2_id end;
    end if;
    update public.tournament_matches set status='completed',winner_id=v_winner,started_at=coalesce(started_at,now()),completed_at=now(),actual_duration_minutes=null,completion_reason='health_walkover',updated_at=now() where id=p_match_id;
    for v_blocked in select x.pid from (values (m.player1_id,p1_block),(m.player2_id,p2_block)) x(pid,blocked) where x.blocked loop
      select owner_user_id into v_owner from public.players where id=v_blocked;
      if v_owner is not null then
        perform public.emit_notification_v1(v_owner,v_blocked,'player.health.medical_walkover','Medical walkover',
          'You were medically unavailable for this match, so the opponent advanced by walkover.',
          '/game/injuries',jsonb_build_object('match_id',p_match_id,'completion_reason','health_walkover','match_absolute_day',v_day),
          'health-walkover:'||p_match_id::text||':'||v_blocked::text);
      end if;
    end loop;
    return jsonb_build_object('status','walkover','reason','health_unavailable','match_id',p_match_id,'winner_id',v_winner,'player1_blocked',p1_block,'player2_blocked',p2_block);
  end if;
  w:=public.ensure_tournament_match_weather_v1(p_match_id);sim:=public.simulate_tournament_match_v2(p_match_id,null);
  sim:=jsonb_set(sim,'{metadata}',coalesce(sim->'metadata','{}'::jsonb)||jsonb_build_object('weather',w,'engine_scope',jsonb_build_object('tactics',true,'playing_style',true,'weather',true,'injuries',true,'illness',true,'equipment',false,'staff',false)));
  r:=public.register_tournament_match_simulation_v1(p_match_id,sim->>'engine_version',sim->>'engine_seed',(sim->>'winner_id')::uuid,sim->'final_score',sim->'sets',sim->'player1_stats',sim->'player2_stats',sim->'events',(sim->>'replay_duration_seconds')::integer,(sim->>'total_points')::integer,(sim->>'total_games')::integer,sim->'metadata');
  return r||jsonb_build_object('engine_version',sim->>'engine_version');
end;
$function$;
