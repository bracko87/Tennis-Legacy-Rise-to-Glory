CREATE OR REPLACE FUNCTION public.get_tournament_application_field_v1(p_competition_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
           row_number() over(order by coalesce(pr.ranking_points,0) desc,coalesce(pr.seed_rating,0) desc,p.created_at,p.id)::integer current_world_rank
    from public.players p
    left join public.player_rankings pr on pr.player_id=p.id
    where p.world=v_world and p.moderation_status<>'rejected'
  ), base as (
    select a.id application_id,a.player_id,p.first_name,p.last_name,p.country_code,p.player_type,
           a.priority,a.accept_qualification,a.application_source,a.status application_status,a.decision_reason,
           rw.current_world_rank::integer world_rank,
           a.ranking_position_snapshot::integer application_rank_at_submission,
           rw.current_world_rank,
           te.draw_type entry_draw_type,te.entry_status,
           (p.owner_user_id=v_uid) is_user,
           row_number() over(order by rw.current_world_rank,a.created_at,a.id)::integer overall_order
    from public.tournament_applications a
    join public.players p on p.id=a.player_id
    join ranked_world rw on rw.player_id=a.player_id
    left join public.tournament_entries te on te.competition_id=a.competition_id and te.player_id=a.player_id
    where a.competition_id=p_competition_id
      and a.status in ('applied','accepted_main_draw','accepted_qualification')
  ), staged as (
    select b.*,
           count(*) filter(where b.overall_order>v_direct_slots and b.accept_qualification and b.application_status in ('applied','accepted_qualification'))
             over(order by b.overall_order rows between unbounded preceding and current row)::integer as qualification_order
    from base b
  ), projected as (
    select s.*,
      case
        when s.entry_draw_type='main_draw' then 'main_draw'
        when s.entry_draw_type='qualification' then 'qualification'
        when s.application_status='accepted_main_draw' then 'main_draw'
        when s.application_status='accepted_qualification' then 'qualification'
        when s.application_status='applied' and s.overall_order<=v_direct_slots then 'main_draw'
        when s.application_status='applied' and s.overall_order>v_direct_slots and s.accept_qualification and s.qualification_order<=v_qcap then 'qualification'
        else 'outside'
      end projected_group
    from staged s
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'application_id',application_id,'player_id',player_id,'first_name',first_name,'last_name',last_name,
      'country_code',country_code,'player_type',player_type,'world_rank',world_rank,'current_world_rank',current_world_rank,'application_rank_at_submission',application_rank_at_submission,'priority',priority,
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
end;
$function$
;