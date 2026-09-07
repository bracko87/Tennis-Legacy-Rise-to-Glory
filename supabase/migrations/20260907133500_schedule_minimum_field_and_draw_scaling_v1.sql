-- Schedule commitments, minimum tournament field, and small-field draw scaling v1.
--
-- Rules:
--   * Schedule shows only accepted (active entry) tournaments that have not started.
--   * Pending applications never appear as commitments.
--   * A tournament needs at least 8 accepted players when the final field locks.
--   * A missed final-lock cancellation is checked again before draw publication.
--   * Small accepted fields use the smallest normal power-of-two draw that fits them,
--     with 8-16 players using a Round-of-16 bracket.

-- Add a normal 16-player seed layout so small tournaments can publish a proper draw.
insert into public.tournament_draw_seed_groups(draw_size,group_no,seed_start,seed_end) values
  (16,1,1,1),(16,2,2,2),(16,3,3,4)
on conflict (draw_size,group_no) do update
set seed_start=excluded.seed_start,seed_end=excluded.seed_end;

insert into public.tournament_draw_seed_slots(draw_size,group_no,bracket_slot) values
  (16,1,1),(16,2,16),(16,3,5),(16,3,12)
on conflict (draw_size,bracket_slot) do update
set group_no=excluded.group_no;

-- The Schedule page is a commitment/preparation page, not an application list.
create or replace function public.get_player_tournament_summary_v1(p_player_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_player public.players%rowtype;
  v_current_abs integer;
  v_next jsonb;
  v_recent jsonb;
  v_best jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select * into v_player from public.players where id=p_player_id and moderation_status <> 'rejected';
  if v_player.id is null then raise exception 'Player not found.'; end if;

  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_current_abs
  from public.get_current_game_day_internal_v1() d;

  with competition_windows as (
    select
      wc.id competition_id,
      wc.status competition_status,
      e.season_number,
      min(ss.season_week)::smallint start_week,
      max(ss.season_week)::smallint end_week,
      s.name tournament_name,s.city,s.country_code,s.category_code,s.surface,s.logo_url,
      c.label category_label
    from public.tournament_world_competitions wc
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_series s on s.id=e.tournament_series_id
    join public.tournament_categories c on c.code=s.category_code
    join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
    where wc.world=v_player.world
      and wc.status<>'canceled'
      and e.status<>'canceled'
    group by wc.id,wc.status,e.season_number,s.name,s.city,s.country_code,s.category_code,s.surface,s.logo_url,c.label
  ), accepted_future as (
    select distinct
      cw.*,
      public.training_camp_week_start_absolute_v1(cw.season_number,cw.start_week) start_abs
    from public.tournament_entries te
    join competition_windows cw on cw.competition_id=te.competition_id
    where te.player_id=p_player_id
      and te.entry_status='active'
      -- Strictly future: as soon as tournament week starts it stops being a
      -- preparation target, even if the player is still active in the draw.
      and public.training_camp_week_start_absolute_v1(cw.season_number,cw.start_week)>v_current_abs
    order by start_abs,cw.tournament_name
    limit 5
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'competition_id',u.competition_id,'season',u.season_number,'start_week',u.start_week,'end_week',u.end_week,
    'tournament_name',u.tournament_name,'city',u.city,'country_code',u.country_code,
    'category_code',u.category_code,'category_label',u.category_label,'surface',u.surface,'logo_url',u.logo_url,
    'entry_status','accepted'
  ) order by u.start_abs,u.tournament_name),'[]'::jsonb) into v_next
  from accepted_future u;

  with result_rows as (
    select r.id,r.competition_id,r.result_code,r.ranking_points_earned,r.completed_at,
      e.season_number,min(ss.season_week)::smallint start_week,max(ss.season_week)::smallint end_week,
      s.name tournament_name,s.city,s.country_code,s.category_code,s.surface,s.logo_url,
      c.label category_label,c.winner_points,
      public.tournament_result_label_v1(r.result_code) result_label,
      (c.winner_points::numeric*public.tournament_result_weight_v1(r.result_code)) performance_score
    from public.player_tournament_results r
    join public.tournament_world_competitions wc on wc.id=r.competition_id
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_series s on s.id=e.tournament_series_id
    join public.tournament_categories c on c.code=s.category_code
    join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
    where r.player_id=p_player_id
    group by r.id,r.competition_id,r.result_code,r.ranking_points_earned,r.completed_at,e.season_number,
      s.name,s.city,s.country_code,s.category_code,s.surface,s.logo_url,c.label,c.winner_points
  ), recent as (
    select * from result_rows order by season_number desc,end_week desc,completed_at desc limit 5
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'result_id',r.id,'competition_id',r.competition_id,'season',r.season_number,'start_week',r.start_week,'end_week',r.end_week,
    'tournament_name',r.tournament_name,'city',r.city,'country_code',r.country_code,
    'category_code',r.category_code,'category_label',r.category_label,'surface',r.surface,'logo_url',r.logo_url,
    'result_code',r.result_code,'result_label',r.result_label,'ranking_points_earned',r.ranking_points_earned
  ) order by r.season_number desc,r.end_week desc,r.completed_at desc),'[]'::jsonb) into v_recent from recent r;

  with result_rows as (
    select r.id,r.competition_id,r.result_code,r.ranking_points_earned,r.completed_at,
      e.season_number,min(ss.season_week)::smallint start_week,max(ss.season_week)::smallint end_week,
      s.name tournament_name,s.city,s.country_code,s.category_code,s.surface,s.logo_url,
      c.label category_label,c.winner_points,
      public.tournament_result_label_v1(r.result_code) result_label,
      (c.winner_points::numeric*public.tournament_result_weight_v1(r.result_code)) performance_score
    from public.player_tournament_results r
    join public.tournament_world_competitions wc on wc.id=r.competition_id
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_series s on s.id=e.tournament_series_id
    join public.tournament_categories c on c.code=s.category_code
    join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
    where r.player_id=p_player_id
    group by r.id,r.competition_id,r.result_code,r.ranking_points_earned,r.completed_at,e.season_number,
      s.name,s.city,s.country_code,s.category_code,s.surface,s.logo_url,c.label,c.winner_points
  ), best as (
    select * from result_rows order by performance_score desc,winner_points desc,season_number desc,end_week desc limit 5
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'result_id',b.id,'competition_id',b.competition_id,'season',b.season_number,'start_week',b.start_week,'end_week',b.end_week,
    'tournament_name',b.tournament_name,'city',b.city,'country_code',b.country_code,
    'category_code',b.category_code,'category_label',b.category_label,'surface',b.surface,'logo_url',b.logo_url,
    'result_code',b.result_code,'result_label',b.result_label,'ranking_points_earned',b.ranking_points_earned
  ) order by b.performance_score desc,b.winner_points desc,b.season_number desc,b.end_week desc),'[]'::jsonb) into v_best from best b;

  return jsonb_build_object('next_tournaments',v_next,'recent_tournaments',v_recent,'best_results',v_best);
