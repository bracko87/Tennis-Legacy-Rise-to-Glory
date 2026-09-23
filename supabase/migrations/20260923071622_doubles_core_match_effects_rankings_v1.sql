-- ---------------------------------------------------------------------------
-- 5. Match simulation, fatigue and equipment wear
-- ---------------------------------------------------------------------------

create or replace function public.doubles_team_strength_v1(p_team_id uuid,p_surface text)
returns numeric
language plpgsql stable security definer set search_path=public
as $$
declare
  t public.tournament_doubles_teams%rowtype;v_player uuid;s public.player_skills%rowtype;e jsonb;v numeric:=0;v_one numeric;v_mod numeric;
begin
  select * into t from public.tournament_doubles_teams where id=p_team_id;
  if t.id is null then return 0; end if;
  foreach v_player in array array[t.player1_id,t.player2_id] loop
    select * into s from public.player_skills where player_id=v_player;
    if s.player_id is null then continue; end if;
    e:=public.get_equipment_match_modifiers_readonly_v2(v_player,coalesce(p_surface,'hard'));
    v_mod:=coalesce((e->>'serve_pct')::numeric,0)*0.18+coalesce((e->>'return_pct')::numeric,0)*0.16+
           coalesce((e->>'rally_pct')::numeric,0)*0.18+coalesce((e->>'net_pct')::numeric,0)*0.22+
           coalesce((e->>'movement_pct')::numeric,0)*0.10+coalesce((e->>'stamina_pct')::numeric,0)*0.08+
           coalesce((e->>'focus_pct')::numeric,0)*0.08;
    v_one:=s.serve*0.18+s.return_skill*0.15+s.volley*0.20+s.forehand*0.10+s.backhand*0.09+s.movement*0.09+s.stamina*0.07+s.focus*0.07+s.smash*0.05;
    v_one:=v_one*(1+v_mod/100.0)*greatest(0.70,1-s.fatigue*0.003);
    v:=v+v_one;
  end loop;
  return round(v/2.0,4);
end;
$$;

create or replace function public.apply_doubles_equipment_wear_v1(p_player_id uuid,p_doubles_match_id uuid,p_surface text,p_multiplier numeric)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  l public.player_equipment_loadouts%rowtype;rb numeric;ra numeric;sb numeric;sa numeric;ab numeric;aa numeric;rw numeric:=0;sw numeric:=0;aw numeric:=0;
  shoe_surface text;shoe_mult numeric:=1;bag_protect numeric:=0;a record;before_acc jsonb:='{}'::jsonb;after_acc jsonb:='{}'::jsonb;a_after numeric;v_surface text:=lower(coalesce(p_surface,'hard'));v_mult numeric:=greatest(0.1,least(1,coalesce(p_multiplier,0.7)));
