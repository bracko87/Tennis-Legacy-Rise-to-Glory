create or replace function public.publish_tournament_draw_v1(p_competition_id uuid)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare
 v_world text;v_edition uuid;v_category public.tournament_categories%rowtype;v_abs integer;
 v_main_size integer;v_q_size integer;v_qslots integer;v_main_seeds integer;v_q_seeds integer;v_main_count integer;v_q_count integer;
 v_byes integer:=0;v_q_byes integer:=0;v_slot integer;v_opp integer;v_group integer;v_seed_start integer;v_section integer;v_section_size integer;
 v_q_rounds integer;v_main_rounds integer;v_round integer;v_matches integer;v_match integer;v_label text;
 v_main_week integer;v_q_week integer;v_main_phase text;v_q_phase text;v_main_offset integer;v_q_offset integer;
 v_p1 uuid;v_p2 uuid;v_seed_no integer;v_remaining integer;r record;
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
 from public.tournament_editions ed join public.tournament_series ts on ts.id=ed.tournament_series_id join public.tournament_categories tc on tc.code=ts.category_code
 where ed.id=v_edition;

 select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
 v_main_size:=v_category.main_draw_capacity;v_q_size:=v_category.qualifying_capacity_max;v_qslots:=v_category.default_qualifier_slots;
 v_main_rounds:=v_category.main_draw_rounds;v_q_rounds:=v_category.qualification_rounds_max;
 select count(*) into v_main_count from public.tournament_entries where competition_id=p_competition_id and draw_type='main_draw' and entry_status='active';
 select count(*) into v_q_count from public.tournament_entries where competition_id=p_competition_id and draw_type='qualification' and entry_status='active';
 if v_main_count=0 and v_q_count=0 then return jsonb_build_object('status','no_entries');end if;
 if v_q_count=0 then v_qslots:=0;v_q_size:=0;v_q_rounds:=0;end if;
 if v_main_count>v_main_size-v_qslots then raise exception 'Too many main-draw entries: %, maximum with qualification is %.',v_main_count,v_main_size-v_qslots;end if;
 if v_q_count>v_q_size then raise exception 'Too many qualification entries: %, capacity is %.',v_q_count,v_q_size;end if;
 if v_qslots>0 and (v_q_size%v_qslots<>0 or (v_q_size/v_qslots) not in (4,8)) then raise exception 'Qualification format must resolve into 4- or 8-player sections.';end if;

 drop table if exists pg_temp.tmp_world_rank;
 create temporary table tmp_world_rank(player_id uuid primary key,rank_position integer) on commit drop;
 insert into tmp_world_rank
 select p.id,row_number() over(order by coalesce(pr.ranking_points,0) desc,coalesce(pr.seed_rating,0) desc,p.created_at asc,p.id asc)::integer
 from public.players p left join public.player_rankings pr on pr.player_id=p.id
 where p.world=v_world and p.moderation_status<>'rejected';
 update public.tournament_entries e set ranking_position_snapshot=w.rank_position,seed_number=null,bracket_slot=null,updated_at=now()
 from tmp_world_rank w where e.competition_id=p_competition_id and e.player_id=w.player_id;

 select coalesce(max(seed_end),0) into v_main_seeds from public.tournament_draw_seed_groups where draw_size=v_main_size;
 v_main_seeds:=least(v_main_seeds,v_main_count);v_q_seeds:=least(v_q_count,v_qslots*2);

 drop table if exists pg_temp.tmp_main_slots;
 create temporary table tmp_main_slots(slot integer primary key,kind text,player_id uuid) on commit drop;
 insert into tmp_main_slots(slot) select generate_series(1,v_main_size);

 v_seed_no:=0;
 for r in
   select e.id,e.player_id,e.ranking_position_snapshot from public.tournament_entries e
   where e.competition_id=p_competition_id and e.draw_type='main_draw' and e.entry_status='active'
   order by e.ranking_position_snapshot nulls last,e.player_id limit v_main_seeds
 loop
   v_seed_no:=v_seed_no+1;
   select group_no,seed_start into v_group,v_seed_start from public.tournament_draw_seed_groups
   where draw_size=v_main_size and v_seed_no between seed_start and seed_end;
   select x.bracket_slot into v_slot from (
     select bracket_slot,row_number() over(order by md5(p_competition_id::text||':seed-group:'||v_group::text||':'||bracket_slot::text)) rn
     from public.tournament_draw_seed_slots where draw_size=v_main_size and group_no=v_group
   )x where x.rn=v_seed_no-v_seed_start+1;
   update tmp_main_slots set kind='player',player_id=r.player_id where slot=v_slot;
   update public.tournament_entries set seed_number=v_seed_no,bracket_slot=v_slot,updated_at=now() where id=r.id;
 end loop;

 v_byes:=v_main_size-v_main_count-v_qslots;v_remaining:=v_byes;
 for r in select seed_number,bracket_slot from public.tournament_entries where competition_id=p_competition_id and draw_type='main_draw' and seed_number is not null order by seed_number loop
   exit when v_remaining<=0;
   v_opp:=case when mod(r.bracket_slot,2)=1 then r.bracket_slot+1 else r.bracket_slot-1 end;
   if exists(select 1 from tmp_main_slots where slot=v_opp and kind is null) then update tmp_main_slots set kind='bye' where slot=v_opp;v_remaining:=v_remaining-1;end if;
 end loop;
 while v_remaining>0 loop
   select slot into v_slot from tmp_main_slots where kind is null order by md5(p_competition_id::text||':main-bye:'||slot::text) limit 1;
   update tmp_main_slots set kind='bye' where slot=v_slot;v_remaining:=v_remaining-1;
 end loop;

 delete from public.tournament_qualifier_slots where competition_id=p_competition_id;
 if v_qslots>0 then
   for v_section in 1..v_qslots loop
     select slot into v_slot from tmp_main_slots where kind is null order by md5(p_competition_id::text||':qualifier-slot:'||slot::text) limit 1;
     update tmp_main_slots set kind='qualifier' where slot=v_slot;
     insert into public.tournament_qualifier_slots(competition_id,section_number,bracket_slot) values(p_competition_id,v_section,v_slot);
   end loop;
 end if;

 for r in
   select e.id,e.player_id from public.tournament_entries e
   where e.competition_id=p_competition_id and e.draw_type='main_draw' and e.entry_status='active' and e.seed_number is null
   order by md5(p_competition_id::text||':main-player:'||e.player_id::text)
 loop
   select slot into v_slot from tmp_main_slots where kind is null order by md5(p_competition_id::text||':main-open:'||slot::text) limit 1;
   update tmp_main_slots set kind='player',player_id=r.player_id where slot=v_slot;
   update public.tournament_entries set bracket_slot=v_slot,updated_at=now() where id=r.id;
 end loop;
 if exists(select 1 from tmp_main_slots where kind is null) then raise exception 'Main draw slot assignment incomplete.';end if;

 select sl.season_week,sl.phase into v_main_week,v_main_phase from public.tournament_schedule_slots sl
 where sl.tournament_edition_id=v_edition and sl.phase in('main_draw','full')
 order by case when sl.phase='main_draw' then 0 else 1 end,sl.slot_order limit 1;
 select sl.season_week,sl.phase into v_q_week,v_q_phase from public.tournament_schedule_slots sl
 where sl.tournament_edition_id=v_edition and sl.phase in('qualification','full')
 order by case when sl.phase='qualification' then 0 else 1 end,sl.slot_order limit 1;
 if v_main_week is null then raise exception 'Main draw schedule slot missing.';end if;
 v_q_offset:=case when v_q_phase='qualification' and v_category.qualification_rest_day_first then 1 else 0 end;
 v_main_offset:=case when v_main_phase='full' then v_q_rounds else case when v_category.main_draw_rest_day_first then 1 else 0 end end;
 if v_main_offset+v_main_rounds>7 or (v_qslots>0 and v_q_offset+v_q_rounds>7) then raise exception 'Tournament round schedule exceeds seven game days.';end if;

 for v_round in 1..v_main_rounds loop
   v_matches:=v_main_size/(power(2,v_round)::integer);v_label:=public.tournament_round_label_v1('main_draw',v_main_size,v_round,v_main_rounds);
   for v_match in 1..v_matches loop
     v_p1:=null;v_p2:=null;
     if v_round=1 then
       select player_id into v_p1 from tmp_main_slots where slot=v_match*2-1 and kind='player';
       select player_id into v_p2 from tmp_main_slots where slot=v_match*2 and kind='player';
     end if;
     insert into public.tournament_matches(competition_id,draw_type,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,player1_id,player2_id,status)
     values(p_competition_id,'main_draw',v_round,v_label,v_match,v_main_size,v_main_week,(v_main_offset+v_round)::smallint,v_p1,v_p2,'scheduled');
   end loop;
 end loop;

 if v_qslots>0 then
   v_section_size:=v_q_size/v_qslots;
   drop table if exists pg_temp.tmp_q_slots;
   create temporary table tmp_q_slots(slot integer primary key,kind text,player_id uuid) on commit drop;
   insert into tmp_q_slots(slot) select generate_series(1,v_q_size);
   v_seed_no:=0;
   for r in
     select e.id,e.player_id,e.ranking_position_snapshot from public.tournament_entries e
     where e.competition_id=p_competition_id and e.draw_type='qualification' and e.entry_status='active'
     order by e.ranking_position_snapshot nulls last,e.player_id limit v_q_seeds
   loop
     v_seed_no:=v_seed_no+1;
     if v_seed_no<=v_qslots then
       v_section:=v_seed_no;v_slot:=(v_section-1)*v_section_size+1;
     else
       select x.section_no into v_section from generate_series(1,v_qslots) as x(section_no)
       order by md5(p_competition_id::text||':q-bottom-section:'||x.section_no::text)
       offset (v_seed_no-v_qslots-1) limit 1;
       v_slot:=(v_section-1)*v_section_size+v_section_size;
     end if;
     update tmp_q_slots set kind='player',player_id=r.player_id where slot=v_slot;
     update public.tournament_entries set seed_number=v_seed_no,bracket_slot=v_slot,updated_at=now() where id=r.id;
   end loop;
   v_q_byes:=v_q_size-v_q_count;v_remaining:=v_q_byes;
   for r in select seed_number,bracket_slot from public.tournament_entries where competition_id=p_competition_id and draw_type='qualification' and seed_number is not null order by seed_number loop
     exit when v_remaining<=0;
     v_opp:=case when mod(r.bracket_slot,2)=1 then r.bracket_slot+1 else r.bracket_slot-1 end;
     if exists(select 1 from tmp_q_slots where slot=v_opp and kind is null) then update tmp_q_slots set kind='bye' where slot=v_opp;v_remaining:=v_remaining-1;end if;
   end loop;
   while v_remaining>0 loop
     select slot into v_slot from tmp_q_slots where kind is null order by md5(p_competition_id::text||':q-bye:'||slot::text) limit 1;
     update tmp_q_slots set kind='bye' where slot=v_slot;v_remaining:=v_remaining-1;
   end loop;
   for r in
     select e.id,e.player_id from public.tournament_entries e
     where e.competition_id=p_competition_id and e.draw_type='qualification' and e.entry_status='active' and e.seed_number is null
     order by md5(p_competition_id::text||':q-player:'||e.player_id::text)
   loop
     select slot into v_slot from tmp_q_slots where kind is null order by md5(p_competition_id::text||':q-open:'||slot::text) limit 1;
     update tmp_q_slots set kind='player',player_id=r.player_id where slot=v_slot;
     update public.tournament_entries set bracket_slot=v_slot,updated_at=now() where id=r.id;
   end loop;
   for v_round in 1..v_q_rounds loop
     v_matches:=v_q_size/(power(2,v_round)::integer);v_label:=public.tournament_round_label_v1('qualification',v_q_size,v_round,v_q_rounds);
     for v_match in 1..v_matches loop
       v_p1:=null;v_p2:=null;
       if v_round=1 then
         select player_id into v_p1 from tmp_q_slots where slot=v_match*2-1 and kind='player';
         select player_id into v_p2 from tmp_q_slots where slot=v_match*2 and kind='player';
       end if;
       insert into public.tournament_matches(competition_id,draw_type,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,player1_id,player2_id,status)
       values(p_competition_id,'qualification',v_round,v_label,v_match,v_q_size,v_q_week,(v_q_offset+v_round)::smallint,v_p1,v_p2,'scheduled');
     end loop;
   end loop;
 end if;

 insert into public.tournament_draw_publications(competition_id,ranking_snapshot_absolute_day,main_draw_size,main_seed_count,qualifying_draw_size,qualifying_seed_count,qualifier_slots,randomization_key)
 values(p_competition_id,v_abs,v_main_size,v_main_seeds,v_q_size,v_q_seeds,v_qslots,md5(p_competition_id::text||':draw-v1'));

 for v_match in 1..(v_main_size/2) loop perform public.resolve_main_first_round_match_v1(p_competition_id,v_match);end loop;
 if v_qslots>0 then
   for v_match in 1..(v_q_size/2) loop
     select player1_id,player2_id into v_p1,v_p2 from public.tournament_matches where competition_id=p_competition_id and draw_type='qualification' and round_number=1 and match_number=v_match;
     if v_p1 is null and v_p2 is null then
       update public.tournament_matches set status='cancelled',completed_at=now(),updated_at=now() where competition_id=p_competition_id and draw_type='qualification' and round_number=1 and match_number=v_match;
     elsif (v_p1 is null)<>(v_p2 is null) then
       update public.tournament_matches set status='bye',winner_id=coalesce(v_p1,v_p2),completed_at=now(),updated_at=now() where competition_id=p_competition_id and draw_type='qualification' and round_number=1 and match_number=v_match;
     end if;
   end loop;
 end if;
 return jsonb_build_object('status','published','main_draw_size',v_main_size,'main_seeds',v_main_seeds,'qualification_size',v_q_size,'qualification_seeds',v_q_seeds,'qualifier_slots',v_qslots,'main_byes',v_byes,'qualification_byes',v_q_byes);
end;$$;
revoke all on function public.publish_tournament_draw_v1(uuid) from public,anon,authenticated;

create or replace function public.process_due_tournament_draws_v1()
returns jsonb language plpgsql security definer set search_path='public' as $$
declare d record;v_abs integer;v_count integer:=0;r record;v_result jsonb;
begin
 select * into d from public.get_current_game_day_internal_v1();v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
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
     if v_result->>'status'='published' then v_count:=v_count+1;end if;
   exception when others then null;
   end;
 end loop;
 return jsonb_build_object('status','processed','published_draws',v_count,'game_absolute_day',v_abs);
end;$$;
revoke all on function public.process_due_tournament_draws_v1() from public,anon,authenticated;
select cron.unschedule(jobid) from cron.job where jobname='tennis-draw-publication-v1';
select cron.schedule('tennis-draw-publication-v1','47 * * * *','select public.process_due_tournament_draws_v1();');