end;
$$;

revoke all on function public.get_player_tournament_summary_v1(uuid) from public,anon;
grant execute on function public.get_player_tournament_summary_v1(uuid) to authenticated;

-- If a competition is cancelled, human travel plans are rebuilt so a cancelled
-- event cannot leave a stale outbound/return leg on the calendar.
create or replace function public.cancel_tournament_for_minimum_field_v1(p_competition_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_count integer;
  r record;
begin
  select count(*) into v_count
  from public.tournament_entries
  where competition_id=p_competition_id and entry_status='active';

  if v_count>=8 then
    return jsonb_build_object('status','field_valid','accepted_players',v_count,'minimum_players',8);
  end if;

  update public.tournament_world_competitions
  set status='canceled'
  where id=p_competition_id and status<>'canceled';

  for r in
    select distinct te.player_id
    from public.tournament_entries te
    join public.players p on p.id=te.player_id
    where te.competition_id=p_competition_id
      and p.owner_user_id is not null
  loop
    begin
      perform public.rebuild_player_travel_plan_v1(r.player_id);
    exception when others then
      null;
    end;
  end loop;

  return jsonb_build_object('status','canceled_minimum_field','accepted_players',v_count,'minimum_players',8);
end;
$$;
revoke all on function public.cancel_tournament_for_minimum_field_v1(uuid) from public,anon,authenticated;

-- The entry-lifecycle engine is the authority for the exact final-field-lock
-- moment. This lightweight hourly guard cancels any still-unpublished field as
-- soon as that lifecycle reports field_locked=true and fewer than 8 players.
create or replace function public.process_minimum_tournament_fields_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  d record;
  r record;
  v_abs integer;
  v_lifecycle jsonb;
  v_count integer:=0;
  v_result jsonb;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);

  for r in
    select
      wc.id,
      min(public.training_camp_week_start_absolute_v1(ed.season_number,sl.season_week::smallint))::integer start_abs
    from public.tournament_world_competitions wc
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_schedule_slots sl on sl.tournament_edition_id=ed.id
    where wc.status<>'canceled'
      and ed.status<>'canceled'
      and not exists(select 1 from public.tournament_draw_publications dp where dp.competition_id=wc.id)
      and not exists(select 1 from public.tournament_matches tm where tm.competition_id=wc.id)
    group by wc.id,ed.season_number
    having min(public.training_camp_week_start_absolute_v1(ed.season_number,sl.season_week::smallint))::integer>=v_abs
       and min(public.training_camp_week_start_absolute_v1(ed.season_number,sl.season_week::smallint))::integer<=v_abs+14
  loop
    begin
      v_lifecycle:=public.get_tournament_entry_lifecycle_v2(r.id);
      if coalesce((v_lifecycle->>'field_locked')::boolean,false) then
        v_result:=public.cancel_tournament_for_minimum_field_v1(r.id);
        if v_result->>'status'='canceled_minimum_field' then v_count:=v_count+1; end if;
      end if;
    exception when others then
      -- A single malformed/legacy competition must not block the rest.
      null;
    end;
  end loop;

  return jsonb_build_object('status','processed','canceled_tournaments',v_count,'game_absolute_day',v_abs);