begin
  if exists(select 1 from public.player_doubles_equipment_wear_events where player_id=p_player_id and doubles_match_id=p_doubles_match_id) then return jsonb_build_object('status','already_applied'); end if;
  select * into l from public.player_equipment_loadouts where player_id=p_player_id;
  if l.player_id is null then return jsonb_build_object('status','no_loadout'); end if;
  select i.condition,c.wear_per_match into rb,rw from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id where i.id=l.racket_inventory_id and i.player_id=p_player_id for update of i;
  select i.condition,c.wear_per_match,c.surface,c.wrong_surface_wear_multiplier into sb,sw,shoe_surface,shoe_mult from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id where i.id=l.shoes_inventory_id and i.player_id=p_player_id for update of i;
  select i.condition,c.wear_per_match into ab,aw from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id where i.id=l.apparel_inventory_id and i.player_id=p_player_id for update of i;
  select coalesce(max(coalesce((c.gameplay_effects->>'racket_wear_reduction_pct')::numeric,0)*public.equipment_condition_factor_v1(i.condition)),0) into bag_protect
  from public.player_equipment_accessory_loadout al join public.player_equipment_inventory i on i.id=al.inventory_id and i.player_id=al.player_id join public.equipment_catalog_items c on c.id=i.catalog_item_id where al.player_id=p_player_id and c.accessory_kind='bag';
  ra:=greatest(0,round(coalesce(rb,0)-(coalesce(rw,0)*(1-greatest(0,least(35,bag_protect))/100.0)*v_mult),2));
  sa:=greatest(0,round(coalesce(sb,0)-(case when shoe_surface=v_surface then coalesce(sw,0) when shoe_surface='all' then coalesce(sw,0)*1.15 else coalesce(sw,0)*coalesce(shoe_mult,1.8) end)*v_mult,2));
  aa:=greatest(0,round(coalesce(ab,0)-coalesce(aw,0)*v_mult,2));
  if l.racket_inventory_id is not null then update public.player_equipment_inventory set condition=ra,updated_at=now() where id=l.racket_inventory_id and player_id=p_player_id; end if;
  if l.shoes_inventory_id is not null then update public.player_equipment_inventory set condition=sa,updated_at=now() where id=l.shoes_inventory_id and player_id=p_player_id; end if;
  if l.apparel_inventory_id is not null then update public.player_equipment_inventory set condition=aa,updated_at=now() where id=l.apparel_inventory_id and player_id=p_player_id; end if;
  for a in select al.accessory_kind,i.id inventory_id,i.condition,c.wear_per_match from public.player_equipment_accessory_loadout al join public.player_equipment_inventory i on i.id=al.inventory_id and i.player_id=al.player_id join public.equipment_catalog_items c on c.id=i.catalog_item_id where al.player_id=p_player_id for update of i loop
    before_acc:=before_acc||jsonb_build_object(a.accessory_kind,jsonb_build_object('inventory_id',a.inventory_id,'condition',a.condition));
    a_after:=greatest(0,round(a.condition-coalesce(a.wear_per_match,0)*v_mult,2));
    update public.player_equipment_inventory set condition=a_after,updated_at=now() where id=a.inventory_id and player_id=p_player_id;
    after_acc:=after_acc||jsonb_build_object(a.accessory_kind,jsonb_build_object('inventory_id',a.inventory_id,'condition',a_after));
  end loop;
  insert into public.player_doubles_equipment_wear_events(doubles_match_id,player_id,surface,wear_multiplier,racket_before,racket_after,shoes_before,shoes_after,apparel_before,apparel_after,accessories_before,accessories_after)
  values(p_doubles_match_id,p_player_id,v_surface,v_mult,rb,ra,sb,sa,ab,aa,before_acc,after_acc);
  return jsonb_build_object('status','applied','wear_multiplier',v_mult,'racket',jsonb_build_array(rb,ra),'shoes',jsonb_build_array(sb,sa),'apparel',jsonb_build_array(ab,aa));
end;
$$;

create or replace function public.apply_doubles_match_effects_v1()
returns trigger language plpgsql security definer set search_path=public
as $$
declare
  t1 public.tournament_doubles_teams%rowtype;t2 public.tournament_doubles_teams%rowtype;v_player uuid;s public.player_skills%rowtype;
  v_surface text;v_fatigue_mult numeric;v_wear_mult numeric;v_gain integer;v_after smallint;v_win boolean;
begin
  if new.status<>'completed' or new.winner_team_id is null or (tg_op='UPDATE' and old.status='completed') then return new; end if;
  select * into t1 from public.tournament_doubles_teams where id=new.team1_id;
  select * into t2 from public.tournament_doubles_teams where id=new.team2_id;
  select ts.surface,ds.fatigue_multiplier,ds.equipment_wear_multiplier into v_surface,v_fatigue_mult,v_wear_mult
  from public.tournament_world_competitions wc join public.tournament_editions e on e.id=wc.tournament_edition_id join public.tournament_series ts on ts.id=e.tournament_series_id join public.tournament_doubles_settings ds on ds.tournament_series_id=ts.id where wc.id=new.competition_id;
  foreach v_player in array array[t1.player1_id,t1.player2_id,t2.player1_id,t2.player2_id] loop
    if v_player is null or exists(select 1 from public.player_doubles_match_condition_events where doubles_match_id=new.id and player_id=v_player) then continue; end if;
    select * into s from public.player_skills where player_id=v_player for update;
    if s.player_id is null then continue; end if;
    v_win:=(new.winner_team_id=t1.id and v_player in (t1.player1_id,t1.player2_id)) or (new.winner_team_id=t2.id and v_player in (t2.player1_id,t2.player2_id));
    v_gain:=greatest(3,round(public.calculate_match_fatigue_v2(greatest(20,coalesce(new.actual_duration_minutes,90)),greatest(2,coalesce(new.sets_played,2)),greatest(6,coalesce(new.games_played,20)),s.fitness,s.stamina,s.recovery,v_surface)*v_fatigue_mult));
    v_after:=least(100,s.fatigue+v_gain)::smallint;
    update public.player_skills set fatigue=v_after,sharpness=least(100,s.sharpness+1),morale=greatest(1,least(100,s.morale+case when v_win then 1 else -1 end)),confidence=greatest(1,least(100,s.confidence+case when v_win then 2 else -1 end)),updated_at=now() where player_id=v_player;
    insert into public.player_doubles_match_condition_events(doubles_match_id,player_id,outcome,surface,estimated_match_minutes,sets_played,games_played,fatigue_before,fatigue_after)
    values(new.id,v_player,case when v_win then 'win' else 'loss' end,coalesce(v_surface,'hard'),coalesce(new.actual_duration_minutes,90),coalesce(new.sets_played,2),coalesce(new.games_played,20),s.fatigue,v_after);
    if exists(select 1 from public.players where id=v_player and owner_user_id is not null) then perform public.apply_doubles_equipment_wear_v1(v_player,new.id,v_surface,v_wear_mult); end if;
  end loop;
  return new;
end;
$$;
drop trigger if exists trg_apply_doubles_match_effects_v1 on public.tournament_doubles_matches;
create trigger trg_apply_doubles_match_effects_v1 after update of status on public.tournament_doubles_matches
for each row when (new.status='completed' and old.status is distinct from 'completed') execute function public.apply_doubles_match_effects_v1();

create or replace function public.doubles_match_game_second_v1(p_match_id uuid)
returns bigint language sql stable security definer set search_path=public
as $$
 select ((((e.season_number-1)::bigint*366)+2+((m.scheduled_season_week-1)::bigint*7)+(m.scheduled_day-1)::bigint)*86400 + coalesce(m.scheduled_start_minute,600)::bigint*60)
 from public.tournament_doubles_matches m join public.tournament_world_competitions wc on wc.id=m.competition_id join public.tournament_editions e on e.id=wc.tournament_edition_id where m.id=p_match_id;
$$;

create or replace function public.simulate_doubles_match_v1(p_match_id uuid)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  m public.tournament_doubles_matches%rowtype;v_surface text;v_s1 numeric;v_s2 numeric;v_p numeric;v_roll numeric;v_winner uuid;v_sets smallint;v_games integer;v_minutes integer;
begin
  select * into m from public.tournament_doubles_matches where id=p_match_id for update;
  if m.id is null then return jsonb_build_object('status','missing'); end if;
  if m.status<>'scheduled' or m.team1_id is null or m.team2_id is null then return jsonb_build_object('status','not_ready'); end if;
  select ts.surface into v_surface from public.tournament_world_competitions wc join public.tournament_editions e on e.id=wc.tournament_edition_id join public.tournament_series ts on ts.id=e.tournament_series_id where wc.id=m.competition_id;
  v_s1:=greatest(1,public.doubles_team_strength_v1(m.team1_id,v_surface));v_s2:=greatest(1,public.doubles_team_strength_v1(m.team2_id,v_surface));
  v_p:=v_s1/(v_s1+v_s2);v_roll:=random();v_winner:=case when v_roll<=v_p then m.team1_id else m.team2_id end;
  v_sets:=case when abs(v_s1-v_s2)<8 and random()<0.55 then 3 else 2 end;
  v_games:=case when v_sets=3 then 24+floor(random()*10)::integer else 16+floor(random()*9)::integer end;
  v_minutes:=greatest(55,least(150,round(40+v_games*2.2+case when v_sets=3 then 12 else 0 end)::integer));
  update public.tournament_doubles_matches set status='completed',winner_team_id=v_winner,actual_duration_minutes=v_minutes,sets_played=v_sets,games_played=v_games,completion_reason='played',started_at=coalesce(started_at,now()),completed_at=now(),simulation_metadata=jsonb_build_object('team1_strength',round(v_s1,2),'team2_strength',round(v_s2,2),'team1_win_probability',round(v_p,4)),updated_at=now() where id=m.id;
  return jsonb_build_object('status','completed','winner_team_id',v_winner,'duration_minutes',v_minutes,'sets_played',v_sets,'games_played',v_games);