end;
$$;
revoke all on function public.process_minimum_tournament_fields_v1() from public,anon,authenticated;

select cron.unschedule(jobid) from cron.job where jobname='tennis-minimum-field-v1';
select cron.schedule(
  'tennis-minimum-field-v1',
  '19 * * * *',
  'select public.process_minimum_tournament_fields_v1();'
);

-- Bracket advancement must use the draw that was actually published. A small
-- 16-player bracket has four main-draw rounds even when its category normally
-- has a 32/64/128-player main draw.
create or replace function public.advance_tournament_bracket_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_max_round smallint;
  v_next_no integer;
  v_next_id uuid;
  v_next_label text;
  v_loser uuid;
  v_target_slot integer;
  v_target_match integer;
  v_feeders_done integer;
  v_next_p1 uuid;
  v_next_p2 uuid;
  v_category public.tournament_categories%rowtype;
begin
  if new.status not in ('completed','bye','walkover','cancelled') then return new;end if;
  if tg_op='UPDATE' and old.status is not distinct from new.status then return new;end if;

  select tc.* into v_category
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.tournament_categories tc on tc.code=ts.category_code
  where wc.id=new.competition_id;

  v_max_round:=case
    when new.draw_type='main_draw'
      then ceil(ln(greatest(new.bracket_size,2)::numeric)/ln(2::numeric))::smallint
    else v_category.qualification_rounds_max
  end;

  if new.winner_id is not null then
    v_loser:=case
      when new.player1_id=new.winner_id then new.player2_id
      when new.player2_id=new.winner_id then new.player1_id
      else null
    end;
    if v_loser is not null then
      update public.tournament_entries set entry_status='eliminated',updated_at=now()
      where competition_id=new.competition_id and player_id=v_loser;
    end if;
  end if;

  if new.round_number<v_max_round then
    v_next_no:=(new.match_number+1)/2;
    select id into v_next_id
    from public.tournament_matches
    where competition_id=new.competition_id and draw_type=new.draw_type
      and round_number=new.round_number+1 and match_number=v_next_no;

    if v_next_id is null then
      v_next_label:=public.tournament_round_label_v1(new.draw_type,new.bracket_size,new.round_number+1,v_max_round);
      insert into public.tournament_matches(
        competition_id,draw_type,round_number,round_label,match_number,bracket_size,
        scheduled_season_week,scheduled_day,status
      ) values(
        new.competition_id,new.draw_type,new.round_number+1,v_next_label,v_next_no,new.bracket_size,
        new.scheduled_season_week,least(7,new.scheduled_day+1),'scheduled'
      )
      on conflict(competition_id,draw_type,round_number,match_number) do nothing
      returning id into v_next_id;
      if v_next_id is null then
        select id into v_next_id from public.tournament_matches
        where competition_id=new.competition_id and draw_type=new.draw_type
          and round_number=new.round_number+1 and match_number=v_next_no;
      end if;
    end if;

    if new.winner_id is not null then
      if mod(new.match_number,2)=1 then
        update public.tournament_matches set player1_id=new.winner_id,updated_at=now()
        where id=v_next_id and player1_id is null;
      else
        update public.tournament_matches set player2_id=new.winner_id,updated_at=now()
        where id=v_next_id and player2_id is null;
      end if;
    end if;

    select count(*) into v_feeders_done
    from public.tournament_matches f
    where f.competition_id=new.competition_id
      and f.draw_type=new.draw_type
      and f.round_number=new.round_number
      and f.match_number in(v_next_no*2-1,v_next_no*2)
      and f.status in('completed','bye','walkover','cancelled');

    if v_feeders_done=2 then
      select player1_id,player2_id into v_next_p1,v_next_p2
      from public.tournament_matches where id=v_next_id;
      if v_next_p1 is null and v_next_p2 is null then
        update public.tournament_matches
        set status='cancelled',completed_at=coalesce(completed_at,now()),updated_at=now()
        where id=v_next_id and status='scheduled';
      elsif (v_next_p1 is null)<>(v_next_p2 is null) then
        update public.tournament_matches
        set status='bye',winner_id=coalesce(v_next_p1,v_next_p2),completed_at=coalesce(completed_at,now()),updated_at=now()
        where id=v_next_id and status='scheduled';
      end if;
    end if;
  else
    if new.draw_type='qualification' then
      select bracket_slot into v_target_slot
      from public.tournament_qualifier_slots
      where competition_id=new.competition_id and section_number=new.match_number;

      if v_target_slot is not null then
        update public.tournament_qualifier_slots
        set resolved=true,filled_player_id=new.winner_id
        where competition_id=new.competition_id and section_number=new.match_number;

        if new.winner_id is not null then
          update public.tournament_entries
          set draw_type='main_draw',entry_status='active',seed_number=null,bracket_slot=v_target_slot,updated_at=now()
          where competition_id=new.competition_id and player_id=new.winner_id;
          v_target_match:=(v_target_slot+1)/2;
          if mod(v_target_slot,2)=1 then
            update public.tournament_matches set player1_id=new.winner_id,updated_at=now()
            where competition_id=new.competition_id and draw_type='main_draw' and round_number=1 and match_number=v_target_match;
          else
            update public.tournament_matches set player2_id=new.winner_id,updated_at=now()
            where competition_id=new.competition_id and draw_type='main_draw' and round_number=1 and match_number=v_target_match;
          end if;
        end if;
        perform public.resolve_main_first_round_match_v1(new.competition_id,(v_target_slot+1)/2);
      end if;
    elsif new.winner_id is not null then
      update public.tournament_entries set entry_status='champion',updated_at=now()
      where competition_id=new.competition_id and player_id=new.winner_id;
    end if;
  end if;

  return new;