end;
$$;

create or replace function public.process_due_doubles_matches_v1()
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare m record;v_now bigint:=public.current_game_second_v1();v_count integer:=0;begin
  for m in select id from public.tournament_doubles_matches where status='scheduled' and scheduled_start_minute is null and team1_id is not null and team2_id is not null order by created_at limit 50 loop perform public.schedule_doubles_match_v1(m.id); end loop;
  for m in select id from public.tournament_doubles_matches where status='scheduled' and team1_id is not null and team2_id is not null and scheduled_start_minute is not null and public.doubles_match_game_second_v1(id)<=v_now order by public.doubles_match_game_second_v1(id),id limit 25 loop perform public.simulate_doubles_match_v1(m.id);v_count:=v_count+1; end loop;
  return jsonb_build_object('processed',v_count);
end;
$$;

-- Reuse the existing minute cron by adding doubles processing without altering singles behavior.
create or replace function public.process_match_replay_clock_v1()
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare e jsonb;a jsonb;b jsonb;d jsonb;begin
 e:=public.process_due_match_engine_v1();
 a:=public.start_due_match_replays_v1();
 b:=public.finalize_due_match_replays_v1();
 d:=public.process_due_doubles_matches_v1();
 return jsonb_build_object('prepared',coalesce((e->>'prepared')::int,0),'started',coalesce((a->>'started')::int,0),'completed',coalesce((b->>'completed')::int,0),'doubles_processed',coalesce((d->>'processed')::int,0));
end;$$;

-- If a singles match time is changed, re-run doubles scheduling for affected players.
create or replace function public.revalidate_doubles_after_singles_schedule_change_v1()
returns trigger language plpgsql security definer set search_path=public
as $$
declare dm record;begin
  if new.scheduled_start_minute is null then return new; end if;
  for dm in
    select distinct d.id
    from public.tournament_doubles_matches d
    left join public.tournament_doubles_teams t1 on t1.id=d.team1_id
    left join public.tournament_doubles_teams t2 on t2.id=d.team2_id
    join public.tournament_world_competitions dwc on dwc.id=d.competition_id
    join public.tournament_editions de on de.id=dwc.tournament_edition_id
    join public.tournament_world_competitions swc on swc.id=new.competition_id
    join public.tournament_editions se on se.id=swc.tournament_edition_id
    where d.status='scheduled' and d.scheduled_start_minute is not null
      and de.season_number=se.season_number and d.scheduled_season_week=new.scheduled_season_week and d.scheduled_day=new.scheduled_day
      and (new.player1_id in (t1.player1_id,t1.player2_id,t2.player1_id,t2.player2_id) or new.player2_id in (t1.player1_id,t1.player2_id,t2.player1_id,t2.player2_id))
  loop perform public.schedule_doubles_match_v1(dm.id); end loop;
  return new;
end;$$;
drop trigger if exists trg_revalidate_doubles_after_singles_schedule_change_v1 on public.tournament_matches;
create trigger trg_revalidate_doubles_after_singles_schedule_change_v1
after insert or update of scheduled_season_week,scheduled_day,scheduled_start_minute,court_number on public.tournament_matches
for each row execute function public.revalidate_doubles_after_singles_schedule_change_v1();

-- ---------------------------------------------------------------------------
-- 6. Result finalization, prize split and doubles rankings
-- ---------------------------------------------------------------------------

create or replace function public.finalize_doubles_team_result_v1(p_match_id uuid,p_team_id uuid)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  m public.tournament_doubles_matches%rowtype;t public.tournament_doubles_teams%rowtype;v_series uuid;v_category text;v_name text;v_season integer;v_world text;v_stage text;v_code text;v_points integer:=0;v_team_prize bigint:=0;v_player_prize bigint:=0;v_publish integer;v_abs integer;v_player uuid;v_type text;
begin
  select * into m from public.tournament_doubles_matches where id=p_match_id;
  select * into t from public.tournament_doubles_teams where id=p_team_id;
  if m.id is null or t.id is null or m.status not in ('completed','walkover') or m.winner_team_id is null then return jsonb_build_object('status','not_final'); end if;
  if p_team_id not in (m.team1_id,m.team2_id) then raise exception 'Team is not in this match.'; end if;
  select e.tournament_series_id,ts.category_code,ts.name,e.season_number,wc.world into v_series,v_category,v_name,v_season,v_world
  from public.tournament_world_competitions wc join public.tournament_editions e on e.id=wc.tournament_edition_id join public.tournament_series ts on ts.id=e.tournament_series_id where wc.id=m.competition_id;
  if p_team_id=m.winner_team_id then
    if lower(m.round_label)<>'final' then return jsonb_build_object('status','still_active'); end if;
    v_stage:='winner';v_code:='champion';
  else
    v_stage:=case lower(m.round_label) when 'final' then 'runner_up' when 'semifinal' then 'semifinal' when 'quarterfinal' then 'quarterfinal' when 'round of 16' then 'round_16' when 'round of 32' then 'round_32' when 'round of 64' then 'round_64' else 'other' end;
    v_code:=v_stage;
  end if;
  select coalesce(points,0) into v_points from public.tournament_doubles_ranking_point_rules where world=v_world and category_code=v_category and stage_code=v_stage;
  select coalesce(team_prize_usd,0) into v_team_prize from public.tournament_doubles_prize_payouts where tournament_series_id=v_series and world=v_world and stage_code=v_stage;
  v_player_prize:=floor(v_team_prize/2.0)::bigint;
  select public.training_camp_week_start_absolute_v1(v_season,max(ss.season_week)::smallint)+7 into v_publish
  from public.tournament_world_competitions wc join public.tournament_editions e on e.id=wc.tournament_edition_id join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id where wc.id=m.competition_id;
  v_abs:=public.training_camp_week_start_absolute_v1(v_season,m.scheduled_season_week::smallint)+m.scheduled_day-1;
  foreach v_player in array array[t.player1_id,t.player2_id] loop
    insert into public.player_doubles_tournament_results(player_id,team_id,competition_id,world,result_code,result_stage_code,ranking_points_earned,team_prize_money_earned,player_prize_money_earned,ranking_publish_status,ranking_publish_absolute_day,completed_at,updated_at)
    values(v_player,t.id,m.competition_id,v_world,v_code,v_stage,v_points,v_team_prize,v_player_prize,'pending',v_publish,coalesce(m.completed_at,now()),now())
    on conflict(player_id,competition_id) do update set team_id=excluded.team_id,result_code=excluded.result_code,result_stage_code=excluded.result_stage_code,ranking_points_earned=excluded.ranking_points_earned,team_prize_money_earned=excluded.team_prize_money_earned,player_prize_money_earned=excluded.player_prize_money_earned,ranking_publish_absolute_day=excluded.ranking_publish_absolute_day,completed_at=excluded.completed_at,updated_at=now();
    select player_type into v_type from public.players where id=v_player;
    if v_type='human' and v_player_prize>0 then
      perform public.post_career_finance_transaction_v1(v_player,v_player_prize,'prize_money','doubles_'||v_stage,format('%s — Doubles %s prize money',v_name,initcap(replace(v_stage,'_',' '))),'doubles_tournament_result',m.competition_id::text,'doubles-prize:'||m.competition_id::text||':'||v_player::text,jsonb_build_object('tournament_name',v_name,'discipline','doubles','team_id',t.id,'stage_code',v_stage,'team_prize_usd',v_team_prize,'split_pct',50,'taxable',true),false,v_abs);
    end if;
  end loop;
  return jsonb_build_object('status','finalized','stage_code',v_stage,'ranking_points_earned',v_points,'team_prize_money_earned',v_team_prize,'player_prize_money_earned',v_player_prize,'ranking_publish_absolute_day',v_publish);