end;
$$;
revoke all on function public.advance_tournament_bracket_v1() from public,anon,authenticated;

-- Publish the smallest standard main draw that fits an under-capacity accepted
-- field. Qualification is only needed when accepted players exceed the normal
-- main-draw capacity.
create or replace function public.publish_tournament_draw_v1(p_competition_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_world text;
  v_edition uuid;
  v_category public.tournament_categories%rowtype;
  v_abs integer;
  v_main_size integer;
  v_q_size integer;
  v_qslots integer;
  v_main_seeds integer;
  v_q_seeds integer;
  v_main_count integer;
  v_q_count integer;
  v_total_count integer;
  v_byes integer:=0;
  v_q_byes integer:=0;
  v_slot integer;
  v_opp integer;
  v_group integer;
  v_seed_start integer;
  v_section integer;
  v_section_size integer;
  v_q_rounds integer;
  v_main_rounds integer;
  v_round integer;
  v_matches integer;
  v_match integer;
  v_label text;
  v_main_week integer;
  v_q_week integer;
  v_main_phase text;
  v_q_phase text;
  v_main_offset integer;
  v_q_offset integer;
  v_p1 uuid;
  v_p2 uuid;
  v_seed_no integer;
  v_remaining integer;
  v_guard jsonb;
  r record;
begin
  if exists(select 1 from public.tournament_draw_publications where competition_id=p_competition_id)
     or exists(select 1 from public.tournament_matches where competition_id=p_competition_id) then
    return jsonb_build_object('status','already_published');
  end if;

  select wc.world,ed.id into v_world,v_edition
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  where wc.id=p_competition_id and wc.status<>'canceled' and ed.status<>'canceled';
  if v_edition is null then raise exception 'Tournament competition not found.';end if;

  select tc.* into v_category
  from public.tournament_editions ed
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.tournament_categories tc on tc.code=ts.category_code
  where ed.id=v_edition;

  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs
  from public.get_current_game_day_internal_v1() d;

  select count(*) into v_main_count
  from public.tournament_entries
  where competition_id=p_competition_id and draw_type='main_draw' and entry_status='active';
  select count(*) into v_q_count
  from public.tournament_entries
  where competition_id=p_competition_id and draw_type='qualification' and entry_status='active';
  v_total_count:=v_main_count+v_q_count;

  if v_total_count<8 then
    v_guard:=public.cancel_tournament_for_minimum_field_v1(p_competition_id);
    return v_guard;
  end if;

  v_main_size:=v_category.main_draw_capacity;
  v_q_size:=v_category.qualifying_capacity_max;
  v_qslots:=v_category.default_qualifier_slots;
  v_q_rounds:=v_category.qualification_rounds_max;

  -- When everybody fits directly into the main draw there is no reason to run
  -- qualification. Collapse the field and use the smallest normal bracket.
  if v_total_count<=v_category.main_draw_capacity then
    update public.tournament_entries
    set draw_type='main_draw',seed_number=null,bracket_slot=null,updated_at=now()
    where competition_id=p_competition_id and entry_status='active';

    v_main_count:=v_total_count;
    v_q_count:=0;
    v_qslots:=0;
    v_q_size:=0;
    v_q_rounds:=0;
    v_main_size:=case
      when v_total_count<=16 then 16
      when v_total_count<=32 then 32
      when v_total_count<=64 then 64
      else 128
    end;
    v_main_size:=least(v_main_size,v_category.main_draw_capacity);
  end if;

  v_main_rounds:=ceil(ln(greatest(v_main_size,2)::numeric)/ln(2::numeric))::integer;

  if v_main_count=0 and v_q_count=0 then return jsonb_build_object('status','no_entries');end if;
  if v_q_count=0 then v_qslots:=0;v_q_size:=0;v_q_rounds:=0;end if;
  if v_main_count>v_main_size-v_qslots then raise exception 'Too many main-draw entries: %, maximum with qualification is %.',v_main_count,v_main_size-v_qslots;end if;
  if v_q_count>v_q_size then raise exception 'Too many qualification entries: %, capacity is %.',v_q_count,v_q_size;end if;
  if v_qslots>0 and (v_q_size%v_qslots<>0 or (v_q_size/v_qslots) not in (4,8)) then raise exception 'Qualification format must resolve into 4- or 8-player sections.';end if;

  drop table if exists pg_temp.tmp_world_rank;
  create temporary table tmp_world_rank(player_id uuid primary key,rank_position integer) on commit drop;
  insert into tmp_world_rank
  select p.id,row_number() over(order by coalesce(pr.ranking_points,0) desc,coalesce(pr.seed_rating,0) desc,p.created_at asc,p.id asc)::integer
  from public.players p
  left join public.player_rankings pr on pr.player_id=p.id
  where p.world=v_world and p.moderation_status<>'rejected';

  update public.tournament_entries e
  set ranking_position_snapshot=w.rank_position,seed_number=null,bracket_slot=null,updated_at=now()
  from tmp_world_rank w
  where e.competition_id=p_competition_id and e.player_id=w.player_id;

  select coalesce(max(seed_end),0) into v_main_seeds
  from public.tournament_draw_seed_groups where draw_size=v_main_size;
  v_main_seeds:=least(v_main_seeds,v_main_count);
  v_q_seeds:=least(v_q_count,v_qslots*2);

  drop table if exists pg_temp.tmp_main_slots;
  create temporary table tmp_main_slots(slot integer primary key,kind text,player_id uuid) on commit drop;
  insert into tmp_main_slots(slot) select generate_series(1,v_main_size);

  v_seed_no:=0;
  for r in
    select e.id,e.player_id,e.ranking_position_snapshot
    from public.tournament_entries e
    where e.competition_id=p_competition_id and e.draw_type='main_draw' and e.entry_status='active'
    order by e.ranking_position_snapshot nulls last,e.player_id
    limit v_main_seeds
  loop
    v_seed_no:=v_seed_no+1;
    select group_no,seed_start into v_group,v_seed_start
    from public.tournament_draw_seed_groups
    where draw_size=v_main_size and v_seed_no between seed_start and seed_end;
    select x.bracket_slot into v_slot from (
      select bracket_slot,row_number() over(order by md5(p_competition_id::text||':seed-group:'||v_group::text||':'||bracket_slot::text)) rn
      from public.tournament_draw_seed_slots
      where draw_size=v_main_size and group_no=v_group
    )x where x.rn=v_seed_no-v_seed_start+1;
    update tmp_main_slots set kind='player',player_id=r.player_id where slot=v_slot;
    update public.tournament_entries set seed_number=v_seed_no,bracket_slot=v_slot,updated_at=now() where id=r.id;
  end loop;

  v_byes:=v_main_size-v_main_count-v_qslots;
  v_remaining:=v_byes;
  for r in
    select seed_number,bracket_slot
    from public.tournament_entries
    where competition_id=p_competition_id and draw_type='main_draw' and seed_number is not null
    order by seed_number
  loop
    exit when v_remaining<=0;
    v_opp:=case when mod(r.bracket_slot,2)=1 then r.bracket_slot+1 else r.bracket_slot-1 end;
    if exists(select 1 from tmp_main_slots where slot=v_opp and kind is null) then
      update tmp_main_slots set kind='bye' where slot=v_opp;
      v_remaining:=v_remaining-1;
    end if;
  end loop;

  while v_remaining>0 loop
    select slot into v_slot
    from tmp_main_slots where kind is null
    order by md5(p_competition_id::text||':main-bye:'||slot::text) limit 1;
    update tmp_main_slots set kind='bye' where slot=v_slot;
    v_remaining:=v_remaining-1;
  end loop;

  delete from public.tournament_qualifier_slots where competition_id=p_competition_id;
  if v_qslots>0 then
    for v_section in 1..v_qslots loop
      select slot into v_slot
      from tmp_main_slots where kind is null
      order by md5(p_competition_id::text||':qualifier-slot:'||slot::text) limit 1;
      update tmp_main_slots set kind='qualifier' where slot=v_slot;
      insert into public.tournament_qualifier_slots(competition_id,section_number,bracket_slot)
      values(p_competition_id,v_section,v_slot);
    end loop;
  end if;

  for r in
    select e.id,e.player_id
    from public.tournament_entries e
    where e.competition_id=p_competition_id and e.draw_type='main_draw' and e.entry_status='active' and e.seed_number is null
    order by md5(p_competition_id::text||':main-player:'||e.player_id::text)
  loop
    select slot into v_slot
    from tmp_main_slots where kind is null
    order by md5(p_competition_id::text||':main-open:'||slot::text) limit 1;
    update tmp_main_slots set kind='player',player_id=r.player_id where slot=v_slot;
    update public.tournament_entries set bracket_slot=v_slot,updated_at=now() where id=r.id;
  end loop;

  if exists(select 1 from tmp_main_slots where kind is null) then raise exception 'Main draw slot assignment incomplete.';end if;

  select sl.season_week,sl.phase into v_main_week,v_main_phase
  from public.tournament_schedule_slots sl
  where sl.tournament_edition_id=v_edition and sl.phase in('main_draw','full')
  order by case when sl.phase='main_draw' then 0 else 1 end,sl.slot_order limit 1;

  select sl.season_week,sl.phase into v_q_week,v_q_phase
  from public.tournament_schedule_slots sl
  where sl.tournament_edition_id=v_edition and sl.phase in('qualification','full')
  order by case when sl.phase='qualification' then 0 else 1 end,sl.slot_order limit 1;

  if v_main_week is null then raise exception 'Main draw schedule slot missing.';end if;
  v_q_offset:=case when v_q_phase='qualification' and v_category.qualification_rest_day_first then 1 else 0 end;
  v_main_offset:=case when v_main_phase='full' then v_q_rounds else case when v_category.main_draw_rest_day_first then 1 else 0 end end;
  if v_main_offset+v_main_rounds>7 or (v_qslots>0 and v_q_offset+v_q_rounds>7) then raise exception 'Tournament round schedule exceeds seven game days.';end if;

  for v_round in 1..v_main_rounds loop
    v_matches:=v_main_size/(power(2,v_round)::integer);
    v_label:=public.tournament_round_label_v1('main_draw',v_main_size,v_round,v_main_rounds);
    for v_match in 1..v_matches loop
      v_p1:=null;v_p2:=null;
      if v_round=1 then
        select player_id into v_p1 from tmp_main_slots where slot=v_match*2-1 and kind='player';
        select player_id into v_p2 from tmp_main_slots where slot=v_match*2 and kind='player';
      end if;
      insert into public.tournament_matches(
        competition_id,draw_type,round_number,round_label,match_number,bracket_size,
        scheduled_season_week,scheduled_day,player1_id,player2_id,status
      ) values(
        p_competition_id,'main_draw',v_round,v_label,v_match,v_main_size,
        v_main_week,(v_main_offset+v_round)::smallint,v_p1,v_p2,'scheduled'
      );
    end loop;
  end loop;

  if v_qslots>0 then
    v_section_size:=v_q_size/v_qslots;
    drop table if exists pg_temp.tmp_q_slots;
    create temporary table tmp_q_slots(slot integer primary key,kind text,player_id uuid) on commit drop;
    insert into tmp_q_slots(slot) select generate_series(1,v_q_size);
    v_seed_no:=0;

    for r in
      select e.id,e.player_id,e.ranking_position_snapshot
      from public.tournament_entries e
      where e.competition_id=p_competition_id and e.draw_type='qualification' and e.entry_status='active'
      order by e.ranking_position_snapshot nulls last,e.player_id
      limit v_q_seeds
    loop
      v_seed_no:=v_seed_no+1;
      if v_seed_no<=v_qslots then
        v_section:=v_seed_no;v_slot:=(v_section-1)*v_section_size+1;
      else
        select x.section_no into v_section
        from generate_series(1,v_qslots) as x(section_no)
        order by md5(p_competition_id::text||':q-bottom-section:'||x.section_no::text)
        offset (v_seed_no-v_qslots-1) limit 1;
        v_slot:=(v_section-1)*v_section_size+v_section_size;
      end if;
      update tmp_q_slots set kind='player',player_id=r.player_id where slot=v_slot;
      update public.tournament_entries set seed_number=v_seed_no,bracket_slot=v_slot,updated_at=now() where id=r.id;
    end loop;

    v_q_byes:=v_q_size-v_q_count;
    v_remaining:=v_q_byes;
    for r in
      select seed_number,bracket_slot
      from public.tournament_entries
      where competition_id=p_competition_id and draw_type='qualification' and seed_number is not null
      order by seed_number
    loop
      exit when v_remaining<=0;
      v_opp:=case when mod(r.bracket_slot,2)=1 then r.bracket_slot+1 else r.bracket_slot-1 end;
      if exists(select 1 from tmp_q_slots where slot=v_opp and kind is null) then
        update tmp_q_slots set kind='bye' where slot=v_opp;
        v_remaining:=v_remaining-1;
      end if;
    end loop;

    while v_remaining>0 loop
      select slot into v_slot
      from tmp_q_slots where kind is null
      order by md5(p_competition_id::text||':q-bye:'||slot::text) limit 1;
      update tmp_q_slots set kind='bye' where slot=v_slot;
      v_remaining:=v_remaining-1;
    end loop;

    for r in
      select e.id,e.player_id
      from public.tournament_entries e
      where e.competition_id=p_competition_id and e.draw_type='qualification' and e.entry_status='active' and e.seed_number is null
      order by md5(p_competition_id::text||':q-player:'||e.player_id::text)
    loop
      select slot into v_slot
      from tmp_q_slots where kind is null
      order by md5(p_competition_id::text||':q-open:'||slot::text) limit 1;
      update tmp_q_slots set kind='player',player_id=r.player_id where slot=v_slot;
      update public.tournament_entries set bracket_slot=v_slot,updated_at=now() where id=r.id;
    end loop;

    for v_round in 1..v_q_rounds loop
      v_matches:=v_q_size/(power(2,v_round)::integer);
      v_label:=public.tournament_round_label_v1('qualification',v_q_size,v_round,v_q_rounds);
      for v_match in 1..v_matches loop
        v_p1:=null;v_p2:=null;
        if v_round=1 then
          select player_id into v_p1 from tmp_q_slots where slot=v_match*2-1 and kind='player';
          select player_id into v_p2 from tmp_q_slots where slot=v_match*2 and kind='player';
        end if;
        insert into public.tournament_matches(
          competition_id,draw_type,round_number,round_label,match_number,bracket_size,
          scheduled_season_week,scheduled_day,player1_id,player2_id,status
        ) values(
          p_competition_id,'qualification',v_round,v_label,v_match,v_q_size,
          v_q_week,(v_q_offset+v_round)::smallint,v_p1,v_p2,'scheduled'
        );
      end loop;
    end loop;
  end if;

  insert into public.tournament_draw_publications(
    competition_id,ranking_snapshot_absolute_day,main_draw_size,main_seed_count,
    qualifying_draw_size,qualifying_seed_count,qualifier_slots,randomization_key
  ) values(
    p_competition_id,v_abs,v_main_size,v_main_seeds,v_q_size,v_q_seeds,v_qslots,
    md5(p_competition_id::text||':draw-v1')
  );

  for v_match in 1..(v_main_size/2) loop
    perform public.resolve_main_first_round_match_v1(p_competition_id,v_match);
  end loop;

  if v_qslots>0 then
    for v_match in 1..(v_q_size/2) loop
      select player1_id,player2_id into v_p1,v_p2
      from public.tournament_matches
      where competition_id=p_competition_id and draw_type='qualification' and round_number=1 and match_number=v_match;
      if v_p1 is null and v_p2 is null then
        update public.tournament_matches set status='cancelled',completed_at=now(),updated_at=now()
        where competition_id=p_competition_id and draw_type='qualification' and round_number=1 and match_number=v_match;
      elsif (v_p1 is null)<>(v_p2 is null) then
        update public.tournament_matches set status='bye',winner_id=coalesce(v_p1,v_p2),completed_at=now(),updated_at=now()
        where competition_id=p_competition_id and draw_type='qualification' and round_number=1 and match_number=v_match;
      end if;
    end loop;
  end if;

  return jsonb_build_object(
    'status','published',
    'accepted_players',v_total_count,
    'minimum_players',8,
    'main_draw_size',v_main_size,
    'main_seeds',v_main_seeds,
    'qualification_size',v_q_size,
    'qualification_seeds',v_q_seeds,
    'qualifier_slots',v_qslots,
    'main_byes',v_byes,
    'qualification_byes',v_q_byes
  );
end;
$$;
revoke all on function public.publish_tournament_draw_v1(uuid) from public,anon,authenticated;

-- Keep the existing draw-publication cadence, but count minimum-field
-- cancellations separately rather than swallowing them as generic failures.
create or replace function public.process_due_tournament_draws_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  d record;
  v_abs integer;
  v_count integer:=0;
  v_canceled integer:=0;
  r record;
  v_result jsonb;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);

  for r in
    select wc.id,min(public.training_camp_week_start_absolute_v1(ed.season_number,sl.season_week::smallint))::integer start_abs
    from public.tournament_world_competitions wc
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_schedule_slots sl on sl.tournament_edition_id=ed.id
    where wc.status<>'canceled' and ed.status<>'canceled'
      and not exists(select 1 from public.tournament_draw_publications dp where dp.competition_id=wc.id)
      and not exists(select 1 from public.tournament_matches m where m.competition_id=wc.id)
      and exists(select 1 from public.tournament_entries e where e.competition_id=wc.id and e.entry_status='active')
    group by wc.id,ed.season_number
    having min(public.training_camp_week_start_absolute_v1(ed.season_number,sl.season_week::smallint))::integer-3<v_abs
  loop
    begin
      v_result:=public.publish_tournament_draw_v1(r.id);
      if v_result->>'status'='published' then
        v_count:=v_count+1;
      elsif v_result->>'status'='canceled_minimum_field' then
        v_canceled:=v_canceled+1;
      end if;
    exception when others then
      null;
    end;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'published_draws',v_count,
    'canceled_minimum_fields',v_canceled,
    'game_absolute_day',v_abs
  );
end;
$$;
revoke all on function public.process_due_tournament_draws_v1() from public,anon,authenticated;