end;$$;

create or replace function public.finalize_completed_doubles_match_v1()
returns trigger language plpgsql security definer set search_path=public
as $$
declare v_loser uuid;begin
  if new.status in ('completed','walkover') and new.winner_team_id is not null and (tg_op='INSERT' or old.status is distinct from new.status or old.winner_team_id is distinct from new.winner_team_id) then
    v_loser:=case when new.team1_id=new.winner_team_id then new.team2_id else new.team1_id end;
    if v_loser is not null then perform public.finalize_doubles_team_result_v1(new.id,v_loser); end if;
    if lower(new.round_label)='final' then perform public.finalize_doubles_team_result_v1(new.id,new.winner_team_id); end if;
  end if;
  return new;
end;$$;
drop trigger if exists trg_finalize_completed_doubles_match_v1 on public.tournament_doubles_matches;
create trigger trg_finalize_completed_doubles_match_v1 after insert or update of status,winner_team_id on public.tournament_doubles_matches
for each row execute function public.finalize_completed_doubles_match_v1();

create or replace function public.process_doubles_rankings_for_day_v1(p_absolute_day integer)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare c record;v_pub integer:=0;v_exp integer:=0;v_act integer:=0;v_cycles integer:=0;v_n integer;v_cycle_pub integer;v_cycle_exp integer;v_cycle_act integer;
begin
  for c in
    select wc.id competition_id,e.tournament_series_id,wc.world,e.season_number,
      public.training_camp_week_start_absolute_v1(e.season_number,max(ss.season_week)::smallint)+7 publish_day
    from public.tournament_world_competitions wc
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
    where exists(select 1 from public.tournament_doubles_matches dm where dm.competition_id=wc.id and lower(dm.round_label)='final' and dm.status in ('completed','walkover') and dm.winner_team_id is not null)
    group by wc.id,e.tournament_series_id,wc.world,e.season_number
    having public.training_camp_week_start_absolute_v1(e.season_number,max(ss.season_week)::smallint)+7<=p_absolute_day
       and not exists(select 1 from public.doubles_ranking_defence_cycles dc where dc.competition_id=wc.id)
  loop
    v_cycle_pub:=0;v_cycle_exp:=0;v_cycle_act:=0;
    update public.player_doubles_tournament_results r set ranking_publish_status='published',ranking_published_at=coalesce(r.ranking_published_at,now()),updated_at=now()
    where r.competition_id=c.competition_id and r.ranking_publish_status='pending' and r.ranking_publish_absolute_day<=p_absolute_day;
    get diagnostics v_n=row_count;v_cycle_pub:=v_n;v_pub:=v_pub+v_n;
    if c.season_number>1 then
      update public.player_doubles_ranking_contributions oldc set is_active=false,deactivated_absolute_day=p_absolute_day,deactivated_at=now(),
        replaced_by_result_id=(select r.id from public.player_doubles_tournament_results r where r.competition_id=c.competition_id and r.player_id=oldc.player_id and r.ranking_publish_status='published' limit 1),
        replaced_by_competition_id=c.competition_id,replacement_reason=case when exists(select 1 from public.player_doubles_tournament_results r where r.competition_id=c.competition_id and r.player_id=oldc.player_id and r.ranking_publish_status='published') then 'next_edition_result' else 'next_edition_no_result' end,updated_at=now()
      where oldc.is_active and oldc.tournament_series_id=c.tournament_series_id and oldc.world=c.world and oldc.season_number=c.season_number-1;
      get diagnostics v_n=row_count;v_cycle_exp:=v_n;v_exp:=v_exp+v_n;
    end if;
    insert into public.player_doubles_ranking_contributions(player_id,source_result_id,competition_id,tournament_series_id,world,season_number,ranking_points,awarded_absolute_day,expires_absolute_day,published_at,is_active)
    select r.player_id,r.id,r.competition_id,c.tournament_series_id,c.world,c.season_number,r.ranking_points_earned,coalesce(r.ranking_publish_absolute_day,p_absolute_day),coalesce(r.ranking_publish_absolute_day,p_absolute_day)+366,coalesce(r.ranking_published_at,now()),true
    from public.player_doubles_tournament_results r where r.competition_id=c.competition_id and r.ranking_publish_status='published'
    on conflict(source_result_id) do nothing;
    get diagnostics v_n=row_count;v_cycle_act:=v_n;v_act:=v_act+v_n;
    insert into public.doubles_ranking_defence_cycles(competition_id,tournament_series_id,world,season_number,scheduled_publish_absolute_day,processed_absolute_day,published_results,expired_contributions,activated_contributions)
    values(c.competition_id,c.tournament_series_id,c.world,c.season_number,c.publish_day,p_absolute_day,v_cycle_pub,v_cycle_exp,v_cycle_act) on conflict(competition_id) do nothing;
    v_cycles:=v_cycles+1;
  end loop;
  update public.player_doubles_ranking_contributions set is_active=false,deactivated_absolute_day=p_absolute_day,deactivated_at=now(),replacement_reason=coalesce(replacement_reason,'scheduled_expiration'),updated_at=now()
  where is_active and expires_absolute_day<=p_absolute_day;
  get diagnostics v_n=row_count;v_exp:=v_exp+v_n;
  update public.player_doubles_rankings r set ranking_points=coalesce((select sum(c.ranking_points)::integer from public.player_doubles_ranking_contributions c where c.player_id=r.player_id and c.is_active),0),updated_at=now();
  insert into public.player_doubles_ranking_snapshots(player_id,world,game_absolute_day,ranking_position,ranking_points)
  select player_id,world,p_absolute_day,row_number() over(partition by world order by ranking_points desc,seed_rating desc,player_id)::integer,ranking_points from public.player_doubles_rankings
  on conflict(player_id,game_absolute_day) do update set ranking_position=excluded.ranking_position,ranking_points=excluded.ranking_points;
  insert into public.doubles_ranking_publication_runs(game_absolute_day,published_results,defence_cycles_processed,contributions_expired,contributions_activated,processed_at)
  values(p_absolute_day,v_pub,v_cycles,v_exp,v_act,now()) on conflict(game_absolute_day) do update set published_results=excluded.published_results,defence_cycles_processed=excluded.defence_cycles_processed,contributions_expired=excluded.contributions_expired,contributions_activated=excluded.contributions_activated,processed_at=now();
  return jsonb_build_object('status','published','game_absolute_day',p_absolute_day,'published_results',v_pub,'defence_cycles_processed',v_cycles,'contributions_expired',v_exp,'contributions_activated',v_act);
end;$$;

create or replace function public.process_doubles_rankings_after_singles_publication_v1()
returns trigger language plpgsql security definer set search_path=public
as $$ begin perform public.process_doubles_rankings_for_day_v1(new.game_absolute_day);return new;end;$$;
drop trigger if exists trg_process_doubles_rankings_after_singles_publication_v1 on public.ranking_publication_runs;
create trigger trg_process_doubles_rankings_after_singles_publication_v1 after insert or update on public.ranking_publication_runs
for each row execute function public.process_doubles_rankings_after_singles_publication_v1();